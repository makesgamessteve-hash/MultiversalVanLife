# Spec Delta

## ADDED Requirements

### Requirement: Terrain follows the planet
Land terrain SHALL follow the planet's elevation, rivers, coasts and biomes at large scale with local detail added.

#### Scenario: River on the map
- **WHEN** the planet's river network passes through a land
- **THEN** the river flows through that land's terrain along the same course

#### Scenario: Coast
- **WHEN** a land lies on the planet's coast
- **THEN** its terrain descends to a sea surface on the side where the planet has ocean
