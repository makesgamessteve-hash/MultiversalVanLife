/* Unit tests: procedural textures. MIT License. */
#include "test.h"
#include "core/texgen.h"
#include <stdlib.h>

static double edge_vs_inner(const mvl_image *img) {
    /* average colour difference across the wrap-around edge vs inside */
    double edge = 0, inner = 0;
    int s = img->w;
    for (int y = 0; y < s; ++y) {
        const uint8_t *a = img->rgba + ((size_t)y * s + (s - 1)) * 4, *b = img->rgba + ((size_t)y * s) * 4;
        const uint8_t *c = img->rgba + ((size_t)y * s + s / 2) * 4, *d = img->rgba + ((size_t)y * s + s / 2 + 1) * 4;
        for (int ch = 0; ch < 3; ++ch) {
            edge += abs((int)a[ch] - (int)b[ch]);
            inner += abs((int)c[ch] - (int)d[ch]);
        }
    }
    return edge / (inner + 1.0);
}

void test_texgen(void) {
    mvl_tex_recipe r;
    mvl_image a, b;
    CHECK_EQ_INT(mvl_tex_kind_from_name("stone"), MVL_TEX_STONE);
    CHECK_EQ_INT(mvl_tex_kind_from_name("nonsense"), MVL_TEX_NOISE);
    CHECK_EQ_INT(mvl_tex_kind_from_name(NULL), MVL_TEX_NOISE);
    for (int k = 0; k < MVL_TEX_KIND_COUNT; ++k) {
        mvl_tex_recipe_init(&r, (mvl_tex_kind)k, 1234);
        r.size = 64;
        r.color_count = 3;
        r.colors[2][0] = 200;
        r.colors[2][3] = 255;
        CHECK(mvl_tex_generate(&r, &a));
        CHECK(mvl_tex_generate(&r, &b));
        CHECK(!memcmp(a.rgba, b.rgba, 64 * 64 * 4)); /* deterministic */
        if (k != MVL_TEX_CLOTH && k != MVL_TEX_BRICK) CHECK(edge_vs_inner(&a) < 2.5); /* seamless */
        mvl_image_free(&a);
        mvl_image_free(&b);
    }
    /* recipe hash distinguishes recipes */
    mvl_tex_recipe_init(&r, MVL_TEX_STONE, 1);
    {
        uint32_t h1 = mvl_tex_recipe_hash(&r);
        r.colors[0][0] = 99;
        CHECK(h1 != mvl_tex_recipe_hash(&r));
    }
    /* single colour and invalid sizes */
    r.color_count = 1;
    CHECK(mvl_tex_generate(&r, &a));
    CHECK_EQ_INT(a.rgba[0] <= 99 * 2, 1);
    mvl_image_free(&a);
    r.color_count = 99;
    CHECK(mvl_tex_generate(&r, &a));
    mvl_image_free(&a);
    r.size = 48;
    CHECK(!mvl_tex_generate(&r, &a));
    r.size = 256;
    CHECK(!mvl_tex_generate(&r, &a));
    r.size = 16;
    r.scale = 0;
    CHECK(!mvl_tex_generate(&r, &a));
    r.scale = 1;
    r.contrast = 5.0f;
    CHECK(mvl_tex_generate(&r, &a));
    mvl_image_free(&a);
    /* recolouring: foliage only, or every visible pixel, along a palette */
    {
        const uint8_t px[4][4] = {{40, 120, 30, 255}, {100, 200, 80, 255}, {120, 80, 40, 255}, {0, 255, 0, 0}};
        const uint8_t pal[2][4] = {{10, 0, 20, 255}, {200, 0, 220, 255}};
        CHECK(mvl_image_alloc(&a, 2, 2));
        memcpy(a.rgba, px, sizeof px);
        CHECK_EQ_INT(mvl_tex_recolor(&a, pal, 2, MVL_RECOLOR_GREEN), 2);
        CHECK_EQ_INT(a.rgba[0], 10);            /* darkest leaf -> first colour */
        CHECK_EQ_INT(a.rgba[4 + 2], 220);       /* brightest leaf -> last colour */
        CHECK_EQ_INT(a.rgba[8], 120);           /* bark untouched */
        CHECK_EQ_INT(a.rgba[12 + 1], 255);      /* transparent pixel untouched */
        CHECK_EQ_INT(a.rgba[3], 255);           /* alpha kept */
        memcpy(a.rgba, px, sizeof px);
        CHECK_EQ_INT(mvl_tex_recolor(&a, pal, 2, MVL_RECOLOR_ALL), 3);
        CHECK_EQ_INT(a.rgba[8 + 1], 0);         /* bark repainted too */
        CHECK_EQ_INT(mvl_tex_recolor(&a, pal, 0, MVL_RECOLOR_ALL), 0);
        CHECK_EQ_INT(mvl_tex_recolor(NULL, pal, 2, MVL_RECOLOR_ALL), 0);
        {
            uint8_t many[8][4];
            memset(many, 90, sizeof many);
            CHECK_EQ_INT(mvl_tex_recolor(&a, (const uint8_t(*)[4])many, 8, MVL_RECOLOR_GREEN), 0); /* nothing green left */
        }
        memcpy(a.rgba, px, 4);                  /* one leaf alone: the middle of the palette */
        CHECK_EQ_INT(mvl_tex_recolor(&a, pal, 2, MVL_RECOLOR_GREEN), 1);
        CHECK(a.rgba[0] > 90 && a.rgba[0] < 120);
        mvl_image_free(&a);
    }
}
