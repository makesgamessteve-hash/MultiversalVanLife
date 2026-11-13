# Proposal

## Why

The game has three handmade destinations, so every journey is the same and the "multiverse" ends after three nights. A multiversal travel game needs a cosmos that is endless yet coherent: places with real geology, life, peoples, beliefs and history that explain each other, and that remember the player. The van interior also cannot show where it is parked, flat decals flicker against the ground, and dialogue depends on pre-recorded voice clips that cannot follow generated content.

## What Changes

- **BREAKING** Remove the handmade destinations (Lanternfen, Clockwork Bazaar, Tidewater Library) and their fixed quests.
- Add a seeded, lazily generated cosmos with a top-down hierarchy: multiverse → universe → galaxy → star cluster → star system → planet → continent → country → land. Travelling somewhere generates only that place and its ungenerated ancestors; generation is deterministic and independent of the order of visits.
- Generate, on each level as appropriate: structure and layout, physics and metaphysics (magic sources, psionics, faster-than-light rules, real or silent gods), geology, climate, flora and fauna, intelligent species, languages, religions, traditions and calendars, technology, factions and spheres of influence, known individuals and major historic events. Parents commit facts that children must honour, and every generated fact records its causes.
- Store history as eras with snapshots so visiting the past can be added later (present day only for now).
- Make every visited place permanent: its generated description is stored, every action the player takes there is remembered, time passes between visits, consequences spread as rumours and history, and returning shows what the player changed.
- Choose destinations through Juniper's nightly signals (places in trouble, including follow-ups from places already visited) and a logbook of visited places; show the discovered lore in a codex that contrasts what people believe with what really happened.
- Keep Earth real: a fixed "Prime" universe with our physics, astronomy and an unsimulated Earth; only the farm's surroundings are generated.
- Generate quests from each place's present-day tensions and real stakeholders.
- Build plants, animals, peoples, clothing, buildings and monuments as voxel models at runtime from their generated traits, and generate textures, palettes and skies from the place's physics.
- Stream land terrain lazily in chunks that follow the planet's generated geography.
- Put the van interior into the same scene as the world and give it windows that are portals to the outside or to the travel vortex.
- Render flat decals (roads, paths, rugs) without z-fighting, and add hilly terrain and frustum culling.
- **BREAKING** Dialogue becomes text-only: remove the voice clips and the voice generation tool.
- Replace the procedural sound effects, ambience and music with sounds generated once with ElevenLabs and committed as assets; add MP3 support for music.
- **BREAKING** The save becomes a save folder with an index and one record per visited place.

## Capabilities

### New Capabilities
- `multiverse-generation`: The generation hierarchy: addresses, laziness, determinism, commitments between levels, causal links, universe metaphysics, cosmic structure, eras and budgets.
- `planet-generation`: Planet physics, tectonics, geology, climate, hydrology, biomes, the planet's sky, and the subdivision into continents, countries and lands.
- `life-generation`: Trees of life, adaptation to the environment, ecosystems, creature behaviour and intelligent species.
- `culture-generation`: Languages, religions, traditions, calendars, values, technology and architecture styles.
- `history-generation`: Chronicle simulation on every level, factions and spheres of influence, known individuals, historic events refined down the hierarchy, cultural memory, and present-day tensions.
- `world-memory`: Persistent visited places, remembered player actions, time between visits, consequences and the Wanderer's chronicle.
- `signals-and-codex`: Juniper's nightly signals, the logbook of visited places and the lore codex.
- `prime-universe`: The fixed Prime universe with the real Earth and the generated farm.
- `land-streaming`: Lazy chunk streaming of land terrain, settlements, roads, ruins and wildlife.
- `procedural-visuals`: Runtime voxel models, generated textures and palettes, and generated skies.
- `generated-quests`: Quests from present-day tensions with real stakeholders and lasting outcomes.
- `van-windows`: The van interior shares the world scene and its windows show the outside through portals.

### Modified Capabilities
- `story-and-worlds`: The console offers signals and the logbook, entering and leaving the van no longer loads a separate world, and the fixed destinations are removed.
- `rendering`: Adds terrain, decals without z-fighting and portal rendering.
- `audio-and-voice`: Dialogue becomes text-only, voice clips and the voice tool are removed, and an ElevenLabs sound effect and music tool is added.
- `data-and-mods`: Mods add generation passes and content instead of fixed destinations; MP3 becomes a supported format.
- `scripting-api`: Scripts get deterministic noise and generation kernels, runtime voxel models and textures, entity parenting, portals, decals, mesh release and persistent place storage.
- `save-games`: The save becomes a folder with an index and place records.
- `quality-and-testing`: Tests cover determinism, consistency, plausibility, variety, budgets and persistence instead of the fixed worlds.

## Impact

- Engine core (C): noise and terrain, planet-grid kernels (plates, climate, rivers, territory growth), voxel model building and texture generation, frustum culling, portal maths, decals, entity parenting, releasable mesh and texture slots, MP3 decoding (vendored public-domain `dr_mp3`), new Lua API, unit tests.
- Renderer: stencil buffer, decal pass, portal passes, generated skies with moons and a galaxy band.
- Game scripts: a new `gen/` framework (address and seed system, pass registry, budgeted coroutines, consistency checker) with generators for every level, `memory/` for persistent places and consequences, codex and signals UI, rewritten story, home and van; removal of the handmade worlds.
- Saves: new folder format with migration from the current single file.
- Assets: `van_interior.vox` with window openings, ElevenLabs sounds and music, removal of `game/voice/*.wav`.
- Tools: `tools/voicegen` replaced by `tools/audiogen` (music needs a paid ElevenLabs plan); a world-bible exporter for reviewing generated places.
- Tests, docs and CI: new unit and game tests, generation budgets in CI, README, modding guide and specs updated. The work is delivered in playable phases.
