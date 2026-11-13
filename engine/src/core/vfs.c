/* Multiversal Van Life - virtual file system over data folders. MIT License. */
#include "core/vfs.h"
#include "core/compat.h"
#include "core/log.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <direct.h>
#include <io.h>
#include <windows.h>
#else
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>
#endif

void mvl_vfs_init(mvl_vfs *vfs) { memset(vfs, 0, sizeof *vfs); }

int mvl_vfs_add_root(mvl_vfs *vfs, const char *dir, const char *name) {
    size_t len;
    mvl_vfs_root *r;
    if (vfs->count >= MVL_VFS_MAX_ROOTS || !dir) return -1;
    len = strlen(dir);
    if (len == 0 || len >= MVL_PATH_MAX - 1) return -1;
    r = &vfs->roots[vfs->count];
    memcpy(r->path, dir, len + 1);
    /* strip trailing separators */
    while (len > 1 && (r->path[len - 1] == '/' || r->path[len - 1] == '\\')) r->path[--len] = 0;
    snprintf(r->name, sizeof r->name, "%s", name ? name : "root");
    return vfs->count++;
}

int mvl_vfs_add_mods(mvl_vfs *vfs, const char *mods_dir) {
    char list_path[MVL_PATH_MAX], dir[MVL_PATH_MAX];
    char *text, *line, *save = NULL;
    int added = 0;
    mvl_path_join(list_path, sizeof list_path, mods_dir, "mods.txt");
    text = mvl_file_read(list_path, NULL);
    if (!text) return 0;
    for (line = strtok_r(text, "\r\n", &save); line; line = strtok_r(NULL, "\r\n", &save)) {
        char clean[MVL_PATH_MAX];
        while (*line == ' ' || *line == '\t') ++line;
        if (*line == 0 || *line == '#') continue;
        if (!mvl_vfs_sanitize(line, clean, sizeof clean) || strchr(clean, '/')) {
            MVL_WARN("ignoring invalid mod name '%s'", line);
            continue;
        }
        mvl_path_join(dir, sizeof dir, mods_dir, clean);
        if (mvl_vfs_add_root(vfs, dir, clean) >= 0) {
            MVL_INFO("mod enabled: %s", clean);
            ++added;
        }
    }
    free(text);
    return added;
}

int mvl_vfs_sanitize(const char *in, char *out, size_t out_size) {
    size_t o = 0;
    const char *p = in;
    if (!in || !out || out_size == 0) return 0;
    if (in[0] == '/' || in[0] == '\\' || (in[0] && in[1] == ':')) return 0;
    while (*p) {
        const char *seg = p;
        size_t n;
        while (*p && *p != '/' && *p != '\\') ++p;
        n = (size_t)(p - seg);
        if (n == 2 && seg[0] == '.' && seg[1] == '.') return 0;
        if (n > 0 && !(n == 1 && seg[0] == '.')) {
            if (o + n + 2 > out_size) return 0;
            if (o > 0) out[o++] = '/';
            memcpy(out + o, seg, n);
            o += n;
        }
        if (*p) ++p;
    }
    out[o] = 0;
    return o > 0;
}

void mvl_path_join(char *out, size_t out_size, const char *dir, const char *file) {
    size_t dl = strlen(dir);
    if (dl == 0) snprintf(out, out_size, "%s", file);
    else if (dir[dl - 1] == '/' || dir[dl - 1] == '\\') snprintf(out, out_size, "%s%s", dir, file);
    else snprintf(out, out_size, "%s/%s", dir, file);
}

void mvl_path_dirname(char *out, size_t out_size, const char *path) {
    const char *slash = strrchr(path, '/');
    const char *bslash = strrchr(path, '\\');
    size_t n;
    if (bslash && (!slash || bslash > slash)) slash = bslash;
    if (!slash) {
        snprintf(out, out_size, ".");
        return;
    }
    n = (size_t)(slash - path);
    if (n == 0) n = 1; /* root "/" */
    if (n >= out_size) n = out_size - 1;
    memcpy(out, path, n);
    out[n] = 0;
}

static int file_exists(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) return 0;
    fclose(f);
    return 1;
}

int mvl_vfs_resolve(const mvl_vfs *vfs, const char *rel, char *out, size_t out_size) {
    char clean[MVL_PATH_MAX];
    if (!mvl_vfs_sanitize(rel, clean, sizeof clean)) return -1;
    for (int i = vfs->count - 1; i >= 0; --i) {
        mvl_path_join(out, out_size, vfs->roots[i].path, clean);
        if (file_exists(out)) return i;
    }
    return -1;
}

int mvl_vfs_exists(const mvl_vfs *vfs, const char *rel) {
    char full[MVL_PATH_MAX * 2];
    return mvl_vfs_resolve(vfs, rel, full, sizeof full) >= 0;
}

char *mvl_vfs_read(const mvl_vfs *vfs, const char *rel, size_t *size) {
    char full[MVL_PATH_MAX * 2];
    if (mvl_vfs_resolve(vfs, rel, full, sizeof full) < 0) return NULL;
    return mvl_file_read(full, size);
}

char *mvl_vfs_read_root(const mvl_vfs *vfs, int root, const char *rel, size_t *size) {
    char clean[MVL_PATH_MAX], full[MVL_PATH_MAX * 2];
    if (root < 0 || root >= vfs->count) return NULL;
    if (!mvl_vfs_sanitize(rel, clean, sizeof clean)) return NULL;
    mvl_path_join(full, sizeof full, vfs->roots[root].path, clean);
    return mvl_file_read(full, size);
}

char *mvl_file_read(const char *path, size_t *size) {
    FILE *f = fopen(path, "rb");
    char *buf;
    long len;
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    len = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (len < 0) {
        fclose(f);
        return NULL;
    }
    buf = (char *)malloc((size_t)len + 1);
    if (buf && fread(buf, 1, (size_t)len, f) != (size_t)len) {
        free(buf);
        buf = NULL;
    }
    fclose(f);
    if (!buf) return NULL;
    buf[len] = 0;
    if (size) *size = (size_t)len;
    return buf;
}

int mvl_file_write(const char *path, const void *data, size_t size) {
    FILE *f = fopen(path, "wb");
    size_t n;
    if (!f) return 0;
    n = fwrite(data, 1, size, f);
    fclose(f);
    return n == size;
}

int mvl_file_write_atomic(const char *path, const void *data, size_t size) {
    char tmp[MVL_PATH_MAX + 8];
    FILE *f;
    int ok;
    if (snprintf(tmp, sizeof tmp, "%s.tmp", path) >= (int)sizeof tmp) return 0;
    f = fopen(tmp, "wb");
    if (!f) return 0;
    ok = fwrite(data, 1, size, f) == size;
    ok = fflush(f) == 0 && ok;
#if defined(_WIN32)
    ok = ok && _commit(_fileno(f)) == 0;
#else
    ok = ok && fsync(fileno(f)) == 0;
#endif
    ok = fclose(f) == 0 && ok;
#if defined(_WIN32)
    ok = ok && MoveFileExA(tmp, path, MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH);
#else
    ok = ok && rename(tmp, path) == 0;
#endif
    if (!ok) remove(tmp);
    return ok;
}

int mvl_is_dir(const char *path) {
#if defined(_WIN32)
    DWORD a = GetFileAttributesA(path);
    return a != INVALID_FILE_ATTRIBUTES && (a & FILE_ATTRIBUTE_DIRECTORY) != 0;
#else
    struct stat st;
    return stat(path, &st) == 0 && S_ISDIR(st.st_mode);
#endif
}

int mvl_mkdirs(const char *dir) {
    char buf[MVL_PATH_MAX];
    size_t n = strlen(dir);
    if (n == 0 || n >= sizeof buf) return 0;
    memcpy(buf, dir, n + 1);
    for (size_t i = 1; i <= n; ++i) {
        char c = buf[i];
        if (c != '/' && c != '\\' && c != 0) continue;
        if (i == 2 && buf[1] == ':') continue; /* drive letter */
        buf[i] = 0;
        if (!mvl_is_dir(buf)) {
#if defined(_WIN32)
            _mkdir(buf);
#else
            mkdir(buf, 0755);
#endif
        }
        buf[i] = c;
    }
    return mvl_is_dir(dir);
}

static int walk(char *path, size_t root_len, int depth, mvl_dir_fn fn, void *user) {
    size_t len = strlen(path);
    int count = 0;
    if (depth > 16) return 0;
#if defined(_WIN32)
    {
        WIN32_FIND_DATAA fd;
        HANDLE h;
        if (len + 3 >= MVL_PATH_MAX) return 0;
        memcpy(path + len, "/*", 3);
        h = FindFirstFileA(path, &fd);
        path[len] = 0;
        if (h == INVALID_HANDLE_VALUE) return 0;
        do {
            const char *name = fd.cFileName;
#else
    {
        DIR *d = opendir(path);
        struct dirent *ent;
        if (!d) return 0;
        while ((ent = readdir(d)) != NULL) {
            const char *name = ent->d_name;
#endif
            size_t nl = strlen(name);
            int is_dir;
            if (!strcmp(name, ".") || !strcmp(name, "..") || len + nl + 2 >= MVL_PATH_MAX) continue;
            path[len] = '/';
            memcpy(path + len + 1, name, nl + 1);
            is_dir = mvl_is_dir(path);
            if (is_dir) count += walk(path, root_len, depth + 1, fn, user);
            fn(path + root_len + 1, is_dir, user);
            ++count;
            path[len] = 0;
#if defined(_WIN32)
        } while (FindNextFileA(h, &fd));
        FindClose(h);
    }
#else
        }
        closedir(d);
    }
#endif
    return count;
}

int mvl_dir_walk(const char *dir, mvl_dir_fn fn, void *user) {
    char path[MVL_PATH_MAX];
    size_t n = strlen(dir);
    if (n == 0 || n >= sizeof path) return 0;
    memcpy(path, dir, n + 1);
    while (n > 1 && (path[n - 1] == '/' || path[n - 1] == '\\')) path[--n] = 0;
    return walk(path, n, 0, fn, user);
}

int mvl_remove_path(const char *path) {
    if (mvl_is_dir(path)) {
#if defined(_WIN32)
        return _rmdir(path) == 0;
#else
        return rmdir(path) == 0;
#endif
    }
    return remove(path) == 0;
}
