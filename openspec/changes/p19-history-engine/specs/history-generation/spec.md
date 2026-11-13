# Spec Delta

## Purpose

Simulates history on every level of the cosmos, producing factions, spheres of influence, known individuals and major events that refine down the hierarchy, the different ways cultures remember them, and the tensions of the present day.

## ADDED Requirements

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
