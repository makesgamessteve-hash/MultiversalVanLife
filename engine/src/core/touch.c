/* Multiversal Van Life - virtual on-screen touch controls. MIT License. */
#include "core/touch.h"
#include <math.h>
#include <stdio.h>
#include <string.h>

static void add_button(mvl_touch *t, const char *action, const char *label, float x, float y, float r, int right) {
    mvl_touch_button *b = &t->buttons[t->button_count++];
    snprintf(b->action, sizeof b->action, "%s", action);
    snprintf(b->label, sizeof b->label, "%s", label);
    b->x = x;
    b->y = y;
    b->r = r;
    b->anchor_right = right;
    b->held = 0;
}

void mvl_touch_init(mvl_touch *t, float aspect) {
    memset(t, 0, sizeof *t);
    t->aspect = aspect > 0 ? aspect : 1.0f;
    t->k = t->aspect < 1.0f ? t->aspect : 1.0f;
    t->stick_radius = 0.12f;
    t->look_scale = 2.5f;
    add_button(t, "interact", "USE", 0.17f, 0.78f, 0.09f, 1);
    add_button(t, "menu", "II", 0.08f, 0.1f, 0.06f, 1);
    add_button(t, "back", "X", 0.33f, 0.86f, 0.065f, 1);
}

void mvl_touch_set_aspect(mvl_touch *t, float aspect) {
    if (aspect > 0) t->aspect = aspect;
    t->k = t->aspect < 1.0f ? t->aspect : 1.0f;
}

float mvl_touch_button_x(const mvl_touch *t, int i) {
    const mvl_touch_button *b = &t->buttons[i];
    return b->anchor_right ? t->aspect - b->x * t->k : b->x * t->k;
}

float mvl_touch_button_y(const mvl_touch *t, int i) {
    /* keep buttons anchored to the bottom (or top) edge when scaled */
    const mvl_touch_button *b = &t->buttons[i];
    return b->y > 0.5f ? 1.0f - (1.0f - b->y) * t->k : b->y * t->k;
}

float mvl_touch_button_r(const mvl_touch *t, int i) { return t->buttons[i].r * t->k; }

float mvl_touch_stick_radius(const mvl_touch *t) { return t->stick_radius * t->k; }

void mvl_touch_stick_home(const mvl_touch *t, float *x, float *y) {
    *x = 0.2f * t->k;
    *y = 1.0f - 0.25f * t->k;
}

static mvl_finger *find_finger(mvl_touch *t, long long id) {
    for (int i = 0; i < MVL_TOUCH_MAX_FINGERS; ++i)
        if (t->fingers[i].role != MVL_FINGER_NONE && t->fingers[i].id == id) return &t->fingers[i];
    return NULL;
}

void mvl_touch_down(mvl_touch *t, long long id, float nx, float ny) {
    float x = nx * t->aspect, y = ny;
    mvl_finger *f = NULL;
    t->enabled = 1;
    if (find_finger(t, id)) return;
    for (int i = 0; i < MVL_TOUCH_MAX_FINGERS; ++i)
        if (t->fingers[i].role == MVL_FINGER_NONE) {
            f = &t->fingers[i];
            break;
        }
    if (!f) return;
    f->id = id;
    f->x = f->last_x = x;
    f->y = f->last_y = y;
    for (int b = 0; b < t->button_count; ++b) {
        float dx = x - mvl_touch_button_x(t, b), dy = y - mvl_touch_button_y(t, b);
        float r = mvl_touch_button_r(t, b) * 1.25f; /* generous hit area */
        if (dx * dx + dy * dy <= r * r) {
            f->role = MVL_FINGER_BUTTON;
            f->button = b;
            t->buttons[b].held++;
            t->buttons[b].tapped = 2;
            return;
        }
    }
    if (x < t->aspect * 0.5f && !t->stick_active) {
        f->role = MVL_FINGER_STICK;
        t->stick_active = 1;
        t->stick_cx = t->stick_x = x;
        t->stick_cy = t->stick_y = y;
    } else {
        f->role = MVL_FINGER_LOOK;
    }
}

void mvl_touch_move(mvl_touch *t, long long id, float nx, float ny) {
    mvl_finger *f = find_finger(t, id);
    float x = nx * t->aspect, y = ny;
    if (!f) return;
    if (f->role == MVL_FINGER_STICK) {
        float dx = x - t->stick_cx, dy = y - t->stick_cy, d = sqrtf(dx * dx + dy * dy), sr = mvl_touch_stick_radius(t);
        if (d > sr) {
            dx *= sr / d;
            dy *= sr / d;
        }
        t->stick_x = t->stick_cx + dx;
        t->stick_y = t->stick_cy + dy;
    } else if (f->role == MVL_FINGER_LOOK) {
        t->look_dx += (x - f->last_x) * t->look_scale;
        t->look_dy += (y - f->last_y) * t->look_scale;
    }
    f->last_x = f->x = x;
    f->last_y = f->y = y;
}

void mvl_touch_up(mvl_touch *t, long long id) {
    mvl_finger *f = find_finger(t, id);
    if (!f) return;
    if (f->role == MVL_FINGER_STICK) t->stick_active = 0;
    if (f->role == MVL_FINGER_BUTTON && t->buttons[f->button].held > 0) t->buttons[f->button].held--;
    f->role = MVL_FINGER_NONE;
}

void mvl_touch_cancel_all(mvl_touch *t) {
    for (int i = 0; i < MVL_TOUCH_MAX_FINGERS; ++i) t->fingers[i].role = MVL_FINGER_NONE;
    for (int b = 0; b < t->button_count; ++b) t->buttons[b].held = t->buttons[b].tapped = 0;
    t->stick_active = 0;
    t->look_dx = t->look_dy = 0.0f;
}

void mvl_touch_stick(const mvl_touch *t, float *x, float *y) {
    if (!t->stick_active) {
        *x = *y = 0.0f;
        return;
    }
    *x = (t->stick_x - t->stick_cx) / mvl_touch_stick_radius(t);
    *y = -(t->stick_y - t->stick_cy) / mvl_touch_stick_radius(t);
}

void mvl_touch_apply(mvl_touch *t, mvl_input *in) {
    float sx, sy;
    if (!t->enabled) return;
    mvl_touch_stick(t, &sx, &sy);
    /* only write values that changed so other external sources (tests, XR)
       are not overridden while no finger is down */
    if (sx != t->applied[0]) mvl_input_set_external(in, "move_x", t->applied[0] = sx);
    if (sy != t->applied[1]) mvl_input_set_external(in, "move_y", t->applied[1] = sy);
    for (int b = 0; b < t->button_count; ++b) {
        float v = (t->buttons[b].held > 0 || t->buttons[b].tapped > 0) ? 1.0f : 0.0f;
        if (t->buttons[b].tapped > 0) t->buttons[b].tapped--;
        if (v != t->applied[2 + b]) mvl_input_set_external(in, t->buttons[b].action, t->applied[2 + b] = v);
    }
    mvl_input_add_look(in, t->look_dx, t->look_dy);
    t->look_dx = t->look_dy = 0.0f;
}
