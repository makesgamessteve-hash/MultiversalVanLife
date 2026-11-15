# Design

## Context

See `docs/concepts/juniper-interior.md`. Builds on the blocks of V2.

## Decisions

- **Souvenirs**: `progress` keeps one record per culture (by culture id and planet): name, species, the land's
  architecture style (material, palette, ornament, door size, height), a person's anatomy and dress, two plant
  species of the land and the night of the first visit. Records are small (well under 1 kB) and saved with the game.
- **Placement**: the blocks around the core in spiral order (skipping the core and the blocks in front of the cab and
  behind the garden door) are assigned to the souvenirs in visit order; the other blocks stay generic.
- **Look**: a wing block uses the people's palette for walls, wall shadows, trims and floors, their material for
  wall textures (stone courses, timber boards, mud brick, hides), doorways of their door height and an arch, and
  their ornament as reliefs; its rooms are galleries and halls; one holds a statue of a person of the people on a
  plinth, others pots of their plants and a sign with their name in the entrance.
- **Rebuilding**: a block that becomes a wing while it is built is rebuilt once the player is away from it.

## Risks / Trade-offs

- [Save size] -> records are capped at 256 peoples (the spiral then wraps).
