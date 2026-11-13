/* Multiversal Van Life - MagicaVoxel .vox loader and voxel mesher. MIT License. */
#include "core/assets.h"
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

int mvl_voxels_mesh(const mvl_voxels *v, float s, mvl_mesh *out) {
    /* direction, neighbour offset, corner offsets (vox space), engine normal, shade */
    static const int dirs[6][3] = {{1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0}, {0, 0, 1}, {0, 0, -1}};
    static const int corners[6][4][3] = {
        {{1, 0, 0}, {1, 1, 0}, {1, 1, 1}, {1, 0, 1}},
        {{0, 1, 0}, {0, 0, 0}, {0, 0, 1}, {0, 1, 1}},
        {{1, 1, 0}, {0, 1, 0}, {0, 1, 1}, {1, 1, 1}},
        {{0, 0, 0}, {1, 0, 0}, {1, 0, 1}, {0, 0, 1}},
        {{0, 0, 1}, {1, 0, 1}, {1, 1, 1}, {0, 1, 1}},
        {{0, 1, 0}, {1, 1, 0}, {1, 0, 0}, {0, 0, 0}},
    };
    static const float shade[6] = {0.82f, 0.82f, 0.72f, 0.72f, 1.0f, 0.55f};
    float ox = v->sx * 0.5f, oy = v->sy * 0.5f;
    mvl_mesh_init(out);
    if (!v->cells) return 0;
    for (int z = 0; z < v->sz; ++z)
        for (int y = 0; y < v->sy; ++y)
            for (int x = 0; x < v->sx; ++x) {
                uint8_t c = mvl_voxels_get(v, x, y, z);
                uint32_t col;
                if (!c) continue;
                col = v->palette[c];
                for (int f = 0; f < 6; ++f) {
                    float p[4][3], n[3];
                    uint8_t rgba[4];
                    if (mvl_voxels_get(v, x + dirs[f][0], y + dirs[f][1], z + dirs[f][2])) continue;
                    for (int k = 0; k < 4; ++k) {
                        float vx = (float)(x + corners[f][k][0]), vy = (float)(y + corners[f][k][1]), vz = (float)(z + corners[f][k][2]);
                        p[k][0] = (vx - ox) * s;
                        p[k][1] = vz * s;
                        p[k][2] = -(vy - oy) * s;
                    }
                    n[0] = (float)dirs[f][0];
                    n[1] = (float)dirs[f][2];
                    n[2] = (float)-dirs[f][1];
                    rgba[0] = (uint8_t)((float)(col & 0xff) * shade[f]);
                    rgba[1] = (uint8_t)((float)((col >> 8) & 0xff) * shade[f]);
                    rgba[2] = (uint8_t)((float)((col >> 16) & 0xff) * shade[f]);
                    rgba[3] = 255;
                    mvl_mesh_add_quad(out, (const float(*)[3])p, n, 0, 0, 0, 0, rgba);
                }
            }
    mvl_mesh_compute_bounds(out);
    return out->count > 0;
}
