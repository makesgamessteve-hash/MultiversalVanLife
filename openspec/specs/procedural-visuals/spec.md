# procedural-visuals Specification

## Purpose
Shows the generated cosmos visually: generated textures, palettes and skies, and voxel models built at runtime from generated traits.

## Requirements

### Requirement: Generated textures and palettes
Ground, rock, foliage and water textures and palettes SHALL be generated or tinted from the place's geology, biome and the star's light, so foliage colour follows the star's spectrum and stone colour follows the bedrock.

#### Scenario: Red sun foliage
- **WHEN** a planet orbits a dim red star
- **THEN** its plants use dark, near-black or deep purple foliage palettes

#### Scenario: Local stone
- **WHEN** a land's bedrock is red sandstone
- **THEN** its rocks and stone textures use red sandstone colours

### Requirement: Generated skies
Each planet's sky SHALL be drawn from its generated data: sky colour from atmosphere and star, the star's disc, moons with phases, visible planets and the galaxy band.

#### Scenario: Thick atmosphere
- **WHEN** a planet has a thick hazy atmosphere
- **THEN** its sky is denser and its fog starts closer than on a thin-aired world

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
