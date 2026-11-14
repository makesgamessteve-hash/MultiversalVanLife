# Design

## Context

Phase 19 simulates history per level and stores eras; the framework provides commitments. Signals and troubles still use provisional rules from phase 9.

## Goals / Non-Goals

**Goals:** consistency from cosmos to valley; troubles grounded in history.
**Non-Goals:** quests from tensions (phase 21).

## Decisions

- **Refinement**: events touching children become commitments `event_ref`; a child's history pass seeds local events from them (with local participants drawn from its own factions and individuals) before simulating its own; traces are features with era styles.
- **Era styles**: buildings for ruins use the architecture style of the culture and era recorded in the event, weathered (missing voxels, moss tint).
- **Memory**: per culture, a distortion pass maps true events to believed versions (rules: self-glorify, villainise enemies, apotheosis of founders, scapegoat disasters, forget beyond N eras), each with `because` links.
- **Tensions**: derived from the final state (resources under pressure, overlapping spheres, succession age of rulers, religious splits, magic decline, hostile species near settlements) with severity and stakeholders; provisional troubles are removed and signals score tensions.
- **Wanderer**: low-rate sightings inserted into histories of universes Juniper has "visited" (a seeded set), creating legends and sometimes shrines.

## Risks / Trade-offs

- [Too many traces per land] → caps per land and priority by fame of events.
