# Design

## Context

The fact graph with `because` links exists since phase 6; cultural memory since phase 20; deeds and consequences since phases 21–22.

## Goals / Non-Goals

**Goals:** discoverable lore, readable in the retro UI on all input devices.
**Non-Goals:** a full encyclopaedia of undiscovered facts.

## Decisions

- **Discovery set**: stored in `records/codex.rec` as fact ids with the source and version (which culture's telling); triggers in dialogue templates, inscriptions on monuments, observing creatures and visiting places.
- **UI**: two-pane list/detail screen; links are selectable items; "why" lists `because` facts that are discovered (undiscovered causes shown as "unknown"); believed/true tabs; name glosses from the language data.
- **Juniper's knowledge**: a seeded set of universes and eras Juniper "knows" (consistent with Wanderer sightings) decides where the true version is available.
- **Chronicle**: deeds and consequences from the world memory rendered as entries linked to places and people.

## Risks / Trade-offs

- [Text overflow on small screens] → wrapped pages with scrolling; tested on the phone viewport in the web smoke test.
