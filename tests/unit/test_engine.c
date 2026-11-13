/* Unit tests: engine loop and the Lua API (script.c). MIT License. */
#include "test.h"
#include "core/engine.h"
#include <stdlib.h>

static int resolve(const char *name, void *user) { return name[0] == 'Z' ? -1 : (int)(unsigned char)name[0]; }

static void write_base(const char *dir, const char *main_lua) {
    char p[600];
    unsigned char tga[22] = {0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 32, 0x28, 255, 255, 255, 255};
    unsigned char wav[48] = {'R', 'I', 'F', 'F', 0, 0, 0, 0, 'W', 'A', 'V', 'E', 'f', 'm', 't', ' ', 16, 0, 0, 0, 1, 0, 1, 0,
                             0x44, 0xAC, 0, 0, 0, 0, 0, 0, 2, 0, 16, 0, 'd', 'a', 't', 'a', 4, 0, 0, 0, 1, 0, 2, 0};
    snprintf(p, sizeof p, "%s/scripts/main.lua", dir);
    tmp_write(p, main_lua, strlen(main_lua));
    snprintf(p, sizeof p, "%s/textures/font.tga", dir);
    tmp_write(p, tga, sizeof tga);
    snprintf(p, sizeof p, "%s/textures/ui.tga", dir);
    tmp_write(p, tga, sizeof tga);
    snprintf(p, sizeof p, "%s/sounds/s.wav", dir);
    tmp_write(p, wav, sizeof wav);
    snprintf(p, sizeof p, "%s/models/tri.obj", dir);
    tmp_write(p, "v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n", 32);
    snprintf(p, sizeof p, "%s/scripts/lib/mod.lua", dir);
    tmp_write(p, "return { value = 42 }\n", 22);
    snprintf(p, sizeof p, "%s/scripts/lib/broken.lua", dir);
    tmp_write(p, "return {", 8);
    snprintf(p, sizeof p, "%s/config/input.ini", dir);
    tmp_write(p, "interact = E, Zbad\nmove_y = W\n", 30);
    snprintf(p, sizeof p, "%s/config/engine.ini", dir);
    tmp_write(p, "[ui]\nheight = 100\n[save]\nfile = s.ini\n", 37);
    snprintf(p, sizeof p, "%s/data.txt", dir);
    tmp_write(p, "hello", 5);
}

static mvl_engine_desc desc_for(const char *name, char *data, char *save, char *mods) {
    mvl_engine_desc d;
    memset(&d, 0, sizeof d);
    tmp_path(data, 512, name);
    d.data_dir = data;
    if (save) {
        snprintf(save, 512, "%s_save", data);
        tmp_write("x", "", 0);
        {
            char marker[600];
            snprintf(marker, sizeof marker, "%s_save/.keep", name);
            tmp_write(marker, "", 0);
        }
        d.save_dir = save;
    }
    if (mods) {
        snprintf(mods, 512, "%s_mods", data);
        d.mods_dir = mods;
    }
    d.platform = "test";
    d.gfx = mvl_gfx_null_backend();
    d.key_resolver = resolve;
    d.headless = 1;
    d.aspect = 2.0f;
    return d;
}

static const char *API_SCRIPT =
    "local m = require('lib.mod')\n"
    "assert(m.value == 42)\n"
    "assert(not pcall(require, 'lib.broken'))\n"
    "assert(not pcall(require, 'lib.missing'))\n"
    "assert(io == nil and os.execute == nil and loadfile == nil)\n"
    "assert(dofile('scripts/lib/mod.lua').value == 42)\n"
    "assert(not pcall(dofile, 'nope.lua'))\n"
    "assert(not pcall(dofile, 'scripts/lib/broken.lua'))\n"
    "calls = {}\n"
    "function game.init()\n"
    "  local t = mvl.texture('textures/font.tga'); assert(t > 0)\n"
    "  local me = mvl.mesh('models/tri.obj'); assert(me > 0)\n"
    "  assert(mvl.mesh('voxels/none.vox', 0.5) == 0)\n"
    "  local pl = mvl.plane_mesh(2, 2); local bx = mvl.box_mesh(1, 2, 3)\n"
    "  local x0, y0, z0, x1, y1, z1 = mvl.mesh_bounds(bx); assert(y1 == 2)\n"
    "  assert(mvl.mesh_bounds(999) == nil)\n"
    "  local snd = mvl.sound('sounds/s.wav'); assert(snd > 0)\n"
    "  assert(mvl.sound_length(snd) > 0 and mvl.sound_length(999) == 0)\n"
    "  local e = mvl.spawn{ mesh = me, texture = t, pos = {1, 2, 3}, scale = 2, color = {1, 0, 0, 0.5}, uv_scroll = {1, 2},\n"
    "    yaw = 1, pitch = 0.1, roll = 0.2, radius = 0.5, box = {2, 4}, visible = true, unlit = true, nofog = true, solid = true }\n"
    "  local s = mvl.spawn{ kind = 'sprite', texture = t }\n"
    "  assert(mvl.exists(e) and mvl.entity_count() == 2)\n"
    "  assert(mvl.set(e, { pos = {4, 5, 6} }))\n"
    "  local x, y, z = mvl.get_pos(e); assert(x == 4)\n"
    "  mvl.set_pos(e, 7, 8, 9); assert(select(1, mvl.get_pos(e)) == 7)\n"
    "  mvl.set_yaw(e, 2); assert(mvl.get_yaw(e) == 2)\n"
    "  mvl.set_visible(e, false); mvl.set_color(e, 1, 1, 1)\n"
    "  assert(mvl.destroy(s) and not mvl.destroy(s))\n"
    "  assert(not mvl.set(s, {}) and mvl.get_pos(s) == nil and mvl.get_yaw(s) == nil)\n"
    "  mvl.set_pos(s, 1, 1, 1); mvl.set_yaw(s, 1); mvl.set_visible(s, true); mvl.set_color(s, 1, 1, 1)\n"
    "  mvl.light(0, 1, 2, 3, 1, 1, 1, 5); mvl.light(0)\n"
    "  assert(not pcall(mvl.light, 99))\n"
    "  local cx = mvl.camera(1, 2, 3, 0.5, 0.1, 80); assert(cx == 1)\n"
    "  assert(select(6, mvl.camera()) == 80)\n"
    "  mvl.environment{ reset = true, sky_top = {1, 1, 1}, sun_dir = {0, -1, 0}, fog_near = 3, fog_far = 9, stars = 0.5 }\n"
    "  mvl.environment{ ambient = 0.5 }\n"
    "  mvl.bounds(-5, -5, 5, 5)\n"
    "  local nx, ny, nz = mvl.move(0, 0, 0, 100, 0, 0.5); assert(nx == 4.5)\n"
    "  assert(mvl.overlaps(7, 9, 0.6) and not mvl.overlaps(-3, -3))\n"
    "  assert(mvl.value('nothing') == 0 and not mvl.down('x') and not mvl.pressed('x') and not mvl.released('x'))\n"
    "  local lx, ly = mvl.look(); assert(lx == 0)\n"
    "  assert(mvl.touch(true) and not mvl.touch(false) and not mvl.touch())\n"
    "  local v = mvl.play(snd, 1, 0, true, 1); assert(mvl.playing(v))\n"
    "  mvl.fade(v, 0.5, 0.1); mvl.stop(v); mvl.stop_group(1)\n"
    "  assert(mvl.group_volume(1, 0.5) == 0.5 and mvl.group_volume(9) == 0)\n"
    "  local w, h = mvl.ui_size(); assert(h == 200 and w == 400, w .. 'x' .. h)\n"
    "  assert(mvl.config('ui.height') == '100' and mvl.config('nope', 'd') == 'd')\n"
    "  mvl.save_set('a', 1); mvl.save_set('b', 'x'); mvl.save_set('b', nil)\n"
    "  assert(mvl.save_get('a') == '1' and mvl.save_get('b', 'z') == 'z')\n"
    "  assert(mvl.save_write())\n"
    "  assert(mvl.file_exists('data.txt') and not mvl.file_exists('nope'))\n"
    "  assert(mvl.read('data.txt') == 'hello' and mvl.read('nope') == nil)\n"
    "  assert(mvl.platform() == 'test' and mvl.headless() and not mvl.testing())\n"
    "  local sup, act = mvl.xr(); assert(not sup and not act)\n"
    "  assert(not mvl.xr_request()); assert(mvl.xr_head() == 0)\n"
    "  assert(mvl.version == '0.1.0')\n"
    "  mvl.log('hello'); assert(mvl.time() == 0 and mvl.ticks() == 0)\n"
    "  local s2, n = mvl.wrap('hello world', 30); assert(n == 2)\n"
    "  mvl.clear_scene(); assert(mvl.entity_count() == 0)\n"
    "  assert(not pcall(mvl.spawn, 5))\n"
    "end\n"
    "function game.update(dt) calls.update = (calls.update or 0) + 1\n"
    "  if mvl.ticks() == 3 then mvl.save_clear() end end\n"
    "function game.draw_ui()\n"
    "  mvl.rect(0, 0, 1, 1); mvl.image(1, 0, 0, 1, 1); mvl.text(0, 0, 'x', 1, 1, 1, 1, 1); assert(mvl.text_width('ab') == 12)\n"
    "  if mvl.ticks() >= 10 then mvl.quit() end end\n"
    "function game.shutdown() end\n";

void test_engine_api(void) {
    static mvl_engine e;
    char data[512], save[512];
    mvl_engine_desc d = desc_for("eng_api", data, save, NULL);
    write_base(data, API_SCRIPT);
    CHECK(mvl_engine_init(&e, &d));
    CHECK_EQ_INT(e.script_errors, 0);
    CHECK(e.input.action_count >= 2);
    CHECK_EQ_INT(mvl_engine_run_headless(&e, 100), 0);
    CHECK(e.quit_requested);
    CHECK_EQ_INT(e.ticks, 10);
    {
        float w, h;
        mvl_engine_set_aspect(&e, 0); /* ignored */
        mvl_engine_set_aspect(&e, 1.0f);
        mvl_engine_ui_size(&e, &w, &h);
        CHECK_NEAR(w, 400, 1e-6); /* minimum width keeps menus usable */
        CHECK_NEAR(h, 400, 1e-6);
        mvl_engine_set_aspect(&e, 8.0f);
        mvl_engine_ui_size(&e, &w, &h);
        CHECK_NEAR(h, 120, 1e-6); /* configured 100 is raised to the 120 minimum */
    }
    /* touch controls drawn when enabled */
    e.touch.enabled = 1;
    e.quit_requested = 0;
    mvl_engine_frame(&e, 1.0 / 60.0);
    CHECK(e.ui.count > 5);
    mvl_touch_down(&e.touch, 1, 0.1f, 0.8f);
    mvl_touch_down(&e.touch, 2, 0.9f, 0.78f);
    mvl_engine_frame(&e, 1.0 / 60.0);
    mvl_engine_frame(&e, -1.0); /* negative dt clamped */
    mvl_engine_frame(&e, 5.0);  /* long stall clamped */
    e.xr_active = 1;
    mvl_engine_frame(&e, 0);
    mvl_engine_shutdown(&e);
    mvl_engine_shutdown(&e); /* idempotent for the script part */
}

void test_engine_errors(void) {
    static mvl_engine e;
    char data[512];
    mvl_engine_desc d;
    /* missing data dir */
    memset(&d, 0, sizeof d);
    d.gfx = mvl_gfx_null_backend();
    CHECK(!mvl_engine_init(&e, &d));
    mvl_engine_shutdown(&e);
    /* main script missing */
    d = desc_for("eng_nomain", data, NULL, NULL);
    tmp_write("eng_nomain/readme.txt", "x", 1);
    CHECK(!mvl_engine_init(&e, &d));
    CHECK(strstr(e.last_error, "not found") != NULL);
    mvl_engine_shutdown(&e);
    /* syntax error */
    d = desc_for("eng_syntax", data, NULL, NULL);
    write_base(data, "this is not lua");
    CHECK(!mvl_engine_init(&e, &d));
    mvl_engine_shutdown(&e);
    /* runtime errors in callbacks are reported but do not stop the engine */
    d = desc_for("eng_runtime", data, NULL, NULL);
    write_base(data, "function game.update() error('boom') end\nfunction game.draw_ui() local x = nil; return x.y end\n");
    CHECK(mvl_engine_init(&e, &d));
    CHECK_EQ_INT(mvl_engine_run_headless(&e, 3), 1);
    CHECK(e.script_errors >= 6);
    CHECK(strstr(e.last_error, "game.") != NULL);
    CHECK(!mvl_script_run_string(&e, "error('x')", "=chunk"));
    CHECK(!mvl_script_run_string(&e, "+++", "=chunk"));
    CHECK(mvl_script_run_string(&e, "game = 5", "=chunk"));
    CHECK(mvl_script_call(&e, "update", 1, 0.1)); /* game is not a table: ignored */
    CHECK(!mvl_engine_write_save(&e));            /* no save dir */
    mvl_engine_shutdown(&e);
    CHECK(!mvl_script_call(&e, "update", 0, 0));  /* no Lua state */
    /* init error */
    d = desc_for("eng_initerr", data, NULL, NULL);
    write_base(data, "function game.init() error('nope') end\n");
    CHECK(!mvl_engine_init(&e, &d));
    mvl_engine_shutdown(&e);
}

void test_engine_save_and_mods(void) {
    static mvl_engine e;
    char data[512], save[512], mods[512], p[700];
    mvl_engine_desc d = desc_for("eng_save", data, save, mods);
    write_base(data, "function game.init() mvl.save_set('n', (tonumber(mvl.save_get('n', '0')) + 1)) mvl.save_write()\n"
                     "  local list = mvl.mods(); assert(#list == 1 and list[1] == 'm1')\n"
                     "  assert(mvl.run_mod(1) == 'mod-ok')\n"
                     "  assert(not pcall(mvl.run_mod, 5)) end\n");
    snprintf(p, sizeof p, "%s/s.ini", save);
    tmp_write(p, "", 0); /* start without a save from earlier runs */
    snprintf(p, sizeof p, "%s/mods.txt", mods);
    tmp_write(p, "m1\n", 3);
    snprintf(p, sizeof p, "%s/m1/init.lua", mods);
    tmp_write(p, "return 'mod-ok'", 15);
    CHECK(mvl_engine_init(&e, &d));
    CHECK_EQ_INT(e.script_errors, 0);
    mvl_engine_shutdown(&e);
    CHECK(mvl_engine_init(&e, &d));
    CHECK_STR(mvl_kv_get(&e.save, "n"), "2");
    mvl_engine_shutdown(&e);
    /* a broken mod reports its error */
    snprintf(p, sizeof p, "%s/m1/init.lua", mods);
    tmp_write(p, "return {", 8);
    write_base(data, "function game.init() assert(not pcall(mvl.run_mod, 1)) end\n");
    CHECK(mvl_engine_init(&e, &d));
    mvl_engine_shutdown(&e);
    /* a mod without init.lua returns nothing */
    snprintf(p, sizeof p, "%s/mods.txt", mods);
    tmp_write(p, "m2\n", 3);
    snprintf(p, sizeof p, "%s/m2/x.txt", mods);
    tmp_write(p, "x", 1);
    write_base(data, "function game.init() assert(mvl.run_mod(1) == nil) end\n");
    CHECK(mvl_engine_init(&e, &d));
    CHECK_EQ_INT(e.script_errors, 0);
    mvl_engine_shutdown(&e);
    /* unwritable save location */
    d.save_dir = "/nonexistent/dir";
    write_base(data, "function game.init() assert(not mvl.save_write()) end\n");
    CHECK(mvl_engine_init(&e, &d));
    CHECK_EQ_INT(e.script_errors, 0);
    mvl_engine_shutdown(&e);
}

static int g_saved;
static void on_save(void *u) { g_saved++; }

static void run_test_script(const char *name, const char *test_lua, int expect_rc, int frames) {
    static mvl_engine e;
    char data[512], tp[600];
    mvl_engine_desc d = desc_for(name, data, NULL, NULL);
    write_base(data, "function game.update() end\n");
    snprintf(tp, sizeof tp, "%s_test/test.lua", name);
    tmp_write(tp, test_lua, strlen(test_lua));
    tmp_path(tp, sizeof tp, name);
    strcat(tp, "_test/test.lua");
    d.test_script = tp;
    CHECK(mvl_engine_init(&e, &d));
    e.on_save = on_save;
    CHECK_EQ_INT(mvl_engine_run_headless(&e, frames), expect_rc);
    mvl_engine_shutdown(&e);
}

void test_engine_test_runner(void) {
    run_test_script("tr_pass",
                    "test.wait(2); test.seconds(0.05); test.hold('interact', 2); test.press('move_y')\n"
                    "test.look(0.1, 0.2); test.touch('down', 1, 0.1, 0.5); test.touch('move', 1, 0.1, 0.4); test.touch('up', 1)\n"
                    "test.set_xr(true, true, 0.5); local s, a = mvl.xr(); test.expect(s and a, 'xr flags')\n"
                    "test.eq(test.mixer_voices(), 0, 'no voices'); test.expect(test.ui_quads() >= 0)\n"
                    "test.until_true(function() return mvl.ticks() > 10 end, 50, 'ticks')\n"
                    "test.expect(mvl.testing(), 'test mode')\n",
                    0, 600);
    run_test_script("tr_fail", "test.wait(1); test.eq(1, 2, 'numbers')\n", 1, 600);
    run_test_script("tr_expect", "test.expect(false, 'nope')\n", 1, 600);
    run_test_script("tr_timeout", "test.until_true(function() return false end, 5, 'never')\n", 1, 600);
    run_test_script("tr_unfinished", "test.wait(1000)\n", 1, 10);
    {
        static mvl_engine e;
        char data[512], tp[600];
        mvl_engine_desc d = desc_for("tr_missing", data, NULL, NULL);
        write_base(data, "\n");
        tmp_path(tp, sizeof tp, "tr_missing_none.lua");
        d.test_script = tp;
        CHECK(!mvl_engine_init(&e, &d));
        mvl_engine_shutdown(&e);
        d = desc_for("tr_syntax", data, NULL, NULL);
        write_base(data, "\n");
        tmp_write("tr_syntax_test/test.lua", "+++", 3);
        tmp_path(tp, sizeof tp, "tr_syntax_test/test.lua");
        d.test_script = tp;
        CHECK(!mvl_engine_init(&e, &d));
        mvl_engine_shutdown(&e);
        /* shared helpers next to the test are loaded; broken helpers fail */
        d = desc_for("tr_helpers", data, NULL, NULL);
        write_base(data, "\n");
        tmp_write("tr_helpers_test/helpers.lua", "HELPER = 7", 10);
        tmp_write("tr_helpers_test/test.lua", "test.eq(HELPER, 7, 'helper')", 28);
        tmp_path(tp, sizeof tp, "tr_helpers_test/test.lua");
        d.test_script = tp;
        CHECK(mvl_engine_init(&e, &d));
        CHECK_EQ_INT(mvl_engine_run_headless(&e, 10), 0);
        mvl_engine_shutdown(&e);
        tmp_write("tr_helpers_test/helpers.lua", "error('bad helper')", 19);
        CHECK(!mvl_engine_init(&e, &d));
        mvl_engine_shutdown(&e);
    }
}
