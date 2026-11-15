# Spec Delta

## ADDED Requirements

### Requirement: An endless house
Beyond the core the house SHALL go on without end in blocks of generated rooms, the same in every session of a game,
every room reachable on foot from the core.

#### Scenario: Far from the hall
- **WHEN** the player walks a kilometre in one direction through the house
- **THEN** rooms keep coming, the rooms behind are released and the way back leads to the hall

#### Scenario: Same house
- **WHEN** the same game is loaded again
- **THEN** every block has the same rooms
