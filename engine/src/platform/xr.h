/* Multiversal Van Life - WebXR (immersive VR) glue. On desktop builds these
 * are stubs; on the web they talk to web/library_webxr.js. MIT License. */
#ifndef MVL_XR_H
#define MVL_XR_H

#include "core/engine.h"

int mvl_xr_supported(void);
void mvl_xr_start(mvl_engine *e);

/* provided by main.c */
void mvl_platform_xr_tick(double dt);
struct mvl_renderer *mvl_platform_renderer(void);
mvl_engine *mvl_platform_engine(void);

#endif
