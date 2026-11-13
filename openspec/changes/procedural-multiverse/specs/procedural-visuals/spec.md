# Spec Delta

## Purpose

Shows the generated cosmos visually: voxel models built at runtime from generated traits for plants, creatures, peoples, clothing, buildings and monuments, plus generated textures, palettes and skies.

## ADDED Requirements

### Requirement: Runtime voxel models
Plants, animals, intelligent species, clothing, buildings, furniture and monuments SHALL be built as voxel models at runtime from their generated traits (body plan, size, colours, culture, era), so different species and cultures look different.

#### Scenario: Two species
- **WHEN** two intelligent species with different body plans appear in the game
- **THEN** their characters have visibly different shapes and colours

#### Scenario: Statue of a real figure
- **WHEN** a land contains a monument to a known individual
- **THEN** the statue shows that individual's species and attributes

### Requirement: Generated textures and palettes
Ground, rock, foliage, water and material textures SHALL be generated or tinted from the place's geology, biome and the star's light, so foliage colour follows the star's spectrum and stone colour follows the bedrock.

#### Scenario: Red sun foliage
- **WHEN** a planet orbits a dim red star
- **THEN** its plants use dark, near-black or deep purple foliage palettes

### Requirement: Generated skies
Each planet's sky SHALL be drawn from its generated data: sky colour from atmosphere and star, the star's disc, moons with phases, visible planets and the galaxy band.

#### Scenario: Thick atmosphere
- **WHEN** a planet has a thick hazy atmosphere
- **THEN** its sky is denser and its fog starts closer than on a thin-aired world

### Requirement: Simple animation
Creatures and characters SHALL animate procedurally according to their anatomy (walking legs, flapping wings, slithering bodies, swaying plants).

#### Scenario: Winged flyer
- **WHEN** a winged creature flies
- **THEN** its wings move

### Requirement: Model budgets and caching
Generated models and textures SHALL be cached by their parameters, built within the generation budget and released when no longer used, with the existing hand-made art as a fallback.

#### Scenario: Many villagers
- **WHEN** a village has many villagers of the same species
- **THEN** their body models are shared and only variations (clothing, colour) are built separately
