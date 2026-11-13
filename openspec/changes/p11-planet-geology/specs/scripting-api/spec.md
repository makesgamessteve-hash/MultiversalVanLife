# Spec Delta

## ADDED Requirements

### Requirement: Planet grid and tectonics kernels
Scripts SHALL have fast engine functions to build a geodesic planet grid, seed and grow tectonic plates, classify plate boundaries and compute elevation, returning deterministic data that scripts can read and store.

#### Scenario: Plates from a kernel
- **WHEN** a script runs the plate kernel with a seed on a planet grid
- **THEN** it receives a plate id per cell and boundary types per edge, identical on every platform
