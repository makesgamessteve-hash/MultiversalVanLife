# Spec Delta

## ADDED Requirements

### Requirement: Persistence tests
Game tests SHALL check that visited places are stored and that recorded changes survive leaving, restarting and generator changes.

#### Scenario: Remembered lantern
- **WHEN** a test lights a lantern, leaves, restarts the game and returns
- **THEN** the lantern is still lit
