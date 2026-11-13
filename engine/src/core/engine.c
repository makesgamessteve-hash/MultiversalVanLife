/* Multiversal Van Life - engine core. MIT License. */
#include "core/engine.h"
#include "core/log.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void draw_touch_controls(mvl_engine *e);

void mvl_engine_ui_size(const mvl_engine *e, float *w, float *h) {
    float uh = (float)mvl_kv_get_int(&e->config, "ui.height", 240);
    float min_w = (float)mvl_kv_get_int(&e->config, "ui.min_width", 400);
    float aspect = e->aspect > 0 ? e->aspect : 16.0f / 9.0f;
    if (uh < 120) uh = 120;
    /* portrait screens (phones): grow the canvas so menus still fit */
    if (uh * aspect < min_w) uh = min_w / aspect;
    *h = (float)(int)(uh + 0.5f);
    *w = (float)(int)(*h * aspect + 0.5f);
}

void mvl_engine_set_aspect(mvl_engine *e, float aspect) {
    if (aspect <= 0.0f) return;
    e->aspect = aspect;
    mvl_touch_set_aspect(&e->touch, aspect);
}

static void load_save(mvl_engine *e, const char *save_dir) {
    char *text;
    mvl_kv_init(&e->save);
    e->save_path[0] = 0;
    if (!save_dir || !*save_dir) return;
    mvl_path_join(e->save_path, sizeof e->save_path, save_dir,
                  mvl_kv_get_str(&e->config, "save.file", "savegame.ini"));
    text = mvl_file_read(e->save_path, NULL);
    if (text) {
        mvl_kv_parse(&e->save, text);
        free(text);
    }
}

int mvl_engine_write_save(mvl_engine *e) {
    size_t len;
    char *text;
    int ok;
    if (!e->save_path[0]) return 0;
    text = mvl_kv_serialize(&e->save, &len);
    if (!text) return 0;
    ok = mvl_file_write(e->save_path, text, len);
    free(text);
    if (!ok) MVL_WARN("could not write save file %s", e->save_path);
    if (ok && e->on_save) e->on_save(e->on_save_user);
    return ok;
}

int mvl_engine_init(mvl_engine *e, const mvl_engine_desc *d) {
    char *text;
    memset(e, 0, sizeof *e);
    snprintf(e->platform, sizeof e->platform, "%s", d->platform ? d->platform : "unknown");
    e->headless = d->headless;
    e->aspect = d->aspect > 0 ? d->aspect : 16.0f / 9.0f;
    e->fixed_dt = 1.0f / 60.0f;
    e->test_ref = -1;

    mvl_vfs_init(&e->vfs);
    if (!d->data_dir || mvl_vfs_add_root(&e->vfs, d->data_dir, "base") < 0) {
        snprintf(e->last_error, sizeof e->last_error, "invalid data directory");
        return 0;
    }
    if (d->mods_dir) mvl_vfs_add_mods(&e->vfs, d->mods_dir);

    mvl_kv_init(&e->config);
    text = mvl_vfs_read(&e->vfs, "config/engine.ini", NULL);
    if (text) {
        mvl_kv_parse(&e->config, text);
        free(text);
    }
    e->fixed_dt = 1.0f / (float)mvl_kv_get_int(&e->config, "engine.tick_rate", 60);

    mvl_res_init(&e->res, &e->vfs, d->gfx);
    mvl_scene_init(&e->scene);
    mvl_ui_init(&e->ui);
    e->ui.font_texture = mvl_res_texture(&e->res, mvl_kv_get_str(&e->config, "ui.font", "textures/font.tga"));
    mvl_mixer_init(&e->mixer, d->audio_rate > 0 ? d->audio_rate : 44100);
    mvl_touch_init(&e->touch, e->aspect);

    mvl_input_init(&e->input);
    e->input.mouse_sensitivity = mvl_kv_get_float(&e->config, "input.mouse_sensitivity", 0.0025f);
    text = mvl_vfs_read(&e->vfs, "config/input.ini", NULL);
    if (text) {
        mvl_input_load_bindings(&e->input, text, d->key_resolver, d->key_resolver_user);
        free(text);
    }
    /* actions the touch layer drives always exist */
    mvl_input_add_action(&e->input, "move_x");
    mvl_input_add_action(&e->input, "move_y");

    load_save(e, d->save_dir);

    if (!mvl_script_init(e)) return 0;
    if (d->test_script) {
        e->test_mode = 1;
        if (!mvl_script_load_test(e, d->test_script)) return 0;
    }
    if (!mvl_script_call(e, "init", 0, 0)) return 0;
    return 1;
}

void mvl_engine_shutdown(mvl_engine *e) {
    mvl_script_shutdown(e);
    mvl_mixer_stop_all(&e->mixer);
    mvl_res_shutdown(&e->res);
    mvl_kv_free(&e->config);
    mvl_kv_free(&e->save);
}

void mvl_engine_frame(mvl_engine *e, double dt) {
    float w, h;
    int steps = 0;
    if (dt < 0) dt = 0;
    if (dt > 0.25) dt = 0.25; /* avoid spiral of death after stalls */
    e->accumulator += dt;
    mvl_touch_apply(&e->touch, &e->input);
    mvl_input_update(&e->input);
    while (e->accumulator + 1e-6 >= e->fixed_dt && steps < 8) {
        if (e->test_mode && !e->test_done) mvl_script_step_test(e);
        mvl_input_update(&e->input);
        mvl_script_call(e, "update", 1, e->fixed_dt);
        mvl_input_end_frame(&e->input);
        e->accumulator -= e->fixed_dt;
        e->time += e->fixed_dt;
        e->ticks++;
        steps++;
    }
    if (steps == 8) e->accumulator = 0;
    e->alpha = (float)(e->accumulator / e->fixed_dt);
    mvl_engine_ui_size(e, &w, &h);
    mvl_ui_begin(&e->ui, w, h);
    mvl_script_call(e, "draw_ui", 0, 0);
    draw_touch_controls(e);
    e->frame++;
}

static void draw_touch_controls(mvl_engine *e) {
    mvl_touch *t = &e->touch;
    mvl_ui *ui = &e->ui;
    float s = ui->height; /* layout units -> ui pixels */
    int tex;
    const float base[4] = {1, 1, 1, 0.3f}, ring[4] = {1, 1, 1, 0.75f}, knob[4] = {1, 0.9f, 0.7f, 0.8f};
    const float btn[4] = {1, 1, 1, 0.55f}, held[4] = {1, 0.75f, 0.3f, 0.85f}, label[4] = {0.05f, 0.05f, 0.12f, 1};
    float cx, cy;
    if (!t->enabled || e->xr_active) return;
    mvl_touch_stick_home(t, &cx, &cy);
    cx *= s;
    cy *= s;
    tex = mvl_res_texture(&e->res, mvl_kv_get_str(&e->config, "ui.touch_atlas", "textures/ui.tga"));
    if (t->stick_active) {
        cx = t->stick_cx * s;
        cy = t->stick_cy * s;
    }
    {
        float r = mvl_touch_stick_radius(t) * s, kr = r * 0.45f;
        float kx = t->stick_active ? t->stick_x * s : cx, ky = t->stick_active ? t->stick_y * s : cy;
        mvl_ui_image(ui, tex, cx - r, cy - r, r * 2, r * 2, 0, 0, 0.5f, 0.5f, base);
        mvl_ui_image(ui, tex, cx - r, cy - r, r * 2, r * 2, 0.5f, 0, 1, 0.5f, ring);
        mvl_ui_image(ui, tex, kx - kr, ky - kr, kr * 2, kr * 2, 0, 0, 0.5f, 0.5f, knob);
    }
    for (int b = 0; b < t->button_count; ++b) {
        const mvl_touch_button *bt = &t->buttons[b];
        float r = mvl_touch_button_r(t, b) * s, bx = mvl_touch_button_x(t, b) * s, by = mvl_touch_button_y(t, b) * s;
        float tw = mvl_ui_text_width(bt->label, 1.0f);
        mvl_ui_image(ui, tex, bx - r, by - r, r * 2, r * 2, 0, 0, 0.5f, 0.5f, bt->held ? held : btn);
        mvl_ui_image(ui, tex, bx - r, by - r, r * 2, r * 2, 0.5f, 0, 1, 0.5f, ring);
        mvl_ui_text(ui, bx - tw * 0.5f, by - 4, bt->label, 1.0f, label);
    }
}

int mvl_engine_run_headless(mvl_engine *e, int max_frames) {
    for (int i = 0; i < max_frames && !e->quit_requested; ++i) {
        mvl_engine_frame(e, 1.0 / 60.0);
        if (e->test_mode && e->test_done) break;
    }
    if (e->test_mode) {
        if (!e->test_done) {
            MVL_ERROR("test did not finish within %d frames", max_frames);
            return 1;
        }
        return e->test_failed ? 1 : 0;
    }
    return e->script_errors ? 1 : 0;
}
