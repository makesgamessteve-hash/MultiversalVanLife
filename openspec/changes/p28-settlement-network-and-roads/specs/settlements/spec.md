# Spec Delta

## ADDED Requirements

### Requirement: Settlement network
Each region SHALL place its settlements from the planet plan (types from farmstead to city and nomad camp, with sizes, specialties, founding eras and condition), connected by a ranked road network with bridges, fords and harbours.

#### Scenario: Farmland
- **WHEN** a region of fertile farmland is generated
- **THEN** it has villages a few kilometres apart joined by roads, with hamlets and farmsteads between them

#### Scenario: A road between towns
- **WHEN** two towns of a region are connected
- **THEN** a road runs between them over passable terrain, crossing rivers by bridges or fords

### Requirement: Land use and named features
Region plans SHALL assign land use (fields, pastures, orchards, woods, mines, sacred groves, ruins) and name hills, forests, lakes and passes in the local language.

#### Scenario: Around a village
- **WHEN** the player walks out of a village
- **THEN** fields of the local crops and pastures surround it, with woods beyond
