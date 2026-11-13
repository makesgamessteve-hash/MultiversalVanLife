# Spec Delta

## Purpose

Makes the van's bigger-on-the-inside interior part of the world it is parked in, with windows that look out at that world.

## ADDED Requirements

### Requirement: Interior in the world scene
The van interior SHALL exist in the same scene as the current world, so entering and leaving the van moves the player without loading another world.

#### Scenario: Stepping outside
- **WHEN** the player uses the interior door
- **THEN** they stand behind the van in the current world immediately, without a loading fade

### Requirement: Windows are portals
The interior SHALL have windows that show the world outside as seen from the matching place on the van's exterior, updating live and following the van's position and heading.

#### Scenario: Looking out
- **WHEN** the van is parked facing a settlement and the player looks through a side window
- **THEN** the settlement is visible through the window from the matching angle

#### Scenario: Different location
- **WHEN** the van has travelled to another destination
- **THEN** the windows show the new destination

### Requirement: Travel view
While travelling, the windows SHALL show an animated multiversal vortex instead of a world.

#### Scenario: During travel
- **WHEN** the player chooses a destination at the console
- **THEN** the windows show the vortex until the van has arrived
