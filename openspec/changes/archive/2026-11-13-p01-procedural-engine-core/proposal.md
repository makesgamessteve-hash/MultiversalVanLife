# Proposal

Phase 1 of 24 of the procedural multiverse roadmap (see `docs/ROADMAP.md`). Depends on: nothing.

## Why

Every later phase (terrain streaming, cosmos generation, generated creatures and buildings) needs deterministic randomness, terrain meshes, runtime voxel models and textures, composite entities and resources that can be freed. These are engine-core features and must exist, tested, before any generation work starts.

## What Changes

- Deterministic 32-bit hashing, a seedable random stream and 2D/3D value noise with fBm, identical on every platform.
- A terrain height function (seed, shape, optional coarse elevation map, flat areas) and a chunk mesh builder with shared borders and palette colours.
- Releasable, reusable mesh and texture slots.
- Entity parenting with local transforms.
- A voxel grid API to build voxel models at runtime.
- Procedural textures generated from parameters.
- Lua bindings for all of the above. The game itself does not change yet.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `scripting-api`: Adds deterministic procedural helpers, the terrain API, runtime voxel models and textures, entity parenting and resource release.

## Impact

- `engine/src/core`: new `noise`, `terrain`, `voxgrid`, `texgen` modules; changes to `resources`, `scene`, `script`.
- Core compile flags: `-ffp-contract=off` (GCC/Clang), `/fp:precise` (MSVC).
- Unit tests; coverage must stay ≥ 95%.
