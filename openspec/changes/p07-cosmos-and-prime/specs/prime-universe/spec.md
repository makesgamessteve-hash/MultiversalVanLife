# Spec Delta

## Purpose

Keeps the player's home real: a fixed Prime universe containing the real Earth, whose history and beliefs are not simulated, with a generated farm where the story begins.

## ADDED Requirements

### Requirement: Fixed Prime universe
The Prime universe SHALL be fixed, not generated: physics like ours without magic or psionics, the Milky Way, the Sun with its real planets and the Moon, with real orbital data.

#### Scenario: Prime data
- **WHEN** the Prime universe's data is queried
- **THEN** it contains the Sun, the eight planets and the Moon with their real orbital periods and no magic or psionics

### Requirement: Earth is not simulated
Earth's history, peoples, religions and cultures SHALL NOT be generated, simulated or depicted beyond the player's immediate rural surroundings.

#### Scenario: No generated Earth lore
- **WHEN** generation is asked for Earth's history, factions or religions
- **THEN** it returns none

### Requirement: Prime is excluded from generation
The multiverse generator SHALL never generate content inside the Prime universe except the farm and its surroundings.

#### Scenario: Universe zero
- **WHEN** the multiverse generator enumerates universes
- **THEN** index 0 is always the fixed Prime universe
