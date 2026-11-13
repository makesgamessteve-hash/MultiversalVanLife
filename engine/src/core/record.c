/* Multiversal Van Life - data records (see record.h). MIT License. */
#include "core/record.h"
#include "core/vfs.h"
#include "lauxlib.h"
#include "lua.h"
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum { T_NIL, T_FALSE, T_TRUE, T_INT, T_NUM, T_STR, T_TABLE, T_SREF };

unsigned mvl_crc32(const void *data, size_t size) {
    const unsigned char *p = (const unsigned char *)data;
    uint32_t c = 0xffffffffu;
    for (size_t i = 0; i < size; ++i) {
        c ^= p[i];
        for (int k = 0; k < 8; ++k) c = (c >> 1) ^ (0xedb88320u & (0u - (c & 1u)));
    }
    return (unsigned)(c ^ 0xffffffffu);
}

/* ------------------------------------------------------------- encoder */
typedef struct {
    lua_State *L;
    unsigned char *buf;
    size_t len, cap;
    int strings;          /* stack index: string -> reference index */
    lua_Integer nstrings;
    char *err;
    size_t err_size;
    int failed;
} enc;

static void fail(enc *e, const char *msg) {
    if (!e->failed) snprintf(e->err, e->err_size, "%s", msg);
    e->failed = 1;
}

static void put(enc *e, const void *data, size_t n) {
    if (e->failed) return;
    if (e->len + n > e->cap) {
        size_t cap = e->cap ? e->cap : 256;
        unsigned char *nb;
        while (cap < e->len + n) cap *= 2;
        nb = (unsigned char *)realloc(e->buf, cap);
        if (!nb) {
            fail(e, "out of memory");
            return;
        }
        e->buf = nb;
        e->cap = cap;
    }
    memcpy(e->buf + e->len, data, n);
    e->len += n;
}

static void put_byte(enc *e, int b) {
    unsigned char c = (unsigned char)b;
    put(e, &c, 1);
}

static void put_varint(enc *e, uint64_t v) {
    unsigned char tmp[10];
    int n = 0;
    do {
        tmp[n] = (unsigned char)(v & 0x7f);
        v >>= 7;
        if (v) tmp[n] |= 0x80;
        ++n;
    } while (v);
    put(e, tmp, (size_t)n);
}

static void put_number(enc *e, lua_State *L, int idx) {
    if (lua_isinteger(L, idx)) {
        int64_t i = (int64_t)lua_tointeger(L, idx);
        put_byte(e, T_INT);
        put_varint(e, ((uint64_t)i << 1) ^ (uint64_t)(i >> 63)); /* zig-zag */
    } else {
        double d = (double)lua_tonumber(L, idx);
        uint64_t bits;
        unsigned char b[8];
        memcpy(&bits, &d, 8);
        for (int k = 0; k < 8; ++k) b[k] = (unsigned char)(bits >> (8 * k));
        put_byte(e, T_NUM);
        put(e, b, 8);
    }
}

static void put_string(enc *e, int idx) {
    lua_State *L = e->L;
    size_t n;
    const char *s = lua_tolstring(L, idx, &n);
    if (n >= 2) {
        lua_pushvalue(L, idx);
        if (lua_rawget(L, e->strings) == LUA_TNUMBER) {
            put_byte(e, T_SREF);
            put_varint(e, (uint64_t)lua_tointeger(L, -1));
            lua_pop(L, 1);
            return;
        }
        lua_pop(L, 1);
        lua_pushvalue(L, idx);
        lua_pushinteger(L, e->nstrings++);
        lua_rawset(L, e->strings);
    }
    put_byte(e, T_STR);
    put_varint(e, (uint64_t)n);
    put(e, s, n);
}

typedef struct {
    int type; /* 0 boolean, 1 number, 2 string */
    int boolean, is_int;
    lua_Integer i;
    double d;
    const char *s;
    size_t len;
} key;

static int key_cmp(const void *pa, const void *pb) {
    const key *a = (const key *)pa, *b = (const key *)pb;
    if (a->type != b->type) return a->type < b->type ? -1 : 1;
    if (a->type == 0) return a->boolean - b->boolean;
    if (a->type == 1) {
        if (a->is_int && b->is_int) return a->i < b->i ? -1 : (a->i > b->i);
        return a->d < b->d ? -1 : (a->d > b->d ? 1 : a->is_int - b->is_int);
    }
    {
        size_t n = a->len < b->len ? a->len : b->len;
        int c = memcmp(a->s, b->s, n);
        if (c) return c;
        return a->len < b->len ? -1 : (a->len > b->len);
    }
}

static void put_value(enc *e, int idx, int depth);

static void push_key(lua_State *L, const key *k) {
    if (k->type == 0) lua_pushboolean(L, k->boolean);
    else if (k->type == 1 && k->is_int) lua_pushinteger(L, k->i);
    else if (k->type == 1) lua_pushnumber(L, (lua_Number)k->d);
    else lua_pushlstring(L, k->s, k->len);
}

static void put_table(enc *e, int idx, int depth) {
    lua_State *L = e->L;
    lua_Integer n = (lua_Integer)lua_rawlen(L, idx);
    key *keys = NULL;
    size_t nk = 0, ck = 0;
    if (depth >= MVL_RECORD_MAX_DEPTH) {
        fail(e, "table nested too deeply (or it contains itself)");
        return;
    }
    if (!lua_checkstack(L, 8)) {
        fail(e, "out of stack space");
        return;
    }
    put_byte(e, T_TABLE);
    put_varint(e, (uint64_t)n);
    for (lua_Integer i = 1; i <= n && !e->failed; ++i) {
        lua_rawgeti(L, idx, i);
        put_value(e, lua_gettop(L), depth + 1);
        lua_pop(L, 1);
    }
    /* every other key, sorted so equal tables always encode the same */
    lua_pushnil(L);
    while (!e->failed && lua_next(L, idx)) {
        key k;
        memset(&k, 0, sizeof k);
        lua_pop(L, 1); /* value */
        switch (lua_type(L, -1)) {
        case LUA_TBOOLEAN:
            k.boolean = lua_toboolean(L, -1);
            break;
        case LUA_TNUMBER:
            k.type = 1;
            k.is_int = lua_isinteger(L, -1);
            k.i = k.is_int ? lua_tointeger(L, -1) : 0;
            k.d = (double)lua_tonumber(L, -1);
            if (k.is_int && k.i >= 1 && k.i <= n) continue; /* already in the array part */
            break;
        case LUA_TSTRING:
            k.type = 2;
            k.s = lua_tolstring(L, -1, &k.len); /* stays valid: the table holds the key */
            break;
        default:
            fail(e, "table keys must be booleans, numbers or strings");
            lua_pop(L, 1);
            continue;
        }
        if (nk == ck) {
            key *nkeys;
            ck = ck ? ck * 2 : 16;
            nkeys = (key *)realloc(keys, ck * sizeof *keys);
            if (!nkeys) {
                fail(e, "out of memory");
                lua_pop(L, 1);
                break;
            }
            keys = nkeys;
        }
        keys[nk++] = k;
    }
    if (!e->failed) {
        if (nk > 1) qsort(keys, nk, sizeof *keys, key_cmp);
        put_varint(e, (uint64_t)nk);
        for (size_t i = 0; i < nk && !e->failed; ++i) {
            push_key(L, &keys[i]);
            put_value(e, lua_gettop(L), depth + 1);
            lua_rawget(L, idx);
            put_value(e, lua_gettop(L), depth + 1);
            lua_pop(L, 1);
        }
    }
    free(keys);
}

static void put_value(enc *e, int idx, int depth) {
    lua_State *L = e->L;
    if (e->failed) return;
    switch (lua_type(L, idx)) {
    case LUA_TNIL:
        put_byte(e, T_NIL);
        break;
    case LUA_TBOOLEAN:
        put_byte(e, lua_toboolean(L, idx) ? T_TRUE : T_FALSE);
        break;
    case LUA_TNUMBER:
        put_number(e, L, idx);
        break;
    case LUA_TSTRING:
        put_string(e, idx);
        break;
    case LUA_TTABLE:
        put_table(e, idx, depth);
        break;
    default: {
        char msg[96];
        snprintf(msg, sizeof msg, "cannot store a %s in a record", luaL_typename(L, idx));
        fail(e, msg);
    }
    }
}

static void put_u32(unsigned char *p, uint32_t v) {
    for (int k = 0; k < 4; ++k) p[k] = (unsigned char)(v >> (8 * k));
}

static uint32_t get_u32(const unsigned char *p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

unsigned char *mvl_record_encode(lua_State *L, int idx, size_t *size, char *err, size_t err_size) {
    enc e;
    int top = lua_gettop(L);
    idx = lua_absindex(L, idx);
    memset(&e, 0, sizeof e);
    e.L = L;
    e.err = err;
    e.err_size = err_size;
    lua_newtable(L);
    e.strings = lua_gettop(L);
    put(&e, "MVLR\x01\0\0\0", 8);
    put(&e, "\0\0\0\0\0\0\0\0", 8); /* size and CRC, filled in below */
    put_value(&e, idx, 0);
    lua_settop(L, top);
    if (e.failed || e.len - MVL_RECORD_HEADER > 0xffffffffu) {
        if (!e.failed) fail(&e, "record too large");
        free(e.buf);
        return NULL;
    }
    put_u32(e.buf + 8, (uint32_t)(e.len - MVL_RECORD_HEADER));
    put_u32(e.buf + 12, mvl_crc32(e.buf + MVL_RECORD_HEADER, e.len - MVL_RECORD_HEADER));
    *size = e.len;
    return e.buf;
}

/* ------------------------------------------------------------- decoder */
typedef struct {
    lua_State *L;
    const unsigned char *p, *end;
    int strings;
    lua_Integer nstrings;
} dec;

static int get_varint(dec *d, uint64_t *out) {
    uint64_t v = 0;
    for (int shift = 0; shift < 64; shift += 7) {
        unsigned char b;
        if (d->p >= d->end) return 0;
        b = *d->p++;
        if (shift == 63 && (b & 0x7e)) return 0; /* would overflow 64 bits */
        v |= (uint64_t)(b & 0x7f) << shift;
        if (!(b & 0x80)) {
            *out = v;
            return 1;
        }
    }
    return 0;
}

static int get_value(dec *d, int depth);

static int get_table(dec *d, int depth) {
    lua_State *L = d->L;
    uint64_t n, m;
    int t;
    if (depth >= MVL_RECORD_MAX_DEPTH || !lua_checkstack(L, 8)) return 0;
    /* every value takes at least one byte: bound counts by the data left */
    if (!get_varint(d, &n) || n > (uint64_t)(d->end - d->p) || n > 0x7fffffffu) return 0;
    lua_createtable(L, (int)n, 0);
    t = lua_gettop(L);
    for (uint64_t i = 1; i <= n; ++i) {
        if (!get_value(d, depth + 1)) return 0;
        if (lua_isnil(L, -1)) lua_pop(L, 1);
        else lua_rawseti(L, t, (lua_Integer)i);
    }
    if (!get_varint(d, &m) || m > (uint64_t)(d->end - d->p) / 2) return 0;
    for (uint64_t i = 0; i < m; ++i) {
        int kt;
        if (!get_value(d, depth + 1)) return 0;
        kt = lua_type(L, -1);
        if (kt != LUA_TBOOLEAN && kt != LUA_TNUMBER && kt != LUA_TSTRING) return 0;
        if (kt == LUA_TNUMBER && !lua_isinteger(L, -1) && isnan((double)lua_tonumber(L, -1))) return 0;
        if (!get_value(d, depth + 1)) return 0;
        if (lua_isnil(L, -1)) lua_pop(L, 2);
        else lua_rawset(L, t);
    }
    return 1;
}

static int get_value(dec *d, int depth) {
    lua_State *L = d->L;
    uint64_t v;
    if (d->p >= d->end) return 0;
    switch (*d->p++) {
    case T_NIL:
        lua_pushnil(L);
        return 1;
    case T_FALSE:
    case T_TRUE:
        lua_pushboolean(L, d->p[-1] == T_TRUE);
        return 1;
    case T_INT:
        if (!get_varint(d, &v)) return 0;
        lua_pushinteger(L, (lua_Integer)(int64_t)((v >> 1) ^ (0u - (v & 1u))));
        return 1;
    case T_NUM: {
        uint64_t bits = 0;
        double x;
        if (d->end - d->p < 8) return 0;
        for (int k = 0; k < 8; ++k) bits |= (uint64_t)d->p[k] << (8 * k);
        d->p += 8;
        memcpy(&x, &bits, 8);
        lua_pushnumber(L, (lua_Number)x);
        return 1;
    }
    case T_STR:
        if (!get_varint(d, &v) || v > (uint64_t)(d->end - d->p)) return 0;
        lua_pushlstring(L, (const char *)d->p, (size_t)v);
        d->p += v;
        if (v >= 2) {
            lua_pushvalue(L, -1);
            lua_rawseti(L, d->strings, ++d->nstrings);
        }
        return 1;
    case T_SREF:
        if (!get_varint(d, &v) || v >= (uint64_t)d->nstrings) return 0;
        lua_rawgeti(L, d->strings, (lua_Integer)v + 1);
        return 1;
    case T_TABLE:
        return get_table(d, depth);
    default:
        return 0;
    }
}

int mvl_record_decode(lua_State *L, const unsigned char *data, size_t size) {
    dec d;
    int top = lua_gettop(L), ok;
    if (!data || size < MVL_RECORD_HEADER || memcmp(data, "MVLR", 4) || data[4] != MVL_RECORD_VERSION ||
        data[5] || data[6] || data[7]) /* reserved */
        return 0;
    if (get_u32(data + 8) != size - MVL_RECORD_HEADER) return 0;
    if (get_u32(data + 12) != mvl_crc32(data + MVL_RECORD_HEADER, size - MVL_RECORD_HEADER)) return 0;
    d.L = L;
    d.p = data + MVL_RECORD_HEADER;
    d.end = data + size;
    d.nstrings = 0;
    if (!lua_checkstack(L, 8)) return 0;
    lua_newtable(L);
    d.strings = lua_gettop(L);
    ok = get_value(&d, 0) && d.p == d.end;
    if (!ok) {
        lua_settop(L, top);
        return 0;
    }
    lua_remove(L, d.strings);
    return 1;
}

/* ---------------------------------------------------------------- files */
int mvl_record_save(lua_State *L, int idx, const char *path, char *err, size_t err_size) {
    char dir[MVL_PATH_MAX];
    size_t size;
    unsigned char *data = mvl_record_encode(L, idx, &size, err, err_size);
    int ok;
    if (!data) return 0;
    mvl_path_dirname(dir, sizeof dir, path);
    mvl_mkdirs(dir);
    ok = mvl_file_write_atomic(path, data, size);
    free(data);
    if (!ok) snprintf(err, err_size, "could not write %s", path);
    return ok;
}

static int load_one(lua_State *L, const char *path, int *found) {
    size_t size;
    char *data = mvl_file_read(path, &size);
    int ok;
    if (!data) return 0;
    *found = 1;
    ok = mvl_record_decode(L, (const unsigned char *)data, size);
    free(data);
    return ok;
}

int mvl_record_load(lua_State *L, const char *path) {
    char tmp[MVL_PATH_MAX + 8];
    int found = 0;
    if (load_one(L, path, &found)) return 1;
    /* interrupted save: the complete new version may still be in .tmp */
    snprintf(tmp, sizeof tmp, "%s.tmp", path);
    if (load_one(L, tmp, &found)) return 1;
    return found ? -1 : 0;
}
