/* Multiversal Van Life - small vector / matrix library. MIT License. */
#ifndef MVL_MATH_H
#define MVL_MATH_H

#define MVL_PI 3.14159265358979323846f

typedef struct { float x, y, z; } vec3;
typedef struct { float x, y, z, w; } vec4;
/* Column-major 4x4 matrix (OpenGL convention): m[col*4 + row]. */
typedef struct { float m[16]; } mat4;

float mvl_clampf(float v, float lo, float hi);
float mvl_lerpf(float a, float b, float t);
float mvl_wrap_angle(float a); /* wraps into [-pi, pi] */

vec3 v3(float x, float y, float z);
vec3 v3_add(vec3 a, vec3 b);
vec3 v3_sub(vec3 a, vec3 b);
vec3 v3_scale(vec3 a, float s);
float v3_dot(vec3 a, vec3 b);
vec3 v3_cross(vec3 a, vec3 b);
float v3_len(vec3 a);
vec3 v3_norm(vec3 a);
vec3 v3_lerp(vec3 a, vec3 b, float t);

mat4 m4_identity(void);
mat4 m4_mul(mat4 a, mat4 b);
vec4 m4_mul_v4(mat4 m, vec4 v);
vec3 m4_transform_point(mat4 m, vec3 p);
mat4 m4_translate(vec3 t);
mat4 m4_scale(vec3 s);
mat4 m4_rotate_x(float a);
mat4 m4_rotate_y(float a);
mat4 m4_rotate_z(float a);
mat4 m4_perspective(float fovy_rad, float aspect, float znear, float zfar);
mat4 m4_ortho(float l, float r, float b, float t, float n, float f);
mat4 m4_look_at(vec3 eye, vec3 center, vec3 up);
mat4 m4_transpose(mat4 m);
/* Returns 0 if the matrix is singular, 1 otherwise. */
int m4_invert(mat4 m, mat4 *out);

/* Yaw/pitch helpers. Yaw 0 looks along -Z, positive yaw turns left. */
vec3 mvl_forward(float yaw, float pitch);
vec3 mvl_right(float yaw);

#endif
