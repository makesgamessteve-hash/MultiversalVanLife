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

### Requirement: Quests from tensions
Every quest SHALL come from an active tension of the land, with a quest giver and other stakeholders who are real characters of that land, and its text SHALL use the land's lore (names, places, saints, holidays, history).

#### Scenario: Lore in the quest
- **WHEN** a quest giver explains a quest
- **THEN** the text names at least one local place, person, holiday or historic event related to the tension

### Requirement: Advanced quest templates
The base game SHALL also provide these templates: carry a message, mediate a dispute, escort someone and restore a failing source of magic or water.

#### Scenario: Mediation
- **WHEN** the player talks to both parties of a dispute and chooses a resolution
- **THEN** the quest completes with the chosen outcome

### Requirement: Choices with lasting outcomes
Quests SHALL allow different outcomes where the tension allows it (siding with one party, a compromise, failure or abandoning), and each outcome SHALL have lasting consequences recorded by the world memory.

#### Scenario: Taking a side
- **WHEN** the player resolves a water dispute in favour of the upstream village
- **THEN** the upstream village is grateful and the downstream village resents the player on later visits

### Requirement: Culture-based dialogue
Characters SHALL speak lines assembled from templates using their culture's names, greetings, blessings, idioms and versions of history, their memory of the player, and current events; dialogue SHALL be text only.

#### Scenario: Blessing
- **WHEN** a villager of a moon-worshipping culture says farewell
- **THEN** the farewell can invoke their moon deity by name
