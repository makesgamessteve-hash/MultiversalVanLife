# Design

## Context

Phase 5 provides records, phase 9 generated lands with quests reached by signals and the logbook.

## Goals / Non-Goals

**Goals:** visited lands frozen in the save; every change persistent; compact data.
**Non-Goals:** time passing, consequences and character memory (phases 21–22).

## Decisions

- **Place record**: on first arrival `records/places/<address>.rec` stores the land description (not geometry), ancestor summaries needed for display and the generator version. Loading prefers the record over generation.
- **Object ids**: every feature and spawned persistent object gets `<chunk or feature id>/<n>`, stable because generation is deterministic and the record freezes the description; player-created objects get ids from a per-land counter.
- **Change log**: state overrides per object id (`taken`, `position`, `state = lit/open/broken/repaired`, custom fields); quests store their progress; chunks apply overrides when building.
- **Writes**: changes are buffered and flushed to the record on leaving a land, ending the night and every 30 s.

## Risks / Trade-offs

- [Save growth] → descriptions and overrides only; size checked in phase 24.
