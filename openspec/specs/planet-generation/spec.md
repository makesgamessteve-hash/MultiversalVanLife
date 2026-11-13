# planet-generation Specification

## Purpose
Generates planets as physically coherent worlds: their physics from star and orbit, tectonics and geology, climate and water, biomes, magic geography and sky, and their subdivision into continents, countries and lands.

## Requirements

### Requirement: Planet physics from star and orbit
A planet's mass, radius, gravity, composition, atmosphere, temperature range, day length, axial tilt and year length SHALL follow from its star, orbit and formation history, and SHALL be consistent with the star system's layout.

#### Scenario: Close to a dim red star
- **WHEN** a planet orbits close to a red dwarf
- **THEN** it is likely tidally locked or slowly rotating, its light is reddish and its year is short

### Requirement: Tectonics and continents
Planets with active geology SHALL be divided into tectonic plates whose motion produces continents, mountain ranges at collisions, rifts and ocean ridges at divergence, island arcs and volcanoes at subduction.

#### Scenario: Mountains where plates collide
- **WHEN** two continental plates converge
- **THEN** a mountain range runs along their boundary

### Requirement: Geology and resources
Each region SHALL have rock types, soils and deposits (metals, fuels, gems, and magical minerals where the universe allows magic) derived from tectonic setting and planet composition.

#### Scenario: Ore near old mountains
- **WHEN** a region lies on an old eroded mountain belt
- **THEN** it is more likely to have metal ores than a young sediment basin

### Requirement: Magic geography
Where magic exists, its local strength SHALL follow the universe's magic source: life density for life-fed magic, plate boundaries for tectonic magic, starlight and star type for stellar magic, and holy sites for belief-fed magic.

#### Scenario: Tectonic magic
- **WHEN** a universe's magic is fed by tectonics
- **THEN** the strongest magic on its planets lies along plate boundaries and volcanoes

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

### Requirement: Planet sky
Each planet SHALL have sky data that matches its place in the cosmos: star colour and size, moons with their sizes, orbits and phases, visible sister planets and the band of its galaxy as seen from its position.

#### Scenario: Two moons
- **WHEN** a planet has two moons
- **THEN** both are visible in its night sky with phases that follow their orbits
