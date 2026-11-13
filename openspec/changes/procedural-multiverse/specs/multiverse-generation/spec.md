# Spec Delta

## Purpose

Generates an endless, seeded multiverse: the destinations the van can reach and the worlds themselves, streamed around the player in chunks so that only nearby content exists at any time.

## ADDED Requirements

### Requirement: Seeded multiverse
Every save game SHALL have a multiverse seed chosen when a new journey starts, and all generated content SHALL be a pure function of that seed and the content's coordinates.

#### Scenario: Same seed, same world
- **WHEN** a destination is generated twice from the same seed
- **THEN** its name, biome, terrain, props, characters and quest are identical

#### Scenario: New journey
- **WHEN** the player starts a new journey
- **THEN** a new seed is chosen and the destinations differ from the previous journey

### Requirement: Endless destinations
The van console SHALL offer at least three generated destinations every night, derived from the seed and the night number, and SHALL keep offering new ones without limit.

#### Scenario: Next night
- **WHEN** the player opens the console on a later night
- **THEN** it offers destinations that were not offered on earlier nights

#### Scenario: Returning to a place
- **WHEN** the player has visited a destination before
- **THEN** the console can also take them back to it, and it is generated exactly as before

### Requirement: Lazy chunk streaming
Worlds SHALL be generated in square chunks around the player: chunks within the view radius are generated on demand, chunks well beyond it are discarded, and at most a fixed number of chunks are generated per tick.

#### Scenario: Walking away
- **WHEN** the player walks several chunks in one direction
- **THEN** new chunks appear ahead before they are visible and chunks behind are removed, so the number of entities stays bounded

#### Scenario: Coming back
- **WHEN** the player returns to a discarded chunk
- **THEN** it is regenerated with the same content

### Requirement: Terrain
Generated worlds SHALL have continuous rolling terrain without seams between chunks; the area around the van's landing spot and settlements SHALL be flattened, and the player and every placed object SHALL stand on the terrain surface.

#### Scenario: Crossing a chunk border
- **WHEN** the player walks across the border between two chunks
- **THEN** the ground height is continuous and the player does not jump or sink

### Requirement: Data-driven biomes
Each destination SHALL use a biome template that defines its sky, fog, palette, terrain shape, ground and decal textures, plants, props, characters, ambience and quest types; biome templates SHALL be Lua data that mods can add to.

#### Scenario: Biome variety
- **WHEN** many destinations are generated from one seed
- **THEN** they use several different biomes and colour variations

#### Scenario: Mod biome
- **WHEN** an enabled mod registers a biome
- **THEN** generated destinations can use it

### Requirement: Generated home
The home farm SHALL also be generated from the seed: the farmhouse, barn, fields, roads, trees and the neighbour's name and look vary between journeys, while the farmhouse, the gate and the van's parking spot stay recognisable.

#### Scenario: Two journeys
- **WHEN** two new journeys are started
- **THEN** their farms differ in layout while both contain a farmhouse, a neighbour and the van at the gate
