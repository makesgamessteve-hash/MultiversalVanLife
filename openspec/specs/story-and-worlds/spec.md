# story-and-worlds Specification

## Purpose
A rural person finds an old sentient van, Juniper, that travels between worlds. Every night they visit a place and help the people who live there.

## Requirements

### Requirement: Night one introduction
A new game SHALL start on the generated farm at night with the van parked at the gate; shortly after, the van SHALL call the player, and entering it the first time SHALL play Juniper's introduction and remember that the van was met.

#### Scenario: First visit
- **WHEN** the player uses the van door for the first time
- **THEN** the player is inside the van and the lines `van_intro_1` to `van_intro_6` are shown

### Requirement: Van interior and console
The van interior SHALL be much larger than the exterior and contain a console that offers tonight's signals, the logbook of visited lands (the current location disabled), a way home when away and a cancel entry.

#### Scenario: Travelling
- **WHEN** the player chooses a signal or a logbook entry at the console
- **THEN** the travel sound and camera shake play inside the van while the destination is generated, the outside world is replaced by the destination, the location is saved, and stepping outside puts the player next to the van's rear door

### Requirement: Interaction
The player SHALL interact with the nearest enabled interactable within its range that lies in front of them (within about 63 degrees of the view direction), shown with a prompt.

#### Scenario: Nothing in front
- **WHEN** the only interactable is behind the player
- **THEN** no prompt is shown and the interact action does nothing

### Requirement: Ending a night with milestones
Travelling home SHALL end the night, increase the night counter, save and show a title card; every third land helped SHALL be celebrated with a line from Juniper.

#### Scenario: Milestone
- **WHEN** the player returns home after helping their third land
- **THEN** `van_home` and `van_milestone` are shown

### Requirement: Driving the van
After arriving in a generated land, the player SHALL be able to drive the van around it from the driver's seat:
accelerating, braking, reversing and steering over the terrain, blocked by buildings, people and trees and by deep
water, seen from behind the van or through the windscreen. The van's door, lights and windows SHALL follow it, and its
parked place SHALL be remembered on later visits and after a restart.

#### Scenario: Driving away
- **WHEN** the player sits in the driver's seat and drives forward
- **THEN** the van moves through the land, the windows show the new view and getting up leaves the van parked there

#### Scenario: Remembered place
- **WHEN** the player parks the van somewhere else and comes back later
- **THEN** the van is where they parked it

#### Scenario: Not at home
- **WHEN** the player tries the seat at home or during a trip
- **THEN** the van does not move and Juniper says why
