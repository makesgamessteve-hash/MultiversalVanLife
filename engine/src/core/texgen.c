/* Multiversal Van Life - procedural textures from recipes. MIT License. */
#include "core/texgen.h"
#include "core/noise.h"
#include <math.h>
#include <string.h>

static const char *KIND_NAMES[MVL_TEX_KIND_COUNT] = {"noise", "stone", "soil", "bark", "foliage", "water", "cloth", "brick"};

mvl_tex_kind mvl_tex_kind_from_name(const char *name) {
    for (int i = 0; name && i < MVL_TEX_KIND_COUNT; ++i)
        if (!strcmp(name, KIND_NAMES[i])) return (mvl_tex_kind)i;
    return MVL_TEX_NOISE;
}

void mvl_tex_recipe_init(mvl_tex_recipe *r, mvl_tex_kind kind, uint32_t seed) {
    static const uint8_t grey[2][4] = {{70, 70, 76, 255}, {170, 168, 160, 255}};
    memset(r, 0, sizeof *r);
    r->kind = kind;
    r->size = 32;
    r->seed = seed;
    r->scale = 4;
    r->octaves = 3;
    r->contrast = 1.0f;
    memcpy(r->colors, grey, sizeof grey);
    r->color_count = 2;
}

uint32_t mvl_tex_recipe_hash(const mvl_tex_recipe *r) {
    uint32_t h = mvl_hash3((uint32_t)r->kind, (uint32_t)r->size, r->seed);
    h = mvl_hash_combine(h, (uint32_t)r->scale);
    h = mvl_hash_combine(h, (uint32_t)r->octaves);
    h = mvl_hash_combine(h, (uint32_t)(r->contrast * 1000.0f));
    h = mvl_hash_combine(h, (uint32_t)r->color_count);
    for (int i = 0; i < r->color_count && i < MVL_TEX_MAX_COLORS; ++i)
        h = mvl_hash_combine(h, (uint32_t)r->colors[i][0] | ((uint32_t)r->colors[i][1] << 8) |
                                    ((uint32_t)r->colors[i][2] << 16) | ((uint32_t)r->colors[i][3] << 24));
    return h;
}

static void gradient(const mvl_tex_recipe *r, float t, uint8_t *out) {
    int n = r->color_count < 1 ? 1 : (r->color_count > MVL_TEX_MAX_COLORS ? MVL_TEX_MAX_COLORS : r->color_count);
    float u;
    int i;
    if (t < 0.0f) t = 0.0f;
    if (t > 1.0f) t = 1.0f;
    if (n == 1) {
        memcpy(out, r->colors[0], 4);
        return;
    }
    u = t * (float)(n - 1);
    i = (int)u;
    if (i >= n - 1) i = n - 2;
    u -= (float)i;
    for (int c = 0; c < 4; ++c) out[c] = (uint8_t)((float)r->colors[i][c] + ((float)r->colors[i + 1][c] - (float)r->colors[i][c]) * u + 0.5f);
}

/* Returns the gradient position in [0,1] for pixel (x, y). */
static float sample(const mvl_tex_recipe *r, int x, int y, float *shade) {
    float s = (float)r->size, sc = (float)r->scale;
    float fx = (float)x / s * sc, fy = (float)y / s * sc;
    int p = r->scale;
    float n = mvl_fbm2_periodic(fx, fy, p, p, r->seed, r->octaves, 0.5f) * 0.5f + 0.5f;
    uint32_t px = mvl_hash3((uint32_t)x, (uint32_t)y, r->seed);
    float speck = (float)(px & 255u) / 255.0f;
    *shade = 1.0f;
    switch (r->kind) {
    case MVL_TEX_STONE: {
        float ridge = fabsf(mvl_fbm2_periodic(fx * 1.5f, fy * 1.5f, p * 3 / 2 > 0 ? p * 3 / 2 : 1, p * 3 / 2 > 0 ? p * 3 / 2 : 1,
                                              r->seed ^ 0xa5a5u, 2, 0.5f));
        if (ridge < 0.06f) *shade = 0.55f; /* cracks */
        return n;
    }
    case MVL_TEX_SOIL:
        if (speck > 0.94f) *shade = 1.25f; /* pebbles */
        return n * 0.8f + speck * 0.2f;
    case MVL_TEX_BARK: {
        float fibres = mvl_noise2_periodic(fx * 4.0f, fy * 0.5f, p * 4, p / 2 > 0 ? p / 2 : 1, r->seed ^ 0x77u) * 0.5f + 0.5f;
        return fibres * 0.7f + n * 0.3f;
    }
    case MVL_TEX_FOLIAGE:
        if (n > 0.62f && speck > 0.7f) *shade = 1.3f; /* light catching leaves */
        if (n < 0.35f) *shade = 0.7f;
        return n;
    case MVL_TEX_WATER: {
        float w = sinf((n * 6.0f + fy * 0.5f) * 3.14159265f) * 0.5f + 0.5f;
        return n * 0.6f + w * 0.4f;
    }
    case MVL_TEX_CLOTH: {
        int stripe = (y / (r->size / 8 > 0 ? r->size / 8 : 1)) % 3 == 0;
        float weave = ((x + y) & 1) ? 0.45f : 0.55f;
        if (stripe) *shade = 0.8f;
        return weave * 0.6f + n * 0.4f;
    }
    case MVL_TEX_BRICK: {
        int bh = r->size / 8 > 0 ? r->size / 8 : 1, bw = bh * 2;
        int row = y / bh, ox = (row & 1) ? bw / 2 : 0;
        if (y % bh == 0 || (x + ox) % bw == 0) {
            *shade = 0.5f; /* mortar */
            return 0.2f;
        }
        return n * 0.5f + 0.4f + (float)(mvl_hash3((uint32_t)((x + ox) / bw), (uint32_t)row, r->seed) & 63u) / 400.0f;
    }
    default:
        return n;
    }
}

int mvl_tex_generate(const mvl_tex_recipe *r, mvl_image *img) {
    int s = r->size;
    if (s < 16 || s > 128 || (s & (s - 1)) || r->scale < 1) return 0;
    if (!mvl_image_alloc(img, s, s)) return 0;
    for (int y = 0; y < s; ++y)
        for (int x = 0; x < s; ++x) {
            float shade, t = sample(r, x, y, &shade);
            uint8_t *p = img->rgba + ((size_t)y * s + x) * 4;
            t = (t - 0.5f) * r->contrast + 0.5f;
            gradient(r, t, p);
            for (int c = 0; c < 3; ++c) {
                float v = (float)p[c] * shade;
                p[c] = (uint8_t)(v > 255.0f ? 255.0f : v);
            }
        }
    return 1;
}
