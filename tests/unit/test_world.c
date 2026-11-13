/* Unit tests: resources, scene and collision. MIT License. */
#include "test.h"
#include "core/resources.h"
#include "core/scene.h"
#include <stdlib.h>

static int g_tex, g_mesh, g_destroyed;
static unsigned t_create(void *u, const mvl_image *img, int lin, int rep) { return ++g_tex; }
static unsigned m_create(void *u, const mvl_mesh *m) { return ++g_mesh; }
static unsigned fail_create(void *u, const mvl_mesh *m) { return 0; }
static unsigned fail_tex(void *u, const mvl_image *img, int lin, int rep) { return 0; }
static void destroy(void *u, unsigned h) { g_destroyed++; }

static const char *write_fixtures(char *dir, size_t n) {
    unsigned char tga[18 + 4] = {0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 32, 0x28, 1, 2, 3, 4};
    tmp_path(dir, n, "res");
    tmp_write("res/textures/a.tga", tga, sizeof tga);
    tmp_write("res/textures/bad.tga", "nope", 4);
    tmp_write("res/models/tri.obj", "v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n", 32);
    tmp_write("res/models/bad.obj", "# none\n", 7);
    tmp_write("res/sounds/bad.wav", "RIFF", 4);
    {
        /* minimal valid wav */
        unsigned char w[44 + 4] = {'R', 'I', 'F', 'F', 0, 0, 0, 0, 'W', 'A', 'V', 'E', 'f', 'm', 't', ' ', 16, 0, 0, 0, 1, 0, 1, 0,
                                   0x44, 0xAC, 0, 0, 0, 0, 0, 0, 2, 0, 16, 0, 'd', 'a', 't', 'a', 4, 0, 0, 0, 1, 0, 2, 0};
        tmp_write("res/sounds/ok.wav", w, sizeof w);
    }
    {
        /* minimal vox: one voxel */
        unsigned char v[] = {'V', 'O', 'X', ' ', 150, 0, 0, 0, 'M', 'A', 'I', 'N', 0, 0, 0, 0, 0, 0, 0, 0,
                             'S', 'I', 'Z', 'E', 12, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0,
                             'X', 'Y', 'Z', 'I', 8, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1};
        tmp_write("res/voxels/one.vox", v, sizeof v);
        tmp_write("res/voxels/bad.vox", "VOX ", 4);
    }
    return dir;
}

void test_resources(void) {
    char dir[512];
    mvl_vfs vfs;
    mvl_resources r;
    mvl_gfx_backend b = {0, t_create, destroy, m_create, destroy};
    int id;
    write_fixtures(dir, sizeof dir);
    mvl_vfs_init(&vfs);
    mvl_vfs_add_root(&vfs, dir, "base");
    mvl_res_init(&r, &vfs, b);
    CHECK_EQ_INT(r.textures[0].handle, 1);
    id = mvl_res_texture(&r, "textures/a.tga");
    CHECK_EQ_INT(id, 1);
    CHECK_EQ_INT(mvl_res_texture(&r, "textures/a.tga"), 1); /* cached */
    CHECK_EQ_INT(mvl_res_texture(&r, "textures/none.tga"), 0);
    CHECK_EQ_INT(mvl_res_texture(&r, "textures/bad.tga"), 0);
    CHECK_EQ_INT(mvl_res_texture(&r, NULL), 0);
    CHECK(mvl_res_get_texture(&r, 1)->w == 1);
    CHECK(mvl_res_get_texture(&r, 99) == NULL);
    id = mvl_res_mesh(&r, "models/tri.obj", 0);
    CHECK_EQ_INT(id, 1);
    CHECK_EQ_INT(mvl_res_mesh(&r, "models/tri.obj", 0), 1);
    CHECK_EQ_INT(mvl_res_get_mesh(&r, id)->vertex_count, 3);
    CHECK(mvl_res_get_mesh(&r, 0) == NULL);
    CHECK_EQ_INT(mvl_res_mesh(&r, "models/bad.obj", 0), 0);
    CHECK_EQ_INT(mvl_res_mesh(&r, "models/none.obj", 0), 0);
    CHECK_EQ_INT(mvl_res_mesh(&r, "voxels/one.vox", 0.25f), 2);
    CHECK_EQ_INT(mvl_res_mesh(&r, "voxels/one.vox", 0.5f), 3); /* different size, new mesh */
    CHECK_EQ_INT(mvl_res_mesh(&r, "voxels/one.vox", 0), 4);    /* default size */
    CHECK_EQ_INT(mvl_res_mesh(&r, "voxels/bad.vox", 0.25f), 0);
    CHECK_EQ_INT(mvl_res_mesh(&r, "textures/a.tga", 0), 0);    /* unknown type */
    CHECK_EQ_INT(mvl_res_mesh(&r, NULL, 0), 0);
    CHECK_EQ_INT(mvl_res_sound(&r, "sounds/ok.wav"), 1);
    CHECK_EQ_INT(mvl_res_sound(&r, "sounds/ok.wav"), 1);
    CHECK_EQ_INT(mvl_res_sound(&r, "sounds/bad.wav"), 0);
    CHECK_EQ_INT(mvl_res_sound(&r, "sounds/none.wav"), 0);
    CHECK_EQ_INT(mvl_res_sound(&r, NULL), 0);
    CHECK(mvl_res_get_sound(&r, 1)->frames == 2);
    CHECK(mvl_res_get_sound(&r, 7) == NULL);
    {
        mvl_mesh empty;
        mvl_mesh_init(&empty);
        CHECK_EQ_INT(mvl_res_mesh_from_data(&r, "empty", &empty), 0);
    }
    g_destroyed = 0;
    mvl_res_shutdown(&r);
    CHECK_EQ_INT(g_destroyed, 2 + 4);
}

void test_resources_limits(void) {
    char dir[512];
    mvl_vfs vfs;
    mvl_resources r;
    mvl_gfx_backend b = {0, fail_tex, destroy, fail_create, destroy};
    mvl_image img;
    mvl_mesh m;
    write_fixtures(dir, sizeof dir);
    mvl_vfs_init(&vfs);
    mvl_vfs_add_root(&vfs, dir, "base");
    mvl_res_init(&r, &vfs, b);
    CHECK_EQ_INT(mvl_res_texture(&r, "textures/a.tga"), 0);
    CHECK_EQ_INT(mvl_res_mesh(&r, "models/tri.obj", 0), 0);
    mvl_res_shutdown(&r);
    /* table full */
    mvl_res_init(&r, &vfs, mvl_gfx_null_backend());
    mvl_image_alloc(&img, 1, 1);
    mvl_mesh_init(&m);
    mvl_mesh_build_box(&m, 1, 1, 1);
    for (int i = 0; i < MVL_MAX_TEXTURES + 2; ++i) mvl_res_texture_from_image(&r, "x", &img, 0);
    CHECK_EQ_INT(mvl_res_texture_from_image(&r, "x", &img, 0), 0);
    for (int i = 0; i < MVL_MAX_MESHES + 2; ++i) mvl_res_mesh_from_data(&r, "x", &m);
    CHECK_EQ_INT(mvl_res_mesh_from_data(&r, "x", &m), 0);
    r.sound_count = MVL_MAX_SOUNDS;
    CHECK_EQ_INT(mvl_res_sound(&r, "sounds/ok.wav"), 0);
    r.sound_count = 1;
    mvl_mesh_free(&m);
    mvl_image_free(&img);
    mvl_res_shutdown(&r);
}

void test_scene_entities(void) {
    static mvl_scene s;
    int a, b, c;
    mvl_entity *e;
    mvl_scene_init(&s);
    a = mvl_scene_spawn(&s, MVL_ENT_MESH);
    b = mvl_scene_spawn(&s, MVL_ENT_SPRITE);
    CHECK(a > 0 && b > 0 && a != b);
    CHECK_EQ_INT(mvl_scene_count(&s), 2);
    e = mvl_scene_get(&s, b);
    CHECK(e && e->kind == MVL_ENT_SPRITE && (e->flags & MVL_ENT_VISIBLE));
    CHECK(mvl_scene_destroy(&s, b));
    CHECK(!mvl_scene_destroy(&s, b));
    CHECK(mvl_scene_get(&s, b) == NULL); /* stale handle */
    CHECK(mvl_scene_get(&s, 0) == NULL);
    CHECK(mvl_scene_get(&s, -5) == NULL);
    c = mvl_scene_spawn(&s, MVL_ENT_MESH); /* reuses slot with new generation */
    CHECK(c != b);
    CHECK(mvl_scene_get(&s, c) != NULL);
    CHECK_EQ_INT(s.high_water, 2);
    mvl_scene_destroy(&s, c);
    CHECK_EQ_INT(s.high_water, 1);
    mvl_scene_clear(&s);
    CHECK_EQ_INT(mvl_scene_count(&s), 0);
    for (int i = 0; i < MVL_MAX_ENTITIES; ++i) mvl_scene_spawn(&s, MVL_ENT_MESH);
    CHECK_EQ_INT(mvl_scene_spawn(&s, MVL_ENT_MESH), 0);
    mvl_scene_clear(&s);
    {
        mvl_entity en;
        mat4 m;
        vec3 p;
        memset(&en, 0, sizeof en);
        en.pos = v3(1, 0, 0);
        en.scale = v3(2, 2, 2);
        m = mvl_entity_model_matrix(&en);
        p = m4_transform_point(m, v3(1, 0, 0));
        CHECK_NEAR(p.x, 3, 1e-5);
    }
    {
        mat4 v = mvl_camera_view(&s.camera), pr = mvl_camera_proj(&s.camera, 1.5f);
        vec3 p = m4_transform_point(v, v3(0, 1.6f, -2));
        CHECK_NEAR(p.z, -2, 1e-5);
        CHECK(pr.m[11] == -1.0f);
    }
}

void test_scene_collision(void) {
    static mvl_scene s;
    int h;
    mvl_entity *e;
    vec3 p;
    mvl_scene_init(&s);
    s.bounds_min[0] = s.bounds_min[1] = -10;
    s.bounds_max[0] = s.bounds_max[1] = 10;
    /* circle collider */
    h = mvl_scene_spawn(&s, MVL_ENT_MESH);
    e = mvl_scene_get(&s, h);
    e->flags |= MVL_ENT_SOLID;
    e->radius = 1.0f;
    p = mvl_scene_move(&s, v3(-3, 0, 0), v3(2.5f, 0, 0), 0.5f);
    CHECK(p.x <= -1.49f);
    CHECK(mvl_scene_overlaps(&s, v3(0.5f, 0, 0), 0.3f));
    CHECK(!mvl_scene_overlaps(&s, v3(5, 0, 0), 0.3f));
    p = mvl_scene_move(&s, v3(0, 0, 0), v3(0, 0, 0), 0.5f); /* exactly at centre */
    CHECK(p.x >= 1.49f);
    e->radius = 0;
    /* rotated box collider */
    e->half_x = 2;
    e->half_z = 0.5f;
    e->yaw = MVL_PI / 2; /* box now long along Z */
    p = mvl_scene_move(&s, v3(-2, 0, 1.5f), v3(1.5f, 0, 0), 0.3f);
    CHECK(p.x < -0.79f);
    CHECK_NEAR(p.z, 1.5f, 1e-3);
    e->yaw = 0;
    p = mvl_scene_move(&s, v3(0.2f, 0, 0.1f), v3(0, 0, 0), 0.3f); /* centre inside: push along z */
    CHECK(fabs(p.z) >= 0.79f);
    p = mvl_scene_move(&s, v3(1.9f, 0, 0), v3(0, 0, 0), 0.3f); /* push along x */
    CHECK(p.x >= 2.29f);
    p = mvl_scene_move(&s, v3(-1.9f, 0, -0.1f), v3(0, 0, 0), 0.3f);
    CHECK(p.x <= -2.29f);
    /* not solid: ignored */
    e->flags &= ~MVL_ENT_SOLID;
    p = mvl_scene_move(&s, v3(0, 0, 0), v3(0, 0, 0), 0.3f);
    CHECK_NEAR(p.x, 0, 1e-6);
    /* bounds */
    p = mvl_scene_move(&s, v3(9, 0, 9), v3(5, 0, 5), 0.5f);
    CHECK_NEAR(p.x, 9.5f, 1e-5);
    CHECK_NEAR(p.z, 9.5f, 1e-5);
}

static int g_live;
static unsigned live_create_tex(void *u, const mvl_image *img, int lin, int rep) { return (unsigned)++g_live + 1000000u; }
static unsigned live_create_mesh(void *u, const mvl_mesh *m) { return (unsigned)++g_live + 2000000u; }
static void live_destroy(void *u, unsigned h) { g_live--; }

void test_resources_release(void) {
    static mvl_resources r;
    mvl_vfs vfs;
    mvl_gfx_backend b = {0, live_create_tex, live_destroy, live_create_mesh, live_destroy};
    mvl_image img;
    mvl_mesh m;
    int first_mesh = 0, first_tex = 0;
    mvl_vfs_init(&vfs);
    g_live = 0;
    mvl_res_init(&r, &vfs, b);
    mvl_image_alloc(&img, 2, 2);
    mvl_mesh_init(&m);
    mvl_mesh_build_box(&m, 1, 1, 1);
    for (int i = 0; i < 10000; ++i) {
        int mid = mvl_res_mesh_from_data(&r, "chunk", &m);
        int tid = mvl_res_texture_from_image(&r, "gen", &img, 0);
        if (i == 0) {
            first_mesh = mid;
            first_tex = tid;
        }
        if (mid != first_mesh || tid != first_tex) { /* slots are reused */
            CHECK(0);
            break;
        }
        CHECK(mvl_res_get_mesh(&r, mid) != NULL);
        CHECK(mvl_res_release_mesh(&r, mid));
        CHECK(mvl_res_release_texture(&r, tid));
        if (mvl_res_get_mesh(&r, mid) || mvl_res_get_texture(&r, tid)) {
            CHECK(0);
            break;
        }
    }
    CHECK_EQ_INT(g_live, 1); /* only the built-in white texture is left */
    CHECK_EQ_INT(r.mesh_count, 2);
    CHECK(!mvl_res_release_mesh(&r, first_mesh)); /* already released */
    CHECK(!mvl_res_release_mesh(&r, 0));
    CHECK(!mvl_res_release_mesh(&r, 5000));
    CHECK(!mvl_res_release_texture(&r, 0)); /* white texture stays */
    CHECK(!mvl_res_release_texture(&r, -1));
    /* a released slot never matches a cached path lookup */
    CHECK_EQ_INT(mvl_res_texture(&r, ""), 0);
    mvl_mesh_free(&m);
    mvl_image_free(&img);
    mvl_res_shutdown(&r);
    CHECK_EQ_INT(g_live, 0);
}

void test_scene_parenting(void) {
    static mvl_scene s;
    int root, arm, hand, other;
    mvl_entity *r, *a, *h;
    vec3 p;
    mvl_scene_init(&s);
    root = mvl_scene_spawn(&s, MVL_ENT_MESH);
    arm = mvl_scene_spawn(&s, MVL_ENT_MESH);
    hand = mvl_scene_spawn(&s, MVL_ENT_SPRITE);
    other = mvl_scene_spawn(&s, MVL_ENT_MESH);
    r = mvl_scene_get(&s, root);
    a = mvl_scene_get(&s, arm);
    h = mvl_scene_get(&s, hand);
    r->pos = v3(10, 0, 0);
    a->pos = v3(0, 0, -2); /* 2 m in front of the root */
    h->pos = v3(0, 1, 0);
    CHECK(mvl_scene_attach(&s, arm, root));
    CHECK(mvl_scene_attach(&s, hand, arm));
    CHECK_EQ_INT(r->child_count, 1);
    p = mvl_scene_world_pos(&s, h);
    CHECK_NEAR(p.x, 10, 1e-5);
    CHECK_NEAR(p.y, 1, 1e-5);
    CHECK_NEAR(p.z, -2, 1e-5);
    /* turning the parent turns the children (yaw 90 deg: forward -Z becomes -X) */
    r->yaw = MVL_PI / 2;
    p = mvl_scene_world_pos(&s, h);
    CHECK_NEAR(p.x, 8, 1e-4);
    CHECK_NEAR(p.z, 0, 1e-4);
    r->scale = v3(2, 2, 2);
    p = mvl_scene_world_pos(&s, a);
    CHECK_NEAR(p.x, 6, 1e-4);
    p = mvl_scene_world_pos(&s, r); /* roots: world pos is pos */
    CHECK_NEAR(p.x, 10, 1e-6);
    /* cycles, invalid handles and depth are refused */
    CHECK(!mvl_scene_attach(&s, root, hand));
    CHECK(!mvl_scene_attach(&s, root, root));
    CHECK(!mvl_scene_attach(&s, 0, root));
    CHECK(!mvl_scene_attach(&s, other, 123456));
    {
        int chain[MVL_MAX_PARENT_DEPTH + 2];
        int ok = 1;
        chain[0] = mvl_scene_spawn(&s, MVL_ENT_MESH);
        for (int i = 1; i < MVL_MAX_PARENT_DEPTH; ++i) {
            chain[i] = mvl_scene_spawn(&s, MVL_ENT_MESH);
            ok &= mvl_scene_attach(&s, chain[i], chain[i - 1]);
        }
        CHECK(ok);
        chain[MVL_MAX_PARENT_DEPTH] = mvl_scene_spawn(&s, MVL_ENT_MESH);
        CHECK(!mvl_scene_attach(&s, chain[MVL_MAX_PARENT_DEPTH], chain[MVL_MAX_PARENT_DEPTH - 1]));
        CHECK(mvl_scene_destroy(&s, chain[0]));
        CHECK(mvl_scene_get(&s, chain[MVL_MAX_PARENT_DEPTH - 1]) == NULL);
        mvl_scene_destroy(&s, chain[MVL_MAX_PARENT_DEPTH]);
    }
    /* re-parenting and detaching update child counts */
    CHECK(mvl_scene_attach(&s, hand, other));
    CHECK_EQ_INT(a->child_count, 0);
    CHECK_EQ_INT(mvl_scene_get(&s, other)->child_count, 1);
    CHECK(mvl_scene_attach(&s, hand, 0));
    CHECK_EQ_INT(mvl_scene_get(&s, other)->child_count, 0);
    CHECK(mvl_scene_attach(&s, hand, arm));
    /* children never collide */
    a->flags |= MVL_ENT_SOLID;
    a->radius = 5;
    CHECK(!mvl_scene_overlaps(&s, v3(10, 0, -2), 0.5f));
    /* destroying a child decrements its parent; destroying the root cascades */
    CHECK(mvl_scene_destroy(&s, hand));
    CHECK_EQ_INT(a->child_count, 0);
    hand = mvl_scene_spawn(&s, MVL_ENT_SPRITE);
    CHECK(mvl_scene_attach(&s, hand, arm));
    CHECK(mvl_scene_destroy(&s, root));
    CHECK(mvl_scene_get(&s, arm) == NULL);
    CHECK(mvl_scene_get(&s, hand) == NULL);
    CHECK(mvl_scene_get(&s, other) != NULL);
    CHECK_EQ_INT(mvl_scene_count(&s), 1);
}

void test_scene_persistent_and_heights(void) {
    static mvl_scene s;
    int keep, child, gone, gone_child;
    mvl_entity *k;
    vec3 p;
    mvl_scene_init(&s);
    keep = mvl_scene_spawn(&s, MVL_ENT_MESH);
    child = mvl_scene_spawn(&s, MVL_ENT_MESH);
    gone = mvl_scene_spawn(&s, MVL_ENT_MESH);
    gone_child = mvl_scene_spawn(&s, MVL_ENT_MESH);
    k = mvl_scene_get(&s, keep);
    k->flags |= MVL_ENT_PERSISTENT;
    mvl_scene_attach(&s, child, keep);
    mvl_scene_attach(&s, gone_child, gone);
    s.lights[2].enabled = 1;
    mvl_scene_clear_world(&s);
    CHECK(mvl_scene_get(&s, keep) && mvl_scene_get(&s, child));
    CHECK(!mvl_scene_get(&s, gone) && !mvl_scene_get(&s, gone_child));
    CHECK_EQ_INT(k->child_count, 1);
    CHECK(s.lights[2].enabled); /* lights are kept */
    CHECK_EQ_INT(mvl_scene_count(&s), 2);
    mvl_scene_clear(&s);
    CHECK_EQ_INT(mvl_scene_count(&s), 0);
    mvl_scene_clear_world(&s); /* empty scene */
    /* colliders far above or below the mover are ignored */
    keep = mvl_scene_spawn(&s, MVL_ENT_MESH);
    k = mvl_scene_get(&s, keep);
    k->flags |= MVL_ENT_SOLID;
    k->radius = 1;
    k->pos = v3(0, -400, 0);
    p = mvl_scene_move(&s, v3(-2, 0, 0), v3(2, 0, 0), 0.3f);
    CHECK_NEAR(p.x, 0, 1e-5);                   /* world level: passes through */
    p = mvl_scene_move(&s, v3(-2, -400, 0), v3(1, 0, 0), 0.3f);
    CHECK(p.x < -1.2f);                          /* pocket level: blocked */
    CHECK(!mvl_scene_overlaps(&s, v3(0, 0, 0), 0.3f));
    CHECK(mvl_scene_overlaps(&s, v3(0, -401, 0), 0.3f));
}
