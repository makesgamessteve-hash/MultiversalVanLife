/* Unit tests: TGA, WAV, OBJ, VOX decoders and mesh builders. MIT License. */
#include "test.h"
#include "core/assets.h"
#include <stdlib.h>

static size_t make_tga(unsigned char *buf, int type, int bits, int w, int h, int desc) {
    memset(buf, 0, 18);
    buf[2] = (unsigned char)type;
    buf[12] = (unsigned char)w;
    buf[14] = (unsigned char)h;
    buf[16] = (unsigned char)bits;
    buf[17] = (unsigned char)desc;
    return 18;
}

void test_tga_uncompressed(void) {
    unsigned char buf[256];
    mvl_image img;
    size_t n = make_tga(buf, 2, 32, 2, 2, 0x28);
    /* top-left origin BGRA */
    const unsigned char px[16] = {255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 1, 2, 3, 4};
    memcpy(buf + n, px, 16);
    CHECK(mvl_image_load_tga(buf, n + 16, &img));
    CHECK_EQ_INT(img.w, 2);
    CHECK_EQ_INT(img.rgba[2], 255); /* first pixel blue */
    CHECK_EQ_INT(img.rgba[12], 3);
    CHECK_EQ_INT(img.rgba[15], 4);
    {
        size_t sz;
        unsigned char *enc = (unsigned char *)mvl_image_save_tga(&img, &sz);
        mvl_image back;
        CHECK(enc && sz == 18 + 16);
        CHECK(mvl_image_load_tga(enc, sz, &back));
        CHECK(!memcmp(back.rgba, img.rgba, 16));
        mvl_image_free(&back);
        free(enc);
    }
    mvl_image_free(&img);
    /* bottom-left origin 24 bit: rows are flipped */
    n = make_tga(buf, 2, 24, 1, 2, 0);
    buf[n] = 10; buf[n + 1] = 20; buf[n + 2] = 30;     /* bottom row */
    buf[n + 3] = 40; buf[n + 4] = 50; buf[n + 5] = 60; /* top row */
    CHECK(mvl_image_load_tga(buf, n + 6, &img));
    CHECK_EQ_INT(img.rgba[0], 60);
    CHECK_EQ_INT(img.rgba[3], 255);
    CHECK_EQ_INT(img.rgba[6], 10);
    mvl_image_free(&img);
    /* grayscale */
    n = make_tga(buf, 3, 8, 1, 1, 0x20);
    buf[n] = 77;
    CHECK(mvl_image_load_tga(buf, n + 1, &img));
    CHECK_EQ_INT(img.rgba[1], 77);
    mvl_image_free(&img);
}

void test_tga_rle_and_errors(void) {
    unsigned char buf[256];
    mvl_image img;
    size_t n = make_tga(buf, 10, 24, 4, 1, 0x20);
    /* run of 3 red pixels, then 1 raw green pixel */
    buf[n++] = 0x82; buf[n++] = 0; buf[n++] = 0; buf[n++] = 255;
    buf[n++] = 0x00; buf[n++] = 0; buf[n++] = 255; buf[n++] = 0;
    CHECK(mvl_image_load_tga(buf, n, &img));
    CHECK_EQ_INT(img.rgba[8], 255);
    CHECK_EQ_INT(img.rgba[13], 255);
    mvl_image_free(&img);
    /* truncated RLE stream */
    CHECK(!mvl_image_load_tga(buf, n - 5, &img));
    n = make_tga(buf, 10, 24, 4, 1, 0x20);
    buf[n++] = 0x83; buf[n++] = 1;
    CHECK(!mvl_image_load_tga(buf, n, &img));
    n = make_tga(buf, 10, 24, 4, 1, 0x20);
    buf[n++] = 0x03; buf[n++] = 1;
    CHECK(!mvl_image_load_tga(buf, n, &img));
    /* a run longer than the image is clamped */
    n = make_tga(buf, 10, 24, 1, 1, 0x20);
    buf[n++] = 0x85; buf[n++] = 1; buf[n++] = 2; buf[n++] = 3;
    CHECK(mvl_image_load_tga(buf, n, &img));
    mvl_image_free(&img);
    /* invalid headers */
    CHECK(!mvl_image_load_tga(NULL, 0, &img));
    CHECK(!mvl_image_load_tga(buf, 10, &img));
    make_tga(buf, 1, 8, 1, 1, 0);
    CHECK(!mvl_image_load_tga(buf, 64, &img));
    make_tga(buf, 2, 16, 1, 1, 0);
    CHECK(!mvl_image_load_tga(buf, 64, &img));
    make_tga(buf, 2, 32, 0, 1, 0);
    CHECK(!mvl_image_load_tga(buf, 64, &img));
    make_tga(buf, 2, 32, 1, 1, 0);
    buf[1] = 1; /* colour map */
    CHECK(!mvl_image_load_tga(buf, 64, &img));
    make_tga(buf, 2, 32, 8, 8, 0);
    CHECK(!mvl_image_load_tga(buf, 30, &img)); /* truncated data */
    make_tga(buf, 2, 32, 1, 1, 0);
    buf[0] = 200; /* id length beyond buffer */
    CHECK(!mvl_image_load_tga(buf, 20, &img));
    CHECK(!mvl_image_alloc(&img, 0, 0));
}

static size_t make_wav(unsigned char *b, int channels, int bits, int rate, const void *pcm, unsigned len, int odd_chunk) {
    size_t n = 0;
    unsigned fmt_len = 16;
    memcpy(b, "RIFF\0\0\0\0WAVE", 12);
    n = 12;
    if (odd_chunk) { /* unknown odd sized chunk is skipped with padding */
        memcpy(b + n, "junk\3\0\0\0abc\0", 12);
        n += 12;
    }
    memcpy(b + n, "fmt ", 4);
    b[n + 4] = (unsigned char)fmt_len; b[n + 5] = b[n + 6] = b[n + 7] = 0;
    n += 8;
    b[n] = 1; b[n + 1] = 0;
    b[n + 2] = (unsigned char)channels; b[n + 3] = 0;
    b[n + 4] = (unsigned char)(rate & 0xff); b[n + 5] = (unsigned char)(rate >> 8); b[n + 6] = (unsigned char)(rate >> 16); b[n + 7] = 0;
    memset(b + n + 8, 0, 6);
    b[n + 14] = (unsigned char)bits; b[n + 15] = 0;
    n += 16;
    memcpy(b + n, "data", 4);
    b[n + 4] = (unsigned char)len; b[n + 5] = b[n + 6] = b[n + 7] = 0;
    n += 8;
    memcpy(b + n, pcm, len);
    return n + len;
}

void test_wav(void) {
    unsigned char b[256];
    mvl_sound s;
    short pcm16[4] = {1000, 3000, -2000, -4000};
    unsigned char pcm8[2] = {128, 255};
    size_t n = make_wav(b, 2, 16, 22050, pcm16, 8, 1);
    CHECK(mvl_sound_load_wav(b, n, &s));
    CHECK_EQ_INT(s.frames, 2);
    CHECK_EQ_INT(s.rate, 22050);
    CHECK_EQ_INT(s.samples[0], 2000);
    CHECK_EQ_INT(s.samples[1], -3000);
    mvl_sound_free(&s);
    n = make_wav(b, 1, 8, 8000, pcm8, 2, 0);
    CHECK(mvl_sound_load_wav(b, n, &s));
    CHECK_EQ_INT(s.samples[0], 0);
    CHECK_EQ_INT(s.samples[1], 127 << 8);
    mvl_sound_free(&s);
    /* data chunk length larger than the file is clamped */
    n = make_wav(b, 1, 16, 8000, pcm16, 8, 0);
    b[n - 8 - 4] = 200;
    CHECK(mvl_sound_load_wav(b, n, &s));
    CHECK_EQ_INT(s.frames, 4);
    mvl_sound_free(&s);
    CHECK(!mvl_sound_load_wav(b, 8, &s));
    CHECK(!mvl_sound_load_wav("RIFF0000AVI ", 12, &s));
    n = make_wav(b, 3, 16, 8000, pcm16, 8, 0);
    CHECK(!mvl_sound_load_wav(b, n, &s));
    n = make_wav(b, 1, 24, 8000, pcm16, 8, 0);
    CHECK(!mvl_sound_load_wav(b, n, &s));
    n = make_wav(b, 1, 16, 8000, pcm16, 8, 0);
    CHECK(!mvl_sound_load_wav(b, 12 + 8 + 16, &s)); /* no data chunk */
    CHECK(mvl_sound_from_pcm16(pcm16, 4, 44100, &s));
    CHECK_EQ_INT(s.samples[3], -4000);
    mvl_sound_free(&s);
    CHECK(!mvl_sound_from_pcm16(pcm16, 0, 44100, &s));
}

void test_obj(void) {
    mvl_mesh m;
    const char *obj =
        "# quad\nmtllib x.mtl\no thing\n"
        "v 0 0 0\nv 1 0 0\nv 1 1 0\nv 0 1 0\n"
        "vt 0 0\nvt 1 0\nvt 1 1\nvt 0 1\n"
        "vn 0 0 1\n"
        "f 1/1/1 2/2/1 3/3/1 4/4/1\n"
        "f -4//1 -3//1 -2//1\n"
        "f 1 2 3\n"
        "  f 1/1 2/2 3/3\n";
    CHECK(mvl_mesh_load_obj(obj, &m));
    CHECK_EQ_INT(m.count, 15);
    CHECK_NEAR(m.v[0].uv[1], 1.0, 1e-6); /* v flipped */
    CHECK_NEAR(m.v[0].normal[2], 1.0, 1e-6);
    CHECK_NEAR(m.v[9].normal[1], 1.0, 1e-6); /* default normal */
    CHECK_NEAR(m.max[0], 1.0, 1e-6);
    mvl_mesh_free(&m);
    CHECK(!mvl_mesh_load_obj("v 0 0 0\nf 1 2 3\n", &m));       /* bad index */
    CHECK(!mvl_mesh_load_obj("v 0 0 0\nf 1/5 1/5 1/5\n", &m)); /* bad uv index */
    CHECK(!mvl_mesh_load_obj("v 0 0 0\nf 1//7 1//7 1//7\n", &m));
    CHECK(!mvl_mesh_load_obj("v 0 0 0\nf 0 0 0\n", &m));
    CHECK(!mvl_mesh_load_obj("# nothing\n", &m));
    CHECK(!mvl_mesh_load_obj(NULL, &m));
    CHECK(mvl_mesh_load_obj("v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 x 2 3\n", &m)); /* junk token skipped */
    CHECK_EQ_INT(m.count, 3);
    mvl_mesh_free(&m);
    CHECK(!mvl_mesh_load_obj("v 0 0 0\nf -9 1 1\n", &m));
}

void test_mesh_builders(void) {
    mvl_mesh m;
    mvl_mesh_init(&m);
    mvl_mesh_build_plane(&m, 4, 2, 2, 1);
    CHECK_EQ_INT(m.count, 6);
    CHECK_NEAR(m.min[0], -2, 1e-6);
    CHECK_NEAR(m.max[2], 1, 1e-6);
    mvl_mesh_free(&m);
    mvl_mesh_build_box(&m, 2, 3, 2);
    CHECK_EQ_INT(m.count, 36);
    CHECK_NEAR(m.max[1], 3, 1e-6);
    CHECK_NEAR(m.min[1], 0, 1e-6);
    mvl_mesh_free(&m);
    mvl_mesh_compute_bounds(&m);
    CHECK_NEAR(m.max[0], 0, 1e-6);
}

static size_t chunk(unsigned char *b, const char *id, unsigned clen, unsigned children) {
    memcpy(b, id, 4);
    for (int i = 0; i < 4; ++i) {
        b[4 + i] = (unsigned char)(clen >> (8 * i));
        b[8 + i] = (unsigned char)(children >> (8 * i));
    }
    return 12;
}

static void put32(unsigned char *b, unsigned v) {
    for (int i = 0; i < 4; ++i) b[i] = (unsigned char)(v >> (8 * i));
}

static size_t make_vox(unsigned char *b, int with_palette, int sx, int sy, int sz) {
    size_t n = 0;
    memcpy(b, "VOX ", 4);
    put32(b + 4, 150);
    n = 8;
    n += chunk(b + n, "MAIN", 0, 0);
    n += chunk(b + n, "SIZE", 12, 0);
    put32(b + n, (unsigned)sx); put32(b + n + 4, (unsigned)sy); put32(b + n + 8, (unsigned)sz);
    n += 12;
    n += chunk(b + n, "XYZI", 4 + 3 * 4, 0);
    put32(b + n, 3);
    n += 4;
    b[n++] = 0; b[n++] = 0; b[n++] = 0; b[n++] = 1;
    b[n++] = 1; b[n++] = 0; b[n++] = 0; b[n++] = 2;
    b[n++] = 9; b[n++] = 9; b[n++] = 9; b[n++] = 3; /* out of bounds: ignored */
    if (with_palette) {
        n += chunk(b + n, "RGBA", 1024, 0);
        for (int i = 0; i < 256; ++i) {
            b[n++] = (unsigned char)i; b[n++] = 10; b[n++] = 20; b[n++] = 255;
        }
    }
    return n;
}

void test_vox(void) {
    static unsigned char b[4096];
    mvl_voxels v;
    mvl_mesh m;
    size_t n = make_vox(b, 1, 2, 1, 1);
    CHECK(mvl_voxels_load_vox(b, n, &v));
    CHECK_EQ_INT(v.sx, 2);
    CHECK_EQ_INT(mvl_voxels_get(&v, 0, 0, 0), 1);
    CHECK_EQ_INT(mvl_voxels_get(&v, 5, 0, 0), 0);
    CHECK_EQ_INT(mvl_voxels_get(&v, -1, 0, 0), 0);
    CHECK_EQ_INT(v.palette[1] & 0xff, 0);
    CHECK(mvl_voxels_mesh(&v, 0.5f, &m));
    CHECK_EQ_INT(m.count, 10 * 6); /* two touching cubes: 10 visible faces */
    CHECK_NEAR(m.min[0], -0.5, 1e-6);
    CHECK_NEAR(m.max[1], 0.5, 1e-6);
    mvl_mesh_free(&m);
    mvl_voxels_free(&v);
    CHECK(!mvl_voxels_mesh(&v, 1, &m));
    n = make_vox(b, 0, 2, 1, 1);
    CHECK(mvl_voxels_load_vox(b, n, &v)); /* default palette */
    CHECK(v.palette[1] != 0);
    mvl_voxels_free(&v);
    n = make_vox(b, 0, 0, 1, 1);
    CHECK(!mvl_voxels_load_vox(b, n, &v));
    n = make_vox(b, 0, 300, 1, 1);
    CHECK(!mvl_voxels_load_vox(b, n, &v));
    CHECK(!mvl_voxels_load_vox(b, 10, &v));
    CHECK(!mvl_voxels_load_vox("NOPE00000000000000000000", 24, &v));
    memcpy(b + 8, "MAIX", 4);
    CHECK(!mvl_voxels_load_vox(b, n, &v));
    /* SIZE without XYZI */
    n = make_vox(b, 0, 2, 1, 1);
    CHECK(!mvl_voxels_load_vox(b, 20 + 12 + 12, &v));
    /* chunk length past end of data stops parsing */
    n = make_vox(b, 0, 2, 1, 1);
    put32(b + 20 + 4, 100000);
    CHECK(!mvl_voxels_load_vox(b, n, &v));
}
