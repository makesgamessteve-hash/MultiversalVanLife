/* Multiversal Van Life - action based input mapping. MIT License.
 *
 * The platform layer feeds raw "source codes" (keys, mouse and gamepad
 * buttons, gamepad axes) and the core maps them to named actions that Lua
 * scripts query (e.g. "move_y", "interact"). Bindings come from
 * game/config/input.ini so they are moddable.
 */
#ifndef MVL_INPUT_H
#define MVL_INPUT_H

#define MVL_MAX_ACTIONS 32
#define MVL_MAX_BINDINGS 8

/* Source code namespaces. */
#define MVL_SRC_KEY(sc) (sc)                      /* 0..999: keyboard scancodes */
#define MVL_SRC_MOUSE(b) (1000 + (b))             /* mouse buttons */
#define MVL_SRC_PAD_BUTTON(b) (2000 + (b))        /* gamepad buttons */
#define MVL_SRC_PAD_AXIS_POS(a) (3000 + (a) * 2)  /* gamepad axis, positive half */
#define MVL_SRC_PAD_AXIS_NEG(a) (3001 + (a) * 2)  /* gamepad axis, negative half */

typedef struct {
    int source;
    float scale; /* +1 or -1: contribution to an axis action */
} mvl_binding;

typedef struct {
    char name[32];
    mvl_binding bindings[MVL_MAX_BINDINGS];
    int binding_count;
    float value;        /* current value: digital 0/1, axes -1..1 */
    float external;     /* value injected by touch controls / XR / tests */
    int down, prev_down;
} mvl_action;

/* Resolves a binding name like "W", "Space", "mouse1", "pad_a",
 * "pad_leftx+" into a source code. Returns -1 if unknown. */
typedef int (*mvl_key_resolver)(const char *name, void *user);

typedef struct {
    mvl_action actions[MVL_MAX_ACTIONS];
    int action_count;
    float source_values[4096];
    float look_dx, look_dy;     /* accumulated mouse/touch look this frame */
    float mouse_sensitivity;
    float deadzone;
    char text_entered[64];
} mvl_input;

void mvl_input_init(mvl_input *in);
int mvl_input_add_action(mvl_input *in, const char *name);
int mvl_input_find(const mvl_input *in, const char *name);
int mvl_input_bind(mvl_input *in, const char *action, int source, float scale);
/* Parses bindings from text: `action = Key, Key2, -pad_lefty` (a leading
 * '-' makes the binding contribute negatively). Returns bindings added. */
int mvl_input_load_bindings(mvl_input *in, const char *text, mvl_key_resolver resolve, void *user);

void mvl_input_set_source(mvl_input *in, int source, float value);
void mvl_input_set_external(mvl_input *in, const char *action, float value);
void mvl_input_add_look(mvl_input *in, float dx, float dy);
/* Clears all held state (e.g. on focus loss). */
void mvl_input_reset(mvl_input *in);

/* Computes action values. Call once per frame after feeding sources. */
void mvl_input_update(mvl_input *in);
/* Call at the end of a fixed update to consume edges and look deltas. */
void mvl_input_end_frame(mvl_input *in);

float mvl_input_value(const mvl_input *in, const char *action);
int mvl_input_down(const mvl_input *in, const char *action);
int mvl_input_pressed(const mvl_input *in, const char *action);
int mvl_input_released(const mvl_input *in, const char *action);

#endif
