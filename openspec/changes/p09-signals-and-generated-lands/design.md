# Design

## Context

Phases 6–8 provide the framework, cosmos down to star systems, streaming and the farm. Planets, life, cultures and history do not exist yet.

## Goals / Non-Goals

**Goals:** a playable loop through the hierarchy now; nothing thrown away later except the provisional land rules.
**Non-Goals:** deep content (phases 11–22).

## Decisions

- **Provisional lands**: a temporary pass derives planet and land skeletons from the star system skeleton (temperature class → land style from a small table: temperate, marsh, desert, snow, crystal, fungal), reusing and tinting existing art. It is registered as a pass and replaced in phase 20 by the full pipeline; the signal and quest code does not change.
- **Troubles**: provisional troubles are drawn per land (dark lamps, broken machine, lost items, missing person) and mapped to the four templates; they become tensions in phase 20.
- **Signals**: candidate lands come from random addresses across universes (never `u0`); each candidate is generated only as a skeleton for scoring; scoring = severity + novelty (unvisited galaxy, unused trouble kind); three are offered, deterministic per seed and night.
- **Travel**: choosing a signal starts the runner with a raised budget; the vortex lasts until generation finishes (minimum 3.5 s).
- **Quests**: `gen/quests.lua` templates with setup/talk/complete callbacks and text templates; items placed as features within 60 m of the giver on walkable ground.
- **Names**: provisional syllable lexicons per land style (replaced by languages in phase 16).

## Risks / Trade-offs

- [Provisional content feels thin] → accepted for a few phases; it keeps the game playable and tests stable.
