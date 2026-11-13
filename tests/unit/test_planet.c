/* Unit tests: planet kernels (planet.c). MIT License. */
#include "test.h"
#include "core/planet.h"
#include <stdlib.h>

void test_planet_grid(void) {
    for (int level = 0; level <= 5; ++level) {
        const mvl_planet_grid *g = mvl_planet_grid_get(level);
        int fives = 0, sym = 1, deg_ok = 1;
        CHECK(g != NULL);
        CHECK_EQ_INT(g->count, 10 * (1 << (2 * level)) + 2);
        for (int i = 0; i < g->count; ++i) {
            int deg = g->nbr_start[i + 1] - g->nbr_start[i];
            const float *p = g->pos + 3 * i;
            if (deg == 5) ++fives;
            if (deg != 5 && deg != 6) deg_ok = 0;
            CHECK_NEAR(p[0] * p[0] + p[1] * p[1] + p[2] * p[2], 1.0, 1e-5);
            for (int j = g->nbr_start[i]; j < g->nbr_start[i + 1] && sym; ++j) {
                int nb = g->nbr[j], back = 0;
                for (int k = g->nbr_start[nb]; k < g->nbr_start[nb + 1]; ++k) back |= g->nbr[k] == i;
                if (!back) sym = 0;
            }
            if (level == 5 && i % 997 == 0) CHECK_EQ_INT(mvl_planet_nearest(g, p[0], p[1], p[2]), i);
        }
        CHECK(sym);
        CHECK(deg_ok);
        CHECK_EQ_INT(fives, 12);
        CHECK(g->edge > 0.0f);
    }
    CHECK(mvl_planet_grid_get(-1) == NULL);
    CHECK(mvl_planet_grid_get(MVL_PLANET_MAX_LEVEL + 1) == NULL);
    CHECK(mvl_planet_grid_get(5) == mvl_planet_grid_get(5)); /* built once */
    mvl_planet_grids_free();
    CHECK_EQ_INT(mvl_planet_grid_get(2)->count, 162); /* rebuilt on demand */
}

static int connected(const mvl_planet_grid *g, const int *plate, int p) {
    int *seen = (int *)calloc((size_t)g->count, sizeof(int)), *queue = (int *)malloc(sizeof(int) * (size_t)g->count);
    int head = 0, tail = 0, start = -1, total = 0, reached = 0;
    for (int i = 0; i < g->count; ++i)
        if (plate[i] == p) {
            ++total;
            if (start < 0) start = i;
        }
    queue[tail++] = start;
    seen[start] = 1;
    while (head < tail) {
        int c = queue[head++];
        ++reached;
        for (int j = g->nbr_start[c]; j < g->nbr_start[c + 1]; ++j) {
            int nb = g->nbr[j];
            if (!seen[nb] && plate[nb] == p) {
                seen[nb] = 1;
                queue[tail++] = nb;
            }
        }
    }
    free(seen);
    free(queue);
    return reached == total;
}

void test_planet_tectonics(void) {
    const mvl_planet_grid *g = mvl_planet_grid_get(5);
    int n = g->count, plates;
    int *plate = (int *)malloc(sizeof(int) * (size_t)n), *plate2 = (int *)malloc(sizeof(int) * (size_t)n);
    float *elev = (float *)malloc(sizeof(float) * (size_t)n), *elev2 = (float *)malloc(sizeof(float) * (size_t)n);
    float *dist = (float *)malloc(sizeof(float) * (size_t)n);
    uint8_t *bound = (uint8_t *)malloc((size_t)n);
    mvl_plate_info info[MVL_PLANET_MAX_PLATES];
    double mountain = 0, plain = 0;
    int nm = 0, np = 0, kinds[4] = {0};
    plates = mvl_planet_tectonics(g, 1234, 14, 0.35f, plate, elev, bound, dist, info);
    CHECK_EQ_INT(plates, 14);
    for (int i = 0; i < n; ++i) CHECK(plate[i] >= 0 && plate[i] < plates);
    for (int p = 0; p < plates; ++p) CHECK(connected(g, plate, p));
    {
        float area = 0;
        for (int p = 0; p < plates; ++p) area += info[p].area;
        CHECK_NEAR(area, 1.0, 1e-3);
    }
    /* every boundary kind occurs; mountains rise where continents collide */
    for (int i = 0; i < n; ++i) {
        kinds[bound[i]]++;
        if (!info[plate[i]].continental) continue;
        if (bound[i] == MVL_BOUND_CONVERGENT && dist[i] < 1.0f) {
            int other_cont = 0;
            for (int j = g->nbr_start[i]; j < g->nbr_start[i + 1]; ++j)
                if (plate[g->nbr[j]] != plate[i] && info[plate[g->nbr[j]]].continental) other_cont = 1;
            if (other_cont) mountain += elev[i], ++nm;
        } else if (bound[i] == MVL_BOUND_NONE || dist[i] > 4.0f) {
            plain += elev[i], ++np;
        }
    }
    CHECK(kinds[MVL_BOUND_CONVERGENT] > 0 && kinds[MVL_BOUND_DIVERGENT] > 0 && kinds[MVL_BOUND_TRANSFORM] > 0);
    CHECK(nm > 0 && np > 0);
    if (nm > 0 && np > 0) CHECK(mountain / nm > plain / np + 1.5);
    /* deterministic, and the seed matters */
    mvl_planet_tectonics(g, 1234, 14, 0.35f, plate2, elev2, bound, dist, info);
    CHECK(memcmp(plate, plate2, sizeof(int) * (size_t)n) == 0);
    CHECK(memcmp(elev, elev2, sizeof(float) * (size_t)n) == 0);
    mvl_planet_tectonics(g, 4321, 14, 0.35f, plate2, elev2, bound, dist, info);
    CHECK(memcmp(elev, elev2, sizeof(float) * (size_t)n) != 0);
    /* plates kernel alone, with clamped counts */
    CHECK_EQ_INT(mvl_planet_plates(g, 5, 0, plate), 1);
    CHECK(mvl_planet_plates(g, 5, 1000, plate) <= MVL_PLANET_MAX_PLATES);
    free(plate), free(plate2), free(elev), free(elev2), free(dist), free(bound);
}
