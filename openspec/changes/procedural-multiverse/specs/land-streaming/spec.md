# Spec Delta

## Purpose

Turns a land's description into the walkable world: terrain that follows the planet's geography, streamed lazily in chunks around the player together with settlements, roads, ruins, plants and wildlife.

## ADDED Requirements

### Requirement: Lazy chunk streaming
Lands SHALL be built in square chunks around the player: chunks within the view radius are built on demand, chunks well beyond it are discarded, and at most a fixed number of chunks are built per tick.

#### Scenario: Walking away
- **WHEN** the player walks several chunks in one direction
- **THEN** new chunks appear ahead before they are visible and chunks behind are removed, so the number of entities stays bounded

#### Scenario: Coming back
- **WHEN** the player returns to a discarded chunk
- **THEN** it is rebuilt with the same content plus every change the world memory recorded there

### Requirement: Terrain follows the planet
Land terrain SHALL be continuous across chunks and across neighbouring lands, follow the planet's elevation, rivers, coasts and biomes at large scale with local detail added, and be flattened under settlements, roads and the van's landing spot; the player and every placed object SHALL stand on the surface.

#### Scenario: Crossing into the next land
- **WHEN** the player walks from one land into a neighbouring land
- **THEN** the ground is continuous and the neighbouring land is generated lazily as the player approaches

#### Scenario: River on the map
- **WHEN** the planet's river network passes through a land
- **THEN** the river flows through that land's terrain along the same course

### Requirement: Settlements, roads and ruins
Each land SHALL place the settlements, roads, farms, sacred sites, ruins and historic traces its description contains, built in the style of the culture and era that made them.

#### Scenario: Ruin of an older era
- **WHEN** a land's history contains a city destroyed centuries ago
- **THEN** its ruins appear at the city's location in the architecture style of that era

### Requirement: Plants and wildlife
Each chunk SHALL be populated with the plants and animals of its biome from the planet's tree of life, with densities following climate and soil, and animals moving with their behaviours.

#### Scenario: Biome change
- **WHEN** the player walks from forest into grassland
- **THEN** plant and animal species change according to the two biomes
