/* Multiversal Van Life - INI style key/value store. MIT License. */
#include "core/kv.h"
#include "core/compat.h"
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void mvl_kv_init(mvl_kv *kv) { memset(kv, 0, sizeof *kv); }

void mvl_kv_free(mvl_kv *kv) {
    free(kv->items);
    memset(kv, 0, sizeof *kv);
}

void mvl_kv_clear(mvl_kv *kv) { kv->count = 0; }

static void trim(char *s) {
    size_t n = strlen(s), start = 0;
    while (n > 0 && isspace((unsigned char)s[n - 1])) s[--n] = 0;
    while (s[start] && isspace((unsigned char)s[start])) ++start;
    if (start) memmove(s, s + start, n - start + 1);
}

static int find(const mvl_kv *kv, const char *key) {
    for (int i = 0; i < kv->count; ++i)
        if (strcmp(kv->items[i].key, key) == 0) return i;
    return -1;
}

int mvl_kv_set(mvl_kv *kv, const char *key, const char *value) {
    int i;
    char *p;
    if (!key || !*key || strlen(key) >= MVL_KV_KEY_MAX) return 0;
    i = find(kv, key);
    if (i < 0) {
        if (kv->count == kv->cap) {
            int ncap = kv->cap ? kv->cap * 2 : 16;
            mvl_kv_entry *n = (mvl_kv_entry *)realloc(kv->items, sizeof(mvl_kv_entry) * (size_t)ncap);
            if (!n) return 0;
            kv->items = n;
            kv->cap = ncap;
        }
        i = kv->count++;
        snprintf(kv->items[i].key, MVL_KV_KEY_MAX, "%s", key);
    }
    snprintf(kv->items[i].value, MVL_KV_VALUE_MAX, "%s", value ? value : "");
    for (p = kv->items[i].value; *p; ++p)
        if (*p == '\n' || *p == '\r') *p = ' ';
    return 1;
}

int mvl_kv_remove(mvl_kv *kv, const char *key) {
    int i = find(kv, key);
    if (i < 0) return 0;
    kv->items[i] = kv->items[kv->count - 1];
    kv->count--;
    return 1;
}

int mvl_kv_parse(mvl_kv *kv, const char *text) {
    char section[MVL_KV_KEY_MAX] = "";
    const char *p = text;
    int n = 0;
    if (!text) return 0;
    while (*p) {
        char line[MVL_KV_KEY_MAX + MVL_KV_VALUE_MAX + 8];
        size_t len = 0;
        char *eq;
        while (*p && *p != '\n') {
            if (len < sizeof line - 1) line[len++] = *p;
            ++p;
        }
        if (*p) ++p;
        line[len] = 0;
        trim(line);
        if (!line[0] || line[0] == ';' || line[0] == '#') continue;
        if (line[0] == '[') {
            char *end = strchr(line, ']');
            if (end) {
                *end = 0;
                snprintf(section, sizeof section, "%s", line + 1);
                trim(section);
            }
            continue;
        }
        eq = strchr(line, '=');
        if (!eq) continue;
        *eq = 0;
        trim(line);
        trim(eq + 1);
        if (!line[0]) continue;
        {
            char key[MVL_KV_KEY_MAX * 2];
            char *val = eq + 1;
            size_t vl = strlen(val);
            if (vl >= 2 && val[0] == '"' && val[vl - 1] == '"') {
                val[vl - 1] = 0;
                ++val;
            }
            if (section[0]) snprintf(key, sizeof key, "%s.%s", section, line);
            else snprintf(key, sizeof key, "%s", line);
            if (mvl_kv_set(kv, key, val)) ++n;
        }
    }
    return n;
}

const char *mvl_kv_get(const mvl_kv *kv, const char *key) {
    int i = find(kv, key);
    return i < 0 ? NULL : kv->items[i].value;
}

const char *mvl_kv_get_str(const mvl_kv *kv, const char *key, const char *def) {
    const char *v = mvl_kv_get(kv, key);
    return v ? v : def;
}

int mvl_kv_get_int(const mvl_kv *kv, const char *key, int def) {
    const char *v = mvl_kv_get(kv, key);
    char *end;
    long r;
    if (!v || !*v) return def;
    r = strtol(v, &end, 0);
    return *end ? def : (int)r;
}

float mvl_kv_get_float(const mvl_kv *kv, const char *key, float def) {
    const char *v = mvl_kv_get(kv, key);
    char *end;
    float r;
    if (!v || !*v) return def;
    r = strtof(v, &end);
    return *end ? def : r;
}

int mvl_kv_get_bool(const mvl_kv *kv, const char *key, int def) {
    const char *v = mvl_kv_get(kv, key);
    if (!v) return def;
    if (!strcasecmp(v, "1") || !strcasecmp(v, "true") || !strcasecmp(v, "yes") || !strcasecmp(v, "on")) return 1;
    if (!strcasecmp(v, "0") || !strcasecmp(v, "false") || !strcasecmp(v, "no") || !strcasecmp(v, "off")) return 0;
    return def;
}

static int cmp_entry(const void *a, const void *b) {
    return strcmp(((const mvl_kv_entry *)a)->key, ((const mvl_kv_entry *)b)->key);
}

char *mvl_kv_serialize(const mvl_kv *kv, size_t *len) {
    size_t cap = 64, n = 0;
    char *out;
    mvl_kv_entry *sorted = NULL;
    for (int i = 0; i < kv->count; ++i) cap += strlen(kv->items[i].key) + strlen(kv->items[i].value) + 4;
    out = (char *)malloc(cap);
    if (!out) return NULL;
    if (kv->count) {
        sorted = (mvl_kv_entry *)malloc(sizeof(mvl_kv_entry) * (size_t)kv->count);
        if (!sorted) {
            free(out);
            return NULL;
        }
        memcpy(sorted, kv->items, sizeof(mvl_kv_entry) * (size_t)kv->count);
        qsort(sorted, (size_t)kv->count, sizeof(mvl_kv_entry), cmp_entry);
    }
    out[0] = 0;
    for (int i = 0; i < kv->count; ++i)
        n += (size_t)snprintf(out + n, cap - n, "%s = %s\n", sorted[i].key, sorted[i].value);
    free(sorted);
    if (len) *len = n;
    return out;
}
