# life-generation Specification

## Purpose
Generates life that fits its world: each living planet's tree of life, plants and animals adapted to their environment and roles, creature behaviour, and the intelligent species that evolved from that life.

## Requirements

### Requirement: Tree of life
Every planet with life SHALL have a tree of life whose biochemistry and major lineages (body plans) follow from its conditions and the universe's laws; all its native species SHALL descend from these lineages.

#### Scenario: Shared ancestry
- **WHEN** two animal species on a planet belong to the same lineage
- **THEN** they share body plan features such as limb count and covering

### Requirement: Adaptation
Species traits SHALL follow their environment: pigments from the star's light, build from gravity, flight from air density, covering from climate, size from resources and magic or psionic traits from local fields where those exist.

#### Scenario: High gravity
- **WHEN** a planet has high gravity
- **THEN** its land animals are on average shorter and stockier than on a low-gravity planet

### Requirement: Ecosystems
Each biome SHALL contain plants and animals filling ecological roles (producers, grazers, predators, scavengers, pollinators, decomposers) in plausible proportions, and every species SHALL have a name and bestiary description.

#### Scenario: Food chain
- **WHEN** a biome contains predators
- **THEN** it also contains prey they can eat

### Requirement: Intelligent species
Intelligent species SHALL evolve from a lineage of their homeworld (or be committed to it by a higher level) and SHALL have physiology traits that later shape their culture: anatomy, senses, lifespan, reproduction, diet, social instinct and psionic potential.

#### Scenario: Body shapes culture
- **WHEN** an intelligent species is descended from flying animals
- **THEN** its anatomy includes wings

#### Scenario: Committed homeworld
- **WHEN** a higher level commits a species to a planet
- **THEN** that planet's generated life includes that species with consistent anatomy

### Requirement: Spread of species
Species that travel between worlds SHALL appear on other planets only where history placed them (colonies, migrations, exiles), keeping their homeworld traits.

#### Scenario: Colonists
- **WHEN** a commitment places a colony of a species on a planet
- **THEN** that species lives there with its homeworld anatomy alongside native life
