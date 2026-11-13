/* Unit tests: input mapping, touch controls. MIT License. */
#include "test.h"
#include "core/input.h"
#include "core/touch.h"

static int resolver(const char *name, void *user) {
    if (!strcmp(name, "W")) return 26;
    if (!strcmp(name, "S")) return 22;
    if (!strcmp(name, "Space")) return 44;
    if (!strcmp(name, "padx")) return MVL_SRC_PAD_AXIS_POS(0);
    return -1;
}

void test_input_bindings(void) {
    static mvl_input in;
    mvl_input_init(&in);
    CHECK_EQ_INT(mvl_input_load_bindings(&in, "[bindings]\nmove_y = W, -S, +padx , bogus, -, \ninteract = Space\nempty =\n", resolver, NULL), 4);
    CHECK(mvl_input_find(&in, "move_y") >= 0);
    CHECK(mvl_input_find(&in, "empty") >= 0);
    CHECK(mvl_input_find(&in, "nothing") < 0);
    mvl_input_set_source(&in, 26, 1);
    mvl_input_update(&in);
    CHECK_NEAR(mvl_input_value(&in, "move_y"), 1, 1e-6);
    CHECK(mvl_input_down(&in, "move_y"));
    CHECK(mvl_input_pressed(&in, "move_y"));
    mvl_input_end_frame(&in);
    mvl_input_update(&in);
    CHECK(!mvl_input_pressed(&in, "move_y"));
    mvl_input_set_source(&in, 26, 0);
    mvl_input_set_source(&in, 22, 1);
    mvl_input_update(&in);
    CHECK_NEAR(mvl_input_value(&in, "move_y"), -1, 1e-6);
    mvl_input_set_source(&in, 26, 1);
    mvl_input_set_source(&in, MVL_SRC_PAD_AXIS_POS(0), 0.1f); /* inside deadzone */
    mvl_input_update(&in);
    CHECK_NEAR(mvl_input_value(&in, "move_y"), 0, 1e-6);
    mvl_input_set_source(&in, MVL_SRC_PAD_AXIS_POS(0), 0.9f);
    mvl_input_set_external(&in, "move_y", 1);
    mvl_input_update(&in);
    CHECK_NEAR(mvl_input_value(&in, "move_y"), 1, 1e-6); /* clamped */
    mvl_input_set_external(&in, "move_y", -5);
    mvl_input_update(&in);
    CHECK_NEAR(mvl_input_value(&in, "move_y"), -1, 1e-6);
    mvl_input_end_frame(&in);
    mvl_input_reset(&in);
    mvl_input_update(&in);
    CHECK(mvl_input_released(&in, "move_y"));
    CHECK(!mvl_input_released(&in, "nothing"));
    CHECK(!mvl_input_pressed(&in, "nothing"));
    CHECK(!mvl_input_down(&in, "nothing"));
    CHECK_NEAR(mvl_input_value(&in, "nothing"), 0, 1e-6);
    mvl_input_add_look(&in, 0.5f, 0.25f);
    CHECK_NEAR(in.look_dx, 0.5f, 1e-6);
    mvl_input_end_frame(&in);
    CHECK_NEAR(in.look_dy, 0, 1e-6);
    /* invalid sources and limits */
    CHECK(!mvl_input_bind(&in, "x", 5000, 1));
    mvl_input_set_source(&in, -1, 1);
    for (int i = 0; i < MVL_MAX_BINDINGS + 1; ++i) mvl_input_bind(&in, "many", 1, 1);
    CHECK(!mvl_input_bind(&in, "many", 1, 1));
    for (int i = 0; i < MVL_MAX_ACTIONS; ++i) {
        char n[16];
        snprintf(n, sizeof n, "a%d", i);
        mvl_input_add_action(&in, n);
    }
    CHECK_EQ_INT(mvl_input_add_action(&in, "overflow"), -1);
    CHECK_EQ_INT(mvl_input_add_action(&in, "this-action-name-is-far-too-long-to-fit"), -1);
    mvl_input_load_bindings(&in, "x = W\n", NULL, NULL);
}

void test_touch_controls(void) {
    static mvl_input in;
    mvl_touch t;
    float x, y;
    mvl_input_init(&in);
    mvl_touch_init(&t, 0);
    CHECK_NEAR(t.aspect, 1, 1e-6);
    mvl_touch_set_aspect(&t, 2.0f);
    mvl_touch_set_aspect(&t, -1.0f);
    CHECK_NEAR(t.aspect, 2, 1e-6);
    mvl_touch_apply(&t, &in); /* disabled: no effect */
    CHECK(mvl_input_find(&in, "move_x") < 0);
    /* stick */
    mvl_touch_down(&t, 1, 0.1f, 0.7f);
    CHECK(t.enabled && t.stick_active);
    mvl_touch_down(&t, 1, 0.1f, 0.7f); /* duplicate id ignored */
    mvl_touch_move(&t, 1, 0.1f, 0.2f); /* far up: clamped to radius */
    mvl_touch_stick(&t, &x, &y);
    CHECK_NEAR(y, 1, 1e-4);
    CHECK_NEAR(x, 0, 1e-4);
    mvl_touch_apply(&t, &in);
    mvl_input_update(&in);
    CHECK_NEAR(mvl_input_value(&in, "move_y"), 1, 1e-4);
    mvl_touch_move(&t, 1, 0.12f, 0.7f); /* small move: not clamped */
    mvl_touch_stick(&t, &x, &y);
    CHECK(x > 0 && x < 1);
    /* second finger on the left while stick is active -> look */
    mvl_touch_down(&t, 2, 0.2f, 0.5f);
    CHECK_EQ_INT(t.fingers[1].role, MVL_FINGER_LOOK);
    mvl_touch_move(&t, 2, 0.3f, 0.6f);
    CHECK(t.look_dx > 0 && t.look_dy > 0);
    mvl_touch_apply(&t, &in);
    CHECK(in.look_dx > 0);
    CHECK_NEAR(t.look_dx, 0, 1e-6);
    mvl_touch_up(&t, 2);
    mvl_touch_up(&t, 1);
    CHECK(!t.stick_active);
    mvl_touch_stick(&t, &x, &y);
    CHECK_NEAR(x + y, 0, 1e-6);
    mvl_touch_apply(&t, &in);
    mvl_input_update(&in);
    CHECK_NEAR(mvl_input_value(&in, "move_y"), 0, 1e-6);
    /* buttons: interact sits at (aspect - 0.17, 0.78) */
    mvl_touch_down(&t, 3, (2.0f - 0.17f) / 2.0f, 0.78f);
    CHECK_EQ_INT(t.buttons[0].held, 1);
    mvl_touch_move(&t, 3, 0.9f, 0.7f); /* moving a button finger does nothing */
    mvl_touch_apply(&t, &in);
    mvl_input_update(&in);
    CHECK(mvl_input_down(&in, "interact"));
    mvl_touch_up(&t, 3);
    mvl_touch_up(&t, 99);  /* unknown finger */
    mvl_touch_move(&t, 99, 0, 0);
    mvl_touch_apply(&t, &in); /* a short tap stays visible for one more frame */
    mvl_input_update(&in);
    CHECK(mvl_input_down(&in, "interact"));
    mvl_touch_apply(&t, &in);
    mvl_input_update(&in);
    CHECK(!mvl_input_down(&in, "interact"));
    CHECK_NEAR(mvl_touch_button_x(&t, 0), 2.0f - 0.17f, 1e-5);
    t.buttons[0].anchor_right = 0;
    CHECK_NEAR(mvl_touch_button_x(&t, 0), 0.17f, 1e-5);
    /* portrait screens scale the layout down and keep it at the edges */
    mvl_touch_set_aspect(&t, 0.5f);
    CHECK_NEAR(t.k, 0.5f, 1e-6);
    CHECK_NEAR(mvl_touch_button_y(&t, 0), 1.0f - 0.22f * 0.5f, 1e-5);
    CHECK_NEAR(mvl_touch_button_y(&t, 1), 0.05f, 1e-5);
    CHECK_NEAR(mvl_touch_button_r(&t, 0), 0.045f, 1e-5);
    CHECK_NEAR(mvl_touch_stick_radius(&t), 0.06f, 1e-5);
    {
        float hx, hy;
        mvl_touch_stick_home(&t, &hx, &hy);
        CHECK_NEAR(hx, 0.1f, 1e-5);
        CHECK_NEAR(hy, 0.875f, 1e-5);
    }
    /* run out of finger slots */
    for (int i = 0; i < MVL_TOUCH_MAX_FINGERS + 2; ++i) mvl_touch_down(&t, 100 + i, 0.9f, 0.4f);
    mvl_touch_cancel_all(&t);
    CHECK_EQ_INT(t.fingers[0].role, MVL_FINGER_NONE);
}
