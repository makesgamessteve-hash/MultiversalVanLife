# Spec Delta

## ADDED Requirements

### Requirement: Terrain slots
Scripts SHALL be able to configure up to four independent terrain height fields (slots), query the height and build
chunk meshes of any of them; slot 0 is the default.

#### Scenario: Two terrains
- **WHEN** slot 0 and slot 1 are configured differently
- **THEN** heights and chunks of each follow its own configuration
