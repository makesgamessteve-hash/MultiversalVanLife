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

/* ------------------------------------------------------------- climate */
typedef struct {
    float axis[3];      /* rotation axis (unit) */
    float sin_tilt;     /* sine of the axial tilt */
    int locked;         /* tidally locked: temperatures follow the substellar point */
    float sub[3];       /* direction of the star for locked worlds */
    float mean;         /* global mean temperature (K) */
    float span;         /* equator to pole (or day to night) difference (K) */
    float lapse;        /* cooling with height (K per km) */
    float water;        /* 0 dry world .. 1 water world (scales evaporation) */
    int iterations;     /* moisture transport steps (default 80) */
} mvl_climate_params;

/* Temperature (annual mean, coldest and warmest season, K), precipitation
 * (relative, about 1 on a wet world) and the downwind neighbour of each
 * cell. elevation: km relative to sea level (below 0 is sea). */
int mvl_planet_climate(const mvl_planet_grid *g, const float *elevation, const mvl_climate_params *p,
                       float *t_mean, float *t_min, float *t_max, float *precip, int *wind_to);

/* -------------------------------------------------------------- rivers */
/* Fills depressions (priority flood from the sea, or from the lowest cell of
 * a dry world) and routes water downhill: filled is the water surface (km),
 * flow_to the downstream neighbour (-1 at the sea or the final sink), flow
 * the water passing through (sum of upstream precipitation), lake 1 where
 * the surface lies above the ground. Along flow_to, filled never rises. */
int mvl_planet_rivers(const mvl_planet_grid *g, const float *elevation, const float *precip, float *filled,
                      int *flow_to, float *flow, uint8_t *lake);

/* ---------------------------------------------------------- territories */
/* Grows territories from seed cells over cells with cost >= 0 (cost < 0 is
 * impassable); writes the owning seed's index per cell (-1 unreached). */
int mvl_planet_territory(const mvl_planet_grid *g, const int *seeds, int nseeds, const float *cost, int *owner);

/* Connected components of cells with mask != 0: ids 0.. by first cell, -1
 * for masked-out cells. Returns the number of components. */
int mvl_planet_components(const mvl_planet_grid *g, const uint8_t *mask, int *id);

#endif
