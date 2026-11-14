# Spec Delta

## ADDED Requirements

### Requirement: Driving the van
After arriving in a generated land, the player SHALL be able to drive the van around it from the driver's seat:
accelerating, braking, reversing and steering over the terrain, blocked by buildings, people and trees and by deep
water, seen from behind the van or through the windscreen. The van's door, lights and windows SHALL follow it, and its
parked place SHALL be remembered on later visits and after a restart.

#### Scenario: Driving away
- **WHEN** the player sits in the driver's seat and drives forward
- **THEN** the van moves through the land, the windows show the new view and getting up leaves the van parked there

#### Scenario: Remembered place
- **WHEN** the player parks the van somewhere else and comes back later
- **THEN** the van is where they parked it

#### Scenario: Not at home
- **WHEN** the player tries the seat at home or during a trip
- **THEN** the van does not move and Juniper says why
