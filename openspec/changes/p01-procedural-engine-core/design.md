# Design

## Context

The core (`engine/src/core`) has no randomness or noise, only file-based voxel meshes, fixed resource tables that are never freed and a flat entity list without hierarchy. It must stay free of SDL/OpenGL with ≥ 95% line coverage.

## Goals / Non-Goals

**Goals:** bit-identical results on all platforms; fast enough for the web; small, testable APIs.
**Non-Goals:** using the features in gameplay (later phases), erosion or caves.

## Decisions

- **Hash and random**: a 32-bit integer hash (xxHash32-style avalanche) for seeds; PCG32 for random streams. Integers only, so determinism does not depend on floats.
- **Noise**: value noise on an integer lattice with quintic interpolation, fBm with octave/lacunarity/gain. Floats only in add/mul; the core is compiled with `-ffp-contract=off` / `/fp:precise` so FMA contraction cannot change results. Reference values in unit tests catch platform drift.
- **Terrain**: `height(x, z) = base + amp · fbm(...)`, optionally added to a bicubically sampled coarse elevation map, then blended towards up to 16 flat areas (centre, radius, falloff, target height). Chunks are grids (default 32 m, 16×16 cells) whose border vertices are computed from the same function, so neighbours match exactly; normals use central differences of the height function, not of the mesh, so they also match across borders. Vertex colours come from a palette indexed by height, slope and a noise term.
- **Releasable slots**: resource tables keep a free list; released slots are reused, the cache key is cleared and the GPU handle destroyed through the backend.
- **Parenting**: entities get `parent` and local transform fields; world matrices are composed when drawing (depth limited to 8); destroying a parent destroys its children.
- **Voxel grid**: a heap grid (≤ 128³) with fill operations (box, sphere, ellipsoid, cylinder, line), mirroring, palette painting and meshing through the existing `.vox` mesher.
- **Textures**: 32×32 or 64×64 RGBA generated from a recipe (noise type, palette, scale, cracks/veins/stripes), tileable by sampling noise on a torus.

## Risks / Trade-offs

- [Float determinism on WebAssembly] → same flags apply; CI compares reference values on every platform.
- [Coverage] → every new module gets unit tests in this phase.
