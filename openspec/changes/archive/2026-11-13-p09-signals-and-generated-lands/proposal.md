# Proposal

Phase 9 of 24 of the procedural multiverse roadmap (see `docs/ROADMAP.md`). Depends on: p08.

## Why

This phase switches the game from three handmade destinations to the generated cosmos: Juniper's signals lead to generated lands with settlements and quests. Until the deep generators arrive in later phases, lands use simple provisional rules derived from their star system, so the game is playable end to end.

## What Changes

- **BREAKING** Remove Lanternfen, the Clockwork Bazaar and the Tidewater Library.
- Signals: three per night, chosen by severity and variety, never in the Prime universe; generation starts on selection and finishes during the travel vortex.
- Logbook of visited lands in the console.
- Provisional land generation: a land style from its planet skeleton, a settlement with villagers, roads and a quest from four base templates (relight, gather, return, lost person) with generated text.
- Juniper celebrates every third land helped.
- Mods extend the generator instead of adding fixed destinations.

## Capabilities

### New Capabilities
- `signals-and-codex`: Nightly signals and the logbook (the codex follows in phase 23).
- `generated-quests`: Land quests from templates and reachable quest items.

### Modified Capabilities
- `land-streaming`: Adds settlements and roads.
- `story-and-worlds`: Console offers signals and the logbook; night milestones; fixed destinations removed.
- `data-and-mods`: Mods add generation content.
- `quality-and-testing`: Quest tests use generated lands.

## Impact

- `gen/levels/land.lua` (provisional rules), `gen/signals.lua`, `gen/quests.lua`, `gen/names.lua`, console UI, removal of `worlds/fen.lua`, `market.lua`, `library.lua`, rewritten game tests.
