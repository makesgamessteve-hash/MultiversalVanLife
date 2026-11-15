# Design

## Context

See `docs/concepts/juniper-interior.md`. The interior stays a pocket of the current world's scene (at y = -400), so
entering, leaving and travelling never reload it; its windows stay portals to the parked van's windows.

## Decisions

- **Plan**: `gen/house/plan.lua` describes rooms as rectangles in pocket metres (+X = the van's front, +Z = its left)
  with a level height, a ceiling height, a kind, a style and doorways on their walls (side, offset, width, height,
  shape). The core is hand-planned data; later phases add generated blocks.
- **Rooms**: `gen/house/rooms.lua` turns a room into one voxel grid (1/8 m): floor layer, walls two voxels thick
  inside the room's rectangle (a wall between two rooms is therefore 0.5 m), doorways cut through with frames,
  ceiling, skirting, rails, wallpaper patterns and the room's furniture. One mesh per room (unlit, tinted by the
  room's light), so a room is one entity plus its colliders.
- **Furniture**: `gen/house/furniture.lua` draws pieces into a room grid through a pen (origin and quarter turn):
  bed, wardrobe, nightstand, dresser, bath, basin, toilet, mirror, range, counters, sink, dresser with plates,
  tables, chairs, sofa, armchairs, fireplace, piano, bookshelves full of books, ladder, desk, globe, lamps, plants,
  rugs, paintings, coat rack, bench, wicker chairs, dashboard, seats, radio. Each piece returns its footprint for a
  box collider.
- **Levels and stairs**: rooms have a level height; stairs are ramps with side walls. `lib/house.lua` answers the
  floor height under the player (the highest floor at most a step above their feet), so walking up the stairs
  lifts them to the landing. Colliders get a height (engine): a solid entity blocks only feet between its base
  (minus 0.4 m) and its top, so the storeys do not block each other.
- **Interactables** keep their `y` (the floor of their room); the player's `base_y` follows the floor they stand on.
- **Cab**: the windscreen and side windows look out of the parked van's windows as before; the hall has a window
  beside the door outside. The driver's seat and the seated eye move to the cab. The radio menu holds the signals,
  the way home and "Not yet"; the atlas holds the logbook (travel to a place visited) and the codex.
- **Between worlds**: a self-contained scene above the world (unlit, without fog): a dome of night sky with stars
  and aurora, a sea of clouds and a glowing road whose markings stream past.

## Risks / Trade-offs

- [Entity budget] -> one mesh per room and merged colliders; the core is about 15 rooms.
- [Build time] -> rooms are built once per session (a few ms each in release builds).
