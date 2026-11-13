/* Multiversal Van Life - resource cache. MIT License. */
#include "core/resources.h"
#include "core/compat.h"
#include "core/log.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static unsigned g_null_next = 1;
static unsigned null_tex_create(void *u, const mvl_image *img, int lin, int rep) { return g_null_next++; }
static void null_destroy(void *u, unsigned h) {}
static unsigned null_mesh_create(void *u, const mvl_mesh *m) { return g_null_next++; }

mvl_gfx_backend mvl_gfx_null_backend(void) {
    mvl_gfx_backend b;
    memset(&b, 0, sizeof b);
    b.texture_create = null_tex_create;
    b.texture_destroy = null_destroy;
    b.mesh_create = null_mesh_create;
    b.mesh_destroy = null_destroy;
    return b;
}

void mvl_res_init(mvl_resources *r, const mvl_vfs *vfs, mvl_gfx_backend gfx) {
    mvl_image white;
    memset(r, 0, sizeof *r);
    r->vfs = vfs;
    r->gfx = gfx;
    /* id 0 of meshes and sounds is reserved as "invalid" */
    r->mesh_count = 1;
    r->sound_count = 1;
    if (mvl_image_alloc(&white, 4, 4)) {
        memset(white.rgba, 255, 4 * 4 * 4);
        snprintf(r->textures[0].path, MVL_PATH_MAX, "<white>");
        r->textures[0].w = r->textures[0].h = 4;
        r->textures[0].handle = gfx.texture_create(gfx.user, &white, 0, 1);
        mvl_image_free(&white);
    }
    r->texture_count = 1;
}

void mvl_res_shutdown(mvl_resources *r) {
    for (int i = 0; i < r->texture_count; ++i)
        if (r->textures[i].handle) r->gfx.texture_destroy(r->gfx.user, r->textures[i].handle);
    for (int i = 1; i < r->mesh_count; ++i)
        if (r->meshes[i].handle) r->gfx.mesh_destroy(r->gfx.user, r->meshes[i].handle);
    for (int i = 1; i < r->sound_count; ++i) mvl_sound_free(&r->sounds[i].sound);
    r->texture_count = r->mesh_count = r->sound_count = 0;
}

static int ends_with(const char *s, const char *suffix) {
    size_t a = strlen(s), b = strlen(suffix);
    return a >= b && strcasecmp(s + a - b, suffix) == 0;
}

/* Finds a released slot in [1, count) or appends one. Returns -1 if full. */
static int free_texture_slot(mvl_resources *r) {
    for (int i = 1; i < r->texture_count; ++i)
        if (!r->textures[i].handle) return i;
    return r->texture_count < MVL_MAX_TEXTURES ? r->texture_count : -1;
}

static int free_mesh_slot(mvl_resources *r) {
    for (int i = 1; i < r->mesh_count; ++i)
        if (!r->meshes[i].handle) return i;
    return r->mesh_count < MVL_MAX_MESHES ? r->mesh_count : -1;
}

int mvl_res_texture_from_image(mvl_resources *r, const char *name, const mvl_image *img, int linear) {
    mvl_texture_res *t;
    int id = free_texture_slot(r);
    if (id < 0) return 0;
    t = &r->textures[id];
    t->handle = r->gfx.texture_create(r->gfx.user, img, linear, 1);
    if (!t->handle) return 0;
    snprintf(t->path, MVL_PATH_MAX, "%s", name);
    t->w = img->w;
    t->h = img->h;
    if (id == r->texture_count) r->texture_count++;
    return id;
}

int mvl_res_release_texture(mvl_resources *r, int id) {
    mvl_texture_res *t;
    if (id <= 0 || id >= r->texture_count || !r->textures[id].handle) return 0;
    t = &r->textures[id];
    r->gfx.texture_destroy(r->gfx.user, t->handle);
    memset(t, 0, sizeof *t);
    return 1;
}

int mvl_res_find_texture(const mvl_resources *r, const char *name) {
    for (int i = 1; i < r->texture_count; ++i)
        if (r->textures[i].handle && !strcmp(r->textures[i].path, name)) return i;
    return 0;
}

int mvl_res_release_mesh(mvl_resources *r, int id) {
    mvl_mesh_res *m;
    if (id <= 0 || id >= r->mesh_count || !r->meshes[id].handle) return 0;
    m = &r->meshes[id];
    r->gfx.mesh_destroy(r->gfx.user, m->handle);
    memset(m, 0, sizeof *m);
    return 1;
}

int mvl_res_texture(mvl_resources *r, const char *path) {
    size_t size;
    char *data;
    mvl_image img;
    int id;
    if (!path) return 0;
    for (int i = 1; i < r->texture_count; ++i)
        if (r->textures[i].handle && !strcmp(r->textures[i].path, path)) return i;
    data = mvl_vfs_read(r->vfs, path, &size);
    if (!data) {
        MVL_WARN("texture not found: %s", path);
        return 0;
    }
    if (!mvl_image_load_tga(data, size, &img)) {
        MVL_WARN("could not decode texture: %s", path);
        free(data);
        return 0;
    }
    free(data);
    id = mvl_res_texture_from_image(r, path, &img, 0);
    mvl_image_free(&img);
    return id;
}

int mvl_res_mesh_from_data(mvl_resources *r, const char *name, const mvl_mesh *mesh) {
    mvl_mesh_res *m;
    int id = free_mesh_slot(r);
    if (id < 0 || mesh->count == 0) return 0;
    m = &r->meshes[id];
    m->handle = r->gfx.mesh_create(r->gfx.user, mesh);
    if (!m->handle) return 0;
    snprintf(m->path, MVL_PATH_MAX, "%s", name);
    m->vertex_count = mesh->count;
    memcpy(m->min, mesh->min, sizeof m->min);
    memcpy(m->max, mesh->max, sizeof m->max);
    if (id == r->mesh_count) r->mesh_count++;
    return id;
}

int mvl_res_mesh(mvl_resources *r, const char *path, float voxel_size) {
    char key[MVL_PATH_MAX];
    size_t size;
    char *data;
    mvl_mesh mesh;
    int ok = 0, id;
    if (!path) return 0;
    if (ends_with(path, ".vox")) snprintf(key, sizeof key, "%s@%g", path, voxel_size);
    else snprintf(key, sizeof key, "%s", path);
    for (int i = 1; i < r->mesh_count; ++i)
        if (r->meshes[i].handle && !strcmp(r->meshes[i].path, key)) return i;
    data = mvl_vfs_read(r->vfs, path, &size);
    if (!data) {
        MVL_WARN("mesh not found: %s", path);
        return 0;
    }
    if (ends_with(path, ".obj")) {
        ok = mvl_mesh_load_obj(data, &mesh);
    } else if (ends_with(path, ".vox")) {
        mvl_voxels vox;
        if (mvl_voxels_load_vox(data, size, &vox)) {
            ok = mvl_voxels_mesh(&vox, voxel_size > 0 ? voxel_size : 0.125f, &mesh);
            mvl_voxels_free(&vox);
            if (!ok) mvl_mesh_free(&mesh);
        }
    }
    free(data);
    if (!ok) {
        MVL_WARN("could not decode mesh: %s", path);
        return 0;
    }
    id = mvl_res_mesh_from_data(r, key, &mesh);
    mvl_mesh_free(&mesh);
    return id;
}

int mvl_res_sound(mvl_resources *r, const char *path) {
    size_t size;
    char *data;
    mvl_sound_res *s;
    if (!path) return 0;
    for (int i = 1; i < r->sound_count; ++i)
        if (!strcmp(r->sounds[i].path, path)) return i;
    if (r->sound_count >= MVL_MAX_SOUNDS) return 0;
    data = mvl_vfs_read(r->vfs, path, &size);
    if (!data) {
        MVL_WARN("sound not found: %s", path);
        return 0;
    }
    s = &r->sounds[r->sound_count];
    if (!(ends_with(path, ".mp3") ? mvl_sound_load_mp3(data, size, &s->sound) : mvl_sound_load_wav(data, size, &s->sound))) {
        MVL_WARN("could not decode sound: %s", path);
        free(data);
        return 0;
    }
    free(data);
    snprintf(s->path, MVL_PATH_MAX, "%s", path);
    return r->sound_count++;
}

const mvl_sound *mvl_res_get_sound(const mvl_resources *r, int id) {
    return (id > 0 && id < r->sound_count) ? &r->sounds[id].sound : NULL;
}

const mvl_mesh_res *mvl_res_get_mesh(const mvl_resources *r, int id) {
    return (id > 0 && id < r->mesh_count && r->meshes[id].handle) ? &r->meshes[id] : NULL;
}

const mvl_texture_res *mvl_res_get_texture(const mvl_resources *r, int id) {
    return (id >= 0 && id < r->texture_count && r->textures[id].handle) ? &r->textures[id] : NULL;
}
