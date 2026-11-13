# Design

## Context

See proposal.md for motivation. Relevant current state:

- The scene is a single flat entity list (`engine/src/core/scene.c`); `world.load` in Lua clears it and builds one hand-written world. The van interior is its own world (`worlds/van.lua`), so entering the van reloads the scene with a fade.
- Ground is one flat `plane_mesh` at y = 0; water and roads are planes 1–5 cm above it. Depth is a 24-bit buffer with `znear = 0.05`, `zfar = 200`, which gives too little precision at distance, hence the flicker.
- Mesh resources live in a fixed table of 256 slots that are never freed.
- Dialogue lines and voice clips live in `game/voice/`; procedural sounds come from `tools/gen_assets.py`.
- The engine core must stay free of SDL/OpenGL and keep ≥ 95% line coverage; gameplay must stay in moddable Lua.

## Goals / Non-Goals

**Goals:**
- Deterministic generation from a 32-bit save seed, identical on every platform.
- Constant memory while walking indefinitely (bounded entities, meshes, lights).
- Portals that work in flat rendering and WebXR.
- Keep the core testable: noise, terrain meshing, frustum maths and portal maths in C core with unit tests; streaming and content rules in Lua with game tests.

**Non-Goals:**
- Generating textures or voxel models at runtime (existing art is reused, tinted and scaled).
- Recursive portals (a window seen through a window shows the sky).
- Persisting partial quest progress or picked-up items across leaving a destination; only completion is saved.
- Caves, overhangs or terrain editing.

## Decisions

### 1. One scene: the van interior is a pocket inside the world
The interior is spawned once per world at a fixed offset far below the terrain (y = −400) and stays there; entering/leaving the van only teleports the player and swaps collision bounds and ambience. Travelling clears and regenerates only the outside world; interior entities are tagged and survive.
*Alternative*: two scenes rendered into textures. Rejected: duplicates scene state, needs a second render target per window and a different code path in XR.

### 2. Stencil portals with oblique near-plane clipping
A portal is a rectangle (centre, yaw, width, height) plus a target frame (position, yaw). The renderer: (1) draws the normal scene, portal rectangles excluded; (2) for each enabled portal writes its rectangle into the stencil buffer with depth testing (hidden windows write nothing); (3) inside the stencil, draws the sky with the virtual view and depth func ALWAYS, which also resets depth to the far plane; (4) draws the scene with the virtual view `view · Mportal⁻¹` and a projection whose near plane is replaced by the target window plane (Lengyel's oblique frustum), so nothing between the virtual eye and the window (e.g. the van's own body) leaks in. The matrix maths (portal transform, oblique projection, plane clipping) is in C core and unit tested; the GL passes stay in the renderer. Stencil requires `GL_DEPTH24_STENCIL8` in the off-screen target and an 8-bit stencil on the default/WebXR framebuffer.
*Alternative*: render-to-texture per window. Rejected: per-window FBOs at the right resolution, extra cost, harder in XR.

### 3. Travel vortex as a distant tunnel
A spinning, UV-scrolling tunnel mesh lives far above the world (y = +600). During travel each portal's target is moved into the tunnel; afterwards it is set to the exterior van's windows again.

### 4. Decals: separate pass with polygon offset, plus better depth precision
Entities flagged `decal` (with a `layer` 0–7) are drawn after all opaque geometry and before translucent geometry, with depth test LEQUAL, depth writes off and `glPolygonOffset(-1, -(layer+1)·4)`. In addition `znear` becomes 0.1 and `zfar` follows the fog distance (+20 m), and roads/paths are built as strips that follow the terrain heights instead of flat planes. Water is a real surface at a biome water level, not a decal.
*Alternative*: lifting decals by a fixed offset. Rejected: still fails at distance and on slopes.

### 5. Deterministic noise and terrain in C core
`noise.c` provides a 32-bit integer hash (xxHash32 style finaliser), value noise with quintic interpolation and fBm, using only `float` add/mul and an integer lattice. The core is compiled with `-ffp-contract=off` (GCC/Clang) and `/fp:precise` (MSVC) so results are identical across platforms and on WebAssembly. Terrain height = fBm(seed, shape) blended towards flat spots (up to 16 circles with target height, radius and falloff). `mvl_terrain_build_chunk` builds a grid mesh (default 32 m chunk, 16×16 cells) whose border vertices are computed from the same function as neighbours, so there are no cracks; normals use central differences of the height function; colours blend a biome palette by height, slope and a noise term.
*Alternative*: generate terrain in Lua. Rejected: too slow on the web for 289 vertices × several chunks per second.

### 6. Streaming in Lua
`gen/chunks.lua` keeps a map of loaded chunks keyed by `cx,cz`. Each tick it sorts missing chunks within the load radius (3 chunks) by distance and generates at most one; chunks beyond the unload radius (5) are destroyed (entities destroyed, terrain mesh released). Chunk content uses a PRNG seeded with `hash(world_seed, cx, cz)`. Placed objects query `mvl.height`. Mesh slots become reusable through `mvl.release_mesh`.

### 7. Destinations and features
A destination descriptor is generated from `hash(save_seed, night, slot)`: name, biome, palette variation, terrain shape, water level, quest template and quest seed. Settlement buildings, quest items and quest targets are "features" with absolute positions computed once when the destination is entered; a chunk spawns the features inside its bounds unless the feature is marked consumed in the visit state. The console offers three new descriptors per night plus the visited ones (stored in the save as their ids).

### 8. Data-driven biomes and quests
`gen/biomes.lua` and `gen/quests.lua` are registries of plain Lua tables (palette ranges, sky/fog, terrain shape, textures, plants, props, character sprites, ambience, name syllables, allowed quests; quest templates with setup/talk/complete callbacks and text templates). The base game ships six biomes (marsh, brass bazaar, drowned archive, crystal desert, mushroom forest, snowy steppe) reusing and tinting existing art, and four quest templates. Mods call the same `register` functions.

### 9. Text-only dialogue
`dialogue.say` accepts line ids from `game/dialogue/lines.txt` or `{speaker = name, color = …, text = …}` tables built from templates. Voice playback code and the WAV clips are removed; the blip remains.

### 10. Sound and music from ElevenLabs, MP3 decoding
`tools/audiogen` reads `manifest.json` (id, kind, prompt, duration, loop, output). Sound effects and ambience loops use `textToSoundEffects` with `eleven_text_to_sound_v3`, `loop: true` for ambience and output `pcm_22050` wrapped as WAV (loops stay sample-exact; MP3 encoder padding would cause seams). Music uses `music.compose` (`music_v2_5`, instrumental, MP3 output) and is stored as `.mp3`; the engine decodes MP3 with the vendored public-domain `dr_mp3` single-file decoder in `third_party/` (excluded from coverage). Music tracks are looped by the script with a short crossfade. If the account cannot generate music (paid plans only) the tool skips those entries and keeps existing files.

### 11. Frustum culling
With chunks and portals the scene is drawn up to five times per frame. A bounding sphere per entity (from mesh bounds and scale) is tested against the six frustum planes (core function, unit tested) before drawing.

## Risks / Trade-offs

- [Float differences between platforms break determinism] → integer lattice + `-ffp-contract=off`; a game test compares a terrain fingerprint against a stored value on every CI platform.
- [Generation hitches on the web] → one chunk per tick budget; chunk grid 16×16; profile in the web smoke test (frame count over 5 s).
- [Portal passes cost draw calls] → frustum culling, max 4 windows in the base interior, portals skipped when their rectangle is off screen.
- [Stencil missing on some WebXR layers] → request `stencil: true` for the XR layer; if no stencil is available portals fall back to showing the sky colour.
- [Music needs a paid ElevenLabs plan] → the tool reports skipped tracks and the existing procedural music files stay in place.
- [Generated quests can become unwinnable] → items are only placed on walkable ground (slope check) within 60 m of the settlement and above water level; every template is completed by a game test on several seeds.
- [Coverage of new C code] → noise, terrain, frustum, portal maths and resource release get unit tests; `dr_mp3` lives in `third_party/` and is not counted.

## Migration Plan

- Old saves without `story.seed` get a new seed and their location is reset to home; flags for removed destinations are ignored.
- Mods that registered `destination = true` worlds keep loading but are no longer offered by the console; the modding guide shows how to register a biome instead.
- Rollback: revert the change commit; the removed worlds and voice clips are in git history.
