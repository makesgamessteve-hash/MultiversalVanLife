# Proposal

Phase 25 of 33 of the roadmap (see `docs/ROADMAP.md` and `docs/concepts/living-planets.md`). Depends on: p24.

## Why

Generated houses are 4-5 m wide with 2.75 m storeys and every building is capped at 8 x 8 x 5 m, so next to the player's 1.6 m eye height villages look like sheds.

## What Changes

- Buildings planned in metres from the size of the people who live in them, then voxelised at 0.125 m.
- Storeys of 1.75 x the people's height (at least 3 m), doors of 1.25 x their height, footprints by building kind (cottage, village house, farmhouse and barn, town house, inn, hall, workshop, temple).
- Model grids up to 24 x 24 x 16 m; larger buildings from several modules.
- Settlements spaced for the bigger buildings; villagers and the player walk through doors.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `procedural-visuals`: See the requirements of this change.

## Impact

- `gen/visuals/buildings.lua`, `gen/culture/architecture.lua`, `gen/levels/provisional.lua`, `gen/levels/land.lua`, model cache, GL galleries.
