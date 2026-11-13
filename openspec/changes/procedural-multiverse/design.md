# Design

## Context

See proposal.md for motivation and the specs for the required behaviour. Relevant current state:

- The scene is a single flat entity list (`engine/src/core/scene.c`); `world.load` in Lua clears it and builds one hand-written world. The van interior is its own world, so entering the van reloads the scene with a fade.
- Ground is one flat plane at y = 0; water and roads are planes 1–5 cm above it with a 24-bit depth buffer, `znear = 0.05`, `zfar = 200`, hence the flicker.
- Mesh and texture resources live in fixed tables (256 slots) that are never freed; voxel meshes come only from `.vox` files.
- Saves are one `key = value` file; dialogue lines and voice clips live in `game/voice/`; sounds are procedural from `tools/gen_assets.py`.
- Constraints: the engine core stays free of SDL/OpenGL with ≥ 95% line coverage; gameplay and content rules stay in moddable Lua; the web build must stay responsive on phones.

## Goals / Non-Goals

**Goals:**
- An endless, lazily generated cosmos that is internally consistent across nine levels and explains itself (causal links).
- Deep, interconnected generation: physics → geology → climate → life → peoples → beliefs → history → present → quests, on every level where it applies.
- Permanent world memory: visited places and all player changes persist and develop over time.
- Determinism across platforms and order of visits; bounded time and memory per generation step.
- Keep the core testable: numeric kernels in C with unit tests, content rules in Lua with game tests and a consistency checker.

**Non-Goals:**
- Visiting the past (the data model supports it; the game shows the present).
- Simulating or depicting Earth's real history, peoples or religions.
- Full physics simulation (climate, erosion and plates are plausible approximations, not science-grade).
- Free navigation of the cosmos map; destinations come from signals and the logbook.
- Natural-language generation beyond templates and grammars.
- Recursive portals; caves or terrain editing.

## Decisions

### 1. Addresses, seeds and generation passes
An address is the index path `u.g.c.s.p.k.n.l`. A node's seed is `hash(parent_seed, level, index)` with a 32-bit integer hash; seeds never depend on other nodes' contents, which gives order independence. Generation of a node is split into named **passes** registered per level (for a planet: `physics`, `plates`, `geology`, `climate`, `hydrology`, `biomes`, `life`, `species`, `cultures`, `history`, `present`, `subdivide`). Each pass reads the parent node, earlier passes of the same node and commitments, and writes its own fields. Mods register additional passes or content tables through the same registry. Each pass draws randomness from its own stream `hash(node_seed, pass_name)`, so adding a pass does not reshuffle the others.
*Alternative*: one monolithic generator per level. Rejected: impossible to extend by mods and to test in isolation.

### 2. Skeletons, details and commitments
Generating a node has two depths. A **skeleton** is the cheap summary of a child that the parent needs for its own work (position, size, type, a few key traits). A **detail** generation runs all passes, and only happens on the travel path. When a parent's passes decide something about a child (a homeworld, a capital, a battle, a birthplace, an artifact, a colony, a migration), they append a **commitment** to that child's address in the parent's data. A child's passes satisfy their commitments first (constraint-first generation), then fill in the rest. Anything spanning several children (empires, religions, species, trade routes) is defined on the lowest common ancestor (the LCA rule) and referenced by id.
*Alternative*: simulate everything bottom-up then aggregate. Rejected: forces generating siblings, which breaks laziness.

### 3. Causal links and the fact graph
Generated facts are stored in tables with stable ids (`<address>/<kind>/<n>`). Each fact carries a `because` list of fact ids that caused it. The codex "why" view, the consistency checker and the world bible export all walk this graph. It costs a few integers per fact and needs no inference engine.

### 4. Universe metaphysics drives everything below
Each universe draws a law set: magic source (none, life, stellar, tectonic, belief), magic and psionic strengths, faster-than-light mode (none, gates, jumps), real or silent gods, age, and cosmic eras (from the elder ages of the first civilisations to the present). Every lower pass reads these laws: magic geography on planets, fauna with magical traits, technology versus magic balance in cultures, real deities in religions, and whether interstellar factions can exist (no faster-than-light travel means no interstellar empires, only generation ships and isolated worlds).

### 5. Cosmic structure
- **Universe**: an implicit, endless galaxy density field (noise over a 3D lattice); only **notable galaxies** (those history touches) are listed explicitly, the rest are generated on demand when a signal points there.
- **Galaxy**: a morphology (spiral with 2–6 arms, barred, elliptical, irregular, ring) gives a density and age/metallicity field; clusters are sampled along it with Poisson-disc distribution; the galactic habitable zone favours rocky planets.
- **Star cluster**: open, globular or stellar nursery; stars sampled from a mass function shaped by cluster age; travel lanes for gate or jump universes form a relative neighbourhood graph.
- **Star system**: star(s) from the skeleton; planets placed with spacing rules and frost line; moons and belts; physics derived from orbit and composition.

### 6. Planet grid and numeric kernels in C
Planets use a geodesic sphere grid of about 10,000 cells (an icosahedron subdivision) generated in C. Kernels (all deterministic, unit tested): plate seeding and growth, plate motion and boundary classification, elevation from boundaries plus noise, simple ocean currents and wind belts by latitude, temperature and moisture advection with rain shadow, flow-direction and accumulation for rivers and lakes, biome classification (Whittaker-style table extended for alien conditions), territory growth on region graphs (weighted multi-source Dijkstra for country borders) and Poisson-disc sampling. Lua receives compact arrays and keeps only what later passes need. Continents are connected land cell sets; countries come from history's territories at the present; lands are cell groups of about 2–4 km² each.
*Alternative*: everything in Lua. Rejected: on the web the climate and river passes would take seconds.

### 7. Life
A planet with life draws a biochemistry from its conditions and the universe's laws (carbon/water, ammonia, silicon at extremes; magical life where magic is strong). A small set of **lineages** (body plans as trait vectors: symmetry, limb count, covering, locomotion modes, sense organs, size range) radiates into biomes; species are trait vectors adapted to biome pressures (gravity, air density, temperature, light spectrum, predators) and assigned ecological roles with simple population ratios. Intelligent species branch from a lineage (or are committed from above) and get physiology traits used by culture passes. Names come from the observing culture's language when one exists, otherwise from a scientific-sounding lexicon.

### 8. Cultures: language, religion, traditions, technology, architecture
- **Language**: phoneme inventory filtered by anatomy, syllable template, a root lexicon of ~300 meanings; names compose roots by meaning ("tide" + "kneel" → *Ossery*). Splits in history create daughter languages through regular sound-change rules, giving related names and older forms on ruins.
- **Religion**: a motif table maps sources to motifs (two moons → twin gods; volcano → fire mother; short lifespan → rebirth; tectonic magic → earth spirits; historic founder → saint). A religion is a weighted selection of motifs with doctrines (virtues, taboos, afterlife), clergy, sacred sites and calendar feasts; schisms and conversions are history events.
- **Traditions and calendar**: calendar units from day, year and moon periods; holidays from astronomical events (solstices, eclipses, conjunctions) and commemorations of history events; funerals, rites and food taboos chosen from tables constrained by geography, species biology and religion.
- **Technology**: per faction a tech level per era from a dependency graph (fire → pottery → bronze → iron → … → spaceflight), unlocked by resources, domestication, population, stability and trade; magic and psionics open alternative branches (enchanting, psionic communes) that can substitute for or complement mechanics.
- **Architecture**: a style vector (materials, roof pitch, wall thickness, plan shape, openings, ornament motifs, temple orientation) derived from geology, climate, anatomy, religion and tech, consumed by the voxel builders.

### 9. History: one chronicle engine for all levels
A generic simulator runs factions on a region graph of the node's children (clusters, systems, continents, countries, lands) with a level-specific time step and event table. Each step every faction picks actions weighted by traits, resources, relations and laws; resolution produces events with participants, places, dates and causes. Individuals are created by events (founders, generals, prophets) with lifespans from species biology; long-lived species keep figures alive into the present. Events touching children become commitments for their refinement. Eras are cut where the state changes most (collapses, conquests, revolutions); each era stores a snapshot of territories, populations, rulers and tech. Cultural memory derives each culture's version of events with distortion rules. The present-day pass turns the final state into **tensions** with causes, stakeholders and severity. Wanderer sightings are sprinkled into histories with a low rate, consistent with Juniper's lore.
*Alternative*: pure template storytelling without simulation. Rejected: no causal consistency between factions, places and people.

### 10. Laziness, budgets and caching
All passes run as Lua coroutines that yield when the frame budget (default 6 ms, 2 ms on the web while not travelling) is used up; the travel sequence raises the budget and lasts until the destination is ready. Caps per level (factions, events, individuals, languages, species) bound cost. Generated nodes are cached in memory with an LRU limit; the path to the current land stays pinned.

### 11. World memory
- **Stored places**: on first arrival, the land's description and the summaries of its ancestors (what the land and codex need, not full ancestor data) are written as records in the save folder. Revisits load records instead of regenerating, so game updates and mod changes never alter visited places.
- **Change log**: every persistent object (item, lamp, door, well, building, character, creature group) has a stable id within its land. Changes are stored as state overrides; objects created by the player get new ids. Chunks apply overrides when they build.
- **Character memory**: per character a small record (met, name known as, favour, deeds witnessed).
- **Time between visits**: each land records the night of the last visit. On return, an **aftermath simulation** advances the land's local state by the elapsed time using the same tension/event rules at land scale: populations, buildings, relationships and new tensions caused by the player's outcomes. Results are written back as changes.
- **Spread**: deeds become history events of the land with a fame value; on later generation or revisit of neighbouring lands, countries and planets, rumours and legends with distortion are injected and faction attitudes adjusted.
- **Visible marks**: aftermath rules can add monuments, shrines, murals, renamed places and festivals, built by the voxel builders in the local style.
- **Follow-up signals**: aftermath and spread produce invitations and needs that feed the signal selector with a guaranteed slot.

### 12. Save format
The save becomes a folder: `index.ini` (key/value as today) plus `places/<address>.rec` and `codex.rec`, `chronicle.rec`. Records are a compact binary-safe serialisation of plain tables written by the engine (temp file + rename for atomicity) and parsed by a data-only reader (no Lua `load`). The web build keeps the folder under the IndexedDB mount. Old single-file saves are converted on load.

### 13. Prime universe
Address `u0` is reserved for Prime and is excluded from the multiverse generator and from signal selection. It contains a fixed Milky Way, Sun, real planets, Moon and Earth with an astronomical model good enough for the sky (Moon phase from the date in game). Only the farm land is generated (from the save seed, using a rural temperate biome and a fixed farmhouse, gate and van spot). Prime has no generated history, factions or religions; galaxy histories elsewhere may mention "quiet worlds" without naming Earth.

### 14. Runtime voxel models and textures
C core gains a voxel grid API (fill boxes, spheres, cylinders, mirror, paint) and builds meshes with the existing mesher. Lua builders turn traits into grids:
- **Plants**: an L-system-like branch grammar per lineage (trunk, branches, leaves, fronds, caps).
- **Creatures and people**: body-plan assembly (torso segments, limbs, heads, wings, tails) with sizes from traits and colours from adaptation; clothing layers in the culture's palette.
- **Buildings**: architecture style plus a floor plan grammar; monuments compose a plinth with the honoured individual's body model.

Textures are generated in C from parameters (noise-based stone, soil, bark, foliage, water, cloth patterns) at 32×32 or 64×64 for the retro look. Models and textures are cached by parameter hash, shared between instances, and released when unused. Composite and animated models use entity parenting (limbs as children) with procedural animation in Lua (gait cycles, wing flaps, sway). The existing art remains as fallback and for the van.

### 15. Signals and codex UI
The signal selector scores the present-day tensions of candidate lands (generated as skeletons from random addresses across universes, galaxies and planets, plus visited places) by severity, novelty and variety, and offers three with one follow-up slot. Choosing a signal starts path generation immediately. The codex is a paged in-van and pause-menu UI backed by the fact graph and the player's discovery set; it shows believed and true versions side by side.

### 16. Earlier decisions kept
- **Van interior as a pocket in the world scene**: spawned far below the terrain and never unloaded; door teleports; travel replaces only the outside world.
- **Stencil portals with oblique near-plane clipping**: windows show the matching exterior view; a vortex tunnel far above the world is the travel view.
- **Decals**: separate pass after opaque geometry with polygon offset per layer, depth writes off; `znear` 0.1, fog-based `zfar`; roads follow the terrain; water is a real surface at the water level.
- **Terrain**: deterministic noise (integer lattice, `-ffp-contract=off` / `/fp:precise`), chunks of 32 m × 16 cells with shared borders, following the land's coarse elevation from the planet grid.
- **Streaming**: load radius 3 chunks, unload radius 5, one chunk per tick, mesh release.
- **Frustum culling** in every pass.
- **Text-only dialogue** from `game/dialogue/lines.txt` plus templates.
- **ElevenLabs audio**: `tools/audiogen` generates sound effects and loops as WAV (`eleven_text_to_sound_v3`, loop mode) and music as MP3 (`music_v2_5`), decoded with vendored `dr_mp3`; tracks the plan cannot generate are skipped.

## Risks / Trade-offs

- [Scope is very large] → delivered in playable phases (see tasks); each phase ends with a working game and passing CI.
- [Float differences break determinism] → integer hashing everywhere, floats only in C kernels compiled without contraction, fingerprints of reference addresses checked on every CI platform.
- [Generation hitches on the web] → coroutine passes with frame budgets, generation during console and travel, C kernels for numeric work, per-level caps.
- [Generated content feels like random soup] → strong causal rules, the consistency checker, variety tests over 200 seeds, and the world bible export for human review and tuning.
- [Save growth with permanent memory] → store descriptions and overrides, never geometry; records only for visited lands; target under 20 MB for 200 lands.
- [Persistence vs. generator updates] → visited places are frozen records; only unvisited places use the new generator.
- [Quests becoming unwinnable] → items only on walkable ground near the giver, every template completed by game tests on several seeds, abandon option.
- [Voxel model variety looking crude] → body-plan and architecture grammars with curated part tables, palettes from the environment, retro low-resolution look accepted.
- [Music needs a paid ElevenLabs plan] → the tool skips music it cannot generate and keeps the existing files.
- [Coverage of new C code] → kernels, voxel API, textures, records, portals and culling get unit tests; `dr_mp3` lives in `third_party/` and is not counted.

## Migration Plan

- Old saves are converted on load: a seed is created, the location resets to home, flags for removed destinations are dropped.
- Mods registering `destination = true` worlds keep loading but are no longer offered; the modding guide shows how to register generation content.
- Each phase is merged to `main` separately with CI green; rollback is reverting the phase's commits (removed worlds and voice clips remain in history).
