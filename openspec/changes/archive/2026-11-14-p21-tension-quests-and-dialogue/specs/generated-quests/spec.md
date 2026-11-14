# Spec Delta

## ADDED Requirements

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
