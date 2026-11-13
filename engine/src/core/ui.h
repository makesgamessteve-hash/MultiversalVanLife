/* Multiversal Van Life - immediate mode 2D UI draw list. MIT License.
 * Coordinates are virtual pixels of the low resolution UI canvas
 * (origin top-left). Text uses an 8x8 cell bitmap font (ASCII 32..127 in a
 * 16x6 grid) with a 6 pixel advance. */
#ifndef MVL_UI_H
#define MVL_UI_H

#include <stddef.h>

#define MVL_UI_MAX_QUADS 4096
#define MVL_FONT_CELL 8
#define MVL_FONT_ADVANCE 6
#define MVL_FONT_LINE 10

typedef struct {
    float x, y, w, h;
    float u0, v0, u1, v1;
    float color[4];
    int texture; /* resource id, 0 = white */
} mvl_ui_quad;

typedef struct {
    mvl_ui_quad quads[MVL_UI_MAX_QUADS];
    int count;
    float width, height;
    int font_texture;
} mvl_ui;

void mvl_ui_init(mvl_ui *ui);
void mvl_ui_begin(mvl_ui *ui, float width, float height);
void mvl_ui_rect(mvl_ui *ui, float x, float y, float w, float h, const float color[4]);
void mvl_ui_image(mvl_ui *ui, int texture, float x, float y, float w, float h,
                  float u0, float v0, float u1, float v1, const float color[4]);
/* Draws text (handles '\n'); returns the widest line width in pixels. */
float mvl_ui_text(mvl_ui *ui, float x, float y, const char *text, float scale, const float color[4]);
float mvl_ui_text_width(const char *text, float scale);
int mvl_ui_text_lines(const char *text);
/* Word-wraps `text` to `max_width` pixels, writing into `out`. */
void mvl_ui_wrap(const char *text, float max_width, float scale, char *out, size_t out_size);

#endif
