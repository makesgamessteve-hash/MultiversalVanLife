# Design

## Context

Decal planes are 1–5 cm above the ground with a 24-bit depth buffer, `znear` 0.05 and `zfar` 200. The renderer draws every entity once per frame without culling and has no stencil buffer.

## Goals / Non-Goals

**Goals:** no z-fighting at any distance; portals in flat and XR rendering; cheaper passes.
**Non-Goals:** recursive portals (a portal seen through a portal shows the sky).

## Decisions

- **Decal pass**: after opaque geometry and before translucent geometry; depth test LEQUAL, depth writes off, `glPolygonOffset(-1, -(layer+1)·4)`. Plus `znear` 0.1 and `zfar` = fog far + 20 m. *Alternative*: lifting decals by a fixed offset — still fails at distance and on slopes.
- **Water** becomes a real surface at a water level (it intersects the ground naturally) rather than a decal.
- **Portals**: (1) draw the scene without portal rectangles; (2) per enabled portal, write its rectangle into the stencil with depth testing; (3) inside the stencil, draw the sky with the virtual view and depth func ALWAYS, which resets depth; (4) draw the scene with the virtual view `view · M⁻¹` and an oblique near plane on the target rectangle's plane (Lengyel), so geometry between the virtual eye and the target window is clipped. Maths in core with unit tests; GL passes in the renderer. *Alternative*: render-to-texture per window — needs per-window FBOs and a separate XR path.
- **Culling**: bounding sphere per entity (mesh bounds × scale, sprite size) against six planes extracted from view-projection; applied in every pass including portal and XR passes.

## Risks / Trade-offs

- [No stencil on some WebXR layers] → request `stencil: true`; without stencil portals show the sky colour only.
- [Extra passes cost] → culling, and portals skipped when their rectangle is off screen.
