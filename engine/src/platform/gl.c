/* Multiversal Van Life - OpenGL entry point loader. MIT License. */
#include "platform/gl.h"
#include <SDL3/SDL.h>

#ifdef __EMSCRIPTEN__
int mvl_gl_load(void) { return 1; }
#else
#define X(ret, name, params) mvl_pfn_##name mvl_##name;
MVL_GL_FUNCS
#undef X

int mvl_gl_load(void) {
    int ok = 1;
#define X(ret, name, params)                                                 \
    mvl_##name = (mvl_pfn_##name)SDL_GL_GetProcAddress(#name);               \
    if (!mvl_##name) {                                                       \
        SDL_Log("missing OpenGL function %s", #name);                        \
        ok = 0;                                                              \
    }
    MVL_GL_FUNCS
#undef X
    return ok;
}
#endif
