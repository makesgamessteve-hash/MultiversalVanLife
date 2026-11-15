# Proposal

Phase 33 of 33 of the roadmap (see `docs/ROADMAP.md` and `docs/concepts/living-planets.md`). Depends on: p32.

## Why

With real-sized planets and continuous travel, the player needs fast ways along roads, and signals, quests, the codex and a map need to use the plan; the whole needs guarding again.

## What Changes

- Road hops: from a signpost, the map or the console the van drives along the road network at speed to a chosen place, the land streaming past at low detail.
- Signals from named places with their reason and surroundings.
- Quests over real distances (the next village, the city gate) and troubles shared by neighbouring places.
- A map in the van (planet atlas, then explored region plans) and codex entries for regions, towns, roads, rivers and hills.
- Variety statistics, time budgets, the web frame check and the save stress test extended to towns.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `story-and-worlds`: See the requirements of this change.
- `signals-and-codex`: See the requirements of this change.
- `generated-quests`: See the requirements of this change.
- `quality-and-testing`: See the requirements of this change.

## Impact

- `lib/drive.lua`, `lib/story.lua`, new `lib/map.lua`, `gen/signals.lua`, `gen/quests.lua`, codex, `gen/stats.lua`, tests.
