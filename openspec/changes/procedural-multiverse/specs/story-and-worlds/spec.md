# Spec Delta

## MODIFIED Requirements

### Requirement: Night one introduction
A new game SHALL start on the generated farm at night with the van parked at the gate; shortly after, the van SHALL call the player, and entering it the first time SHALL play Juniper's introduction and remember that the van was met.

#### Scenario: First visit
- **WHEN** the player uses the van door for the first time
- **THEN** the player is inside the van and the lines `van_intro_1` to `van_intro_6` are shown

### Requirement: Van interior and console
The van interior SHALL be much larger than the exterior and contain a console that lists the generated destinations offered tonight and previously visited destinations (the current location disabled), a way home when away, and a cancel entry.

#### Scenario: Travelling
- **WHEN** the player chooses a destination at the console
- **THEN** the travel sound and camera shake play inside the van, the outside world is replaced by the destination, the location is saved, and stepping outside puts the player next to the van's rear door facing the settlement

## ADDED Requirements

### Requirement: Ending a night with milestones
Travelling home SHALL end the night, increase the night counter, save and show a title card; every third destination helped SHALL be celebrated with a line from Juniper.

#### Scenario: Milestone
- **WHEN** the player returns home after helping their third destination
- **THEN** `van_home` and `van_milestone` are shown

## REMOVED Requirements

### Requirement: Ending a night
**Reason**: With an endless multiverse there is no "all destinations helped"; replaced by "Ending a night with milestones".
**Migration**: None needed.

### Requirement: Destinations with quests
**Reason**: The handmade destinations are replaced by generated destinations and template quests.
**Migration**: See the `multiverse-generation` and `generated-quests` capabilities. Saves that refer to the removed destinations continue at home.
