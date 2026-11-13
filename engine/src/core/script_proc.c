/* Multiversal Van Life - Lua bindings for procedural generation: hashing,
 * random streams, noise, terrain, runtime voxel models, generated textures,
 * resource release and entity parenting. MIT License. */
#include "core/noise.h"
#include "core/script_internal.h"
#include "core/texgen.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define RNG_MT "mvl.rng"
#define VOX_MT "mvl.voxels"

static int field_int(lua_State *L, int t, const char *k, int def) {
    int v = def;
    lua_getfield(L, t, k);
    if (lua_isnumber(L, -1)) v = (int)lua_tointeger(L, -1);
    lua_pop(L, 1);
    return v;
}

static float field_num(lua_State *L, int t, const char *k, float def) {
    float v = def;
    lua_getfield(L, t, k);
    if (lua_isnumber(L, -1)) v = (float)lua_tonumber(L, -1);
    lua_pop(L, 1);
    return v;
}

/* Reads {r, g, b[, a]} (0..255) at the top of the stack into out. */
static void read_rgba(lua_State *L, uint8_t out[4]) {
    for (int i = 0; i < 4; ++i) {
        lua_rawgeti(L, -1, i + 1);
        out[i] = (uint8_t)(lua_isnumber(L, -1) ? (int)lua_tointeger(L, -1) & 255 : (i == 3 ? 255 : 0));
        lua_pop(L, 1);
    }
}

/* ------------------------------------------------------------ hashing */
static int l_hash(lua_State *L) {
    uint32_t h = 0x811c9dc5u;
    int n = lua_gettop(L);
    for (int i = 1; i <= n; ++i) {
        if (lua_type(L, i) == LUA_TSTRING) h = mvl_hash_combine(h, mvl_hash_str(lua_tostring(L, i), 0));
        else {
            lua_Integer v = luaL_checkinteger(L, i);
            h = mvl_hash_combine(mvl_hash_combine(h, (uint32_t)v), (uint32_t)((uint64_t)v >> 32));
        }
    }
    lua_pushinteger(L, (lua_Integer)h);
    return 1;
}

/* -------------------------------------------------------- random stream */
static mvl_rng *check_rng(lua_State *L) { return (mvl_rng *)luaL_checkudata(L, 1, RNG_MT); }

static int l_rng(lua_State *L) {
    uint32_t seed = (uint32_t)luaL_checkinteger(L, 1), stream = (uint32_t)luaL_optinteger(L, 2, 0);
    mvl_rng *r = (mvl_rng *)lua_newuserdatauv(L, sizeof(mvl_rng), 0);
    mvl_rng_seed(r, seed, stream);
    luaL_setmetatable(L, RNG_MT);
    return 1;
}

static int rng_next(lua_State *L) {
    lua_pushnumber(L, mvl_rng_float(check_rng(L)));
    return 1;
}

static int rng_u32(lua_State *L) {
    lua_pushinteger(L, (lua_Integer)mvl_rng_u32(check_rng(L)));
    return 1;
}

static int rng_int(lua_State *L) {
    mvl_rng *r = check_rng(L);
    lua_pushinteger(L, mvl_rng_range(r, (int32_t)luaL_checkinteger(L, 2), (int32_t)luaL_checkinteger(L, 3)));
    return 1;
}

static int rng_float(lua_State *L) {
    mvl_rng *r = check_rng(L);
    float lo = (float)luaL_optnumber(L, 2, 0), hi = (float)luaL_optnumber(L, 3, 1);
    lua_pushnumber(L, lo + (hi - lo) * mvl_rng_float(r));
    return 1;
}

static int rng_chance(lua_State *L) {
    mvl_rng *r = check_rng(L);
    lua_pushboolean(L, mvl_rng_float(r) < (float)luaL_checknumber(L, 2));
    return 1;
}

/* Picks a random element of an array table. */
static int rng_pick(lua_State *L) {
    mvl_rng *r = check_rng(L);
    lua_Integer n;
    luaL_checktype(L, 2, LUA_TTABLE);
    n = (lua_Integer)lua_rawlen(L, 2);
    if (n == 0) return 0;
    lua_rawgeti(L, 2, 1 + mvl_rng_range(r, 0, (int32_t)n - 1));
    return 1;
}

/* --------------------------------------------------------------- noise */
static int l_noise(lua_State *L) {
    float x = (float)luaL_checknumber(L, 1), y = (float)luaL_checknumber(L, 2);
    uint32_t seed = (uint32_t)luaL_optinteger(L, 3, 0);
    int oct = (int)luaL_optinteger(L, 4, 1);
    lua_pushnumber(L, mvl_fbm2(x, y, seed, oct, (float)luaL_optnumber(L, 5, 2.0), (float)luaL_optnumber(L, 6, 0.5)));
    return 1;
}

static int l_noise3(lua_State *L) {
    float x = (float)luaL_checknumber(L, 1), y = (float)luaL_checknumber(L, 2), z = (float)luaL_checknumber(L, 3);
    uint32_t seed = (uint32_t)luaL_optinteger(L, 4, 0);
    int oct = (int)luaL_optinteger(L, 5, 1);
    lua_pushnumber(L, mvl_fbm3(x, y, z, seed, oct, (float)luaL_optnumber(L, 6, 2.0), (float)luaL_optnumber(L, 7, 0.5)));
    return 1;
}

/* ------------------------------------------------------------- terrain */
static int l_terrain(lua_State *L) {
    mvl_engine *e = mvl_script_engine(L);
    mvl_terrain *t = &e->terrain;
    luaL_checktype(L, 1, LUA_TTABLE);
    mvl_terrain_free(t);
    mvl_terrain_init(t, (uint32_t)field_int(L, 1, "seed", 0));
    t->base = field_num(L, 1, "base", t->base);
    t->amp = field_num(L, 1, "amp", t->amp);
    t->freq = field_num(L, 1, "freq", t->freq);
    t->octaves = field_int(L, 1, "octaves", t->octaves);
    t->lacunarity = field_num(L, 1, "lacunarity", t->lacunarity);
    t->gain = field_num(L, 1, "gain", t->gain);
    t->color_low = field_num(L, 1, "color_low", t->color_low);
    t->color_high = field_num(L, 1, "color_high", t->color_high);
    t->slope_start = field_num(L, 1, "slope_start", t->slope_start);
    t->color_noise = field_num(L, 1, "color_noise", t->color_noise);
    t->uv_scale = field_num(L, 1, "uv_scale", t->uv_scale);
    if (t->uv_scale <= 0.0f) t->uv_scale = 4.0f;
    lua_getfield(L, 1, "palette");
    if (lua_istable(L, -1)) {
        int n = (int)lua_rawlen(L, -1);
        t->palette_count = 0;
        for (int i = 1; i <= n && i <= MVL_TERRAIN_PALETTE; ++i) {
            lua_rawgeti(L, -1, i);
            if (lua_istable(L, -1)) read_rgba(L, t->palette[t->palette_count++]);
            lua_pop(L, 1);
        }
        if (t->palette_count == 0) t->palette_count = 1;
    }
    lua_pop(L, 1);
    lua_getfield(L, 1, "slope_color");
    if (lua_istable(L, -1)) read_rgba(L, t->slope_color);
    lua_pop(L, 1);
    lua_getfield(L, 1, "flats");
    if (lua_istable(L, -1)) {
        int n = (int)lua_rawlen(L, -1);
        for (int i = 1; i <= n; ++i) {
            lua_rawgeti(L, -1, i);
            if (lua_istable(L, -1)) {
                int top = lua_gettop(L);
                if (!mvl_terrain_add_flat(t, field_num(L, top, "x", 0), field_num(L, top, "z", 0),
                                          field_num(L, top, "radius", 4), field_num(L, top, "falloff", 6),
                                          field_num(L, top, "height", 0)))
                    luaL_error(L, "too many flat areas (max %d)", MVL_TERRAIN_MAX_FLATS);
            }
            lua_pop(L, 1);
        }
    }
    lua_pop(L, 1);
    lua_getfield(L, 1, "map");
    if (lua_istable(L, -1)) {
        int top = lua_gettop(L), w = field_int(L, top, "w", 0), h = field_int(L, top, "h", 0);
        float *data;
        if (w < 2 || h < 2 || w * h > 1 << 20) return luaL_error(L, "terrain map needs w, h >= 2");
        data = (float *)malloc(sizeof(float) * (size_t)w * (size_t)h);
        if (!data) return luaL_error(L, "out of memory");
        lua_getfield(L, top, "data");
        for (int i = 0; i < w * h; ++i) {
            lua_rawgeti(L, -1, i + 1);
            data[i] = (float)lua_tonumber(L, -1);
            lua_pop(L, 1);
        }
        lua_pop(L, 1);
        mvl_terrain_set_map(t, data, w, h, field_num(L, top, "x0", 0), field_num(L, top, "z0", 0),
                            field_num(L, top, "cell", 1));
        free(data);
    }
    lua_pop(L, 1);
    return 0;
}

static int l_height(lua_State *L) {
    lua_pushnumber(L, mvl_terrain_height(&mvl_script_engine(L)->terrain, (float)luaL_checknumber(L, 1),
                                         (float)luaL_checknumber(L, 2)));
    return 1;
}

static int l_terrain_chunk(lua_State *L) {
    mvl_engine *e = mvl_script_engine(L);
    int cx = (int)luaL_checkinteger(L, 1), cz = (int)luaL_checkinteger(L, 2);
    float size = (float)luaL_optnumber(L, 3, 32);
    int cells = (int)luaL_optinteger(L, 4, 16);
    mvl_mesh m;
    char name[64];
    if (!mvl_terrain_build_chunk(&e->terrain, cx, cz, size, cells, &m)) return luaL_error(L, "invalid chunk parameters");
    snprintf(name, sizeof name, "<terrain %d %d>", cx, cz);
    lua_pushinteger(L, mvl_res_mesh_from_data(&e->res, name, &m));
    mvl_mesh_free(&m);
    return 1;
}

/* ------------------------------------------------------ resource release */
static int l_release_mesh(lua_State *L) {
    lua_pushboolean(L, mvl_res_release_mesh(&mvl_script_engine(L)->res, (int)luaL_checkinteger(L, 1)));
    return 1;
}

static int l_release_texture(lua_State *L) {
    lua_pushboolean(L, mvl_res_release_texture(&mvl_script_engine(L)->res, (int)luaL_checkinteger(L, 1)));
    return 1;
}

/* ------------------------------------------------------------ parenting */
static int l_attach(lua_State *L) {
    mvl_engine *e = mvl_script_engine(L);
    lua_pushboolean(L, mvl_scene_attach(&e->scene, (int)luaL_checkinteger(L, 1), (int)luaL_optinteger(L, 2, 0)));
    return 1;
}

static int l_world_pos(lua_State *L) {
    mvl_engine *e = mvl_script_engine(L);
    mvl_entity *en = mvl_scene_get(&e->scene, (int)luaL_checkinteger(L, 1));
    vec3 p;
    if (!en) return 0;
    p = mvl_scene_world_pos(&e->scene, en);
    lua_pushnumber(L, p.x);
    lua_pushnumber(L, p.y);
    lua_pushnumber(L, p.z);
    return 3;
}

/* --------------------------------------------------------- voxel models */
static mvl_voxels *check_vox(lua_State *L) {
    mvl_voxels *v = (mvl_voxels *)luaL_checkudata(L, 1, VOX_MT);
    if (!v->cells) luaL_error(L, "voxel grid was freed");
    return v;
}

static uint8_t arg_color(lua_State *L, int idx) { return (uint8_t)(luaL_checkinteger(L, idx) & 255); }

static int l_voxels(lua_State *L) {
    int sx = (int)luaL_checkinteger(L, 1), sy = (int)luaL_checkinteger(L, 2), sz = (int)luaL_checkinteger(L, 3);
    mvl_voxels *v = (mvl_voxels *)lua_newuserdatauv(L, sizeof(mvl_voxels), 0);
    memset(v, 0, sizeof *v);
    luaL_setmetatable(L, VOX_MT);
    if (!mvl_voxels_alloc(v, sx, sy, sz)) return luaL_error(L, "voxel grid size must be 1..%d", MVL_VOXGRID_MAX);
    return 1;
}

static int vox_gc(lua_State *L) {
    mvl_voxels_free((mvl_voxels *)luaL_checkudata(L, 1, VOX_MT));
    return 0;
}

static int vox_set(lua_State *L) {
    mvl_voxels_set(check_vox(L), (int)luaL_checkinteger(L, 2), (int)luaL_checkinteger(L, 3), (int)luaL_checkinteger(L, 4),
                   arg_color(L, 5));
    return 0;
}

static int vox_get(lua_State *L) {
    lua_pushinteger(L, mvl_voxels_get(check_vox(L), (int)luaL_checkinteger(L, 2), (int)luaL_checkinteger(L, 3),
                                      (int)luaL_checkinteger(L, 4)));
    return 1;
}

static int vox_box(lua_State *L) {
    mvl_voxels_fill_box(check_vox(L), (int)luaL_checkinteger(L, 2), (int)luaL_checkinteger(L, 3), (int)luaL_checkinteger(L, 4),
                        (int)luaL_checkinteger(L, 5), (int)luaL_checkinteger(L, 6), (int)luaL_checkinteger(L, 7),
                        arg_color(L, 8));
    return 0;
}

static int vox_ellipsoid(lua_State *L) {
    mvl_voxels_fill_ellipsoid(check_vox(L), (float)luaL_checknumber(L, 2), (float)luaL_checknumber(L, 3),
                              (float)luaL_checknumber(L, 4), (float)luaL_checknumber(L, 5), (float)luaL_checknumber(L, 6),
                              (float)luaL_checknumber(L, 7), arg_color(L, 8));
    return 0;
}

static int vox_sphere(lua_State *L) {
    float r = (float)luaL_checknumber(L, 5);
    mvl_voxels_fill_ellipsoid(check_vox(L), (float)luaL_checknumber(L, 2), (float)luaL_checknumber(L, 3),
                              (float)luaL_checknumber(L, 4), r, r, r, arg_color(L, 6));
    return 0;
}

static int vox_cylinder(lua_State *L) {
    mvl_voxels_fill_cylinder(check_vox(L), (float)luaL_checknumber(L, 2), (float)luaL_checknumber(L, 3),
                             (int)luaL_checkinteger(L, 4), (int)luaL_checkinteger(L, 5), (float)luaL_checknumber(L, 6),
                             arg_color(L, 7));
    return 0;
}

static int vox_line(lua_State *L) {
    mvl_voxels_fill_line(check_vox(L), (float)luaL_checknumber(L, 2), (float)luaL_checknumber(L, 3),
                         (float)luaL_checknumber(L, 4), (float)luaL_checknumber(L, 5), (float)luaL_checknumber(L, 6),
                         (float)luaL_checknumber(L, 7), (float)luaL_checknumber(L, 8), arg_color(L, 9));
    return 0;
}

static int vox_mirror_x(lua_State *L) {
    mvl_voxels_mirror_x(check_vox(L));
    return 0;
}

static int vox_replace(lua_State *L) {
    lua_pushinteger(L, mvl_voxels_replace(check_vox(L), arg_color(L, 2), arg_color(L, 3)));
    return 1;
}

static int vox_color(lua_State *L) {
    mvl_voxels_set_color(check_vox(L), (int)luaL_checkinteger(L, 2), (uint8_t)luaL_checkinteger(L, 3),
                         (uint8_t)luaL_checkinteger(L, 4), (uint8_t)luaL_checkinteger(L, 5),
                         (uint8_t)luaL_optinteger(L, 6, 255));
    return 0;
}

static int vox_count(lua_State *L) {
    lua_pushinteger(L, mvl_voxels_count(check_vox(L)));
    return 1;
}

static int vox_size(lua_State *L) {
    mvl_voxels *v = check_vox(L);
    lua_pushinteger(L, v->sx);
    lua_pushinteger(L, v->sy);
    lua_pushinteger(L, v->sz);
    return 3;
}

static int vox_mesh(lua_State *L) {
    mvl_voxels *v = check_vox(L);
    mvl_engine *e = mvl_script_engine(L);
    mvl_mesh m;
    char name[48];
    static unsigned serial;
    if (!mvl_voxels_mesh(v, (float)luaL_optnumber(L, 2, 0.125), &m)) {
        mvl_mesh_free(&m);
        lua_pushinteger(L, 0); /* empty grid */
        return 1;
    }
    snprintf(name, sizeof name, "<voxels %u>", ++serial);
    lua_pushinteger(L, mvl_res_mesh_from_data(&e->res, name, &m));
    mvl_mesh_free(&m);
    return 1;
}

static int vox_free(lua_State *L) {
    mvl_voxels_free((mvl_voxels *)luaL_checkudata(L, 1, VOX_MT));
    return 0;
}

/* -------------------------------------------------- generated textures */
static int l_texture_gen(lua_State *L) {
    mvl_engine *e = mvl_script_engine(L);
    mvl_tex_recipe r;
    mvl_image img;
    char name[48];
    int id;
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_getfield(L, 1, "kind");
    mvl_tex_recipe_init(&r, mvl_tex_kind_from_name(lua_tostring(L, -1)), 0);
    lua_pop(L, 1);
    r.seed = (uint32_t)field_int(L, 1, "seed", 0);
    r.size = field_int(L, 1, "size", r.size);
    r.scale = field_int(L, 1, "scale", r.scale);
    r.octaves = field_int(L, 1, "octaves", r.octaves);
    r.contrast = field_num(L, 1, "contrast", r.contrast);
    lua_getfield(L, 1, "colors");
    if (lua_istable(L, -1)) {
        int n = (int)lua_rawlen(L, -1);
        r.color_count = 0;
        for (int i = 1; i <= n && i <= MVL_TEX_MAX_COLORS; ++i) {
            lua_rawgeti(L, -1, i);
            if (lua_istable(L, -1)) read_rgba(L, r.colors[r.color_count++]);
            lua_pop(L, 1);
        }
        if (r.color_count == 0) r.color_count = 1;
    }
    lua_pop(L, 1);
    snprintf(name, sizeof name, "<texgen %08x>", (unsigned)mvl_tex_recipe_hash(&r));
    id = mvl_res_find_texture(&e->res, name);
    if (!id) {
        if (!mvl_tex_generate(&r, &img)) return luaL_error(L, "invalid texture recipe (size 16..128, power of two)");
        id = mvl_res_texture_from_image(&e->res, name, &img, 0);
        mvl_image_free(&img);
    }
    lua_pushinteger(L, id);
    return 1;
}

void mvl_script_open_procedural(lua_State *L) {
    static const luaL_Reg funcs[] = {{"hash", l_hash},
                                     {"rng", l_rng},
                                     {"noise", l_noise},
                                     {"noise3", l_noise3},
                                     {"terrain", l_terrain},
                                     {"height", l_height},
                                     {"terrain_chunk", l_terrain_chunk},
                                     {"release_mesh", l_release_mesh},
                                     {"release_texture", l_release_texture},
                                     {"attach", l_attach},
                                     {"world_pos", l_world_pos},
                                     {"voxels", l_voxels},
                                     {"texture_gen", l_texture_gen},
                                     {NULL, NULL}};
    static const luaL_Reg rng_methods[] = {{"next", rng_next}, {"u32", rng_u32}, {"int", rng_int}, {"float", rng_float},
                                           {"chance", rng_chance}, {"pick", rng_pick}, {NULL, NULL}};
    static const luaL_Reg vox_methods[] = {{"set", vox_set},       {"get", vox_get},           {"box", vox_box},
                                           {"ellipsoid", vox_ellipsoid}, {"sphere", vox_sphere}, {"cylinder", vox_cylinder},
                                           {"line", vox_line},     {"mirror_x", vox_mirror_x}, {"replace", vox_replace},
                                           {"color", vox_color},   {"count", vox_count},       {"size", vox_size},
                                           {"mesh", vox_mesh},     {"free", vox_free},         {NULL, NULL}};
    luaL_setfuncs(L, funcs, 0);
    luaL_newmetatable(L, RNG_MT);
    luaL_newlib(L, rng_methods);
    lua_setfield(L, -2, "__index");
    lua_pop(L, 1);
    luaL_newmetatable(L, VOX_MT);
    luaL_newlib(L, vox_methods);
    lua_setfield(L, -2, "__index");
    lua_pushcfunction(L, vox_gc);
    lua_setfield(L, -2, "__gc");
    lua_pop(L, 1);
}
