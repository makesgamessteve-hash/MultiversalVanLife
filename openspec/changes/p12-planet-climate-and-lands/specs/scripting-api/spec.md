# Spec Delta

## ADDED Requirements

### Requirement: Climate, river and territory kernels
Scripts SHALL have fast engine functions for climate fields (temperature, wind, moisture with rain shadow), river networks (flow direction, accumulation, lakes) and territory growth on region graphs, returning deterministic data.

#### Scenario: Rivers from a kernel
- **WHEN** a script runs the river kernel on an elevation grid
- **THEN** it receives river paths and flow amounts it can store in the planet description
