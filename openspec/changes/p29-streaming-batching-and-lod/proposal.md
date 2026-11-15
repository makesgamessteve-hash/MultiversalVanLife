# Proposal

Phase 29 of 33 of the roadmap (see `docs/ROADMAP.md` and `docs/concepts/living-planets.md`). Depends on: p28.

## Why

Dense places and continuous, fast travel exceed what the engine can draw (2,048 entities, one draw call each) and what the streamer loads (a fixed 7 x 7 chunks, one per tick).

## What Changes

- Streaming on demand: chunks prioritised by distance, view direction and travel speed, a long corridor ahead while driving, resident budgets per device with least recently used release, time-sliced generation, lands and region plans generated ahead along the predicted path.
- Static batching: a chunk's static objects merged into a few meshes per material.
- Instancing for repeated meshes (plants, crops, props) on GL 3.3 and WebGL2.
- Sprite batches for crowds and small plants.
- A far ring of low-detail land impostors to 2-4 km, and per-frame selection of the 6 nearest lights.
- Full density on every device.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `rendering`: See the requirements of this change.
- `land-streaming`: See the requirements of this change.
- `engine-core`: See the requirements of this change.

## Impact

- `engine/src/core` (mesh builder, instance buffers, scene), `engine/src/platform/renderer.c`, `gen/chunks.lua`, `lib/world.lua`, unit tests, GL tests, web smoke.
