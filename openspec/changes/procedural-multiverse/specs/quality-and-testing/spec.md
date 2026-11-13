# Spec Delta

## MODIFIED Requirements

### Requirement: Automated game tests
Every `tests/game/test_*.lua` file SHALL be run by CTest through the headless runner with a fresh save folder; tests drive the real game with input actions, touch events and simulated XR state and fail on any failed expectation, script error or timeout.

#### Scenario: Full quest
- **WHEN** a quest test runs for a quest template
- **THEN** it travels to a generated destination using that template, completes the quest through the game's own interactions and checks that the destination is marked as helped

## ADDED Requirements

### Requirement: Generation tests
Game tests SHALL check that generation is deterministic for a seed, that streaming keeps the number of entities and meshes bounded on a long walk, and that every base biome and quest template can be generated and completed.

#### Scenario: Long walk
- **WHEN** a test walks the player 500 m through a generated world
- **THEN** entity and mesh counts stay below fixed limits and no script errors occur
