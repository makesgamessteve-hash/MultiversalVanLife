/* Multiversal Van Life - mesh container, OBJ loader and builders. MIT License. */
#include "core/assets.h"
#include <stdlib.h>
#include <string.h>

static const uint8_t WHITE[4] = {255, 255, 255, 255};

void mvl_mesh_init(mvl_mesh *m) { memset(m, 0, sizeof *m); }

void mvl_mesh_free(mvl_mesh *m) {
    free(m->v);
    memset(m, 0, sizeof *m);
}

int mvl_mesh_push(mvl_mesh *m, const mvl_vertex *v) {
    if (m->count == m->cap) {
        int ncap = m->cap ? m->cap * 2 : 64;
        mvl_vertex *n = (mvl_vertex *)realloc(m->v, sizeof(mvl_vertex) * (size_t)ncap);
        if (!n) return 0;
        m->v = n;
        m->cap = ncap;
    }
    m->v[m->count++] = *v;
    return 1;
}

void mvl_mesh_compute_bounds(mvl_mesh *m) {
    for (int k = 0; k < 3; ++k) m->min[k] = m->max[k] = 0.0f;
    for (int i = 0; i < m->count; ++i)
        for (int k = 0; k < 3; ++k) {
            float p = m->v[i].pos[k];
            if (i == 0 || p < m->min[k]) m->min[k] = p;
            if (i == 0 || p > m->max[k]) m->max[k] = p;
        }
}

/* ------------------------------------------------------------------ OBJ */
typedef struct {
    float *d;
    int count, cap, stride;
} farr;

static int farr_push(farr *a, const float *vals) {
    if (a->count == a->cap) {
        int ncap = a->cap ? a->cap * 2 : 64;
        float *n = (float *)realloc(a->d, sizeof(float) * (size_t)(ncap * a->stride));
        if (!n) return 0;
        a->d = n;
        a->cap = ncap;
    }
    memcpy(a->d + a->count * a->stride, vals, sizeof(float) * (size_t)a->stride);
    a->count++;
    return 1;
}

static int resolve_index(long idx, int count) {
    if (idx > 0) return idx <= count ? (int)idx - 1 : -1;
    if (idx < 0) return (int)(count + idx) >= 0 ? (int)(count + idx) : -1;
    return -1;
}

/* Parses "v", "v/t", "v//n" or "v/t/n" into a vertex. */
static int parse_face_vertex(const char **pp, farr *pos, farr *uv, farr *nrm, mvl_vertex *out) {
    const char *p = *pp;
    char *end;
    long vi, ti = 0, ni = 0;
    int i;
    vi = strtol(p, &end, 10);
    if (end == p) return 0;
    p = end;
    if (*p == '/') {
        ++p;
        if (*p != '/') {
            ti = strtol(p, &end, 10);
            p = end;
        }
        if (*p == '/') {
            ++p;
            ni = strtol(p, &end, 10);
            p = end;
        }
    }
    *pp = p;
    memset(out, 0, sizeof *out);
    memcpy(out->color, WHITE, 4);
    i = resolve_index(vi, pos->count);
    if (i < 0) return -1;
    memcpy(out->pos, pos->d + i * 3, sizeof(float) * 3);
    if (ti) {
        i = resolve_index(ti, uv->count);
        if (i < 0) return -1;
        out->uv[0] = uv->d[i * 2];
        out->uv[1] = 1.0f - uv->d[i * 2 + 1];
    }
    if (ni) {
        i = resolve_index(ni, nrm->count);
        if (i < 0) return -1;
        memcpy(out->normal, nrm->d + i * 3, sizeof(float) * 3);
    } else {
        out->normal[1] = 1.0f;
    }
    return 1;
}

int mvl_mesh_load_obj(const char *text, mvl_mesh *out) {
    farr pos = {0, 0, 0, 3}, uv = {0, 0, 0, 2}, nrm = {0, 0, 0, 3};
    const char *p = text;
    int ok = 1;
    mvl_mesh_init(out);
    if (!text) return 0;
    while (*p && ok) {
        while (*p == ' ' || *p == '\t') ++p;
        if (p[0] == 'v' && (p[1] == ' ' || p[1] == '\t')) {
            float f[3] = {0, 0, 0};
            char *end;
            p += 2;
            for (int k = 0; k < 3; ++k) {
                f[k] = strtof(p, &end);
                p = end;
            }
            ok = farr_push(&pos, f);
        } else if (p[0] == 'v' && p[1] == 't') {
            float f[2] = {0, 0};
            char *end;
            p += 2;
            for (int k = 0; k < 2; ++k) {
                f[k] = strtof(p, &end);
                p = end;
            }
            ok = farr_push(&uv, f);
        } else if (p[0] == 'v' && p[1] == 'n') {
            float f[3] = {0, 0, 0};
            char *end;
            p += 2;
            for (int k = 0; k < 3; ++k) {
                f[k] = strtof(p, &end);
                p = end;
            }
            ok = farr_push(&nrm, f);
        } else if (p[0] == 'f' && (p[1] == ' ' || p[1] == '\t')) {
            mvl_vertex first, prev, cur;
            int n = 0;
            p += 2;
            for (;;) {
                int r;
                while (*p == ' ' || *p == '\t') ++p;
                if (*p == 0 || *p == '\n' || *p == '\r') break;
                r = parse_face_vertex(&p, &pos, &uv, &nrm, &cur);
                if (r < 0) {
                    ok = 0;
                    break;
                }
                if (r == 0) {
                    while (*p && *p != ' ' && *p != '\n') ++p;
                    continue;
                }
                if (n == 0) first = cur;
                else if (n >= 2) {
                    ok = mvl_mesh_push(out, &first) && mvl_mesh_push(out, &prev) && mvl_mesh_push(out, &cur);
                    if (!ok) break;
                }
                prev = cur;
                ++n;
            }
        }
        while (*p && *p != '\n') ++p;
        if (*p) ++p;
    }
    free(pos.d);
    free(uv.d);
    free(nrm.d);
    if (!ok || out->count == 0) {
        mvl_mesh_free(out);
        return 0;
    }
    mvl_mesh_compute_bounds(out);
    return 1;
}

/* ------------------------------------------------------------- builders */
void mvl_mesh_add_quad(mvl_mesh *m, const float p[4][3], const float n[3],
                       float u0, float v0, float u1, float v1, const uint8_t color[4]) {
    const float uvs[4][2] = {{u0, v1}, {u1, v1}, {u1, v0}, {u0, v0}};
    static const int idx[6] = {0, 1, 2, 0, 2, 3};
    for (int i = 0; i < 6; ++i) {
        mvl_vertex v;
        int k = idx[i];
        memcpy(v.pos, p[k], sizeof v.pos);
        v.uv[0] = uvs[k][0];
        v.uv[1] = uvs[k][1];
        memcpy(v.normal, n, sizeof v.normal);
        memcpy(v.color, color ? color : WHITE, 4);
        mvl_mesh_push(m, &v);
    }
}

void mvl_mesh_build_plane(mvl_mesh *m, float sx, float sz, float tx, float tz) {
    float hx = sx * 0.5f, hz = sz * 0.5f;
    const float p[4][3] = {{-hx, 0, hz}, {hx, 0, hz}, {hx, 0, -hz}, {-hx, 0, -hz}};
    const float n[3] = {0, 1, 0};
    mvl_mesh_add_quad(m, p, n, 0, 0, tx, tz, WHITE);
    mvl_mesh_compute_bounds(m);
}

void mvl_mesh_build_box(mvl_mesh *m, float sx, float sy, float sz) {
    float x = sx * 0.5f, z = sz * 0.5f, y = sy;
    const float faces[6][4][3] = {
        {{-x, 0, z}, {x, 0, z}, {x, y, z}, {-x, y, z}},     /* +Z */
        {{x, 0, -z}, {-x, 0, -z}, {-x, y, -z}, {x, y, -z}}, /* -Z */
        {{x, 0, z}, {x, 0, -z}, {x, y, -z}, {x, y, z}},     /* +X */
        {{-x, 0, -z}, {-x, 0, z}, {-x, y, z}, {-x, y, -z}}, /* -X */
        {{-x, y, z}, {x, y, z}, {x, y, -z}, {-x, y, -z}},   /* +Y */
        {{-x, 0, -z}, {x, 0, -z}, {x, 0, z}, {-x, 0, z}},   /* -Y */
    };
    const float normals[6][3] = {{0, 0, 1}, {0, 0, -1}, {1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0}};
    for (int f = 0; f < 6; ++f) mvl_mesh_add_quad(m, faces[f], normals[f], 0, 0, 1, 1, WHITE);
    mvl_mesh_compute_bounds(m);
}
