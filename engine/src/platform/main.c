/* Multiversal Van Life - SDL3 platform layer: window, GL context, input,
 * audio output, main loop and command line. MIT License.
 *
 *   multiversal_van_life [--data DIR] [--mods DIR] [--save DIR]
 *                        [--width W --height H] [--fullscreen] [--touch]
 *                        [--test FILE] [--frames N] [--screenshot FILE.tga]
 *                        [--mute]
 */
#include "core/engine.h"
#include "core/log.h"
#include "platform/gl.h"
#include "platform/renderer.h"
#include "platform/xr.h"
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif

typedef struct {
    SDL_Window *window;
    SDL_GLContext gl;
    SDL_AudioStream *audio;
    SDL_Gamepad *pad;
    mvl_renderer *renderer;
    mvl_engine engine;
    Uint64 last_ticks;
    int max_frames;
    const char *screenshot;
    const char *shots_dir;
    int running;
    int exit_code;
    int mouse_captured;
    Uint64 last_touch_ms; /* browsers synthesise mouse events after taps */
    float audio_buf[2 * 4096];
} app_state;

static app_state g_app;

/* ------------------------------------------------------------ bindings */
static int resolve_binding(const char *name, void *user) {
    static const struct { const char *name; int src; } named[] = {
        {"mouse1", MVL_SRC_MOUSE(1)}, {"mouse2", MVL_SRC_MOUSE(3)}, {"mouse3", MVL_SRC_MOUSE(2)},
        {"pad_a", MVL_SRC_PAD_BUTTON(SDL_GAMEPAD_BUTTON_SOUTH)},
        {"pad_b", MVL_SRC_PAD_BUTTON(SDL_GAMEPAD_BUTTON_EAST)},
        {"pad_x", MVL_SRC_PAD_BUTTON(SDL_GAMEPAD_BUTTON_WEST)},
        {"pad_y", MVL_SRC_PAD_BUTTON(SDL_GAMEPAD_BUTTON_NORTH)},
        {"pad_start", MVL_SRC_PAD_BUTTON(SDL_GAMEPAD_BUTTON_START)},
        {"pad_back", MVL_SRC_PAD_BUTTON(SDL_GAMEPAD_BUTTON_BACK)},
        {"pad_up", MVL_SRC_PAD_BUTTON(SDL_GAMEPAD_BUTTON_DPAD_UP)},
        {"pad_down", MVL_SRC_PAD_BUTTON(SDL_GAMEPAD_BUTTON_DPAD_DOWN)},
        {"pad_left", MVL_SRC_PAD_BUTTON(SDL_GAMEPAD_BUTTON_DPAD_LEFT)},
        {"pad_right", MVL_SRC_PAD_BUTTON(SDL_GAMEPAD_BUTTON_DPAD_RIGHT)},
        {"pad_leftx+", MVL_SRC_PAD_AXIS_POS(SDL_GAMEPAD_AXIS_LEFTX)},
        {"pad_leftx-", MVL_SRC_PAD_AXIS_NEG(SDL_GAMEPAD_AXIS_LEFTX)},
        {"pad_lefty+", MVL_SRC_PAD_AXIS_POS(SDL_GAMEPAD_AXIS_LEFTY)},
        {"pad_lefty-", MVL_SRC_PAD_AXIS_NEG(SDL_GAMEPAD_AXIS_LEFTY)},
        {"pad_rightx+", MVL_SRC_PAD_AXIS_POS(SDL_GAMEPAD_AXIS_RIGHTX)},
        {"pad_rightx-", MVL_SRC_PAD_AXIS_NEG(SDL_GAMEPAD_AXIS_RIGHTX)},
        {"pad_righty+", MVL_SRC_PAD_AXIS_POS(SDL_GAMEPAD_AXIS_RIGHTY)},
        {"pad_righty-", MVL_SRC_PAD_AXIS_NEG(SDL_GAMEPAD_AXIS_RIGHTY)},
    };
    SDL_Scancode sc;
    (void)user;
    for (size_t i = 0; i < sizeof named / sizeof named[0]; ++i)
        if (!SDL_strcasecmp(name, named[i].name)) return named[i].src;
    sc = SDL_GetScancodeFromName(name);
    return (sc == SDL_SCANCODE_UNKNOWN || sc >= 1000) ? -1 : MVL_SRC_KEY((int)sc);
}

/* --------------------------------------------------------------- audio */
static void pump_audio(app_state *a) {
    int queued, want, frames;
    if (!a->audio) return;
    queued = SDL_GetAudioStreamQueued(a->audio) / (int)(2 * sizeof(float));
    want = a->engine.mixer.rate / 10; /* keep ~100 ms buffered */
    while (queued < want) {
        frames = want - queued;
        if (frames > 4096) frames = 4096;
        mvl_mixer_mix(&a->engine.mixer, a->audio_buf, frames);
        SDL_PutAudioStreamData(a->audio, a->audio_buf, frames * (int)(2 * sizeof(float)));
        queued += frames;
    }
}

/* -------------------------------------------------------------- events */
static void set_capture(app_state *a, int on) {
    if (a->engine.touch.enabled) on = 0;
    if (a->mouse_captured == on) return;
    a->mouse_captured = on;
    SDL_SetWindowRelativeMouseMode(a->window, on);
}

static void handle_event(app_state *a, const SDL_Event *ev) {
    mvl_engine *e = &a->engine;
    switch (ev->type) {
    case SDL_EVENT_QUIT:
        a->running = 0;
        break;
    case SDL_EVENT_KEY_DOWN:
    case SDL_EVENT_KEY_UP:
        if (ev->key.scancode < 1000) mvl_input_set_source(&e->input, ev->key.scancode, ev->type == SDL_EVENT_KEY_DOWN);
        if (ev->type == SDL_EVENT_KEY_DOWN && ev->key.scancode == SDL_SCANCODE_ESCAPE) set_capture(a, 0);
        if (ev->type == SDL_EVENT_KEY_DOWN && ev->key.scancode == SDL_SCANCODE_F11) {
            SDL_SetWindowFullscreen(a->window, !(SDL_GetWindowFlags(a->window) & SDL_WINDOW_FULLSCREEN));
        }
        break;
    case SDL_EVENT_MOUSE_BUTTON_DOWN:
    case SDL_EVENT_MOUSE_BUTTON_UP:
        if (ev->button.which == SDL_TOUCH_MOUSEID || SDL_GetTicks() - a->last_touch_ms < 1500) break;
        mvl_input_set_source(&e->input, MVL_SRC_MOUSE(ev->button.button), ev->type == SDL_EVENT_MOUSE_BUTTON_DOWN);
        if (ev->type == SDL_EVENT_MOUSE_BUTTON_DOWN) {
            if (e->touch.enabled) {
                e->touch.enabled = 0; /* a real mouse is in use again */
                mvl_touch_cancel_all(&e->touch);
            }
            set_capture(a, 1);
        }
        break;
    case SDL_EVENT_MOUSE_MOTION:
        if (ev->motion.which != SDL_TOUCH_MOUSEID && a->mouse_captured)
            mvl_input_add_look(&e->input, ev->motion.xrel * e->input.mouse_sensitivity,
                               ev->motion.yrel * e->input.mouse_sensitivity);
        break;
    case SDL_EVENT_FINGER_DOWN:
        a->last_touch_ms = SDL_GetTicks();
        set_capture(a, 0);
        mvl_touch_down(&e->touch, (long long)ev->tfinger.fingerID, ev->tfinger.x, ev->tfinger.y);
        break;
    case SDL_EVENT_FINGER_MOTION:
        a->last_touch_ms = SDL_GetTicks();
        mvl_touch_move(&e->touch, (long long)ev->tfinger.fingerID, ev->tfinger.x, ev->tfinger.y);
        break;
    case SDL_EVENT_FINGER_UP:
    case SDL_EVENT_FINGER_CANCELED:
        a->last_touch_ms = SDL_GetTicks();
        mvl_touch_up(&e->touch, (long long)ev->tfinger.fingerID);
        break;
    case SDL_EVENT_GAMEPAD_ADDED:
        if (!a->pad) a->pad = SDL_OpenGamepad(ev->gdevice.which);
        break;
    case SDL_EVENT_GAMEPAD_REMOVED:
        if (a->pad && SDL_GetGamepadID(a->pad) == ev->gdevice.which) {
            SDL_CloseGamepad(a->pad);
            a->pad = NULL;
            mvl_input_reset(&e->input);
        }
        break;
    case SDL_EVENT_GAMEPAD_BUTTON_DOWN:
    case SDL_EVENT_GAMEPAD_BUTTON_UP:
        mvl_input_set_source(&e->input, MVL_SRC_PAD_BUTTON(ev->gbutton.button), ev->type == SDL_EVENT_GAMEPAD_BUTTON_DOWN);
        break;
    case SDL_EVENT_GAMEPAD_AXIS_MOTION: {
        float v = ev->gaxis.value / 32767.0f;
        mvl_input_set_source(&e->input, MVL_SRC_PAD_AXIS_POS(ev->gaxis.axis), v > 0 ? v : 0);
        mvl_input_set_source(&e->input, MVL_SRC_PAD_AXIS_NEG(ev->gaxis.axis), v < 0 ? -v : 0);
        break;
    }
    case SDL_EVENT_WINDOW_FOCUS_LOST:
        mvl_input_reset(&e->input);
        mvl_touch_cancel_all(&e->touch);
        break;
    default:
        break;
    }
}

/* ----------------------------------------------------------- main loop */
static void save_screenshot(app_state *a, const char *path, int w, int h) {
    mvl_image img;
    size_t n;
    void *tga;
    if (!mvl_renderer_screenshot(a->renderer, w, h, &img)) return;
    tga = mvl_image_save_tga(&img, &n);
    if (tga && mvl_file_write(path, tga, n)) MVL_INFO("screenshot written to %s", path);
    free(tga);
    mvl_image_free(&img);
}

static void frame(void) {
    app_state *a = &g_app;
    mvl_engine *e = &a->engine;
    SDL_Event ev;
    Uint64 now;
    double dt;
    int w, h;
    while (SDL_PollEvent(&ev)) handle_event(a, &ev);
    if (e->xr_requested) {
        e->xr_requested = 0;
        mvl_xr_start(e);
    }
#ifdef __EMSCRIPTEN__
    if (e->xr_active) return; /* the WebXR session drives frames */
#endif
    now = SDL_GetTicksNS();
    dt = (double)(now - a->last_ticks) / 1e9;
    a->last_ticks = now;
    if (a->max_frames > 0 || e->test_mode) dt = 1.0 / 60.0; /* deterministic when testing */
    SDL_GetWindowSizeInPixels(a->window, &w, &h);
    if (h > 0) mvl_engine_set_aspect(e, (float)w / (float)h);
    mvl_engine_frame(e, dt);
    pump_audio(a);
    mvl_renderer_draw(a->renderer, e, w, h);
    if (a->max_frames > 0 && (int)e->frame >= a->max_frames && a->screenshot) save_screenshot(a, a->screenshot, w, h);
    if (e->screenshot_request[0]) { /* requested by an automated test */
        char path[1024];
        snprintf(path, sizeof path, "%s/%s", a->shots_dir ? a->shots_dir : ".", e->screenshot_request);
        save_screenshot(a, path, w, h);
        e->screenshot_request[0] = 0;
    }
    SDL_GL_SwapWindow(a->window);
    if (e->quit_requested) a->running = 0;
    if (e->test_mode && e->test_done) a->running = 0;
    if (a->max_frames > 0 && (int)e->frame >= a->max_frames) a->running = 0;
#ifdef __EMSCRIPTEN__
    if (!a->running) emscripten_cancel_main_loop();
#endif
}

/* Called by the XR glue once per XR animation frame. */
void mvl_platform_xr_tick(double dt) {
    app_state *a = &g_app;
    mvl_engine_frame(&a->engine, dt);
    pump_audio(a);
    mvl_renderer_prepare_xr(a->renderer, &a->engine);
}

mvl_renderer *mvl_platform_renderer(void) { return g_app.renderer; }
mvl_engine *mvl_platform_engine(void) { return &g_app.engine; }

static void on_save(void *user) {
    (void)user;
#ifdef __EMSCRIPTEN__
    EM_ASM(FS.syncfs(false, function(err) { if (err) console.warn('save sync failed', err); }););
#endif
}

#ifdef __EMSCRIPTEN__
EMSCRIPTEN_KEEPALIVE void mvl_web_set_touch(int on) {
    g_app.engine.touch.enabled = on;
}
EMSCRIPTEN_KEEPALIVE void mvl_web_save_synced(void) {}
#endif

int main(int argc, char **argv) {
    app_state *a = &g_app;
    mvl_engine_desc d;
    char data_dir[1024], mods_dir[1024];
    char *pref = NULL;
    int width = 1280, height = 720, fullscreen = 0, mute = 0, force_touch = 0;
    memset(&d, 0, sizeof d);
#ifdef __EMSCRIPTEN__
    snprintf(data_dir, sizeof data_dir, "/game");
    snprintf(mods_dir, sizeof mods_dir, "/mods");
    d.platform = "web";
    d.save_dir = "/save";
#else
    const char *base = SDL_GetBasePath();
    snprintf(data_dir, sizeof data_dir, "%sgame", base ? base : "./");
    snprintf(mods_dir, sizeof mods_dir, "%smods", base ? base : "./");
#if defined(_WIN32)
    d.platform = "windows";
#elif defined(__APPLE__)
    d.platform = "macos";
#else
    d.platform = "linux";
#endif
#endif
    d.data_dir = data_dir;
    d.mods_dir = mods_dir;
    for (int i = 1; i < argc; ++i) {
        const char *arg = argv[i], *v = i + 1 < argc ? argv[i + 1] : NULL;
        if (!strcmp(arg, "--data") && v) d.data_dir = argv[++i];
        else if (!strcmp(arg, "--mods") && v) d.mods_dir = argv[++i];
        else if (!strcmp(arg, "--save") && v) d.save_dir = argv[++i];
        else if (!strcmp(arg, "--width") && v) width = atoi(argv[++i]);
        else if (!strcmp(arg, "--height") && v) height = atoi(argv[++i]);
        else if (!strcmp(arg, "--test") && v) d.test_script = argv[++i];
        else if (!strcmp(arg, "--frames") && v) a->max_frames = atoi(argv[++i]);
        else if (!strcmp(arg, "--screenshot") && v) a->screenshot = argv[++i];
        else if (!strcmp(arg, "--shots") && v) a->shots_dir = argv[++i];
        else if (!strcmp(arg, "--fullscreen")) fullscreen = 1;
        else if (!strcmp(arg, "--mute")) mute = 1;
        else if (!strcmp(arg, "--touch")) force_touch = 1;
        else {
            fprintf(stderr, "unknown argument: %s\n", arg);
            return 2;
        }
    }

    SDL_SetHint(SDL_HINT_TOUCH_MOUSE_EVENTS, "0");
    SDL_SetHint(SDL_HINT_MOUSE_TOUCH_EVENTS, "0");
    if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMEPAD | (mute ? 0 : SDL_INIT_AUDIO))) {
        fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
        return 1;
    }
#ifndef __EMSCRIPTEN__
    if (!d.save_dir) {
        pref = SDL_GetPrefPath("MultiversalVanLife", "MultiversalVanLife");
        d.save_dir = pref;
    }
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
#ifdef __APPLE__
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG);
#endif
#else
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_ES);
#endif
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
    SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE, 8);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);

    a->window = SDL_CreateWindow("Multiversal Van Life", width, height,
                                 SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIGH_PIXEL_DENSITY |
                                     (fullscreen ? SDL_WINDOW_FULLSCREEN : 0));
    if (!a->window) {
        fprintf(stderr, "window creation failed: %s\n", SDL_GetError());
        return 1;
    }
    a->gl = SDL_GL_CreateContext(a->window);
    if (!a->gl || !mvl_gl_load()) {
        fprintf(stderr, "OpenGL 3.3 / ES 3.0 context unavailable: %s\n", SDL_GetError());
        return 1;
    }
    SDL_GL_SetSwapInterval((a->max_frames > 0 || d.test_script) ? 0 : 1);

    if (!mute) {
        SDL_AudioSpec spec;
        spec.format = SDL_AUDIO_F32;
        spec.channels = 2;
        spec.freq = 44100;
        a->audio = SDL_OpenAudioDeviceStream(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &spec, NULL, NULL);
        if (a->audio) SDL_ResumeAudioStreamDevice(a->audio);
        else MVL_WARN("no audio device: %s", SDL_GetError());
    }

    a->renderer = mvl_renderer_create();
    d.gfx = mvl_renderer_backend(a->renderer);
    d.key_resolver = resolve_binding;
    d.audio_rate = 44100;
    d.aspect = (float)width / (float)height;
    if (!mvl_engine_init(&a->engine, &d)) {
        fprintf(stderr, "engine init failed: %s\n", a->engine.last_error);
        return 1;
    }
    a->engine.on_save = on_save;
    a->engine.xr_supported = mvl_xr_supported();
    if (force_touch) a->engine.touch.enabled = 1;
    if (!mvl_renderer_init(a->renderer, &a->engine)) {
        fprintf(stderr, "renderer init failed (see log)\n");
        return 1;
    }
    a->running = 1;
    a->last_ticks = SDL_GetTicksNS();
#ifdef __EMSCRIPTEN__
    EM_ASM(if (Module.mvlReady) Module.mvlReady(););
    emscripten_set_main_loop(frame, 0, 1);
#else
    while (a->running) frame();
#endif
    a->exit_code = a->engine.test_mode ? (a->engine.test_done && !a->engine.test_failed ? 0 : 1)
                                       : (a->engine.script_errors ? 1 : 0);
    mvl_engine_shutdown(&a->engine);
    mvl_renderer_destroy(a->renderer);
    if (a->pad) SDL_CloseGamepad(a->pad);
    if (a->audio) SDL_DestroyAudioStream(a->audio);
    SDL_GL_DestroyContext(a->gl);
    SDL_DestroyWindow(a->window);
    SDL_free(pref);
    SDL_Quit();
    return a->exit_code;
}
