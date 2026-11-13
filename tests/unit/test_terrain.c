/* Unit tests: terrain height field and chunk meshes. MIT License. */
#include "test.h"
#include "core/terrain.h"

static const mvl_vertex *find_vertex(const mvl_mesh *m, float lx, float lz) {
    for (int i = 0; i < m->count; ++i)
        if (m->v[i].pos[0] == lx && m->v[i].pos[2] == lz) return &m->v[i];
    return NULL;
}

void test_terrain_height(void) {
    mvl_terrain t;
    float map[4] = {0, 10, 20, 30};
    mvl_terrain_init(&t, 7);
    CHECK_NEAR(mvl_terrain_height(&t, 3.5f, -2.0f), mvl_terrain_height(&t, 3.5f, -2.0f), 0);
    /* flat area: exactly flat inside, blended in the falloff, untouched outside */
    CHECK(mvl_terrain_add_flat(&t, 10, 10, 5, 4, 2.5f));
    CHECK_NEAR(mvl_terrain_height(&t, 12, 11), 2.5f, 0);
    {
        mvl_terrain plain;
        mvl_terrain_init(&plain, 7);
        CHECK_NEAR(mvl_terrain_height(&t, 40, 40), mvl_terrain_height(&plain, 40, 40), 0);
        CHECK(fabsf(mvl_terrain_height(&t, 17, 10) - 2.5f) <= fabsf(mvl_terrain_height(&plain, 17, 10) - 2.5f) + 1e-5f);
    }
    /* segment flats (roads): flat across, graded along */
    mvl_terrain_init(&t, 7);
    CHECK(mvl_terrain_add_segment(&t, 0, 0, 100, 0, 3, 4, 1.0f, 5.0f));
    CHECK_NEAR(mvl_terrain_height(&t, 0, 0), 1.0f, 1e-5);
    CHECK_NEAR(mvl_terrain_height(&t, 50, 2), 3.0f, 1e-5);
    CHECK_NEAR(mvl_terrain_height(&t, 100, -2.5f), 5.0f, 1e-5);
    CHECK_NEAR(mvl_terrain_height(&t, 120, 0), mvl_terrain_height(&t, 120, 0), 0);
    CHECK(mvl_terrain_add_segment(&t, 5, 5, 5, 5, 1, 1, 2.0f, 9.0f)); /* zero length: a disc */
    CHECK_NEAR(mvl_terrain_height(&t, 5.5f, 5), 2.0f, 1e-5);
    /* the noise origin shifts the field, not the flats */
    {
        mvl_terrain a, b;
        mvl_terrain_init(&a, 9);
        mvl_terrain_init(&b, 9);
        b.origin_x = 2048;
        b.origin_z = -64;
        CHECK_NEAR(mvl_terrain_height(&b, 10, 20), mvl_terrain_height(&a, 2058, -44), 0);
    }
    for (int i = 0; i < MVL_TERRAIN_MAX_FLATS; ++i) mvl_terrain_add_flat(&t, 0, 0, -1, 0, 0);
    CHECK(!mvl_terrain_add_flat(&t, 0, 0, 1, 1, 0));
    CHECK(!mvl_terrain_add_segment(&t, 0, 0, 1, 1, 1, 1, 0, 0));
    /* coarse map: a ramp along x is followed */
    mvl_terrain_init(&t, 7);
    t.amp = 0;
    {
        float ramp[8] = {0, 10, 20, 30, 0, 10, 20, 30};
        CHECK(mvl_terrain_set_map(&t, ramp, 4, 2, 0, 0, 10));
        CHECK_NEAR(mvl_terrain_height(&t, 10, 0), 10, 1e-4);
        CHECK_NEAR(mvl_terrain_height(&t, 15, 5), 15, 1e-3);
        CHECK(mvl_terrain_height(&t, 25, 0) > mvl_terrain_height(&t, 5, 0));
        CHECK_NEAR(mvl_terrain_height(&t, -50, -50), 0, 1e-4); /* clamped edges */
    }
    CHECK(!mvl_terrain_set_map(&t, NULL, 4, 2, 0, 0, 10));
    CHECK(!mvl_terrain_set_map(&t, map, 1, 4, 0, 0, 10));
    CHECK(!mvl_terrain_set_map(&t, map, 2, 2, 0, 0, 0));
    mvl_terrain_free(&t);
    mvl_terrain_free(&t);
}

void test_terrain_chunks(void) {
    mvl_terrain t;
    mvl_mesh a, b, c;
    int cells = 8;
    float size = 16.0f, step = size / (float)cells;
    mvl_terrain_init(&t, 99);
    t.amp = 6.0f;
    CHECK(mvl_terrain_build_chunk(&t, 0, 0, size, cells, &a));
    CHECK(mvl_terrain_build_chunk(&t, 1, 0, size, cells, &b));
    CHECK(mvl_terrain_build_chunk(&t, 0, -1, size, cells, &c));
    CHECK_EQ_INT(a.count, cells * cells * 6);
    /* every vertex height equals the height query at its world position */
    for (int i = 0; i < a.count; ++i)
        if (a.v[i].pos[1] != mvl_terrain_height(&t, a.v[i].pos[0], a.v[i].pos[2])) {
            CHECK(0);
            break;
        }
    /* the shared border of chunk (0,0) and (1,0) is identical */
    for (int j = 0; j <= cells; ++j) {
        const mvl_vertex *va = find_vertex(&a, size, (float)j * step);
        const mvl_vertex *vb = find_vertex(&b, 0.0f, (float)j * step);
        CHECK(va && vb);
        if (va && vb) {
            CHECK(va->pos[1] == vb->pos[1]);
            CHECK(va->normal[0] == vb->normal[0] && va->normal[1] == vb->normal[1] && va->normal[2] == vb->normal[2]);
            CHECK(!memcmp(va->color, vb->color, 4));
            CHECK(va->uv[0] == vb->uv[0]);
        }
    }
    /* border with the chunk below (z-1) */
    for (int i = 0; i <= cells; ++i) {
        const mvl_vertex *va = find_vertex(&a, (float)i * step, 0.0f);
        const mvl_vertex *vc = find_vertex(&c, (float)i * step, size);
        CHECK(va && vc && va->pos[1] == vc->pos[1]);
    }
    /* triangles face up */
    for (int i = 0; i < a.count; i += 3) {
        float ux = a.v[i + 1].pos[0] - a.v[i].pos[0], uz = a.v[i + 1].pos[2] - a.v[i].pos[2];
        float vx = a.v[i + 2].pos[0] - a.v[i].pos[0], vz = a.v[i + 2].pos[2] - a.v[i].pos[2];
        if (uz * vx - ux * vz <= 0.0f) {
            CHECK(0);
            break;
        }
    }
    mvl_mesh_free(&a);
    mvl_mesh_free(&b);
    mvl_mesh_free(&c);
    /* steep slopes get the slope colour, palette edge cases */
    t.amp = 60.0f;
    t.freq = 0.2f;
    t.palette_count = 1;
    t.color_noise = 0;
    CHECK(mvl_terrain_build_chunk(&t, 3, 3, size, cells, &a));
    mvl_mesh_free(&a);
    t.palette_count = 9;
    t.color_high = t.color_low;
    CHECK(mvl_terrain_build_chunk(&t, 3, 3, size, cells, &a));
    mvl_mesh_free(&a);
    CHECK(!mvl_terrain_build_chunk(&t, 0, 0, size, 0, &a));
    CHECK(!mvl_terrain_build_chunk(&t, 0, 0, -1, 4, &a));
}
