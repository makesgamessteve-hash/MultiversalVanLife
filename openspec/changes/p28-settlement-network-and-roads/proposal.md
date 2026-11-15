# Proposal

Phase 28 of 33 of the roadmap (see `docs/ROADMAP.md` and `docs/concepts/living-planets.md`). Depends on: p27.

## Why

Every land has the same hamlet at its middle and one road crosses a district: places do not form a network, so nothing on the ground has a reason to be where it is.

## What Changes

- Region plans place settlements from the atlas: farmsteads, hamlets, villages, towns, cities and camps with types, sizes, specialties, founding eras and condition, named in their language.
- Road networks: highways, roads, tracks and paths routed by terrain cost, with bridges, fords and harbours; signposts' destinations.
- Land use areas (fields, pastures, orchards, woods, mines, sacred groves, ruins) and named features (hills, forests, lakes, passes).
- History commitments target real places (the capital's palace quarter, the main square of the faith's first city).
- Lands generate the parts of the plan that fall into them; quests, residents and traces live in real settlements.

## Capabilities

### New Capabilities
- `settlements`: Settlements of generated planets, their network, layouts, things and people.

### Modified Capabilities
- `history-generation`: See the requirements of this change.

## Impact

- New `gen/plan/region.lua`, `gen/plan/settlements.lua`, `gen/plan/roads.lua`, `gen/levels/land.lua`, history refinement, quests, tests.
