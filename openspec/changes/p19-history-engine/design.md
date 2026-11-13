# Design

## Context

Phases 7–18 provide every level's structure, planets, life and culture generators. History now drives culture changes over time.

## Goals / Non-Goals

**Goals:** one engine, consistent causes, bounded cost.
**Non-Goals:** event refinement into children, cultural memory and tensions (phase 20).

## Decisions

- **Engine**: factions on a region graph of the node's children; fixed time step per level (universe 10⁸ y, galaxy 10³ y, cluster 10² y, planet 25 y, continent 10 y, country 5 y, land 1 y); each step every faction scores actions from an event table by traits, resources, relations and laws; resolution creates events with participants, places, dates and `because` links. Caps: events, factions and individuals per level.
- **Culture hooks**: events call culture generators: splits → `language.split`, foundings and schisms → religions, notable events → `traditions.commemorate`, prosperity and contact → technology level per era.
- **Territories and spheres**: per step region ownership and influence weights; the present-day state of a planet's history sets the final country borders (replacing the provisional growth of phase 12).
- **Individuals**: created by events with lifespans from species biology; long-lived species keep figures alive; living individuals become land residents at the present.
- **Eras**: cut where state change is largest (collapses, conquests, revolutions); each stores territories, rulers, populations and tech.
- **Prime**: the engine refuses addresses in `u0`; lore texts may mention "quiet worlds".

## Risks / Trade-offs

- [Runaway empires or nothing happening] → balancing via variety tests in phase 24 and per-level tuning tables.
