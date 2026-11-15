# Design

## Context

See `docs/concepts/juniper-interior.md`. Builds on the house framework of V1.

## Decisions

- **Grid**: block (bx, bz) covers pocket metres [32 bx - 16, 32 bx + 16) on both axes; the core is block (0, 0). The
  core opens into blocks (0, 1) and (0, -1) through the ends of the cross gallery; its front (the cab) and back (the
  garden door) stay closed.
- **Doorways**: every generated block has a doorway in the middle of each side, 2 m wide; a block next to the core
  leaves the sides facing the core's closed walls shut. Inside, every template connects all its rooms to the side
  doorways, so the whole house is connected.
- **Templates**: cross (corridors from the side doorways to the middle, one to three rooms per quarter), enfilade
  (three by three rooms with doorways between neighbours), hall (one grand room the size of the block), cloister (a
  ring corridor round a courtyard with plants and a fountain, rooms outside the ring).
- **Seeds**: `hash(multiverse seed, bx, bz)`; the same game always has the same house.
- **Kinds**: bedroom, bathroom, sitting room, study, library, music room, gallery, store room, linen room, games room,
  workshop, corridor; each with its furniture and its share by template.
- **Styles**: a few cosy house styles (wallpaper, panelling, floors, trims) chosen per block.
- **Streaming**: rooms whose rectangle lies within 40 m of the player are built (one per tick, nearest first) and
  released beyond 56 m; the core is always built. Room meshes are released with their room.

## Risks / Trade-offs

- [Repetition] -> templates, kinds and styles mixed per block; variety measured in a test.
- [Frame time on the web] -> one room per tick; the web smoke test checks the frame rate during a trip.
