# scripting-api Specification

## Purpose
Gameplay is written in Lua 5.4. The engine exposes a single `mvl` table for resources, entities, camera, environment, collision, input, audio, UI, configuration and saves, and calls hooks on the global `game` table.

## Requirements
### Requirement: Game hooks
The engine SHALL call `game.init()` once after loading `engine.main_script`, `game.update(dt)` every fixed tick, `game.draw_ui()` every frame and `game.shutdown()` on exit, skipping hooks that are not defined.

#### Scenario: Missing main script
- **WHEN** the configured main script does not exist
- **THEN** engine initialisation fails with a message naming the script

### Requirement: Module loading through the data folders
`require` SHALL resolve module names to `scripts/<name with dots as slashes>.lua` through the virtual file system, and `dofile` SHALL read from the data folders.

#### Scenario: Requiring a library
- **WHEN** a script calls `require("lib.player")`
- **THEN** `scripts/lib/player.lua` is loaded from the highest priority data root

### Requirement: Sandbox
The Lua environment SHALL NOT expose the `io` library, `loadfile` or the process-control and file functions of `os` (`execute`, `exit`, `remove`, `rename`, `tmpname`, `getenv`, `setlocale`).

#### Scenario: Mod tries to run a command
- **WHEN** a script calls `os.execute`
- **THEN** the call fails because the function does not exist

### Requirement: Entity API
Scripts SHALL be able to spawn mesh and sprite entities with a table of properties (mesh, texture, position, yaw/pitch/roll, scale, colour, UV scrolling, visibility, unlit, no-fog, solid with box or radius collider), update, query and destroy them, using handles that become invalid after destruction.

#### Scenario: Stale handle
- **WHEN** a script uses the handle of a destroyed entity
- **THEN** getters return nothing and setters have no effect

### Requirement: Collision helper
`mvl.move(x, y, z, dx, dz, radius)` SHALL move a circle on the ground plane, sliding along solid box and circle colliders and staying inside the world bounds.

#### Scenario: Walking into a wall
- **WHEN** the player moves into a solid box collider
- **THEN** the returned position is pushed out of the box
