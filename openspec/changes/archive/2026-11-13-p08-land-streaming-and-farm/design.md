# Design

## Context

Phase 1 provides terrain chunks and mesh release, phase 2 decals and culling, phase 6–7 the framework and Prime. Worlds are currently built in one go on a flat plane.

## Goals / Non-Goals

**Goals:** bounded streaming; continuous terrain; a generated farm.
**Non-Goals:** following a planet's geography (phase 12), real wildlife (phases 14–15).

## Decisions

- **Chunks**: 32 m, 16×16 cells; load radius 3 chunks, unload radius 5; the nearest missing chunk is built first, at most one per tick; chunk content seeded by `hash(land_seed, cx, cz)`; entities per chunk tracked and destroyed on unload; terrain meshes released.
- **Land description**: a land node holds terrain shape, palette, flat areas, features (buildings, props) with absolute positions; chunks spawn the features inside their bounds.
- **Neighbouring lands**: a land is about 2 km across; approaching its edge requests the neighbour's node (siblings in the same country are generated lazily as summaries plus detail on approach).
- **Farm**: `u0/.../earth/farm` is a land with a farm style: farmhouse, barn, well, fields as decals, fence with gate, road, trees, neighbour NPC; layout drawn from the save seed; the van spot and gate are fixed relative to the farmhouse.
- **Old home**: `worlds/home.lua` becomes a thin wrapper around the farm land.

## Risks / Trade-offs

- [Hitches when chunks build] → one chunk per tick and C-built meshes.
