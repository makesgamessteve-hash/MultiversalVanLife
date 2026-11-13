# Spec Delta

## ADDED Requirements

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

## REMOVED Requirements

### Requirement: Mods override and extend the base game
**Reason**: Fixed destinations no longer exist; mods extend the generator instead. Replaced by "Mods override and extend generated content".
**Migration**: Register generation content in the mod's `init.lua` instead of a world with `destination = true`.
