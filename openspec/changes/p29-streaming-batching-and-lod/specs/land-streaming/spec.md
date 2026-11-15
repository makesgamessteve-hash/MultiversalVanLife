# Spec Delta

## ADDED Requirements

### Requirement: Streaming on demand
Chunks SHALL be loaded and released on demand by distance, view direction and travel speed within resident budgets, generated in time slices nearest first, with lands and plans generated ahead along the direction of travel.

#### Scenario: Driving fast
- **WHEN** the player drives along a road at full speed
- **THEN** the road ahead is always loaded, chunks behind are released and no frame stalls
