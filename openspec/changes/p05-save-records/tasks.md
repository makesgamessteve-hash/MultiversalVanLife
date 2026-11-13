# Tasks

## 1. Records

- [ ] 1.1 Add `record.c` (serialise/parse plain tables with CRC, atomic write, `.tmp` fallback); verify unit tests for round trip, corruption, truncated files and rejected code
- [ ] 1.2 Expose `mvl.record_read(name)` / `mvl.record_write(name, table)` / `mvl.record_list(prefix)`; verify engine API unit tests and coverage ≥ 95%

## 2. Save folder

- [ ] 2.1 Move the save to `index.ini` + `records/`, keep web IndexedDB sync; verify game tests for new game, continue and the web smoke test
- [ ] 2.2 Convert old single-file saves; verify a game test that continues from a committed old save fixture
- [ ] 2.3 Document the save layout and record API in `docs/MODDING.md`; verify the documented example runs in a game test
