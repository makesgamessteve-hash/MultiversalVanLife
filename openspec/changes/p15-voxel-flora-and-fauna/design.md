# Design

## Context

Phase 1 provides voxel grids, parenting and texture generation; phase 14 species traits and chunk population.

## Goals / Non-Goals

**Goals:** recognisable, varied retro voxel life; cheap animation.
**Non-Goals:** skeletal animation, physics, combat.

## Decisions

- **Plants**: a lineage-specific branch grammar (trunk/stalk, branching angle and depth, leaf/frond/cap/crystal tips) evaluated into a voxel grid (≤ 32³) and coloured from the palette.
- **Animals**: torso segments plus attached parts (legs, wings, tails, heads, antennae, shells) from the body plan; each movable part is a separate small mesh attached by parenting, so animation is transform-only.
- **Animation**: gait cycles by limb count (alternating pairs), wing flaps, sinusoidal body waves, plant sway as yaw/roll noise; computed in Lua for visible creatures only.
- **Behaviour**: a small state machine per creature (idle, graze, wander, flee, chase, herd follow) with steering and terrain height; herds share a leader.
- **Cache**: models keyed by parameter hash with reference counts; released when the last user is gone; per-frame build budget shared with the generation runner.

## Risks / Trade-offs

- [Draw calls from multi-part creatures] → parts only within 40 m; far creatures use a single merged model.
