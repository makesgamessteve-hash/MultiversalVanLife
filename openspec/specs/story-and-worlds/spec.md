# story-and-worlds Specification

## Purpose
A rural person finds an old sentient van, Juniper, that travels between worlds. Every night they visit a place and help the people who live there.

## Requirements
### Requirement: Night one introduction
A new game SHALL start on the farm at night with the van parked at the gate; shortly after, the van SHALL call the player, and entering it the first time SHALL play Juniper's introduction and remember that the van was met.

#### Scenario: First visit
- **WHEN** the player uses the van door for the first time
- **THEN** the interior loads and the lines `van_intro_1` to `van_intro_6` play

### Requirement: Van interior and console
The van interior SHALL be much larger than the exterior and contain a console that lists every registered destination (the current location disabled), a way home when away, and a cancel entry.

#### Scenario: Travelling
- **WHEN** the player chooses a destination at the console
- **THEN** the travel sound and camera shake play inside the van, the location is saved, and stepping outside loads the destination next to the van's rear door facing the scene

### Requirement: Ending a night
Travelling home SHALL end the night, increase the night counter, save, show a title card and, once every destination was helped, play Juniper's thank-you line.

#### Scenario: All worlds helped
- **WHEN** the player returns home after helping all destinations
- **THEN** `van_home` and `van_all_done` play

### Requirement: Destinations with quests
The base game SHALL include three destinations, each with characters and a quest that can be completed once and is remembered in the save: Lanternfen (catch fireflies and relight four lanterns), the Clockwork Bazaar (find three gears for Tock) and the Tidewater Library (return four books to the shelves).

#### Scenario: Completing Lanternfen
- **WHEN** the fourth lantern is lit
- **THEN** the fen is marked as helped and Old Wick thanks the player

### Requirement: Interaction
The player SHALL interact with the nearest enabled interactable within its range that lies in front of them (within about 63 degrees of the view direction), shown with a prompt.

#### Scenario: Nothing in front
- **WHEN** the only interactable is behind the player
- **THEN** no prompt is shown and the interact action does nothing
