# Design

## Context

See `docs/concepts/living-planets.md`. This phase builds on p27.

## Decisions

- **Settlement placement**: atlas seeds inside the region first, then villages by population on farmland (Poisson-disc spacing, preferring water and good soil), hamlets and farmsteads in between; nomadic cultures get camps.
- **Roads**: a minimum spanning network over the settlements plus the atlas routes, routed with A* on a 256 m cost grid (slope, water, wetland, borders), ranked by the places they join; crossings become bridges or fords by river size and technology.
- **Lands**: a land takes the settlements, roads, rivers and land use areas intersecting it; a settlement spanning several lands is laid out once by the land holding its centre and shared by its neighbours.
- **Determinism**: region plans depend only on the planet and the region seed, so neighbours agree without generating each other.

## Risks / Trade-offs

- [Generation time and frame rate] -> the p24 budgets, statistics and frame checks run on every push.
