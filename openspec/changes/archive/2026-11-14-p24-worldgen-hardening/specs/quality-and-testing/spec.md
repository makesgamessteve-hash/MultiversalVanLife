# Spec Delta

## ADDED Requirements

### Requirement: Variety and budget tests
Tests SHALL generate places from at least 200 seeds and check variety statistics (biomes, species body plans, religion sources, tech levels, tension kinds) and that every level stays within its time and count budgets on CI, including the web build's frame rate during travel.

#### Scenario: Monotony
- **WHEN** more than half of the generated planets share one biome distribution
- **THEN** the variety test fails

#### Scenario: Slow level
- **WHEN** generating a level exceeds its time budget on CI
- **THEN** the budget test fails naming the level and pass
