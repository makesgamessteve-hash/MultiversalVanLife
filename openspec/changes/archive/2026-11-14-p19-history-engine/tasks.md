# Tasks

## 1. Engine

- [x] 1.1 Add the chronicle engine with per-level time steps, event tables, resolution and caps; verify the time-scale test and chronological-order checker over 200 seeds
- [x] 1.2 Add culture hooks (language splits, religions, commemorations, technology per era); verify that commemorated holidays and split languages appear for matching events

## 2. Factions and people

- [x] 2.1 Add territories and spheres of influence and set country borders from history; verify the borders-follow-history test
- [x] 2.2 Add known individuals and place living ones in lands; verify the lifespan checker and the meeting-a-legend game test

## 3. Eras and Prime

- [x] 3.1 Store eras with snapshots; verify the past-state test
- [x] 3.2 Exclude Prime from histories; verify the no-history-in-Prime test
- [x] 3.3 Add history bible sections and update `docs/WORLDGEN.md`; verify a bible export of a reference planet
