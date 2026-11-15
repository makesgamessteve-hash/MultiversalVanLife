# Design

## Context

See `docs/concepts/living-planets.md`. This phase builds on p25.

## Decisions

- **Atlas pass**: a planet pass after history computes the new fields per cell (10,242 cells, within the planet budget).
- **Population**: fertility from temperature, rainfall, soil (biome), slope and fresh water; multiplied by the culture's technology (farming, irrigation, industry) and history (capitals attract, wars and plagues thin out, colonies grow); drought tensions lower it.
- **Settlement seeds**: cities where population, rivers, coasts and crossings meet (gravity model), positions within the cell from its seed; capitals from history.
- **Routes**: least-cost paths on the cell graph between cities (slope, rivers, wetland, borders at war), sea lanes between ports.
- **Queries**: `gen.plan.at(G, planet, lat, lon)` interpolates per-cell fields and lists nearby seeds and routes; used later by regions, signals, dialogue and the map.

## Risks / Trade-offs

- [Generation time and frame rate] -> the p24 budgets, statistics and frame checks run on every push.
