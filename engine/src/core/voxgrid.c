/* Multiversal Van Life - runtime voxel modelling. MIT License. */
#include "core/assets.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>

int mvl_voxels_alloc(mvl_voxels *v, int sx, int sy, int sz) {
    memset(v, 0, sizeof *v);
    if (sx < 1 || sy < 1 || sz < 1 || sx > MVL_VOXGRID_MAX || sy > MVL_VOXGRID_MAX || sz > MVL_VOXGRID_MAX) return 0;
    v->cells = (uint8_t *)calloc((size_t)sx * (size_t)sy * (size_t)sz, 1);
    if (!v->cells) return 0;
    v->sx = sx;
    v->sy = sy;
    v->sz = sz;
    mvl_voxels_default_palette(v->palette);
    return 1;
}

void mvl_voxels_set(mvl_voxels *v, int x, int y, int z, uint8_t c) {
    if (x < 0 || y < 0 || z < 0 || x >= v->sx || y >= v->sy || z >= v->sz) return;
    v->cells[((size_t)z * v->sy + y) * v->sx + x] = c;
}

static void order(int *a, int *b) {
    if (*a > *b) {
        int t = *a;
        *a = *b;
        *b = t;
    }
}

void mvl_voxels_fill_box(mvl_voxels *v, int x0, int y0, int z0, int x1, int y1, int z1, uint8_t c) {
    order(&x0, &x1);
    order(&y0, &y1);
    order(&z0, &z1);
    if (x0 < 0) x0 = 0;
    if (y0 < 0) y0 = 0;
    if (z0 < 0) z0 = 0;
    if (x1 >= v->sx) x1 = v->sx - 1;
    if (y1 >= v->sy) y1 = v->sy - 1;
    if (z1 >= v->sz) z1 = v->sz - 1;
    for (int z = z0; z <= z1; ++z)
        for (int y = y0; y <= y1; ++y)
            for (int x = x0; x <= x1; ++x) v->cells[((size_t)z * v->sy + y) * v->sx + x] = c;
}

void mvl_voxels_fill_ellipsoid(mvl_voxels *v, float cx, float cy, float cz, float rx, float ry, float rz, uint8_t c) {
    int x0, x1, y0, y1, z0, z1;
    if (rx <= 0 || ry <= 0 || rz <= 0) return;
    x0 = (int)floorf(cx - rx);
    x1 = (int)ceilf(cx + rx);
    y0 = (int)floorf(cy - ry);
    y1 = (int)ceilf(cy + ry);
    z0 = (int)floorf(cz - rz);
    z1 = (int)ceilf(cz + rz);
    for (int z = z0; z <= z1; ++z)
        for (int y = y0; y <= y1; ++y)
            for (int x = x0; x <= x1; ++x) {
                float dx = ((float)x + 0.5f - cx) / rx, dy = ((float)y + 0.5f - cy) / ry, dz = ((float)z + 0.5f - cz) / rz;
                if (dx * dx + dy * dy + dz * dz <= 1.0f) mvl_voxels_set(v, x, y, z, c);
            }
}

void mvl_voxels_fill_cylinder(mvl_voxels *v, float cx, float cy, int z0, int z1, float r, uint8_t c) {
    int x0 = (int)floorf(cx - r), x1 = (int)ceilf(cx + r), y0 = (int)floorf(cy - r), y1 = (int)ceilf(cy + r);
    if (r <= 0) return;
    order(&z0, &z1);
    for (int z = z0; z <= z1; ++z)
        for (int y = y0; y <= y1; ++y)
            for (int x = x0; x <= x1; ++x) {
                float dx = (float)x + 0.5f - cx, dy = (float)y + 0.5f - cy;
                if (dx * dx + dy * dy <= r * r) mvl_voxels_set(v, x, y, z, c);
            }
}

void mvl_voxels_fill_line(mvl_voxels *v, float x0, float y0, float z0, float x1, float y1, float z1, float radius, uint8_t c) {
    float dx = x1 - x0, dy = y1 - y0, dz = z1 - z0;
    float len = fabsf(dx);
    int steps;
    if (fabsf(dy) > len) len = fabsf(dy);
    if (fabsf(dz) > len) len = fabsf(dz);
    steps = (int)ceilf(len * 2.0f);
    if (steps < 1) steps = 1;
    for (int i = 0; i <= steps; ++i) {
        float t = (float)i / (float)steps;
        float px = x0 + dx * t, py = y0 + dy * t, pz = z0 + dz * t;
        if (radius < 0.75f) mvl_voxels_set(v, (int)floorf(px), (int)floorf(py), (int)floorf(pz), c);
        else mvl_voxels_fill_ellipsoid(v, px, py, pz, radius, radius, radius, c);
    }
}

void mvl_voxels_mirror_x(mvl_voxels *v) {
    for (int z = 0; z < v->sz; ++z)
        for (int y = 0; y < v->sy; ++y)
            for (int x = 0; x < v->sx / 2; ++x) {
                size_t row = ((size_t)z * v->sy + y) * v->sx;
                v->cells[row + (size_t)(v->sx - 1 - x)] = v->cells[row + (size_t)x];
            }
}

int mvl_voxels_replace(mvl_voxels *v, uint8_t from, uint8_t to) {
    int n = 0;
    size_t total = (size_t)v->sx * v->sy * v->sz;
    for (size_t i = 0; i < total; ++i)
        if (v->cells[i] == from) {
            v->cells[i] = to;
            ++n;
        }
    return n;
}

void mvl_voxels_set_color(mvl_voxels *v, int index, uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
    if (index < 1 || index > 255) return;
    v->palette[index] = (uint32_t)r | ((uint32_t)g << 8) | ((uint32_t)b << 16) | ((uint32_t)a << 24);
}

int mvl_voxels_count(const mvl_voxels *v) {
    int n = 0;
    size_t total = (size_t)v->sx * v->sy * v->sz;
    for (size_t i = 0; i < total; ++i) n += v->cells[i] != 0;
    return n;
}
