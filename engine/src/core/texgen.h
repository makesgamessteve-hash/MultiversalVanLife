/* Multiversal Van Life - procedural textures from recipes. MIT License.
 * Textures are small (16..128 px), seamless (periodic noise) and built from
 * a palette gradient, in the retro style of the hand-made art. */
#ifndef MVL_TEXGEN_H
#define MVL_TEXGEN_H

#include "core/assets.h"
#include <stdint.h>

typedef enum {
    MVL_TEX_NOISE = 0, /* smooth fractal noise */
    MVL_TEX_STONE,     /* noise with dark cracks */
    MVL_TEX_SOIL,      /* noise with pebbles */
    MVL_TEX_BARK,      /* vertical fibres */
    MVL_TEX_FOLIAGE,   /* leafy clumps with highlights */
    MVL_TEX_WATER,     /* soft ripples */
    MVL_TEX_CLOTH,     /* woven threads with stripes */
    MVL_TEX_BRICK,     /* bricks with mortar */
    MVL_TEX_KIND_COUNT
} mvl_tex_kind;

#define MVL_TEX_MAX_COLORS 6

typedef struct {
    mvl_tex_kind kind;
    int size;          /* power of two 16..128 */
    uint32_t seed;
    int scale;         /* noise cells across the texture (period) */
    int octaves;
    float contrast;    /* 1 = normal */
    uint8_t colors[MVL_TEX_MAX_COLORS][4];
    int color_count;
} mvl_tex_recipe;

void mvl_tex_recipe_init(mvl_tex_recipe *r, mvl_tex_kind kind, uint32_t seed);
/* Generates the texture into img (allocated). Returns 1 on success. */
int mvl_tex_generate(const mvl_tex_recipe *r, mvl_image *img);
/* Stable hash of a recipe, used to cache generated textures. */
uint32_t mvl_tex_recipe_hash(const mvl_tex_recipe *r);
mvl_tex_kind mvl_tex_kind_from_name(const char *name);

#endif
