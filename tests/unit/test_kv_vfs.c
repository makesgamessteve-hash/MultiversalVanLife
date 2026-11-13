/* Unit tests: kv store, VFS and logging. MIT License. */
#include "test.h"
#include "core/kv.h"
#include "core/log.h"
#include "core/vfs.h"
#include <stdlib.h>

void test_kv_parse_and_get(void) {
    mvl_kv kv;
    char *s;
    size_t n;
    mvl_kv_init(&kv);
    CHECK_EQ_INT(mvl_kv_parse(&kv, "; comment\n# also\nname = Juniper\n[render]\nheight= 240 \nscale = 1.5\n"
                                   "dither = yes\nbad line\n = nokey\n[ui ]\nquoted = \"hi there\"\nhex = 0x10\nnum = 12abc\n"
                                   "off = off\nmaybe = perhaps\n[broken\nlast=1"),
                 10);
    CHECK_STR(mvl_kv_get(&kv, "name"), "Juniper");
    CHECK_EQ_INT(mvl_kv_get_int(&kv, "render.height", 0), 240);
    CHECK_EQ_INT(mvl_kv_get_int(&kv, "ui.hex", 0), 16);
    CHECK_EQ_INT(mvl_kv_get_int(&kv, "ui.num", 7), 7);
    CHECK_EQ_INT(mvl_kv_get_int(&kv, "missing", 3), 3);
    CHECK_NEAR(mvl_kv_get_float(&kv, "render.scale", 0), 1.5, 1e-6);
    CHECK_NEAR(mvl_kv_get_float(&kv, "ui.num", 2.0f), 2.0, 1e-6);
    CHECK_NEAR(mvl_kv_get_float(&kv, "nope", 4.0f), 4.0, 1e-6);
    CHECK(mvl_kv_get_bool(&kv, "render.dither", 0));
    CHECK(!mvl_kv_get_bool(&kv, "ui.off", 1));
    CHECK(mvl_kv_get_bool(&kv, "ui.maybe", 1));
    CHECK(mvl_kv_get_bool(&kv, "missing", 1));
    CHECK_STR(mvl_kv_get_str(&kv, "ui.quoted", ""), "hi there");
    CHECK_STR(mvl_kv_get_str(&kv, "x", "def"), "def");
    CHECK_STR(mvl_kv_get(&kv, "ui.last"), "1");
    CHECK(mvl_kv_parse(&kv, NULL) == 0);
    CHECK(mvl_kv_set(&kv, "multi", "a\nb\rc"));
    CHECK_STR(mvl_kv_get(&kv, "multi"), "a b c");
    CHECK(!mvl_kv_set(&kv, "", "x"));
    CHECK(mvl_kv_remove(&kv, "multi"));
    CHECK(!mvl_kv_remove(&kv, "multi"));
    s = mvl_kv_serialize(&kv, &n);
    CHECK(s && strstr(s, "name = Juniper\n"));
    CHECK(strstr(s, "render.height = 240\n") != NULL);
    {
        mvl_kv back;
        mvl_kv_init(&back);
        mvl_kv_parse(&back, s);
        CHECK_STR(mvl_kv_get(&back, "render.height"), "240");
        mvl_kv_free(&back);
    }
    free(s);
    for (int i = 0; i < 40; ++i) {
        char k[16];
        snprintf(k, sizeof k, "k%d", i);
        mvl_kv_set(&kv, k, k);
    }
    CHECK_STR(mvl_kv_get(&kv, "k39"), "k39");
    mvl_kv_clear(&kv);
    CHECK(mvl_kv_get(&kv, "name") == NULL);
    s = mvl_kv_serialize(&kv, NULL);
    CHECK_STR(s, "");
    free(s);
    mvl_kv_free(&kv);
}

void test_vfs_paths(void) {
    char out[64];
    CHECK(mvl_vfs_sanitize("scripts/./lib//util.lua", out, sizeof out));
    CHECK_STR(out, "scripts/lib/util.lua");
    CHECK(mvl_vfs_sanitize("a\\b", out, sizeof out));
    CHECK_STR(out, "a/b");
    CHECK(!mvl_vfs_sanitize("../etc/passwd", out, sizeof out));
    CHECK(!mvl_vfs_sanitize("/abs", out, sizeof out));
    CHECK(!mvl_vfs_sanitize("C:/win", out, sizeof out));
    CHECK(!mvl_vfs_sanitize("", out, sizeof out));
    CHECK(!mvl_vfs_sanitize(".", out, sizeof out));
    CHECK(!mvl_vfs_sanitize(NULL, out, sizeof out));
    CHECK(!mvl_vfs_sanitize("averyveryveryverylongname/averyveryveryverylongname/x", out, 16));
    mvl_path_join(out, sizeof out, "dir/", "f");
    CHECK_STR(out, "dir/f");
    mvl_path_join(out, sizeof out, "", "f");
    CHECK_STR(out, "f");
    mvl_path_join(out, sizeof out, "d", "f");
    CHECK_STR(out, "d/f");
    mvl_path_dirname(out, sizeof out, "a/b/c.lua");
    CHECK_STR(out, "a/b");
    mvl_path_dirname(out, sizeof out, "c.lua");
    CHECK_STR(out, ".");
    mvl_path_dirname(out, sizeof out, "/c.lua");
    CHECK_STR(out, "/");
    mvl_path_dirname(out, sizeof out, "a\\b\\c");
    CHECK_STR(out, "a\\b");
}

void test_vfs_roots_and_mods(void) {
    mvl_vfs vfs;
    char base[512], mods[512], full[1024], *data;
    size_t n;
    tmp_path(base, sizeof base, "vfs_base");
    tmp_path(mods, sizeof mods, "vfs_mods");
    tmp_write("vfs_base/hello.txt", "base", 4);
    tmp_write("vfs_base/only.txt", "only", 4);
    tmp_write("vfs_mods/mods.txt", "# list\n\n  modA\n../evil\nmodB\nmissing/x\n", 39);
    tmp_write("vfs_mods/modA/hello.txt", "modA", 4);
    tmp_write("vfs_mods/modB/hello.txt", "modB", 4);
    mvl_vfs_init(&vfs);
    CHECK_EQ_INT(mvl_vfs_add_root(&vfs, base, "base"), 0);
    CHECK_EQ_INT(mvl_vfs_add_root(&vfs, "", "x"), -1);
    CHECK_EQ_INT(mvl_vfs_add_root(&vfs, NULL, "x"), -1);
    CHECK_EQ_INT(mvl_vfs_add_mods(&vfs, mods), 2);
    CHECK_EQ_INT(mvl_vfs_add_mods(&vfs, "/nonexistent-dir"), 0);
    CHECK_STR(vfs.roots[1].name, "modA");
    data = mvl_vfs_read(&vfs, "hello.txt", &n);
    CHECK(data && n == 4 && !memcmp(data, "modB", 4));
    free(data);
    data = mvl_vfs_read_root(&vfs, 1, "hello.txt", NULL);
    CHECK(data && !memcmp(data, "modA", 4));
    free(data);
    CHECK(mvl_vfs_read_root(&vfs, 9, "hello.txt", NULL) == NULL);
    CHECK(mvl_vfs_read_root(&vfs, 0, "../x", NULL) == NULL);
    CHECK(mvl_vfs_exists(&vfs, "only.txt"));
    CHECK(!mvl_vfs_exists(&vfs, "nothing.txt"));
    CHECK(!mvl_vfs_exists(&vfs, "../only.txt"));
    CHECK(mvl_vfs_read(&vfs, "nothing.txt", NULL) == NULL);
    CHECK_EQ_INT(mvl_vfs_resolve(&vfs, "only.txt", full, sizeof full), 0);
    {
        mvl_vfs v2;
        char trailing[600];
        mvl_vfs_init(&v2);
        snprintf(trailing, sizeof trailing, "%s//", base);
        mvl_vfs_add_root(&v2, trailing, NULL);
        CHECK_STR(v2.roots[0].name, "root");
        CHECK(mvl_vfs_exists(&v2, "only.txt"));
        for (int i = 1; i < MVL_VFS_MAX_ROOTS; ++i) mvl_vfs_add_root(&v2, base, "x");
        CHECK_EQ_INT(mvl_vfs_add_root(&v2, base, "x"), -1);
    }
    CHECK(mvl_file_read("/nonexistent/file", NULL) == NULL);
    CHECK(!mvl_file_write("/nonexistent/dir/file", "x", 1));
    {
        /* reading a directory fails gracefully */
        char *d = mvl_file_read(base, NULL);
        free(d);
    }
}

static int g_sink_count;
static void sink(mvl_log_level level, const char *msg, void *user) {
    (void)level;
    (void)msg;
    *(int *)user += 1;
}

void test_log(void) {
    int count = 0;
    mvl_log_set_sink(sink, &count);
    mvl_log_set_min_level(MVL_LOG_WARN);
    MVL_INFO("hidden");
    MVL_WARN("shown %d", 1);
    MVL_ERROR("shown");
    CHECK_EQ_INT(count, 2);
    mvl_log_set_min_level(MVL_LOG_DEBUG);
    MVL_DEBUG("debug");
    CHECK_EQ_INT(count, 3);
    mvl_log_set_sink(NULL, NULL);
    MVL_DEBUG("to stderr");
    mvl_log_set_min_level(MVL_LOG_INFO);
    mvl_log_set_sink(sink, &g_sink_count);
}
