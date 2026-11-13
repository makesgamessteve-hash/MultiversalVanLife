# Tasks

## 1. Guards

- [ ] 1.1 Add variety statistics and thresholds over 200 seeds to CI; verify the monotony test fails on a deliberately biased generator in a local run
- [ ] 1.2 Add per-pass budgets and the web travel frame check to CI; verify the slow-level test fails on an artificial delay in a local run
- [ ] 1.3 Add the 200-land save stress test; verify the save stays below 20 MB

## 2. Finish

- [ ] 2.1 Update the remaining game tests (touch, pause/XR, mods with generation content); verify `ctest` headless and `-L gl`, and the web smoke test
- [ ] 2.2 Finish `docs/WORLDGEN.md`, `docs/MODDING.md`, README and CREDITS and mark the roadmap done; verify documented examples run in game tests
- [ ] 2.3 Push to `main`, check all CI jobs and the GitHub Pages build; verify by playing the published build
