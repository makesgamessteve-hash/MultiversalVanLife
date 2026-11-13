# multiverse-generation Specification

## Purpose
Defines the generation hierarchy of the cosmos (multiverse, universe, galaxy, star cluster, star system, planet, continent, country, land): how places are addressed, generated lazily and deterministically, kept consistent across levels, and explained through causal links.

## Requirements

### Requirement: Hierarchical addresses
Every generated place SHALL have an address listing its index on each level from the multiverse down (universe, galaxy, star cluster, star system, planet, continent, country, land), and its seed SHALL be derived only from the save's multiverse seed and that address.

#### Scenario: Same address, same place
- **WHEN** the same address is generated twice from the same multiverse seed
- **THEN** both results are identical in every generated field

### Requirement: Lazy path generation
Requesting a place SHALL generate that place and only those of its ancestors that were not generated yet; siblings and descendants SHALL only be generated as summaries their parent needs.

#### Scenario: Deep request
- **WHEN** a land deep in an ungenerated branch is requested
- **THEN** exactly the nodes on its path are generated in detail and no sibling is generated in detail

### Requirement: Order independence
Generation results SHALL NOT depend on which places were generated before or in which order.

#### Scenario: Two orders
- **WHEN** one run generates place A then place B and another generates B then A from the same seed
- **THEN** A and B are identical in both runs

### Requirement: Commitments between levels
When a level generates facts about places inside it (such as a homeworld, a capital, a battle site, a birthplace or an artifact's location), it SHALL record them as commitments on the child's address, and the child's generation SHALL honour every commitment before adding its own content.

#### Scenario: Committed fact
- **WHEN** a parent commits that a child contains a specific site
- **THEN** generating the child produces that site

### Requirement: Shared things live at the common ancestor
Anything that involves more than one child of a place (a faction, a species, a religion, a trade route) SHALL be defined on the lowest level that contains all of them, and descendants SHALL refer to it instead of redefining it.

#### Scenario: Shared faction
- **WHEN** a faction spans three children of a place
- **THEN** it is defined on that place and each child refers to the same faction

### Requirement: Causal links
Every generated fact SHALL record the facts it was derived from, so the game can answer why something is as it is.

#### Scenario: Asking why
- **WHEN** a generated fact is queried for its causes
- **THEN** the facts it was derived from are listed and can be followed further

### Requirement: Generation budgets
Generation SHALL run incrementally within a per-frame time budget and each level SHALL have fixed caps on its counts, so frame time and memory stay bounded.

#### Scenario: Large node
- **WHEN** a node whose generation takes longer than one frame is requested
- **THEN** it is generated over several frames while the game keeps rendering within the budget

### Requirement: Versioned generation
Every generated place SHALL record the generator version and the active mods it was generated with.

#### Scenario: Version recorded
- **WHEN** a place is generated
- **THEN** its data lists the generator version and the active mods
