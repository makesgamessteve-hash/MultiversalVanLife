# Proposal

Phase 18 of 24 of the procedural multiverse roadmap (see `docs/ROADMAP.md`). Depends on: p17.

## Why

Settlements still use hand-made voxel buildings and villagers are tinted sprites. Each culture's buildings, dress and people should look like the result of their land, body, beliefs and technology.

## What Changes

- Architecture styles and dress derived from geology, climate, anatomy, religion and technology.
- Voxel buildings (houses, workshops, temples, walls, wells, monuments) from a floor-plan grammar.
- Voxel characters of each species with clothing in their culture's style; statues of known individuals.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `culture-generation`: Adds architecture and dress.
- `procedural-visuals`: Adds voxel peoples, buildings and monuments.

## Impact

- `gen/culture/architecture.lua`, `gen/visuals/buildings.lua`, `people.lua`; settlements and villagers switch to generated models; GL gallery tests.
