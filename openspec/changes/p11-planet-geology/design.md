# Design

## Context

Phase 7 provides star systems with planet skeletons; phase 9 uses provisional land styles derived from them.

## Goals / Non-Goals

**Goals:** plausible planets fast enough for the web.
**Non-Goals:** science-grade geophysics, erosion simulation, caves.

## Decisions

- **Grid**: icosahedron subdivided 5 times (10,242 cells), cell neighbours and positions computed once in C and shared.
- **Physics**: mass from formation zone and metallicity; radius, gravity, atmosphere retention from mass and temperature; tidal locking from distance to small stars; tilt and day length random within plausible ranges.
- **Plates**: 8–20 seeds by Poisson disc; growth by weighted flood fill; each plate gets a velocity (rotation pole) and type (continental/oceanic by area target); boundaries classified convergent/divergent/transform by relative velocity; elevation = plate base + boundary profiles + fBm.
- **Geology**: rock and soil per cell from setting (orogen, craton, basin, volcanic arc, rift, ocean floor) and age; deposits drawn with probabilities per setting and composition.
- **Magic map**: per-cell strength from the universe's source (plate boundaries, later life density from phase 14, starlight, holy sites from phase 16) and stored with causes.
- **Data in Lua**: kernels return compact arrays; Lua keeps per-cell fields that later passes need, plus bible sections.

## Risks / Trade-offs

- [Kernel time on the web] → measured in the budget test; grid level reduced to 4 (2,562 cells) if needed.
