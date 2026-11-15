# Design

## Context

See `docs/concepts/living-planets.md`. This phase builds on p32.

## Decisions

- **Hops**: a route on the road graph; the van follows it at up to 120 km/h with the far ring and a corridor of low-detail chunks, then slows and the near world loads at the destination.
- **Map**: textures generated from the atlas and region plans (texgen), with roads, settlements and the van; revealed as the player explores.
- **Quests**: message, escort and mediate quests choose real places of the network; distances are bounded so they fit a night.

## Risks / Trade-offs

- [Generation time and frame rate] -> the p24 budgets, statistics and frame checks run on every push.
