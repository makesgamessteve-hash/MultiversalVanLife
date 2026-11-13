# Design

## Context

`world.load("van")` clears the scene and builds the interior; leaving reloads the location world. Phase 2 provides portals.

## Goals / Non-Goals

**Goals:** no reload when entering or leaving; live windows; travel replaces only the outside.
**Non-Goals:** windows on the exterior showing the interior.

## Decisions

- **Pocket**: interior entities are spawned once at y = −400 below the world and tagged `persistent`; `world.load` for locations keeps tagged entities. Being inside sets collision bounds to the interior and swaps ambience; leaving restores the world bounds.
- **Lighting**: the scene has one environment, so interior entities are drawn unlit with tints; travel flashes animate those tints.
- **Windows**: four openings in the interior side walls; each portal maps the interior window frame to the matching exterior window frame of the parked van (rotation + translation, no scale). The exterior van mesh is culled from inside by back-face culling and the oblique near plane.
- **Vortex**: a spinning, UV-scrolling tunnel far above the world (y = +600); during travel each portal target moves into it.
- **Travel**: the outside world is cleared and rebuilt while the player stays inside; the interior stays untouched.

## Risks / Trade-offs

- [Interior visible from below the terrain] → the terrain is drawn with back-face culling and the interior is closed with a ceiling, so neither side sees the other except through portals.
