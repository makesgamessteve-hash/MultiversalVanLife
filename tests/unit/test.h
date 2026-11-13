/* Multiversal Van Life - minimal unit test framework. MIT License. */
#ifndef MVL_TEST_H
#define MVL_TEST_H

#include <math.h>
#include <stdio.h>
#include <string.h>

extern int mvl_test_failures;
extern int mvl_test_checks;
extern const char *mvl_test_tmp;

#define CHECK(cond)                                                                 \
    do {                                                                            \
        mvl_test_checks++;                                                          \
        if (!(cond)) {                                                              \
            mvl_test_failures++;                                                    \
            fprintf(stderr, "%s:%d: CHECK failed: %s\n", __FILE__, __LINE__, #cond); \
        }                                                                           \
    } while (0)

#define CHECK_EQ_INT(a, b)                                                                                \
    do {                                                                                                  \
        long long _a = (long long)(a), _b = (long long)(b);                                               \
        mvl_test_checks++;                                                                                \
        if (_a != _b) {                                                                                   \
            mvl_test_failures++;                                                                          \
            fprintf(stderr, "%s:%d: %s == %s failed (%lld vs %lld)\n", __FILE__, __LINE__, #a, #b, _a, _b); \
        }                                                                                                 \
    } while (0)

#define CHECK_NEAR(a, b, eps)                                                                         \
    do {                                                                                              \
        double _a = (double)(a), _b = (double)(b);                                                    \
        mvl_test_checks++;                                                                            \
        if (fabs(_a - _b) > (eps)) {                                                                  \
            mvl_test_failures++;                                                                      \
            fprintf(stderr, "%s:%d: %s ~= %s failed (%g vs %g)\n", __FILE__, __LINE__, #a, #b, _a, _b); \
        }                                                                                             \
    } while (0)

#define CHECK_STR(a, b)                                                                                  \
    do {                                                                                                 \
        const char *_a = (a), *_b = (b);                                                                 \
        mvl_test_checks++;                                                                               \
        if (!_a || !_b || strcmp(_a, _b)) {                                                             \
            mvl_test_failures++;                                                                         \
            fprintf(stderr, "%s:%d: %s == \"%s\" failed (got \"%s\")\n", __FILE__, __LINE__, #a, _b ? _b : "(null)", _a ? _a : "(null)"); \
        }                                                                                                \
    } while (0)

typedef void (*mvl_test_fn)(void);
typedef struct { const char *name; mvl_test_fn fn; } mvl_test_case;

/* Writes `size` bytes into <tmp>/<name> and stores the full path in out. */
void tmp_path(char *out, size_t size, const char *name);
void tmp_write(const char *name, const void *data, size_t size);

#endif
