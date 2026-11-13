# Spec Delta

## MODIFIED Requirements

### Requirement: Van interior and console
The van interior SHALL be much larger than the exterior and contain a console that offers tonight's signals, the logbook of visited lands (the current location disabled), a way home when away and a cancel entry.

#### Scenario: Travelling
- **WHEN** the player chooses a signal or a logbook entry at the console
- **THEN** the travel sound and camera shake play inside the van while the destination is generated, the outside world is replaced by the destination, the location is saved, and stepping outside puts the player next to the van's rear door

## ADDED Requirements

### Requirement: Ending a night with milestones
Travelling home SHALL end the night, increase the night counter, save and show a title card; every third land helped SHALL be celebrated with a line from Juniper.

#### Scenario: Milestone
- **WHEN** the player returns home after helping their third land
- **THEN** `van_home` and `van_milestone` are shown

## REMOVED Requirements

### Requirement: Destinations with quests
**Reason**: The handmade destinations are replaced by generated lands reached through signals.
**Migration**: See `signals-and-codex` and `generated-quests`. Saves located at a removed destination continue at home.

### Requirement: Ending a night
**Reason**: In an endless cosmos there is no "all destinations helped"; replaced by "Ending a night with milestones".
**Migration**: None needed.
