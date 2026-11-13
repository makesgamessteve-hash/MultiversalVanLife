# Spec Delta

## Purpose

Turns each land's present-day tensions into quests with real stakeholders, local lore and lasting outcomes.

## ADDED Requirements

### Requirement: Quests from tensions
Every quest SHALL come from an active tension of the land, with a quest giver and other stakeholders who are real characters of that land, and its text SHALL use the land's lore (names, places, saints, holidays, history).

#### Scenario: Arriving through a signal
- **WHEN** the player steps out of the van at a land reached through a signal
- **THEN** a stakeholder of the signalled tension is within sight of the van and talking to them explains the problem in local terms

### Requirement: Quest templates
The base game SHALL provide quest templates that tensions can use, at least: relight lights, gather parts, return items, find a lost person, carry a message, mediate a dispute, escort someone and restore a failing source of magic or water; templates are filled with items, places and people from the land.

#### Scenario: Lost person
- **WHEN** the player finds the lost person and walks back to the giver
- **THEN** the lost person follows the player and the quest completes on arrival

#### Scenario: Mediation
- **WHEN** the player talks to both parties of a dispute and chooses a resolution
- **THEN** the quest completes with the chosen outcome

### Requirement: Choices with lasting outcomes
Quests SHALL allow different outcomes where the tension allows it (siding with one party, a compromise, failure or abandoning), and each outcome SHALL have lasting consequences recorded by the world memory.

#### Scenario: Taking a side
- **WHEN** the player resolves a water dispute in favour of the upstream village
- **THEN** the upstream village thrives and the downstream village resents the player on later visits

### Requirement: Reachable quest items
Quest items and targets SHALL be placed on walkable ground within a bounded distance of the quest giver, independent of which chunks are currently built, and never duplicated.

#### Scenario: Items beyond view
- **WHEN** a quest item lies in a chunk that has not been built yet
- **THEN** it appears when that chunk is built and it is not duplicated when the chunk is rebuilt

### Requirement: Generated dialogue
Characters SHALL speak lines assembled from templates using their culture's names, greetings, blessings, idioms and versions of history, their memory of the player, and current events; dialogue SHALL be text only.

#### Scenario: Blessing
- **WHEN** a villager of a moon-worshipping culture says farewell
- **THEN** the farewell can invoke their moon deity by name
