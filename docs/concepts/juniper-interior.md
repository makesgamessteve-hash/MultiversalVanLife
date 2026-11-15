# Concept: Juniper's interior

Juniper is an old van that is a whole home inside: a cosy house at the heart, wings that remember the peoples the
player has met, rooms that go on without end and a garden the size of a small planet behind the back door. This
replaces the single console room of phase 3 (a round room with a glowing hexagonal console in the middle and a
swirling tunnel in the windows while travelling), which looked too much like a famous time machine.

## Decisions

1. **Style: a cosy core with souvenir wings.** The heart of the house is a warm, lived-in home: floorboards, rugs,
   wallpaper, lamps, a fireplace, books. Every people the player visits adds a wing built in their own architecture
   (their materials, colours, doors and ornaments).
2. **Size: both endless.** Corridors lead from the core into wings and rooms that are generated as the player walks,
   without end, and the garden door opens onto a garden that is a small world of its own, streamed in chunks like a
   land, with its own sky.
3. **Travel: the cab radio and the atlas.** The driver's cab at the front of the house has the windscreen and side
   windows (portals to the outside, as before), the driver's seat, a dashboard radio that tunes into tonight's
   signals and a road atlas on the passenger seat with the places visited and the codex.
4. **Explore first.** Rooms are furnished and explorable now; uses (sleeping, cooking, reading the codex as books,
   growing seeds) come in a later phase.

## The core

The core is one 32 x 32 m block of hand-planned rooms (metres, local to the pocket; +X is the van's front):

| Room | Where | What is in it |
|---|---|---|
| Cab | front, 4 x 5 m, low ceiling | windscreen and side windows, dashboard with wheel and radio, driver's and passenger's seats, the atlas |
| Hall | behind the cab | the door outside with a window beside it, coat rack, bench, stairs up |
| Cross gallery | across the middle | runner rug, paintings, side tables; doors at both ends lead into the wings |
| Library | front left, two storeys high | shelves of books on every wall, a ladder, reading chairs, a globe, a desk |
| Kitchen | front right | range, counters, sink, dresser with plates, a long table with chairs |
| Living room | back left | fireplace, sofas, armchairs, piano, lamps, plants |
| Conservatory | back right | glass roof, plants, wicker chairs; the garden door |
| Landing, bedroom, bathroom | upstairs | bed, wardrobe, dresser; claw-foot tub, basin and mirror |

## The endless house

Beyond the core the house is a grid of 32 m blocks. Every block has a doorway in the middle of each side, so every
block connects to its four neighbours and every room can be reached from the core. A block is laid out from its seed
(the multiverse seed and its grid position) by one of a few templates: a cross of corridors with rooms in the
quarters, an enfilade of rooms opening into each other, a grand hall, a cloister round an indoor courtyard. Rooms
are drawn from a list of kinds (bedrooms, bathrooms, sitting rooms, studies, music rooms, galleries, store rooms,
linen rooms, games rooms, workshops) in house styles that vary by block. Blocks are generated and built when the
player comes near and released behind them.

## Souvenir wings

The blocks nearest the core, in a spiral, are given to the peoples visited, in the order of their first visit. A
wing uses the people's style vector (material, palette, ornaments, door sizes) for its walls, floors, doorways and
decoration, and shows things of their world: a statue of one of them, plants of their land, their motifs on the
walls. Juniper mentions the new wing after a visit.

## The garden

The conservatory's glass doors open onto the garden: a small world with rolling meadows, woods, ponds, orchards,
flower beds, hedges and paths, with its own gentle sky and sun. It is streamed in chunks around the player like a
land, without end. Through the open door the garden is seen from the house (a portal), and from the garden the back
of the house stands at the start of the paths with the door back in.

## Between worlds

While the van travels, the windows no longer show a swirling tunnel: the van drives along a glowing road over a sea
of clouds at night, under ribbons of aurora and stars, the clouds and the road's markings streaming past.

## Engine work

- Colliders with a height (`height`): walls and stairs of one storey do not block the storey above or below.
- Terrain slots: the garden has its own height field next to the land's (`mvl.terrain{slot = 1}`,
  `mvl.height(x, z, slot)`, `mvl.terrain_chunk(..., slot)`).

## Phases

| Phase | Change | What |
|---|---|---|
| V1 | `v1-cosy-core` | collider heights, the house framework (rooms, furniture, floors, stairs), the core, the cab radio and atlas, the road between worlds in the windows while travelling |
| V2 | `v2-endless-house` | blocks of generated rooms without end, streaming and budgets |
| V3 | `v3-souvenir-wings` | wings in the architecture of the peoples visited |
| V4 | `v4-garden-planet` | terrain slots, the endless garden with its own sky, the garden door both ways |
