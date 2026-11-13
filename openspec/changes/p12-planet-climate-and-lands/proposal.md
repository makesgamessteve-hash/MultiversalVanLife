# Proposal

Phase 12 of 24 of the procedural multiverse roadmap (see `docs/ROADMAP.md`). Depends on: p11.

## Why

Climate, water and biomes decide where life and peoples can live, and the walkable lands must look like the planet they belong to.

## What Changes

- Climate (temperature, winds, precipitation, seasons, rain shadows), rivers and lakes, and biomes per cell.
- Subdivision into continents, provisional countries and lands of a few square kilometres.
- Land terrain follows the planet's elevation, rivers, coasts and biomes; the provisional land styles of phase 9 are replaced by real biomes.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `planet-generation`: Adds climate, rivers and lakes, biomes and subdivision.
- `land-streaming`: Adds terrain that follows the planet.
- `scripting-api`: Adds climate, river and territory kernels.

## Impact

- `planet.c` kernels, planet and continent/country/land passes, land terrain sampling, river water surfaces, game and GL tests.
