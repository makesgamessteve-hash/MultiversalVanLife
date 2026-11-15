# van-interior Specification

## Purpose
Makes the inside of the van a home without end: a cosy core house with a cab, rooms that go on, wings for the peoples visited and a garden of its own.

## Requirements

### Requirement: A home inside the van
The van interior SHALL be a house at human scale with a cab, a hall, a cross gallery, a library, a kitchen, a living
room, a conservatory and, up a flight of stairs, a landing, a bedroom and a bathroom, each furnished for its use and
all reachable from the hall on foot.

#### Scenario: Walking through the house
- **WHEN** the player walks from the hall to every room of the core
- **THEN** each room is reached through doorways and stairs without passing through walls or furniture

#### Scenario: Upstairs
- **WHEN** the player walks up the stairs in the hall
- **THEN** they stand on the landing, and the walls of the ground floor do not block them there

### Requirement: Not a time machine
The interior SHALL have no central console room: travel is chosen at the cab's radio and atlas.

#### Scenario: Looking for the console
- **WHEN** the player looks around the cab and the hall
- **THEN** they find a dashboard radio and a road atlas, and no console
