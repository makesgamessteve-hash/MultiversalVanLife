# land-streaming Specification

## Purpose
Turns a land's description into the walkable world: terrain streamed lazily in chunks around the player together with buildings, plants and props.

## Requirements

### Requirement: Lazy chunk streaming
Lands SHALL be built in square chunks around the player: chunks within the view radius are built on demand, chunks well beyond it are discarded, and at most a fixed number of chunks are built per tick.

#### Scenario: Walking away
- **WHEN** the player walks several chunks in one direction
- **THEN** new chunks appear ahead before they are visible and chunks behind are removed, so the number of entities and meshes stays bounded

#### Scenario: Coming back
- **WHEN** the player returns to a discarded chunk
- **THEN** it is rebuilt with the same content

### Requirement: Continuous terrain
Land terrain SHALL be continuous across chunks and across neighbouring lands, flattened under buildings, roads and the van's landing spot, and the player and every placed object SHALL stand on the surface.

#### Scenario: Crossing a chunk border
- **WHEN** the player walks across the border between two chunks
- **THEN** the ground height is continuous and the player does not jump or sink

#### Scenario: Neighbouring land
- **WHEN** the player walks towards the edge of a land
- **THEN** the neighbouring land is generated lazily and its terrain continues without a seam

### Requirement: Settlements and roads
Each land SHALL place the settlements, buildings, roads and villagers its description contains, near the landing spot for lands reached by signals.

#### Scenario: Settlement near the van
- **WHEN** the player arrives at a land through a signal
- **THEN** buildings of a settlement are visible from the van's door

### Requirement: Terrain follows the planet
Land terrain SHALL follow the planet's elevation, rivers, coasts and biomes at large scale with local detail added.

#### Scenario: River on the map
- **WHEN** the planet's river network passes through a land
- **THEN** the river flows through that land's terrain along the same course

#### Scenario: Coast
- **WHEN** a land lies on the planet's coast
- **THEN** its terrain descends to a sea surface on the side where the planet has ocean

### Requirement: Plants and wildlife
Each chunk SHALL be populated with the plants and animals of its biome from the planet's tree of life, with densities following climate and soil.

#### Scenario: Biome change
- **WHEN** the player walks from forest into grassland
- **THEN** plant and animal species change according to the two biomes

### Requirement: Ruins and historic traces
Each land SHALL place the ruins, battlefields, monuments, craters and shrines its history left there, built in the style of the culture and era that made them.

#### Scenario: Ruin of an older era
- **WHEN** a land's history contains a city destroyed centuries ago
- **THEN** its ruins appear at the city's location in the architecture style of that era
