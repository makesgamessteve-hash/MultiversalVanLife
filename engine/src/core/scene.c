/* Multiversal Van Life - scene graph, camera and collision. MIT License. */
#include "core/scene.h"
#include <math.h>
#include <string.h>

#define SLOT_BITS 12
#define SLOT_MASK ((1 << SLOT_BITS) - 1)

void mvl_env_default(mvl_environment *e) {
    const float top[3] = {0.02f, 0.03f, 0.10f}, hor[3] = {0.12f, 0.14f, 0.26f};
    memset(e, 0, sizeof *e);
    memcpy(e->sky_top, top, sizeof top);
    memcpy(e->sky_horizon, hor, sizeof hor);
    memcpy(e->fog_color, hor, sizeof hor);
    e->fog_near = 10.0f;
    e->fog_far = 60.0f;
    e->ambient[0] = e->ambient[1] = 0.25f;
    e->ambient[2] = 0.35f;
    e->sun_dir = v3_norm(v3(-0.3f, -1.0f, -0.4f));
    e->sun_color[0] = 0.35f;
    e->sun_color[1] = 0.4f;
    e->sun_color[2] = 0.55f;
    e->stars = 1.0f;
}

void mvl_scene_init(mvl_scene *s) {
    memset(s, 0, sizeof *s);
    s->camera.fov_deg = 70.0f;
    s->camera.znear = 0.05f;
    s->camera.zfar = 200.0f;
    s->camera.pos = v3(0, 1.6f, 0);
    mvl_env_default(&s->env);
    s->bounds_min[0] = s->bounds_min[1] = -100.0f;
    s->bounds_max[0] = s->bounds_max[1] = 100.0f;
}

void mvl_scene_clear(mvl_scene *s) {
    for (int i = 0; i < s->high_water; ++i) s->entities[i].alive = 0;
    s->high_water = 0;
    memset(s->lights, 0, sizeof s->lights);
}

int mvl_scene_spawn(mvl_scene *s, mvl_entity_kind kind) {
    for (int i = 0; i < MVL_MAX_ENTITIES; ++i) {
        mvl_entity *e = &s->entities[i];
        if (e->alive) continue;
        {
            int gen = (e->generation + 1) & 0x7ffff;
            memset(e, 0, sizeof *e);
            e->generation = gen ? gen : 1;
        }
        e->alive = 1;
        e->kind = kind;
        e->flags = MVL_ENT_VISIBLE;
        e->scale = v3(1, 1, 1);
        e->color[0] = e->color[1] = e->color[2] = e->color[3] = 1.0f;
        if (i + 1 > s->high_water) s->high_water = i + 1;
        return (e->generation << SLOT_BITS) | i;
    }
    return 0;
}

mvl_entity *mvl_scene_get(mvl_scene *s, int handle) {
    int slot = handle & SLOT_MASK, gen = handle >> SLOT_BITS;
    mvl_entity *e;
    if (handle <= 0 || slot >= MVL_MAX_ENTITIES) return NULL;
    e = &s->entities[slot];
    return (e->alive && e->generation == gen) ? e : NULL;
}

int mvl_scene_destroy(mvl_scene *s, int handle) {
    mvl_entity *e = mvl_scene_get(s, handle);
    if (!e) return 0;
    e->alive = 0;
    while (s->high_water > 0 && !s->entities[s->high_water - 1].alive) s->high_water--;
    return 1;
}

int mvl_scene_count(const mvl_scene *s) {
    int n = 0;
    for (int i = 0; i < s->high_water; ++i) n += s->entities[i].alive;
    return n;
}

mat4 mvl_entity_model_matrix(const mvl_entity *e) {
    mat4 m = m4_translate(e->pos);
    m = m4_mul(m, m4_rotate_y(e->yaw));
    m = m4_mul(m, m4_rotate_x(e->pitch));
    m = m4_mul(m, m4_rotate_z(e->roll));
    return m4_mul(m, m4_scale(e->scale));
}

mat4 mvl_camera_view(const mvl_camera *c) {
    mat4 m = m4_rotate_x(-c->pitch);
    m = m4_mul(m, m4_rotate_y(-c->yaw));
    return m4_mul(m, m4_translate(v3_scale(c->pos, -1.0f)));
}

mat4 mvl_camera_proj(const mvl_camera *c, float aspect) {
    return m4_perspective(c->fov_deg * MVL_PI / 180.0f, aspect, c->znear, c->zfar);
}

/* Pushes a circle out of one collider. Returns 1 if it was overlapping. */
static int resolve(const mvl_entity *e, vec3 *p, float r) {
    if (e->radius > 0.0f) {
        float dx = p->x - e->pos.x, dz = p->z - e->pos.z;
        float min = e->radius + r, d2 = dx * dx + dz * dz;
        if (d2 >= min * min) return 0;
        if (d2 < 1e-10f) {
            p->x = e->pos.x + min;
            return 1;
        }
        {
            float d = sqrtf(d2), push = (min - d) / d;
            p->x += dx * push;
            p->z += dz * push;
        }
        return 1;
    } else {
        /* box rotated by yaw: transform into box space */
        float c = cosf(e->yaw), sn = sinf(e->yaw);
        float dx = p->x - e->pos.x, dz = p->z - e->pos.z;
        float lx = c * dx - sn * dz, lz = sn * dx + c * dz;
        float qx = mvl_clampf(lx, -e->half_x, e->half_x), qz = mvl_clampf(lz, -e->half_z, e->half_z);
        float ex = lx - qx, ez = lz - qz, d2 = ex * ex + ez * ez;
        if (d2 >= r * r) return 0;
        if (d2 > 1e-10f) {
            float d = sqrtf(d2), push = (r - d) / d;
            lx += ex * push;
            lz += ez * push;
        } else {
            /* centre inside the box: push out along the smallest axis */
            float px = e->half_x - fabsf(lx), pz = e->half_z - fabsf(lz);
            if (px < pz) lx = (lx < 0 ? -1.0f : 1.0f) * (e->half_x + r);
            else lz = (lz < 0 ? -1.0f : 1.0f) * (e->half_z + r);
        }
        p->x = e->pos.x + c * lx + sn * lz;
        p->z = e->pos.z - sn * lx + c * lz;
        return 1;
    }
}

static int collides(const mvl_entity *e) {
    return e->alive && (e->flags & MVL_ENT_SOLID) && (e->radius > 0.0f || (e->half_x > 0.0f && e->half_z > 0.0f));
}

vec3 mvl_scene_move(const mvl_scene *s, vec3 pos, vec3 delta, float radius) {
    vec3 p = v3_add(pos, v3(delta.x, 0.0f, delta.z));
    for (int iter = 0; iter < 4; ++iter) {
        int any = 0;
        for (int i = 0; i < s->high_water; ++i)
            if (collides(&s->entities[i])) any |= resolve(&s->entities[i], &p, radius);
        if (!any) break;
    }
    p.x = mvl_clampf(p.x, s->bounds_min[0] + radius, s->bounds_max[0] - radius);
    p.z = mvl_clampf(p.z, s->bounds_min[1] + radius, s->bounds_max[1] - radius);
    return p;
}

int mvl_scene_overlaps(const mvl_scene *s, vec3 pos, float radius) {
    for (int i = 0; i < s->high_water; ++i) {
        vec3 p = pos;
        if (collides(&s->entities[i]) && resolve(&s->entities[i], &p, radius - 1e-4f)) return 1;
    }
    return 0;
}
