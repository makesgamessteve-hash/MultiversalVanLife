# Proposal

Phase 27 of 33 of the roadmap (see `docs/ROADMAP.md` and `docs/concepts/living-planets.md`). Depends on: p26.

## Why

Only one 32 km district of each country can be visited and countries never meet, so travel cannot be continuous and most of every planet is unreachable.

## What Changes

- A planet-wide grid of 32 km regions on a cube sphere, each with 16 x 16 lands of 2 km; land addresses `planet.rR.lL`.
- Continuous lands: walking and driving cross land, region and country borders without loading screens; neighbouring lands and regions stream in from the plan.
- Region terrain at 256 m from the planet with rivers, lakes and coasts continuous across region borders.
- Countries and continents remain levels for politics, culture and history; borders are real lines on the ground.
- A version flag keeps old multiverses' visited lands and districts working; fingerprints are updated once.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `multiverse-generation`: See the requirements of this change.
- `land-streaming`: See the requirements of this change.
- `save-games`: See the requirements of this change.

## Impact

- `gen/address.lua`, `gen.lua` levels, new `gen/levels/region.lua`, `gen/levels/land.lua`, `gen/chunks.lua` neighbours, `memory/places.lua`, signals, history commitments, tests.
