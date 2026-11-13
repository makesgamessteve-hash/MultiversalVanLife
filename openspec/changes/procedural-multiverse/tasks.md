# Tasks

## 1. Core: deterministic noise and terrain

- [ ] 1.1 Add `engine/src/core/noise.c/.h` (32-bit hash, value noise, fBm) and compile the core with `-ffp-contract=off` / `/fp:precise`; verify with unit tests for known hash/noise values and range checks
- [ ] 1.2 Add terrain height function with up to 16 flat spots and `mvl_terrain_build_chunk` (grid mesh, shared borders, central-difference normals, palette colours); verify with unit tests that neighbouring chunk border vertices match exactly and heights equal the height query
- [ ] 1.3 Add `mvl_res_mesh_release` with slot reuse; verify with a unit test that creates and releases 10,000 meshes without failure
- [ ] 1.4 Expose `mvl.hash`, `mvl.noise`, `mvl.terrain{}`, `mvl.height`, `mvl.terrain_chunk`, `mvl.release_mesh` in `script.c`; verify with engine API unit tests and keep `ninja coverage` ≥ 95%

## 2. Core: decals, frustum culling, portals

- [ ] 2.1 Add `decal` flag and `layer` to entities (`mvl.spawn{decal = true, layer = n}`); verify with a unit test of the Lua field mapping
- [ ] 2.2 Add bounding-sphere frustum culling helpers to the core; verify with unit tests for inside/outside/intersecting spheres
- [ ] 2.3 Add portal definitions to the scene (up to 8; rectangle + target frame) with core functions for the portal transform, virtual view and oblique near-plane projection; expose `mvl.portal(i, {...})` / `mvl.portal(i)`; verify with unit tests that a point seen through a portal maps to the target frame and that points behind the target plane are clipped

## 3. Renderer

- [ ] 3.1 Switch render targets to depth+stencil, request an 8-bit stencil for the window and WebXR layer, set `znear` 0.1 and fog-based `zfar`; verify the GL game tests still pass under Xvfb
- [ ] 3.2 Draw decals in their own pass with polygon offset per layer; verify with a GL test that renders a red decal over green terrain at 60 m and a shallow angle and checks the screenshot contains no green pixels inside the decal area
- [ ] 3.3 Implement the stencil portal passes (stencil mark, sky reset, virtual-view world pass with oblique projection) for flat rendering and each XR view; verify with a GL test screenshot that a portal shows a distinctly coloured target scene and nothing when occluded
- [ ] 3.4 Apply frustum culling in every pass; verify draw counts drop in a GL test log and frame time in the web smoke test stays under the budget

## 4. MP3 support

- [ ] 4.1 Vendor `dr_mp3` in `third_party/dr_libs` with its license and decode `.mp3` in `mvl_res_sound`; verify with a unit test that decodes a small committed MP3 fixture

## 5. Generation framework (Lua)

- [ ] 5.1 Add `gen/rng.lua` (seeded 64-bit PRNG on top of `mvl.hash`) and `gen/names.lua` (syllable names); verify with a game test that the same seed gives the same sequences and names
- [ ] 5.2 Add `gen/biomes.lua` registry with six base biomes reusing/tinting existing art; verify a game test generates every biome without script errors
- [ ] 5.3 Add `gen/destinations.lua` (descriptor from seed, night and slot; visited list in the save; new seed on new journey; old-save migration); verify with game tests for determinism, three new offers per night and save/continue
- [ ] 5.4 Add `gen/chunks.lua` streaming (load radius 3, unload radius 5, one chunk per tick, terrain + flora + props + feature spawning, mesh release); verify with a game test walking 500 m that entity and mesh counts stay bounded and the player stays on the terrain
- [ ] 5.5 Add `gen/settlements.lua` (flattened settlement around the landing spot, buildings, villagers with generated names, tinted sprites and template chatter); verify with a game test that a quest giver is within 25 m of the van door

## 6. Quests and dialogue

- [ ] 6.1 Move fixed lines to `game/dialogue/lines.txt`, make `dialogue.say` accept generated `{speaker, text}` lines, remove voice playback and `game/voice/*.wav`; verify with a game test that dialogue shows text and no voice-group sound plays
- [ ] 6.2 Add `gen/quests.lua` with the relight, gather, return and lost-person templates, text templates and completion stored in the save; verify each template with a game test that completes it on three seeds
- [ ] 6.3 Make completed quests stay completed on revisits (no item respawn, giver thanks the player); verify with a game test that revisits a helped destination

## 7. Story, home and van

- [ ] 7.1 Regenerate `van_interior.vox` with window openings in `tools/gen_assets.py`; verify `gen_assets.py --check` passes and the openings are present
- [ ] 7.2 Rewrite `story.lua` / `worlds/van.lua` so the interior is a pocket in the world scene, door teleports without a fade, windows are portals to the exterior van windows and the vortex during travel; verify with game tests for entering/leaving without world reload and portal targets before, during and after travel
- [ ] 7.3 Generate the home farm from the seed (`worlds/home.lua` via the generator with a farm biome and fixed farmhouse/gate/van spot); verify with a game test that two seeds give different layouts with a farmhouse, neighbour and van
- [ ] 7.4 Remove `fen.lua`, `market.lua`, `library.lua`, update the console (offers + visited + home) and milestone line every third helped destination; verify with the night-cycle game test

## 8. Sound and music

- [ ] 8.1 Replace `tools/voicegen` with `tools/audiogen` (manifest of sound effects, ambience loops and music; WAV for sounds/loops, MP3 for music; skip-on-plan-error) with node tests; verify `npm test` passes
- [ ] 8.2 Generate all manifest entries once with ElevenLabs and commit them under `game/sounds` and `game/music`; verify every manifest entry has a file and a game test loads all biome soundscapes

## 9. Tests, docs and specs

- [ ] 9.1 Rewrite the remaining game tests (intro, night cycle, touch, pause/XR, mods with a mod biome) for generated content; verify `ctest` passes headless and with `-L gl` under Xvfb, and the web smoke test passes
- [ ] 9.2 Update README, `docs/MODDING.md` (biomes, quest templates, portals, decals, new API) and CREDITS (dr_mp3, ElevenLabs audio); verify the documented mod example runs as the `test_mods` game test
- [ ] 9.3 Run the full CI on push to `main` and check the GitHub Pages build plays; verify all CI jobs pass

## Workflow follow-up

- Archive the change with `openspec archive procedural-multiverse` after the implementation is merged, so the main specs are updated.
- Verify `openspec validate --specs --strict` passes after archiving.
