# Proposal

Phase 23 of 24 of the procedural multiverse roadmap (see `docs/ROADMAP.md`). Depends on: p22.

## Why

The generated depth only matters if the player can discover and explore it. A codex collects what the player has learned, explains why things are as they are, contrasts belief with truth and chronicles the player's own deeds.

## What Changes

- A codex (in the van and in the pause menu) with entries for places, factions, species, religions, languages, individuals, events, creatures and traditions, cross-linked and with a "why" view.
- Entries unlocked by visiting, talking, reading inscriptions and observing.
- Believed and true versions side by side; name translations.
- The Wanderer's chronicle of the player's deeds and their consequences.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `signals-and-codex`: Adds the codex, belief and truth, and codex access.
- `world-memory`: Adds the Wanderer's chronicle.

## Impact

- `game/scripts/lib/codex.lua` (UI with keyboard, gamepad and touch), discovery tracking in dialogue and interactions, inscriptions on monuments, codex record in the save, game tests.
