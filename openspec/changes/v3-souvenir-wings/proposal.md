# Proposal

Phase V3 of 4 of Juniper's interior (see `docs/ROADMAP.md` and `docs/concepts/juniper-interior.md`). Depends on: V2.

## Why

The house should remember where it has been: every people the player visits adds a wing built in their own
architecture.

## What Changes

- On a first visit to a land of a people, the van keeps a souvenir of them (name, species, style vector, motifs,
  plants of their land, a person of their species) in the save.
- The blocks nearest the core, in a spiral, become the wings of the peoples visited, in the order of the visits:
  walls, floors, doorways and decoration in their materials, colours, door sizes and ornaments, with a statue of one
  of them, plants of their land and a sign with their name.
- Juniper mentions the new wing after the visit.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `van-interior`: See the requirements of this change.

## Impact

- New `gen/house/wings.lua`; `gen/house/blocks.lua`, `lib/progress.lua`, `lib/story.lua`, `dialogue/lines.txt`; tests
  and docs.
