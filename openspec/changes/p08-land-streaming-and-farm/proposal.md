# Proposal

Phase 8 of 24 of the procedural multiverse roadmap (see `docs/ROADMAP.md`). Depends on: p07.

## Why

Lands are the walkable bottom of the hierarchy. They must stream lazily in chunks around the player on hilly terrain. The farm is the first generated land and proves the system before destinations switch over.

## What Changes

- Land streaming: terrain chunks built around the player within a view radius, discarded beyond it, one per tick, with flora and props and mesh release.
- Continuous hilly terrain across chunks and neighbouring lands, flattened under buildings and the van.
- The farm in the Prime universe is generated from the save seed (farmhouse, barn, fields, roads, trees, neighbour), replacing the hand-made home.

## Capabilities

### New Capabilities
- `land-streaming`: Lazy chunk streaming and continuous terrain.

### Modified Capabilities
- `prime-universe`: Adds the generated farm.
- `story-and-worlds`: The story starts on the generated farm.
- `rendering`: Adds terrain rendering.

## Impact

- `gen/chunks.lua`, `gen/levels/land.lua` (farm style), `worlds/home.lua` rewritten, game tests for walking and farms.
