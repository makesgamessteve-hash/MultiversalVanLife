# Proposal

Phase 32 of 33 of the roadmap (see `docs/ROADMAP.md` and `docs/concepts/living-planets.md`). Depends on: p31.

## Why

A place with the right buildings and things still feels dead without its people going about their day and its animals.

## What Changes

- Visible people from the settlement's population and the local time of day.
- Roles from society (farmers, merchants, priests, guards, crafters, children, elders, travellers on trade roads) in their culture's dress and body.
- Daily routines on the layout: home, work, market and temple along streets, stalls tended, fields worked, chats, processions on holidays, shelter from rain.
- Lazy characters: background people become characters (name, memory, dialogue) when talked to.
- Domestic animals: herds, poultry, dogs, draught animals, pets.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `settlements`: See the requirements of this change.
- `life-generation`: See the requirements of this change.

## Impact

- New `lib/crowd.lua`, `gen/settle/population.lua`, `lib/talk.lua`, `gen/chunks.lua`, `lib/creatures.lua`, tests.
