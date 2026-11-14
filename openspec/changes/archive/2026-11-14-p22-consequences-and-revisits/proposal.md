# Proposal

Phase 22 of 24 of the procedural multiverse roadmap (see `docs/ROADMAP.md`). Depends on: p21.

## Why

The player's actions must keep mattering after they leave: time passes in visited places, consequences develop and spread, the world shows visible marks of what the player did, and Juniper is called back to places that need the player again.

## What Changes

- Each visited land keeps a clock; on return the elapsed time is simulated (aftermath).
- Notable deeds become history events and spread as rumours and legends to neighbouring lands and up the hierarchy, changing reputations and faction attitudes.
- Visible marks: restored or ruined buildings, monuments, shrines, murals, renamed places and festivals.
- Follow-up signals from visited places with new needs or invitations.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `world-memory`: Adds time between visits, spreading consequences, visible marks and regular revisits.
- `signals-and-codex`: Adds follow-up signals.

## Impact

- `memory/aftermath.lua`, `memory/spread.lua`, `memory/marks.lua`, signal selector changes, game tests over multiple nights.
