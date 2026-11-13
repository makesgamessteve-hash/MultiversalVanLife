/* Multiversal Van Life - software audio mixer. MIT License. */
#include "core/mixer.h"
#include <string.h>

void mvl_mixer_init(mvl_mixer *m, int rate) {
    memset(m, 0, sizeof *m);
    m->rate = rate > 0 ? rate : 44100;
    for (int g = 0; g < MVL_MIX_GROUPS; ++g) m->group_volume[g] = 1.0f;
    m->master = 1.0f;
    m->next_id = 1;
}

static mvl_voice *find(mvl_mixer *m, int id) {
    if (id <= 0) return NULL;
    for (int i = 0; i < MVL_MAX_VOICES; ++i)
        if (m->voices[i].active && m->voices[i].id == id) return &m->voices[i];
    return NULL;
}

int mvl_mixer_play(mvl_mixer *m, const mvl_sound *s, float volume, float pan, int loop, int group) {
    mvl_voice *v = NULL;
    if (!s || !s->samples || s->frames <= 0) return 0;
    for (int i = 0; i < MVL_MAX_VOICES && !v; ++i)
        if (!m->voices[i].active) v = &m->voices[i];
    if (!v) {
        for (int i = 0; i < MVL_MAX_VOICES; ++i)
            if (!m->voices[i].loop && (!v || m->voices[i].volume < v->volume)) v = &m->voices[i];
        if (!v) return 0;
    }
    memset(v, 0, sizeof *v);
    v->sound = s;
    v->step = (double)s->rate / (double)m->rate;
    v->volume = v->target = volume;
    v->pan = pan < -1 ? -1 : (pan > 1 ? 1 : pan);
    v->loop = loop;
    v->group = (group >= 0 && group < MVL_MIX_GROUPS) ? group : 0;
    v->active = 1;
    v->id = m->next_id++;
    return v->id;
}

int mvl_mixer_playing(const mvl_mixer *m, int id) { return find((mvl_mixer *)m, id) != NULL; }

float mvl_mixer_volume(const mvl_mixer *m, int id) {
    const mvl_voice *v = find((mvl_mixer *)m, id);
    return v ? v->volume : -1.0f;
}

void mvl_mixer_stop(mvl_mixer *m, int id) {
    mvl_voice *v = find(m, id);
    if (v) v->active = 0;
}

void mvl_mixer_stop_group(mvl_mixer *m, int group) {
    for (int i = 0; i < MVL_MAX_VOICES; ++i)
        if (m->voices[i].group == group) m->voices[i].active = 0;
}

void mvl_mixer_stop_all(mvl_mixer *m) {
    for (int i = 0; i < MVL_MAX_VOICES; ++i) m->voices[i].active = 0;
}

void mvl_mixer_fade(mvl_mixer *m, int id, float volume, float seconds, int stop) {
    mvl_voice *v = find(m, id);
    if (!v) return;
    v->target = volume;
    v->stop_at_zero = stop;
    /* nothing to fade (also a voice that is still silent when replaced) */
    if (seconds <= 0.0f || v->volume == volume) {
        v->volume = volume;
        v->fade_rate = 0.0f;
        if (stop && volume <= 0.0f) v->active = 0;
        return;
    }
    v->fade_rate = (volume > v->volume ? volume - v->volume : v->volume - volume) / seconds;
}

void mvl_mixer_set_group_volume(mvl_mixer *m, int group, float vol) {
    if (group >= 0 && group < MVL_MIX_GROUPS) m->group_volume[group] = vol;
}

int mvl_mixer_active_count(const mvl_mixer *m) {
    int n = 0;
    for (int i = 0; i < MVL_MAX_VOICES; ++i) n += m->voices[i].active;
    return n;
}

void mvl_mixer_mix(mvl_mixer *m, float *out, int frames) {
    float fade_step_scale = 1.0f / (float)m->rate;
    memset(out, 0, sizeof(float) * 2 * (size_t)frames);
    for (int i = 0; i < MVL_MAX_VOICES; ++i) {
        mvl_voice *v = &m->voices[i];
        const int16_t *src;
        int n;
        float gl, gr;
        if (!v->active) continue;
        src = v->sound->samples;
        n = v->sound->frames;
        gl = 1.0f - (v->pan > 0 ? v->pan : 0.0f);
        gr = 1.0f + (v->pan < 0 ? v->pan : 0.0f);
        for (int f = 0; f < frames; ++f) {
            int i0 = (int)v->pos, i1 = i0 + 1;
            float t = (float)(v->pos - (double)i0), s, g;
            if (i1 >= n) i1 = v->loop ? 0 : n - 1;
            s = ((float)src[i0] * (1.0f - t) + (float)src[i1] * t) * (1.0f / 32768.0f);
            if (v->fade_rate > 0.0f) {
                float d = v->fade_rate * fade_step_scale;
                if (v->volume < v->target) v->volume = v->volume + d > v->target ? v->target : v->volume + d;
                else v->volume = v->volume - d < v->target ? v->target : v->volume - d;
                if (v->volume == v->target) {
                    v->fade_rate = 0.0f;
                    if (v->stop_at_zero && v->target <= 0.0f) {
                        v->active = 0;
                        break;
                    }
                }
            }
            g = v->volume * m->group_volume[v->group] * m->master;
            out[f * 2] += s * g * gl;
            out[f * 2 + 1] += s * g * gr;
            v->pos += v->step;
            if (v->pos >= (double)n) {
                if (v->loop) v->pos -= (double)n;
                else {
                    v->active = 0;
                    break;
                }
            }
        }
    }
    for (int f = 0; f < frames * 2; ++f) {
        if (out[f] > 1.0f) out[f] = 1.0f;
        if (out[f] < -1.0f) out[f] = -1.0f;
    }
}
