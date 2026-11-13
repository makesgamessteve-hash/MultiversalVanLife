# Design

## Context

Phase 15 provides creature assembly and the model cache; phase 17 culture traits; settlements are placed by phase 9 code.

## Goals / Non-Goals

**Goals:** culturally distinct, recognisable buildings and people in the retro voxel style.
**Non-Goals:** interiors you can walk into (later), indoor furniture beyond a few pieces.

## Decisions

- **Style vector**: material palette (from geology and flora), roof type and pitch (from precipitation and snow), wall thickness (temperature), plan shape (round, square, courtyard, longhouse, burrow, tower), openings (doors sized to anatomy, roof entries for flyers), ornament motifs (from religion), temple orientation (towards the sacred sky object).
- **Buildings**: a floor-plan grammar per building kind generates footprint and storeys into a voxel grid (≤ 64×64×48 at 1/8 m), painted with the style palette; colliders from the footprint.
- **People**: species body from phase 15 assembly scaled to sapient proportions, plus clothing layers (robes, tunics, wraps, harnesses) in the culture's dress palette and status markers.
- **Monuments**: plinth + a statue built from the honoured individual's body model in stone colours; event monuments use symbolic shapes.

## Risks / Trade-offs

- [Model build time for a whole village] → buildings cached per style and kind with variations by seed; built over several frames during travel.
