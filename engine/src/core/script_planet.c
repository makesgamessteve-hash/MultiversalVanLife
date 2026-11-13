/* Multiversal Van Life - Lua bindings for the planet kernels (planet.h).
 * Cells and plates are numbered from 1 in Lua. MIT License. */
#include "core/planet.h"
#include "core/script_internal.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>

static const mvl_planet_grid *check_grid(lua_State *L, int arg) {
    int level = (int)luaL_checkinteger(L, arg);
    const mvl_planet_grid *g = mvl_planet_grid_get(level);
    if (!g) luaL_error(L, "planet grid level must be 0..%d", MVL_PLANET_MAX_LEVEL);
    return g;
}

static int check_cell(lua_State *L, const mvl_planet_grid *g, int arg) {
    int c = (int)luaL_checkinteger(L, arg);
    if (c < 1 || c > g->count) luaL_error(L, "cell %d out of range 1..%d", c, g->count);
    return c - 1;
}

static int table_int(lua_State *L, int t, const char *k, int def) {
    int v = def;
    lua_getfield(L, t, k);
    if (lua_isnumber(L, -1)) v = (int)lua_tointeger(L, -1);
    lua_pop(L, 1);
    return v;
}

static float table_num(lua_State *L, int t, const char *k, float def) {
    float v = def;
    lua_getfield(L, t, k);
    if (lua_isnumber(L, -1)) v = (float)lua_tonumber(L, -1);
    lua_pop(L, 1);
    return v;
}

static void push_floats(lua_State *L, const float *v, int n) {
    lua_createtable(L, n, 0);
    for (int i = 0; i < n; ++i) {
        lua_pushnumber(L, (lua_Number)v[i]);
        lua_rawseti(L, -2, i + 1);
    }
}

static void push_ints(lua_State *L, const int *v, int n, int add) {
    lua_createtable(L, n, 0);
    for (int i = 0; i < n; ++i) {
        lua_pushinteger(L, v[i] + add);
        lua_rawseti(L, -2, i + 1);
    }
}

/* Reads a Lua array of numbers (cell values) into floats. */
static float *read_floats(lua_State *L, int idx, int n) {
    float *v = (float *)malloc(sizeof(float) * (size_t)n);
    if (!v) luaL_error(L, "out of memory");
    luaL_checktype(L, idx, LUA_TTABLE);
    if ((int)lua_rawlen(L, idx) < n) {
        free(v);
        luaL_error(L, "expected %d cell values", n);
    }
    for (int i = 0; i < n; ++i) {
        lua_rawgeti(L, idx, i + 1);
        v[i] = (float)lua_tonumber(L, -1);
        lua_pop(L, 1);
    }
    return v;
}

/* planet_grid(level) -> cell count, mean neighbour distance (chord) */
static int l_planet_grid(lua_State *L) {
    const mvl_planet_grid *g = check_grid(L, 1);
    lua_pushinteger(L, g->count);
    lua_pushnumber(L, g->edge);
    return 2;
}

/* planet_cell(level, i) -> x, y, z */
static int l_planet_cell(lua_State *L) {
    const mvl_planet_grid *g = check_grid(L, 1);
    int c = check_cell(L, g, 2);
    for (int k = 0; k < 3; ++k) lua_pushnumber(L, g->pos[3 * c + k]);
    return 3;
}

/* planet_neighbours(level, i) -> { j, ... } */
static int l_planet_neighbours(lua_State *L) {
    const mvl_planet_grid *g = check_grid(L, 1);
    int c = check_cell(L, g, 2);
    push_ints(L, g->nbr + g->nbr_start[c], g->nbr_start[c + 1] - g->nbr_start[c], 1);
    return 1;
}

/* planet_nearest(level, x, y, z) -> i */
static int l_planet_nearest(lua_State *L) {
    const mvl_planet_grid *g = check_grid(L, 1);
    lua_pushinteger(L, mvl_planet_nearest(g, (float)luaL_checknumber(L, 2), (float)luaL_checknumber(L, 3),
                                          (float)luaL_checknumber(L, 4)) + 1);
    return 1;
}

/* planet_sample(level, values, x, y, z) -> value interpolated from the
 * nearest cell and its neighbours */
static int l_planet_sample(lua_State *L) {
    const mvl_planet_grid *g = check_grid(L, 1);
    float p[3] = {(float)luaL_checknumber(L, 3), (float)luaL_checknumber(L, 4), (float)luaL_checknumber(L, 5)};
    float l, wsum = 0.0f, vsum = 0.0f;
    int c;
    luaL_checktype(L, 2, LUA_TTABLE);
    l = sqrtf(p[0] * p[0] + p[1] * p[1] + p[2] * p[2]);
    if (l <= 0.0f) return luaL_error(L, "zero direction");
    p[0] /= l, p[1] /= l, p[2] /= l;
    c = mvl_planet_nearest(g, p[0], p[1], p[2]);
    for (int j = g->nbr_start[c] - 1; j < g->nbr_start[c + 1]; ++j) {
        int cell = j < g->nbr_start[c] ? c : g->nbr[j];
        const float *q = g->pos + 3 * cell;
        float dx = p[0] - q[0], dy = p[1] - q[1], dz = p[2] - q[2];
        float d2 = (dx * dx + dy * dy + dz * dz) / (g->edge * g->edge), w = 1.0f / (d2 * d2 + 1e-6f);
        lua_rawgeti(L, 2, cell + 1);
        vsum += w * (float)lua_tonumber(L, -1);
        wsum += w;
        lua_pop(L, 1);
    }
    lua_pushnumber(L, vsum / wsum);
    return 1;
}

/* planet_plates(level, seed, n) -> { plate of each cell } */
static int l_planet_plates(lua_State *L) {
    const mvl_planet_grid *g = check_grid(L, 1);
    int *plate = (int *)malloc(sizeof(int) * (size_t)g->count);
    if (!plate) return luaL_error(L, "out of memory");
    mvl_planet_plates(g, (uint32_t)luaL_checkinteger(L, 2), (int)luaL_checkinteger(L, 3), plate);
    push_ints(L, plate, g->count, 1);
    free(plate);
    return 1;
}

/* planet_tectonics{ level, seed, plates, continental } -> { plate, elevation,
 * boundary, dist, plates = { { pole, speed, continental, area } } } */
static int l_planet_tectonics(lua_State *L) {
    const mvl_planet_grid *g;
    int n, *plate, ib;
    float *elev, *dist;
    uint8_t *bound;
    mvl_plate_info info[MVL_PLANET_MAX_PLATES];
    luaL_checktype(L, 1, LUA_TTABLE);
    g = mvl_planet_grid_get(table_int(L, 1, "level", 5));
    if (!g) return luaL_error(L, "planet grid level must be 0..%d", MVL_PLANET_MAX_LEVEL);
    plate = (int *)malloc(sizeof(int) * (size_t)g->count);
    elev = (float *)malloc(sizeof(float) * (size_t)g->count);
    dist = (float *)malloc(sizeof(float) * (size_t)g->count);
    bound = (uint8_t *)malloc((size_t)g->count);
    if (!plate || !elev || !dist || !bound) {
        free(plate), free(elev), free(dist), free(bound);
        return luaL_error(L, "out of memory");
    }
    n = mvl_planet_tectonics(g, (uint32_t)table_int(L, 1, "seed", 0), table_int(L, 1, "plates", 12),
                             table_num(L, 1, "continental", 0.35f), plate, elev, bound, dist, info);
    lua_createtable(L, 0, 5);
    push_ints(L, plate, g->count, 1);
    lua_setfield(L, -2, "plate");
    push_floats(L, elev, g->count);
    lua_setfield(L, -2, "elevation");
    lua_createtable(L, g->count, 0);
    ib = lua_gettop(L);
    for (int i = 0; i < g->count; ++i) {
        lua_pushinteger(L, bound[i]);
        lua_rawseti(L, ib, i + 1);
    }
    lua_setfield(L, -2, "boundary");
    for (int i = 0; i < g->count; ++i)
        if (dist[i] > 1e8f) dist[i] = 99.0f;
    push_floats(L, dist, g->count);
    lua_setfield(L, -2, "dist");
    lua_createtable(L, n, 0);
    for (int k = 0; k < n; ++k) {
        lua_createtable(L, 0, 4);
        push_floats(L, info[k].pole, 3);
        lua_setfield(L, -2, "pole");
        lua_pushnumber(L, info[k].speed);
        lua_setfield(L, -2, "speed");
        lua_pushboolean(L, info[k].continental);
        lua_setfield(L, -2, "continental");
        lua_pushnumber(L, info[k].area);
        lua_setfield(L, -2, "area");
        lua_rawseti(L, -2, k + 1);
    }
    lua_setfield(L, -2, "plates");
    free(plate), free(elev), free(dist), free(bound);
    return 1;
}

static void read_vec3(lua_State *L, int t, const char *k, float *out, float x, float y, float z) {
    out[0] = x, out[1] = y, out[2] = z;
    lua_getfield(L, t, k);
    if (lua_istable(L, -1))
        for (int i = 0; i < 3; ++i) {
            lua_rawgeti(L, -1, i + 1);
            out[i] = (float)lua_tonumber(L, -1);
            lua_pop(L, 1);
        }
    lua_pop(L, 1);
}

static const mvl_planet_grid *table_grid(lua_State *L, int t) {
    const mvl_planet_grid *g = mvl_planet_grid_get(table_int(L, t, "level", 5));
    if (!g) luaL_error(L, "planet grid level must be 0..%d", MVL_PLANET_MAX_LEVEL);
    return g;
}

/* planet_climate{ level, elevation, axis, tilt_sin, locked, sub, mean, span,
 * lapse, water, iterations } -> { temp, tmin, tmax, precip, wind } */
static int l_planet_climate(lua_State *L) {
    const mvl_planet_grid *g;
    mvl_climate_params p;
    float *elev, *tm, *tn, *tx, *pr;
    int *wind;
    luaL_checktype(L, 1, LUA_TTABLE);
    g = table_grid(L, 1);
    memset(&p, 0, sizeof p);
    read_vec3(L, 1, "axis", p.axis, 0, 1, 0);
    read_vec3(L, 1, "sub", p.sub, 1, 0, 0);
    p.sin_tilt = table_num(L, 1, "tilt_sin", 0.4f);
    lua_getfield(L, 1, "locked");
    p.locked = lua_toboolean(L, -1);
    lua_pop(L, 1);
    p.mean = table_num(L, 1, "mean", 288.0f);
    p.span = table_num(L, 1, "span", 60.0f);
    p.lapse = table_num(L, 1, "lapse", 6.5f);
    p.water = table_num(L, 1, "water", 0.7f);
    p.iterations = table_int(L, 1, "iterations", 80);
    lua_getfield(L, 1, "elevation");
    elev = read_floats(L, lua_gettop(L), g->count);
    lua_pop(L, 1);
    tm = (float *)malloc(sizeof(float) * (size_t)g->count * 4);
    wind = (int *)malloc(sizeof(int) * (size_t)g->count);
    if (!tm || !wind) {
        free(elev), free(tm), free(wind);
        return luaL_error(L, "out of memory");
    }
    tn = tm + g->count, tx = tn + g->count, pr = tx + g->count;
    mvl_planet_climate(g, elev, &p, tm, tn, tx, pr, wind);
    lua_createtable(L, 0, 5);
    push_floats(L, tm, g->count);
    lua_setfield(L, -2, "temp");
    push_floats(L, tn, g->count);
    lua_setfield(L, -2, "tmin");
    push_floats(L, tx, g->count);
    lua_setfield(L, -2, "tmax");
    push_floats(L, pr, g->count);
    lua_setfield(L, -2, "precip");
    push_ints(L, wind, g->count, 1);
    lua_setfield(L, -2, "wind");
    free(elev), free(tm), free(wind);
    return 1;
}

/* planet_rivers{ level, elevation, precip } -> { filled, flow_to (0 at the
 * sea), flow, lake (booleans) } */
static int l_planet_rivers(lua_State *L) {
    const mvl_planet_grid *g;
    float *elev, *prec, *filled, *flow;
    int *to;
    uint8_t *lake;
    luaL_checktype(L, 1, LUA_TTABLE);
    g = table_grid(L, 1);
    lua_getfield(L, 1, "elevation");
    elev = read_floats(L, lua_gettop(L), g->count);
    lua_pop(L, 1);
    lua_getfield(L, 1, "precip");
    prec = read_floats(L, lua_gettop(L), g->count);
    lua_pop(L, 1);
    filled = (float *)malloc(sizeof(float) * (size_t)g->count * 2);
    to = (int *)malloc(sizeof(int) * (size_t)g->count);
    lake = (uint8_t *)malloc((size_t)g->count);
    if (!filled || !to || !lake) {
        free(elev), free(prec), free(filled), free(to), free(lake);
        return luaL_error(L, "out of memory");
    }
    flow = filled + g->count;
    mvl_planet_rivers(g, elev, prec, filled, to, flow, lake);
    lua_createtable(L, 0, 4);
    push_floats(L, filled, g->count);
    lua_setfield(L, -2, "filled");
    push_ints(L, to, g->count, 1);
    lua_setfield(L, -2, "flow_to");
    push_floats(L, flow, g->count);
    lua_setfield(L, -2, "flow");
    lua_createtable(L, g->count, 0);
    for (int i = 0; i < g->count; ++i) {
        lua_pushboolean(L, lake[i]);
        lua_rawseti(L, -2, i + 1);
    }
    lua_setfield(L, -2, "lake");
    free(elev), free(prec), free(filled), free(to), free(lake);
    return 1;
}

/* planet_territory(level, seeds, cost) -> { owner (seed number or 0) } */
static int l_planet_territory(lua_State *L) {
    const mvl_planet_grid *g = check_grid(L, 1);
    int n, *seeds, *owner;
    float *cost;
    luaL_checktype(L, 2, LUA_TTABLE);
    n = (int)lua_rawlen(L, 2);
    seeds = (int *)malloc(sizeof(int) * (size_t)(n > 0 ? n : 1));
    owner = (int *)malloc(sizeof(int) * (size_t)g->count);
    if (!seeds || !owner) {
        free(seeds), free(owner);
        return luaL_error(L, "out of memory");
    }
    for (int i = 0; i < n; ++i) {
        lua_rawgeti(L, 2, i + 1);
        seeds[i] = (int)lua_tointeger(L, -1) - 1;
        lua_pop(L, 1);
    }
    cost = read_floats(L, 3, g->count);
    mvl_planet_territory(g, seeds, n, cost, owner);
    push_ints(L, owner, g->count, 1);
    free(seeds), free(owner), free(cost);
    return 1;
}

/* planet_components(level, mask) -> ids (1.., 0 for masked out), count */
static int l_planet_components(lua_State *L) {
    const mvl_planet_grid *g = check_grid(L, 1);
    uint8_t *mask = (uint8_t *)malloc((size_t)g->count);
    int *id = (int *)malloc(sizeof(int) * (size_t)g->count), n;
    if (!mask || !id) {
        free(mask), free(id);
        return luaL_error(L, "out of memory");
    }
    luaL_checktype(L, 2, LUA_TTABLE);
    for (int i = 0; i < g->count; ++i) {
        lua_rawgeti(L, 2, i + 1);
        mask[i] = (uint8_t)lua_toboolean(L, -1);
        lua_pop(L, 1);
    }
    n = mvl_planet_components(g, mask, id);
    push_ints(L, id, g->count, 1);
    lua_pushinteger(L, n);
    free(mask), free(id);
    return 2;
}

void mvl_script_open_planet(lua_State *L) {
    static const luaL_Reg funcs[] = {{"planet_grid", l_planet_grid},       {"planet_cell", l_planet_cell},
                                     {"planet_neighbours", l_planet_neighbours},
                                     {"planet_nearest", l_planet_nearest}, {"planet_sample", l_planet_sample},
                                     {"planet_plates", l_planet_plates},   {"planet_tectonics", l_planet_tectonics},
                                     {"planet_climate", l_planet_climate}, {"planet_rivers", l_planet_rivers},
                                     {"planet_territory", l_planet_territory},
                                     {"planet_components", l_planet_components}, {NULL, NULL}};
    luaL_setfuncs(L, funcs, 0);
}
