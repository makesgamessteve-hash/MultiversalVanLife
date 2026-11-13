/* Multiversal Van Life - virtual file system over data folders. MIT License. */
#include "core/vfs.h"
#include "core/compat.h"
#include "core/log.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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
