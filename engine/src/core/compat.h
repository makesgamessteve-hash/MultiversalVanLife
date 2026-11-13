/* Multiversal Van Life - portability shims. MIT License. */
#ifndef MVL_COMPAT_H
#define MVL_COMPAT_H

#if defined(_MSC_VER)
#define strtok_r strtok_s
#define strcasecmp _stricmp
#define strncasecmp _strnicmp
#else
#include <strings.h>
#endif

#endif
