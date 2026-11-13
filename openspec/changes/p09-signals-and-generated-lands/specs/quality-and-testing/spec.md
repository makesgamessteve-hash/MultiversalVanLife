# Spec Delta

## MODIFIED Requirements

### Requirement: Automated game tests
Every `tests/game/test_*.lua` file SHALL be run by CTest through the headless runner with a fresh save folder; tests drive the real game with input actions, touch events and simulated XR state and fail on any failed expectation, script error or timeout.

#### Scenario: Full quest
- **WHEN** a quest test runs for a quest template
- **THEN** it travels to a generated land using that template, completes the quest through the game's own interactions and checks that the land is marked as helped
