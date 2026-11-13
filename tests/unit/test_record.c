/* Unit tests: data records (record.c) and the file helpers they use. MIT License. */
#include "test.h"
#include "core/record.h"
#include "core/vfs.h"
#include "lauxlib.h"
#include "lua.h"
#include "lualib.h"
#include <stdlib.h>

/* enc(v) -> bytes or nil, err ; dec(bytes) -> ok, value */
static int l_enc(lua_State *L) {
    size_t n;
    char err[128];
    unsigned char *d = mvl_record_encode(L, 1, &n, err, sizeof err);
    if (!d) {
        lua_pushnil(L);
        lua_pushstring(L, err);
        return 2;
    }
    lua_pushlstring(L, (const char *)d, n);
    free(d);
    return 1;
}

static int l_dec(lua_State *L) {
    size_t n;
    const char *s = luaL_checklstring(L, 1, &n);
    int top = lua_gettop(L);
    int ok = mvl_record_decode(L, (const unsigned char *)s, n);
    if (lua_gettop(L) != top + ok) return luaL_error(L, "unbalanced stack");
    lua_pushboolean(L, ok);
    if (ok) lua_insert(L, -2);
    return ok ? 2 : 1;
}

static int l_crc(lua_State *L) {
    size_t n;
    const char *s = luaL_checklstring(L, 1, &n);
    lua_pushinteger(L, (lua_Integer)mvl_crc32(s, n));
    return 1;
}

static lua_State *state(void) {
    lua_State *L = luaL_newstate();
    luaL_openlibs(L);
    lua_register(L, "enc", l_enc);
    lua_register(L, "dec", l_dec);
    lua_register(L, "crc", l_crc);
    return L;
}

static void run(lua_State *L, const char *code) {
    int ok = luaL_dostring(L, code) == LUA_OK;
    if (!ok) fprintf(stderr, "lua: %s\n", lua_tostring(L, -1));
    CHECK(ok);
    lua_settop(L, 0);
}

static const char *DEEP_EQ =
    "function deq(a, b)\n"
    "  if type(a) ~= type(b) then return false end\n"
    "  if type(a) == 'number' then return math.type(a) == math.type(b) and (a == b or (a ~= a and b ~= b)) end\n"
    "  if type(a) ~= 'table' then return a == b end\n"
    "  for k, v in pairs(a) do if not deq(v, b[k]) then return false end end\n"
    "  for k in pairs(b) do if a[k] == nil then return false end end\n"
    "  return true\n"
    "end\n";

void test_record_format(void) {
    lua_State *L = state();
    run(L, DEEP_EQ);
    run(L, "assert(crc('123456789') == 0xCBF43926) assert(crc('') == 0)");
    /* round trips */
    run(L, "local t = { 1, 2.5, 'three', true, false, { nested = { deeper = { 'x' } } },\n"
           "  name = 'Lanternfen', [7.25] = 'float key', [true] = 'yes', [false] = 0, [-3] = 'neg',\n"
           "  big = math.maxinteger, small = math.mininteger, zero = 0, negz = -0.0, inf = math.huge,\n"
           "  ninf = -math.huge, nan = 0/0, bytes = 'a\\0b\\255', empty = {}, long = string.rep('ab', 300) }\n"
           "local s = assert(enc(t))\n"
           "local ok, u = dec(s)\n"
           "assert(ok and deq(t, u), 'round trip')\n"
           "assert(math.type(u.zero) == 'integer' and math.type(u[2]) == 'float')\n"
           "assert(1 / u.negz < 0, 'negative zero kept')\n"
           "for _, v in ipairs({ 0, -1, 1, 63, -64, 64, 1 << 40, -(1 << 40), 'x', '', true }) do\n"
           "  local ok2, w = dec(assert(enc({ v }))) assert(ok2 and w[1] == v, tostring(v)) end\n"
           "local ok3, top = dec(assert(enc('just a string'))) assert(ok3 and top == 'just a string')\n"
           "local ok4, n = dec(assert(enc(nil))) assert(ok4 and n == nil)\n");
    /* holes in arrays, repeated strings are stored once */
    run(L, "local t = { 1, nil, 3 } t[4] = 4\n"
           "local ok, u = dec(assert(enc(t))) assert(ok and u[1] == 1 and u[2] == nil and u[4] == 4)\n"
           "local rows = {} for i = 1, 200 do rows[i] = { kind = 'village', owner = 'Brassa' } end\n"
           "local s = assert(enc(rows)) assert(#s < 200 * 12, 'compact: ' .. #s)\n"
           "local ok2, back = dec(s) assert(ok2 and deq(rows, back))\n");
    /* the same table always encodes to the same bytes */
    run(L, "local a, b = {}, {}\n"
           "for i = 1, 50 do a['k' .. i] = i end\n"
           "for i = 50, 1, -1 do b['k' .. i] = i end\n"
           "a[1.5] = true b[1.5] = true a[false] = 1 b[false] = 1\n"
           "assert(enc(a) == enc(b), 'deterministic')\n");
    /* unsupported values */
    run(L, "local function bad(v, pat) local s, err = enc(v) assert(s == nil and err:find(pat), err) end\n"
           "bad({ f = print }, 'function')\n"
           "bad({ [{}] = 1 }, 'keys')\n"
           "bad({ co = coroutine.create(print) }, 'thread')\n"
           "bad({ io.stdout }, 'userdata')\n"
           "local cyc = {} cyc.self = cyc bad(cyc, 'deeply')\n"
           "local deep = {} local c = deep for i = 1, 60 do c.x = {} c = c.x end bad(deep, 'deeply')\n");
    /* damaged data never decodes and never breaks the stack */
    run(L, "local s = assert(enc({ a = { 1, 2, 3 }, b = 'text', c = 1.5 }))\n"
           "for n = 0, #s - 1 do assert(not dec(s:sub(1, n)), 'truncated ' .. n) end\n"
           "for i = 1, #s do local c = s:byte(i)\n"
           "  local m = s:sub(1, i - 1) .. string.char((c + 1) % 256) .. s:sub(i + 1)\n"
           "  assert(not dec(m), 'flipped byte ' .. i) end\n"
           "assert(not dec('return os.exit(1)'), 'code is not a record')\n"
           "assert(not dec(s .. 'x'), 'trailing data')\n");
    /* structurally invalid payloads with a valid header and CRC */
    run(L, "local function rec(p)\n"
           "  return 'MVLR\\1\\0\\0\\0' .. string.pack('<I4I4', #p, crc(p)) .. p end\n"
           "assert(dec(rec('\\2')))\n"
           "for _, p in ipairs({ '', '\\9', '\\3', '\\3\\255', '\\4\\0\\0', '\\5\\5ab', '\\7\\0', '\\6\\9', '\\6\\0\\9',\n"
           "    '\\6\\0\\1\\6\\0\\0\\1', '\\6\\0\\1\\0\\1', '\\6\\0\\1\\4' .. string.pack('<d', 0/0) .. '\\1',\n"
           "    '\\3\\255\\255\\255\\255\\255\\255\\255\\255\\255\\127', '\\2\\2' }) do\n"
           "  assert(not dec(rec(p)), 'invalid payload ' .. p:gsub('.', function(c) return c:byte() .. ' ' end)) end\n"
           "local hdr = rec('\\2') assert(not dec('MVLR\\2' .. hdr:sub(6)), 'future version')\n"
           "local ok, t = dec(rec('\\6\\0\\1\\2\\0')) assert(ok and next(t) == nil, 'nil values are skipped')\n");
    /* random mutations of valid records (with a fixed-up CRC) are safe */
    run(L, "local base = assert(enc({ list = { 1, 2, 3, 'x', { y = 'zz' } }, name = 'abc', n = 4.5, flag = true }))\n"
           "local seed = 12345\n"
           "local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648 return seed % n end\n"
           "local payload = base:sub(17)\n"
           "for _ = 1, 3000 do\n"
           "  local p = payload local i = rnd(#p) + 1\n"
           "  p = p:sub(1, i - 1) .. string.char(rnd(256)) .. p:sub(i + 1)\n"
           "  if rnd(4) == 0 then p = p:sub(1, rnd(#p) + 1) end\n"
           "  dec('MVLR\\1\\0\\0\\0' .. string.pack('<I4I4', #p, crc(p)) .. p)\n"
           "end\n");
    lua_close(L);
}

static int g_seen;
static void count_entry(const char *rel, int is_dir, void *user) {
    (void)rel;
    (void)user;
    g_seen += is_dir ? 100 : 1;
}

void test_record_files(void) {
    lua_State *L = state();
    char dir[512], path[600], tmp[620], err[128];
    size_t n;
    unsigned char *good;
    run(L, DEEP_EQ);
    tmp_path(dir, sizeof dir, "records_test/a/b");
    CHECK(mvl_mkdirs(dir));
    CHECK(mvl_mkdirs(dir)); /* already there */
    CHECK(!mvl_mkdirs(""));
    snprintf(path, sizeof path, "%s/rec.rec", dir);
    snprintf(tmp, sizeof tmp, "%s.tmp", path);
    mvl_remove_path(path);
    mvl_remove_path(tmp);
    CHECK_EQ_INT(mvl_record_load(L, path), 0); /* missing */
    /* save and load */
    run(L, "T1 = { place = 'farm', visits = 3 } T2 = { place = 'farm', visits = 4 }");
    lua_getglobal(L, "T1");
    CHECK(mvl_record_save(L, -1, path, err, sizeof err));
    lua_settop(L, 0);
    CHECK_EQ_INT(mvl_record_load(L, path), 1);
    lua_setglobal(L, "R");
    run(L, "assert(deq(R, T1))");
    /* a crash while writing the next version: the partial .tmp is ignored */
    lua_getglobal(L, "T2");
    good = mvl_record_encode(L, -1, &n, err, sizeof err);
    lua_settop(L, 0);
    CHECK(good != NULL);
    CHECK(mvl_file_write(tmp, good, n / 2));
    CHECK_EQ_INT(mvl_record_load(L, path), 1);
    lua_setglobal(L, "R");
    run(L, "assert(deq(R, T1), 'old version survives')");
    /* a crash between writing .tmp and the rename (or a damaged main file):
     * the complete .tmp is used */
    CHECK(mvl_file_write(tmp, good, n));
    CHECK(mvl_file_write(path, good, 10));
    CHECK_EQ_INT(mvl_record_load(L, path), 1);
    lua_setglobal(L, "R");
    run(L, "assert(deq(R, T2), 'new version from .tmp')");
    /* both damaged */
    CHECK(mvl_file_write(tmp, "junk", 4));
    CHECK_EQ_INT(mvl_record_load(L, path), -1);
    CHECK_EQ_INT(lua_gettop(L), 0);
    free(good);
    /* unsupported values and unwritable paths */
    run(L, "BAD = { print }");
    lua_getglobal(L, "BAD");
    CHECK(!mvl_record_save(L, -1, path, err, sizeof err));
    CHECK(strstr(err, "function") != NULL);
    /* a folder cannot be created below a plain file, not even by root */
    tmp_write("records_blocker", "x", 1);
    tmp_path(dir, sizeof dir, "records_blocker/x/y.rec");
    lua_getglobal(L, "T1");
    CHECK(!mvl_record_save(L, -1, dir, err, sizeof err));
    CHECK(strstr(err, "could not write") != NULL);
    lua_settop(L, 0);
    tmp_path(dir, sizeof dir, "records_blocker/x.rec");
    CHECK(!mvl_file_write_atomic(dir, "x", 1));
    tmp_path(dir, sizeof dir, "records_test");
    /* folder walking and removal */
    g_seen = 0;
    CHECK(mvl_dir_walk(dir, count_entry, NULL) >= 3);
    CHECK(g_seen >= 2 * 100 + 1); /* folders a and b, the record */
    CHECK(!mvl_remove_path(dir)); /* not empty */
    CHECK_EQ_INT(mvl_dir_walk("", count_entry, NULL), 0);
    tmp_path(path, sizeof path, "records_missing_dir");
    CHECK_EQ_INT(mvl_dir_walk(path, count_entry, NULL), 0);
    CHECK(mvl_is_dir(dir));
    CHECK(!mvl_is_dir(path));
    lua_close(L);
}
