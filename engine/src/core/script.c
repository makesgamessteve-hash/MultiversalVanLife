/* Multiversal Van Life - Lua scripting bridge. MIT License.
 *
 * Exposes the `mvl` table to game scripts. Scripts are loaded through the
 * VFS (so mods can override them) and run in a light sandbox: the `io`
 * library and process-control functions of `os` are removed.
 */
#include "core/engine.h"
#include "core/log.h"
#include "core/record.h"
#include "core/script_internal.h"
#include "lauxlib.h"
#include "lua.h"
#include "lualib.h"
#include <stdlib.h>
#include <string.h>

#define ENGINE_KEY "mvl.engine"

static mvl_engine *eng(lua_State *L) {
    mvl_engine *e;
    lua_getfield(L, LUA_REGISTRYINDEX, ENGINE_KEY);
    e = (mvl_engine *)lua_touserdata(L, -1);
    lua_pop(L, 1);
    return e;
}

mvl_engine *mvl_script_engine(lua_State *L) { return eng(L); }

static void report_error(mvl_engine *e, const char *where, const char *msg) {
    snprintf(e->last_error, sizeof e->last_error, "%s: %s", where, msg ? msg : "?");
    MVL_ERROR("%s", e->last_error);
    e->script_errors++;
    if (e->test_mode) e->test_failed = 1;
}

static int traceback(lua_State *L) {
    const char *msg = lua_tostring(L, 1);
    luaL_traceback(L, L, msg ? msg : "(error object is not a string)", 1);
    return 1;
}

static int pcall_tb(lua_State *L, int nargs, int nres) {
    int base = lua_gettop(L) - nargs, r;
    lua_pushcfunction(L, traceback);
    lua_insert(L, base);
    r = lua_pcall(L, nargs, nres, base);
    lua_remove(L, base);
    return r;
}

/* ------------------------------------------------------------- helpers */
static float opt_field_num(lua_State *L, int t, const char *k, float def) {
    float v = def;
    lua_getfield(L, t, k);
    if (lua_isnumber(L, -1)) v = (float)lua_tonumber(L, -1);
    lua_pop(L, 1);
    return v;
}

static int read_vec(lua_State *L, int t, const char *k, float *out, int n) {
    int ok = 0;
    lua_getfield(L, t, k);
    if (lua_istable(L, -1)) {
        for (int i = 0; i < n; ++i) {
            lua_rawgeti(L, -1, i + 1);
            if (lua_isnumber(L, -1)) out[i] = (float)lua_tonumber(L, -1);
            lua_pop(L, 1);
        }
        ok = 1;
    } else if (lua_isnumber(L, -1) && n >= 1) {
        float v = (float)lua_tonumber(L, -1);
        for (int i = 0; i < n; ++i) out[i] = v;
        ok = 1;
    }
    lua_pop(L, 1);
    return ok;
}

static int opt_field_bool(lua_State *L, int t, const char *k, int def) {
    int v = def;
    lua_getfield(L, t, k);
    if (!lua_isnil(L, -1)) v = lua_toboolean(L, -1);
    lua_pop(L, 1);
    return v;
}

static void set_flag(unsigned *flags, unsigned bit, int on) {
    if (on) *flags |= bit;
    else *flags &= ~bit;
}

/* Applies table fields at index t to an entity. */
static void apply_entity_fields(lua_State *L, mvl_entity *en, int t) {
    float v[4];
    lua_getfield(L, t, "mesh");
    if (lua_isinteger(L, -1)) en->mesh = (int)lua_tointeger(L, -1);
    lua_pop(L, 1);
    lua_getfield(L, t, "texture");
    if (lua_isinteger(L, -1)) en->texture = (int)lua_tointeger(L, -1);
    lua_pop(L, 1);
    v[0] = en->pos.x; v[1] = en->pos.y; v[2] = en->pos.z;
    if (read_vec(L, t, "pos", v, 3)) en->pos = v3(v[0], v[1], v[2]);
    v[0] = en->scale.x; v[1] = en->scale.y; v[2] = en->scale.z;
    if (read_vec(L, t, "scale", v, 3)) en->scale = v3(v[0], v[1], v[2]);
    memcpy(v, en->color, sizeof v);
    if (read_vec(L, t, "color", v, 4)) memcpy(en->color, v, sizeof v);
    v[0] = en->uv_scroll[0]; v[1] = en->uv_scroll[1];
    if (read_vec(L, t, "uv_scroll", v, 2)) {
        en->uv_scroll[0] = v[0];
        en->uv_scroll[1] = v[1];
    }
    en->yaw = opt_field_num(L, t, "yaw", en->yaw);
    en->pitch = opt_field_num(L, t, "pitch", en->pitch);
    en->roll = opt_field_num(L, t, "roll", en->roll);
    en->radius = opt_field_num(L, t, "radius", en->radius);
    v[0] = en->half_x; v[1] = en->half_z;
    if (read_vec(L, t, "box", v, 2)) {
        en->half_x = v[0] * 0.5f;
        en->half_z = v[1] * 0.5f;
    }
    set_flag(&en->flags, MVL_ENT_VISIBLE, opt_field_bool(L, t, "visible", (en->flags & MVL_ENT_VISIBLE) != 0));
    set_flag(&en->flags, MVL_ENT_UNLIT, opt_field_bool(L, t, "unlit", (en->flags & MVL_ENT_UNLIT) != 0));
    set_flag(&en->flags, MVL_ENT_NOFOG, opt_field_bool(L, t, "nofog", (en->flags & MVL_ENT_NOFOG) != 0));
    set_flag(&en->flags, MVL_ENT_SOLID, opt_field_bool(L, t, "solid", (en->flags & MVL_ENT_SOLID) != 0));
    set_flag(&en->flags, MVL_ENT_DECAL, opt_field_bool(L, t, "decal", (en->flags & MVL_ENT_DECAL) != 0));
    set_flag(&en->flags, MVL_ENT_PERSISTENT, opt_field_bool(L, t, "persistent", (en->flags & MVL_ENT_PERSISTENT) != 0));
    {
        float layer = opt_field_num(L, t, "layer", (float)en->layer);
        en->layer = layer < 0 ? 0 : (layer > 7 ? 7 : (int)layer);
    }
}

/* ----------------------------------------------------------- resources */
static int l_texture(lua_State *L) {
    lua_pushinteger(L, mvl_res_texture(&eng(L)->res, luaL_checkstring(L, 1)));
    return 1;
}

static int l_mesh(lua_State *L) {
    lua_pushinteger(L, mvl_res_mesh(&eng(L)->res, luaL_checkstring(L, 1), (float)luaL_optnumber(L, 2, 0.125)));
    return 1;
}

static int l_plane_mesh(lua_State *L) {
    mvl_mesh m;
    char name[96];
    float sx = (float)luaL_checknumber(L, 1), sz = (float)luaL_checknumber(L, 2);
    float tx = (float)luaL_optnumber(L, 3, 1), tz = (float)luaL_optnumber(L, 4, 1);
    int seg = (int)luaL_optinteger(L, 5, 1);
    mvl_mesh_init(&m);
    mvl_mesh_build_plane_grid(&m, sx, sz, tx, tz, seg);
    snprintf(name, sizeof name, "<plane %g %g %g %g %d>", sx, sz, tx, tz, seg);
    lua_pushinteger(L, mvl_res_mesh_from_data(&eng(L)->res, name, &m));
    mvl_mesh_free(&m);
    return 1;
}

/* ribbon_mesh({x, y, z, x, y, z, ...}, width [, v_scale]) */
static int l_ribbon_mesh(lua_State *L) {
    mvl_mesh m;
    float *pts;
    int n;
    luaL_checktype(L, 1, LUA_TTABLE);
    n = (int)lua_rawlen(L, 1) / 3;
    if (n < 2 || n > 4096) return luaL_error(L, "a ribbon needs 2 to 4096 points");
    pts = (float *)malloc(sizeof(float) * 3 * (size_t)n);
    if (!pts) return luaL_error(L, "out of memory");
    for (int i = 0; i < 3 * n; ++i) {
        lua_rawgeti(L, 1, i + 1);
        pts[i] = (float)lua_tonumber(L, -1);
        lua_pop(L, 1);
    }
    mvl_mesh_init(&m);
    mvl_mesh_build_ribbon(&m, pts, n, (float)luaL_checknumber(L, 2), (float)luaL_optnumber(L, 3, 4.0));
    free(pts);
    lua_pushinteger(L, mvl_res_mesh_from_data(&eng(L)->res, "<ribbon>", &m));
    mvl_mesh_free(&m);
    return 1;
}

static int l_box_mesh(lua_State *L) {
    mvl_mesh m;
    char name[96];
    float sx = (float)luaL_checknumber(L, 1), sy = (float)luaL_checknumber(L, 2), sz = (float)luaL_checknumber(L, 3);
    mvl_mesh_init(&m);
    mvl_mesh_build_box(&m, sx, sy, sz);
    snprintf(name, sizeof name, "<box %g %g %g>", sx, sy, sz);
    lua_pushinteger(L, mvl_res_mesh_from_data(&eng(L)->res, name, &m));
    mvl_mesh_free(&m);
    return 1;
}

static int l_mesh_bounds(lua_State *L) {
    const mvl_mesh_res *m = mvl_res_get_mesh(&eng(L)->res, (int)luaL_checkinteger(L, 1));
    if (!m) return 0;
    for (int i = 0; i < 3; ++i) lua_pushnumber(L, m->min[i]);
    for (int i = 0; i < 3; ++i) lua_pushnumber(L, m->max[i]);
    return 6;
}

static int l_sound(lua_State *L) {
    lua_pushinteger(L, mvl_res_sound(&eng(L)->res, luaL_checkstring(L, 1)));
    return 1;
}

/* ------------------------------------------------------------ entities */
static int l_spawn(lua_State *L) {
    mvl_engine *e = eng(L);
    int h;
    mvl_entity *en;
    const char *kind;
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_getfield(L, 1, "kind");
    kind = lua_tostring(L, -1);
    h = mvl_scene_spawn(&e->scene, (kind && !strcmp(kind, "sprite")) ? MVL_ENT_SPRITE : MVL_ENT_MESH);
    lua_pop(L, 1);
    en = mvl_scene_get(&e->scene, h);
    if (!en) return luaL_error(L, "too many entities");
    apply_entity_fields(L, en, 1);
    lua_getfield(L, 1, "parent");
    if (lua_isinteger(L, -1) && !mvl_scene_attach(&e->scene, h, (int)lua_tointeger(L, -1))) {
        mvl_scene_destroy(&e->scene, h);
        return luaL_error(L, "invalid parent entity");
    }
    lua_pop(L, 1);
    lua_pushinteger(L, h);
    return 1;
}

static mvl_entity *check_entity(lua_State *L, int idx) {
    return mvl_scene_get(&eng(L)->scene, (int)luaL_checkinteger(L, idx));
}

static int l_set(lua_State *L) {
    mvl_entity *en = check_entity(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    if (en) apply_entity_fields(L, en, 2);
    lua_pushboolean(L, en != NULL);
    return 1;
}

static int l_set_pos(lua_State *L) {
    mvl_entity *en = check_entity(L, 1);
    if (en) en->pos = v3((float)luaL_checknumber(L, 2), (float)luaL_checknumber(L, 3), (float)luaL_checknumber(L, 4));
    return 0;
}

static int l_get_pos(lua_State *L) {
    mvl_entity *en = check_entity(L, 1);
    if (!en) return 0;
    lua_pushnumber(L, en->pos.x);
    lua_pushnumber(L, en->pos.y);
    lua_pushnumber(L, en->pos.z);
    return 3;
}

static int l_set_yaw(lua_State *L) {
    mvl_entity *en = check_entity(L, 1);
    if (en) en->yaw = (float)luaL_checknumber(L, 2);
    return 0;
}

static int l_get_yaw(lua_State *L) {
    mvl_entity *en = check_entity(L, 1);
    if (!en) return 0;
    lua_pushnumber(L, en->yaw);
    return 1;
}

static int l_set_visible(lua_State *L) {
    mvl_entity *en = check_entity(L, 1);
    if (en) set_flag(&en->flags, MVL_ENT_VISIBLE, lua_toboolean(L, 2));
    return 0;
}

static int l_set_color(lua_State *L) {
    mvl_entity *en = check_entity(L, 1);
    if (en) {
        en->color[0] = (float)luaL_checknumber(L, 2);
        en->color[1] = (float)luaL_checknumber(L, 3);
        en->color[2] = (float)luaL_checknumber(L, 4);
        en->color[3] = (float)luaL_optnumber(L, 5, 1.0);
    }
    return 0;
}

static int l_destroy(lua_State *L) {
    lua_pushboolean(L, mvl_scene_destroy(&eng(L)->scene, (int)luaL_checkinteger(L, 1)));
    return 1;
}

static int l_exists(lua_State *L) {
    lua_pushboolean(L, check_entity(L, 1) != NULL);
    return 1;
}

/* mvl.clear_scene() removes the world but keeps persistent entities;
 * mvl.clear_scene(true) removes everything. */
static int l_clear_scene(lua_State *L) {
    if (lua_toboolean(L, 1)) mvl_scene_clear(&eng(L)->scene);
    else mvl_scene_clear_world(&eng(L)->scene);
    return 0;
}

static int l_entity_count(lua_State *L) {
    lua_pushinteger(L, mvl_scene_count(&eng(L)->scene));
    return 1;
}

/* -------------------------------------------------------- world state */
static int l_light(lua_State *L) {
    mvl_engine *e = eng(L);
    int i = (int)luaL_checkinteger(L, 1);
    mvl_light *li;
    if (i < 0 || i >= MVL_MAX_LIGHTS) return luaL_error(L, "light index out of range");
    li = &e->scene.lights[i];
    if (lua_isnoneornil(L, 2)) {
        li->enabled = 0;
        return 0;
    }
    li->pos = v3((float)luaL_checknumber(L, 2), (float)luaL_checknumber(L, 3), (float)luaL_checknumber(L, 4));
    li->color[0] = (float)luaL_checknumber(L, 5);
    li->color[1] = (float)luaL_checknumber(L, 6);
    li->color[2] = (float)luaL_checknumber(L, 7);
    li->range = (float)luaL_optnumber(L, 8, 6.0);
    li->enabled = 1;
    return 0;
}

static int l_camera(lua_State *L) {
    mvl_camera *c = &eng(L)->scene.camera;
    if (lua_gettop(L) >= 3) {
        c->pos = v3((float)luaL_checknumber(L, 1), (float)luaL_checknumber(L, 2), (float)luaL_checknumber(L, 3));
        c->yaw = (float)luaL_optnumber(L, 4, c->yaw);
        c->pitch = (float)luaL_optnumber(L, 5, c->pitch);
        c->fov_deg = (float)luaL_optnumber(L, 6, c->fov_deg);
    }
    lua_pushnumber(L, c->pos.x);
    lua_pushnumber(L, c->pos.y);
    lua_pushnumber(L, c->pos.z);
    lua_pushnumber(L, c->yaw);
    lua_pushnumber(L, c->pitch);
    lua_pushnumber(L, c->fov_deg);
    return 6;
}

static int l_environment(lua_State *L) {
    mvl_environment *env = &eng(L)->scene.env;
    float v[3];
    luaL_checktype(L, 1, LUA_TTABLE);
    if (opt_field_bool(L, 1, "reset", 0)) mvl_env_default(env);
    read_vec(L, 1, "sky_top", env->sky_top, 3);
    read_vec(L, 1, "sky_horizon", env->sky_horizon, 3);
    read_vec(L, 1, "fog_color", env->fog_color, 3);
    read_vec(L, 1, "ambient", env->ambient, 3);
    read_vec(L, 1, "sun_color", env->sun_color, 3);
    v[0] = env->sun_dir.x; v[1] = env->sun_dir.y; v[2] = env->sun_dir.z;
    if (read_vec(L, 1, "sun_dir", v, 3)) env->sun_dir = v3_norm(v3(v[0], v[1], v[2]));
    env->fog_near = opt_field_num(L, 1, "fog_near", env->fog_near);
    env->fog_far = opt_field_num(L, 1, "fog_far", env->fog_far);
    env->stars = opt_field_num(L, 1, "stars", env->stars);
    return 0;
}

static int l_bounds(lua_State *L) {
    mvl_scene *s = &eng(L)->scene;
    s->bounds_min[0] = (float)luaL_checknumber(L, 1);
    s->bounds_min[1] = (float)luaL_checknumber(L, 2);
    s->bounds_max[0] = (float)luaL_checknumber(L, 3);
    s->bounds_max[1] = (float)luaL_checknumber(L, 4);
    return 0;
}

static int l_move(lua_State *L) {
    mvl_engine *e = eng(L);
    vec3 p = v3((float)luaL_checknumber(L, 1), (float)luaL_checknumber(L, 2), (float)luaL_checknumber(L, 3));
    vec3 d = v3((float)luaL_checknumber(L, 4), 0, (float)luaL_checknumber(L, 5));
    vec3 r = mvl_scene_move(&e->scene, p, d, (float)luaL_optnumber(L, 6, 0.3));
    lua_pushnumber(L, r.x);
    lua_pushnumber(L, r.y);
    lua_pushnumber(L, r.z);
    return 3;
}

static int l_overlaps(lua_State *L) {
    vec3 p = v3((float)luaL_checknumber(L, 1), (float)luaL_optnumber(L, 4, 0), (float)luaL_checknumber(L, 2));
    lua_pushboolean(L, mvl_scene_overlaps(&eng(L)->scene, p, (float)luaL_optnumber(L, 3, 0.3)));
    return 1;
}

/* --------------------------------------------------------------- input */
static int l_value(lua_State *L) {
    lua_pushnumber(L, mvl_input_value(&eng(L)->input, luaL_checkstring(L, 1)));
    return 1;
}
static int l_down(lua_State *L) {
    lua_pushboolean(L, mvl_input_down(&eng(L)->input, luaL_checkstring(L, 1)));
    return 1;
}
static int l_pressed(lua_State *L) {
    lua_pushboolean(L, mvl_input_pressed(&eng(L)->input, luaL_checkstring(L, 1)));
    return 1;
}
static int l_released(lua_State *L) {
    lua_pushboolean(L, mvl_input_released(&eng(L)->input, luaL_checkstring(L, 1)));
    return 1;
}
static int l_look(lua_State *L) {
    mvl_engine *e = eng(L);
    lua_pushnumber(L, e->input.look_dx);
    lua_pushnumber(L, e->input.look_dy);
    return 2;
}
static int l_touch(lua_State *L) {
    mvl_engine *e = eng(L);
    if (!lua_isnoneornil(L, 1)) {
        e->touch.enabled = lua_toboolean(L, 1);
        if (!e->touch.enabled) mvl_touch_cancel_all(&e->touch);
    }
    lua_pushboolean(L, e->touch.enabled);
    return 1;
}

/* --------------------------------------------------------------- audio */
static int l_play(lua_State *L) {
    mvl_engine *e = eng(L);
    const mvl_sound *s = mvl_res_get_sound(&e->res, (int)luaL_checkinteger(L, 1));
    int id = mvl_mixer_play(&e->mixer, s, (float)luaL_optnumber(L, 2, 1.0), (float)luaL_optnumber(L, 3, 0.0),
                            lua_toboolean(L, 4), (int)luaL_optinteger(L, 5, 0));
    lua_pushinteger(L, id);
    return 1;
}
static int l_stop(lua_State *L) {
    mvl_mixer_stop(&eng(L)->mixer, (int)luaL_checkinteger(L, 1));
    return 0;
}
static int l_stop_group(lua_State *L) {
    mvl_mixer_stop_group(&eng(L)->mixer, (int)luaL_checkinteger(L, 1));
    return 0;
}
static int l_fade(lua_State *L) {
    mvl_mixer_fade(&eng(L)->mixer, (int)luaL_checkinteger(L, 1), (float)luaL_checknumber(L, 2),
                   (float)luaL_optnumber(L, 3, 0.5), lua_toboolean(L, 4));
    return 0;
}
static int l_playing(lua_State *L) {
    lua_pushboolean(L, mvl_mixer_playing(&eng(L)->mixer, (int)luaL_checkinteger(L, 1)));
    return 1;
}
static int l_group_volume(lua_State *L) {
    mvl_engine *e = eng(L);
    int g = (int)luaL_checkinteger(L, 1);
    if (!lua_isnoneornil(L, 2)) mvl_mixer_set_group_volume(&e->mixer, g, (float)luaL_checknumber(L, 2));
    lua_pushnumber(L, (g >= 0 && g < MVL_MIX_GROUPS) ? e->mixer.group_volume[g] : 0.0);
    return 1;
}
static int l_sound_length(lua_State *L) {
    const mvl_sound *s = mvl_res_get_sound(&eng(L)->res, (int)luaL_checkinteger(L, 1));
    lua_pushnumber(L, s ? (double)s->frames / (double)s->rate : 0.0);
    return 1;
}

/* ------------------------------------------------------------------ UI */
static void color_args(lua_State *L, int first, float c[4]) {
    c[0] = (float)luaL_optnumber(L, first, 1);
    c[1] = (float)luaL_optnumber(L, first + 1, 1);
    c[2] = (float)luaL_optnumber(L, first + 2, 1);
    c[3] = (float)luaL_optnumber(L, first + 3, 1);
}
static int l_ui_size(lua_State *L) {
    mvl_engine *e = eng(L);
    float w, h;
    mvl_engine_ui_size(e, &w, &h);
    lua_pushnumber(L, w);
    lua_pushnumber(L, h);
    return 2;
}
static int l_rect(lua_State *L) {
    float c[4];
    color_args(L, 5, c);
    mvl_ui_rect(&eng(L)->ui, (float)luaL_checknumber(L, 1), (float)luaL_checknumber(L, 2), (float)luaL_checknumber(L, 3),
                (float)luaL_checknumber(L, 4), c);
    return 0;
}
static int l_image(lua_State *L) {
    float c[4];
    color_args(L, 10, c);
    mvl_ui_image(&eng(L)->ui, (int)luaL_checkinteger(L, 1), (float)luaL_checknumber(L, 2), (float)luaL_checknumber(L, 3),
                 (float)luaL_checknumber(L, 4), (float)luaL_checknumber(L, 5), (float)luaL_optnumber(L, 6, 0),
                 (float)luaL_optnumber(L, 7, 0), (float)luaL_optnumber(L, 8, 1), (float)luaL_optnumber(L, 9, 1), c);
    return 0;
}
static int l_text(lua_State *L) {
    float c[4];
    color_args(L, 5, c);
    lua_pushnumber(L, mvl_ui_text(&eng(L)->ui, (float)luaL_checknumber(L, 1), (float)luaL_checknumber(L, 2),
                                  luaL_checkstring(L, 3), (float)luaL_optnumber(L, 4, 1), c));
    return 1;
}
static int l_text_width(lua_State *L) {
    lua_pushnumber(L, mvl_ui_text_width(luaL_checkstring(L, 1), (float)luaL_optnumber(L, 2, 1)));
    return 1;
}
static int l_wrap(lua_State *L) {
    char buf[4096];
    mvl_ui_wrap(luaL_checkstring(L, 1), (float)luaL_checknumber(L, 2), (float)luaL_optnumber(L, 3, 1), buf, sizeof buf);
    lua_pushstring(L, buf);
    lua_pushinteger(L, mvl_ui_text_lines(buf));
    return 2;
}

/* --------------------------------------------------- config, save, files */
static int l_config(lua_State *L) {
    const char *v = mvl_kv_get(&eng(L)->config, luaL_checkstring(L, 1));
    if (v) lua_pushstring(L, v);
    else lua_pushvalue(L, 2);
    return 1;
}
static int l_save_get(lua_State *L) {
    const char *v = mvl_kv_get(&eng(L)->save, luaL_checkstring(L, 1));
    if (v) lua_pushstring(L, v);
    else lua_pushvalue(L, 2);
    return 1;
}
static int l_save_set(lua_State *L) {
    mvl_engine *e = eng(L);
    const char *k = luaL_checkstring(L, 1);
    if (lua_isnoneornil(L, 2)) mvl_kv_remove(&e->save, k);
    else mvl_kv_set(&e->save, k, luaL_tolstring(L, 2, NULL));
    return 0;
}
static int l_save_write(lua_State *L) {
    lua_pushboolean(L, mvl_engine_write_save(eng(L)));
    return 1;
}
static int l_save_clear(lua_State *L) {
    mvl_kv_clear(&eng(L)->save);
    mvl_engine_clear_records(eng(L));
    return 0;
}

/* ------------------------------------------------------------- records */
static const char *record_path(lua_State *L, char *out, size_t size) {
    const char *name = luaL_checkstring(L, 1);
    if (!mvl_engine_record_path(eng(L), name, out, size)) {
        if (!eng(L)->save_dir[0]) return NULL;
        luaL_error(L, "invalid record name '%s' (use letters, digits, _ - . and /)", name);
    }
    return out;
}

static int l_record_write(lua_State *L) {
    char path[MVL_PATH_MAX * 2], err[256];
    luaL_checktype(L, 2, LUA_TTABLE);
    if (!record_path(L, path, sizeof path)) {
        size_t size;
        unsigned char *data = mvl_record_encode(L, 2, &size, err, sizeof err); /* still report bad values */
        if (!data) return luaL_error(L, "record '%s': %s", lua_tostring(L, 1), err);
        free(data);
        lua_pushboolean(L, 0);
        lua_pushstring(L, "no save folder");
        return 2;
    }
    if (!mvl_record_save(L, 2, path, err, sizeof err)) {
        if (strncmp(err, "could not write", 15)) return luaL_error(L, "record '%s': %s", lua_tostring(L, 1), err);
        lua_pushboolean(L, 0);
        lua_pushstring(L, err);
        return 2;
    }
    eng(L)->save_sync_pending = 1;
    lua_pushboolean(L, 1);
    return 1;
}

static int l_record_read(lua_State *L) {
    char path[MVL_PATH_MAX * 2];
    int r;
    if (!record_path(L, path, sizeof path)) return 0;
    r = mvl_record_load(L, path);
    if (r > 0) return 1;
    lua_pushnil(L);
    lua_pushstring(L, r < 0 ? "damaged" : "missing");
    return 2;
}

static int l_record_delete(lua_State *L) {
    char path[MVL_PATH_MAX * 2], tmp[MVL_PATH_MAX * 2 + 8];
    int removed;
    if (!record_path(L, path, sizeof path)) return 0;
    snprintf(tmp, sizeof tmp, "%s.tmp", path);
    removed = mvl_remove_path(path);
    removed |= mvl_remove_path(tmp);
    eng(L)->save_sync_pending |= removed;
    lua_pushboolean(L, removed);
    return 1;
}

typedef struct {
    lua_State *L;
    const char *prefix;
    size_t prefix_len;
    int set; /* stack index of the name set */
} list_ctx;

static void list_entry(const char *rel, int is_dir, void *user) {
    list_ctx *c = (list_ctx *)user;
    size_t n = strlen(rel);
    char name[MVL_PATH_MAX];
    if (is_dir || n >= sizeof name) return;
    memcpy(name, rel, n + 1);
    for (char *p = name; *p; ++p)
        if (*p == '\\') *p = '/';
    if (n > 8 && !strcmp(name + n - 8, ".rec.tmp")) name[n - 8] = 0;
    else if (n > 4 && !strcmp(name + n - 4, ".rec")) name[n - 4] = 0;
    else return;
    if (strncmp(name, c->prefix, c->prefix_len)) return;
    lua_pushboolean(c->L, 1);
    lua_setfield(c->L, c->set, name);
}

static int cmp_str(const void *a, const void *b) { return strcmp(*(const char *const *)a, *(const char *const *)b); }

static int l_record_list(lua_State *L) {
    char dir[MVL_PATH_MAX];
    list_ctx c;
    const char **names;
    size_t n = 0;
    c.L = L;
    c.prefix = luaL_optlstring(L, 1, "", &c.prefix_len);
    lua_newtable(L); /* result */
    if (!eng(L)->save_dir[0]) return 1;
    lua_newtable(L); /* set of names (a record may exist as .rec and .rec.tmp) */
    c.set = lua_gettop(L);
    mvl_path_join(dir, sizeof dir, eng(L)->save_dir, "records");
    mvl_dir_walk(dir, list_entry, &c);
    lua_pushnil(L);
    while (lua_next(L, c.set)) {
        lua_pop(L, 1);
        ++n;
    }
    names = (const char **)malloc(sizeof *names * (n ? n : 1));
    if (!names) return luaL_error(L, "out of memory");
    n = 0;
    lua_pushnil(L);
    while (lua_next(L, c.set)) {
        lua_pop(L, 1);
        names[n++] = lua_tostring(L, -1); /* anchored by the set */
    }
    qsort(names, n, sizeof *names, cmp_str);
    for (size_t i = 0; i < n; ++i) {
        lua_pushstring(L, names[i]);
        lua_rawseti(L, c.set - 1, (lua_Integer)i + 1);
    }
    free(names);
    lua_pop(L, 1);
    return 1;
}
static int l_exists_file(lua_State *L) {
    lua_pushboolean(L, mvl_vfs_exists(&eng(L)->vfs, luaL_checkstring(L, 1)));
    return 1;
}
static int l_read(lua_State *L) {
    size_t n;
    char *d = mvl_vfs_read(&eng(L)->vfs, luaL_checkstring(L, 1), &n);
    if (!d) return 0;
    lua_pushlstring(L, d, n);
    free(d);
    return 1;
}
static int l_mods(lua_State *L) {
    mvl_engine *e = eng(L);
    lua_newtable(L);
    for (int i = 1; i < e->vfs.count; ++i) {
        lua_pushstring(L, e->vfs.roots[i].name);
        lua_rawseti(L, -2, i);
    }
    return 1;
}
static int load_chunk(lua_State *L, mvl_engine *e, int root, const char *path, const char *chunkname) {
    size_t n;
    char *src = root >= 0 ? mvl_vfs_read_root(&e->vfs, root, path, &n) : mvl_vfs_read(&e->vfs, path, &n);
    int r;
    if (!src) return -1;
    r = luaL_loadbuffer(L, src, n, chunkname);
    free(src);
    return r;
}
static int l_run_mod(lua_State *L) {
    mvl_engine *e = eng(L);
    int idx = (int)luaL_checkinteger(L, 1);
    char name[160];
    int r;
    if (idx < 1 || idx >= e->vfs.count) return luaL_error(L, "no such mod");
    snprintf(name, sizeof name, "@mods/%s/init.lua", e->vfs.roots[idx].name);
    r = load_chunk(L, e, idx, "init.lua", name);
    if (r < 0) return 0;
    if (r != LUA_OK) return lua_error(L);
    lua_call(L, 0, 1);
    return 1;
}

/* ----------------------------------------------------------------- misc */
static int l_log(lua_State *L) {
    MVL_INFO("[lua] %s", luaL_tolstring(L, 1, NULL));
    return 0;
}
static int l_time(lua_State *L) {
    lua_pushnumber(L, eng(L)->time);
    return 1;
}
static int l_ticks(lua_State *L) {
    lua_pushinteger(L, (lua_Integer)eng(L)->ticks);
    return 1;
}
/* Command line tool options (e.g. --bible ADDR --out FILE). */
static int l_option(lua_State *L) {
    const char *v = mvl_kv_get(&eng(L)->options, luaL_checkstring(L, 1));
    if (v) lua_pushstring(L, v);
    else lua_pushnil(L);
    return 1;
}
/* Writes text to the file named by a command line option: scripts can only
 * write where the person running the tool asked them to. */
static int l_write_option_file(lua_State *L) {
    size_t n;
    const char *path = mvl_kv_get(&eng(L)->options, luaL_checkstring(L, 1));
    const char *text = luaL_checklstring(L, 2, &n);
    lua_pushboolean(L, path && *path && mvl_file_write(path, text, n));
    return 1;
}
static int l_quit(lua_State *L) {
    eng(L)->quit_requested = 1;
    return 0;
}
static int l_platform(lua_State *L) {
    lua_pushstring(L, eng(L)->platform);
    return 1;
}
static int l_headless(lua_State *L) {
    lua_pushboolean(L, eng(L)->headless);
    return 1;
}
static int l_xr(lua_State *L) {
    mvl_engine *e = eng(L);
    lua_pushboolean(L, e->xr_supported);
    lua_pushboolean(L, e->xr_active);
    return 2;
}
static int l_xr_request(lua_State *L) {
    mvl_engine *e = eng(L);
    if (e->xr_supported && !e->xr_active) e->xr_requested = 1;
    lua_pushboolean(L, e->xr_requested);
    return 1;
}
static int l_xr_head(lua_State *L) {
    mvl_engine *e = eng(L);
    lua_pushnumber(L, e->xr_head_yaw);
    lua_pushnumber(L, e->xr_head_pitch);
    return 2;
}
static int l_testing(lua_State *L) {
    lua_pushboolean(L, eng(L)->test_mode);
    return 1;
}

static const luaL_Reg mvl_funcs[] = {
    {"texture", l_texture}, {"mesh", l_mesh}, {"plane_mesh", l_plane_mesh}, {"box_mesh", l_box_mesh}, {"ribbon_mesh", l_ribbon_mesh},
    {"mesh_bounds", l_mesh_bounds}, {"sound", l_sound},
    {"spawn", l_spawn}, {"set", l_set}, {"set_pos", l_set_pos}, {"get_pos", l_get_pos},
    {"set_yaw", l_set_yaw}, {"get_yaw", l_get_yaw}, {"set_visible", l_set_visible}, {"set_color", l_set_color},
    {"destroy", l_destroy}, {"exists", l_exists}, {"clear_scene", l_clear_scene}, {"entity_count", l_entity_count},
    {"light", l_light}, {"camera", l_camera}, {"environment", l_environment}, {"bounds", l_bounds},
    {"move", l_move}, {"overlaps", l_overlaps},
    {"value", l_value}, {"down", l_down}, {"pressed", l_pressed}, {"released", l_released}, {"look", l_look},
    {"touch", l_touch},
    {"play", l_play}, {"stop", l_stop}, {"stop_group", l_stop_group}, {"fade", l_fade}, {"playing", l_playing},
    {"group_volume", l_group_volume}, {"sound_length", l_sound_length},
    {"ui_size", l_ui_size}, {"rect", l_rect}, {"image", l_image}, {"text", l_text}, {"text_width", l_text_width},
    {"wrap", l_wrap},
    {"config", l_config}, {"save_get", l_save_get}, {"save_set", l_save_set}, {"save_write", l_save_write},
    {"save_clear", l_save_clear}, {"record_write", l_record_write}, {"record_read", l_record_read},
    {"record_delete", l_record_delete}, {"record_list", l_record_list}, {"file_exists", l_exists_file}, {"read", l_read}, {"mods", l_mods},
    {"run_mod", l_run_mod},
    {"log", l_log}, {"time", l_time}, {"ticks", l_ticks}, {"quit", l_quit}, {"platform", l_platform},
    {"headless", l_headless}, {"xr", l_xr}, {"xr_request", l_xr_request}, {"xr_head", l_xr_head},
    {"testing", l_testing}, {"option", l_option}, {"write_option_file", l_write_option_file},
    {NULL, NULL}};

/* --------------------------------------------- module loading via VFS */
static int vfs_searcher(lua_State *L) {
    mvl_engine *e = eng(L);
    const char *name = luaL_checkstring(L, 1);
    char path[MVL_PATH_MAX], chunk[MVL_PATH_MAX + 2];
    size_t o = 0;
    int r;
    o = (size_t)snprintf(path, sizeof path, "scripts/");
    for (const char *p = name; *p && o + 5 < sizeof path; ++p) path[o++] = *p == '.' ? '/' : *p;
    path[o] = 0;
    snprintf(path + o, sizeof path - o, ".lua");
    snprintf(chunk, sizeof chunk, "@%s", path);
    r = load_chunk(L, e, -1, path, chunk);
    if (r < 0) {
        lua_pushfstring(L, "no file '%s' in game data", path);
        return 1;
    }
    if (r != LUA_OK) return lua_error(L);
    lua_pushstring(L, path);
    return 2;
}

static int l_dofile(lua_State *L) {
    mvl_engine *e = eng(L);
    const char *path = luaL_checkstring(L, 1);
    char chunk[MVL_PATH_MAX + 2];
    int r;
    snprintf(chunk, sizeof chunk, "@%s", path);
    r = load_chunk(L, e, -1, path, chunk);
    if (r < 0) return luaL_error(L, "cannot open %s", path);
    if (r != LUA_OK) return lua_error(L);
    lua_call(L, 0, LUA_MULTRET);
    return lua_gettop(L) - 1;
}

static void sandbox(lua_State *L) {
    static const char *os_remove[] = {"execute", "exit", "remove", "rename", "tmpname", "getenv", "setlocale", NULL};
    lua_pushnil(L);
    lua_setglobal(L, "io");
    lua_pushnil(L);
    lua_setglobal(L, "loadfile");
    lua_getglobal(L, "os");
    for (int i = 0; os_remove[i]; ++i) {
        lua_pushnil(L);
        lua_setfield(L, -2, os_remove[i]);
    }
    lua_pop(L, 1);
    /* package: only our VFS searcher (plus preload) */
    lua_getglobal(L, "package");
    lua_pushstring(L, "");
    lua_setfield(L, -2, "path");
    lua_pushstring(L, "");
    lua_setfield(L, -2, "cpath");
    lua_newtable(L);
    lua_getfield(L, -2, "searchers");
    lua_rawgeti(L, -1, 1); /* preload searcher */
    lua_rawseti(L, -3, 1);
    lua_pop(L, 1);
    lua_pushcfunction(L, vfs_searcher);
    lua_rawseti(L, -2, 2);
    lua_setfield(L, -2, "searchers");
    lua_pop(L, 1);
    lua_pushcfunction(L, l_dofile);
    lua_setglobal(L, "dofile");
}

int mvl_script_run_string(mvl_engine *e, const char *code, const char *name) {
    lua_State *L = e->L;
    if (luaL_loadbuffer(L, code, strlen(code), name) != LUA_OK || pcall_tb(L, 0, 0) != LUA_OK) {
        report_error(e, name, lua_tostring(L, -1));
        lua_pop(L, 1);
        return 0;
    }
    return 1;
}

int mvl_script_init(mvl_engine *e) {
    lua_State *L = luaL_newstate();
    const char *main_script;
    char chunk[MVL_PATH_MAX + 2];
    int r;
    if (!L) {
        snprintf(e->last_error, sizeof e->last_error, "cannot create Lua state");
        return 0;
    }
    e->L = L;
    luaL_openlibs(L);
    lua_pushlightuserdata(L, e);
    lua_setfield(L, LUA_REGISTRYINDEX, ENGINE_KEY);
    sandbox(L);
    luaL_newlib(L, mvl_funcs);
    lua_pushstring(L, "0.1.0");
    lua_setfield(L, -2, "version");
    mvl_script_open_procedural(L);
    lua_setglobal(L, "mvl");
    lua_newtable(L);
    lua_setglobal(L, "game");

    main_script = mvl_kv_get_str(&e->config, "engine.main_script", "scripts/main.lua");
    snprintf(chunk, sizeof chunk, "@%s", main_script);
    r = load_chunk(L, e, -1, main_script, chunk);
    if (r < 0) {
        report_error(e, "init", "main script not found");
        snprintf(e->last_error, sizeof e->last_error, "main script '%s' not found", main_script);
        return 0;
    }
    if (r != LUA_OK || pcall_tb(L, 0, 0) != LUA_OK) {
        report_error(e, main_script, lua_tostring(L, -1));
        lua_pop(L, 1);
        return 0;
    }
    return 1;
}

void mvl_script_shutdown(mvl_engine *e) {
    if (!e->L) return;
    mvl_script_call(e, "shutdown", 0, 0);
    lua_close(e->L);
    e->L = NULL;
    e->test_thread = NULL;
}

int mvl_script_call(mvl_engine *e, const char *fn, int nargs, double arg) {
    lua_State *L = e->L;
    if (!L) return 0;
    lua_getglobal(L, "game");
    if (!lua_istable(L, -1)) {
        lua_pop(L, 1);
        return 1;
    }
    lua_getfield(L, -1, fn);
    lua_remove(L, -2);
    if (!lua_isfunction(L, -1)) {
        lua_pop(L, 1);
        return 1;
    }
    if (nargs) lua_pushnumber(L, arg);
    if (pcall_tb(L, nargs ? 1 : 0, 0) != LUA_OK) {
        char where[64];
        snprintf(where, sizeof where, "game.%s", fn);
        report_error(e, where, lua_tostring(L, -1));
        lua_pop(L, 1);
        return 0;
    }
    return 1;
}

/* ------------------------------------------------------- game tests */
static int t_input(lua_State *L) {
    mvl_input_set_external(&eng(L)->input, luaL_checkstring(L, 1), (float)luaL_optnumber(L, 2, 1.0));
    return 0;
}
static int t_look(lua_State *L) {
    mvl_input_add_look(&eng(L)->input, (float)luaL_checknumber(L, 1), (float)luaL_optnumber(L, 2, 0));
    return 0;
}
static int t_touch(lua_State *L) {
    mvl_engine *e = eng(L);
    const char *what = luaL_checkstring(L, 1);
    long long id = (long long)luaL_checkinteger(L, 2);
    if (!strcmp(what, "down")) mvl_touch_down(&e->touch, id, (float)luaL_checknumber(L, 3), (float)luaL_checknumber(L, 4));
    else if (!strcmp(what, "move")) mvl_touch_move(&e->touch, id, (float)luaL_checknumber(L, 3), (float)luaL_checknumber(L, 4));
    else mvl_touch_up(&e->touch, id);
    return 0;
}
static int t_ui_texts(lua_State *L) {
    /* Returns the number of UI quads drawn last frame (for smoke checks). */
    lua_pushinteger(L, eng(L)->ui.count);
    return 1;
}
static int t_set_xr(lua_State *L) {
    mvl_engine *e = eng(L);
    e->xr_supported = lua_toboolean(L, 1);
    e->xr_active = lua_toboolean(L, 2);
    e->xr_head_yaw = (float)luaL_optnumber(L, 3, 0);
    return 0;
}
/* Asks the platform to save a screenshot of the next rendered frame (ignored headless). */
static int t_screenshot(lua_State *L) {
    mvl_engine *e = eng(L);
    snprintf(e->screenshot_request, sizeof e->screenshot_request, "%s", luaL_checkstring(L, 1));
    return 0;
}

/* Active mixer voices, optionally only those of one group. */
static int t_mixer_voices(lua_State *L) {
    mvl_mixer *m = &eng(L)->mixer;
    if (lua_isnoneornil(L, 1)) lua_pushinteger(L, mvl_mixer_active_count(m));
    else {
        int g = (int)luaL_checkinteger(L, 1), n = 0;
        for (int i = 0; i < MVL_MAX_VOICES; ++i) n += m->voices[i].active && m->voices[i].group == g;
        lua_pushinteger(L, n);
    }
    return 1;
}

/* Reads a file of the test's own folder tree (e.g. a tool's manifest). */
static int t_read_file(lua_State *L) {
    size_t n;
    char *data = mvl_file_read(luaL_checkstring(L, 1), &n);
    if (!data) return 0;
    lua_pushlstring(L, data, n);
    free(data);
    return 1;
}

static int t_voice_volume(lua_State *L) {
    lua_pushnumber(L, mvl_mixer_volume(&eng(L)->mixer, (int)luaL_checkinteger(L, 1)));
    return 1;
}

static const char *TEST_PRELUDE =
    "local t = ...\n"
    "function t.wait(n) coroutine.yield(n or 1) end\n"
    "function t.seconds(s) coroutine.yield(math.max(1, math.floor(s * 60 + 0.5))) end\n"
    "function t.hold(action, frames, value) t.input(action, value or 1); t.wait(frames or 1); t.input(action, 0) end\n"
    "function t.press(action) t.hold(action, 2); t.wait(1) end\n"
    "function t.expect(cond, msg) if not cond then error('expectation failed: ' .. tostring(msg), 2) end end\n"
    "function t.eq(a, b, msg) if a ~= b then error(string.format('%s: expected %s, got %s', msg or 'eq', tostring(b), tostring(a)), 2) end end\n"
    "function t.until_true(fn, max_frames, msg) for i = 1, max_frames or 600 do if fn() then return i end; t.wait(1) end; error('timed out: ' .. tostring(msg), 2) end\n";

int mvl_script_load_test(mvl_engine *e, const char *path) {
    lua_State *L = e->L;
    size_t n;
    char *src = mvl_file_read(path, &n);
    char chunk[MVL_PATH_MAX + 2];
    static const luaL_Reg tfuncs[] = {{"input", t_input}, {"look", t_look}, {"touch", t_touch},
                                      {"ui_quads", t_ui_texts}, {"set_xr", t_set_xr},
                                      {"mixer_voices", t_mixer_voices}, {"voice_volume", t_voice_volume}, {"read_file", t_read_file},
                                      {"screenshot", t_screenshot}, {NULL, NULL}};
    if (!src) {
        snprintf(e->last_error, sizeof e->last_error, "test script '%s' not found", path);
        return 0;
    }
    luaL_newlib(L, tfuncs);
    if (luaL_loadstring(L, TEST_PRELUDE) != LUA_OK) {
        free(src);
        return 0;
    }
    lua_pushvalue(L, -2);
    lua_call(L, 1, 0);
    lua_setglobal(L, "test");
    {
        /* optional shared helpers next to the test file */
        char dir[MVL_PATH_MAX], helpers[MVL_PATH_MAX + 16];
        size_t hn;
        char *hsrc;
        mvl_path_dirname(dir, sizeof dir, path);
        mvl_path_join(helpers, sizeof helpers, dir, "helpers.lua");
        hsrc = mvl_file_read(helpers, &hn);
        if (hsrc) {
            int ok = luaL_loadbuffer(L, hsrc, hn, "@helpers.lua") == LUA_OK && pcall_tb(L, 0, 0) == LUA_OK;
            free(hsrc);
            if (!ok) {
                report_error(e, "test helpers", lua_tostring(L, -1));
                lua_pop(L, 1);
                free(src);
                return 0;
            }
        }
    }
    snprintf(chunk, sizeof chunk, "@%s", path);
    if (luaL_loadbuffer(L, src, n, chunk) != LUA_OK) {
        report_error(e, "test", lua_tostring(L, -1));
        lua_pop(L, 1);
        free(src);
        return 0;
    }
    free(src);
    e->test_thread = lua_newthread(L);
    lua_insert(L, -2);
    lua_xmove(L, e->test_thread, 1); /* move function onto the thread */
    e->test_ref = luaL_ref(L, LUA_REGISTRYINDEX); /* keep thread alive */
    e->test_wait = 0;
    return 1;
}

void mvl_script_step_test(mvl_engine *e) {
    int nres = 0, r;
    if (!e->test_thread || e->test_done) return;
    if (e->test_wait > 0) {
        e->test_wait--;
        return;
    }
    r = lua_resume(e->test_thread, e->L, 0, &nres);
    if (r == LUA_YIELD) {
        e->test_wait = nres > 0 ? (int)lua_tointeger(e->test_thread, -1) - 1 : 0;
        lua_pop(e->test_thread, nres);
        return;
    }
    e->test_done = 1;
    if (r != LUA_OK) {
        const char *msg = lua_tostring(e->test_thread, -1);
        luaL_traceback(e->L, e->test_thread, msg, 0);
        report_error(e, "test", lua_tostring(e->L, -1));
        lua_pop(e->L, 1);
        e->test_failed = 1;
    } else if (!e->test_failed) {
        MVL_INFO("test passed after %lu ticks", e->ticks);
    }
}
