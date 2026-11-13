/* Unit tests: math. MIT License. */
#include "test.h"
#include "core/mvl_math.h"

void test_math_scalars(void) {
    CHECK_NEAR(mvl_clampf(5, 0, 1), 1, 1e-6);
    CHECK_NEAR(mvl_clampf(-5, 0, 1), 0, 1e-6);
    CHECK_NEAR(mvl_clampf(0.5f, 0, 1), 0.5f, 1e-6);
    CHECK_NEAR(mvl_lerpf(2, 4, 0.5f), 3, 1e-6);
    CHECK_NEAR(mvl_wrap_angle(3 * MVL_PI), MVL_PI, 1e-4);
    CHECK_NEAR(mvl_wrap_angle(-3 * MVL_PI), -MVL_PI, 1e-4);
    CHECK_NEAR(mvl_wrap_angle(1.0f), 1.0f, 1e-6);
}

void test_math_vectors(void) {
    vec3 a = v3(1, 2, 3), b = v3(4, 5, 6), c;
    c = v3_add(a, b);
    CHECK_NEAR(c.x + c.y + c.z, 21, 1e-6);
    c = v3_sub(b, a);
    CHECK_NEAR(c.x, 3, 1e-6);
    CHECK_NEAR(v3_dot(a, b), 32, 1e-6);
    c = v3_cross(v3(1, 0, 0), v3(0, 1, 0));
    CHECK_NEAR(c.z, 1, 1e-6);
    CHECK_NEAR(v3_len(v3(3, 4, 0)), 5, 1e-6);
    c = v3_norm(v3(0, 0, 9));
    CHECK_NEAR(c.z, 1, 1e-6);
    c = v3_norm(v3(0, 0, 0));
    CHECK_NEAR(c.x + c.y + c.z, 0, 1e-6);
    c = v3_lerp(a, b, 1);
    CHECK_NEAR(c.y, 5, 1e-6);
    c = v3_scale(a, 2);
    CHECK_NEAR(c.z, 6, 1e-6);
}

void test_math_matrices(void) {
    mat4 id = m4_identity(), t = m4_translate(v3(1, 2, 3)), s = m4_scale(v3(2, 2, 2)), inv, r;
    vec3 p = m4_transform_point(m4_mul(t, s), v3(1, 1, 1));
    CHECK_NEAR(p.x, 3, 1e-5);
    CHECK_NEAR(p.z, 5, 1e-5);
    CHECK(m4_invert(t, &inv));
    p = m4_transform_point(inv, v3(1, 2, 3));
    CHECK_NEAR(v3_len(p), 0, 1e-5);
    {
        mat4 zero;
        memset(&zero, 0, sizeof zero);
        CHECK(!m4_invert(zero, &inv));
    }
    r = m4_rotate_y(MVL_PI / 2);
    p = m4_transform_point(r, v3(0, 0, -1));
    CHECK_NEAR(p.x, -1, 1e-5); /* yaw convention: forward(-Z) turns left */
    p = m4_transform_point(m4_rotate_x(MVL_PI / 2), v3(0, 1, 0));
    CHECK_NEAR(p.z, 1, 1e-5);
    p = m4_transform_point(m4_rotate_z(MVL_PI / 2), v3(1, 0, 0));
    CHECK_NEAR(p.y, 1, 1e-5);
    r = m4_transpose(t);
    CHECK_NEAR(r.m[3], 1, 1e-6);
    CHECK_NEAR(m4_mul(id, t).m[12], 1, 1e-6);
    {
        mat4 pr = m4_perspective(MVL_PI / 2, 1, 1, 100);
        vec3 q = m4_transform_point(pr, v3(0, 0, -1));
        CHECK_NEAR(q.z, -1, 1e-4); /* near plane maps to -1 */
        q = m4_transform_point(m4_ortho(0, 10, 10, 0, -1, 1), v3(10, 10, 0));
        CHECK_NEAR(q.x, 1, 1e-5);
        CHECK_NEAR(q.y, -1, 1e-5);
    }
    {
        mat4 v = m4_look_at(v3(0, 0, 5), v3(0, 0, 0), v3(0, 1, 0));
        vec3 q = m4_transform_point(v, v3(0, 0, 0));
        CHECK_NEAR(q.z, -5, 1e-5);
    }
    {
        vec3 f = mvl_forward(0, 0), rt = mvl_right(0);
        CHECK_NEAR(f.z, -1, 1e-6);
        CHECK_NEAR(rt.x, 1, 1e-6);
        f = mvl_forward(0, MVL_PI / 2);
        CHECK_NEAR(f.y, 1, 1e-5);
    }
}
