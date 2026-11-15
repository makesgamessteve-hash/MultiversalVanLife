# Design

## Context

See `docs/concepts/living-planets.md`. This phase builds on p24.

## Decisions

- **Sizes in metres**: `B.plan` takes the people's height and the building kind and returns metres (footprint, storeys, storey height, door); the voxel builder converts with the 0.125 m voxel. The grid grows with the plan (up to 192 x 192 x 128 voxels).
- **Modules**: walls, palaces and halls longer than 24 m are composed of several models placed side by side by the settlement layout.
- **Spacing**: the provisional settlement places buildings by their footprints (no overlaps, a lane to the door), around a larger square.
- **Budget**: models stay cached per style, kind and variant; the p24 budget test covers land generation, and a new model-time budget covers meshing.

## Risks / Trade-offs

- [Generation time and frame rate] -> the p24 budgets, statistics and frame checks run on every push.
