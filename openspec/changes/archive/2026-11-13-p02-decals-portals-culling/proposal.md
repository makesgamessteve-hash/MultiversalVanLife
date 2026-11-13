# Proposal

Phase 2 of 24 of the procedural multiverse roadmap (see `docs/ROADMAP.md`). Depends on: p01.

## Why

Water and road planes flicker against the ground because they share its depth. The van windows planned for phase 3 need portal rendering, and streamed worlds will draw far more entities, so the renderer needs frustum culling.

## What Changes

- Decal entities (with a layer) drawn in their own pass so they never z-fight with the surface below; better depth precision (`znear` 0.1, fog-based `zfar`).
- Existing water, roads and rugs in the current worlds become decals or real water surfaces, which fixes the flicker in the game today.
- Stencil-based portals (up to 8) that show the scene through a linked transform, in flat rendering and in WebXR.
- Frustum culling in every pass.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `rendering`: Adds decals without z-fighting and portal rendering.
- `scripting-api`: Adds the portal and decal API.

## Impact

- Core: decal fields, portal definitions and maths (portal transform, oblique near plane), frustum helpers; Lua API.
- Renderer: depth+stencil targets, decal pass, portal passes, culling; stencil requested for the window and the WebXR layer.
- Game scripts: water, road and rug props switched to decals or water surfaces.
