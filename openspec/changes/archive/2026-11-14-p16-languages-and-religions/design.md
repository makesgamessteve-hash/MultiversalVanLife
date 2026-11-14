# Design

## Context

Phase 14 provides intelligent species with anatomy; phase 13 the sky data; phases 11–12 geology and climate. History (phase 19) will later split cultures and found religions; until then each sapient species has one founding culture per homeworld region.

## Goals / Non-Goals

**Goals:** meaningful, pronounceable, related names; religions explained by causes.
**Non-Goals:** grammar or full sentences in conlangs; dialogue translation.

## Decisions

- **Phonology**: a consonant/vowel inventory sampled from feature tables and filtered by anatomy (no labials without lips, clicks for beaked or mandibled speakers, tonal vowels for musical species); syllable templates (CV, CVC, CCV…) with phonotactic weights; romanisation table for display.
- **Lexicon**: ~300 meanings (nature, kinship, colours, numbers, verbs of place and motion, sacred terms) with generated roots; names compose 1–3 roots by meaning templates ("tide"+"kneel" → place), storing the gloss.
- **Families**: `split(language, seed)` applies 2–5 sound-change rules (lenition, vowel shifts, cluster simplification) to make a daughter; used by history and for "older forms".
- **Religion**: motif table mapping sources to motifs (two moons → twin gods, volcano → fire mother, short lifespan → rebirth, tectonic magic → earth spirits, founder → saint); a religion = weighted motifs + doctrines (virtues, taboos, afterlife) + clergy form + sacred site kinds; every motif keeps `because` links to its source facts.

## Risks / Trade-offs

- [Unpronounceable names] → phonotactic filters and a readability score rejecting bad names.
