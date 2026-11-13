# scripting-api Specification

## Purpose
Gameplay is written in Lua 5.4. The engine exposes a single `mvl` table for resources, entities, camera, environment, collision, input, audio, UI, configuration and saves, and calls hooks on the global `game` table.

## Requirements

### Requirement: Game hooks
The engine SHALL call `game.init()` once after loading `engine.main_script`, `game.update(dt)` every fixed tick, `game.draw_ui()` every frame and `game.shutdown()` on exit, skipping hooks that are not defined.

#### Scenario: Missing main script
- **WHEN** the configured main script does not exist
- **THEN** engine initialisation fails with a message naming the script

### Requirement: Module loading through the data folders
`require` SHALL resolve module names to `scripts/<name with dots as slashes>.lua` through the virtual file system, and `dofile` SHALL read from the data folders.

#### Scenario: Requiring a library
- **WHEN** a script calls `require("lib.player")`
- **THEN** `scripts/lib/player.lua` is loaded from the highest priority data root

### Requirement: Sandbox
The Lua environment SHALL NOT expose the `io` library, `loadfile` or the process-control and file functions of `os` (`execute`, `exit`, `remove`, `rename`, `tmpname`, `getenv`, `setlocale`).

#### Scenario: Mod tries to run a command
- **WHEN** a script calls `os.execute`
- **THEN** the call fails because the function does not exist

### Requirement: Entity API
Scripts SHALL be able to spawn mesh and sprite entities with a table of properties (mesh, texture, position, yaw/pitch/roll, scale, colour, UV scrolling, visibility, unlit, no-fog, solid with box or radius collider), update, query and destroy them, using handles that become invalid after destruction.

#### Scenario: Stale handle
- **WHEN** a script uses the handle of a destroyed entity
- **THEN** getters return nothing and setters have no effect

### Requirement: Collision helper
`mvl.move(x, y, z, dx, dz, radius)` SHALL move a circle on the ground plane, sliding along solid box and circle colliders and staying inside the world bounds.

#### Scenario: Walking into a wall
- **WHEN** the player moves into a solid box collider
- **THEN** the returned position is pushed out of the box

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

### Requirement: Portal and decal API
Scripts SHALL be able to define portals (a rectangle in the scene and the transform it looks through), switch them off, and mark entities as decals with a layer.

#### Scenario: Disabling a portal
- **WHEN** a script switches a portal off
- **THEN** the renderer no longer draws its linked view

### Requirement: Persistent place storage
Scripts SHALL be able to read and write structured data records (tables of numbers, strings, booleans and nested tables) by name in the save folder.

#### Scenario: Record round trip
- **WHEN** a script stores a nested table and loads it again after a restart
- **THEN** the loaded table equals the stored one

### Requirement: Planet grid and tectonics kernels
Scripts SHALL have fast engine functions to build a geodesic planet grid, seed and grow tectonic plates, classify plate boundaries and compute elevation, returning deterministic data that scripts can read and store.

#### Scenario: Plates from a kernel
- **WHEN** a script runs the plate kernel with a seed on a planet grid
- **THEN** it receives a plate id per cell and boundary types per edge, identical on every platform

### Requirement: Climate, river and territory kernels
Scripts SHALL have fast engine functions for climate fields (temperature, wind, moisture with rain shadow), river networks (flow direction, accumulation, lakes) and territory growth on region graphs, returning deterministic data.

#### Scenario: Rivers from a kernel
- **WHEN** a script runs the river kernel on an elevation grid
- **THEN** it receives river paths and flow amounts it can store in the planet description
