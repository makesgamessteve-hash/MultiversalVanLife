# data-and-mods Specification

## Purpose
All assets (scripts, shaders, textures, models, voxels, sounds, voice lines, configuration) live in folders next to the executable and are never compiled into it, so the game can be modified and extended.

## Requirements

### Requirement: External data folder
The game SHALL load every asset from the `game/` folder next to the executable (or the folder given with `--data`) through a virtual file system.

#### Scenario: Default data location
- **WHEN** the desktop game starts without `--data`
- **THEN** it reads `<executable dir>/game/config/engine.ini` and `<executable dir>/game/scripts/main.lua`

#### Scenario: Web build
- **WHEN** the web build starts
- **THEN** the same `game/` folder is available at `/game` from the preloaded data package

### Requirement: Safe relative paths
The virtual file system SHALL reject absolute paths and paths containing `..` components.

#### Scenario: Escape attempt
- **WHEN** a script requests `../secret.txt`
- **THEN** the request fails and no file outside the data roots is read

### Requirement: Supported asset formats
The engine SHALL load TGA images (uncompressed and RLE; 8, 24 or 32 bit), PCM WAV sounds (8 or 16 bit, mono or stereo), MP3 sounds (mono or stereo), Wavefront OBJ meshes and MagicaVoxel `.vox` models.

#### Scenario: Voxel model
- **WHEN** a `.vox` file is loaded with a voxel size
- **THEN** the engine builds a mesh with hidden faces removed, converts Z-up to Y-up, centres it on X/Z and puts its base at y = 0

#### Scenario: MP3 music
- **WHEN** a script loads `music/title.mp3`
- **THEN** it is decoded to the same sound format as WAV files and can be played and looped

### Requirement: Mods override and extend generated content
The engine SHALL add every folder listed in `mods/mods.txt` as a data root with higher priority than the base game, and scripts SHALL be able to run each mod's `init.lua`; mods SHALL be able to register generation passes and content tables (such as land styles, quest templates and name lexicons).

#### Scenario: Overriding an asset
- **WHEN** an enabled mod contains `textures/grass.tga`
- **THEN** the game loads the mod's file instead of the base one

#### Scenario: Adding generation content
- **WHEN** an enabled mod's `init.lua` registers a new quest template
- **THEN** newly generated lands can use it

#### Scenario: Invalid mod names
- **WHEN** `mods.txt` lists a name containing `/` or `..`
- **THEN** that entry is ignored with a warning
