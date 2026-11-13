# Spec Delta

## ADDED Requirements

### Requirement: Deterministic procedural helpers
Scripts SHALL have deterministic integer hashing, a seedable random generator and smooth 2D and 3D noise functions whose results are identical on every platform for the same inputs.

#### Scenario: Cross-platform determinism
- **WHEN** the same hash, random or noise call is made on Windows, Linux, macOS and the web
- **THEN** the results are identical

### Requirement: Generation kernels
Scripts SHALL have fast engine functions for the numeric parts of generation: planet grids on a sphere, tectonic plate simulation, climate fields, river networks, territory growth on region graphs and spatial point distributions; results SHALL be deterministic data that scripts can read.

#### Scenario: Rivers from a kernel
- **WHEN** a script runs the river kernel on an elevation grid
- **THEN** it receives river paths and flow amounts it can store in the planet description

### Requirement: Terrain API
Scripts SHALL be able to configure a terrain height function (seed, shape, a coarse elevation map to follow, flat areas), query the height at any point, and build a terrain chunk mesh with biome colours for a given chunk.

#### Scenario: Height query matches the mesh
- **WHEN** a script queries the height at a vertex position of a built chunk
- **THEN** the returned height equals the mesh's height at that vertex

### Requirement: Runtime voxel models and textures
Scripts SHALL be able to fill voxel grids, build meshes from them, generate textures from parameters and release both when no longer needed.

#### Scenario: Building a creature
- **WHEN** a script fills a voxel grid with a creature body and builds a mesh
- **THEN** the mesh can be spawned like a loaded `.vox` model

### Requirement: Entity parenting
Scripts SHALL be able to attach entities to a parent entity with a local transform, so composite models (limbs, wings, carried items) move with their parent.

#### Scenario: Moving parent
- **WHEN** a parent entity moves or turns
- **THEN** its children move and turn with it

### Requirement: Releasing resources
Scripts SHALL be able to release meshes and textures they created at runtime; a released id SHALL become invalid and its slot reusable.

#### Scenario: Long walk
- **WHEN** a script builds and releases thousands of meshes over time
- **THEN** mesh creation keeps succeeding

### Requirement: Portal and decal API
Scripts SHALL be able to define portals (a rectangle in the scene and the transform it looks through), switch them off, and mark entities as decals with a layer.

#### Scenario: Disabling a portal
- **WHEN** a script switches a portal off
- **THEN** the renderer no longer draws its linked view

### Requirement: Persistent place storage
Scripts SHALL be able to read and write structured data records (tables of numbers, strings, booleans and nested tables) per place in the save folder; records SHALL be written atomically and loaded without executing code.

#### Scenario: Record round trip
- **WHEN** a script stores a nested table for a land and loads it again after a restart
- **THEN** the loaded table equals the stored one

#### Scenario: Data, not code
- **WHEN** a record file is edited to contain a function call
- **THEN** loading it fails safely without running the call
