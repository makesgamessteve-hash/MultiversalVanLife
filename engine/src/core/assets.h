/* Multiversal Van Life - asset decoders (TGA images, WAV sounds, OBJ meshes,
 * MagicaVoxel .vox models) and procedural mesh builders. MIT License.
 * All decoders work on memory buffers so they are independent from files. */
#ifndef MVL_ASSETS_H
#define MVL_ASSETS_H

#include <stddef.h>
#include <stdint.h>

/* ---------------------------------------------------------------- images */
typedef struct {
    int w, h;
    uint8_t *rgba; /* w*h*4 bytes, rows top to bottom */
} mvl_image;

/* Supports uncompressed (type 2/3) and RLE (type 10/11) TGA, 8/24/32 bpp. */
int mvl_image_load_tga(const void *data, size_t size, mvl_image *out);
int mvl_image_alloc(mvl_image *img, int w, int h);
void mvl_image_free(mvl_image *img);
/* Encodes as uncompressed 32-bit top-left TGA. Caller frees. */
void *mvl_image_save_tga(const mvl_image *img, size_t *size);

/* ---------------------------------------------------------------- sounds */
typedef struct {
    int rate;
    int frames;
    int16_t *samples; /* mono */
} mvl_sound;

/* PCM WAV, 8 or 16 bit, mono or stereo (stereo is downmixed). */
int mvl_sound_load_wav(const void *data, size_t size, mvl_sound *out);
/* Wraps raw signed 16-bit mono PCM. Copies the data. */
int mvl_sound_from_pcm16(const int16_t *pcm, int frames, int rate, mvl_sound *out);
void mvl_sound_free(mvl_sound *s);

/* ---------------------------------------------------------------- meshes */
typedef struct {
    float pos[3];
    float uv[2];
    float normal[3];
    uint8_t color[4];
} mvl_vertex;

typedef struct {
    mvl_vertex *v;
    int count, cap; /* triangle list: count is a multiple of 3 */
    float min[3], max[3];
} mvl_mesh;

void mvl_mesh_init(mvl_mesh *m);
void mvl_mesh_free(mvl_mesh *m);
int mvl_mesh_push(mvl_mesh *m, const mvl_vertex *v);
void mvl_mesh_compute_bounds(mvl_mesh *m);

/* Wavefront OBJ: v/vt/vn/f with any index form; polygons are fanned.
 * Texture v coordinates are flipped so (0,0) is the image top-left. */
int mvl_mesh_load_obj(const char *text, mvl_mesh *out);

/* MagicaVoxel .vox (first model). Voxel space Z-up is converted to Y-up;
 * the model is centred on X/Z with its base at y=0. `voxel_size` is the
 * edge length in metres. Hidden faces are culled; faces get directional
 * shading baked into vertex colours. */
typedef struct {
    int sx, sy, sz;          /* .vox dimensions */
    uint8_t *cells;          /* sx*sy*sz palette indices, 0 = empty */
    uint32_t palette[256];   /* 0xAABBGGRR, palette[i] is color index i */
} mvl_voxels;

int mvl_voxels_load_vox(const void *data, size_t size, mvl_voxels *out);
void mvl_voxels_free(mvl_voxels *v);
uint8_t mvl_voxels_get(const mvl_voxels *v, int x, int y, int z);
int mvl_voxels_mesh(const mvl_voxels *v, float voxel_size, mvl_mesh *out);

/* Builders */
void mvl_mesh_add_quad(mvl_mesh *m, const float p[4][3], const float n[3],
                       float u0, float v0, float u1, float v1, const uint8_t color[4]);
/* Ground plane in XZ centred on origin with UVs repeating `tiles` times. */
void mvl_mesh_build_plane(mvl_mesh *m, float size_x, float size_z, float tiles_x, float tiles_z);
/* Axis aligned box centred on origin (x,z) with base at y=0. */
void mvl_mesh_build_box(mvl_mesh *m, float sx, float sy, float sz);

#endif
