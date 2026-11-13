# rendering Specification

## Purpose
A retro look inspired by late 90s consoles: low resolution rendering, per-vertex lighting, vertex snapping, fog, ordered dithering, billboarded sprites, OBJ models and voxel models.

## Requirements

### Requirement: Low resolution world
The world SHALL be rendered into an off-screen target `render.height` pixels tall (default 240) with the window's aspect ratio and upscaled with nearest filtering.

#### Scenario: Window resize
- **WHEN** the window size changes
- **THEN** the off-screen target is recreated with the new aspect ratio and the same height

### Requirement: Retro shading
World geometry SHALL use per-vertex ambient, directional and up to 8 point lights, snap vertices to the low resolution pixel grid, apply linear fog and alpha-test sprites; the final image SHALL be quantised to 5 bits per channel with 4x4 ordered dithering when `render.dither` is enabled.

#### Scenario: Sprite cut-out
- **WHEN** a sprite texture pixel has alpha below 0.5 and the entity is opaque
- **THEN** the pixel is discarded

#### Scenario: Translucent entity
- **WHEN** an entity colour has alpha below 1
- **THEN** it is drawn after opaque entities with blending and without depth writes

### Requirement: Moddable shaders
Shaders SHALL be loaded from `game/shaders/*.vert|frag` and prefixed with `#version 330 core` on desktop or `#version 300 es` on the web.

#### Scenario: Shader compile error
- **WHEN** a shader fails to compile
- **THEN** the compiler log is reported and the game exits with an error instead of drawing garbage

### Requirement: Sky
The renderer SHALL draw a sky gradient between `sky_horizon` and `sky_top` with a scrolling star texture weighted by `stars`.

#### Scenario: Indoor scene
- **WHEN** a world sets `stars = 0`
- **THEN** no stars are drawn

### Requirement: Decals without z-fighting
Entities marked as decals (water edges, roads, paths, rugs lying on a surface) SHALL be drawn after the surface below them so that they never flicker or disappear into it at any viewing distance or angle, including on sloped ground.

#### Scenario: Decal far away
- **WHEN** a decal lies on the ground and the camera looks at it from 60 m at a shallow angle
- **THEN** the decal is drawn completely without flickering ground patches

#### Scenario: Decal order
- **WHEN** two decals overlap
- **THEN** the one with the higher layer number is drawn on top

### Requirement: Portal rendering
The renderer SHALL draw up to 8 rectangular portals: each portal shows the scene as seen through a linked transform, including the sky, limited exactly to the portal's visible area and correctly hidden behind nearer geometry.

#### Scenario: Portal behind a wall
- **WHEN** a portal is completely hidden behind other geometry
- **THEN** nothing of the linked view is drawn

#### Scenario: Portal in VR
- **WHEN** a WebXR session is active
- **THEN** portals are drawn for each eye with that eye's matrices

### Requirement: Frustum culling
Entities outside the view frustum of a pass SHALL NOT be drawn in that pass.

#### Scenario: Looking away
- **WHEN** the camera looks away from most of the scene
- **THEN** the number of draw calls drops accordingly
