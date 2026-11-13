/* Multiversal Van Life - deterministic terrain height field and chunk meshes.
 * MIT License. */
#include "core/terrain.h"
#include "core/noise.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>

void mvl_terrain_init(mvl_terrain *t, uint32_t seed) {
    static const uint8_t greens[3][4] = {{62, 88, 46, 255}, {84, 112, 58, 255}, {120, 128, 92, 255}};
    memset(t, 0, sizeof *t);
    t->seed = seed;
    t->amp = 3.0f;
    t->freq = 0.02f;
    t->octaves = 4;
    t->lacunarity = 2.0f;
    t->gain = 0.5f;
    t->color_low = -3.0f;
    t->color_high = 6.0f;
    memcpy(t->palette, greens, sizeof greens);
    t->palette_count = 3;
    t->slope_color[0] = 110;
    t->slope_color[1] = 100;
    t->slope_color[2] = 90;
    t->slope_color[3] = 255;
    t->slope_start = 0.25f;
    t->color_noise = 0.12f;
    t->uv_scale = 4.0f;
}

int mvl_terrain_set_map(mvl_terrain *t, const float *data, int w, int h, float x0, float z0, float cell) {
    float *copy;
    if (!data || w < 2 || h < 2 || cell <= 0.0f || (size_t)w * (size_t)h > (size_t)1 << 22) return 0;
    copy = (float *)malloc(sizeof(float) * (size_t)w * (size_t)h);
    if (!copy) return 0;
    memcpy(copy, data, sizeof(float) * (size_t)w * (size_t)h);
    free(t->map);
    t->map = copy;
    t->map_w = w;
    t->map_h = h;
    t->map_x0 = x0;
    t->map_z0 = z0;
    t->map_cell = cell;
    return 1;
}

void mvl_terrain_free(mvl_terrain *t) {
    free(t->map);
    t->map = NULL;
    t->map_w = t->map_h = 0;
}

int mvl_terrain_add_flat(mvl_terrain *t, float x, float z, float radius, float falloff, float height) {
    mvl_terrain_flat *f;
    if (t->flat_count >= MVL_TERRAIN_MAX_FLATS) return 0;
    f = &t->flats[t->flat_count++];
    f->x = x;
    f->z = z;
    f->radius = radius < 0 ? 0 : radius;
    f->falloff = falloff < 0.001f ? 0.001f : falloff;
    f->height = height;
    f->segment = 0;
    return 1;
}

int mvl_terrain_add_segment(mvl_terrain *t, float x, float z, float x2, float z2, float radius, float falloff,
                            float height, float height2) {
    mvl_terrain_flat *f;
    if (!mvl_terrain_add_flat(t, x, z, radius, falloff, height)) return 0;
    f = &t->flats[t->flat_count - 1];
    f->x2 = x2;
    f->z2 = z2;
    f->height2 = height2;
    f->segment = 1;
    return 1;
}

static float map_at(const mvl_terrain *t, int x, int z) {
    if (x < 0) x = 0;
    if (z < 0) z = 0;
    if (x >= t->map_w) x = t->map_w - 1;
    if (z >= t->map_h) z = t->map_h - 1;
    return t->map[(size_t)z * (size_t)t->map_w + (size_t)x];
}

/* Catmull-Rom cubic */
static float cubic(float p0, float p1, float p2, float p3, float s) {
    return p1 + 0.5f * s * (p2 - p0 + s * (2.0f * p0 - 5.0f * p1 + 4.0f * p2 - p3 + s * (3.0f * (p1 - p2) + p3 - p0)));
}

static float sample_map(const mvl_terrain *t, float x, float z) {
    float gx = (x - t->map_x0) / t->map_cell, gz = (z - t->map_z0) / t->map_cell;
    float fx = floorf(gx), fz = floorf(gz), sx = gx - fx, sz = gz - fz, rows[4];
    int ix = (int)fx, iz = (int)fz;
    for (int j = 0; j < 4; ++j)
        rows[j] = cubic(map_at(t, ix - 1, iz - 1 + j), map_at(t, ix, iz - 1 + j), map_at(t, ix + 1, iz - 1 + j),
                        map_at(t, ix + 2, iz - 1 + j), sx);
    return cubic(rows[0], rows[1], rows[2], rows[3], sz);
}

float mvl_terrain_height(const mvl_terrain *t, float x, float z) {
    float nx = x + t->origin_x, nz = z + t->origin_z;
    float h = t->base + t->amp * mvl_fbm2(nx * t->freq, nz * t->freq, t->seed, t->octaves, t->lacunarity, t->gain);
    if (t->map) h += sample_map(t, nx, nz);
    for (int i = 0; i < t->flat_count; ++i) {
        const mvl_terrain_flat *f = &t->flats[i];
        float dx = x - f->x, dz = z - f->z, d, w, target = f->height;
        if (f->segment) {
            /* distance to the segment and the height along it */
            float sx = f->x2 - f->x, sz = f->z2 - f->z, len2 = sx * sx + sz * sz;
            float s = len2 > 0.0f ? (dx * sx + dz * sz) / len2 : 0.0f;
            if (s < 0.0f) s = 0.0f;
            if (s > 1.0f) s = 1.0f;
            dx -= sx * s;
            dz -= sz * s;
            target = f->height + (f->height2 - f->height) * s;
        }
        d = sqrtf(dx * dx + dz * dz);
        if (d <= f->radius) w = 1.0f;
        else if (d >= f->radius + f->falloff) continue;
        else {
            float s = 1.0f - (d - f->radius) / f->falloff;
            w = s * s * (3.0f - 2.0f * s);
        }
        h = h + (target - h) * w;
    }
    return h;
}

static void terrain_color(const mvl_terrain *t, float x, float z, float h, float ny, uint8_t out[4]) {
    float c[3], k, slope, bright;
    int n = t->palette_count < 1 ? 1 : (t->palette_count > MVL_TERRAIN_PALETTE ? MVL_TERRAIN_PALETTE : t->palette_count);
    float range = t->color_high - t->color_low;
    float u = range > 0.0f ? (h - t->color_low) / range : 0.0f;
    int i0;
    if (u < 0.0f) u = 0.0f;
    if (u > 1.0f) u = 1.0f;
    u *= (float)(n - 1);
    i0 = (int)u;
    if (i0 >= n - 1) i0 = n > 1 ? n - 2 : 0;
    k = n > 1 ? u - (float)i0 : 0.0f;
    for (int ch = 0; ch < 3; ++ch) {
        float a = t->palette[i0][ch], b = t->palette[n > 1 ? i0 + 1 : 0][ch];
        c[ch] = a + (b - a) * k;
    }
    slope = 1.0f - ny;
    if (slope > t->slope_start) {
        float w = (slope - t->slope_start) / (1.0f - t->slope_start + 1e-6f) * 3.0f;
        if (w > 1.0f) w = 1.0f;
        for (int ch = 0; ch < 3; ++ch) c[ch] += ((float)t->slope_color[ch] - c[ch]) * w;
    }
    bright = 1.0f + t->color_noise * mvl_noise2(x * 0.37f, z * 0.37f, t->seed ^ 0x5bd1e995u);
    for (int ch = 0; ch < 3; ++ch) {
        float v = c[ch] * bright;
        out[ch] = (uint8_t)(v < 0.0f ? 0.0f : (v > 255.0f ? 255.0f : v));
    }
    out[3] = 255;
}

int mvl_terrain_build_chunk(const mvl_terrain *t, int cx, int cz, float size, int cells, mvl_mesh *out) {
    int n, vcount;
    float step, eps;
    mvl_vertex *grid;
    mvl_mesh_init(out);
    if (cells < 1 || cells > 128 || size <= 0.0f) return 0;
    n = cells + 1;
    vcount = n * n;
    step = size / (float)cells;
    eps = step * 0.5f;
    grid = (mvl_vertex *)malloc(sizeof(mvl_vertex) * (size_t)vcount);
    if (!grid) return 0;
    for (int j = 0; j < n; ++j)
        for (int i = 0; i < n; ++i) {
            /* world coordinates from integer grid indices: identical on shared borders */
            float wx = (float)(cx * cells + i) * step, wz = (float)(cz * cells + j) * step;
            float h = mvl_terrain_height(t, wx, wz);
            float hl = mvl_terrain_height(t, wx - eps, wz), hr = mvl_terrain_height(t, wx + eps, wz);
            float hd = mvl_terrain_height(t, wx, wz - eps), hu = mvl_terrain_height(t, wx, wz + eps);
            float nx = hl - hr, ny = 2.0f * eps, nz = hd - hu, len = sqrtf(nx * nx + ny * ny + nz * nz);
            mvl_vertex *v = &grid[j * n + i];
            v->pos[0] = (float)i * step;
            v->pos[1] = h;
            v->pos[2] = (float)j * step;
            v->normal[0] = nx / len;
            v->normal[1] = ny / len;
            v->normal[2] = nz / len;
            v->uv[0] = wx / t->uv_scale;
            v->uv[1] = wz / t->uv_scale;
            terrain_color(t, wx, wz, h, v->normal[1], v->color);
        }
    for (int j = 0; j < cells; ++j)
        for (int i = 0; i < cells; ++i) {
            const mvl_vertex *a = &grid[j * n + i], *b = &grid[j * n + i + 1];
            const mvl_vertex *c = &grid[(j + 1) * n + i], *d = &grid[(j + 1) * n + i + 1];
            /* counter-clockwise seen from above (+Y): a(0,0) c(0,1) d(1,1) b(1,0) */
            mvl_mesh_push(out, a);
            mvl_mesh_push(out, c);
            mvl_mesh_push(out, d);
            mvl_mesh_push(out, a);
            mvl_mesh_push(out, d);
            mvl_mesh_push(out, b);
        }
    free(grid);
    mvl_mesh_compute_bounds(out);
    return 1;
}
