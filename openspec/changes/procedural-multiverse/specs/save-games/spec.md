# Spec Delta

## MODIFIED Requirements

### Requirement: Key/value save file
Progress SHALL be stored as sorted `key = value` lines in `savegame.ini` (name configurable) in the platform's user data folder, or the folder given with `--save`.

#### Scenario: Continue
- **WHEN** a save exists and the player chooses Continue on the title screen
- **THEN** the multiverse seed, night count, met-van flag, current location, visited destinations and completed quests are restored and the game resumes in the van (or on the farm if the van was not met yet)

#### Scenario: Old save
- **WHEN** a save from before the multiverse seed existed is continued
- **THEN** a seed is created for it and the player resumes at home
