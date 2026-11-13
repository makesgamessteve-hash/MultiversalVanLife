# Spec Delta

## Purpose

Makes the cosmos remember the player: visited places are stored permanently, every action there has a lasting effect, and returning shows what the player changed.

## ADDED Requirements

### Requirement: Visited places are stored
When the player first arrives in a land, the land's generated description (terrain parameters, settlements, buildings, people, items, troubles and lore) and the summaries of its ancestors SHALL be stored in the save, and later visits SHALL use the stored description instead of regenerating it.

#### Scenario: Return after a game update
- **WHEN** the player returns to a land after the generator changed
- **THEN** the land, its people and its buildings are exactly as stored

### Requirement: Every action is remembered
Every action that changes the world SHALL be recorded permanently: items taken, carried, dropped or given; objects lit, opened, repaired or broken; quests accepted, completed, failed or abandoned and their progress; and anything the player built or placed.

#### Scenario: Dropped item
- **WHEN** the player drops a carried item in a land and leaves
- **THEN** the item lies at the same spot when the player returns

#### Scenario: Partial quest
- **WHEN** the player lights two of four lanterns and leaves
- **THEN** the two lanterns are still lit on return and the quest continues from there

### Requirement: Rebuilt chunks keep their changes
Chunks of a visited land SHALL apply every recorded change whenever they are built, during the same visit and on later visits.

#### Scenario: Walking back
- **WHEN** the player takes an item, walks far away so its chunk is discarded and walks back
- **THEN** the item is still gone
