/* Multiversal Van Life - retro OpenGL renderer. MIT License. */
#include "platform/renderer.h"
#include "core/log.h"
#include "platform/gl.h"
#include <math.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    GLuint vao, vbo;
    int count;
} gpu_mesh;

typedef struct {
    GLuint prog;
    GLint model, view, proj, tint, unlit, nofog, uv_offset, ambient, sun_dir, sun_color;
    GLint light_pos, light_color, light_range, fog_color, fog_near, fog_far, snap, tex, time;
} world_prog;

typedef struct {
    GLuint fbo, color, depth;
    int w, h;
} target;

struct mvl_renderer {
    gpu_mesh *meshes;
    int mesh_count, mesh_cap;
    world_prog world;
    GLuint sky_prog, ui_prog, post_prog;
    GLint sky_inv, sky_top, sky_hor, sky_stars, sky_tex, sky_time;
    GLint ui_proj, ui_tex;
    GLint post_tex, post_dither, post_size;
    GLuint empty_vao, ui_vao, ui_vbo;
    float *ui_verts;
    int ui_cap;
    int sprite_mesh;     /* index into meshes */
    int ui_quad_mesh;    /* textured quad used to show the UI in XR */
    target world_rt, ui_rt;
    GLuint stars_tex;
    int dither;
};

/* --------------------------------------------------------- backend glue */
static unsigned be_texture_create(void *user, const mvl_image *img, int linear, int repeat) {
    GLuint t = 0;
    (void)user;
    glGenTextures(1, &t);
    glBindTexture(GL_TEXTURE_2D, t);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, img->w, img->h, 0, GL_RGBA, GL_UNSIGNED_BYTE, img->rgba);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, linear ? GL_LINEAR : GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, linear ? GL_LINEAR : GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, repeat ? GL_REPEAT : GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, repeat ? GL_REPEAT : GL_CLAMP_TO_EDGE);
    return t;
}

static void be_texture_destroy(void *user, unsigned h) {
    GLuint t = h;
    (void)user;
    glDeleteTextures(1, &t);
}

static int add_mesh(mvl_renderer *r, const mvl_mesh *m) {
    gpu_mesh g;
    int slot = -1;
    for (int i = 0; i < r->mesh_count; ++i)
        if (!r->meshes[i].vao) { /* reuse slots of released meshes */
            slot = i;
            break;
        }
    if (slot < 0 && r->mesh_count == r->mesh_cap) {
        int ncap = r->mesh_cap ? r->mesh_cap * 2 : 64;
        gpu_mesh *n = (gpu_mesh *)realloc(r->meshes, sizeof(gpu_mesh) * (size_t)ncap);
        if (!n) return -1;
        r->meshes = n;
        r->mesh_cap = ncap;
    }
    glGenVertexArrays(1, &g.vao);
    glBindVertexArray(g.vao);
    glGenBuffers(1, &g.vbo);
    glBindBuffer(GL_ARRAY_BUFFER, g.vbo);
    glBufferData(GL_ARRAY_BUFFER, (GLsizeiptr)(sizeof(mvl_vertex) * (size_t)m->count), m->v, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, sizeof(mvl_vertex), (void *)offsetof(mvl_vertex, pos));
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, sizeof(mvl_vertex), (void *)offsetof(mvl_vertex, uv));
    glEnableVertexAttribArray(2);
    glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, sizeof(mvl_vertex), (void *)offsetof(mvl_vertex, normal));
    glEnableVertexAttribArray(3);
    glVertexAttribPointer(3, 4, GL_UNSIGNED_BYTE, GL_TRUE, sizeof(mvl_vertex), (void *)offsetof(mvl_vertex, color));
    glBindVertexArray(0);
    g.count = m->count;
    if (slot >= 0) {
        r->meshes[slot] = g;
        return slot;
    }
    r->meshes[r->mesh_count] = g;
    return r->mesh_count++;
}

static unsigned be_mesh_create(void *user, const mvl_mesh *m) {
    int i = add_mesh((mvl_renderer *)user, m);
    return i < 0 ? 0 : (unsigned)i + 1;
}

static void be_mesh_destroy(void *user, unsigned h) {
    mvl_renderer *r = (mvl_renderer *)user;
    gpu_mesh *g;
    if (h == 0 || (int)h > r->mesh_count) return;
    g = &r->meshes[h - 1];
    glDeleteBuffers(1, &g->vbo);
    glDeleteVertexArrays(1, &g->vao);
    memset(g, 0, sizeof *g);
}

mvl_renderer *mvl_renderer_create(void) { return (mvl_renderer *)calloc(1, sizeof(mvl_renderer)); }

mvl_gfx_backend mvl_renderer_backend(mvl_renderer *r) {
    mvl_gfx_backend b;
    b.user = r;
    b.texture_create = be_texture_create;
    b.texture_destroy = be_texture_destroy;
    b.mesh_create = be_mesh_create;
    b.mesh_destroy = be_mesh_destroy;
    return b;
}

/* -------------------------------------------------------------- shaders */
static GLuint compile(GLenum type, const char *src, const char *name) {
    GLuint s = glCreateShader(type);
    const char *parts[2] = {MVL_GLSL_HEADER, src};
    GLint ok = 0;
    glShaderSource(s, 2, parts, NULL);
    glCompileShader(s);
    glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[2048];
        glGetShaderInfoLog(s, sizeof log, NULL, log);
        MVL_ERROR("shader %s: %s", name, log);
        glDeleteShader(s);
        return 0;
    }
    return s;
}

static GLuint load_program(mvl_engine *e, const char *base) {
    char vp[128], fp[128];
    char *vs, *fs;
    GLuint v = 0, f = 0, p = 0;
    GLint ok = 0;
    snprintf(vp, sizeof vp, "shaders/%s.vert", base);
    snprintf(fp, sizeof fp, "shaders/%s.frag", base);
    vs = mvl_vfs_read(&e->vfs, vp, NULL);
    fs = mvl_vfs_read(&e->vfs, fp, NULL);
    if (vs && fs) {
        v = compile(GL_VERTEX_SHADER, vs, vp);
        f = compile(GL_FRAGMENT_SHADER, fs, fp);
    } else {
        MVL_ERROR("shader sources for '%s' not found", base);
    }
    free(vs);
    free(fs);
    if (!v || !f) return 0;
    p = glCreateProgram();
    glAttachShader(p, v);
    glAttachShader(p, f);
    glBindAttribLocation(p, 0, "aPos");
    glBindAttribLocation(p, 1, "aUV");
    glBindAttribLocation(p, 2, "aNormal");
    glBindAttribLocation(p, 3, "aColor");
    glLinkProgram(p);
    glDeleteShader(v);
    glDeleteShader(f);
    glGetProgramiv(p, GL_LINK_STATUS, &ok);
    if (!ok) {
        char log[2048];
        glGetProgramInfoLog(p, sizeof log, NULL, log);
        MVL_ERROR("program %s: %s", base, log);
        glDeleteProgram(p);
        return 0;
    }
    return p;
}

static void destroy_target(target *t) {
    if (t->fbo) glDeleteFramebuffers(1, &t->fbo);
    if (t->color) glDeleteTextures(1, &t->color);
    if (t->depth) glDeleteRenderbuffers(1, &t->depth);
    memset(t, 0, sizeof *t);
}

static void ensure_target(target *t, int w, int h, int depth) {
    if (t->fbo && t->w == w && t->h == h) return;
    destroy_target(t);
    t->w = w;
    t->h = h;
    glGenTextures(1, &t->color);
    glBindTexture(GL_TEXTURE_2D, t->color);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glGenFramebuffers(1, &t->fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, t->fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, t->color, 0);
    if (depth) {
        glGenRenderbuffers(1, &t->depth);
        glBindRenderbuffer(GL_RENDERBUFFER, t->depth);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, w, h);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, t->depth);
    }
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) MVL_ERROR("render target incomplete");
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

int mvl_renderer_init(mvl_renderer *r, mvl_engine *e) {
    world_prog *w = &r->world;
    mvl_mesh quad;
    w->prog = load_program(e, "world");
    r->sky_prog = load_program(e, "sky");
    r->ui_prog = load_program(e, "ui");
    r->post_prog = load_program(e, "post");
    if (!w->prog || !r->sky_prog || !r->ui_prog || !r->post_prog) return 0;
#define U(field, name) w->field = glGetUniformLocation(w->prog, name)
    U(model, "uModel"); U(view, "uView"); U(proj, "uProj"); U(tint, "uTint"); U(unlit, "uUnlit");
    U(nofog, "uNoFog"); U(uv_offset, "uUVOffset"); U(ambient, "uAmbient"); U(sun_dir, "uSunDir");
    U(sun_color, "uSunColor"); U(light_pos, "uLightPos"); U(light_color, "uLightColor");
    U(light_range, "uLightRange"); U(fog_color, "uFogColor"); U(fog_near, "uFogNear"); U(fog_far, "uFogFar");
    U(snap, "uSnap"); U(tex, "uTex"); U(time, "uTime");
#undef U
    r->sky_inv = glGetUniformLocation(r->sky_prog, "uInvViewProj");
    r->sky_top = glGetUniformLocation(r->sky_prog, "uTop");
    r->sky_hor = glGetUniformLocation(r->sky_prog, "uHorizon");
    r->sky_stars = glGetUniformLocation(r->sky_prog, "uStars");
    r->sky_tex = glGetUniformLocation(r->sky_prog, "uTex");
    r->sky_time = glGetUniformLocation(r->sky_prog, "uTime");
    r->ui_proj = glGetUniformLocation(r->ui_prog, "uProj");
    r->ui_tex = glGetUniformLocation(r->ui_prog, "uTex");
    r->post_tex = glGetUniformLocation(r->post_prog, "uTex");
    r->post_dither = glGetUniformLocation(r->post_prog, "uDither");
    r->post_size = glGetUniformLocation(r->post_prog, "uSize");

    glGenVertexArrays(1, &r->empty_vao);
    glGenVertexArrays(1, &r->ui_vao);
    glGenBuffers(1, &r->ui_vbo);
    glBindVertexArray(r->ui_vao);
    glBindBuffer(GL_ARRAY_BUFFER, r->ui_vbo);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void *)0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void *)(2 * sizeof(float)));
    glEnableVertexAttribArray(3);
    glVertexAttribPointer(3, 4, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void *)(4 * sizeof(float)));
    glBindVertexArray(0);

    /* unit billboard: x -0.5..0.5, y 0..1, facing +Z */
    mvl_mesh_init(&quad);
    {
        const float p[4][3] = {{-0.5f, 0, 0}, {0.5f, 0, 0}, {0.5f, 1, 0}, {-0.5f, 1, 0}};
        const float n[3] = {0, 0, 1};
        mvl_mesh_add_quad(&quad, p, n, 0, 0, 1, 1, NULL);
    }
    r->sprite_mesh = add_mesh(r, &quad);
    mvl_mesh_free(&quad);
    mvl_mesh_init(&quad);
    {
        /* UI panel for XR: 1.6 x 0.9 m centred, uv v flipped for FBO */
        const float p[4][3] = {{-0.8f, -0.45f, 0}, {0.8f, -0.45f, 0}, {0.8f, 0.45f, 0}, {-0.8f, 0.45f, 0}};
        const float n[3] = {0, 0, 1};
        mvl_mesh_add_quad(&quad, p, n, 0, 1, 1, 0, NULL);
    }
    r->ui_quad_mesh = add_mesh(r, &quad);
    mvl_mesh_free(&quad);
    {
        int id = mvl_res_texture(&e->res, mvl_kv_get_str(&e->config, "render.sky_texture", "textures/sky_stars.tga"));
        const mvl_texture_res *t = mvl_res_get_texture(&e->res, id);
        r->stars_tex = t ? t->handle : 0;
    }
    r->dither = mvl_kv_get_bool(&e->config, "render.dither", 1);
    MVL_INFO("renderer ready: %s", (const char *)glGetString(GL_VERSION));
    return 1;
}

void mvl_renderer_destroy(mvl_renderer *r) {
    if (!r) return;
    for (int i = 0; i < r->mesh_count; ++i)
        if (r->meshes[i].vao) be_mesh_destroy(r, (unsigned)i + 1);
    destroy_target(&r->world_rt);
    destroy_target(&r->ui_rt);
    if (r->world.prog) glDeleteProgram(r->world.prog);
    if (r->sky_prog) glDeleteProgram(r->sky_prog);
    if (r->ui_prog) glDeleteProgram(r->ui_prog);
    if (r->post_prog) glDeleteProgram(r->post_prog);
    free(r->meshes);
    free(r->ui_verts);
    free(r);
}

/* ---------------------------------------------------------------- world */
static GLuint tex_handle(mvl_engine *e, int id) {
    const mvl_texture_res *t = mvl_res_get_texture(&e->res, id);
    if (!t) t = mvl_res_get_texture(&e->res, 0);
    return t ? t->handle : 0;
}

static void draw_sky(mvl_renderer *r, mvl_engine *e, mat4 view, mat4 proj) {
    mat4 vp, inv;
    mvl_environment *env = &e->scene.env;
    view.m[12] = view.m[13] = view.m[14] = 0.0f; /* rotation only */
    vp = m4_mul(proj, view);
    if (!m4_invert(vp, &inv)) inv = m4_identity();
    glDisable(GL_DEPTH_TEST);
    glDepthMask(GL_FALSE);
    glUseProgram(r->sky_prog);
    glUniformMatrix4fv(r->sky_inv, 1, GL_FALSE, inv.m);
    glUniform3f(r->sky_top, env->sky_top[0], env->sky_top[1], env->sky_top[2]);
    glUniform3f(r->sky_hor, env->sky_horizon[0], env->sky_horizon[1], env->sky_horizon[2]);
    glUniform1f(r->sky_stars, r->stars_tex ? env->stars : 0.0f);
    glUniform1f(r->sky_time, (float)e->time);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, r->stars_tex ? r->stars_tex : tex_handle(e, 0));
    glUniform1i(r->sky_tex, 0);
    glBindVertexArray(r->empty_vao);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    glDepthMask(GL_TRUE);
    glEnable(GL_DEPTH_TEST);
}

static void set_world_uniforms(mvl_renderer *r, mvl_engine *e, mat4 view, mat4 proj, float snap_w, float snap_h) {
    world_prog *w = &r->world;
    mvl_environment *env = &e->scene.env;
    float lp[MVL_MAX_LIGHTS * 3], lc[MVL_MAX_LIGHTS * 3], lr[MVL_MAX_LIGHTS];
    for (int i = 0; i < MVL_MAX_LIGHTS; ++i) {
        const mvl_light *l = &e->scene.lights[i];
        lp[i * 3] = l->pos.x;
        lp[i * 3 + 1] = l->pos.y;
        lp[i * 3 + 2] = l->pos.z;
        memcpy(lc + i * 3, l->color, sizeof(float) * 3);
        lr[i] = l->enabled ? l->range : 0.0f;
    }
    glUseProgram(w->prog);
    glUniformMatrix4fv(w->view, 1, GL_FALSE, view.m);
    glUniformMatrix4fv(w->proj, 1, GL_FALSE, proj.m);
    glUniform3f(w->ambient, env->ambient[0], env->ambient[1], env->ambient[2]);
    glUniform3f(w->sun_dir, env->sun_dir.x, env->sun_dir.y, env->sun_dir.z);
    glUniform3f(w->sun_color, env->sun_color[0], env->sun_color[1], env->sun_color[2]);
    glUniform3fv(w->light_pos, MVL_MAX_LIGHTS, lp);
    glUniform3fv(w->light_color, MVL_MAX_LIGHTS, lc);
    glUniform1fv(w->light_range, MVL_MAX_LIGHTS, lr);
    glUniform3f(w->fog_color, env->fog_color[0], env->fog_color[1], env->fog_color[2]);
    glUniform1f(w->fog_near, env->fog_near);
    glUniform1f(w->fog_far, env->fog_far);
    glUniform2f(w->snap, snap_w * 0.5f, snap_h * 0.5f);
    glUniform1f(w->time, (float)e->time);
    glUniform1i(w->tex, 0);
    glActiveTexture(GL_TEXTURE0);
}

static void draw_entity(mvl_renderer *r, mvl_engine *e, const mvl_entity *en, float face_yaw) {
    world_prog *w = &r->world;
    const gpu_mesh *g = NULL;
    mat4 model;
    if (en->kind == MVL_ENT_SPRITE) {
        g = &r->meshes[r->sprite_mesh];
        model = m4_mul(m4_translate(mvl_scene_world_pos(&e->scene, en)), m4_rotate_y(face_yaw));
        if (en->roll != 0.0f) model = m4_mul(model, m4_mul(m4_translate(v3(0, 0.5f * en->scale.y, 0)),
                                                         m4_mul(m4_rotate_z(en->roll), m4_translate(v3(0, -0.5f * en->scale.y, 0)))));
        model = m4_mul(model, m4_scale(v3(en->scale.x, en->scale.y, 1.0f)));
    } else {
        const mvl_mesh_res *mr = mvl_res_get_mesh(&e->res, en->mesh);
        if (!mr || mr->handle == 0 || (int)mr->handle > r->mesh_count) return;
        g = &r->meshes[mr->handle - 1];
        model = mvl_scene_world_matrix(&e->scene, en);
    }
    if (!g->vao) return;
    glUniformMatrix4fv(w->model, 1, GL_FALSE, model.m);
    glUniform4f(w->tint, en->color[0], en->color[1], en->color[2], en->color[3]);
    glUniform1f(w->unlit, (en->flags & MVL_ENT_UNLIT) ? 1.0f : 0.0f);
    glUniform1f(w->nofog, (en->flags & MVL_ENT_NOFOG) ? 1.0f : 0.0f);
    glUniform2f(w->uv_offset, en->uv_scroll[0] * (float)e->time, en->uv_scroll[1] * (float)e->time);
    glBindTexture(GL_TEXTURE_2D, tex_handle(e, en->texture));
    glBindVertexArray(g->vao);
    glDrawArrays(GL_TRIANGLES, 0, g->count);
}

static void draw_world(mvl_renderer *r, mvl_engine *e, mat4 view, mat4 proj, float face_yaw, float snap_w, float snap_h) {
    mvl_scene *s = &e->scene;
    draw_sky(r, e, view, proj);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);
    glDisable(GL_BLEND);
    set_world_uniforms(r, e, view, proj, snap_w, snap_h);
    for (int pass = 0; pass < 2; ++pass) {
        if (pass == 1) {
            glEnable(GL_BLEND);
            glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            glDepthMask(GL_FALSE);
        }
        for (int i = 0; i < s->high_water; ++i) {
            const mvl_entity *en = &s->entities[i];
            int translucent;
            if (!en->alive || !(en->flags & MVL_ENT_VISIBLE)) continue;
            translucent = en->color[3] < 0.999f;
            if (translucent != pass) continue;
            if (en->kind == MVL_ENT_SPRITE) glDisable(GL_CULL_FACE);
            draw_entity(r, e, en, face_yaw);
            if (en->kind == MVL_ENT_SPRITE) glEnable(GL_CULL_FACE);
        }
    }
    glDepthMask(GL_TRUE);
    glDisable(GL_BLEND);
    glDisable(GL_CULL_FACE);
}

/* ------------------------------------------------------------------- UI */
static void draw_ui(mvl_renderer *r, mvl_engine *e) {
    mvl_ui *ui = &e->ui;
    mat4 proj = m4_ortho(0, ui->width, ui->height, 0, -1, 1);
    int need = ui->count * 6 * 8;
    if (ui->count == 0) return;
    if (need > r->ui_cap) {
        float *n = (float *)realloc(r->ui_verts, sizeof(float) * (size_t)need);
        if (!n) return;
        r->ui_verts = n;
        r->ui_cap = need;
    }
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glUseProgram(r->ui_prog);
    glUniformMatrix4fv(r->ui_proj, 1, GL_FALSE, proj.m);
    glUniform1i(r->ui_tex, 0);
    glActiveTexture(GL_TEXTURE0);
    glBindVertexArray(r->ui_vao);
    glBindBuffer(GL_ARRAY_BUFFER, r->ui_vbo);
    {
        int start = 0;
        while (start < ui->count) {
            int tex = ui->quads[start].texture, end = start, n = 0;
            float *v = r->ui_verts;
            while (end < ui->count && ui->quads[end].texture == tex) {
                const mvl_ui_quad *q = &ui->quads[end];
                const float xs[6] = {q->x, q->x + q->w, q->x + q->w, q->x, q->x + q->w, q->x};
                const float ys[6] = {q->y, q->y, q->y + q->h, q->y, q->y + q->h, q->y + q->h};
                const float us[6] = {q->u0, q->u1, q->u1, q->u0, q->u1, q->u0};
                const float vs[6] = {q->v0, q->v0, q->v1, q->v0, q->v1, q->v1};
                for (int k = 0; k < 6; ++k) {
                    *v++ = xs[k];
                    *v++ = ys[k];
                    *v++ = us[k];
                    *v++ = vs[k];
                    memcpy(v, q->color, sizeof(float) * 4);
                    v += 4;
                }
                n += 6;
                ++end;
            }
            glBufferData(GL_ARRAY_BUFFER, (GLsizeiptr)(sizeof(float) * 8 * (size_t)n), r->ui_verts, GL_STREAM_DRAW);
            glBindTexture(GL_TEXTURE_2D, tex_handle(e, tex));
            glDrawArrays(GL_TRIANGLES, 0, n);
            start = end;
        }
    }
    glDisable(GL_BLEND);
}

static void render_ui_canvas(mvl_renderer *r, mvl_engine *e) {
    ensure_target(&r->ui_rt, (int)e->ui.width, (int)e->ui.height, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, r->ui_rt.fbo);
    glViewport(0, 0, r->ui_rt.w, r->ui_rt.h);
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);
    draw_ui(r, e);
}

static void blit(mvl_renderer *r, GLuint tex, int dither, int blend, int w, int h, int sw, int sh) {
    glUseProgram(r->post_prog);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, tex);
    glUniform1i(r->post_tex, 0);
    glUniform1f(r->post_dither, dither ? 1.0f : 0.0f);
    glUniform2f(r->post_size, (float)sw, (float)sh);
    if (blend) {
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    }
    glBindVertexArray(r->empty_vao);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    glDisable(GL_BLEND);
    (void)w;
    (void)h;
}

void mvl_renderer_draw(mvl_renderer *r, mvl_engine *e, int w, int h) {
    int rh = mvl_kv_get_int(&e->config, "render.height", 240), rw;
    float aspect = h > 0 ? (float)w / (float)h : 1.0f;
    mat4 view, proj;
    if (rh < 60) rh = 60;
    if (rh > h && h > 0) rh = h;
    rw = (int)((float)rh * aspect + 0.5f);
    if (rw < 1) rw = 1;
    ensure_target(&r->world_rt, rw, rh, 1);
    glBindFramebuffer(GL_FRAMEBUFFER, r->world_rt.fbo);
    glViewport(0, 0, rw, rh);
    glClearColor(e->scene.env.fog_color[0], e->scene.env.fog_color[1], e->scene.env.fog_color[2], 1);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    view = mvl_camera_view(&e->scene.camera);
    proj = mvl_camera_proj(&e->scene.camera, (float)rw / (float)rh);
    draw_world(r, e, view, proj, e->scene.camera.yaw, (float)rw, (float)rh);
    render_ui_canvas(r, e);

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glViewport(0, 0, w, h);
    glDisable(GL_DEPTH_TEST);
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    blit(r, r->world_rt.color, r->dither, 0, w, h, rw, rh);
    blit(r, r->ui_rt.color, 0, 1, w, h, r->ui_rt.w, r->ui_rt.h);
}

void mvl_renderer_prepare_xr(mvl_renderer *r, mvl_engine *e) { render_ui_canvas(r, e); }

void mvl_renderer_draw_xr_view(mvl_renderer *r, mvl_engine *e, unsigned fbo, const int vp[4],
                               const float view_m[16], const float proj_m[16]) {
    mvl_camera *c = &e->scene.camera;
    mat4 head_view, proj, body, view, head_world, panel;
    float eye_h = mvl_kv_get_float(&e->config, "xr.eye_height", 1.6f);
    memcpy(head_view.m, view_m, sizeof head_view.m);
    memcpy(proj.m, proj_m, sizeof proj.m);
    /* body transform: player position on the floor, turned by camera yaw */
    body = m4_mul(m4_rotate_y(-c->yaw), m4_translate(v3(-c->pos.x, -(c->pos.y - eye_h), -c->pos.z)));
    view = m4_mul(head_view, body);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glViewport(vp[0], vp[1], vp[2], vp[3]);
    glEnable(GL_SCISSOR_TEST);
    glScissor(vp[0], vp[1], vp[2], vp[3]);
    glClearColor(e->scene.env.fog_color[0], e->scene.env.fog_color[1], e->scene.env.fog_color[2], 1);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glDisable(GL_SCISSOR_TEST);
    draw_world(r, e, view, proj, c->yaw + e->xr_head_yaw, 480.0f, 480.0f);
    /* head-locked UI panel 1.5 m in front of the eyes */
    if (e->ui.count > 0 && m4_invert(view, &head_world)) {
        const mvl_entity dummy = {0};
        (void)dummy;
        panel = m4_mul(head_world, m4_translate(v3(0, -0.1f, -1.5f)));
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glDisable(GL_DEPTH_TEST);
        glUseProgram(r->world.prog);
        glUniformMatrix4fv(r->world.model, 1, GL_FALSE, panel.m);
        glUniform4f(r->world.tint, 1, 1, 1, 1);
        glUniform1f(r->world.unlit, 1.0f);
        glUniform1f(r->world.nofog, 1.0f);
        glUniform2f(r->world.uv_offset, 0, 0);
        glBindTexture(GL_TEXTURE_2D, r->ui_rt.color);
        glBindVertexArray(r->meshes[r->ui_quad_mesh].vao);
        glDrawArrays(GL_TRIANGLES, 0, r->meshes[r->ui_quad_mesh].count);
        glEnable(GL_DEPTH_TEST);
        glDisable(GL_BLEND);
    }
}

int mvl_renderer_screenshot(mvl_renderer *r, int w, int h, mvl_image *out) {
    (void)r;
    if (!mvl_image_alloc(out, w, h)) return 0;
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glPixelStorei(GL_PACK_ALIGNMENT, 1);
    glReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, out->rgba);
    /* flip to top-left origin */
    for (int y = 0; y < h / 2; ++y)
        for (int x = 0; x < w * 4; ++x) {
            uint8_t *a = out->rgba + (size_t)y * w * 4 + x, *b = out->rgba + (size_t)(h - 1 - y) * w * 4 + x, t = *a;
            *a = *b;
            *b = t;
        }
    return 1;
}
