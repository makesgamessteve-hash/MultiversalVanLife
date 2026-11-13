# save-games Specification

## Purpose
Story progress (nights, the van, helped worlds and the current location) survives restarts on every platform.

## Requirements
### Requirement: Key/value save file
Progress SHALL be stored as sorted `key = value` lines in `savegame.ini` (name configurable) in the platform's user data folder, or the folder given with `--save`.

#### Scenario: Continue
- **WHEN** a save exists and the player chooses Continue on the title screen
- **THEN** the night count, met-van flag, current location and helped worlds are restored and the game resumes in the van (or on the farm if the van was not met yet)

### Requirement: Persistent web saves
The web build SHALL mount IndexedDB at `/save` before the game starts and synchronise it after every save.

#### Scenario: Reloading the page
- **WHEN** the player reloads the browser tab after saving
- **THEN** Continue is available with the saved progress
