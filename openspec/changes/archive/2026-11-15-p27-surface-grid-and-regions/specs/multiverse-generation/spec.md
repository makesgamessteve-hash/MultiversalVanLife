# Spec Delta

## ADDED Requirements

### Requirement: Planet-wide surface
Every point of a planet's surface SHALL belong to exactly one region of a planet-wide grid of about 32 km regions, each divided into 16 x 16 lands, so any place on the planet can be generated.

#### Scenario: Any place
- **WHEN** the player's position is anywhere on a planet's land
- **THEN** it lies in exactly one region and land, generated on demand from the planet plan
