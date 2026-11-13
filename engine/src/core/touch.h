/* Multiversal Van Life - virtual on-screen touch controls. MIT License.
 *
 * Layout units: y in [0,1] from top to bottom, x in [0,aspect] (both in
 * screen-height units, so circles stay round). The left half hosts a
 * floating movement stick, the right half drags to look around, and round
 * buttons trigger actions ("interact", "menu").
 */
#ifndef MVL_TOUCH_H
#define MVL_TOUCH_H

#include "core/input.h"

#define MVL_TOUCH_MAX_FINGERS 10
#define MVL_TOUCH_MAX_BUTTONS 4

typedef enum { MVL_FINGER_NONE, MVL_FINGER_STICK, MVL_FINGER_LOOK, MVL_FINGER_BUTTON } mvl_finger_role;

typedef struct {
    long long id;
    mvl_finger_role role;
    int button;
    float x, y, last_x, last_y;
} mvl_finger;

typedef struct {
    char action[32];
    char label[16];
    float x, y, r;      /* x measured from the right edge when anchored right */
    int anchor_right;
    int held;
    int tapped; /* keeps very short taps visible for one more frame */
} mvl_touch_button;

typedef struct {
    int enabled;
    float aspect;
    float k;            /* layout scale: 1 in landscape, aspect in portrait */
    mvl_finger fingers[MVL_TOUCH_MAX_FINGERS];
    mvl_touch_button buttons[MVL_TOUCH_MAX_BUTTONS];
    int button_count;
    int stick_active;
    float stick_cx, stick_cy, stick_x, stick_y; /* centre and current pos */
    float stick_radius;
    float look_scale;   /* radians per screen height */
    float look_dx, look_dy;
    float applied[2 + MVL_TOUCH_MAX_BUTTONS]; /* last values written to input */
} mvl_touch;

void mvl_touch_init(mvl_touch *t, float aspect);
void mvl_touch_set_aspect(mvl_touch *t, float aspect);
/* Normalised input: nx, ny in [0,1]. */
void mvl_touch_down(mvl_touch *t, long long id, float nx, float ny);
void mvl_touch_move(mvl_touch *t, long long id, float nx, float ny);
void mvl_touch_up(mvl_touch *t, long long id);
void mvl_touch_cancel_all(mvl_touch *t);
/* Writes stick/button state into input actions and look deltas. */
void mvl_touch_apply(mvl_touch *t, mvl_input *in);
/* Absolute position / radius of a button in layout units. */
float mvl_touch_button_x(const mvl_touch *t, int i);
float mvl_touch_button_y(const mvl_touch *t, int i);
float mvl_touch_button_r(const mvl_touch *t, int i);
/* Effective stick radius and resting centre (layout units). */
float mvl_touch_stick_radius(const mvl_touch *t);
void mvl_touch_stick_home(const mvl_touch *t, float *x, float *y);
/* Stick deflection in [-1,1] (x right, y up). */
void mvl_touch_stick(const mvl_touch *t, float *x, float *y);

#endif
