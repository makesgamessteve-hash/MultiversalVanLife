/* Multiversal Van Life - retro OpenGL renderer. MIT License.
 * The world is drawn into a low resolution off-screen target with per
 * vertex lighting, vertex snapping and fog, then upscaled with nearest
 * filtering and ordered dithering. The UI is drawn into its own canvas. */
#ifndef MVL_RENDERER_H
#define MVL_RENDERER_H

#include "core/engine.h"

typedef struct mvl_renderer mvl_renderer;

mvl_renderer *mvl_renderer_create(void);
/* Returns a gfx backend that uploads into this renderer. */
mvl_gfx_backend mvl_renderer_backend(mvl_renderer *r);
/* Compiles shaders (loaded from the engine VFS). Call after engine init. */
int mvl_renderer_init(mvl_renderer *r, mvl_engine *e);
void mvl_renderer_destroy(mvl_renderer *r);
/* Draws the scene and UI to the default framebuffer of size w x h. */
void mvl_renderer_draw(mvl_renderer *r, mvl_engine *e, int w, int h);

/* XR: draws one eye into framebuffer `fbo` with the viewport and the
 * head-relative view/projection supplied by WebXR. */
void mvl_renderer_draw_xr_view(mvl_renderer *r, mvl_engine *e, unsigned fbo, const int viewport[4],
                               const float view[16], const float proj[16]);
/* Draws the UI canvas off-screen (call once per XR frame before the views). */
void mvl_renderer_prepare_xr(mvl_renderer *r, mvl_engine *e);

/* Reads the default framebuffer into an RGBA image (top-left origin). */
int mvl_renderer_screenshot(mvl_renderer *r, int w, int h, mvl_image *out);

#endif
