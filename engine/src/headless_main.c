/* Multiversal Van Life - headless runner (no window, no audio device, no GPU).
 * Used for automated game tests and CI:
 *   mvl_headless --data game --test tests/game/test_intro.lua [--frames N]
 * MIT License. */
#include "core/engine.h"
#include "core/log.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Bindings are irrelevant headless (tests inject actions directly), but
 * resolving every name keeps the input configuration validated. */
static int resolve_any(const char *name, void *user) {
    unsigned h = 5381;
    (void)user;
    for (const char *p = name; *p; ++p) h = h * 33u + (unsigned char)*p;
    return (int)(h % 999u) + 1;
}

int main(int argc, char **argv) {
    mvl_engine_desc d;
    static mvl_engine e;
    int frames = 60 * 60 * 5, rc;
    memset(&d, 0, sizeof d);
    d.data_dir = "game";
    d.platform = "headless";
    d.headless = 1;
    d.gfx = mvl_gfx_null_backend();
    d.key_resolver = resolve_any;
    d.audio_rate = 44100;
    for (int i = 1; i < argc; ++i) {
        const char *a = argv[i];
        const char *v = i + 1 < argc ? argv[i + 1] : NULL;
        if (!strcmp(a, "--data") && v) d.data_dir = argv[++i];
        else if (!strcmp(a, "--mods") && v) d.mods_dir = argv[++i];
        else if (!strcmp(a, "--save") && v) d.save_dir = argv[++i];
        else if (!strcmp(a, "--test") && v) d.test_script = argv[++i];
        else if (!strcmp(a, "--frames") && v) frames = atoi(argv[++i]);
        else {
            fprintf(stderr, "usage: %s [--data DIR] [--mods DIR] [--save DIR] [--test FILE] [--frames N]\n", argv[0]);
            return 2;
        }
    }
    if (!mvl_engine_init(&e, &d)) {
        fprintf(stderr, "engine init failed: %s\n", e.last_error);
        mvl_engine_shutdown(&e);
        return 1;
    }
    rc = mvl_engine_run_headless(&e, frames);
    mvl_engine_shutdown(&e);
    if (rc == 0 && e.script_errors) rc = 1;
    printf("%s (%lu ticks, %d script errors)\n", rc == 0 ? "OK" : "FAILED", e.ticks, e.script_errors);
    return rc;
}
