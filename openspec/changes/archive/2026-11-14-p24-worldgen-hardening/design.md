# Design

## Context

All generators, world memory and the codex exist; CI already runs determinism fingerprints, the checker and game tests.

## Goals / Non-Goals

**Goals:** catch monotony, slowness and bloat automatically.
**Non-Goals:** new features.

## Decisions

- **Variety**: the headless runner gets `--stats <seeds>` printing distributions; thresholds per statistic stored in `tests/stats_thresholds.ini`.
- **Budgets**: per-pass timing collected by the runner; CI fails above per-level limits (desktop) and the web smoke test measures frames during a travel.
- **Save stress**: a test drives 200 arrivals with scripted changes and measures the folder size.
- **Docs**: `docs/WORLDGEN.md` completed; `docs/ROADMAP.md` marked done.

## Risks / Trade-offs

- [Flaky timing on shared CI runners] → budgets with headroom and medians over several runs.
