# Proposal

Phase 20 of 24 of the procedural multiverse roadmap (see `docs/ROADMAP.md`). Depends on: p19.

## Why

Big events must reach the ground: a galactic war should leave wrecks on a planet and ruins in a valley. Cultures remember history in their own way, and the present day needs concrete troubles that signals and quests can use.

## What Changes

- Events refined down the hierarchy through commitments, with local participants and traces (ruins, battlefields, monuments, craters, shrines) placed in lands.
- Cultural memory: each culture's version of history next to the true record.
- Present-day tensions per country and land with causes, stakeholders and severity; signals and land troubles now come from tensions, replacing the provisional rules of phase 9.
- Wanderer sightings: Juniper's past journeys appear in some histories.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `history-generation`: Adds event refinement, cultural memory, present-day tensions and the Wanderer legend.
- `land-streaming`: Adds ruins and historic traces.

## Impact

- `gen/history/refine.lua`, `memory.lua`, `tensions.lua`, `wanderer.lua`; removal of the provisional land pass; signals use tensions; game tests.
