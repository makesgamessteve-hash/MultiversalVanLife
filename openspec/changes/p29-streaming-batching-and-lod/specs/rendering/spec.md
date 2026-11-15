# Spec Delta

## ADDED Requirements

### Requirement: Batched and instanced drawing
Static objects of a chunk SHALL be drawn as merged meshes and repeated objects as instances, so a dense town stays within the entity and draw-call budgets.

#### Scenario: A dense village
- **WHEN** a village with hundreds of props and plants is loaded
- **THEN** the scene stays under its entity budget and the frame rate within its target

### Requirement: Far ring
Lands beyond the loaded chunks SHALL be shown as low-detail impostors up to a few kilometres away.

#### Scenario: A town on the horizon
- **WHEN** the player looks at a town 2 km away
- **THEN** its buildings and lights are visible as a silhouette
