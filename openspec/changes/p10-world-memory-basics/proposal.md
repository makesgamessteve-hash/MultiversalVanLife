# Proposal

Phase 10 of 24 of the procedural multiverse roadmap (see `docs/ROADMAP.md`). Depends on: p09.

## Why

Places the player visits must stay as they are and remember everything the player did there. This phase stores visited lands and records every change; later phases add time passing, consequences and people's memory.

## What Changes

- Visited lands (and the ancestor summaries they need) are stored in the save on first arrival and loaded on revisits instead of regenerating.
- Every persistent object has a stable id; every change (items taken, carried, dropped or given; objects lit, opened, repaired or broken; quest progress; things the player placed) is recorded and applied when chunks are built.

## Capabilities

### New Capabilities
- `world-memory`: Persistent visited places and remembered player actions.

### Modified Capabilities
- `quality-and-testing`: Persistence tests.

## Impact

- `memory/places.lua`, `memory/changes.lua`, object ids in `gen/chunks.lua` and quests, records from phase 5, game tests across leaving and restarting.
