# Spec Delta

## Purpose

Shows the generated cosmos visually: generated textures, palettes and skies, and voxel models built at runtime from generated traits.

## ADDED Requirements

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
