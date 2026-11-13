# prime-universe Specification

## Purpose
Keeps the player's home real: a fixed Prime universe containing the real Earth, whose history and beliefs are not simulated, with a generated farm where the story begins.

## Requirements

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

### Requirement: Generated farm
The farm and its surroundings SHALL be generated from the save's seed: farmhouse, barn, fields, roads, trees and the neighbour's name and look vary between journeys, while the farmhouse, the gate and the van's parking spot stay recognisable.

#### Scenario: Two journeys
- **WHEN** two new journeys are started
- **THEN** their farms differ in layout while both contain a farmhouse, a neighbour and the van at the gate

### Requirement: Home sky
The farm's sky SHALL show the real Moon with its current phase and the band of the Milky Way.

#### Scenario: Night sky at home
- **WHEN** the player looks at the sky at the farm
- **THEN** the Moon shows a phase and the band of the Milky Way is visible
