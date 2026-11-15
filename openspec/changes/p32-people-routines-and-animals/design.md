# Design

## Context

See `docs/concepts/living-planets.md`. This phase builds on p31.

## Decisions

- **Population**: residents per lot and visitors per square from the settlement's population; the share outdoors from the hour of the planet's day, the weather and holidays.
- **Agents**: the ~30 nearest people are full agents following routines on the street graph (state machines with destinations and timetables); the rest are animated sprites in sprite batches.
- **Promotion**: talking to a background person gives them a stable id in the land (from their lot and role), a name in the language and a character record (p21).
- **Animals**: domestic species from the culture's herds and the region's life, kept in pastures, yards and stables; draught animals pull carts on roads.

## Risks / Trade-offs

- [Generation time and frame rate] -> the p24 budgets, statistics and frame checks run on every push.
