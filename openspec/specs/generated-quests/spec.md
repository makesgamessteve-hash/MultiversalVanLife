# generated-quests Specification

## Purpose
Gives every land reached through a signal people to meet and a problem to solve, built from quest templates with generated characters, names and text.

## Requirements

### Requirement: Land quests
Every land reached through a signal SHALL contain a settlement near the landing spot with a quest giver for the signalled trouble.

#### Scenario: Arriving through a signal
- **WHEN** the player steps out of the van at a land reached through a signal
- **THEN** a quest giver is within sight of the van and talking to them explains the problem

### Requirement: Quest templates
The base game SHALL provide at least these templates, each with generated counts, item names and text: relight lights (carry glowing things to dark lamps), gather parts (find items and bring them to the giver), return items (carry items to their places) and find a lost person (find someone far away and lead them back).

#### Scenario: Gathering
- **WHEN** the player has collected every item of a gather quest and talks to the giver
- **THEN** the quest is complete

#### Scenario: Lost person
- **WHEN** the player finds the lost person and walks back to the giver
- **THEN** the lost person follows the player and the quest completes on arrival

### Requirement: Reachable quest items
Quest items and targets SHALL be placed on walkable ground within a bounded distance of the quest giver, independent of which chunks are currently built, and never duplicated.

#### Scenario: Items beyond view
- **WHEN** a quest item lies in a chunk that has not been built yet
- **THEN** it appears when that chunk is built and it is not duplicated when the chunk is rebuilt
