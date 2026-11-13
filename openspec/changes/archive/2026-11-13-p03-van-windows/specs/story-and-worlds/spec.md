# Spec Delta

## MODIFIED Requirements

### Requirement: Van interior and console
The van interior SHALL be much larger than the exterior and contain a console that lists every registered destination (the current location disabled), a way home when away, and a cancel entry.

#### Scenario: Travelling
- **WHEN** the player chooses a destination at the console
- **THEN** the travel sound and camera shake play inside the van, the outside world is replaced by the destination while the player stays inside, the location is saved, and stepping outside puts the player next to the van's rear door
