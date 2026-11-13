/* Multiversal Van Life - logging. MIT License. */
#ifndef MVL_LOG_H
#define MVL_LOG_H

typedef enum { MVL_LOG_DEBUG, MVL_LOG_INFO, MVL_LOG_WARN, MVL_LOG_ERROR } mvl_log_level;

typedef void (*mvl_log_sink)(mvl_log_level level, const char *msg, void *user);

/* Replaces the log sink. NULL restores the default (stderr). */
void mvl_log_set_sink(mvl_log_sink sink, void *user);
void mvl_log_set_min_level(mvl_log_level level);
void mvl_log(mvl_log_level level, const char *fmt, ...);

#define MVL_INFO(...) mvl_log(MVL_LOG_INFO, __VA_ARGS__)
#define MVL_WARN(...) mvl_log(MVL_LOG_WARN, __VA_ARGS__)
#define MVL_ERROR(...) mvl_log(MVL_LOG_ERROR, __VA_ARGS__)
#define MVL_DEBUG(...) mvl_log(MVL_LOG_DEBUG, __VA_ARGS__)

#endif
