# Design

## Context

The interior is a pocket below the world whose windows are portals to the van's exterior windows (phase 3). The camera
is set by the player module each frame; scripts can set it directly (`mvl.camera`). Collision is `mvl.move` against
solid entities, clamped to the scene bounds.

## Decisions

- **Seat**: voxels in `van_interior.vox` at the +X (front) wall under the windscreen window, an invisible solid collider
  and a fixed interactable "Sit in the driver's seat".
- **Thickness**: interior windows get 4-voxel (0.5 m) framed reveals with a wooden sill on the inside of the
  1-voxel wall; the portal stays on the wall plane, so the world is seen at the end of a deep window. The exterior glass
  is set one voxel into the body, framed by the body colour.
- **Driving** (`lib/drive.lua`): only in generated lands (not at home, not while travelling). The player stays seated in
  the pocket; the van exterior (model, roof lamp and its light, door, window portals, streaming anchor) is moved every
  frame by `story.move_van`. A simple car model: throttle, brakes, reverse, drag, steering that depends on speed, the
  body pitched to the terrain under its wheels; `mvl.move` with a 1.3 m radius against the land's solids, with the scene
  bounds switched to the land's while driving; deep water stops the van. Views: chase camera behind the van (default)
  or the seated view through the windscreen portal; interact switches, back gets up.
- **Memory**: the parked place is kept in the land's change log (`van`), used when the land is built again.
