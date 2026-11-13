# Tasks

## 1. Stored places

- [x] 1.1 Store land descriptions and ancestor summaries on first arrival and load them on revisits; verify the return-after-generator-change game test (simulated version bump)

## 2. Changes

- [x] 2.1 Give persistent objects stable ids and add the change log with buffered writes; verify game tests for dropped items and walking back to a discarded chunk
- [x] 2.2 Persist quest progress per land; verify the partial-quest and remembered-lantern game tests across restart
- [x] 2.3 Document world memory for modders (object ids, custom state) in `docs/MODDING.md`; verify the documented example runs in a game test
