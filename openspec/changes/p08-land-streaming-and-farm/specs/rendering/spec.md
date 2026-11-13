# Spec Delta

## ADDED Requirements

### Requirement: Terrain rendering
Terrain chunks SHALL be drawn with per-vertex colours from the land's palette combined with the ground texture, without visible cracks along chunk borders.

#### Scenario: Chunk seams
- **WHEN** two neighbouring terrain chunks are drawn
- **THEN** no gaps or sky pixels appear along their shared border
