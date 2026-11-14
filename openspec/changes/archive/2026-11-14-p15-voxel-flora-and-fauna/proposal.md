# Proposal

Phase 15 of 24 of the procedural multiverse roadmap (see `docs/ROADMAP.md`). Depends on: p14.

## Why

Generated species are only data drawn as tinted sprites. They should look and move like what they are, so every world's wildlife is visibly its own.

## What Changes

- Plants built as voxel models from a branch grammar per lineage; animals assembled from body plans.
- Procedural animation (gaits, wings, slithering, swaying) using entity parenting.
- Behaviours (grazing, herding, fleeing, prowling, flying, burrowing) reacting to the player.
- Model caching, sharing and release within budgets.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `procedural-visuals`: Adds runtime voxel models for plants and animals, animation, budgets and caching.
- `life-generation`: Adds creature behaviour.

## Impact

- `gen/visuals/plants.lua`, `creatures.lua`, `anim.lua`, `game/scripts/lib/creatures.lua` (behaviour), model cache; GL gallery tests.
