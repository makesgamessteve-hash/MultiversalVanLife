# Spec Delta

## ADDED Requirements

### Requirement: Human geography
Each planet with peoples SHALL have, per cell, fertility, population density, urbanisation and land use derived from its nature, its peoples' technology, its history and its tensions, and seeds of its cities and towns connected by trade routes.

#### Scenario: River valley
- **WHEN** a fertile river valley lies in a country of farmers
- **THEN** it has a high population, farmland and a city or town seed on the river

#### Scenario: Uninhabited world
- **WHEN** a planet has no peoples
- **THEN** its cells have land use but no population and no settlements

### Requirement: Plan queries
The planet plan SHALL answer what is at any latitude and longitude (country, culture, biome, population, land use, nearest settlements and routes) without generating lands below the planet.

#### Scenario: Asking about a place
- **WHEN** a script asks what lies at a point of a planet
- **THEN** it gets the country, culture, land use and the nearest towns and roads, and no land is generated
