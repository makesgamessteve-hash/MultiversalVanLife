# Spec Delta

## MODIFIED Requirements

### Requirement: Key/value save file
Progress SHALL be stored in a save folder in the platform's user data folder (or the folder given with `--save`) containing an index of sorted `key = value` lines (seed, night, location, flags) and data records for places and other structured progress.

#### Scenario: Continue
- **WHEN** a save exists and the player chooses Continue on the title screen
- **THEN** the index and every record are restored and the game resumes where the player left it

#### Scenario: Old save
- **WHEN** a save from before the save folder existed is continued
- **THEN** it is converted to the new format without losing progress

## ADDED Requirements

### Requirement: Safe saves
Saves SHALL be written atomically, so a crash never leaves a half-written record, and loaded without executing code.

#### Scenario: Crash while saving
- **WHEN** the game stops while a record is being written
- **THEN** the previous version of that record is still loadable

#### Scenario: Tampered record
- **WHEN** a record file is edited to contain code
- **THEN** loading it fails safely without running anything
