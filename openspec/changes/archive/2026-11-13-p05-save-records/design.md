# Design

## Context

`engine.c` reads and writes `savegame.ini` through the kv store; the web build mounts IndexedDB at `/save` and syncs after writes.

## Goals / Non-Goals

**Goals:** structured, safe, compact records; migration.
**Non-Goals:** cloud saves; multiple save slots (later).

## Decisions

- **Folder layout**: `<save>/index.ini` and `<save>/records/<name>.rec`; record names are sanitised paths (place addresses map to nested folders).
- **Format**: a small tagged binary format (nil, bool, integer, number, string, table with array and hash parts), little-endian, with a header and CRC32. Written by C (`record.c`) to `<file>.tmp`, flushed, then renamed. Parsed by C into Lua tables, so no Lua `load` is involved. *Alternative*: Lua table literals loaded in an empty environment — rejected, still runs the Lua parser on untrusted text and is larger.
- **Migration**: on start, if `savegame.ini` exists and `index.ini` does not, its keys are copied into `index.ini` and the old file is renamed to `savegame.ini.bak`.
- **Web**: same layout under `/save`, `FS.syncfs` after each save batch.

## Risks / Trade-offs

- [Rename not atomic on some filesystems] → the reader falls back to `.tmp` if the main file fails its CRC.
