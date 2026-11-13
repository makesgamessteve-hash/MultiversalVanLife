/* Multiversal Van Life - deterministic hashing, random streams and noise.
 * MIT License.
 *
 * Everything here must give bit-identical results on every platform
 * (Windows, Linux, macOS, WebAssembly): integers are used for hashing and
 * random numbers, and noise uses only float add/mul on an integer lattice.
 * The core is compiled without floating point contraction (no FMA). */
#ifndef MVL_NOISE_H
#define MVL_NOISE_H

#include <stdint.h>

/* ----------------------------------------------------------- hashing */
uint32_t mvl_hash_u32(uint32_t x);
/* Mixes v into h (order sensitive). */
uint32_t mvl_hash_combine(uint32_t h, uint32_t v);
uint32_t mvl_hash3(uint32_t a, uint32_t b, uint32_t c);
uint32_t mvl_hash_str(const char *s, uint32_t seed);

/* ------------------------------------------------- random streams (PCG32) */
typedef struct {
    uint64_t state, inc;
} mvl_rng;

void mvl_rng_seed(mvl_rng *r, uint32_t seed, uint32_t stream);
uint32_t mvl_rng_u32(mvl_rng *r);
/* Uniform float in [0, 1). */
float mvl_rng_float(mvl_rng *r);
/* Uniform integer in [lo, hi] (inclusive). */
int32_t mvl_rng_range(mvl_rng *r, int32_t lo, int32_t hi);

/* ------------------------------------------------------------ noise */
/* Value noise in [-1, 1] on an integer lattice with quintic fade. */
float mvl_noise2(float x, float y, uint32_t seed);
float mvl_noise3(float x, float y, float z, uint32_t seed);
/* Lattice wraps every px / py cells, so the result tiles seamlessly. */
float mvl_noise2_periodic(float x, float y, int px, int py, uint32_t seed);
/* Fractal sum normalised to roughly [-1, 1]. */
float mvl_fbm2(float x, float y, uint32_t seed, int octaves, float lacunarity, float gain);
float mvl_fbm3(float x, float y, float z, uint32_t seed, int octaves, float lacunarity, float gain);
float mvl_fbm2_periodic(float x, float y, int px, int py, uint32_t seed, int octaves, float gain);

#endif
