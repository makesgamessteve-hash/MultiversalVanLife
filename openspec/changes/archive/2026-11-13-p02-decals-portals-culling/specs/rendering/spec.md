# Spec Delta

## ADDED Requirements

### Requirement: Decals without z-fighting
Entities marked as decals (water edges, roads, paths, rugs lying on a surface) SHALL be drawn after the surface below them so that they never flicker or disappear into it at any viewing distance or angle, including on sloped ground.

#### Scenario: Decal far away
- **WHEN** a decal lies on the ground and the camera looks at it from 60 m at a shallow angle
- **THEN** the decal is drawn completely without flickering ground patches

#### Scenario: Decal order
- **WHEN** two decals overlap
- **THEN** the one with the higher layer number is drawn on top

### Requirement: Portal rendering
The renderer SHALL draw up to 8 rectangular portals: each portal shows the scene as seen through a linked transform, including the sky, limited exactly to the portal's visible area and correctly hidden behind nearer geometry.

#### Scenario: Portal behind a wall
- **WHEN** a portal is completely hidden behind other geometry
- **THEN** nothing of the linked view is drawn

#### Scenario: Portal in VR
- **WHEN** a WebXR session is active
- **THEN** portals are drawn for each eye with that eye's matrices

### Requirement: Frustum culling
Entities outside the view frustum of a pass SHALL NOT be drawn in that pass.

#### Scenario: Looking away
- **WHEN** the camera looks away from most of the scene
- **THEN** the number of draw calls drops accordingly
