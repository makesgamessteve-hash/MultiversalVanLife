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
- **WHEN** a quest test runs for a quest template
- **THEN** it travels to a generated land using that template, completes the quest through the game's own interactions and checks that the land is marked as helped

### Requirement: Web smoke test
CI SHALL load the web build in headless Chromium, both as a desktop browser and as an emulated phone, and fail on page errors, console errors or a blank screen.

#### Scenario: Phone start
- **WHEN** the emulated phone taps the USE button on the title screen
- **THEN** a new journey starts without errors

### Requirement: Generation determinism tests
Tests SHALL check that generation is deterministic for a seed on every CI platform (comparing stored fingerprints of reference addresses) and independent of the order in which places are generated.

#### Scenario: Fingerprint mismatch
- **WHEN** a platform produces a different fingerprint for a reference address
- **THEN** CI fails on that platform

### Requirement: Consistency checker
A consistency checker SHALL verify generated places (every commitment honoured, no references to missing entities, chronological order, plus checks registered by generators) and tests SHALL run it over many seeds.

#### Scenario: Broken commitment
- **WHEN** a generator leaves a commitment unhonoured
- **THEN** the consistency test fails naming the commitment

### Requirement: World bible export
A tool SHALL export any address as readable Markdown describing everything generated there and on its path, for review and tuning.

#### Scenario: Reviewing a place
- **WHEN** the exporter runs for an address
- **THEN** it writes a document with one section per generated node on the path and every fact with its causes
