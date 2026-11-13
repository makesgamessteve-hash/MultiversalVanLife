/* Multiversal Van Life - planet kernels (see planet.h). MIT License. */
#include "core/planet.h"
#include "core/noise.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>

/* ------------------------------------------------------------------ grid */
static mvl_planet_grid *g_grids[MVL_PLANET_MAX_LEVEL + 1];

static void normalize3(float *v) {
    float l = sqrtf(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    if (l > 0.0f) {
        v[0] /= l;
        v[1] /= l;
        v[2] /= l;
    }
}

typedef struct {
    uint64_t *keys;
    int *vals;
    size_t cap;
} edge_map;

static int edge_lookup(edge_map *m, int a, int b, int fresh) {
    uint64_t key = a < b ? ((uint64_t)a << 32) | (uint32_t)b : ((uint64_t)b << 32) | (uint32_t)a;
    /* hash of the ordered pair: the same edge seen from either face */
    size_t i = (size_t)mvl_hash_combine(mvl_hash_u32((uint32_t)key), (uint32_t)(key >> 32)) & (m->cap - 1);
    while (m->keys[i]) {
        if (m->keys[i] == key + 1) return m->vals[i];
        i = (i + 1) & (m->cap - 1);
    }
    m->keys[i] = key + 1;
    m->vals[i] = fresh;
    return -1;
}

static int cmp_int(const void *a, const void *b) {
    int x = *(const int *)a, y = *(const int *)b;
    return (x > y) - (x < y);
}

static mvl_planet_grid *build_grid(int level) {
    static const int base_faces[20][3] = {{0, 11, 5}, {0, 5, 1},  {0, 1, 7},   {0, 7, 10}, {0, 10, 11},
                                          {1, 5, 9},  {5, 11, 4}, {11, 10, 2}, {10, 7, 6}, {7, 1, 8},
                                          {3, 9, 4},  {3, 4, 2},  {3, 2, 6},   {3, 6, 8},  {3, 8, 9},
                                          {4, 9, 5},  {2, 4, 11}, {6, 2, 10},  {8, 6, 7},  {9, 8, 1}};
    const float t = 1.6180339887f;
    const float base[12][3] = {{-1, t, 0}, {1, t, 0}, {-1, -t, 0}, {1, -t, 0}, {0, -1, t}, {0, 1, t},
                               {0, -1, -t}, {0, 1, -t}, {t, 0, -1}, {t, 0, 1}, {-t, 0, -1}, {-t, 0, 1}};
    int nv = 10 * (1 << (2 * level)) + 2, nf = 20 * (1 << (2 * level)), v = 12, f = 20;
    mvl_planet_grid *g = (mvl_planet_grid *)calloc(1, sizeof *g);
    int *faces = (int *)malloc(sizeof(int) * 3 * (size_t)nf), *next = (int *)malloc(sizeof(int) * 3 * (size_t)nf);
    int *deg, *fill;
    edge_map m;
    if (!g || !faces || !next) {
        free(g);
        free(faces);
        free(next);
        return NULL;
    }
    g->level = level;
    g->count = nv;
    g->pos = (float *)malloc(sizeof(float) * 3 * (size_t)nv);
    for (int i = 0; i < 12; ++i) {
        memcpy(g->pos + 3 * i, base[i], sizeof base[i]);
        normalize3(g->pos + 3 * i);
    }
    memcpy(faces, base_faces, sizeof base_faces);
    m.cap = 1;
    while (m.cap < (size_t)nv * 4) m.cap <<= 1;
    m.keys = (uint64_t *)calloc(m.cap, sizeof *m.keys);
    m.vals = (int *)malloc(sizeof(int) * m.cap);
    for (int l = 0; l < level; ++l) {
        int nn = 0;
        memset(m.keys, 0, sizeof *m.keys * m.cap);
        for (int i = 0; i < f; ++i) {
            int c[3], mid[3];
            memcpy(c, faces + 3 * i, sizeof c);
            for (int k = 0; k < 3; ++k) {
                int a = c[k], b = c[(k + 1) % 3];
                int found = edge_lookup(&m, a, b, v);
                if (found < 0) {
                    float *p = g->pos + 3 * v;
                    for (int d = 0; d < 3; ++d) p[d] = (g->pos[3 * a + d] + g->pos[3 * b + d]) * 0.5f;
                    normalize3(p);
                    found = v++;
                }
                mid[k] = found;
            }
            {
                const int tri[4][3] = {{c[0], mid[0], mid[2]}, {c[1], mid[1], mid[0]}, {c[2], mid[2], mid[1]},
                                       {mid[0], mid[1], mid[2]}};
                memcpy(next + 3 * nn, tri, sizeof tri);
                nn += 4;
            }
        }
        {
            int *tmp = faces;
            faces = next;
            next = tmp;
        }
        f = nn;
    }
    free(m.keys);
    free(m.vals);
    /* neighbours from the faces' edges */
    deg = (int *)calloc((size_t)nv, sizeof(int));
    fill = (int *)calloc((size_t)nv, sizeof(int));
    g->nbr_start = (int *)malloc(sizeof(int) * ((size_t)nv + 1));
    for (int i = 0; i < f; ++i)
        for (int k = 0; k < 3; ++k) deg[faces[3 * i + k]] += 2;
    g->nbr_start[0] = 0;
    for (int i = 0; i < nv; ++i) g->nbr_start[i + 1] = g->nbr_start[i] + deg[i];
    g->nbr = (int *)malloc(sizeof(int) * (size_t)g->nbr_start[nv]);
    for (int i = 0; i < f; ++i)
        for (int k = 0; k < 3; ++k) {
            int a = faces[3 * i + k], b = faces[3 * i + (k + 1) % 3];
            g->nbr[g->nbr_start[a] + fill[a]++] = b;
            g->nbr[g->nbr_start[b] + fill[b]++] = a;
        }
    /* sort and remove duplicates (each edge was seen from both faces) */
    {
        int out = 0;
        for (int i = 0; i < nv; ++i) {
            int s = g->nbr_start[i], e = s + fill[i], start = out;
            qsort(g->nbr + s, (size_t)(e - s), sizeof(int), cmp_int);
            for (int j = s; j < e; ++j)
                if (j == s || g->nbr[j] != g->nbr[j - 1]) g->nbr[out++] = g->nbr[j];
            g->nbr_start[i] = start;
        }
        g->nbr_start[nv] = out;
    }
    {
        double sum = 0;
        int n = 0;
        for (int i = 0; i < nv; ++i)
            for (int j = g->nbr_start[i]; j < g->nbr_start[i + 1]; ++j) {
                const float *a = g->pos + 3 * i, *b = g->pos + 3 * g->nbr[j];
                float dx = a[0] - b[0], dy = a[1] - b[1], dz = a[2] - b[2];
                sum += sqrtf(dx * dx + dy * dy + dz * dz);
                ++n;
            }
        g->edge = (float)(sum / (double)n);
    }
    free(deg);
    free(fill);
    free(faces);
    free(next);
    return g;
}

const mvl_planet_grid *mvl_planet_grid_get(int level) {
    if (level < 0 || level > MVL_PLANET_MAX_LEVEL) return NULL;
    if (!g_grids[level]) g_grids[level] = build_grid(level);
    return g_grids[level];
}

void mvl_planet_grids_free(void) {
    for (int i = 0; i <= MVL_PLANET_MAX_LEVEL; ++i) {
        if (!g_grids[i]) continue;
        free(g_grids[i]->pos);
        free(g_grids[i]->nbr_start);
        free(g_grids[i]->nbr);
        free(g_grids[i]);
        g_grids[i] = NULL;
    }
}

static float dot3(const float *a, const float *b) { return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]; }

int mvl_planet_nearest(const mvl_planet_grid *g, float x, float y, float z) {
    float p[3] = {x, y, z}, best;
    int cur = 0;
    normalize3(p);
    best = dot3(p, g->pos);
    for (int i = 1; i < 12; ++i) {
        float d = dot3(p, g->pos + 3 * i);
        if (d > best) best = d, cur = i;
    }
    for (;;) {
        int moved = cur;
        for (int j = g->nbr_start[cur]; j < g->nbr_start[cur + 1]; ++j) {
            float d = dot3(p, g->pos + 3 * g->nbr[j]);
            if (d > best) best = d, moved = g->nbr[j];
        }
        if (moved == cur) return cur;
        cur = moved;
    }
}

/* ------------------------------------------------------------ min-heap */
typedef struct {
    float cost;
    int cell, tag;
} heap_item;

typedef struct {
    heap_item *a;
    int n, cap;
} heap;

static int item_less(const heap_item *x, const heap_item *y) {
    if (x->cost != y->cost) return x->cost < y->cost;
    if (x->cell != y->cell) return x->cell < y->cell;
    return x->tag < y->tag;
}

static int heap_push(heap *h, float cost, int cell, int tag) {
    int i;
    if (h->n == h->cap) {
        int cap = h->cap ? h->cap * 2 : 1024;
        heap_item *na = (heap_item *)realloc(h->a, sizeof *na * (size_t)cap);
        if (!na) return 0;
        h->a = na;
        h->cap = cap;
    }
    i = h->n++;
    h->a[i].cost = cost;
    h->a[i].cell = cell;
    h->a[i].tag = tag;
    while (i > 0) {
        int p = (i - 1) / 2;
        heap_item tmp;
        if (!item_less(&h->a[i], &h->a[p])) break;
        tmp = h->a[i];
        h->a[i] = h->a[p];
        h->a[p] = tmp;
        i = p;
    }
    return 1;
}

static heap_item heap_pop(heap *h) {
    heap_item top = h->a[0];
    int i = 0;
    h->a[0] = h->a[--h->n];
    for (;;) {
        int l = 2 * i + 1, r = l + 1, s = i;
        heap_item tmp;
        if (l < h->n && item_less(&h->a[l], &h->a[s])) s = l;
        if (r < h->n && item_less(&h->a[r], &h->a[s])) s = r;
        if (s == i) break;
        tmp = h->a[i];
        h->a[i] = h->a[s];
        h->a[s] = tmp;
        i = s;
    }
    return top;
}

static float chord(const mvl_planet_grid *g, int a, int b) {
    const float *p = g->pos + 3 * a, *q = g->pos + 3 * b;
    float dx = p[0] - q[0], dy = p[1] - q[1], dz = p[2] - q[2];
    return sqrtf(dx * dx + dy * dy + dz * dz) / g->edge;
}

/* ---------------------------------------------------------------- plates */
int mvl_planet_plates(const mvl_planet_grid *g, uint32_t seed, int nplates, int *plate) {
    mvl_rng rng;
    int seeds[MVL_PLANET_MAX_PLATES], n = 0;
    float growth[MVL_PLANET_MAX_PLATES], min_dot, angle2;
    heap h = {0};
    if (nplates < 1) nplates = 1;
    if (nplates > MVL_PLANET_MAX_PLATES) nplates = MVL_PLANET_MAX_PLATES;
    mvl_rng_seed(&rng, seed, 11);
    /* seeds spread apart (Poisson disc on the sphere, relaxed if needed) */
    angle2 = 4.0f * 3.14159265f / (float)nplates * 0.7f; /* (min angle)^2, radians^2 */
    for (int tries = 0; n < nplates && tries < 4000; ++tries) {
        int c = mvl_rng_range(&rng, 0, g->count - 1), ok = 1;
        if (tries % 400 == 399) angle2 *= 0.7f;
        min_dot = 1.0f - angle2 * 0.5f;
        for (int k = 0; k < n && ok; ++k)
            if (dot3(g->pos + 3 * c, g->pos + 3 * seeds[k]) > min_dot) ok = 0;
        if (ok) seeds[n++] = c;
    }
    for (int i = 0; i < g->count; ++i) plate[i] = -1;
    for (int k = 0; k < n; ++k) {
        growth[k] = 0.6f + 0.8f * mvl_rng_float(&rng);
        heap_push(&h, 0.0f, seeds[k], k);
    }
    /* weighted flood fill: plates grow at their own rate through rough ground */
    while (h.n > 0) {
        heap_item it = heap_pop(&h);
        if (plate[it.cell] >= 0) continue;
        plate[it.cell] = it.tag;
        for (int j = g->nbr_start[it.cell]; j < g->nbr_start[it.cell + 1]; ++j) {
            int nb = g->nbr[j];
            if (plate[nb] < 0) {
                const float *p = g->pos + 3 * nb;
                float rough = 1.0f + 0.6f * mvl_fbm3(p[0] * 3.0f, p[1] * 3.0f, p[2] * 3.0f, seed ^ 0x5eedu, 3, 2.0f, 0.5f);
                heap_push(&h, it.cost + chord(g, it.cell, nb) * rough * growth[it.tag], nb, it.tag);
            }
        }
    }
    free(h.a);
    return n;
}

/* ------------------------------------------------------------- tectonics */
static void cross3(const float *a, const float *b, float *out) {
    out[0] = a[1] * b[2] - a[2] * b[1];
    out[1] = a[2] * b[0] - a[0] * b[2];
    out[2] = a[0] * b[1] - a[1] * b[0];
}

/* Smooth bump: 1 at 0, 0 at width and beyond. */
static float bump(float d, float width) {
    float s = d / width;
    if (s >= 1.0f) return 0.0f;
    s = 1.0f - s * s;
    return s * s;
}

int mvl_planet_tectonics(const mvl_planet_grid *g, uint32_t seed, int nplates, float continental_fraction,
                         int *plate, float *elevation, uint8_t *boundary, float *boundary_dist,
                         mvl_plate_info *info) {
    mvl_rng rng;
    int n = mvl_planet_plates(g, seed, nplates, plate), order[MVL_PLANET_MAX_PLATES];
    float area_cont = 0.0f;
    /* per-cell description of its nearest boundary */
    float *strength = (float *)calloc((size_t)g->count, sizeof(float));
    int *config = (int *)calloc((size_t)g->count, sizeof(int)); /* kind | own continental << 2 | other << 3 */
    heap h = {0};
    if (!strength || !config) {
        free(strength);
        free(config);
        return 0;
    }
    mvl_rng_seed(&rng, seed, 12);
    for (int k = 0; k < n; ++k) {
        memset(&info[k], 0, sizeof info[k]);
        order[k] = k;
    }
    for (int i = 0; i < g->count; ++i) info[plate[i]].area += 1.0f / (float)g->count;
    /* motion: a random rotation pole and speed per plate */
    for (int k = 0; k < n; ++k) {
        float v[3];
        do {
            v[0] = mvl_rng_float(&rng) * 2 - 1;
            v[1] = mvl_rng_float(&rng) * 2 - 1;
            v[2] = mvl_rng_float(&rng) * 2 - 1;
        } while (v[0] * v[0] + v[1] * v[1] + v[2] * v[2] > 1.0f || v[0] * v[0] + v[1] * v[1] + v[2] * v[2] < 0.01f);
        normalize3(v);
        memcpy(info[k].pole, v, sizeof v);
        info[k].speed = 0.3f + 0.7f * mvl_rng_float(&rng);
    }
    /* continental crust: plates in random order until the target area */
    for (int k = n - 1; k > 0; --k) {
        int j = mvl_rng_range(&rng, 0, k), tmp = order[k];
        order[k] = order[j];
        order[j] = tmp;
    }
    for (int k = 0; k < n && area_cont < continental_fraction; ++k) {
        info[order[k]].continental = 1;
        area_cont += info[order[k]].area;
    }
    /* boundaries: relative motion across each edge between plates */
    for (int i = 0; i < g->count; ++i) {
        boundary[i] = MVL_BOUND_NONE;
        boundary_dist[i] = 1e9f;
    }
    for (int i = 0; i < g->count; ++i) {
        const float *p = g->pos + 3 * i;
        int a = plate[i];
        for (int j = g->nbr_start[i]; j < g->nbr_start[i + 1]; ++j) {
            int nb = g->nbr[j], b = plate[nb];
            float va[3], vb[3], d[3], rel[3], dl, along, mag;
            int kind;
            if (b == a) continue;
            cross3(info[a].pole, p, va);
            cross3(info[b].pole, p, vb);
            for (int c = 0; c < 3; ++c) {
                va[c] *= info[a].speed;
                vb[c] *= info[b].speed;
                rel[c] = va[c] - vb[c];
                d[c] = g->pos[3 * nb + c] - p[c];
            }
            dl = sqrtf(dot3(d, d));
            along = dot3(rel, d) / dl; /* > 0: this plate moves towards the other */
            mag = sqrtf(dot3(rel, rel));
            kind = along > 0.3f * mag ? MVL_BOUND_CONVERGENT
                                      : (along < -0.3f * mag ? MVL_BOUND_DIVERGENT : MVL_BOUND_TRANSFORM);
            if (mag + 0.001f > strength[i] || boundary[i] == MVL_BOUND_NONE) {
                strength[i] = mag + 0.001f;
                boundary[i] = (uint8_t)kind;
                config[i] = kind | (info[a].continental << 2) | (info[b].continental << 3) | ((a < b) << 4);
            }
        }
        if (boundary[i] != MVL_BOUND_NONE) heap_push(&h, 0.0f, i, config[i]);
    }
    /* distance to the nearest boundary, carrying its description */
    while (h.n > 0) {
        heap_item it = heap_pop(&h);
        if (it.cost >= boundary_dist[it.cell]) continue;
        boundary_dist[it.cell] = it.cost;
        config[it.cell] = it.tag;
        boundary[it.cell] = (uint8_t)(it.tag & 3);
        for (int j = g->nbr_start[it.cell]; j < g->nbr_start[it.cell + 1]; ++j) {
            int nb = g->nbr[j];
            float c = it.cost + chord(g, it.cell, nb);
            if (c < boundary_dist[nb] && c < 8.0f && plate[nb] == plate[it.cell]) heap_push(&h, c, nb, it.tag);
        }
    }
    /* elevation in km above the deep ocean floor */
    for (int i = 0; i < g->count; ++i) {
        const float *p = g->pos + 3 * i;
        int cont = info[plate[i]].continental, cfg = config[i], kind = cfg & 3;
        int own_c = (cfg >> 2) & 1, other_c = (cfg >> 3) & 1, first = (cfg >> 4) & 1;
        float dist = boundary_dist[i] < 1e8f ? boundary_dist[i] : 99.0f;
        float e = cont ? 4.5f : 0.0f;
        if (kind == MVL_BOUND_CONVERGENT) {
            if (own_c && other_c) e += 4.0f * bump(dist, 2.5f);                  /* collision: high mountains */
            else if (own_c && !other_c) e += 3.0f * bump(dist, 2.0f);            /* coastal range above subduction */
            else if (!own_c && other_c) e -= 3.0f * bump(dist, 1.2f);            /* trench */
            else e += (first ? 4.5f : -2.0f) * bump(dist, 1.5f);                 /* island arc or trench */
        } else if (kind == MVL_BOUND_DIVERGENT) {
            if (own_c && other_c) e -= 2.0f * bump(dist, 1.5f);                  /* rift valley */
            else if (!own_c) e += 1.8f * bump(dist, 2.0f);                       /* mid-ocean ridge */
        } else if (kind == MVL_BOUND_TRANSFORM) {
            e += 0.4f * bump(dist, 1.0f);
        }
        if (cont && !other_c && kind != MVL_BOUND_CONVERGENT && kind != MVL_BOUND_NONE) {
            /* passive margin: the continent slopes down to the ocean */
            float s = dist / 2.5f;
            if (s < 1.0f) e -= 3.0f * (1.0f - s) * (1.0f - s);
        }
        /* broad swells make coasts, inland seas and islands irregular */
        e += 1.6f * mvl_fbm3(p[0] * 1.7f, p[1] * 1.7f, p[2] * 1.7f, seed ^ 0xc0a5u, 3, 2.0f, 0.5f);
        e += 0.8f * mvl_fbm3(p[0] * 4.0f, p[1] * 4.0f, p[2] * 4.0f, seed ^ 0xe1e7u, 4, 2.0f, 0.5f);
        elevation[i] = e;
    }
    free(strength);
    free(config);
    free(h.a);
    return n;
}

/* --------------------------------------------------------------- climate */
int mvl_planet_climate(const mvl_planet_grid *g, const float *elevation, const mvl_climate_params *p,
                       float *t_mean, float *t_min, float *t_max, float *precip, int *wind_to) {
    int n = g->count, iters = p->iterations > 0 ? p->iterations : 80;
    float *out = (float *)calloc((size_t)n, sizeof(float)), *in = (float *)calloc((size_t)n, sizeof(float));
    float *evap = (float *)calloc((size_t)n, sizeof(float)), *rate = (float *)calloc((size_t)n, sizeof(float));
    float k = 0.5f * (1.0f - 1.2f * p->sin_tilt * p->sin_tilt); /* insolation contrast by latitude */
    if (!out || !in || !evap || !rate) {
        free(out), free(in), free(evap), free(rate);
        return 0;
    }
    for (int i = 0; i < n; ++i) {
        const float *q = g->pos + 3 * i;
        float s = dot3(q, p->axis), s2 = s * s, sea = elevation[i] < 0.0f, h = sea ? 0.0f : elevation[i];
        float wind[3], east[3], north[3], best = -2.0f;
        int to = i;
        if (p->locked) {
            /* day side hot, night side cold; fourth root of the light */
            float light = dot3(q, p->sub), f = light > 0.0f ? sqrtf(sqrtf(light)) : 0.0f;
            t_mean[i] = p->mean - p->span * 0.5f + p->span * f;
            for (int c = 0; c < 3; ++c) wind[c] = p->sub[c] - light * q[c]; /* surface flow towards the star */
        } else {
            float f = 1.0f - k * (3.0f * s2 - 1.0f) * 0.5f, band, poleward;
            t_mean[i] = p->mean + p->span * (f - 1.0f) * 1.4f;
            cross3(p->axis, q, east);
            normalize3(east);
            cross3(q, east, north);
            /* trade winds, westerlies, polar easterlies */
            if (s2 < 0.25f) band = -1.0f, poleward = -0.4f;
            else if (s2 < 0.75f) band = 1.0f, poleward = 0.4f;
            else band = -1.0f, poleward = -0.3f;
            if (s < 0.0f) poleward = -poleward;
            for (int c = 0; c < 3; ++c) wind[c] = band * east[c] + poleward * north[c];
        }
        t_mean[i] -= p->lapse * h;
        {
            /* seasons: stronger with tilt and latitude, milder over the sea */
            float amp = p->locked ? 2.0f : (5.0f + 45.0f * p->sin_tilt * sqrtf(s2)) * (sea ? 0.3f : 1.0f);
            t_min[i] = t_mean[i] - amp;
            t_max[i] = t_mean[i] + amp;
        }
        for (int j = g->nbr_start[i]; j < g->nbr_start[i + 1]; ++j) {
            const float *r = g->pos + 3 * g->nbr[j];
            float d[3] = {r[0] - q[0], r[1] - q[1], r[2] - q[2]}, dl = sqrtf(dot3(d, d)), v = dot3(d, wind) / dl;
            if (v > best) best = v, to = g->nbr[j];
        }
        wind_to[i] = to;
        {
            float warm = (t_mean[i] - 250.0f) / 50.0f;
            if (warm < 0.0f) warm = 0.0f;
            if (warm > 1.5f) warm = 1.5f;
            evap[i] = sea ? 0.2f * warm * p->water : 0.02f * warm * p->water;
        }
    }
    /* rain: a base rate, more where air rises over higher ground (the
     * windward side drains the clouds; the lee stays dry), more at the
     * equatorial convergence */
    for (int i = 0; i < n; ++i) {
        float s = dot3(g->pos + 3 * i, p->axis), up = 0.0f;
        int from_count = 0;
        for (int j = g->nbr_start[i]; j < g->nbr_start[i + 1]; ++j) {
            int nb = g->nbr[j];
            if (wind_to[nb] == i) {
                float a = elevation[nb] > 0 ? elevation[nb] : 0, b = elevation[i] > 0 ? elevation[i] : 0;
                up += b - a;
                ++from_count;
            }
        }
        if (from_count) up /= (float)from_count;
        rate[i] = 0.08f + (up > 0.0f ? up * 0.35f : 0.0f) + (!p->locked && s * s < 0.02f ? 0.08f : 0.0f);
        if (rate[i] > 0.9f) rate[i] = 0.9f;
    }
    for (int it = 0; it < iters; ++it) {
        memset(in, 0, sizeof(float) * (size_t)n);
        for (int i = 0; i < n; ++i)
            if (wind_to[i] != i) in[wind_to[i]] += out[i];
        for (int i = 0; i < n; ++i) {
            float total = in[i] + evap[i];
            precip[i] = total * rate[i];
            out[i] = total - precip[i];
        }
    }
    {
        /* scale so that a wet world averages about 1 */
        double sum = 0;
        for (int i = 0; i < n; ++i) sum += precip[i];
        if (sum > 0)
            for (int i = 0; i < n; ++i) precip[i] = (float)(precip[i] * (double)n / sum) * (0.2f + 0.8f * p->water);
    }
    free(out), free(in), free(evap), free(rate);
    return 1;
}

/* ---------------------------------------------------------------- rivers */
int mvl_planet_rivers(const mvl_planet_grid *g, const float *elevation, const float *precip, float *filled,
                      int *flow_to, float *flow, uint8_t *lake) {
    int n = g->count, done = 0, any_sea = 0, lowest = 0;
    int *order = (int *)malloc(sizeof(int) * (size_t)n);
    uint8_t *seen = (uint8_t *)calloc((size_t)n, 1);
    heap h = {0};
    const float eps = 1e-4f;
    if (!order || !seen) {
        free(order), free(seen);
        return 0;
    }
    for (int i = 0; i < n; ++i) {
        flow_to[i] = -1;
        lake[i] = 0;
        filled[i] = elevation[i];
        if (elevation[i] < 0.0f) {
            any_sea = 1;
            seen[i] = 1;
            heap_push(&h, elevation[i], i, 0);
        }
        if (elevation[i] < elevation[lowest]) lowest = i;
    }
    if (!any_sea) {
        seen[lowest] = 1;
        heap_push(&h, elevation[lowest], lowest, 0);
    }
    /* priority flood: water climbs out of the sea (or the final sink) */
    while (h.n > 0) {
        heap_item it = heap_pop(&h);
        int c = it.cell;
        order[done++] = c;
        for (int j = g->nbr_start[c]; j < g->nbr_start[c + 1]; ++j) {
            int nb = g->nbr[j];
            if (seen[nb]) continue;
            seen[nb] = 1;
            if (elevation[nb] <= filled[c] + eps) {
                filled[nb] = filled[c] + eps; /* a basin: the lake surface rises just above its outlet */
                lake[nb] = elevation[nb] < filled[c];
            } else {
                filled[nb] = elevation[nb];
            }
            flow_to[nb] = c;
            heap_push(&h, filled[nb], nb, 0);
        }
    }
    for (int i = 0; i < n; ++i)
        if (elevation[i] < 0.0f) flow_to[i] = -1, lake[i] = 0;
    /* accumulate from the highest cells down */
    for (int i = 0; i < n; ++i) flow[i] = precip[i] > 0.0f ? precip[i] : 0.0f;
    for (int k = done - 1; k >= 0; --k) {
        int c = order[k];
        if (flow_to[c] >= 0) flow[flow_to[c]] += flow[c];
    }
    free(order), free(seen), free(h.a);
    return 1;
}

/* ----------------------------------------------------------- territories */
int mvl_planet_territory(const mvl_planet_grid *g, const int *seeds, int nseeds, const float *cost, int *owner) {
    float *best = (float *)malloc(sizeof(float) * (size_t)g->count);
    heap h = {0};
    int reached = 0;
    if (!best) return 0;
    for (int i = 0; i < g->count; ++i) owner[i] = -1, best[i] = 1e30f;
    for (int k = 0; k < nseeds; ++k)
        if (seeds[k] >= 0 && seeds[k] < g->count && cost[seeds[k]] >= 0.0f) heap_push(&h, 0.0f, seeds[k], k);
    while (h.n > 0) {
        heap_item it = heap_pop(&h);
        if (owner[it.cell] >= 0) continue;
        owner[it.cell] = it.tag;
        ++reached;
        for (int j = g->nbr_start[it.cell]; j < g->nbr_start[it.cell + 1]; ++j) {
            int nb = g->nbr[j];
            float c;
            if (owner[nb] >= 0 || cost[nb] < 0.0f) continue;
            c = it.cost + chord(g, it.cell, nb) * (cost[it.cell] + cost[nb]) * 0.5f;
            if (c < best[nb]) {
                best[nb] = c;
                heap_push(&h, c, nb, it.tag);
            }
        }
    }
    free(best), free(h.a);
    return reached;
}

int mvl_planet_components(const mvl_planet_grid *g, const uint8_t *mask, int *id) {
    int *queue = (int *)malloc(sizeof(int) * (size_t)g->count), count = 0;
    if (!queue) return 0;
    for (int i = 0; i < g->count; ++i) id[i] = -1;
    for (int i = 0; i < g->count; ++i) {
        int head = 0, tail = 0;
        if (!mask[i] || id[i] >= 0) continue;
        id[i] = count;
        queue[tail++] = i;
        while (head < tail) {
            int c = queue[head++];
            for (int j = g->nbr_start[c]; j < g->nbr_start[c + 1]; ++j) {
                int nb = g->nbr[j];
                if (mask[nb] && id[nb] < 0) {
                    id[nb] = count;
                    queue[tail++] = nb;
                }
            }
        }
        ++count;
    }
    free(queue);
    return count;
}
