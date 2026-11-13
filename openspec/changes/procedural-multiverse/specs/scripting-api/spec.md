# Spec Delta

## ADDED Requirements

### Requirement: Deterministic procedural helpers
Scripts SHALL have deterministic integer hashing and smooth 2D noise functions whose results are identical on every platform for the same inputs.

#### Scenario: Cross-platform determinism
- **WHEN** the same hash or noise call is made on Windows, Linux, macOS and the web
- **THEN** the results are identical

### Requirement: Terrain API
Scripts SHALL be able to configure a terrain height function (seed, shape, flat areas), query the height at any point, and build a terrain chunk mesh with biome colours for a given chunk.

#### Scenario: Height query matches the mesh
- **WHEN** a script queries the height at a vertex position of a built chunk
- **THEN** the returned height equals the mesh's height at that vertex

### Requirement: Releasing meshes
Scripts SHALL be able to release meshes they built at runtime so that streaming worlds do not exhaust mesh slots; a released id SHALL become invalid and its slot reusable.

#### Scenario: Long walk
- **WHEN** a script builds and releases thousands of chunk meshes over time
- **THEN** mesh creation keeps succeeding

### Requirement: Portal and decal API
Scripts SHALL be able to define portals (a rectangle in the scene and the transform it looks through), switch them off, and mark entities as decals with a layer.

#### Scenario: Disabling a portal
- **WHEN** a script switches a portal off
- **THEN** the renderer no longer draws its linked view
