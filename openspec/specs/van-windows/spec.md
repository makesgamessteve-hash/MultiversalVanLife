# van-windows Specification

## Purpose
Makes the van's bigger-on-the-inside interior part of the world it is parked in, with windows that look out at that world.

## Requirements

### Requirement: Interior in the world scene
The van interior SHALL exist in the same scene as the current world, so entering and leaving the van moves the player without loading another world.

#### Scenario: Stepping outside
- **WHEN** the player uses the interior door
- **THEN** they stand behind the van in the current world immediately, without a loading fade

### Requirement: Windows are portals
The interior SHALL have windows that show the world outside as seen from the matching place on the van's exterior, updating live and following the van's position and heading.

#### Scenario: Looking out
- **WHEN** the van is parked facing a settlement and the player looks through a side window
- **THEN** the settlement is visible through the window from the matching angle

#### Scenario: Different location
- **WHEN** the van has travelled to another place
- **THEN** the windows show the new place

### Requirement: Travel view
While travelling, the windows SHALL show the road between worlds (a glowing road over a sea of clouds under a night
sky with stars and aurora, its markings and the clouds streaming past) instead of a world.

#### Scenario: During travel
- **WHEN** the player chooses a destination at the radio
- **THEN** the windows show the road between worlds until the van has arrived

### Requirement: Driver's seat
The van interior SHALL have a driver's seat with a steering wheel and a dashboard at the front, facing the windscreen
window, which the player can sit in.

#### Scenario: Sitting down
- **WHEN** the player uses the driver's seat in a generated land
- **THEN** they sit at the wheel and can drive the van

### Requirement: Windows with thickness
The van's windows SHALL have visible thickness: inside, deep framed reveals with a sill around each window; outside,
glass set into the body.

#### Scenario: A deep window
- **WHEN** the player looks at a window from inside the van
- **THEN** the outside is seen at the end of a framed opening about half a metre deep
