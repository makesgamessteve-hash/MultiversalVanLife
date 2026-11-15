/* Multiversal Van Life - MagicaVoxel .vox loader and voxel mesher. MIT License. */
#include "core/assets.h"
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

static uint32_t rd32(const uint8_t *p) { return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24); }

void mvl_voxels_default_palette(uint32_t *pal) {
    /* Simple fallback: a 6x6x6 colour cube followed by greys. */
    pal[0] = 0;
    for (int i = 1; i < 256; ++i) {
        uint32_t r, g, b;
        if (i <= 216) {
            int c = i - 1;
            r = (uint32_t)((c % 6) * 51);
            g = (uint32_t)(((c / 6) % 6) * 51);
            b = (uint32_t)((c / 36) * 51);
        } else {
            r = g = b = (uint32_t)((i - 216) * 6);
        }
        pal[i] = 0xff000000u | (b << 16) | (g << 8) | r;
    }
}

int mvl_voxels_load_vox(const void *data, size_t size, mvl_voxels *out) {
    const uint8_t *d = (const uint8_t *)data, *p, *end;
    int have_size = 0, have_xyzi = 0;
    memset(out, 0, sizeof *out);
    mvl_voxels_default_palette(out->palette);
    if (!d || size < 20 || memcmp(d, "VOX ", 4)) return 0;
    if (memcmp(d + 8, "MAIN", 4)) return 0;
    p = d + 20; /* skip MAIN header (id, content, children) */
    end = d + size;
    while (end - p >= 12) {
        uint32_t clen = rd32(p + 4), chlen = rd32(p + 8);
        const uint8_t *body = p + 12;
        if ((uint64_t)clen > (uint64_t)(end - body)) break;
        if (!memcmp(p, "SIZE", 4) && clen >= 12 && !have_size) {
            out->sx = (int)rd32(body);
            out->sy = (int)rd32(body + 4);
            out->sz = (int)rd32(body + 8);
            if (out->sx <= 0 || out->sy <= 0 || out->sz <= 0 || out->sx > 256 || out->sy > 256 || out->sz > 256) {
                mvl_voxels_free(out);
                return 0;
            }
            out->cells = (uint8_t *)calloc((size_t)out->sx * out->sy * out->sz, 1);
            if (!out->cells) return 0;
            have_size = 1;
        } else if (!memcmp(p, "XYZI", 4) && clen >= 4 && have_size && !have_xyzi) {
            uint32_t n = rd32(body);
            if ((uint64_t)n * 4 > clen - 4) n = (clen - 4) / 4;
            for (uint32_t i = 0; i < n; ++i) {
                const uint8_t *v = body + 4 + i * 4;
                if (v[0] < out->sx && v[1] < out->sy && v[2] < out->sz)
                    out->cells[((size_t)v[2] * out->sy + v[1]) * out->sx + v[0]] = v[3];
            }
            have_xyzi = 1;
        } else if (!memcmp(p, "RGBA", 4) && clen >= 1024) {
            for (int i = 0; i < 255; ++i) {
                const uint8_t *c = body + i * 4;
                out->palette[i + 1] = (uint32_t)c[0] | ((uint32_t)c[1] << 8) | ((uint32_t)c[2] << 16) | ((uint32_t)c[3] << 24);
            }
        }
        p = body + clen;
        (void)chlen; /* children of non-MAIN chunks are flattened in the stream */
    }
    if (!have_size || !have_xyzi) {
        mvl_voxels_free(out);
        return 0;
    }
    return 1;
}

void mvl_voxels_free(mvl_voxels *v) {
    free(v->cells);
    v->cells = NULL;
    v->sx = v->sy = v->sz = 0;
}

uint8_t mvl_voxels_get(const mvl_voxels *v, int x, int y, int z) {
    if (x < 0 || y < 0 || z < 0 || x >= v->sx || y >= v->sy || z >= v->sz) return 0;
    return v->cells[((size_t)z * v->sy + y) * v->sx + x];
}

/* Faces of the voxel mesh: per face direction f (+x, -x, +y, -y, +z, -z),
 * corner offsets of a unit face in voxel space, and a shade. */
static const int vox_dirs[6][3] = {{1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0}, {0, 0, 1}, {0, 0, -1}};
static const int vox_corners[6][4][3] = {
    {{1, 0, 0}, {1, 1, 0}, {1, 1, 1}, {1, 0, 1}},
    {{0, 1, 0}, {0, 0, 0}, {0, 0, 1}, {0, 1, 1}},
    {{1, 1, 0}, {0, 1, 0}, {0, 1, 1}, {1, 1, 1}},
    {{0, 0, 0}, {1, 0, 0}, {1, 0, 1}, {0, 0, 1}},
    {{0, 0, 1}, {1, 0, 1}, {1, 1, 1}, {0, 1, 1}},
    {{0, 1, 0}, {1, 1, 0}, {1, 0, 0}, {0, 0, 0}},
};
static const float vox_shade[6] = {0.82f, 0.82f, 0.72f, 0.72f, 1.0f, 0.55f};

/* Emits the faces marked in `mask` (colour per cell of slice `sl` along the
 * axis of face direction f, 0 = none) as greedy rectangles. */
static void emit(const mvl_voxels *v, mvl_mesh *out, uint8_t *mask, int f, int sl, const int lo[3], const int hi[3],
                 int su, float s, float ox, float oy) {
    int d = f >> 1, u = (d + 1) % 3, w = (d + 2) % 3;
    for (int b = lo[w]; b <= hi[w]; ++b)
        for (int a = lo[u]; a <= hi[u]; ++a) {
            uint8_t c = mask[(size_t)b * (size_t)su + (size_t)a];
            int wd = 1, hh = 1;
            float q[4][3], n[3];
            uint8_t rgba[4];
            uint32_t col;
            if (!c) continue;
            while (a + wd <= hi[u] && wd < MVL_VOX_MERGE && mask[(size_t)b * (size_t)su + (size_t)(a + wd)] == c) ++wd;
            while (b + hh <= hi[w] && hh < MVL_VOX_MERGE) {
                int full = 1;
                for (int k = 0; k < wd && full; ++k)
                    if (mask[(size_t)(b + hh) * (size_t)su + (size_t)(a + k)] != c) full = 0;
                if (!full) break;
                ++hh;
            }
            for (int y = 0; y < hh; ++y) memset(mask + (size_t)(b + y) * (size_t)su + (size_t)a, 0, (size_t)wd);
            for (int k = 0; k < 4; ++k) {
                float c3[3];
                c3[d] = (float)(sl + vox_corners[f][k][d]);
                c3[u] = (float)(a + vox_corners[f][k][u] * wd);
                c3[w] = (float)(b + vox_corners[f][k][w] * hh);
                q[k][0] = (c3[0] - ox) * s;
                q[k][1] = c3[2] * s;
                q[k][2] = -(c3[1] - oy) * s;
            }
            col = v->palette[c];
            n[0] = (float)vox_dirs[f][0];
            n[1] = (float)vox_dirs[f][2];
            n[2] = (float)-vox_dirs[f][1];
            rgba[0] = (uint8_t)((float)(col & 0xff) * vox_shade[f]);
            rgba[1] = (uint8_t)((float)((col >> 8) & 0xff) * vox_shade[f]);
            rgba[2] = (uint8_t)((float)((col >> 16) & 0xff) * vox_shade[f]);
            rgba[3] = 255;
            mvl_mesh_add_quad(out, (const float(*)[3])q, n, 0, 0, 0, 0, rgba);
        }
}

int mvl_voxels_mesh(const mvl_voxels *v, float s, mvl_mesh *out) {
    const int size[3] = {v->sx, v->sy, v->sz};
    const size_t stride[3] = {1, (size_t)v->sx, (size_t)v->sx * (size_t)v->sy};
    float ox = v->sx * 0.5f, oy = v->sy * 0.5f;
    size_t area = 0;
    int box_lo[3], box_hi[3];
    uint8_t *mask, *mask2;
    mvl_mesh_init(out);
    if (!v->cells) return 0;
    for (int d = 0; d < 3; ++d) {
        size_t a = (size_t)size[(d + 1) % 3] * (size_t)size[(d + 2) % 3];
        if (a > area) area = a;
    }
    mask = (uint8_t *)malloc(area * 2);
    if (!mask) return 0;
    mask2 = mask + area;
    /* only the occupied part of the grid is scanned */
    {
        int lo[3] = {v->sx, v->sy, v->sz}, hi[3] = {-1, -1, -1};
        const uint8_t *cell = v->cells;
        for (int z = 0; z < v->sz; ++z)
            for (int y = 0; y < v->sy; ++y)
                for (int x = 0; x < v->sx; ++x, ++cell)
                    if (*cell) {
                        if (x < lo[0]) lo[0] = x;
                        if (x > hi[0]) hi[0] = x;
                        if (y < lo[1]) lo[1] = y;
                        if (y > hi[1]) hi[1] = y;
                        if (z < lo[2]) lo[2] = z;
                        if (z > hi[2]) hi[2] = z;
                    }
        if (hi[0] < 0) {
            free(mask);
            mvl_mesh_compute_bounds(out);
            return 0;
        }
        memcpy(box_lo, lo, sizeof lo);
        memcpy(box_hi, hi, sizeof hi);
    }
    /* greedy meshing: per axis and slice, the visible faces of both
     * directions are found in one scan; faces of one colour are merged into
     * rectangles of at most MVL_VOX_MERGE voxels a side (vertex lighting
     * keeps a point every few metres) */
    for (int d = 0; d < 3; ++d) {
        int u = (d + 1) % 3, w = (d + 2) % 3;
        int su = size[u];
        for (int sl = box_lo[d]; sl <= box_hi[d]; ++sl) {
            int has_next = sl + 1 < size[d], has_prev = sl > 0;
            for (int b = box_lo[w]; b <= box_hi[w]; ++b) {
                const uint8_t *row = v->cells + (size_t)sl * stride[d] + (size_t)b * stride[w];
                uint8_t *mp = mask + (size_t)b * (size_t)su, *mn = mask2 + (size_t)b * (size_t)su;
                for (int a = box_lo[u]; a <= box_hi[u]; ++a) {
                    const uint8_t *cell = row + (size_t)a * stride[u];
                    uint8_t c = *cell;
                    mp[a] = (c && !(has_next && cell[stride[d]])) ? c : 0;
                    mn[a] = (c && !(has_prev && *(cell - stride[d]))) ? c : 0;
                }
            }
            for (int side = 0; side < 2; ++side)
                emit(v, out, side ? mask2 : mask, d * 2 + side, sl, box_lo, box_hi, su, s, ox, oy);
        }
    }
    free(mask);
    mvl_mesh_compute_bounds(out);
    return out->count > 0;
}
