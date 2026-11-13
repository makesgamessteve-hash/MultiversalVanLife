/* Unit tests: mixer and UI. MIT License. */
#include "test.h"
#include "core/mixer.h"
#include "core/ui.h"

void test_mixer(void) {
    static mvl_mixer m;
    short pcm[8] = {16384, 16384, 16384, 16384, 16384, 16384, 16384, 16384};
    mvl_sound s;
    float out[64];
    int a, b;
    mvl_sound_from_pcm16(pcm, 8, 8, &s);
    mvl_mixer_init(&m, 0);
    CHECK_EQ_INT(m.rate, 44100);
    mvl_mixer_init(&m, 8);
    CHECK_EQ_INT(mvl_mixer_play(&m, NULL, 1, 0, 0, 0), 0);
    a = mvl_mixer_play(&m, &s, 1, -1, 0, 0);
    CHECK(a > 0 && mvl_mixer_playing(&m, a));
    mvl_mixer_mix(&m, out, 4);
    CHECK_NEAR(out[0], 0.5f, 1e-3); /* left */
    CHECK_NEAR(out[1], 0.0f, 1e-3); /* hard left pan */
    mvl_mixer_mix(&m, out, 8);    /* runs past the end and stops */
    CHECK(!mvl_mixer_playing(&m, a));
    b = mvl_mixer_play(&m, &s, 4, 5, 1, 9); /* clamps pan and group, loops, output clipped */
    mvl_mixer_mix(&m, out, 20);
    CHECK(mvl_mixer_playing(&m, b));
    CHECK_NEAR(out[38], 0.0f, 1e-3);
    CHECK_NEAR(out[39], 1.0f, 1e-3);
    mvl_mixer_set_group_volume(&m, 0, 0.5f);
    mvl_mixer_set_group_volume(&m, 7, 0.5f);
    mvl_mixer_fade(&m, b, 0, 1.0f, 1); /* 8 frames per second -> fades over 8 frames */
    mvl_mixer_mix(&m, out, 16);
    CHECK(!mvl_mixer_playing(&m, b));
    b = mvl_mixer_play(&m, &s, 0, 0, 1, 1);
    mvl_mixer_fade(&m, b, 1, 0.5f, 0); /* fade in */
    mvl_mixer_mix(&m, out, 8);
    CHECK_NEAR(m.voices[0].volume, 1, 1e-4);
    mvl_mixer_fade(&m, b, 0.5f, 0, 0);
    CHECK_NEAR(m.voices[0].volume, 0.5f, 1e-4);
    mvl_mixer_fade(&m, b, 0, 0, 1); /* instant stop */
    CHECK(!mvl_mixer_playing(&m, b));
    mvl_mixer_fade(&m, 12345, 0, 0, 1);
    mvl_mixer_stop(&m, 12345);
    CHECK(!mvl_mixer_playing(&m, 0));
    for (int i = 0; i < MVL_MAX_VOICES; ++i) mvl_mixer_play(&m, &s, (float)i / 100.0f, 0, 0, 2);
    CHECK_EQ_INT(mvl_mixer_active_count(&m), MVL_MAX_VOICES);
    a = mvl_mixer_play(&m, &s, 1, 0, 0, 0); /* steals the quietest */
    CHECK(a > 0);
    mvl_mixer_stop_group(&m, 2);
    CHECK_EQ_INT(mvl_mixer_active_count(&m), 1);
    mvl_mixer_stop(&m, a);
    CHECK_EQ_INT(mvl_mixer_active_count(&m), 0);
    for (int i = 0; i < MVL_MAX_VOICES; ++i) mvl_mixer_play(&m, &s, 1, 0, 1, 1);
    CHECK_EQ_INT(mvl_mixer_play(&m, &s, 1, 0, 0, 0), 0); /* all looping: nothing to steal */
    mvl_mixer_stop_all(&m);
    CHECK_EQ_INT(mvl_mixer_active_count(&m), 0);
    mvl_sound_free(&s);
}

void test_ui(void) {
    static mvl_ui ui;
    const float red[4] = {1, 0, 0, 1};
    char buf[256];
    mvl_ui_init(&ui);
    ui.font_texture = 7;
    mvl_ui_begin(&ui, 320, 240);
    mvl_ui_rect(&ui, 0, 0, 10, 10, red);
    mvl_ui_image(&ui, 3, 0, 0, 1, 1, 0, 0, 1, 1, NULL);
    CHECK_EQ_INT(ui.count, 2);
    CHECK_NEAR(ui.quads[1].color[3], 1, 1e-6);
    CHECK_NEAR(mvl_ui_text(&ui, 0, 0, "ab c\nxyz12\x01", 1, red), 6 * 6, 1e-6);
    CHECK_EQ_INT(ui.count, 2 + 9);
    CHECK_EQ_INT(ui.quads[2].texture, 7);
    CHECK_NEAR(mvl_ui_text(&ui, 0, 0, NULL, 1, red), 0, 1e-6);
    CHECK_NEAR(mvl_ui_text_width("hello", 2), 60, 1e-6);
    CHECK_NEAR(mvl_ui_text_width("ab\nabcd\nx", 1), 24, 1e-6);
    CHECK_NEAR(mvl_ui_text_width(NULL, 1), 0, 1e-6);
    CHECK_EQ_INT(mvl_ui_text_lines("a\nb\nc"), 3);
    CHECK_EQ_INT(mvl_ui_text_lines(""), 0);
    CHECK_EQ_INT(mvl_ui_text_lines(NULL), 0);
    mvl_ui_wrap("the quick brown fox", 6 * 10, 1, buf, sizeof buf);
    CHECK_STR(buf, "the quick\nbrown fox");
    mvl_ui_wrap("abcdefghijkl", 6 * 5, 1, buf, sizeof buf); /* long word is split */
    CHECK_STR(buf, "abcde\nfghij\nkl");
    mvl_ui_wrap("a\nb  c", 600, 1, buf, sizeof buf);
    CHECK_STR(buf, "a\nb c");
    mvl_ui_wrap("x", 1, 1, buf, sizeof buf);
    CHECK_STR(buf, "x");
    mvl_ui_wrap("hello world", 600, 1, buf, 4);
    CHECK_EQ_INT(strlen(buf), 3);
    mvl_ui_wrap("abcdefghij", 6 * 2, 1, buf, 6);
    CHECK(strlen(buf) <= 5);
    mvl_ui_wrap("abc", 600, 1, buf, 0);
    for (int i = 0; i < MVL_UI_MAX_QUADS + 5; ++i) mvl_ui_rect(&ui, 0, 0, 1, 1, red);
    CHECK_EQ_INT(ui.count, MVL_UI_MAX_QUADS);
}
