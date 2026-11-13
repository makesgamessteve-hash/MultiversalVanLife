# Spec Delta

## ADDED Requirements

### Requirement: Portal and decal API
Scripts SHALL be able to define portals (a rectangle in the scene and the transform it looks through), switch them off, and mark entities as decals with a layer.

#### Scenario: Disabling a portal
- **WHEN** a script switches a portal off
- **THEN** the renderer no longer draws its linked view
