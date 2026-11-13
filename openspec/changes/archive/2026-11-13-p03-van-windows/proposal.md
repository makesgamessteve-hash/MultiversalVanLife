# Proposal

Phase 3 of 24 of the procedural multiverse roadmap (see `docs/ROADMAP.md`). Depends on: p02.

## Why

The van's interior is a separate world, so entering it reloads the scene and the player can never see where the van is parked. Windows that look outside sell the "bigger on the inside" fantasy and prepare the van for travelling to generated places.

## What Changes

- The interior becomes a pocket inside each world's scene; the doors teleport the player instead of loading a world.
- The interior gets windows that are portals to the matching spots on the exterior van.
- During travel the windows show a multiversal vortex.
- `van_interior.vox` is regenerated with window openings.

## Capabilities

### New Capabilities
- `van-windows`: The interior shares the world scene and its windows show the outside through portals or the vortex while travelling.

### Modified Capabilities
- `story-and-worlds`: Entering and leaving the van no longer loads a world.

## Impact

- `tools/gen_assets.py` (interior windows), `game/scripts/lib/story.lua`, `game/scripts/worlds/van.lua`, world loading; game tests for entering, leaving and travelling.
