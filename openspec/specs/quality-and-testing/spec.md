# quality-and-testing Specification

## Purpose
The engine core is covered by unit tests and the game by automated play-throughs, enforced in continuous integration.

## Requirements
### Requirement: Engine core coverage
Unit tests and automated game tests together SHALL cover at least 95% of the lines in `engine/src/core`, and CI SHALL fail below that threshold.

#### Scenario: Coverage gate
- **WHEN** CI runs `ninja coverage` on a coverage build
- **THEN** gcovr fails the job if line coverage is under 95%

### Requirement: Automated game tests
Every `tests/game/test_*.lua` file SHALL be run by CTest through the headless runner with a fresh save folder; tests drive the real game with input actions, touch events and simulated XR state and fail on any failed expectation, script error or timeout.

#### Scenario: Full quest
- **WHEN** `test_fen.lua` runs
- **THEN** it travels to Lanternfen, catches every firefly, lights every lantern and checks that the fen is marked as helped

### Requirement: Web smoke test
CI SHALL load the web build in headless Chromium, both as a desktop browser and as an emulated phone, and fail on page errors, console errors or a blank screen.

#### Scenario: Phone start
- **WHEN** the emulated phone taps the USE button on the title screen
- **THEN** a new journey starts without errors
