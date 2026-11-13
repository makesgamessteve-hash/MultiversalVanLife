/* Multiversal Van Life - action based input mapping. MIT License. */
#include "core/input.h"
#include "core/compat.h"
#include "core/kv.h"
#include "core/log.h"
#include <math.h>
#include <stdio.h>
#include <string.h>

void mvl_input_init(mvl_input *in) {
    memset(in, 0, sizeof *in);
    in->mouse_sensitivity = 0.0025f;
    in->deadzone = 0.2f;
}

int mvl_input_find(const mvl_input *in, const char *name) {
    for (int i = 0; i < in->action_count; ++i)
        if (!strcmp(in->actions[i].name, name)) return i;
    return -1;
}

int mvl_input_add_action(mvl_input *in, const char *name) {
    int i = mvl_input_find(in, name);
    if (i >= 0) return i;
    if (in->action_count >= MVL_MAX_ACTIONS || strlen(name) >= sizeof in->actions[0].name) return -1;
    i = in->action_count++;
    memset(&in->actions[i], 0, sizeof in->actions[i]);
    snprintf(in->actions[i].name, sizeof in->actions[i].name, "%s", name);
    return i;
}

int mvl_input_bind(mvl_input *in, const char *action, int source, float scale) {
    int i = mvl_input_add_action(in, action);
    mvl_action *a;
    if (i < 0 || source < 0 || source >= 4096) return 0;
    a = &in->actions[i];
    if (a->binding_count >= MVL_MAX_BINDINGS) return 0;
    a->bindings[a->binding_count].source = source;
    a->bindings[a->binding_count].scale = scale;
    a->binding_count++;
    return 1;
}

int mvl_input_load_bindings(mvl_input *in, const char *text, mvl_key_resolver resolve, void *user) {
    mvl_kv kv;
    int added = 0;
    mvl_kv_init(&kv);
    mvl_kv_parse(&kv, text);
    for (int i = 0; i < kv.count; ++i) {
        const char *action = kv.items[i].key;
        char buf[MVL_KV_VALUE_MAX];
        char *tok, *save = NULL;
        const char *dot = strrchr(action, '.');
        if (dot) action = dot + 1; /* allow [bindings] sections */
        snprintf(buf, sizeof buf, "%s", kv.items[i].value);
        mvl_input_add_action(in, action);
        for (tok = strtok_r(buf, ",", &save); tok; tok = strtok_r(NULL, ",", &save)) {
            float scale = 1.0f;
            int src;
            while (*tok == ' ' || *tok == '\t') ++tok;
            {
                size_t n = strlen(tok);
                while (n > 0 && (tok[n - 1] == ' ' || tok[n - 1] == '\t')) tok[--n] = 0;
            }
            if (*tok == '-' && tok[1]) {
                scale = -1.0f;
                ++tok;
            } else if (*tok == '+' && tok[1]) {
                ++tok;
            }
            if (!*tok) continue;
            src = resolve ? resolve(tok, user) : -1;
            if (src < 0) {
                MVL_WARN("unknown input binding '%s' for action '%s'", tok, action);
                continue;
            }
            added += mvl_input_bind(in, action, src, scale);
        }
    }
    mvl_kv_free(&kv);
    return added;
}

void mvl_input_set_source(mvl_input *in, int source, float value) {
    if (source >= 0 && source < 4096) in->source_values[source] = value;
}

void mvl_input_set_external(mvl_input *in, const char *action, float value) {
    int i = mvl_input_add_action(in, action);
    if (i >= 0) in->actions[i].external = value;
}

void mvl_input_add_look(mvl_input *in, float dx, float dy) {
    in->look_dx += dx;
    in->look_dy += dy;
}

void mvl_input_reset(mvl_input *in) {
    memset(in->source_values, 0, sizeof in->source_values);
    for (int i = 0; i < in->action_count; ++i) {
        in->actions[i].external = 0.0f;
        in->actions[i].value = 0.0f;
        in->actions[i].down = 0;
    }
    in->look_dx = in->look_dy = 0.0f;
}

void mvl_input_update(mvl_input *in) {
    for (int i = 0; i < in->action_count; ++i) {
        mvl_action *a = &in->actions[i];
        float v = 0.0f;
        for (int b = 0; b < a->binding_count; ++b) {
            float sv = in->source_values[a->bindings[b].source];
            if (a->bindings[b].source >= 3000 && sv < in->deadzone) sv = 0.0f; /* analog deadzone */
            v += sv * a->bindings[b].scale;
        }
        v += a->external;
        if (v > 1.0f) v = 1.0f;
        if (v < -1.0f) v = -1.0f;
        a->value = v;
        a->down = fabsf(v) > 0.5f;
    }
}

void mvl_input_end_frame(mvl_input *in) {
    for (int i = 0; i < in->action_count; ++i) in->actions[i].prev_down = in->actions[i].down;
    in->look_dx = in->look_dy = 0.0f;
}

float mvl_input_value(const mvl_input *in, const char *action) {
    int i = mvl_input_find(in, action);
    return i < 0 ? 0.0f : in->actions[i].value;
}

int mvl_input_down(const mvl_input *in, const char *action) {
    int i = mvl_input_find(in, action);
    return i < 0 ? 0 : in->actions[i].down;
}

int mvl_input_pressed(const mvl_input *in, const char *action) {
    int i = mvl_input_find(in, action);
    return i < 0 ? 0 : (in->actions[i].down && !in->actions[i].prev_down);
}

int mvl_input_released(const mvl_input *in, const char *action) {
    int i = mvl_input_find(in, action);
    return i < 0 ? 0 : (!in->actions[i].down && in->actions[i].prev_down);
}
