# Spec Delta

## MODIFIED Requirements

### Requirement: Key/value save file
Progress SHALL be stored in a save folder in the platform's user data folder (or the folder given with `--save`) containing an index of sorted `key = value` lines (seed, night, location, flags) and one data record per visited place and per generated ancestor summary.

#### Scenario: Continue
- **WHEN** a save exists and the player chooses Continue on the title screen
- **THEN** the multiverse seed, night count, met-van flag, current location, logbook, codex, chronicle and every visited place with its recorded changes are restored, and the game resumes in the van (or on the farm if the van was not met yet)

#### Scenario: Old save
- **WHEN** a save from before the save folder existed is continued
- **THEN** it is converted to the new format, a seed is created for it and the player resumes at home

## ADDED Requirements

### Requirement: Safe and compact saves
Saves SHALL be written atomically (a crash never leaves a half-written record), loaded without executing code, and kept compact by storing descriptions and changes rather than geometry.

#### Scenario: Crash while saving
- **WHEN** the game stops while a place record is being written
- **THEN** the previous version of that record is still loadable

#### Scenario: Many visits
- **WHEN** the player has visited 200 lands
- **THEN** the save folder stays below 20 MB
