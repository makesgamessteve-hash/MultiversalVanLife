# Spec Delta

## MODIFIED Requirements

### Requirement: Automated game tests
Every `tests/game/test_*.lua` file SHALL be run by CTest through the headless runner with a fresh save folder; tests drive the real game with input actions, touch events and simulated XR state and fail on any failed expectation, script error or timeout.

#### Scenario: Full quest
- **WHEN** a quest test runs for a quest template
- **THEN** it travels to a generated land using that template, completes the quest through the game's own interactions and checks that the outcome is recorded by the world memory

## ADDED Requirements

### Requirement: Generation determinism tests
Tests SHALL check that generation is deterministic for a seed on every CI platform (comparing stored fingerprints of generated places) and independent of the order in which places are generated.

#### Scenario: Fingerprint mismatch
- **WHEN** a platform produces a different fingerprint for a reference address
- **THEN** CI fails on that platform

### Requirement: Consistency and plausibility checks
A consistency checker SHALL verify generated places: every commitment honoured, no references to missing entities, individuals' deeds within their lifetimes, events in chronological order, rivers flowing downhill, climate consistent with latitude and altitude; tests SHALL run it over many seeds.

#### Scenario: Broken commitment
- **WHEN** a generator change leaves a committed homeworld without its species
- **THEN** the consistency test fails naming the commitment

### Requirement: Variety and budget tests
Tests SHALL generate places from at least 200 seeds and check variety statistics (biomes, species body plans, religion sources, tech levels, tension types) and that every level stays within its time and count budgets.

#### Scenario: Monotony
- **WHEN** more than half of the generated planets share one biome distribution
- **THEN** the variety test fails

### Requirement: Persistence tests
Game tests SHALL check that visited places are stored, that recorded changes survive leaving, restarting and game updates, and that time between visits produces consequences.

#### Scenario: Remembered lantern
- **WHEN** a test lights a lantern, leaves, restarts the game and returns
- **THEN** the lantern is still lit

### Requirement: World bible export
A tool SHALL export any address as readable Markdown describing everything generated there and on its path, for review and tuning.

#### Scenario: Reviewing a planet
- **WHEN** the exporter runs for a planet address
- **THEN** it writes a document covering the planet's physics, geography, life, peoples, religions, history and present-day tensions
