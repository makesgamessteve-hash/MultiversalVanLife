# Tasks

Each phase ends with a playable game, passing unit/game/GL/web tests and ≥ 95% core line coverage (`ninja coverage`).

## 1. Engine foundations (core)

- [ ] 1.1 Add `noise.c/.h`: 32-bit integer hash, seedable PCG random stream, value noise 2D/3D and fBm on an integer lattice; compile the core with `-ffp-contract=off` / `/fp:precise`; verify with unit tests against stored reference values
- [ ] 1.2 Add terrain height function (seed, shape, coarse elevation map with bicubic sampling, up to 16 flat areas) and `mvl_terrain_build_chunk` (shared borders, central-difference normals, palette colours); verify neighbouring chunk borders match exactly and the height query equals mesh vertices in unit tests
- [ ] 1.3 Make mesh and texture slots releasable and reusable; verify a unit test creates and releases 10,000 of each
- [ ] 1.4 Add entity parenting with local transforms (children follow parent, destroyed with parent); verify transform and lifetime unit tests
- [ ] 1.5 Add decal flag and layer to entities and bounding-sphere frustum culling helpers; verify unit tests for field mapping and inside/outside/intersecting spheres
- [ ] 1.6 Add portal definitions (up to 8) with portal transform, virtual view and oblique near-plane projection; verify unit tests that points map to the target frame and points behind the target plane are clipped
- [ ] 1.7 Add a voxel grid API (allocate, fill box/sphere/cylinder/ellipsoid, mirror, paint, mesh) reusing the voxel mesher; verify unit tests for shape volumes and mesh face counts
- [ ] 1.8 Add procedural texture generation (noise stone, soil, bark, foliage, water, cloth patterns; palette parameters) at 32×32/64×64; verify unit tests for determinism and tiling seams
- [ ] 1.9 Add the data record format (serialise/parse plain tables, atomic write via temp file and rename, data-only parser); verify round-trip, corruption and "no code execution" unit tests
- [ ] 1.10 Vendor `dr_mp3` in `third_party/dr_libs` with its license and decode `.mp3` sounds; verify a unit test decodes a small committed fixture
- [ ] 1.11 Expose all of the above to Lua (`mvl.hash`, `mvl.rng`, `mvl.noise`, `mvl.terrain`, `mvl.height`, `mvl.terrain_chunk`, `mvl.release_mesh`, `mvl.release_texture`, `mvl.attach`, `mvl.portal`, `mvl.voxels`, `mvl.texture_gen`, `mvl.record_read/write`); verify engine API unit tests and coverage ≥ 95%

## 2. Renderer, van windows, decals and audio

- [ ] 2.1 Use depth+stencil render targets, request 8-bit stencil for the window and WebXR layer, set `znear` 0.1 and fog-based `zfar`; verify the GL game tests pass under Xvfb
- [ ] 2.2 Draw decals in their own pass with polygon offset per layer; verify a GL test renders a red decal over green terrain at 60 m and a shallow angle and finds no green pixels in the decal area
- [ ] 2.3 Implement stencil portal passes (mark, sky reset, virtual-view pass with oblique projection) for flat rendering and each XR view; verify a GL screenshot test shows the target scene inside the portal and nothing when occluded
- [ ] 2.4 Apply frustum culling and parented transforms in every pass; verify draw counts drop in a GL test log
- [ ] 2.5 Regenerate `van_interior.vox` with window openings in `tools/gen_assets.py`; verify `--check` passes and the openings exist
- [ ] 2.6 Make the van interior a pocket in the world scene (door teleports, no reload), windows as portals to the exterior van and to a vortex tunnel during travel; verify game tests for entering/leaving without reload and portal targets before, during and after travel
- [ ] 2.7 Move fixed lines to `game/dialogue/lines.txt`, support generated `{speaker, text}` lines, remove voice playback and `game/voice/*.wav`; verify a game test that dialogue types text with blips and no voice-group sound
- [ ] 2.8 Replace `tools/voicegen` with `tools/audiogen` (manifest of sound effects, ambience loops and music; WAV for sounds and loops, MP3 for music; skip-on-plan-error; node tests); verify `npm test` passes
- [ ] 2.9 Generate the manifest once with ElevenLabs and commit sounds and music; verify a game test loads every manifest entry and the van hum/world ambience crossfade on entering the van
- [ ] 2.10 Update README and modding guide for portals, decals, parenting and audio; verify the documented examples run in a game test

## 3. Generation framework, cosmos skeleton, signals and basic world memory

- [ ] 3.1 Add `gen/address.lua` (addresses, seeds per level and pass), `gen/registry.lua` (passes and content tables per level, mod registration) and `gen/run.lua` (coroutine runner with frame budgets and per-level caps); verify game tests for seed derivation, pass isolation and budget yielding
- [ ] 3.2 Add the fact store with stable ids and `because` links, commitments per child address and the LCA reference helpers; verify game tests that commitments are delivered to children and dangling references are detected
- [ ] 3.3 Add the consistency checker framework (commitments, references, chronology hooks) and the world-bible Markdown exporter (`mvl_headless --bible <address>`); verify a test exports a reference address and the checker passes
- [ ] 3.4 Generate the multiverse and universes (law sets, age, cosmic eras skeleton, galaxy density field, notable galaxies); verify determinism, order-independence and law-distribution tests over 200 seeds
- [ ] 3.5 Generate galaxies (morphology, age/metallicity fields, clusters by Poisson disc), clusters (stars, lanes) and star systems (planets, moons, belts, frost line); verify plausibility tests (spacing, metallicity gradients, lane connectivity)
- [ ] 3.6 Reserve the Prime universe `u0` with the fixed Milky Way, Sun, planets, Moon and Earth; generate the farm land from the seed; verify game tests that signals never target Prime, the codex has no Earth lore and two seeds give different farms with farmhouse, neighbour and van
- [ ] 3.7 Add temporary land generation (biome from star/planet skeleton, flat-ish terrain, simple settlement and a template quest) so the game is playable through the hierarchy; remove `fen.lua`, `market.lua`, `library.lua`; verify the intro and night-cycle game tests
- [ ] 3.8 Add land streaming (`gen/chunks.lua`: radius 3/5, one chunk per tick, flora/props/features, mesh release, neighbouring lands generated on approach); verify a game test walking 500 m keeps entities and meshes bounded and the player on the ground
- [ ] 3.9 Add the save folder (`index.ini`, place records, migration from old saves) and stored places (land description + ancestor summaries written on first arrival, loaded on revisit); verify game tests for continue, old-save migration and "revisit after generator change" (simulated version bump)
- [ ] 3.10 Add stable object ids and the change log (taken/dropped/given items, lit/opened/repaired/broken objects, partial quests) applied when chunks build; verify the "dropped item" and "two of four lanterns" game tests across leave and restart
- [ ] 3.11 Add the signal selector (three signals per night by severity, novelty and variety; follow-up slot), the logbook and the console UI; generation starts on selection and finishes during travel; verify game tests for variety over consecutive nights, logbook return and web frame rate during travel in the smoke test

## 4. Planets

- [ ] 4.1 Add the geodesic planet grid and C kernels for plates, elevation, wind/currents, temperature/moisture with rain shadow, rivers/lakes and biome classification; verify unit tests (rivers flow downhill, rain shadow, latitude bands)
- [ ] 4.2 Add planet physics from star and orbit (mass, gravity, atmosphere, temperature, day, tilt, year, tidal locking); verify plausibility tests over 200 seeds
- [ ] 4.3 Add geology and resources by tectonic setting and composition, and magic geography per universe law; verify tests that ore and magic distributions follow their sources
- [ ] 4.4 Subdivide planets into continents, provisional countries and lands; make land terrain follow the planet grid (elevation, rivers, coasts, biomes) across land borders; verify a game test crossing a land border and following a river
- [ ] 4.5 Generate planet skies (atmosphere colour, star disc, moons with phases, planets, galaxy band) in the sky shader; verify GL screenshot tests for a two-moon world and a red-dwarf world
- [ ] 4.6 Generate ground, rock, water and foliage textures and palettes from geology, biome and star light; verify tests that red-dwarf foliage palettes are dark and stone follows bedrock
- [ ] 4.7 Extend the world bible and consistency checker with planet sections; verify the checker over 200 planet seeds

## 5. Life

- [ ] 5.1 Generate biochemistry and lineages (body-plan trait vectors) per living planet; verify tests that all species descend from planet lineages
- [ ] 5.2 Radiate species into biomes with adaptation (gravity, air, temperature, light, magic) and ecological roles; verify food-chain and adaptation tests over many seeds
- [ ] 5.3 Build plants with a branch grammar and animals with body-plan assembly as voxel models, cached and shared; verify a GL screenshot gallery test and model cache tests
- [ ] 5.4 Animate creatures procedurally (gaits, wings, slithering, plant sway) with parenting; add behaviours (graze, herd, flee, prowl, fly, burrow) reacting to the player; verify the "prey flees" game test
- [ ] 5.5 Generate intelligent species from lineages or commitments with physiology traits; verify tests that committed homeworld species exist and anatomy constraints hold
- [ ] 5.6 Populate chunks with flora and fauna by biome, climate and soil; add bestiary codex entries; verify the "biome change" streaming game test

## 6. Cultures

- [ ] 6.1 Generate languages (anatomy-filtered phonology, syllable templates, root lexicon with meanings, compound names) and daughter languages by sound change; verify tests for beaked speakers, translatable names and related names in sister languages
- [ ] 6.2 Generate religions from sky, land, biology, magic and history motifs with doctrines, clergy and sacred sites; real deities in belief universes; verify motif-source tests over many seeds
- [ ] 6.3 Generate calendars from day, year and moons, holidays from astronomy and commemorations, rites, funerals and taboos constrained by geography and biology; verify the commemoration and funeral tests
- [ ] 6.4 Generate values and social structure from species instincts, environment and history; verify the desert hospitality test
- [ ] 6.5 Add the technology dependency graph with resource, domestication, trade, stability and magic branches; verify the "iron needs iron" test
- [ ] 6.6 Generate architecture style vectors and voxel buildings (floor plan grammar, materials from geology, roofs from climate, doors from anatomy, temples from religion); verify a GL gallery test and the local-stone test
- [ ] 6.7 Build people as voxel characters from species anatomy plus clothing in the culture's palette; verify that two species look different in a GL screenshot test

## 7. History

- [ ] 7.1 Implement the chronicle engine (factions on region graphs, level time steps, action and event tables, resolution with causes) for universe, galaxy, cluster, planet, continent, country and land; verify per-level tests for time scales and chronological order
- [ ] 7.2 Add territories and spheres of influence with present-day summaries; finalise country borders from history; verify the contested-border tension test
- [ ] 7.3 Add known individuals with lifespans, deeds and relations; place living individuals in their lands; verify lifespan consistency checks and the "meeting a legend" game test
- [ ] 7.4 Refine events into children via commitments and place traces (ruins, battlefields, monuments, craters, shrines) in lands; verify the galactic-war-on-a-planet and ruins tests
- [ ] 7.5 Store eras with state snapshots; verify the ruins-have-a-past test
- [ ] 7.6 Add cultural memory (distortion rules) storing believed and true versions; verify the two-versions-of-a-war test
- [ ] 7.7 Add present-day tensions with causes, stakeholders and severity; replace temporary land generation from 3.7 with the full pipeline; verify tension coverage tests over 200 seeds
- [ ] 7.8 Add Wanderer sightings to histories; verify the legend-before-the-visit game test
- [ ] 7.9 Extend the consistency checker and world bible with history sections; run them in CI over 200 seeds within budgets

## 8. Quests, dialogue, world memory and codex

- [ ] 8.1 Generate quests from tensions with real stakeholders using templates (relight, gather, return, lost person, message, mediate, escort, restore source); verify a game test completing each template on three seeds
- [ ] 8.2 Add outcome choices with lasting consequences; verify the water-dispute game test across revisits
- [ ] 8.3 Generate dialogue from templates using greetings, blessings, idioms, history versions, character memory and current events; verify the blessing and greeting-a-friend game tests
- [ ] 8.4 Add character memory (met, known-as name, favour, witnessed deeds); verify game tests across restart
- [ ] 8.5 Add the aftermath simulation for time between visits; verify the restored-well game test after ten nights
- [ ] 8.6 Spread deeds as history events, rumours and legends to neighbouring lands and up the hierarchy with faction attitude changes; verify the rumour-in-the-next-valley game test
- [ ] 8.7 Add visible marks (monuments, shrines, murals, renamed places, festivals) built in local style; verify the monument game test
- [ ] 8.8 Feed aftermath needs and invitations into follow-up signals; verify the called-back and invitation game tests
- [ ] 8.9 Add the codex UI (entries, cross-links, why-view, believed vs. true, translations, bestiary, Wanderer's chronicle) in the van and pause menu, with touch and gamepad navigation; verify codex game tests including unlocking by conversation

## 9. Integration, documentation and release

- [ ] 9.1 Add determinism fingerprints for reference addresses to CI on all platforms; verify CI fails on a deliberately changed kernel in a test branch
- [ ] 9.2 Add variety and budget tests over 200 seeds to CI and the web frame-rate check during travel; verify all pass on CI
- [ ] 9.3 Check save size for 200 visited lands stays under 20 MB; verify with a generated stress save
- [ ] 9.4 Rewrite the remaining game tests (touch, pause/XR, mods with generation content); verify `ctest` headless and `-L gl`, and the web smoke test
- [ ] 9.5 Update README, `docs/MODDING.md` (generation passes, content tables, records, new API) and CREDITS; add `docs/WORLDGEN.md` describing the hierarchy, passes and causal model; verify documented mod examples run in game tests
- [ ] 9.6 Push to `main`, check all CI jobs and the GitHub Pages build; verify by playing the published build

## Workflow follow-up

- Archive the change with `openspec archive procedural-multiverse` after the implementation is merged, so the main specs are updated.
- Verify `openspec validate --specs --strict` passes after archiving.
