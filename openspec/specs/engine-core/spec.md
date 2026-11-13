# engine-core Specification

## Purpose
The engine core owns every subsystem (file system, resources, scene, input, touch, mixer, UI, Lua) and advances the game on a fixed time step. It is written in C11 without any dependency on SDL or OpenGL so it can run headless and be unit tested.

## Requirements
### Requirement: Platform independent core
The engine core SHALL compile and run without SDL, OpenGL or any windowing system, talking to the GPU only through an abstract graphics backend.

#### Scenario: Headless run
- **WHEN** the engine is initialised with the null graphics backend and no window
- **THEN** it loads the game scripts, runs frames and reports script errors without crashing

#### Scenario: GPU uploads go through the backend
- **WHEN** a texture or mesh resource is loaded
- **THEN** the core passes the decoded image or vertex data to the backend's create function and stores the returned handle

### Requirement: Fixed time step simulation
The engine SHALL call the script `game.update(dt)` at a fixed rate configured by `engine.tick_rate` (default 60 Hz), independent of the rendering frame rate, and SHALL clamp long frame stalls.

#### Scenario: Frame shorter than a tick
- **WHEN** a frame advances real time by less than one tick
- **THEN** no update runs and the remaining time is accumulated for the next frame

#### Scenario: Long stall
- **WHEN** a frame reports more than 0.25 seconds of elapsed time
- **THEN** at most 0.25 seconds are simulated and at most 8 ticks run in that frame

### Requirement: UI pass per frame
The engine SHALL rebuild the UI draw list every frame by calling `game.draw_ui()` and then drawing on-screen touch controls when they are enabled.

#### Scenario: UI canvas size
- **WHEN** the window aspect ratio changes
- **THEN** the UI canvas keeps the configured `ui.height` (minimum 120) and grows so that its width is at least `ui.min_width` pixels

### Requirement: Error reporting
Script errors SHALL be logged with a Lua traceback, counted and kept as `last_error`, and SHALL NOT stop the engine loop.

#### Scenario: Runtime error in update
- **WHEN** `game.update` raises an error
- **THEN** the error is logged, the error counter increases and the next frame still runs
