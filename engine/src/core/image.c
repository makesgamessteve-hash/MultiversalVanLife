/* Multiversal Van Life - TGA image codec. MIT License. */
#include "core/assets.h"
#include <stdlib.h>
#include <string.h>

int mvl_image_alloc(mvl_image *img, int w, int h) {
    img->w = w;
    img->h = h;
    img->rgba = (w > 0 && h > 0) ? (uint8_t *)calloc((size_t)w * (size_t)h, 4) : NULL;
    return img->rgba != NULL;
}

void mvl_image_free(mvl_image *img) {
    free(img->rgba);
    img->rgba = NULL;
    img->w = img->h = 0;
}

static void put_pixel(uint8_t *dst, const uint8_t *src, int bpp) {
    if (bpp == 1) {
        dst[0] = dst[1] = dst[2] = src[0];
        dst[3] = 255;
    } else {
        dst[0] = src[2];
        dst[1] = src[1];
        dst[2] = src[0];
        dst[3] = bpp == 4 ? src[3] : 255;
    }
}

int mvl_image_load_tga(const void *data, size_t size, mvl_image *out) {
    const uint8_t *d = (const uint8_t *)data;
    const uint8_t *p, *end;
    int idlen, cmaptype, type, w, h, bits, desc, bpp, rle, top, npix;
    uint8_t *tmp;
    memset(out, 0, sizeof *out);
    if (!d || size < 18) return 0;
    idlen = d[0];
    cmaptype = d[1];
    type = d[2];
    w = d[12] | (d[13] << 8);
    h = d[14] | (d[15] << 8);
    bits = d[16];
    desc = d[17];
    if (cmaptype != 0) return 0;
    if (type != 2 && type != 3 && type != 10 && type != 11) return 0;
    if (bits != 8 && bits != 24 && bits != 32) return 0;
    if (w <= 0 || h <= 0 || w > 8192 || h > 8192) return 0;
    bpp = bits / 8;
    rle = type >= 9;
    top = (desc & 0x20) != 0;
    p = d + 18 + idlen;
    end = d + size;
    if (p > end) return 0;
    npix = w * h;
    tmp = (uint8_t *)malloc((size_t)npix * 4);
    if (!tmp) return 0;
    if (!rle) {
        if ((size_t)(end - p) < (size_t)npix * (size_t)bpp) {
            free(tmp);
            return 0;
        }
        for (int i = 0; i < npix; ++i, p += bpp) put_pixel(tmp + i * 4, p, bpp);
    } else {
        int i = 0;
        while (i < npix) {
            int hdr, count;
            if (p >= end) {
                free(tmp);
                return 0;
            }
            hdr = *p++;
            count = (hdr & 0x7f) + 1;
            if (i + count > npix) count = npix - i;
            if (hdr & 0x80) {
                if (end - p < bpp) {
                    free(tmp);
                    return 0;
                }
                for (int k = 0; k < count; ++k) put_pixel(tmp + (i + k) * 4, p, bpp);
                p += bpp;
            } else {
                if (end - p < (long)count * bpp) {
                    free(tmp);
                    return 0;
                }
                for (int k = 0; k < count; ++k, p += bpp) put_pixel(tmp + (i + k) * 4, p, bpp);
            }
            i += count;
        }
    }
    if (!top) {
        /* bottom-left origin: flip rows */
        size_t row = (size_t)w * 4;
        uint8_t *line = (uint8_t *)malloc(row);
        if (!line) {
            free(tmp);
            return 0;
        }
        for (int y = 0; y < h / 2; ++y) {
            uint8_t *a = tmp + (size_t)y * row, *b = tmp + (size_t)(h - 1 - y) * row;
            memcpy(line, a, row);
            memcpy(a, b, row);
            memcpy(b, line, row);
        }
        free(line);
    }
    out->w = w;
    out->h = h;
    out->rgba = tmp;
    return 1;
}

void *mvl_image_save_tga(const mvl_image *img, size_t *size) {
    size_t n = 18 + (size_t)img->w * (size_t)img->h * 4;
    uint8_t *o = (uint8_t *)calloc(1, n);
    if (!o) return NULL;
    o[2] = 2;
    o[12] = (uint8_t)(img->w & 0xff);
    o[13] = (uint8_t)(img->w >> 8);
    o[14] = (uint8_t)(img->h & 0xff);
    o[15] = (uint8_t)(img->h >> 8);
    o[16] = 32;
    o[17] = 0x28;
    for (int i = 0; i < img->w * img->h; ++i) {
        const uint8_t *s = img->rgba + i * 4;
        uint8_t *dp = o + 18 + i * 4;
        dp[0] = s[2];
        dp[1] = s[1];
        dp[2] = s[0];
        dp[3] = s[3];
    }
    if (size) *size = n;
    return o;
}
