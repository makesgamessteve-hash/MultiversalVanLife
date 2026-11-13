# Design

## Context

Phase 6 provides addresses, passes, facts, commitments and the runner.

## Goals / Non-Goals

**Goals:** varied, plausible top levels that constrain lower levels.
**Non-Goals:** history (phase 19), planets in detail (phases 11–13).

## Decisions

- **Universe laws**: drawn from weighted tables; magic source ∈ {none, life, stellar, tectonic, belief}, strengths in [0, 1], FTL ∈ {none, gates, jumps}, gods ∈ {silent, real}; age and a list of cosmic era skeletons (names and spans only).
- **Galaxy field**: implicit 3D density noise; galaxies are enumerated lazily by index within a cell; notable galaxies are listed explicitly for later history phases.
- **Galaxy**: morphology from weights; density, age and metallicity fields along arms/bar/bulge; clusters sampled by Poisson disc weighted by density; a galactic habitable band.
- **Cluster**: type (open, globular, nursery) from position and age; stars from a mass function shaped by age; lanes as a relative neighbourhood graph only if FTL ≠ none.
- **System**: planets placed with spacing rules and a frost line; rocky inside, giants outside; moons and belts; only skeleton physics here.
- **Prime**: `u0` is a hand-written data table (Milky Way, Sun, planets with real periods, Moon); generators return it for index 0 and refuse to generate below it except the farm (phase 8).

## Risks / Trade-offs

- [Implausible systems] → plausibility checks registered with the checker (spacing, frost line, metallicity gradients).
