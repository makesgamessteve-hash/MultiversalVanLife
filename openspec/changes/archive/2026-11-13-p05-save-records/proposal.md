# Proposal

Phase 5 of 24 of the procedural multiverse roadmap (see `docs/ROADMAP.md`). Depends on: p04.

## Why

Permanent world memory needs structured, per-place save data. The current save is a single `key = value` file, which cannot hold place descriptions or change logs.

## What Changes

- **BREAKING** The save becomes a folder: `index.ini` plus data records.
- A compact data-record format written atomically and parsed without executing code.
- A script API to read and write records per place.
- Automatic conversion of old single-file saves.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `save-games`: Save folder with index and records; safe and compact saves.
- `scripting-api`: Persistent place storage.

## Impact

- New core module `record.c`, changes to save handling in `engine.c`, web IndexedDB folder layout, migration code, unit and game tests.
