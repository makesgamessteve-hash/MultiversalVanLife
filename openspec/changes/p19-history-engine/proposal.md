# Proposal

Phase 19 of 24 of the procedural multiverse roadmap (see `docs/ROADMAP.md`). Depends on: p18.

## Why

History binds everything together: it explains borders, ruins, holidays, schisms, technology and the people alive today. It must be simulated consistently on every level of the cosmos.

## What Changes

- One chronicle engine used on every level with its own time scale and event table: factions act on traits, resources and relations through expansion, alliance, war, trade, schism, discovery, plague, migration, revolution, golden age and collapse.
- Territories and spheres of influence; final country borders on planets come from history.
- Known individuals with lifespans, deeds and relations.
- Eras with state snapshots, so the past can be shown later.
- Histories never touch the Prime universe; Earth is a quiet world in the cosmos's lore.

## Capabilities

### New Capabilities
- `history-generation`: Chronicle simulation per level, factions and spheres of influence, known individuals and eras (refinement, memory and tensions follow in phase 20).

### Modified Capabilities
- `prime-universe`: Earth is a quiet world that histories never touch.

## Impact

- `gen/history/engine.lua`, `events/*.lua` per level, `individuals.lua`, `eras.lua`; calls into culture generators (language splits, religion founding, commemorations, technology); checker rules; bible sections.
