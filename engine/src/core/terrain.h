/* Multiversal Van Life - deterministic terrain height field and chunk meshes.
 * MIT License.
 *
 * height(x, z) = base + amp * fbm((x + origin_x) * freq, (z + origin_z) * freq)
 *              + coarse elevation map (bicubic, optional)
 * then blended towards up to MVL_TERRAIN_MAX_FLATS flat areas: discs at one
 * height, or segments (roads) whose height runs from one end to the other.
 * Chunk vertices are computed from integer grid coordinates, so the shared
 * border of two neighbouring chunks is bit-identical (no cracks). */
#ifndef MVL_TERRAIN_H
#define MVL_TERRAIN_H

#include "core/assets.h"
#include <stdint.h>

#define MVL_TERRAIN_MAX_FLATS 128
#define MVL_TERRAIN_PALETTE 4

typedef struct {
    float x, z, radius, falloff, height;
    float x2, z2, height2; /* segment end (segment flats only) */
    int segment;
} mvl_terrain_flat;

typedef struct {
    uint32_t seed;
    float base, amp, freq, lacunarity, gain;
    float origin_x, origin_z; /* added to x, z before sampling the noise */
    int octaves;
    /* optional coarse elevation map (row-major, w x h samples) */
    float *map;
    int map_w, map_h;
    float map_x0, map_z0, map_cell;
    mvl_terrain_flat flats[MVL_TERRAIN_MAX_FLATS];
    int flat_count;
    /* vertex colouring */
    float color_low, color_high;              /* heights mapped to palette 0..n-1 */
    uint8_t palette[MVL_TERRAIN_PALETTE][4];
    int palette_count;
    uint8_t slope_color[4];
    float slope_start;                        /* 1 - normal.y where slope colour starts */
    float color_noise;                        /* brightness variation 0..1 */
    float uv_scale;                           /* metres per texture repeat */
} mvl_terrain;

/* Sets sensible defaults (gentle hills, green palette). Does not own a map. */
void mvl_terrain_init(mvl_terrain *t, uint32_t seed);
/* Copies a coarse map into the terrain (freeing a previous one). */
int mvl_terrain_set_map(mvl_terrain *t, const float *data, int w, int h, float x0, float z0, float cell);
void mvl_terrain_free(mvl_terrain *t);
int mvl_terrain_add_flat(mvl_terrain *t, float x, float z, float radius, float falloff, float height);
/* A flattened band of half width `radius` along the segment (x, z)-(x2, z2),
 * its height running linearly from `height` to `height2`. */
int mvl_terrain_add_segment(mvl_terrain *t, float x, float z, float x2, float z2, float radius, float falloff,
                            float height, float height2);

float mvl_terrain_height(const mvl_terrain *t, float x, float z);
/* Builds chunk (cx, cz) of `size` metres with `cells` x `cells` quads. Vertex
 * positions are local to the chunk origin (cx * size, 0, cz * size). */
int mvl_terrain_build_chunk(const mvl_terrain *t, int cx, int cz, float size, int cells, mvl_mesh *out);

#endif
