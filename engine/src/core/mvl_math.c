/* Multiversal Van Life - small vector / matrix library. MIT License. */
#include "core/mvl_math.h"
#include <math.h>
#include <string.h>

float mvl_clampf(float v, float lo, float hi) { return v < lo ? lo : (v > hi ? hi : v); }
float mvl_lerpf(float a, float b, float t) { return a + (b - a) * t; }

float mvl_wrap_angle(float a) {
    while (a > MVL_PI) a -= 2.0f * MVL_PI;
    while (a < -MVL_PI) a += 2.0f * MVL_PI;
    return a;
}

vec3 v3(float x, float y, float z) { vec3 r = {x, y, z}; return r; }
vec3 v3_add(vec3 a, vec3 b) { return v3(a.x + b.x, a.y + b.y, a.z + b.z); }
vec3 v3_sub(vec3 a, vec3 b) { return v3(a.x - b.x, a.y - b.y, a.z - b.z); }
vec3 v3_scale(vec3 a, float s) { return v3(a.x * s, a.y * s, a.z * s); }
float v3_dot(vec3 a, vec3 b) { return a.x * b.x + a.y * b.y + a.z * b.z; }
vec3 v3_cross(vec3 a, vec3 b) {
    return v3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x);
}
float v3_len(vec3 a) { return sqrtf(v3_dot(a, a)); }
vec3 v3_norm(vec3 a) {
    float l = v3_len(a);
    return l > 1e-8f ? v3_scale(a, 1.0f / l) : v3(0, 0, 0);
}
vec3 v3_lerp(vec3 a, vec3 b, float t) {
    return v3(mvl_lerpf(a.x, b.x, t), mvl_lerpf(a.y, b.y, t), mvl_lerpf(a.z, b.z, t));
}

mat4 m4_identity(void) {
    mat4 r;
    memset(&r, 0, sizeof r);
    r.m[0] = r.m[5] = r.m[10] = r.m[15] = 1.0f;
    return r;
}

mat4 m4_mul(mat4 a, mat4 b) {
    mat4 r;
    for (int c = 0; c < 4; ++c)
        for (int row = 0; row < 4; ++row) {
            float s = 0.0f;
            for (int k = 0; k < 4; ++k) s += a.m[k * 4 + row] * b.m[c * 4 + k];
            r.m[c * 4 + row] = s;
        }
    return r;
}

vec4 m4_mul_v4(mat4 m, vec4 v) {
    vec4 r;
    r.x = m.m[0] * v.x + m.m[4] * v.y + m.m[8] * v.z + m.m[12] * v.w;
    r.y = m.m[1] * v.x + m.m[5] * v.y + m.m[9] * v.z + m.m[13] * v.w;
    r.z = m.m[2] * v.x + m.m[6] * v.y + m.m[10] * v.z + m.m[14] * v.w;
    r.w = m.m[3] * v.x + m.m[7] * v.y + m.m[11] * v.z + m.m[15] * v.w;
    return r;
}

vec3 m4_transform_point(mat4 m, vec3 p) {
    vec4 v = {p.x, p.y, p.z, 1.0f};
    vec4 r = m4_mul_v4(m, v);
    if (r.w != 0.0f && r.w != 1.0f) return v3(r.x / r.w, r.y / r.w, r.z / r.w);
    return v3(r.x, r.y, r.z);
}

mat4 m4_translate(vec3 t) {
    mat4 r = m4_identity();
    r.m[12] = t.x; r.m[13] = t.y; r.m[14] = t.z;
    return r;
}

mat4 m4_scale(vec3 s) {
    mat4 r = m4_identity();
    r.m[0] = s.x; r.m[5] = s.y; r.m[10] = s.z;
    return r;
}

mat4 m4_rotate_x(float a) {
    mat4 r = m4_identity();
    float c = cosf(a), s = sinf(a);
    r.m[5] = c; r.m[6] = s; r.m[9] = -s; r.m[10] = c;
    return r;
}

mat4 m4_rotate_y(float a) {
    mat4 r = m4_identity();
    float c = cosf(a), s = sinf(a);
    r.m[0] = c; r.m[2] = -s; r.m[8] = s; r.m[10] = c;
    return r;
}

mat4 m4_rotate_z(float a) {
    mat4 r = m4_identity();
    float c = cosf(a), s = sinf(a);
    r.m[0] = c; r.m[1] = s; r.m[4] = -s; r.m[5] = c;
    return r;
}

mat4 m4_perspective(float fovy, float aspect, float n, float f) {
    mat4 r;
    float t = 1.0f / tanf(fovy * 0.5f);
    memset(&r, 0, sizeof r);
    r.m[0] = t / aspect;
    r.m[5] = t;
    r.m[10] = (f + n) / (n - f);
    r.m[11] = -1.0f;
    r.m[14] = (2.0f * f * n) / (n - f);
    return r;
}

mat4 m4_ortho(float l, float r_, float b, float t, float n, float f) {
    mat4 r = m4_identity();
    r.m[0] = 2.0f / (r_ - l);
    r.m[5] = 2.0f / (t - b);
    r.m[10] = -2.0f / (f - n);
    r.m[12] = -(r_ + l) / (r_ - l);
    r.m[13] = -(t + b) / (t - b);
    r.m[14] = -(f + n) / (f - n);
    return r;
}

mat4 m4_look_at(vec3 eye, vec3 center, vec3 up) {
    vec3 f = v3_norm(v3_sub(center, eye));
    vec3 s = v3_norm(v3_cross(f, up));
    vec3 u = v3_cross(s, f);
    mat4 r = m4_identity();
    r.m[0] = s.x; r.m[4] = s.y; r.m[8] = s.z;
    r.m[1] = u.x; r.m[5] = u.y; r.m[9] = u.z;
    r.m[2] = -f.x; r.m[6] = -f.y; r.m[10] = -f.z;
    r.m[12] = -v3_dot(s, eye);
    r.m[13] = -v3_dot(u, eye);
    r.m[14] = v3_dot(f, eye);
    return r;
}

mat4 m4_transpose(mat4 m) {
    mat4 r;
    for (int c = 0; c < 4; ++c)
        for (int row = 0; row < 4; ++row) r.m[c * 4 + row] = m.m[row * 4 + c];
    return r;
}

int m4_invert(mat4 mat, mat4 *out) {
    const float *m = mat.m;
    float inv[16], det;
    inv[0] = m[5]*m[10]*m[15] - m[5]*m[11]*m[14] - m[9]*m[6]*m[15] + m[9]*m[7]*m[14] + m[13]*m[6]*m[11] - m[13]*m[7]*m[10];
    inv[4] = -m[4]*m[10]*m[15] + m[4]*m[11]*m[14] + m[8]*m[6]*m[15] - m[8]*m[7]*m[14] - m[12]*m[6]*m[11] + m[12]*m[7]*m[10];
    inv[8] = m[4]*m[9]*m[15] - m[4]*m[11]*m[13] - m[8]*m[5]*m[15] + m[8]*m[7]*m[13] + m[12]*m[5]*m[11] - m[12]*m[7]*m[9];
    inv[12] = -m[4]*m[9]*m[14] + m[4]*m[10]*m[13] + m[8]*m[5]*m[14] - m[8]*m[6]*m[13] - m[12]*m[5]*m[10] + m[12]*m[6]*m[9];
    inv[1] = -m[1]*m[10]*m[15] + m[1]*m[11]*m[14] + m[9]*m[2]*m[15] - m[9]*m[3]*m[14] - m[13]*m[2]*m[11] + m[13]*m[3]*m[10];
    inv[5] = m[0]*m[10]*m[15] - m[0]*m[11]*m[14] - m[8]*m[2]*m[15] + m[8]*m[3]*m[14] + m[12]*m[2]*m[11] - m[12]*m[3]*m[10];
    inv[9] = -m[0]*m[9]*m[15] + m[0]*m[11]*m[13] + m[8]*m[1]*m[15] - m[8]*m[3]*m[13] - m[12]*m[1]*m[11] + m[12]*m[3]*m[9];
    inv[13] = m[0]*m[9]*m[14] - m[0]*m[10]*m[13] - m[8]*m[1]*m[14] + m[8]*m[2]*m[13] + m[12]*m[1]*m[10] - m[12]*m[2]*m[9];
    inv[2] = m[1]*m[6]*m[15] - m[1]*m[7]*m[14] - m[5]*m[2]*m[15] + m[5]*m[3]*m[14] + m[13]*m[2]*m[7] - m[13]*m[3]*m[6];
    inv[6] = -m[0]*m[6]*m[15] + m[0]*m[7]*m[14] + m[4]*m[2]*m[15] - m[4]*m[3]*m[14] - m[12]*m[2]*m[7] + m[12]*m[3]*m[6];
    inv[10] = m[0]*m[5]*m[15] - m[0]*m[7]*m[13] - m[4]*m[1]*m[15] + m[4]*m[3]*m[13] + m[12]*m[1]*m[7] - m[12]*m[3]*m[5];
    inv[14] = -m[0]*m[5]*m[14] + m[0]*m[6]*m[13] + m[4]*m[1]*m[14] - m[4]*m[2]*m[13] - m[12]*m[1]*m[6] + m[12]*m[2]*m[5];
    inv[3] = -m[1]*m[6]*m[11] + m[1]*m[7]*m[10] + m[5]*m[2]*m[11] - m[5]*m[3]*m[10] - m[9]*m[2]*m[7] + m[9]*m[3]*m[6];
    inv[7] = m[0]*m[6]*m[11] - m[0]*m[7]*m[10] - m[4]*m[2]*m[11] + m[4]*m[3]*m[10] + m[8]*m[2]*m[7] - m[8]*m[3]*m[6];
    inv[11] = -m[0]*m[5]*m[11] + m[0]*m[7]*m[9] + m[4]*m[1]*m[11] - m[4]*m[3]*m[9] - m[8]*m[1]*m[7] + m[8]*m[3]*m[5];
    inv[15] = m[0]*m[5]*m[10] - m[0]*m[6]*m[9] - m[4]*m[1]*m[10] + m[4]*m[2]*m[9] + m[8]*m[1]*m[6] - m[8]*m[2]*m[5];
    det = m[0] * inv[0] + m[1] * inv[4] + m[2] * inv[8] + m[3] * inv[12];
    if (fabsf(det) < 1e-12f) return 0;
    det = 1.0f / det;
    for (int i = 0; i < 16; ++i) out->m[i] = inv[i] * det;
    return 1;
}

vec3 mvl_forward(float yaw, float pitch) {
    float cp = cosf(pitch);
    return v3(-sinf(yaw) * cp, sinf(pitch), -cosf(yaw) * cp);
}

vec3 mvl_right(float yaw) { return v3(cosf(yaw), 0.0f, -sinf(yaw)); }
