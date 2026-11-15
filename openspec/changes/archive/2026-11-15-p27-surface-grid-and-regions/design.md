# Design

## Context

See `docs/concepts/living-planets.md`. This phase builds on p26.

## Decisions

- **Cube sphere**: each face is cut into N x N regions with N chosen so regions are about 32 km wide on the planet's radius; region index R = face x N^2 + row x N + column; a region's frame (centre, east, north) maps its lands to the sphere with seams handled at face edges.
- **Levels**: `region` becomes a child level of `planet` (caps sized to the face grid); `land` a child of `region`. Continent and country nodes stay for their facts; a land finds its country from the atlas at its position.
- **Neighbours**: `gen.neighbour_land` crosses region and face borders through the grid; the streamer keeps lands of several regions at once.
- **Compatibility**: multiverses created before the change carry a version flag; their stored lands load by their old addresses and their districts keep working; new exploration uses the grid.
- **Commitments** from planet passes target lands found through the atlas (a capital's land) instead of fixed numbers.

## Risks / Trade-offs

- [Generation time and frame rate] -> the p24 budgets, statistics and frame checks run on every push.
