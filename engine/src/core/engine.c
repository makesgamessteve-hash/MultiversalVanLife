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

/* Saves before the save folder existed were a single `savegame.ini`. Its
 * keys become the index; the old file is kept as `savegame.ini.bak`. */
static void migrate_old_save(mvl_engine *e) {
    char old[MVL_PATH_MAX], bak[MVL_PATH_MAX + 8];
    char *text;
    mvl_path_join(old, sizeof old, e->save_dir, "savegame.ini");
    if (!strcmp(old, e->save_path) || mvl_is_dir(old) || !(text = mvl_file_read(old, NULL))) return;
    mvl_kv_parse(&e->save, text);
    free(text);
    if (!mvl_engine_write_save(e)) return;
    snprintf(bak, sizeof bak, "%s.bak", old);
    remove(bak);
    if (rename(old, bak) == 0) MVL_INFO("converted old save %s", old);
}

static void load_save(mvl_engine *e, const char *save_dir) {
    char *text;
    mvl_kv_init(&e->save);
    e->save_path[0] = e->save_dir[0] = 0;
    if (!save_dir || !*save_dir || strlen(save_dir) >= sizeof e->save_dir - 32) return;
    snprintf(e->save_dir, sizeof e->save_dir, "%s", save_dir);
    mvl_path_join(e->save_path, sizeof e->save_path, save_dir,
                  mvl_kv_get_str(&e->config, "save.file", "index.ini"));
    text = mvl_file_read(e->save_path, NULL);
    if (!text) {
        /* an interrupted save leaves the complete new index in .tmp */
        char tmp[MVL_PATH_MAX + 8];
        snprintf(tmp, sizeof tmp, "%s.tmp", e->save_path);
        text = mvl_file_read(tmp, NULL);
    }
    if (text) {
        mvl_kv_parse(&e->save, text);
        free(text);
    } else {
        migrate_old_save(e);
    }
}

int mvl_engine_write_save(mvl_engine *e) {
    size_t len;
    char *text;
    int ok;
    if (!e->save_path[0]) return 0;
    text = mvl_kv_serialize(&e->save, &len);
    if (!text) return 0;
    mvl_mkdirs(e->save_dir);
    ok = mvl_file_write_atomic(e->save_path, text, len);
    free(text);
    if (!ok) MVL_WARN("could not write save file %s", e->save_path);
    e->save_sync_pending |= ok;
    return ok;
}

int mvl_engine_record_path(const mvl_engine *e, const char *name, char *out, size_t out_size) {
    char clean[MVL_PATH_MAX], rel[MVL_PATH_MAX + 16];
    size_t n = strlen(name);
    if (!e->save_dir[0] || n == 0 || n > 200) return 0;
    for (const char *p = name; *p; ++p) {
        char c = *p;
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == '-' ||
              c == '.' || c == '/'))
            return 0;
    }
    if (!mvl_vfs_sanitize(name, clean, sizeof clean) || strcmp(clean, name)) return 0;
    snprintf(rel, sizeof rel, "records/%s.rec", clean);
    mvl_path_join(out, out_size, e->save_dir, rel);
    return 1;
}

static void remove_entry(const char *rel, int is_dir, void *user) {
    char path[MVL_PATH_MAX * 2];
    (void)is_dir;
    mvl_path_join(path, sizeof path, (const char *)user, rel);
    mvl_remove_path(path);
}

void mvl_engine_clear_records(mvl_engine *e) {
    char dir[MVL_PATH_MAX];
    if (!e->save_dir[0]) return;
    mvl_path_join(dir, sizeof dir, e->save_dir, "records");
    if (mvl_dir_walk(dir, remove_entry, dir) > 0) e->save_sync_pending = 1;
}

static void flush_save_sync(mvl_engine *e) {
    if (!e->save_sync_pending) return;
    e->save_sync_pending = 0;
    if (e->on_save) e->on_save(e->on_save_user);
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
    mvl_kv_init(&e->options);
    if (d->options) {
        /* "a=1;b=x" -> kv lines */
        char *text = (char *)malloc(strlen(d->options) + 1);
        if (text) {
            for (size_t i = 0; (text[i] = d->options[i]) != 0; ++i)
                if (text[i] == ';') text[i] = '\n';
            mvl_kv_parse(&e->options, text);
            free(text);
        }
    }
    text = mvl_vfs_read(&e->vfs, "config/engine.ini", NULL);
    if (text) {
        mvl_kv_parse(&e->config, text);
        free(text);
    }
    e->fixed_dt = 1.0f / (float)mvl_kv_get_int(&e->config, "engine.tick_rate", 60);

    mvl_res_init(&e->res, &e->vfs, d->gfx);
    mvl_scene_init(&e->scene);
    mvl_terrain_init(&e->terrain, 0);
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
    flush_save_sync(e);
    mvl_script_shutdown(e);
    mvl_mixer_stop_all(&e->mixer);
    mvl_res_shutdown(&e->res);
    mvl_terrain_free(&e->terrain);
    mvl_kv_free(&e->config);
    mvl_kv_free(&e->options);
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
    flush_save_sync(e);
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

void mvl_engine_drain_audio(mvl_engine *e, double dt) {
    static float scratch[2 * 512];
    for (int left = (int)(dt * e->mixer.rate + 0.5); left > 0; left -= 512)
        mvl_mixer_mix(&e->mixer, scratch, left < 512 ? left : 512);
}

int mvl_engine_run_headless(mvl_engine *e, int max_frames) {
    for (int i = 0; i < max_frames && !e->quit_requested; ++i) {
        mvl_engine_frame(e, 1.0 / 60.0);
        mvl_engine_drain_audio(e, 1.0 / 60.0);
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
