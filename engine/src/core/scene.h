/* Multiversal Van Life - scene graph (flat entity list), camera, environment,
 * lights and simple collision. MIT License. */
#ifndef MVL_SCENE_H
#define MVL_SCENE_H

#include "core/mvl_math.h"

#define MVL_MAX_ENTITIES 2048
#define MVL_MAX_LIGHTS 8

typedef enum {
    MVL_ENT_MESH = 0,   /* OBJ or voxel mesh */
    MVL_ENT_SPRITE = 1  /* camera facing billboard (rotates around Y) */
} mvl_entity_kind;

enum {
    MVL_ENT_VISIBLE = 1 << 0,
    MVL_ENT_UNLIT = 1 << 1,   /* ignores lighting (glowing things) */
    MVL_ENT_NOFOG = 1 << 2,   /* ignores fog (sky objects) */
    MVL_ENT_SOLID = 1 << 3,   /* blocks movement (see collider) */
    MVL_ENT_DECAL = 1 << 4,   /* lies on a surface: drawn after it, never z-fights */
    MVL_ENT_PERSISTENT = 1 << 5 /* survives mvl_scene_clear_world (e.g. the van interior) */
};

typedef struct {
    int alive;
    int generation;
    mvl_entity_kind kind;
    int mesh;      /* resource id (meshes) */
    int texture;   /* resource id (0 = white) */
    unsigned flags;
    vec3 pos;
    float yaw, pitch, roll;
    vec3 scale;    /* sprites: x = width, y = height (metres) */
    float color[4];
    float uv_scroll[2];
    /* collider: axis aligned box half extents around pos (y ignored), or
     * radius > 0 for a circle collider */
    float half_x, half_z, radius;
    /* parenting: when parent != 0, pos/yaw/pitch/roll/scale are local to the
       parent. Children are destroyed with their parent and never collide. */
    int parent;
    int child_count;
    int layer;     /* decal draw order (0..7, higher on top) */
} mvl_entity;

typedef struct {
    vec3 pos;
    float color[3];
    float range;
    int enabled;
} mvl_light;

typedef struct {
    vec3 pos;
    float yaw, pitch;
    float fov_deg;
    float znear, zfar;
} mvl_camera;

typedef struct {
    float sky_top[3], sky_horizon[3];
    float fog_color[3];
    float fog_near, fog_far;
    float ambient[3];
    vec3 sun_dir;          /* direction the light travels */
    float sun_color[3];
    float stars;           /* 0..1 star visibility */
} mvl_environment;

#define MVL_MAX_PORTALS 8

/* A window into another part of the scene: the rectangle (centre pos, facing
 * forward(yaw), w x h metres) shows what lies beyond the target frame. */
typedef struct {
    int enabled;
    vec3 pos;
    float yaw, w, h;
    vec3 target_pos;
    float target_yaw;
} mvl_portal;

typedef struct {
    mvl_entity entities[MVL_MAX_ENTITIES];
    mvl_portal portals[MVL_MAX_PORTALS];
    int high_water;        /* one past the highest used slot */
    mvl_light lights[MVL_MAX_LIGHTS];
    mvl_camera camera;
    mvl_environment env;
    float bounds_min[2], bounds_max[2]; /* walkable x/z area */
} mvl_scene;

void mvl_scene_init(mvl_scene *s);
/* Removes all entities and lights; keeps camera. */
void mvl_scene_clear(mvl_scene *s);
/* Removes all entities except PERSISTENT ones (and their children); lights,
 * portals and the camera are kept. */
void mvl_scene_clear_world(mvl_scene *s);

/* Colliders only block movers whose height is within this distance, so
 * places stacked far above each other (the van pocket) do not interfere. */
#define MVL_COLLIDE_HEIGHT 6.0f
void mvl_env_default(mvl_environment *e);

/* Entity handles encode slot + generation so stale handles are detected. */
int mvl_scene_spawn(mvl_scene *s, mvl_entity_kind kind);
mvl_entity *mvl_scene_get(mvl_scene *s, int handle);
int mvl_scene_destroy(mvl_scene *s, int handle);
int mvl_scene_count(const mvl_scene *s);

mat4 mvl_entity_model_matrix(const mvl_entity *e);

#define MVL_MAX_PARENT_DEPTH 8
/* Attaches child to parent (0 detaches). The child's current transform
 * becomes its local transform. Fails for cycles, invalid handles or a
 * hierarchy deeper than MVL_MAX_PARENT_DEPTH. Returns 1 on success. */
int mvl_scene_attach(mvl_scene *s, int child, int parent);
/* Local transform composed with all ancestors. */
mat4 mvl_scene_world_matrix(mvl_scene *s, const mvl_entity *e);
vec3 mvl_scene_world_pos(mvl_scene *s, const mvl_entity *e);
/* Maps points around the portal to the corresponding points around its target. */
mat4 mvl_portal_matrix(const mvl_portal *p);
/* Model matrix of the portal rectangle for a unit quad (-0.5..0.5 in x and y). */
mat4 mvl_portal_quad_matrix(const mvl_portal *p);
/* 1 if `eye` is on the side the portal is looked through from. */
int mvl_portal_faces(const mvl_portal *p, vec3 eye);
/* View and projection for drawing what the portal shows: the target region
 * seen from the virtual eye, with everything between the virtual eye and the
 * target plane clipped away (oblique near plane). */
void mvl_portal_view(const mvl_portal *p, mat4 view, mat4 proj, mat4 *out_view, mat4 *out_proj);
mat4 mvl_camera_view(const mvl_camera *c);
mat4 mvl_camera_proj(const mvl_camera *c, float aspect);

/* Moves a circle of `radius` from `pos` by `delta` on the XZ plane, sliding
 * along SOLID entity colliders at a similar height (see MVL_COLLIDE_HEIGHT)
 * and the scene bounds. Returns the new pos. */
vec3 mvl_scene_move(const mvl_scene *s, vec3 pos, vec3 delta, float radius);
/* 1 if a circle at pos overlaps any SOLID collider. */
int mvl_scene_overlaps(const mvl_scene *s, vec3 pos, float radius);

#endif
