# Spec Delta

## Purpose

Keeps the player's home real: a fixed Prime universe containing the real Earth, whose history and beliefs are not simulated, and a generated farm where the story begins.

## ADDED Requirements

### Requirement: Fixed Prime universe
The Prime universe SHALL be fixed, not generated: physics like ours without magic or psionics, the Milky Way, the Sun with its real planets and the Moon, with real orbital data used for the sky.

#### Scenario: Night sky at home
- **WHEN** the player looks at the sky at the farm
- **THEN** the Moon shows a phase and the band of the Milky Way is visible

### Requirement: Earth is not simulated
Earth's history, peoples, religions and cultures SHALL NOT be generated, simulated or depicted beyond the player's immediate rural surroundings.

#### Scenario: No generated Earth lore
- **WHEN** the codex is opened at home
- **THEN** it contains no generated history, factions or religions of Earth

### Requirement: Earth is a quiet world
Generated histories SHALL NOT place events on Earth or in the Prime universe; in the cosmos's lore Earth is a quiet world the rest of the multiverse has overlooked, and signals SHALL never lead into the Prime universe except home.

#### Scenario: Signals avoid Prime
- **WHEN** signals are generated on any night
- **THEN** none of them lies in the Prime universe

### Requirement: Generated farm
The farm and its surroundings SHALL be generated from the save's seed: farmhouse, barn, fields, roads, trees and the neighbour's name and look vary between journeys, while the farmhouse, the gate and the van's parking spot stay recognisable; the farm is a visited place with world memory like any other.

#### Scenario: Two journeys
- **WHEN** two new journeys are started
- **THEN** their farms differ in layout while both contain a farmhouse, a neighbour and the van at the gate
