/* Unit tests: runtime voxel modelling. MIT License. */
#include <math.h>
#include "test.h"
#include "core/assets.h"

void test_voxgrid_shapes(void) {
    mvl_voxels v;
    mvl_mesh m;
    float pi = 3.14159265f;
    CHECK(!mvl_voxels_alloc(&v, 0, 1, 1));
    CHECK(!mvl_voxels_alloc(&v, MVL_VOXGRID_MAX + 1, 1, 1));
    CHECK(mvl_voxels_alloc(&v, 32, 32, 32));
    CHECK_EQ_INT(mvl_voxels_count(&v), 0);
    /* box: exact volume, corners swapped and clipped */
    mvl_voxels_fill_box(&v, 4, 4, 4, 1, 2, 3, 5);
    CHECK_EQ_INT(mvl_voxels_count(&v), 4 * 3 * 2);
    mvl_voxels_fill_box(&v, -10, -10, -10, 50, 50, 50, 0);
    CHECK_EQ_INT(mvl_voxels_count(&v), 0);
    mvl_voxels_fill_box(&v, 30, 30, 30, 40, 40, 40, 1);
    CHECK_EQ_INT(mvl_voxels_count(&v), 8);
    mvl_voxels_fill_box(&v, 0, 0, 0, 31, 31, 31, 0);
    /* sphere: volume close to 4/3 pi r^3 */
    mvl_voxels_fill_ellipsoid(&v, 16, 16, 16, 8, 8, 8, 2);
    CHECK(fabs(mvl_voxels_count(&v) - 4.0 / 3.0 * pi * 512.0) < 0.1 * 4.0 / 3.0 * pi * 512.0);
    mvl_voxels_fill_ellipsoid(&v, 16, 16, 16, 0, 8, 8, 3); /* degenerate: ignored */
    CHECK_EQ_INT(mvl_voxels_replace(&v, 3, 4), 0);
    mvl_voxels_fill_box(&v, 0, 0, 0, 31, 31, 31, 0);
    /* cylinder: pi r^2 h */
    mvl_voxels_fill_cylinder(&v, 16, 16, 10, 1, 6, 3);
    CHECK(fabs(mvl_voxels_count(&v) - pi * 36.0 * 10.0) < 0.12 * pi * 36.0 * 10.0);
    mvl_voxels_fill_cylinder(&v, 16, 16, 0, 5, 0, 3); /* zero radius */
    CHECK_EQ_INT(mvl_voxels_replace(&v, 3, 7), mvl_voxels_count(&v));
    mvl_voxels_fill_box(&v, 0, 0, 0, 31, 31, 31, 0);
    /* lines: thin and thick */
    mvl_voxels_fill_line(&v, 0, 0, 0, 10, 0, 0, 0, 1);
    CHECK_EQ_INT(mvl_voxels_get(&v, 0, 0, 0), 1);
    CHECK_EQ_INT(mvl_voxels_get(&v, 10, 0, 0), 1);
    CHECK_EQ_INT(mvl_voxels_count(&v), 11);
    mvl_voxels_fill_line(&v, 5, 20, 5, 5, 20, 5, 2, 2); /* zero length, thick */
    CHECK(mvl_voxels_get(&v, 5, 20, 5) == 2);
    /* mirror: left half copied to the right */
    mvl_voxels_fill_box(&v, 0, 0, 0, 31, 31, 31, 0);
    mvl_voxels_set(&v, 2, 3, 4, 9);
    mvl_voxels_set(&v, -1, 0, 0, 9); /* out of range: ignored */
    mvl_voxels_mirror_x(&v);
    CHECK_EQ_INT(mvl_voxels_get(&v, 29, 3, 4), 9);
    CHECK_EQ_INT(mvl_voxels_count(&v), 2);
    /* palette */
    mvl_voxels_set_color(&v, 9, 10, 20, 30, 255);
    CHECK_EQ_INT(v.palette[9] & 0xff, 10);
    mvl_voxels_set_color(&v, 0, 1, 1, 1, 1);
    mvl_voxels_set_color(&v, 300, 1, 1, 1, 1);
    mvl_voxels_free(&v);
    /* mesh face counts: one voxel = 6 faces; two touching voxels of one
     * colour merge into a box of 6 faces, of two colours they keep 10 */
    CHECK(mvl_voxels_alloc(&v, 4, 4, 4));
    mvl_voxels_set(&v, 1, 1, 1, 1);
    CHECK(mvl_voxels_mesh(&v, 1.0f, &m));
    CHECK_EQ_INT(m.count, 36);
    mvl_mesh_free(&m);
    mvl_voxels_set(&v, 2, 1, 1, 1);
    CHECK(mvl_voxels_mesh(&v, 0.5f, &m));
    CHECK_EQ_INT(m.count, 36);
    CHECK_NEAR(m.max[0] - m.min[0], 1.0, 1e-6); /* still two voxels long */
    mvl_mesh_free(&m);
    mvl_voxels_set(&v, 2, 1, 1, 2);
    CHECK(mvl_voxels_mesh(&v, 0.5f, &m));
    CHECK_EQ_INT(m.count, 60);
    mvl_mesh_free(&m);
    mvl_voxels_free(&v);
    /* a solid 3x3x3 cube is 6 quads */
    CHECK(mvl_voxels_alloc(&v, 3, 3, 3));
    mvl_voxels_fill_box(&v, 0, 0, 0, 2, 2, 2, 5);
    CHECK(mvl_voxels_mesh(&v, 1.0f, &m));
    CHECK_EQ_INT(m.count, 36);
    mvl_mesh_free(&m);
    mvl_voxels_free(&v);
    /* merging stops at MVL_VOX_MERGE voxels a side: a bar of 40 is cut in 3 */
    CHECK(mvl_voxels_alloc(&v, 40, 1, 1));
    mvl_voxels_fill_box(&v, 0, 0, 0, 39, 0, 0, 3);
    CHECK(mvl_voxels_mesh(&v, 1.0f, &m));
    CHECK_EQ_INT(m.count, (2 + 4 * 3) * 6);
    CHECK_NEAR(m.max[0] - m.min[0], 40.0, 1e-5);
    mvl_mesh_free(&m);
    mvl_voxels_free(&v);
    /* a hole in a wall keeps the faces around it, and the mesh covers the
     * same surface as one face per voxel would */
    CHECK(mvl_voxels_alloc(&v, 5, 1, 5));
    mvl_voxels_fill_box(&v, 0, 0, 0, 4, 0, 4, 1);
    mvl_voxels_set(&v, 2, 0, 2, 0);
    CHECK(mvl_voxels_mesh(&v, 1.0f, &m));
    {
        double front = 0;
        for (int i = 0; i < m.count; i += 3) {
            const float *a = m.v[i].pos, *b = m.v[i + 1].pos, *c = m.v[i + 2].pos;
            double ux = b[0] - a[0], uy = b[1] - a[1], uz = b[2] - a[2], wx = c[0] - a[0], wy = c[1] - a[1], wz = c[2] - a[2];
            double nx = uy * wz - uz * wy, ny = uz * wx - ux * wz, nz = ux * wy - uy * wx;
            if (m.v[i].normal[2] > 0.5f) front += 0.5 * sqrt(nx * nx + ny * ny + nz * nz);
        }
        CHECK_NEAR(front, 24.0, 1e-4); /* 25 voxels minus the hole */
    }
    mvl_mesh_free(&m);
    mvl_voxels_free(&v);
}
