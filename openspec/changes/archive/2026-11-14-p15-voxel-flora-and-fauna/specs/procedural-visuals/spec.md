# Spec Delta

## ADDED Requirements

### Requirement: Runtime voxel plants and animals
Plants and animals SHALL be built as voxel models at runtime from their generated traits (lineage, body plan, size, colours), so different species look different.

#### Scenario: Two species
- **WHEN** two animal species with different body plans appear in a land
- **THEN** their models have visibly different shapes and colours

### Requirement: Simple animation
Creatures SHALL animate procedurally according to their anatomy (walking legs, flapping wings, slithering bodies) and plants SHALL sway.

#### Scenario: Winged flyer
- **WHEN** a winged creature flies
- **THEN** its wings move

### Requirement: Model budgets and caching
Generated models SHALL be cached by their parameters, built within the generation budget, shared between instances and released when no longer used, with the existing hand-made art as a fallback.

#### Scenario: Herd
- **WHEN** a herd of one species is visible
- **THEN** all its members share one body model
