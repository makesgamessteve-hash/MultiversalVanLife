# Spec Delta

## ADDED Requirements

### Requirement: Events refined down the hierarchy
Major events SHALL be recorded with the child places they touch; generating a child SHALL refine them into local events with local participants and traces (battlefields, ruins, monuments, craters, shrines).

#### Scenario: Galactic war on a planet
- **WHEN** a galactic war is recorded as touching a planet
- **THEN** that planet's history contains local events of the war and its lands can contain its traces

### Requirement: Cultural memory
Each culture SHALL remember history in its own version derived from the true events: glorifying its side, vilifying enemies, deifying founders, blaming disasters on outsiders or heresy, and forgetting distant eras; both versions SHALL be stored.

#### Scenario: Two versions of a war
- **WHEN** two nations fought a war
- **THEN** each nation's version blames the other, while the true record states what happened

### Requirement: Present-day tensions
History SHALL end in the present day with a set of active tensions per country and land (such as droughts, succession crises, schisms, failing magic, incursions, epidemics, lost relics, feuds), each with causes, stakeholders and a severity.

#### Scenario: Tension with causes
- **WHEN** a land has a drought tension
- **THEN** it records its causes (for example climate and a dammed river upstream) and the people affected

#### Scenario: Contested border
- **WHEN** two factions' spheres of influence overlap at the present day
- **THEN** the lands in the overlap have a tension involving both factions

### Requirement: The Wanderer legend
Juniper's long past journeys SHALL appear in generated histories as sightings of a wandering cream-and-teal vehicle, so some cultures have legends about it before the player ever arrives.

#### Scenario: Legend before the visit
- **WHEN** the player arrives in a land whose history includes a Wanderer sighting
- **THEN** some people there recognise the van from their legends
