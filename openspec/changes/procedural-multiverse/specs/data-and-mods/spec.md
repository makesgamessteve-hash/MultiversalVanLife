# Spec Delta

## MODIFIED Requirements

### Requirement: Supported asset formats
The engine SHALL load TGA images (uncompressed and RLE; 8, 24 or 32 bit), PCM WAV sounds (8 or 16 bit, mono or stereo), MP3 sounds (mono or stereo), Wavefront OBJ meshes and MagicaVoxel `.vox` models.

#### Scenario: Voxel model
- **WHEN** a `.vox` file is loaded with a voxel size
- **THEN** the engine builds a mesh with hidden faces removed, converts Z-up to Y-up, centres it on X/Z and puts its base at y = 0

#### Scenario: MP3 music
- **WHEN** a script loads `music/title.mp3`
- **THEN** it is decoded to the same sound format as WAV files and can be played and looped

## ADDED Requirements

### Requirement: Mods override and extend generated content
The engine SHALL add every folder listed in `mods/mods.txt` as a data root with higher priority than the base game, and scripts SHALL be able to run each mod's `init.lua`.

#### Scenario: Overriding an asset
- **WHEN** an enabled mod contains `textures/grass.tga`
- **THEN** the game loads the mod's file instead of the base one

#### Scenario: Adding a biome
- **WHEN** an enabled mod's `init.lua` registers a biome or a quest template
- **THEN** generated destinations can use it and the player can travel there through the console

#### Scenario: Invalid mod names
- **WHEN** `mods.txt` lists a name containing `/` or `..`
- **THEN** that entry is ignored with a warning

## REMOVED Requirements

### Requirement: Mods override and extend the base game
**Reason**: Fixed destinations no longer exist; mods extend the generator instead. Replaced by "Mods override and extend generated content".
**Migration**: Register a biome or quest template in the mod's `init.lua` instead of a world with `destination = true`.
