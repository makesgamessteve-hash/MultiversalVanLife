# Spec Delta

## ADDED Requirements

### Requirement: Collider height
A solid entity with a height SHALL block movement only for feet between its base (less 0.4 m) and its top,
so floors of a building stacked above each other do not block each other.

#### Scenario: A wall upstairs
- **WHEN** a wall with a height of 3.5 m stands on a floor 3.6 m above the player's feet
- **THEN** the player walks under it without being blocked
