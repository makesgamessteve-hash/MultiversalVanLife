# Design

## Context

See `docs/concepts/juniper-interior.md`. The garden lies in the same scene as the house, 1,600 m below it (y = -2000),
beyond every far plane of the house and the world, so nothing of one is seen from the other.

## Decisions

- **Terrain slots**: the engine keeps four height fields; `mvl.terrain{slot = n}`, `mvl.height(x, z [, slot])`,
  `mvl.terrain_chunk(cx, cz, size, cells [, slot])`; slot 0 stays the land's.
- **Garden tiles**: the garden is described in 2 km tiles like lands (`gen/house/garden.lua`): terrain (gentle hills,
  base at the garden's level), ponds where it dips below the garden's water level, flora from a mild biome, paths,
  orchards, flower beds, hedges, benches, a gazebo, beehives. The chunk streamer runs a second instance on slot 1 with
  the garden's water level.
- **Sky**: a fixed golden afternoon with a soft sun; stored as an environment and applied when the player is in the
  garden or in the house beyond the cab, and the outside world's environment is applied again in the cab and outside.
- **Doors**: two portals (the conservatory's door looks out of the back of the house in the garden, and back);
  walking through a doorway moves the player to the other side and switches the environment and the sounds.
- **Back of the house**: in the garden, a two-storey cottage front with the door, solid, at the garden's origin.

## Risks / Trade-offs

- [Entities] -> the land outside streams only around the parked van; while the player is in the garden its ring
  shrinks to the chunks next to the van.
