# Spec Delta

## Purpose

Defines the generation hierarchy of the cosmos (multiverse, universe, galaxy, star cluster, star system, planet, continent, country, land): how places are addressed, generated lazily and deterministically, kept consistent across levels, and explained through causal links.

## ADDED Requirements

### Requirement: Hierarchical addresses
Every generated place SHALL have an address listing its index on each level from the multiverse down (universe, galaxy, star cluster, star system, planet, continent, country, land), and its seed SHALL be derived only from the save's multiverse seed and that address.

#### Scenario: Same address, same place
- **WHEN** the same address is generated twice from the same multiverse seed
- **THEN** both results are identical in every generated field

### Requirement: Lazy path generation
Travelling to or inspecting a place SHALL generate that place and only those of its ancestors that were not generated yet; siblings and descendants SHALL only be generated as summaries their parent needs.

#### Scenario: Travelling to a land
- **WHEN** the player travels to a land in a galaxy that was never generated
- **THEN** the universe, galaxy, cluster, star system, planet, continent and country on its path are generated in detail, and no other planet, continent or country is generated in detail

### Requirement: Order independence
Generation results SHALL NOT depend on which places were generated before or in which order.

#### Scenario: Two travel orders
- **WHEN** one test visits place A then place B and another visits B then A from the same seed
- **THEN** A and B are identical in both runs

### Requirement: Commitments between levels
When a level generates facts about places inside it (such as a species' homeworld, a capital, a battle site, a birthplace or an artifact's location), it SHALL record them as commitments on the child's address, and the child's generation SHALL honour every commitment before adding its own content.

#### Scenario: Homeworld promised by the galaxy
- **WHEN** the galaxy commits that planet 2 of star system 5 in cluster 33 is the homeworld of a species
- **THEN** generating that planet produces a life-bearing world whose intelligent species is that species

#### Scenario: Battle site
- **WHEN** a galaxy-level war records a battle in a star system
- **THEN** that system, once generated, contains the battle in its history and its traces (wrecks or ruins) where the battle placed them

### Requirement: Shared things live at the common ancestor
Anything that involves more than one child of a place (a faction across clusters, a species on several planets, a religion spanning countries, a trade route) SHALL be defined on the lowest level that contains all of them, and descendants SHALL refer to it instead of redefining it.

#### Scenario: Interstellar empire
- **WHEN** an empire spans three star clusters
- **THEN** it is defined at galaxy level and each cluster refers to the same empire, rulers and history

### Requirement: Causal links
Every generated fact SHALL record the facts it was derived from (for example climate from latitude and terrain, a holiday from an eclipse and a founding event), so the game can answer why something is as it is.

#### Scenario: Asking why
- **WHEN** the codex shows a tradition
- **THEN** it can list the religious, historical and environmental facts that caused it

### Requirement: Universe metaphysics
Each universe SHALL have generated laws: whether magic exists and its source (life, stars, tectonics or belief), psionic strength, the kind of faster-than-light travel (none, gates or jumps), whether gods can be real, and its age and cosmic eras; all lower levels SHALL derive their magic, technology and religion from these laws.

#### Scenario: Belief-fed magic
- **WHEN** a universe's magic is fed by belief
- **THEN** widely worshipped gods in it can manifest in history and its strongest magic appears near major holy sites

#### Scenario: No faster-than-light travel
- **WHEN** a universe has no faster-than-light travel
- **THEN** no faction in it holds territory in more than one star system except through generation ships or magic

### Requirement: Cosmic structure
Each level SHALL generate the layout of its children: a universe's galaxy density with notable galaxies, a galaxy's shape (spiral, barred, elliptical, irregular or ring) with clusters placed along it, a cluster's stars in 3D with travel lanes, and a star system's stars, planets, belts and moons on orbits.

#### Scenario: Galaxy shape matters
- **WHEN** a cluster lies in a spiral arm rather than the old core
- **THEN** its stars are younger and richer in heavy elements and planets there are more likely to be rocky

### Requirement: History stored as eras
Every level's history SHALL be stored as named eras with snapshots of the place's state at each era's end, so a place's past state can be reconstructed; the game SHALL show only the present for now.

#### Scenario: Ruins have a past
- **WHEN** a land contains ruins of a fallen kingdom
- **THEN** the stored eras contain the kingdom's state when it stood

### Requirement: Generation budgets
Generation SHALL run incrementally within a per-frame time budget, start when a signal is chosen and finish during the travel vortex at the latest, and each level SHALL have fixed caps on its counts (for example events, individuals and factions) so time and memory stay bounded.

#### Scenario: Travelling to a new galaxy on the web
- **WHEN** the player chooses a signal leading into an ungenerated galaxy in the web build
- **THEN** the frame rate stays above 30 FPS and the destination is ready when the travel sequence ends

### Requirement: Versioned generation
Every generated place SHALL record the generator version and the active mods it was generated with; newly generated places use the current version while stored places keep their recorded content.

#### Scenario: Game update
- **WHEN** the generator changes in a game update
- **THEN** places the player already visited stay as they were and only new places use the new generator
