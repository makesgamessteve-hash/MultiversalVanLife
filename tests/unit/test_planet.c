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

void test_planet_climate(void) {
    const mvl_planet_grid *g = mvl_planet_grid_get(4);
    int n = g->count, *wind = (int *)malloc(sizeof(int) * (size_t)n);
    float *elev = (float *)malloc(sizeof(float) * (size_t)n), *tm = (float *)malloc(sizeof(float) * (size_t)n * 4);
    float *tn = tm + n, *tx = tn + n, *pr = tx + n;
    mvl_climate_params p;
    double eq = 0, pole = 0, wet = 0, dry = 0;
    int neq = 0, npole = 0, nwet = 0, ndry = 0;
    memset(&p, 0, sizeof p);
    p.axis[1] = 1;
    p.sin_tilt = 0.4f;
    p.mean = 288;
    p.span = 60;
    p.lapse = 6.5f;
    p.water = 0.8f;
    /* an ocean in the west (x < -0.5), land elsewhere, a north-south ridge at x = 0 */
    for (int i = 0; i < n; ++i) {
        float x = g->pos[3 * i];
        elev[i] = x < -0.5f ? -2.0f : (x > -0.07f && x < 0.07f ? 4.0f : 0.3f);
    }
    CHECK(mvl_planet_climate(g, elev, &p, tm, tn, tx, pr, wind));
    for (int i = 0; i < n; ++i) {
        const float *q = g->pos + 3 * i;
        float s2 = q[1] * q[1];
        CHECK(tn[i] <= tm[i] && tx[i] >= tm[i]);
        CHECK(wind[i] >= 0 && wind[i] < n);
        if (elev[i] == 0.3f && s2 < 0.01f) eq += tm[i], ++neq;
        if (elev[i] == 0.3f && s2 > 0.81f) pole += tm[i], ++npole;
        /* westerlies (30-60 degrees) carry rain eastwards over the ridge */
        if (s2 > 0.3f && s2 < 0.7f && q[2] > 0.3f && elev[i] == 0.3f) {
            if (q[0] > -0.3f && q[0] < -0.08f) wet += pr[i], ++nwet;
            if (q[0] > 0.08f && q[0] < 0.3f) dry += pr[i], ++ndry;
        }
    }
    CHECK(neq > 0 && npole > 0);
    if (neq && npole) CHECK(eq / neq > pole / npole + 20);
    CHECK(nwet > 0 && ndry > 0);
    if (nwet && ndry) CHECK(wet / nwet > 1.5 * dry / ndry); /* rain shadow */
    /* tidally locked: day side hot, night side cold */
    p.locked = 1;
    p.sub[0] = 1;
    p.span = 150;
    for (int i = 0; i < n; ++i) elev[i] = 0.2f;
    CHECK(mvl_planet_climate(g, elev, &p, tm, tn, tx, pr, wind));
    {
        int day = mvl_planet_nearest(g, 1, 0, 0), night = mvl_planet_nearest(g, -1, 0, 0);
        CHECK(tm[day] > tm[night] + 100);
    }
    free(wind), free(elev), free(tm);
}

void test_planet_rivers(void) {
    const mvl_planet_grid *g = mvl_planet_grid_get(4);
    int n = g->count, *plate = (int *)malloc(sizeof(int) * (size_t)n), *to = (int *)malloc(sizeof(int) * (size_t)n);
    float *elev = (float *)malloc(sizeof(float) * (size_t)n), *dist = (float *)malloc(sizeof(float) * (size_t)n);
    float *filled = (float *)malloc(sizeof(float) * (size_t)n), *flow = (float *)malloc(sizeof(float) * (size_t)n);
    float *rain = (float *)malloc(sizeof(float) * (size_t)n);
    uint8_t *bound = (uint8_t *)malloc((size_t)n), *lake = (uint8_t *)malloc((size_t)n);
    mvl_plate_info info[MVL_PLANET_MAX_PLATES];
    double total = 0, out = 0;
    int lakes = 0, ok_down = 1, ok_end = 1;
    mvl_planet_tectonics(g, 77, 10, 0.4f, plate, elev, bound, dist, info);
    for (int i = 0; i < n; ++i) elev[i] -= 3.0f, rain[i] = 1.0f, total += 1.0;
    CHECK(mvl_planet_rivers(g, elev, rain, filled, to, flow, lake));
    for (int i = 0; i < n; ++i) {
        int c = i, steps = 0;
        if (to[i] >= 0 && filled[to[i]] >= filled[i]) ok_down = 0;
        while (to[c] >= 0 && steps++ < n) c = to[c];
        if (to[c] >= 0) ok_end = 0;
        if (to[i] < 0) out += flow[i];
        if (lake[i]) {
            ++lakes;
            CHECK(filled[i] > elev[i]);
        }
    }
    CHECK(ok_down);  /* water never flows uphill */
    CHECK(ok_end);   /* every path ends at the sea */
    CHECK_NEAR(out, total, total * 1e-4); /* no water is lost */
    CHECK(lakes > 0);
    /* a dry world drains to its lowest point */
    for (int i = 0; i < n; ++i) elev[i] += 10.0f;
    CHECK(mvl_planet_rivers(g, elev, rain, filled, to, flow, lake));
    {
        int sinks = 0;
        for (int i = 0; i < n; ++i) sinks += to[i] < 0;
        CHECK_EQ_INT(sinks, 1);
    }
    free(plate), free(to), free(elev), free(dist), free(filled), free(flow), free(rain), free(bound), free(lake);
}

void test_planet_territory(void) {
    const mvl_planet_grid *g = mvl_planet_grid_get(3);
    int n = g->count, *owner = (int *)malloc(sizeof(int) * (size_t)n), *id = (int *)malloc(sizeof(int) * (size_t)n);
    float *cost = (float *)malloc(sizeof(float) * (size_t)n);
    uint8_t *mask = (uint8_t *)malloc((size_t)n);
    int seeds[3] = {0, 100, 300}, reached, comps, counts[3] = {0};
    /* two hemispheres split by an impassable band */
    for (int i = 0; i < n; ++i) {
        float y = g->pos[3 * i + 1];
        cost[i] = (y > -0.1f && y < 0.1f) ? -1.0f : 1.0f;
        mask[i] = cost[i] >= 0.0f;
    }
    reached = mvl_planet_territory(g, seeds, 3, cost, owner);
    CHECK(reached > 0);
    for (int i = 0; i < n; ++i) {
        if (cost[i] < 0) CHECK_EQ_INT(owner[i], -1);
        else if (owner[i] >= 0) counts[owner[i]]++;
    }
    CHECK(counts[0] > 0 && counts[1] + counts[2] > 0);
    comps = mvl_planet_components(g, mask, id);
    CHECK_EQ_INT(comps, 2);
    for (int i = 0; i < n; ++i) CHECK((id[i] < 0) == (mask[i] == 0));
    free(owner), free(id), free(cost), free(mask);
}
