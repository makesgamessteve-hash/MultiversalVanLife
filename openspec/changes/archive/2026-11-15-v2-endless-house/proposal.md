# Proposal

Phase V2 of 4 of Juniper's interior (see `docs/ROADMAP.md` and `docs/concepts/juniper-interior.md`). Depends on: V1.

## Why

The van should be vast, nearly the size of a planet: the house must go on beyond the core, room after room, without
end, and stay affordable on every device.

## What Changes

- The house beyond the core is a grid of 32 m blocks; every block has a doorway in the middle of each side, so all
  blocks connect and every room can be reached from the core.
- Blocks are laid out from their seed by templates (a cross of corridors with rooms in the quarters, an enfilade, a
  grand hall, a cloister round an indoor courtyard) with room kinds and house styles that vary by block.
- Blocks are generated and built near the player and released behind them, within entity, mesh and time budgets.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `van-interior`: See the requirements of this change.

## Impact

- New `gen/house/blocks.lua`, `gen/house/kinds.lua`; `gen/house/plan.lua`, `lib/house.lua`; tests and docs.
