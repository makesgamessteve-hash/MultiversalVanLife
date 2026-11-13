/* Unit tests: frustum culling, bounding spheres, oblique projection, decal
 * fields. MIT License. */
#include "test.h"
#include "core/engine.h"
#include "core/mvl_math.h"

void test_frustum_culling(void) {
    mvl_camera cam = {{0, 0, 0}, 0, 0, 90, 0.1f, 100};
    mat4 vp = m4_mul(mvl_camera_proj(&cam, 1.0f), mvl_camera_view(&cam));
    mvl_frustum f;
    mvl_frustum_from_matrix(&f, vp);
    CHECK(mvl_frustum_sphere(&f, v3(0, 0, -10), 1));    /* straight ahead */
    CHECK(!mvl_frustum_sphere(&f, v3(0, 0, 10), 1));    /* behind */
    CHECK(!mvl_frustum_sphere(&f, v3(0, 0, -200), 1));  /* beyond far */
    CHECK(!mvl_frustum_sphere(&f, v3(50, 0, -10), 1));  /* far right */
    CHECK(mvl_frustum_sphere(&f, v3(10.5f, 0, -10), 1)); /* touching the right plane */
    CHECK(mvl_frustum_sphere(&f, v3(0, 0, 5), 6));      /* big sphere around the eye */
    /* turning the camera turns the frustum */
    cam.yaw = MVL_PI;
    vp = m4_mul(mvl_camera_proj(&cam, 1.0f), mvl_camera_view(&cam));
    mvl_frustum_from_matrix(&f, vp);
    CHECK(mvl_frustum_sphere(&f, v3(0, 0, 10), 1));
    CHECK(!mvl_frustum_sphere(&f, v3(0, 0, -10), 1));
}

void test_bounds_sphere(void) {
    const float mn[3] = {-1, 0, -1}, mx[3] = {1, 2, 1};
    vec3 c;
    float r;
    mvl_bounds_sphere(m4_identity(), mn, mx, &c, &r);
    CHECK_NEAR(c.y, 1, 1e-6);
    CHECK_NEAR(r, sqrtf(3), 1e-5);
    mvl_bounds_sphere(m4_mul(m4_translate(v3(5, 0, 0)), m4_scale(v3(1, 3, 2))), mn, mx, &c, &r);
    CHECK_NEAR(c.x, 5, 1e-5);
    CHECK_NEAR(c.y, 3, 1e-5);
    CHECK_NEAR(r, 3 * sqrtf(3), 1e-4);
    mvl_bounds_sphere(m4_scale(v3(1, 1, 4)), mn, mx, &c, &r);
    CHECK_NEAR(r, 4 * sqrtf(3), 1e-4);
}

void test_oblique_projection(void) {
    /* clip plane z = -5 in view space, visible side further away (z < -5) */
    mat4 p = m4_perspective(MVL_PI / 2, 1, 0.1f, 100), o;
    vec4 plane = {0, 0, -1, -5};
    vec4 before = {0, 0, -3, 1}, after = {0, 0, -20, 1}, ndc_b, ndc_a;
    o = mvl_oblique_projection(p, plane);
    ndc_b = m4_mul_v4(o, before);
    ndc_a = m4_mul_v4(o, after);
    CHECK(ndc_b.z < -ndc_b.w);                           /* clipped: in front of the plane */
    CHECK(ndc_a.z >= -ndc_a.w && ndc_a.z <= ndc_a.w);    /* kept */
    CHECK_NEAR(m4_mul_v4(o, before).x, m4_mul_v4(p, before).x, 1e-6); /* x/y unchanged */
    {
        vec4 on = {0, 0, -5, 1}, c = m4_mul_v4(o, on);
        CHECK_NEAR(c.z / c.w, -1, 1e-3); /* the plane maps to the near plane */
    }
    {
        vec4 degenerate = {0, 0, 0, 0};
        mat4 same = mvl_oblique_projection(p, degenerate);
        CHECK_NEAR(same.m[10], p.m[10], 0);
    }
    {
        vec4 tilted = {0.3f, -0.4f, -1, -5};
        o = mvl_oblique_projection(p, tilted);
        CHECK(o.m[2] != p.m[2]);
    }
}

void test_portals(void) {
    mvl_portal p;
    mvl_camera cam = {{0, 1, 2}, 0, 0, 90, 0.1f, 300};
    mat4 view = mvl_camera_view(&cam), proj = mvl_camera_proj(&cam, 1.0f), vv, vp;
    vec3 q;
    memset(&p, 0, sizeof p);
    p.enabled = 1;
    p.pos = v3(0, 1, 0);
    p.w = 2;
    p.h = 2;
    p.target_pos = v3(100, 1, 50);
    p.target_yaw = 0;
    /* points around the portal map to points around the target */
    q = m4_transform_point(mvl_portal_matrix(&p), v3(0, 1, -1));
    CHECK_NEAR(q.x, 100, 1e-4);
    CHECK_NEAR(q.z, 49, 1e-4);
    p.target_yaw = MVL_PI / 2; /* target turned left: the view through it looks along -X */
    q = m4_transform_point(mvl_portal_matrix(&p), v3(0, 1, -1));
    CHECK_NEAR(q.x, 99, 1e-4);
    CHECK_NEAR(q.z, 50, 1e-4);
    p.target_yaw = 0;
    /* quad matrix and facing */
    q = m4_transform_point(mvl_portal_quad_matrix(&p), v3(0.5f, 0.5f, 0));
    CHECK_NEAR(q.x, 1, 1e-5);
    CHECK_NEAR(q.y, 2, 1e-5);
    CHECK(mvl_portal_faces(&p, v3(0, 1, 2)));
    CHECK(!mvl_portal_faces(&p, v3(0, 1, -2)));
    /* virtual view: a point beyond the target is visible where the portal is */
    mvl_portal_view(&p, view, proj, &vv, &vp);
    {
        vec4 beyond = {100, 1, 40, 1}, between = {100, 1, 51, 1}, behind_eye = {100, 1, 60, 1};
        vec4 cb = m4_mul_v4(m4_mul(vp, vv), beyond), cn = m4_mul_v4(m4_mul(vp, vv), between);
        vec4 ce = m4_mul_v4(m4_mul(vp, vv), behind_eye);
        CHECK(cb.z >= -cb.w && cb.z <= cb.w);
        CHECK_NEAR(cb.x / cb.w, 0, 1e-4); /* straight ahead, centre of the screen */
        CHECK(cn.z < -cn.w);              /* between virtual eye and target plane: clipped */
        CHECK(ce.w < 0 || ce.z < -ce.w);  /* behind the virtual eye */
    }
    /* a singular view leaves the projection alone */
    {
        mat4 zero;
        memset(&zero, 0, sizeof zero);
        mvl_portal_view(&p, zero, proj, &vv, &vp);
        CHECK_NEAR(vp.m[10], proj.m[10], 0);
    }
}
