# Proposal

## Why

The van's windows are flat cut-outs in a paper-thin wall, the cab has nowhere to sit, and once Juniper has landed the
van stays where it arrived. Players want to sit at the wheel and drive the van around the place they travelled to.

## What Changes

- A driver's seat with a steering wheel and a dashboard at the front of the interior, under the windscreen.
- Windows with thickness: deep framed reveals with a sill inside, recessed glass outside.
- Driving: in a generated land, sitting in the driver's seat lets the player drive the van over the terrain (accelerate,
  brake, reverse, steer), colliding with buildings, people and trees and stopping at deep water, with a view from behind
  the van or through the windscreen (whose window shows the moving world). Getting up parks the van; its new place is
  remembered on later visits and after a restart, and the door, lights and windows follow it.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `van-windows`: Adds the driver's seat and windows with thickness.
- `story-and-worlds`: Adds driving the van around a land.

## Impact

- `tools/gen_assets.py` (`van.vox`, `van_interior.vox`), `lib/van.lua`, new `lib/drive.lua`, `lib/story.lua`,
  `worlds/land.lua`, `main.lua`, `memory/changes.lua`, game tests, README controls and docs.
