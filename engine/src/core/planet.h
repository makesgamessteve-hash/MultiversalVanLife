/* Multiversal Van Life - planet kernels: a geodesic grid of cells over the
 * sphere, tectonic plates, elevation, climate, rivers and territories.
 * MIT License.
 *
 * The grid is an icosahedron subdivided `level` times; its vertices are the
 * cells (level 5: 10,242 cells about 220 km apart on an Earth-sized world).
 * All kernels are deterministic on every platform: they use integer hashing,
 * the engine's random streams and noise, and only + - * / and sqrtf. */
#ifndef MVL_PLANET_H
#define MVL_PLANET_H

#include <stdint.h>

#define MVL_PLANET_MAX_LEVEL 6
#define MVL_PLANET_MAX_PLATES 64

typedef struct {
    int level, count;
    float *pos;      /* 3 floats per cell: a point on the unit sphere */
    int *nbr_start;  /* count + 1 offsets into nbr */
    int *nbr;        /* neighbours of each cell, ascending */
    float edge;      /* mean chord length between neighbours */
} mvl_planet_grid;

/* The grid of a subdivision level (built once and kept), or NULL. */
const mvl_planet_grid *mvl_planet_grid_get(int level);
void mvl_planet_grids_free(void);

/* The cell nearest to a direction (x, y, z need not be normalised). */
int mvl_planet_nearest(const mvl_planet_grid *g, float x, float y, float z);

/* Grows `nplates` plates from seeds spread over the sphere; writes the plate
 * of every cell. Returns the number of plates. */
int mvl_planet_plates(const mvl_planet_grid *g, uint32_t seed, int nplates, int *plate);

typedef struct {
    float pole[3];   /* rotation axis of the plate's motion */
    float speed;     /* angular speed (arbitrary units) */
    int continental; /* 1 continental crust, 0 oceanic */
    float area;      /* fraction of the sphere */
} mvl_plate_info;

/* Boundary kinds per cell (the strongest boundary the cell touches). */
enum { MVL_BOUND_NONE, MVL_BOUND_CONVERGENT, MVL_BOUND_DIVERGENT, MVL_BOUND_TRANSFORM };

/* Plates, their motion and the elevation (km relative to an average ocean
 * floor of 0; continents about +4.5) they build: mountains where plates
 * collide, trenches and arcs at subduction, ridges and rifts where they part.
 * Writes plate, elevation, boundary (kind of the nearest boundary),
 * boundary_dist (distance to it, in cells) and per-plate info. */
int mvl_planet_tectonics(const mvl_planet_grid *g, uint32_t seed, int nplates, float continental_fraction,
                         int *plate, float *elevation, uint8_t *boundary, float *boundary_dist,
                         mvl_plate_info *info);

#endif
