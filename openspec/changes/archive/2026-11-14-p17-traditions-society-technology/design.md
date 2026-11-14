# Design

## Context

Phase 16 provides languages and religions; phases 11–14 the planet, its resources and species. History (phase 19) will add commemorations and change technology over eras; this phase defines the generators history will call.

## Goals / Non-Goals

**Goals:** customs and capabilities that follow from causes.
**Non-Goals:** economic simulation.

## Decisions

- **Calendar**: units from day, year and moon periods (lunar, solar or lunisolar); names from the language lexicon; astronomical holidays from solstices, equinoxes, eclipses and conjunctions computed from orbit data.
- **Commemorations**: an API `traditions.commemorate(event)` that history calls to add holidays on event dates.
- **Customs**: rites, funerals (sky, sea, fire, earth, ossuary, tree), food customs and taboos chosen from tables with constraints (geography, biology, religion) and causal links.
- **Society**: value axes (hierarchy–equality, honour–harmony, tradition–innovation, collective–individual, hospitality–wariness) from instincts and environment, nudged by history.
- **Technology**: a dependency graph (fire → pottery → copper → bronze → iron → … → spaceflight) with resource, domestication, population, stability and trade prerequisites; magic and psionic branches as alternatives; a function returns the reachable level for given conditions, used by history per era.

## Risks / Trade-offs

- [Stagnant cultures everywhere] → variety test on tech levels; trade and contact events in history push progress.
