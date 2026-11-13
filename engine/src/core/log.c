/* Multiversal Van Life - logging. MIT License. */
#include "core/log.h"
#include <stdarg.h>
#include <stdio.h>

static mvl_log_sink g_sink;
static void *g_user;
static mvl_log_level g_min = MVL_LOG_INFO;

void mvl_log_set_sink(mvl_log_sink sink, void *user) {
    g_sink = sink;
    g_user = user;
}

void mvl_log_set_min_level(mvl_log_level level) { g_min = level; }

void mvl_log(mvl_log_level level, const char *fmt, ...) {
    static const char *names[] = {"debug", "info", "warn", "error"};
    char buf[1024];
    va_list ap;
    if (level < g_min) return;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof buf, fmt, ap);
    va_end(ap);
    if (g_sink) {
        g_sink(level, buf, g_user);
        return;
    }
    fprintf(stderr, "[%s] %s\n", names[level], buf);
}
