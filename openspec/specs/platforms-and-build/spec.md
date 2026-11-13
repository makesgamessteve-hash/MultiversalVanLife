# platforms-and-build Specification

## Purpose
One CMake project builds the game for Windows, Linux, macOS and the web.

## Requirements
### Requirement: Desktop builds
The project SHALL build with CMake on Windows, Linux and macOS using an installed SDL3 or, if none is found, SDL3 fetched from its official repository, and SHALL copy `game/` next to the executable on every build.

#### Scenario: Editing a script
- **WHEN** a Lua file under `game/` is changed and the project is rebuilt
- **THEN** the copy next to the executable is updated even if no C code changed

### Requirement: Web build
The project SHALL build with Emscripten into an HTML page, JavaScript loader, WebAssembly module and a data package, targeting WebGL2.

#### Scenario: Mobile browser
- **WHEN** the page is opened on a touch device
- **THEN** the game starts with touch controls enabled

### Requirement: Headless runner
The project SHALL build `mvl_headless`, which runs the game without window, GPU or audio device for automated tests.

#### Scenario: CI without a display
- **WHEN** the headless runner executes a game test on a machine without a display
- **THEN** it exits with code 0 on success and 1 on failure
