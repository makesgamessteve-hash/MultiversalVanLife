# Design

## Context

Phase 20 provides tensions with causes and stakeholders; phase 10 the change log; phase 16–17 languages, religions and traditions.

## Goals / Non-Goals

**Goals:** grounded quests with consequences; characters with a voice and a memory.
**Non-Goals:** free-text conversations.

## Decisions

- **Tension → quest**: each tension kind maps to templates; the template is filled with stakeholders (giver, parties, targets), items and places from the land; outcomes are a small list with effects on the land state, faction attitudes and character favour.
- **Dialogue**: a Tracery-like grammar with slots filled from the culture (greeting forms, blessings from religion, idioms from history and nature, sayings about saints) and from memory (known-as name, favour, deeds witnessed, recent events); output stays short for the retro text box.
- **Character memory**: per character record (met, known-as name, favour −3…+3, deeds) stored in the land record; known-as names come from how the community refers to the player (titles from deeds).
- **Choices**: dialogue menus reuse the menu UI and touch controls.

## Risks / Trade-offs

- [Repetitive lines] → grammar with many alternatives per slot and seeded variation per character.
