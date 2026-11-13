# Spec Delta

## Purpose

Gives every generated destination people to meet and a problem to solve, built from quest templates with generated characters, names and dialogue text.

## ADDED Requirements

### Requirement: One quest per destination
Every generated destination SHALL contain a settlement near the landing spot with a quest giver and one quest built from a template allowed by its biome.

#### Scenario: Arriving somewhere new
- **WHEN** the player steps out of the van at a new destination
- **THEN** a quest giver is within sight of the van and talking to them explains the problem

### Requirement: Quest templates
The base game SHALL provide at least these templates, each with a generated count and generated item names: relight lights (carry glowing things to dark lamps), gather parts (find items and bring them to the giver), return items (carry items to their places) and find a lost person (find someone far away and lead them back).

#### Scenario: Gathering
- **WHEN** the player has collected every item of a gather quest and talks to the giver
- **THEN** the quest is complete

#### Scenario: Lost person
- **WHEN** the player finds the lost person and walks back to the giver
- **THEN** the lost person follows the player and the quest completes on arrival

### Requirement: Reachable quest items
Quest items and targets SHALL be placed on walkable ground within a bounded distance of the settlement, independent of which chunks are currently loaded.

#### Scenario: Items beyond view
- **WHEN** a quest item lies in a chunk that has not been generated yet
- **THEN** it appears when that chunk is generated and it is not duplicated when the chunk is regenerated

### Requirement: Generated characters and dialogue
Characters SHALL get generated names, tinted sprites and dialogue text assembled from templates that mention their names, the place and the quest items; dialogue SHALL be shown as text without recorded voices.

#### Scenario: Talking to a villager
- **WHEN** the player talks to a villager who is not the quest giver
- **THEN** they say a generated line that uses the place or their own name

### Requirement: Remembered completion
A completed quest SHALL be stored in the save and SHALL stay completed when the destination is revisited; its giver SHALL thank the player instead of repeating the quest.

#### Scenario: Revisit after helping
- **WHEN** the player returns to a destination whose quest was completed
- **THEN** the quest items are not spawned again and the giver thanks the player
