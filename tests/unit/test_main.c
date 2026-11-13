/* Multiversal Van Life - unit test runner. MIT License. */
#include "test.h"
#include "core/log.h"
#include "core/vfs.h"
#include <stdlib.h>
#ifdef _WIN32
#include <direct.h>
#define MKDIR(p) _mkdir(p)
#else
#include <sys/stat.h>
#define MKDIR(p) mkdir(p, 0755)
#endif

int mvl_test_failures;
int mvl_test_checks;
const char *mvl_test_tmp = MVL_TEST_TMP;

void tmp_path(char *out, size_t size, const char *name) { mvl_path_join(out, size, mvl_test_tmp, name); }

void tmp_write(const char *name, const void *data, size_t size) {
    char p[1024];
    /* accepts names relative to the temp folder or full paths inside it */
    if (!strncmp(name, mvl_test_tmp, strlen(mvl_test_tmp))) snprintf(p, sizeof p, "%s", name);
    else tmp_path(p, sizeof p, name);
    /* create parent folders */
    for (char *c = p + strlen(mvl_test_tmp) + 1; *c; ++c)
        if (*c == '/') {
            *c = 0;
            MKDIR(p);
            *c = '/';
        }
    if (!mvl_file_write(p, data, size)) fprintf(stderr, "could not write fixture %s\n", p);
}

#define T(name) void name(void);
#include "tests.inc"
#undef T

static const mvl_test_case cases[] = {
#define T(name) {#name, name},
#include "tests.inc"
#undef T
};

static void quiet_sink(mvl_log_level level, const char *msg, void *user) {
    (void)level; (void)msg; (void)user;
}

int main(int argc, char **argv) {
    int ran = 0;
    if (!getenv("MVL_TEST_VERBOSE")) mvl_log_set_sink(quiet_sink, NULL);
    MKDIR(mvl_test_tmp);
    for (size_t i = 0; i < sizeof cases / sizeof cases[0]; ++i) {
        int before = mvl_test_failures;
        if (argc > 1 && !strstr(cases[i].name, argv[1])) continue;
        cases[i].fn();
        ++ran;
        printf("%-40s %s\n", cases[i].name, mvl_test_failures == before ? "ok" : "FAILED");
    }
    printf("%d tests, %d checks, %d failures\n", ran, mvl_test_checks, mvl_test_failures);
    return mvl_test_failures ? 1 : 0;
}
