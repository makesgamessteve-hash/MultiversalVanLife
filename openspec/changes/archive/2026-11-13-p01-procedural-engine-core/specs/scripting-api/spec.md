# Spec Delta

## ADDED Requirements

### Requirement: Deterministic procedural helpers
Scripts SHALL have deterministic integer hashing, a seedable random generator and smooth 2D and 3D noise functions whose results are identical on every platform for the same inputs.

#### Scenario: Cross-platform determinism
- **WHEN** the same hash, random or noise call is made on Windows, Linux, macOS and the web
- **THEN** the results are identical

### Requirement: Terrain API
Scripts SHALL be able to configure a terrain height function (seed, shape, a coarse elevation map to follow, flat areas), query the height at any point, and build a terrain chunk mesh with palette colours for a given chunk.

#### Scenario: Height query matches the mesh
- **WHEN** a script queries the height at a vertex position of a built chunk
- **THEN** the returned height equals the mesh's height at that vertex

#### Scenario: No cracks
- **WHEN** two neighbouring chunks are built
- **THEN** the vertices on their shared border are identical

### Requirement: Runtime voxel models and textures
Scripts SHALL be able to fill voxel grids with shapes and colours, build meshes from them and generate textures from parameters.

#### Scenario: Building a creature
- **WHEN** a script fills a voxel grid with a body and builds a mesh
- **THEN** the mesh can be spawned like a loaded `.vox` model

### Requirement: Entity parenting
Scripts SHALL be able to attach entities to a parent entity with a local transform, so composite models (limbs, wings, carried items) move with their parent and are destroyed with it.

#### Scenario: Moving parent
- **WHEN** a parent entity moves or turns
- **THEN** its children move and turn with it

### Requirement: Releasing resources
Scripts SHALL be able to release meshes and textures they created at runtime; a released id SHALL become invalid and its slot reusable.

#### Scenario: Long walk
- **WHEN** a script builds and releases thousands of meshes over time
- **THEN** mesh creation keeps succeeding
