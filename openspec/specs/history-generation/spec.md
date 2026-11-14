# history-generation Specification

## Purpose
Simulates history on every level of the cosmos, producing factions, spheres of influence, known individuals and major events that refine down the hierarchy, the different ways cultures remember them, and the tensions of the present day.

## Requirements

### Requirement: Chronicle simulation per level
Each level SHALL simulate its history over its own time scale (universe: billions of years; galaxy: thousands of years; planet: centuries to decades; country and land: decades to years) with factions acting on their traits, resources and relations through events such as expansion, alliance, war, trade, schism, discovery, plague, migration, revolution, golden age and collapse.

#### Scenario: Different time scales
- **WHEN** a galaxy and one of its planets are generated
- **THEN** the galaxy's history spans much longer periods with coarser events than the planet's

### Requirement: Factions and spheres of influence
Factions (empires, nations, guilds, churches, clans, hives, cults) SHALL have territories (areas they rule) and spheres of influence (where they trade, preach or spy) on their level, changing through history and summarised at the present day.

#### Scenario: Borders follow history
- **WHEN** a planet's history ends with a nation holding a valley
- **THEN** the valley's lands belong to that nation's country

### Requirement: Known individuals
History SHALL produce named individuals (founders, rulers, prophets, heroes, villains, inventors, mages) with birth and death dates, deeds tied to events and relations to other individuals; individuals alive at the present day SHALL be placed where history leaves them and can be met.

#### Scenario: Meeting a legend
- **WHEN** a long-lived individual from the history is alive and lives in the land the player visits
- **THEN** that person is present in the land and talks about their deeds

### Requirement: History stored as eras
Every level's history SHALL be stored as named eras with snapshots of the place's state at each era's end, so a place's past state can be reconstructed; the game SHALL show only the present for now.

#### Scenario: Past state
- **WHEN** a kingdom fell in an earlier era
- **THEN** the stored eras contain the kingdom's territory and rulers when it stood

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
