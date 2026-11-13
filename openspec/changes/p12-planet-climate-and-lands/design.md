# Design

## Context

Phase 11 provides the grid, plates, elevation and geology. Lands use provisional styles and generic terrain.

## Goals / Non-Goals

**Goals:** plausible climate and hydrology; lands that match their planet.
**Non-Goals:** weather simulation, ocean currents beyond simple bands.

## Decisions

- **Climate**: temperature from insolation by latitude and tilt (seasonal min/max), lapse rate with altitude; wind belts by latitude and rotation (tidally locked worlds get substellar flow); moisture advected along winds from oceans, removed by uplift (rain shadow).
- **Rivers**: priority-flood depression filling to find lakes, then flow directions and accumulation; rivers where accumulation exceeds a threshold.
- **Biomes**: a Whittaker-style table over temperature and precipitation, extended by modifiers (thin air → alpine/barren, high magic → crystal/arcane variants, red light → dark-foliage variants, volcanism → ash fields).
- **Subdivision**: continents = connected land cells; provisional countries by territory growth from seeds (refined by history in phase 19); lands = groups of 1–3 cells refined into a 2 km local map.
- **Land terrain**: coarse elevation map of the land's cells (bicubic) + local fBm; river channels carved along the planet's river polylines with water surfaces; sea surface at sea level.

## Risks / Trade-offs

- [Scale mismatch between grid cells and 2 km lands] → local detail noise and channel carving dominate at walking scale; the grid controls only large forms.
