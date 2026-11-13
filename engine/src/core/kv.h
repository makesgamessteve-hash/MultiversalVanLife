/* Multiversal Van Life - INI style key/value store (config + save games).
 * MIT License.
 *
 * Format:  `key = value`, `[section]` prefixes following keys with
 * "section.", lines starting with ';' or '#' are comments.
 */
#ifndef MVL_KV_H
#define MVL_KV_H

#include <stddef.h>

#define MVL_KV_KEY_MAX 128
#define MVL_KV_VALUE_MAX 512

typedef struct {
    char key[MVL_KV_KEY_MAX];
    char value[MVL_KV_VALUE_MAX];
} mvl_kv_entry;

typedef struct {
    mvl_kv_entry *items;
    int count, cap;
} mvl_kv;

void mvl_kv_init(mvl_kv *kv);
void mvl_kv_free(mvl_kv *kv);
void mvl_kv_clear(mvl_kv *kv);
/* Parses text and merges entries into kv. Returns number of entries read. */
int mvl_kv_parse(mvl_kv *kv, const char *text);
/* Sets (or replaces) a value. Newlines in values are replaced by spaces. */
int mvl_kv_set(mvl_kv *kv, const char *key, const char *value);
int mvl_kv_remove(mvl_kv *kv, const char *key);
const char *mvl_kv_get(const mvl_kv *kv, const char *key); /* NULL if missing */
const char *mvl_kv_get_str(const mvl_kv *kv, const char *key, const char *def);
int mvl_kv_get_int(const mvl_kv *kv, const char *key, int def);
float mvl_kv_get_float(const mvl_kv *kv, const char *key, float def);
int mvl_kv_get_bool(const mvl_kv *kv, const char *key, int def);
/* Serialises as sorted `key = value` lines. Caller frees. */
char *mvl_kv_serialize(const mvl_kv *kv, size_t *len);

#endif
