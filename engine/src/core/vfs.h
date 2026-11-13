/* Multiversal Van Life - virtual file system over data folders. MIT License.
 *
 * Assets are never baked into the executable. The VFS searches a list of
 * root folders (mods first, then the base `game/` folder) for relative paths
 * such as "scripts/main.lua". Paths are sanitised: absolute paths and ".."
 * components are rejected so scripts cannot escape the data folders.
 */
#ifndef MVL_VFS_H
#define MVL_VFS_H

#include <stddef.h>

#define MVL_VFS_MAX_ROOTS 16
#define MVL_PATH_MAX 512

typedef struct {
    char path[MVL_PATH_MAX];
    char name[64]; /* display name, e.g. "base" or the mod folder name */
} mvl_vfs_root;

typedef struct {
    mvl_vfs_root roots[MVL_VFS_MAX_ROOTS];
    int count;
} mvl_vfs;

void mvl_vfs_init(mvl_vfs *vfs);
/* Adds a root. Roots added later have higher priority. Returns index or -1. */
int mvl_vfs_add_root(mvl_vfs *vfs, const char *dir, const char *name);
/* Adds every sub folder of `mods_dir` listed (one name per line) in
 * `mods_dir/mods.txt`. Returns number of mods added. */
int mvl_vfs_add_mods(mvl_vfs *vfs, const char *mods_dir);

/* Normalises a relative path into `out`. Returns 0 if the path is unsafe. */
int mvl_vfs_sanitize(const char *in, char *out, size_t out_size);
/* Joins a directory and file name with '/'. */
void mvl_path_join(char *out, size_t out_size, const char *dir, const char *file);
/* Writes the directory part of `path` (without trailing slash) to `out`. */
void mvl_path_dirname(char *out, size_t out_size, const char *path);

/* Resolves to the full path of the highest-priority root containing the
 * file. Returns root index or -1. */
int mvl_vfs_resolve(const mvl_vfs *vfs, const char *rel, char *out, size_t out_size);
int mvl_vfs_exists(const mvl_vfs *vfs, const char *rel);
/* Reads a whole file (NUL terminated, size excludes the NUL). Caller frees. */
char *mvl_vfs_read(const mvl_vfs *vfs, const char *rel, size_t *size);
/* Reads from one specific root only. */
char *mvl_vfs_read_root(const mvl_vfs *vfs, int root, const char *rel, size_t *size);

/* Plain file helpers (absolute or cwd-relative paths). */
char *mvl_file_read(const char *path, size_t *size);
int mvl_file_write(const char *path, const void *data, size_t size);

#endif
