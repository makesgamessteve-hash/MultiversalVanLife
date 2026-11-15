# Design

## Context

See `docs/concepts/living-planets.md`. This phase builds on p29.

## Decisions

- **Plan forms**: the culture's values and plan (architecture), the site's slope and water choose the form; streets are a graph grown from road entries (organic), laid on a grid (planned) or around a centre (ring).
- **Lots**: blocks are split into lots by frontage and depth for the building kind; every lot faces a street with its door.
- **Kinds**: the grammar of p18/p25 gains the new kinds with their own plans and roofs; mills only where water or wind allows; walls only where the times need them (contested borders, war history).
- **Fields**: parcels of the land use areas get crop rows (instanced), hedges and fences along their edges.

## Risks / Trade-offs

- [Generation time and frame rate] -> the p24 budgets, statistics and frame checks run on every push.
