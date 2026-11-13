# Spec Delta

## Purpose

Makes the cosmos remember the player: visited places are stored permanently, every action there has a lasting effect, time passes between visits, consequences spread, and returning shows what the player changed.

## ADDED Requirements

### Requirement: Visited places are stored
When the player first arrives in a land, the land's generated description (terrain parameters, settlements, buildings, people, creatures, items, tensions and lore) and the summaries of its ancestors SHALL be stored in the save, and later visits SHALL use the stored description instead of regenerating it.

#### Scenario: Return after a game update
- **WHEN** the player returns to a land after the generator changed
- **THEN** the land, its people and its buildings are exactly as stored

### Requirement: Every action is remembered
Every action that changes the world SHALL be recorded permanently: items taken, carried, dropped or given; objects lit, opened, repaired or broken; quests accepted, completed, failed or abandoned; dialogue choices; help or harm done to people; and anything the player built or placed.

#### Scenario: Dropped item
- **WHEN** the player drops a carried item in a land and leaves
- **THEN** the item lies at the same spot when the player returns

#### Scenario: Partial quest
- **WHEN** the player lights two of four lanterns and leaves
- **THEN** the two lanterns are still lit on return and the quest continues from there

### Requirement: People remember the player
Characters SHALL remember meeting the player, what the player did for or against them and their community, and SHALL greet and treat the player accordingly on later meetings.

#### Scenario: Greeting a friend
- **WHEN** the player returns to a villager they helped
- **THEN** the villager greets them by the name they know them by and mentions the help

### Requirement: Time passes between visits
Each visited land SHALL keep its own clock; when the player returns, the time since the last visit SHALL be simulated so that consequences develop (settlements grow or decline, children grow up, crops recover, tensions resolve or worsen, new tensions arise from the player's actions).

#### Scenario: Restored well
- **WHEN** the player repaired a village's well and returns ten nights later
- **THEN** the village shows the consequences (for example new fields or more villagers) and people talk about the change

### Requirement: Consequences spread
The player's notable deeds SHALL become events in the land's history and SHALL spread as rumours and legends to neighbouring lands and, for great deeds, to the country, planet and beyond, changing faction attitudes and reputation.

#### Scenario: Rumour in the next valley
- **WHEN** the player ended a feud in one land and then visits a neighbouring land of the same country
- **THEN** people there have heard of it and some refer to the player by the title the story gave them

### Requirement: Visible marks
Lasting consequences SHALL be visible in the world where they happened: restored or ruined buildings, new monuments, shrines or murals of the Wanderer, renamed places and festivals founded in the player's honour.

#### Scenario: Monument
- **WHEN** the player saved a town from disaster and returns much later
- **THEN** the town may contain a monument depicting the player and the van

### Requirement: The Wanderer's chronicle
The codex SHALL contain a chronicle of the player's deeds with the places, people and consequences they led to, updated whenever a consequence develops.

#### Scenario: Consequence logged
- **WHEN** a consequence of an earlier deed develops during a revisit
- **THEN** the chronicle entry for that deed lists the new consequence

### Requirement: Revisits happen
Places the player visited SHALL stay reachable from the van's logbook, and signals SHALL regularly call the player back to visited places when consequences of their actions create new needs or invitations.

#### Scenario: Called back
- **WHEN** a land the player helped develops a new tension caused by that help
- **THEN** a later night's signals include that land
