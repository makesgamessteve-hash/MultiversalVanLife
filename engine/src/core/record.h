/* Multiversal Van Life - data records: compact, safe storage of Lua tables.
 * MIT License.
 *
 * A record is a Lua value (nil, boolean, integer, number, string or a table
 * of those, nested up to MVL_RECORD_MAX_DEPTH) stored in a small tagged
 * binary format:
 *
 *   header  "MVLR" | u8 version | 3 reserved zero bytes | u32 payload size |
 *           u32 CRC-32 of the payload                       (16 bytes, LE)
 *   value   tag byte, then
 *             0 nil, 1 false, 2 true
 *             3 integer: zig-zag varint
 *             4 number: IEEE 754 double, little-endian
 *             5 string: varint length, bytes (remembered for tag 7)
 *             6 table: varint n, n array values (1..n), varint m, m sorted
 *               key/value pairs
 *             7 string reference: varint index of an earlier string
 *
 * Decoding builds Lua tables directly; no Lua code is ever parsed or run,
 * and every length, index and depth is checked against the data. Files are
 * written atomically (`<file>.tmp`, flushed, then renamed); a reader that
 * finds the main file missing or damaged falls back to the `.tmp` file. */
#ifndef MVL_RECORD_H
#define MVL_RECORD_H

#include <stddef.h>

struct lua_State;

#define MVL_RECORD_VERSION 1
#define MVL_RECORD_MAX_DEPTH 48
#define MVL_RECORD_HEADER 16

/* Encodes the value at stack index `idx`. Returns a malloc'd buffer (caller
 * frees) or NULL with a message in `err` (unsupported value, too deep). */
unsigned char *mvl_record_encode(struct lua_State *L, int idx, size_t *size, char *err, size_t err_size);
/* Decodes a buffer and pushes the value. Returns 1, or 0 (nothing pushed)
 * if the data is not a valid record. */
int mvl_record_decode(struct lua_State *L, const unsigned char *data, size_t size);

/* Encodes the value at `idx` and writes it atomically to `path`, creating
 * missing folders. Returns 1, or 0 with a message in `err`. */
int mvl_record_save(struct lua_State *L, int idx, const char *path, char *err, size_t err_size);
/* Loads `path` (or its `.tmp` fallback) and pushes the value. Returns 1 if
 * loaded, 0 if neither file exists (nothing pushed), -1 if they are damaged
 * (nothing pushed). */
int mvl_record_load(struct lua_State *L, const char *path);

/* CRC-32 (IEEE 802.3, as used by zip and PNG). */
unsigned mvl_crc32(const void *data, size_t size);

#endif
