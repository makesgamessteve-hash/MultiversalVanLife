/* Multiversal Van Life - software audio mixer. MIT License.
 * Mixes mono sounds into an interleaved float stereo buffer with linear
 * resampling, panning, looping, per-group volume and fades. The platform
 * layer pulls mixed audio from the main thread, so no locking is needed. */
#ifndef MVL_MIXER_H
#define MVL_MIXER_H

#include "core/assets.h"

#define MVL_MAX_VOICES 32
#define MVL_MIX_GROUPS 3 /* 0 = sfx, 1 = music/ambience, 2 = voice */

typedef struct {
    const mvl_sound *sound;
    double pos;      /* in source frames */
    double step;     /* source frames per output frame */
    float volume, target, fade_rate; /* fade_rate: volume units per second */
    float pan;       /* -1 left .. 1 right */
    int loop, group, active, stop_at_zero;
    int id;
} mvl_voice;

typedef struct {
    int rate;
    mvl_voice voices[MVL_MAX_VOICES];
    float group_volume[MVL_MIX_GROUPS];
    float master;
    int next_id;
} mvl_mixer;

void mvl_mixer_init(mvl_mixer *m, int output_rate);
/* Returns a voice id > 0, or 0 if nothing could be played. When all voices
 * are busy, the quietest non-looping voice is replaced. */
int mvl_mixer_play(mvl_mixer *m, const mvl_sound *s, float volume, float pan, int loop, int group);
int mvl_mixer_playing(const mvl_mixer *m, int id);
/* Current volume of a voice (fades included), or -1 if it is not playing. */
float mvl_mixer_volume(const mvl_mixer *m, int id);
void mvl_mixer_stop(mvl_mixer *m, int id);
void mvl_mixer_stop_group(mvl_mixer *m, int group);
void mvl_mixer_stop_all(mvl_mixer *m);
/* Fades a voice to `volume` over `seconds`; stops it if fading to 0 and
 * `stop` is set. */
void mvl_mixer_fade(mvl_mixer *m, int id, float volume, float seconds, int stop);
void mvl_mixer_set_group_volume(mvl_mixer *m, int group, float v);
int mvl_mixer_active_count(const mvl_mixer *m);
/* Mixes `frames` stereo frames into `out` (overwrites). */
void mvl_mixer_mix(mvl_mixer *m, float *out, int frames);

#endif
