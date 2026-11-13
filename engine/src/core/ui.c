/* Multiversal Van Life - immediate mode 2D UI draw list. MIT License. */
#include "core/ui.h"
#include <string.h>

static const float WHITE[4] = {1, 1, 1, 1};

void mvl_ui_init(mvl_ui *ui) { memset(ui, 0, sizeof *ui); }

void mvl_ui_begin(mvl_ui *ui, float width, float height) {
    ui->count = 0;
    ui->width = width;
    ui->height = height;
}

void mvl_ui_image(mvl_ui *ui, int texture, float x, float y, float w, float h,
                  float u0, float v0, float u1, float v1, const float color[4]) {
    mvl_ui_quad *q;
    if (ui->count >= MVL_UI_MAX_QUADS) return;
    q = &ui->quads[ui->count++];
    q->x = x;
    q->y = y;
    q->w = w;
    q->h = h;
    q->u0 = u0;
    q->v0 = v0;
    q->u1 = u1;
    q->v1 = v1;
    memcpy(q->color, color ? color : WHITE, sizeof q->color);
    q->texture = texture;
}

void mvl_ui_rect(mvl_ui *ui, float x, float y, float w, float h, const float color[4]) {
    mvl_ui_image(ui, 0, x, y, w, h, 0, 0, 1, 1, color);
}

float mvl_ui_text(mvl_ui *ui, float x, float y, const char *text, float scale, const float color[4]) {
    float cx = x, cy = y, widest = 0.0f;
    const float cw = 1.0f / 16.0f, ch = 1.0f / 6.0f;
    if (!text) return 0.0f;
    for (const unsigned char *p = (const unsigned char *)text; *p; ++p) {
        int c = *p;
        if (c == '\n') {
            if (cx - x > widest) widest = cx - x;
            cx = x;
            cy += MVL_FONT_LINE * scale;
            continue;
        }
        if (c < 32 || c > 127) c = '?';
        if (c != ' ') {
            int idx = c - 32, col = idx % 16, row = idx / 16;
            mvl_ui_image(ui, ui->font_texture, cx, cy, MVL_FONT_CELL * scale, MVL_FONT_CELL * scale,
                         col * cw, row * ch, (col + 1) * cw, (row + 1) * ch, color);
        }
        cx += MVL_FONT_ADVANCE * scale;
    }
    if (cx - x > widest) widest = cx - x;
    return widest;
}

float mvl_ui_text_width(const char *text, float scale) {
    float w = 0.0f, line = 0.0f;
    if (!text) return 0.0f;
    for (const char *p = text; *p; ++p) {
        if (*p == '\n') {
            if (line > w) w = line;
            line = 0.0f;
        } else {
            line += MVL_FONT_ADVANCE * scale;
        }
    }
    return line > w ? line : w;
}

int mvl_ui_text_lines(const char *text) {
    int n = 1;
    if (!text || !*text) return 0;
    for (const char *p = text; *p; ++p) n += *p == '\n';
    return n;
}

void mvl_ui_wrap(const char *text, float max_width, float scale, char *out, size_t out_size) {
    size_t o = 0;
    int max_chars = (int)(max_width / (MVL_FONT_ADVANCE * scale));
    int col = 0;
    const char *p = text;
    if (out_size == 0) return;
    if (max_chars < 1) max_chars = 1;
    while (p && *p && o + 1 < out_size) {
        const char *w = p;
        int len = 0;
        if (*p == '\n') {
            out[o++] = '\n';
            col = 0;
            ++p;
            continue;
        }
        if (*p == ' ') {
            if (col > 0 && col < max_chars && out[o - 1] != ' ') {
                out[o++] = ' ';
                ++col;
            }
            ++p;
            continue;
        }
        while (w[len] && w[len] != ' ' && w[len] != '\n') ++len;
        if (col > 0 && col + len > max_chars) {
            if (o > 0 && out[o - 1] == ' ') --o;
            out[o++] = '\n';
            col = 0;
        }
        while (len > 0 && o + 1 < out_size) {
            if (col >= max_chars) {
                out[o++] = '\n';
                col = 0;
                if (o + 1 >= out_size) break;
            }
            out[o++] = *p++;
            --len;
            ++col;
        }
        if (len > 0) break;
    }
    out[o] = 0;
}
