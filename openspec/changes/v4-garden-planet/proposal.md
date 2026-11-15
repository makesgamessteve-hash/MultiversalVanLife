# Proposal

Phase V4 of 4 of Juniper's interior (see `docs/ROADMAP.md` and `docs/concepts/juniper-interior.md`). Depends on: V3.

## Why

A door of the van should open onto an open garden, and the van should be nearly the size of a planet: the garden is a
small world of its own behind the conservatory.

## What Changes

- Terrain slots in the engine: a second height field next to the land's.
- The garden: endless rolling meadows, woods, ponds, orchards, flower beds, hedges and paths, with its own sky and
  sun, streamed in chunks around the player like a land.
- The garden door: the conservatory's glass doors show the garden (a portal) and lead into it; in the garden, the
  back of the house stands at the start of the paths with the door back in.
- The sky, sun and fog follow where the player is: the outside world's in the cab, the garden's in the garden and the
  rest of the house.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `van-interior`, `scripting-api`: See the requirements of this change.

## Impact

- Engine: `terrain.c`, `script.c`, `engine.h`; `gen/chunks.lua` (slot, sea level), new `gen/house/garden.lua`,
  `lib/house.lua`, `lib/van.lua`, `lib/world.lua`, `lib/player.lua`; tests and docs.
