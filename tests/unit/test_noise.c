/* Unit tests: deterministic hashing, random streams and noise. MIT License.
 * The reference values below were produced by this implementation; CI runs
 * these tests on Windows, Linux, macOS (and the web build compiles the same
 * code), so any platform difference fails here. */
#include "test.h"
#include "core/noise.h"
#define REF_HASH_0 0u
#define REF_HASH_12345 1881738165u
#define REF_HASH3_123 4015563656u
#define REF_HASH_STR 3339248461u
#define REF_RNG_FIRST 1307692281u
#define REF_NOISE2 -0.36317122f
#define REF_NOISE3 -0.307981104f
#define REF_FBM2 -0.573120296f
#define REF_FBM3 0.210935861f

void test_hash_reference(void) {
    CHECK_EQ_INT(mvl_hash_u32(0), REF_HASH_0);
    CHECK_EQ_INT(mvl_hash_u32(12345), REF_HASH_12345);
    CHECK_EQ_INT(mvl_hash3(1, 2, 3), REF_HASH3_123);
    CHECK_EQ_INT(mvl_hash_str("juniper", 7), REF_HASH_STR);
    CHECK(mvl_hash3(1, 2, 3) != mvl_hash3(3, 2, 1));
    CHECK(mvl_hash_str(NULL, 1) == mvl_hash_str("", 1));
    CHECK(mvl_hash_combine(1, 2) != mvl_hash_combine(2, 1));
}

void test_rng_streams(void) {
    mvl_rng a, b, c;
    int buckets[4] = {0, 0, 0, 0};
    mvl_rng_seed(&a, 42, 1);
    mvl_rng_seed(&b, 42, 1);
    mvl_rng_seed(&c, 42, 2);
    CHECK_EQ_INT(mvl_rng_u32(&a), REF_RNG_FIRST);
    CHECK_EQ_INT(mvl_rng_u32(&b), REF_RNG_FIRST);
    CHECK(mvl_rng_u32(&c) != REF_RNG_FIRST); /* different stream */
    for (int i = 0; i < 4000; ++i) {
        float f = mvl_rng_float(&a);
        int r = mvl_rng_range(&a, 0, 3);
        CHECK(f >= 0.0f && f < 1.0f);
        if (r < 0 || r > 3) CHECK(0);
        else buckets[r]++;
    }
    for (int i = 0; i < 4; ++i) CHECK(buckets[i] > 850 && buckets[i] < 1150);
    CHECK_EQ_INT(mvl_rng_range(&a, 5, 5), 5);
    CHECK_EQ_INT(mvl_rng_range(&a, 9, 2), 9);
    (void)mvl_rng_range(&a, (-2147483647 - 1), 2147483647); /* full range */
}

void test_noise_reference(void) {
    float mn = 1, mx = -1;
    CHECK_NEAR(mvl_noise2(1.25f, -3.5f, 7), REF_NOISE2, 0);
    CHECK_NEAR(mvl_noise3(0.3f, 1.7f, -2.2f, 9), REF_NOISE3, 0);
    CHECK_NEAR(mvl_fbm2(10.1f, 20.2f, 3, 5, 2.0f, 0.5f), REF_FBM2, 0);
    CHECK_NEAR(mvl_fbm3(1.1f, 2.2f, 3.3f, 4, 4, 2.0f, 0.5f), REF_FBM3, 0);
    /* lattice points are continuous between neighbours, range is bounded */
    for (int i = 0; i < 2000; ++i) {
        float v = mvl_fbm2((float)i * 0.173f, (float)i * 0.071f, 11, 4, 2.0f, 0.5f);
        if (v < mn) mn = v;
        if (v > mx) mx = v;
    }
    CHECK(mn >= -1.0f && mx <= 1.0f && mx - mn > 0.5f);
    CHECK(fabsf(mvl_noise2(5.0f, 5.0f, 1) - mvl_noise2(5.0001f, 5.0f, 1)) < 0.01f);
    /* octave clamping */
    CHECK_NEAR(mvl_fbm2(1, 1, 1, 0, 2, 0.5f), mvl_fbm2(1, 1, 1, 1, 2, 0.5f), 0);
    CHECK_NEAR(mvl_fbm2(1, 1, 1, 99, 2, 0.5f), mvl_fbm2(1, 1, 1, 12, 2, 0.5f), 0);
    CHECK_NEAR(mvl_fbm3(1, 1, 1, 1, 0, 2, 0.5f), mvl_fbm3(1, 1, 1, 1, 1, 2, 0.5f), 0);
    CHECK_NEAR(mvl_fbm3(1, 1, 1, 1, 99, 2, 0.5f), mvl_fbm3(1, 1, 1, 1, 12, 2, 0.5f), 0);
}

void test_noise_periodic(void) {
    for (int i = 0; i < 50; ++i) {
        float x = (float)i * 0.37f, y = (float)i * 0.61f;
        CHECK_NEAR(mvl_noise2_periodic(x, y, 8, 4, 5), mvl_noise2_periodic(x + 8.0f, y + 4.0f, 8, 4, 5), 1e-4);
        CHECK_NEAR(mvl_noise2_periodic(x - 16.0f, y, 8, 4, 5), mvl_noise2_periodic(x, y, 8, 4, 5), 1e-4);
        CHECK_NEAR(mvl_fbm2_periodic(x, y, 4, 4, 2, 4, 0.5f), mvl_fbm2_periodic(x + 4.0f, y, 4, 4, 2, 4, 0.5f), 1e-4);
    }
    CHECK_NEAR(mvl_fbm2_periodic(1, 1, 4, 4, 2, 0, 0.5f), mvl_fbm2_periodic(1, 1, 4, 4, 2, 1, 0.5f), 0);
    CHECK_NEAR(mvl_fbm2_periodic(1, 1, 4, 4, 2, 50, 0.5f), mvl_fbm2_periodic(1, 1, 4, 4, 2, 8, 0.5f), 0);
}
