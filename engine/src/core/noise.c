/* Multiversal Van Life - deterministic hashing, random streams and noise.
 * MIT License. */
#include "core/noise.h"
#include <string.h>
#include <math.h>

uint32_t mvl_hash_u32(uint32_t x) {
    x ^= x >> 15;
    x *= 0x85ebca77u;
    x ^= x >> 13;
    x *= 0xc2b2ae3du;
    x ^= x >> 16;
    return x;
}

uint32_t mvl_hash_combine(uint32_t h, uint32_t v) {
    return mvl_hash_u32(h ^ (v + 0x9e3779b9u + (h << 6) + (h >> 2)));
}

uint32_t mvl_hash3(uint32_t a, uint32_t b, uint32_t c) {
    return mvl_hash_combine(mvl_hash_combine(mvl_hash_u32(a ^ 0x27d4eb2fu), b), c);
}

uint32_t mvl_hash_bytes(const void *data, size_t len, uint32_t seed) {
    uint32_t h = 2166136261u ^ seed;
    const unsigned char *p = (const unsigned char *)data;
    for (size_t i = 0; i < len; ++i) {
        h ^= p[i];
        h *= 16777619u;
    }
    return mvl_hash_u32(h);
}

uint32_t mvl_hash_str(const char *s, uint32_t seed) { return mvl_hash_bytes(s, s ? strlen(s) : 0, seed); }

void mvl_rng_seed(mvl_rng *r, uint32_t seed, uint32_t stream) {
    r->state = 0u;
    r->inc = ((uint64_t)stream << 1u) | 1u;
    mvl_rng_u32(r);
    r->state += seed;
    mvl_rng_u32(r);
}

uint32_t mvl_rng_u32(mvl_rng *r) {
    uint64_t old = r->state;
    uint32_t xorshifted, rot;
    r->state = old * 6364136223846793005ULL + r->inc;
    xorshifted = (uint32_t)(((old >> 18u) ^ old) >> 27u);
    rot = (uint32_t)(old >> 59u);
    return (xorshifted >> rot) | (xorshifted << ((32u - rot) & 31u));
}

float mvl_rng_float(mvl_rng *r) { return (float)(mvl_rng_u32(r) >> 8) * (1.0f / 16777216.0f); }

int32_t mvl_rng_range(mvl_rng *r, int32_t lo, int32_t hi) {
    uint32_t span;
    if (hi <= lo) return lo;
    span = (uint32_t)hi - (uint32_t)lo + 1u; /* unsigned: no signed overflow */
    if (span == 0u) return (int32_t)mvl_rng_u32(r); /* full 32-bit range */
    return lo + (int32_t)(mvl_rng_u32(r) % span);
}

/* --------------------------------------------------------------- noise */
static float lattice(int32_t x, int32_t y, int32_t z, uint32_t seed) {
    uint32_t h = mvl_hash_combine(mvl_hash_combine(mvl_hash_combine(seed, (uint32_t)x), (uint32_t)y), (uint32_t)z);
    return (float)(h & 0xffffffu) * (2.0f / 16777215.0f) - 1.0f;
}

static float fade(float t) { return t * t * t * (t * (t * 6.0f - 15.0f) + 10.0f); }
static float mix(float a, float b, float t) { return a + (b - a) * t; }

static float noise2_wrap(float x, float y, int px, int py, uint32_t seed) {
    float fx = floorf(x), fy = floorf(y);
    int32_t ix = (int32_t)fx, iy = (int32_t)fy;
    int32_t ix1 = ix + 1, iy1 = iy + 1;
    float tx = fade(x - fx), ty = fade(y - fy);
    if (px > 0) {
        ix = ((ix % px) + px) % px;
        ix1 = ((ix1 % px) + px) % px;
    }
    if (py > 0) {
        iy = ((iy % py) + py) % py;
        iy1 = ((iy1 % py) + py) % py;
    }
    return mix(mix(lattice(ix, iy, 0, seed), lattice(ix1, iy, 0, seed), tx),
               mix(lattice(ix, iy1, 0, seed), lattice(ix1, iy1, 0, seed), tx), ty);
}

float mvl_noise2(float x, float y, uint32_t seed) { return noise2_wrap(x, y, 0, 0, seed); }

float mvl_noise2_periodic(float x, float y, int px, int py, uint32_t seed) {
    return noise2_wrap(x, y, px, py, seed);
}

float mvl_noise3(float x, float y, float z, uint32_t seed) {
    float fx = floorf(x), fy = floorf(y), fz = floorf(z);
    int32_t ix = (int32_t)fx, iy = (int32_t)fy, iz = (int32_t)fz;
    float tx = fade(x - fx), ty = fade(y - fy), tz = fade(z - fz);
    float a = mix(mix(lattice(ix, iy, iz, seed), lattice(ix + 1, iy, iz, seed), tx),
                  mix(lattice(ix, iy + 1, iz, seed), lattice(ix + 1, iy + 1, iz, seed), tx), ty);
    float b = mix(mix(lattice(ix, iy, iz + 1, seed), lattice(ix + 1, iy, iz + 1, seed), tx),
                  mix(lattice(ix, iy + 1, iz + 1, seed), lattice(ix + 1, iy + 1, iz + 1, seed), tx), ty);
    return mix(a, b, tz);
}

float mvl_fbm2(float x, float y, uint32_t seed, int octaves, float lacunarity, float gain) {
    float sum = 0.0f, amp = 1.0f, norm = 0.0f;
    if (octaves < 1) octaves = 1;
    if (octaves > 12) octaves = 12;
    for (int i = 0; i < octaves; ++i) {
        sum += mvl_noise2(x, y, seed + (uint32_t)i * 1013u) * amp;
        norm += amp;
        x *= lacunarity;
        y *= lacunarity;
        amp *= gain;
    }
    return sum / norm;
}

float mvl_fbm3(float x, float y, float z, uint32_t seed, int octaves, float lacunarity, float gain) {
    float sum = 0.0f, amp = 1.0f, norm = 0.0f;
    if (octaves < 1) octaves = 1;
    if (octaves > 12) octaves = 12;
    for (int i = 0; i < octaves; ++i) {
        sum += mvl_noise3(x, y, z, seed + (uint32_t)i * 1013u) * amp;
        norm += amp;
        x *= lacunarity;
        y *= lacunarity;
        z *= lacunarity;
        amp *= gain;
    }
    return sum / norm;
}

float mvl_fbm2_periodic(float x, float y, int px, int py, uint32_t seed, int octaves, float gain) {
    float sum = 0.0f, amp = 1.0f, norm = 0.0f;
    if (octaves < 1) octaves = 1;
    if (octaves > 8) octaves = 8;
    for (int i = 0; i < octaves; ++i) {
        sum += mvl_noise2_periodic(x, y, px, py, seed + (uint32_t)i * 1013u) * amp;
        norm += amp;
        x *= 2.0f;
        y *= 2.0f;
        px *= 2;
        py *= 2;
        amp *= gain;
    }
    return sum / norm;
}
