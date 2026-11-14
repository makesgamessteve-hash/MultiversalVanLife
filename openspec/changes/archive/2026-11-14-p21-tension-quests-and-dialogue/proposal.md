# Proposal

Phase 21 of 24 of the procedural multiverse roadmap (see `docs/ROADMAP.md`). Depends on: p20.

## Why

Quests should come from each land's real troubles and real people, offer choices with lasting outcomes, and people should talk like members of their culture and remember the player.

## What Changes

- Quests from present-day tensions with real stakeholders and local lore.
- More templates: carry a message, mediate a dispute, escort someone, restore a failing source of magic or water.
- Choices with different outcomes recorded by the world memory.
- Dialogue from templates using greetings, blessings, idioms, history versions, character memory and current events.
- Characters remember meeting the player and what the player did.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `generated-quests`: Adds quests from tensions, advanced templates, choices with lasting outcomes and culture-based dialogue.
- `world-memory`: Adds people remembering the player.

## Impact

- `gen/quests.lua` rewritten around tensions, `gen/dialogue/*.lua`, `memory/characters.lua`, quest and dialogue game tests.
