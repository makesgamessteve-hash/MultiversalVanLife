# Proposal

Phase 26 of 33 of the roadmap (see `docs/ROADMAP.md` and `docs/concepts/living-planets.md`). Depends on: p25.

## Why

Planets are planned per cell for nature only: nothing tells where people live, how many, what they grow or where their roads run, so no place on the ground can be part of a larger plan.

## What Changes

- Per-cell fertility, population density, urbanisation and land use from climate, soil, water, culture, technology, history and tensions.
- Settlement seeds per cell (cities and towns with positions, ranks, founding eras) and trade routes between them, across borders and seas (ports and sea lanes).
- Plan queries: what is at any latitude and longitude (country, culture, biome, population, land use, nearest settlements and routes) without generating lands.
- Bible sections and variety statistics for the atlas.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `planet-generation`: See the requirements of this change.

## Impact

- `gen/levels/planet.lua`, new `gen/plan/atlas.lua` and `gen/plan/query.lua`, bible, `gen/stats.lua`, tests.
