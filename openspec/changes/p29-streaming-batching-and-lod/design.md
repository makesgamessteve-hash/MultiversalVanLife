# Design

## Context

See `docs/concepts/living-planets.md`. This phase builds on p28.

## Decisions

- **Mesh builder** (C): `mvl.mesh_builder()` appends meshes with transforms and colours into one mesh; chunks merge their static content per material.
- **Instances** (C): an entity of kind `instances` draws one mesh with an array of transforms and tints (glDrawElementsInstanced); the null renderer counts them for tests.
- **Sprite batches**: camera-facing quads expanded in the vertex shader from per-sprite centres and sizes.
- **Streamer**: a priority queue of chunks scored by distance, angle to the view direction and time-to-reach at the current velocity; budgets for entities, meshes and memory; generation sliced by time, nearest first; region and land requests issued ahead along the velocity.
- **Far ring**: per land, a low-resolution terrain mesh with building blocks, tree clusters and lit windows, generated from the land layout; swapped for chunks as they load.
- **Lights**: the 6 nearest of all lamps are real lights each frame; the rest are emissive vertex colours.

## Risks / Trade-offs

- [Generation time and frame rate] -> the p24 budgets, statistics and frame checks run on every push.
