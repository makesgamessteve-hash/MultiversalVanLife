/* Multiversal Van Life - WebXR glue. MIT License.
 *
 * Flow: Lua calls mvl.xr_request() -> the platform calls mvl_xr_start() ->
 * JS requests an 'immersive-vr' session and drives frames by calling
 * mvl_xr_frame() for every XR animation frame with the per-eye matrices and
 * controller state. When the session ends JS calls mvl_xr_session_ended().
 */
#include "platform/xr.h"
#include "core/log.h"
#include "platform/renderer.h"
#include <math.h>

#ifdef __EMSCRIPTEN__
#include <emscripten.h>

extern int mvl_js_xr_supported(void);
extern void mvl_js_xr_start(void);

int mvl_xr_supported(void) { return mvl_js_xr_supported(); }

void mvl_xr_start(mvl_engine *e) {
    (void)e;
    mvl_js_xr_start();
}

/* views: per view 4 viewport ints (as floats) + 16 view + 16 projection.
 * input: move_x, move_y, turn, interact, back, menu */
EMSCRIPTEN_KEEPALIVE void mvl_xr_frame(unsigned fbo, int nviews, const float *views, const float *input, double dt) {
    mvl_engine *e = mvl_platform_engine();
    struct mvl_renderer *r = mvl_platform_renderer();
    const float *v0 = views + 4;
    e->xr_active = 1;
    /* head yaw/pitch from the first view matrix (inverse rotation) */
    /* head forward = -(row 2 of the view rotation) = -(m[2], m[6], m[10]) */
    e->xr_head_yaw = atan2f(v0[2], v0[10]);
    e->xr_head_pitch = asinf(v0[6] > 1 ? -1 : (v0[6] < -1 ? 1 : -v0[6]));
    mvl_input_set_external(&e->input, "move_x", input[0]);
    mvl_input_set_external(&e->input, "move_y", input[1]);
    mvl_input_set_external(&e->input, "turn", input[2]);
    mvl_input_set_external(&e->input, "interact", input[3]);
    mvl_input_set_external(&e->input, "back", input[4]);
    mvl_input_set_external(&e->input, "menu", input[5]);
    mvl_platform_xr_tick(dt);
    for (int i = 0; i < nviews; ++i) {
        const float *v = views + i * 36;
        int vp[4] = {(int)v[0], (int)v[1], (int)v[2], (int)v[3]};
        mvl_renderer_draw_xr_view(r, e, fbo, vp, v + 4, v + 20);
    }
}

EMSCRIPTEN_KEEPALIVE void mvl_xr_session_ended(void) {
    mvl_engine *e = mvl_platform_engine();
    e->xr_active = 0;
    e->xr_head_yaw = e->xr_head_pitch = 0;
    mvl_input_reset(&e->input);
    MVL_INFO("XR session ended");
}
#else
int mvl_xr_supported(void) { return 0; }
void mvl_xr_start(mvl_engine *e) { (void)e; }
#endif
