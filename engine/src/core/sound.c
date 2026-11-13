/* Multiversal Van Life - WAV and MP3 decoding. MIT License. */
#include "core/assets.h"
#include "dr_mp3.h"
#include <stdlib.h>
#include <string.h>

static uint32_t rd32(const uint8_t *p) { return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24); }
static uint16_t rd16(const uint8_t *p) { return (uint16_t)(p[0] | (p[1] << 8)); }

int mvl_sound_load_wav(const void *data, size_t size, mvl_sound *out) {
    const uint8_t *d = (const uint8_t *)data, *p, *end;
    int channels = 0, rate = 0, bits = 0, fmt_ok = 0;
    const uint8_t *pcm = NULL;
    uint32_t pcm_len = 0;
    memset(out, 0, sizeof *out);
    if (!d || size < 12 || memcmp(d, "RIFF", 4) || memcmp(d + 8, "WAVE", 4)) return 0;
    p = d + 12;
    end = d + size;
    while (end - p >= 8) {
        uint32_t len = rd32(p + 4);
        const uint8_t *body = p + 8;
        if ((uint64_t)len > (uint64_t)(end - body)) len = (uint32_t)(end - body);
        if (!memcmp(p, "fmt ", 4) && len >= 16) {
            int format = rd16(body);
            channels = rd16(body + 2);
            rate = (int)rd32(body + 4);
            bits = rd16(body + 14);
            fmt_ok = (format == 1 || format == 0xFFFE);
        } else if (!memcmp(p, "data", 4)) {
            pcm = body;
            pcm_len = len;
        }
        p = body + len + (len & 1);
    }
    if (!fmt_ok || !pcm || channels < 1 || channels > 2 || (bits != 8 && bits != 16) || rate <= 0) return 0;
    {
        int bytes = bits / 8;
        int frames = (int)(pcm_len / (uint32_t)(bytes * channels));
        int16_t *s = (int16_t *)malloc(sizeof(int16_t) * (size_t)(frames > 0 ? frames : 1));
        if (!s) return 0;
        for (int i = 0; i < frames; ++i) {
            int acc = 0;
            for (int c = 0; c < channels; ++c) {
                const uint8_t *q = pcm + ((size_t)i * channels + c) * bytes;
                acc += bits == 8 ? ((int)q[0] - 128) << 8 : (int16_t)rd16(q);
            }
            s[i] = (int16_t)(acc / channels);
        }
        out->rate = rate;
        out->frames = frames;
        out->samples = s;
    }
    return 1;
}

int mvl_sound_load_mp3(const void *data, size_t size, mvl_sound *out) {
    drmp3_config cfg;
    drmp3_uint64 frames = 0;
    drmp3_int16 *pcm;
    int16_t *mono;
    memset(out, 0, sizeof *out);
    if (!data || size == 0) return 0;
    pcm = drmp3_open_memory_and_read_pcm_frames_s16(data, size, &cfg, &frames, NULL);
    if (!pcm || frames == 0 || cfg.channels < 1 || frames > 0x7fffffff) {
        drmp3_free(pcm, NULL);
        return 0;
    }
    mono = (int16_t *)malloc(sizeof(int16_t) * (size_t)frames);
    if (!mono) {
        drmp3_free(pcm, NULL);
        return 0;
    }
    for (drmp3_uint64 i = 0; i < frames; ++i) {
        int acc = 0;
        for (drmp3_uint32 c = 0; c < cfg.channels; ++c) acc += pcm[i * cfg.channels + c];
        mono[i] = (int16_t)(acc / (int)cfg.channels);
    }
    drmp3_free(pcm, NULL);
    out->samples = mono;
    out->frames = (int)frames;
    out->rate = (int)cfg.sampleRate;
    return 1;
}

int mvl_sound_from_pcm16(const int16_t *pcm, int frames, int rate, mvl_sound *out) {
    memset(out, 0, sizeof *out);
    if (frames <= 0 || rate <= 0) return 0;
    out->samples = (int16_t *)malloc(sizeof(int16_t) * (size_t)frames);
    if (!out->samples) return 0;
    memcpy(out->samples, pcm, sizeof(int16_t) * (size_t)frames);
    out->frames = frames;
    out->rate = rate;
    return 1;
}

void mvl_sound_free(mvl_sound *s) {
    free(s->samples);
    memset(s, 0, sizeof *s);
}
