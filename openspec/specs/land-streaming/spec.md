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
