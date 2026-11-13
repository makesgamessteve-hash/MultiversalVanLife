# Proposal

Phase 13 of 24 of the procedural multiverse roadmap (see `docs/ROADMAP.md`). Depends on: p12.

## Why

A place should look like where it is in the cosmos: its sun, moons and galaxy in the sky, its bedrock in the stones and its star's light in the leaves.

## What Changes

- Planet skies: atmosphere colour, star disc, moons with phases, visible planets and the galaxy band, drawn by the sky shader; the farm gets the real Moon and Milky Way.
- Generated ground, rock, water and foliage textures and palettes from geology, biome and starlight.

## Capabilities

### New Capabilities
- `procedural-visuals`: Generated textures, palettes and skies (voxel models follow in phases 15 and 18).

### Modified Capabilities
- `planet-generation`: Adds the planet sky.
- `prime-universe`: Adds the home sky.

## Impact

- Sky shader and uniforms, `gen/visuals/palette.lua`, `texgen` recipes, GL screenshot tests.
