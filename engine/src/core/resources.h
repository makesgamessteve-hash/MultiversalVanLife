/* Multiversal Van Life - resource cache (textures, meshes, sounds). MIT License.
 *
 * Resources are loaded by relative path through the VFS and cached by path.
 * GPU uploads go through an abstract graphics backend so the core stays
 * independent of OpenGL (a null backend is used in tests and headless mode).
 */
#ifndef MVL_RESOURCES_H
#define MVL_RESOURCES_H

#include "core/assets.h"
#include "core/vfs.h"

#define MVL_MAX_TEXTURES 512
#define MVL_MAX_MESHES 1024
#define MVL_MAX_SOUNDS 256

typedef struct mvl_gfx_backend {
    void *user;
    /* return a non-zero handle on success */
    unsigned (*texture_create)(void *user, const mvl_image *img, int filter_linear, int repeat);
    void (*texture_destroy)(void *user, unsigned handle);
    unsigned (*mesh_create)(void *user, const mvl_mesh *mesh);
    void (*mesh_destroy)(void *user, unsigned handle);
} mvl_gfx_backend;

typedef struct {
    char path[MVL_PATH_MAX];
    int w, h;
    unsigned handle;
} mvl_texture_res;

typedef struct {
    char path[MVL_PATH_MAX];
    unsigned handle;
    int vertex_count;
    float min[3], max[3];
} mvl_mesh_res;

typedef struct {
    char path[MVL_PATH_MAX];
    mvl_sound sound;
} mvl_sound_res;

typedef struct {
    const mvl_vfs *vfs;
    mvl_gfx_backend gfx;
    mvl_texture_res textures[MVL_MAX_TEXTURES]; /* index 0 = built-in white */
    int texture_count;
    mvl_mesh_res meshes[MVL_MAX_MESHES];        /* index 0 = invalid */
    int mesh_count;
    mvl_sound_res sounds[MVL_MAX_SOUNDS];       /* index 0 = invalid */
    int sound_count;
} mvl_resources;

/* A backend whose create functions just hand out increasing handles. */
mvl_gfx_backend mvl_gfx_null_backend(void);

void mvl_res_init(mvl_resources *r, const mvl_vfs *vfs, mvl_gfx_backend gfx);
void mvl_res_shutdown(mvl_resources *r);

/* All loaders return an id > 0 or 0 on failure. Repeated loads of the same
 * path return the cached id. */
int mvl_res_texture(mvl_resources *r, const char *path);
int mvl_res_texture_from_image(mvl_resources *r, const char *name, const mvl_image *img, int linear);
/* Path ending in .obj or .vox. `voxel_size` is used for .vox only. */
int mvl_res_mesh(mvl_resources *r, const char *path, float voxel_size);
int mvl_res_mesh_from_data(mvl_resources *r, const char *name, const mvl_mesh *mesh);
int mvl_res_sound(mvl_resources *r, const char *path);
const mvl_sound *mvl_res_get_sound(const mvl_resources *r, int id);
/* Destroys a runtime resource; its id becomes invalid and the slot reusable.
 * The built-in white texture (id 0) cannot be released. Returns 1 on success. */
int mvl_res_release_mesh(mvl_resources *r, int id);
/* Number of meshes currently loaded. */
int mvl_res_mesh_live(const mvl_resources *r);
/* Id of a live texture created under `name`, or 0. */
int mvl_res_find_texture(const mvl_resources *r, const char *name);
int mvl_res_release_texture(mvl_resources *r, int id);
const mvl_mesh_res *mvl_res_get_mesh(const mvl_resources *r, int id);
const mvl_texture_res *mvl_res_get_texture(const mvl_resources *r, int id);

#endif
