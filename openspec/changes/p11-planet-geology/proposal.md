# Proposal

Phase 11 of 24 of the procedural multiverse roadmap (see `docs/ROADMAP.md`). Depends on: p10.

## Why

Planets are where geology, climate, life and peoples meet. This phase gives every planet real physics from its star and orbit, plate tectonics that shape continents and mountains, rocks and resources, and the geography of magic.

## What Changes

- A geodesic planet grid (about 10,000 cells) and C kernels for plates, plate motion and elevation.
- Planet physics: mass, radius, gravity, composition, atmosphere, temperature range, day length, tilt, year, tidal locking.
- Geology and resources by tectonic setting and composition, including magical minerals.
- Magic geography following the universe's magic source.

## Capabilities

### New Capabilities
- `planet-generation`: Planet physics, tectonics, geology and resources, magic geography (climate, subdivision and sky follow in phases 12–13).

### Modified Capabilities
- `scripting-api`: Adds planet grid and tectonics kernels.

## Impact

- New core module `planet.c` (grid, plates, elevation), `gen/levels/planet.lua` passes, checker rules, bible sections, unit and game tests.
