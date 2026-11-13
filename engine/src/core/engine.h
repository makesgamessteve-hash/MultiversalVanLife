/* Multiversal Van Life - engine core: owns every subsystem, runs the Lua
 * game scripts on a fixed time step and exposes state to the platform
 * layer for rendering and audio output. MIT License. */
#ifndef MVL_ENGINE_H
#define MVL_ENGINE_H

#include "core/input.h"
#include "core/kv.h"
#include "core/mixer.h"
#include "core/resources.h"
#include "core/scene.h"
#include "core/terrain.h"
#include "core/touch.h"
#include "core/ui.h"
#include "core/vfs.h"

struct lua_State;

typedef struct {
    const char *data_dir;      /* base game folder (required) */
    const char *mods_dir;      /* optional folder with mods.txt */
    const char *save_dir;      /* optional writable folder for saves */
    const char *platform;      /* "linux", "windows", "macos", "web", "headless" */
    const char *test_script;   /* optional automated game test (file path) */
    mvl_gfx_backend gfx;
    mvl_key_resolver key_resolver;
    void *key_resolver_user;
    int audio_rate;
    float aspect;              /* window aspect ratio */
    int headless;
} mvl_engine_desc;

typedef struct mvl_engine {
    mvl_vfs vfs;
    mvl_resources res;
    mvl_scene scene;
    mvl_input input;
    mvl_touch touch;
    mvl_mixer mixer;
    mvl_ui ui;
    mvl_kv config;
    mvl_kv save;
    mvl_terrain terrain;     /* height field configured by scripts */
    char save_path[MVL_PATH_MAX];
    char platform[16];
    struct lua_State *L;

    double time;              /* simulated seconds */
    unsigned long frame;      /* rendered frames */
    unsigned long ticks;      /* fixed updates */
    float fixed_dt;
    double accumulator;
    float aspect;
    float alpha;              /* interpolation factor of the last frame */
    int headless;
    int quit_requested;
    int script_errors;
    char last_error[1024];

    /* save hook: called after the save file was written (web: sync IDBFS) */
    void (*on_save)(void *user);
    void *on_save_user;

    /* WebXR / VR */
    int xr_supported, xr_active, xr_requested;
    float xr_head_yaw, xr_head_pitch;
    vec3 xr_head_offset;

    /* automated game test */
    int test_mode, test_ref, test_wait, test_done, test_failed;
    struct lua_State *test_thread;
} mvl_engine;

/* Returns 1 on success. On failure `e->last_error` describes the problem. */
int mvl_engine_init(mvl_engine *e, const mvl_engine_desc *desc);
void mvl_engine_shutdown(mvl_engine *e);
/* Advances the simulation by real time `dt` (seconds) using fixed steps,
 * then builds the UI draw list. */
void mvl_engine_frame(mvl_engine *e, double dt);
/* Runs the engine without a window for at most `max_frames` frames at
 * 60 Hz. Returns 0 if a test passed (or no test and no script error). */
int mvl_engine_run_headless(mvl_engine *e, int max_frames);
void mvl_engine_set_aspect(mvl_engine *e, float aspect);
/* Writes the save data to disk. Returns 1 on success. */
int mvl_engine_write_save(mvl_engine *e);
/* UI canvas size derived from config (ui.height) and aspect. */
void mvl_engine_ui_size(const mvl_engine *e, float *w, float *h);

/* script.c */
int mvl_script_init(mvl_engine *e);
void mvl_script_shutdown(mvl_engine *e);
/* Calls game.<fn>(args...) if it exists. Returns 0 on error. */
int mvl_script_call(mvl_engine *e, const char *fn, int nargs_number, double arg);
int mvl_script_run_string(mvl_engine *e, const char *code, const char *name);
int mvl_script_load_test(mvl_engine *e, const char *path);
/* Resumes the test coroutine if it is not waiting. */
void mvl_script_step_test(mvl_engine *e);

#endif
