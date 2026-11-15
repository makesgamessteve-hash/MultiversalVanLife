# Proposal

Phase V1 of 4 of Juniper's interior (see `docs/ROADMAP.md` and `docs/concepts/juniper-interior.md`). Depends on: p25.

## Why

The van's interior is one round room with a glowing hexagonal console in the middle, and a swirling tunnel shows in the
windows while travelling: it looks too much like a famous time machine. The player wants a vast, homely van with
rooms for different things: a library, a bathroom, a bedroom, a kitchen and a door to a garden.

## What Changes

- Colliders with a height, so walls and stairs of one storey do not block another.
- A house framework: rooms generated as voxel models at human scale (walls, doorways, floors, ceilings, wallpaper,
  trims), a furniture library, floors on several levels joined by stairs, wall and furniture colliders.
- The cosy core of the house: cab, hall, cross gallery, library, kitchen, living room, conservatory and, upstairs,
  a landing, a bedroom and a bathroom.
- The cab: windscreen and side windows (portals to the outside), the driver's seat, a dashboard radio that offers
  tonight's signals and the way home, and a road atlas with the places visited and the codex. The console goes.
- While travelling, the windows show the road between worlds instead of the vortex.
- Juniper's lines that mention the console are rewritten.

## Capabilities

### New Capabilities
- `van-interior`: the house inside the van.

### Modified Capabilities
- `van-windows`, `story-and-worlds`, `scripting-api`: See the requirements of this change.

## Impact

- Engine: `scene.c` (collider height), `script.c`; new `gen/house/` (plan, rooms, furniture, styles), new
  `lib/house.lua`; `lib/van.lua`, `lib/story.lua`, `lib/drive.lua`, `lib/player.lua`, `lib/world.lua`,
  `dialogue/lines.txt`; `tools/gen_assets.py` (the old interior model goes); tests and docs.
