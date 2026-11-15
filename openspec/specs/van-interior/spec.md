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

### Requirement: An endless house
Beyond the core the house SHALL go on without end in blocks of generated rooms, the same in every session of a game,
every room reachable on foot from the core.

#### Scenario: Far from the hall
- **WHEN** the player walks a kilometre in one direction through the house
- **THEN** rooms keep coming, the rooms behind are released and the way back leads to the hall

#### Scenario: Same house
- **WHEN** the same game is loaded again
- **THEN** every block has the same rooms

### Requirement: Souvenir wings
Every people the player has visited SHALL have a wing of the house near the core, in the order of the visits, built
in their architecture (materials, colours, doorways and ornaments) and showing one of them as a statue, plants of
their land and their name.

#### Scenario: After a visit
- **WHEN** the player has visited a land of a people for the first time and is back in the van
- **THEN** a block next to the core has become their wing and Juniper mentions it

#### Scenario: Remembered
- **WHEN** the game is loaded again
- **THEN** the wings are where they were
