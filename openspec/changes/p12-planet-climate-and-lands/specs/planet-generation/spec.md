# Spec Delta

## ADDED Requirements

### Requirement: Climate
Temperature, winds and precipitation SHALL be derived from latitude, axial tilt, altitude, prevailing winds, ocean distance and rain shadows, and SHALL vary over the planet's seasons.

#### Scenario: Rain shadow
- **WHEN** prevailing winds cross a mountain range
- **THEN** the leeward side is drier than the windward side

### Requirement: Rivers and lakes
Rivers SHALL flow downhill from wet uplands to lakes or the sea, merging as they go, and lakes SHALL form in basins.

#### Scenario: Downhill
- **WHEN** a river path is traced on the planet grid
- **THEN** its elevation never increases along the flow

### Requirement: Biomes
Each region SHALL get a biome derived from its climate, soil, light and atmosphere (for example tundra, taiga, temperate forest, steppe, desert, savanna, rainforest, wetland, coast, alpine, ash fields), including alien variants the planet's conditions allow.

#### Scenario: Biome follows climate
- **WHEN** a region is hot and very wet
- **THEN** its biome is a rainforest or wetland variant

### Requirement: Subdivision
Planets SHALL be divided into continents (from their landmasses), continents into countries and countries into lands (playable regions of a few square kilometres), and every land SHALL know its terrain, biome, climate, owner and settlements.

#### Scenario: Land knows its place
- **WHEN** a land is generated
- **THEN** its data names its continent, country, biome and climate
