# Tasks

## 1. Randomness and noise

- [x] 1.1 Add `noise.c/.h` (hash, PCG32 streams, value noise 2D/3D, fBm) and the deterministic compile flags; verify unit tests against stored reference values

## 2. Terrain

- [x] 2.1 Add the terrain height function with coarse elevation map sampling and flat areas, and the chunk mesh builder; verify unit tests that borders of neighbouring chunks match exactly and heights equal the height query

## 3. Resources and entities

- [x] 3.1 Make mesh and texture slots releasable and reusable; verify a unit test that creates and releases 10,000 of each
- [x] 3.2 Add entity parenting with local transforms and cascading destroy; verify unit tests for composed transforms and lifetime

## 4. Runtime models and textures

- [x] 4.1 Add the voxel grid API (allocate, fill shapes, mirror, paint, mesh); verify unit tests for shape volumes and face counts
- [x] 4.2 Add procedural texture generation from recipes; verify unit tests for determinism and seamless tiling

## 5. Lua bindings

- [x] 5.1 Expose `mvl.hash`, `mvl.rng`, `mvl.noise`, `mvl.terrain`, `mvl.height`, `mvl.terrain_chunk`, `mvl.release_mesh`, `mvl.release_texture`, `mvl.attach`, `mvl.voxels`, `mvl.texture_gen`; verify engine API unit tests, existing game tests and `ninja coverage` ≥ 95%
- [x] 5.2 Document the new API in `docs/MODDING.md`; verify the documented examples run in a game test
