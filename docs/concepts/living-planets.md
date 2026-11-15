# Concept: living planets

Status: agreed concept, planned as phases 25–33 in the [roadmap](../ROADMAP.md). It builds on
everything in [WORLDGEN.md](../WORLDGEN.md).

## Decisions

| Question | Decision |
|---|---|
| Scale | Planets keep their real size in the plan; the van can hop along roads between places |
| Density | A village is the right typical visit, but **buildings must be sized to people**: today's houses are far too small next to the player's view (§5.1) |
| Travel | **Continuous**: the player can walk and drive anywhere, across regions and borders; the world generates in chunks ahead of them from the planned geography |
| Phones | **Full density** everywhere; instead, chunks are loaded and unloaded much more on demand (§6) |
| People | Daily routines for now; no persistent lives between visits |

## 1. Where we are

The generator already makes whole planets: plates, elevation, climate, rivers, biomes, life,
peoples with languages, faiths, traditions, architecture, histories, borders and present-day
tensions. But between the planet and the place the player walks there is no plan, and the places
themselves are nearly empty.

| | Today | Consequence |
|---|---|---|
| Planet | 10,242 cells (level 5), 150–320 km apart; every field (elevation, climate, biome, country, culture) is per cell | Coherent at the scale of a continent only |
| Country | A political territory of 54 cells (median), about **2.8 million km²** | Large like Argentina or India |
| Walkable part of a country | **One** district: 16 × 16 lands of 2 km = 32 × 32 km, placed at the country's shore, river or capital | 0.04 % of the country exists; neighbouring countries never meet |
| Land (2 km) | One settlement at its middle: a square, 3–6 buildings, 2–4 villagers (+ quest people), a lane to the van; the other 99 % is terrain, flora and wildlife | Every land of a district looks like the same hamlet; nothing relates one village to the next |
| Roads | One "old road" per district, west to east | No network, no destinations |
| Streaming | Chunks of 32 m, 7 × 7 loaded (~110 m around the player), plants and animals per chunk from the land's habitats | Fine for wilderness, too little for towns |
| Engine | At most 2,048 entities, 1,024 meshes, 8 lights, one draw call per entity, no instancing | A dense town would hit the limits within a few chunks |

So: the worlds are believable as *planets on paper* (the bible) but not *on the ground*.

## 2. Goals

1. **Real planets.** Every point of a planet's surface has a place in the plan: you could land
   anywhere and the place knows what it is (the farmland belt around a city, the pass between two
   kingdoms, a fishing village at the river mouth), how it relates to its surroundings (the road
   to the capital, the next village 4 km downstream) and why (soil, water, history, faith).
2. **Lazy, as everything else.** Nothing is generated before it is needed, but every level keeps a
   small *plan* the next level refines. Plans are deterministic (seed + parent plan) and never
   stored in saves; only visited lands and their changes are.
3. **Living places.** Villages, towns and cities with as many buildings, props, plants, animals and
   people as a real place of their kind, busy or quiet with the time of day, shaped by their
   culture.
4. **Fast and small.** Within the time budgets of p24 on desktop and phone, the 2,048-entity scene,
   the web frame check and the 20 MB save budget.

## 3. A planet in layers

The planet is planned top-down at four resolutions. Each layer is generated on demand from the one
above it and answers questions about its area without generating anything below.

```
planet atlas      ~200 km cells   biome, climate, elevation, rivers  (exists)
                                  + population, land use, settlement seeds, trade routes, sea lanes   (new)
region plan       32 km tiles     elevation at 256 m, rivers, coast, settlement sites, road network,
                                  land use areas, named features (hills, lakes, forests)              (new)
land layout       2 km            terrain detail, settlement layouts (streets, lots, squares), fields,
                                  woods, paths, points of interest                                     (rework)
chunk content     32 m            buildings from lots, props, plants, people, animals                 (rework)
```

### 3.1 The surface grid (where places are)

*Decided: continuous travel.* The player walks and drives across land, region and country borders
without a loading screen; the next lands, regions and their plans are generated ahead of them.

Today a land's address `planet.kK.nN.lL` means "land L of the one district of country N". To make the
whole surface addressable, the walkable surface becomes one **planet-wide grid of regions** (32 km
tiles on a cube sphere: six faces, each cut into square tiles; Earth-sized planets have about
500,000 regions, of which a game touches a few dozen), each with its 16 × 16 lands as today:

```
planet.rR.lL        R = face × N² + row × N + column,   L = 16 × row + column (as today)
```

* **Continents and countries stay** as levels of the hierarchy for what they own: politics,
  culture, history, the country plan (§4.3) and their facts. They stop being the *spatial* parents
  of lands; a region knows which countries it touches from the atlas.
* **Borders are real lines**: two countries meet inside a region along the cell boundary; you can
  drive across a border, and the other side has the other people's villages, language and roads.
* **Commitments** (residents, monuments, traces) are made by the planet (as today) to regions and
  lands chosen from the plan (§4.4) instead of fixed land numbers.
* **Old saves**: visited lands are stored with their address and keep loading as they are; a
  version flag marks multiverses generated before the change, whose districts stay old-style.
  Fingerprints are updated once.

*Alternative considered:* keep per-country districts and only make them bigger (the whole country in
its own tangent frame). Less migration, but countries would still not meet, distortion grows with
country size, and a cross-border plan (a road from one kingdom to the next) would have no common
ground. The surface grid is the cleaner long-term choice, and continuous travel needs it.

*Real size, short trips.* With planets at their real size, towns are kilometres apart. Walking and
driving cover the near surroundings; for longer distances the van **hops along roads**: from a
signpost, the map or the console the player picks a place on the road network and the van drives
there at speed with the land streaming past at low detail, slowing down on arrival (no vortex,
the same planet). Only the lands at the destination and the far-ring view on the way are
generated.

### 3.2 The planet atlas (what is everywhere)

New per-cell fields computed in the planet pass from what exists (cheap: 10,242 cells):

| Field | From | Meaning |
|---|---|---|
| `fertility` | climate, soil (biome), slope, fresh water, magic | What the land can feed |
| `population` | fertility × the culture's technology (farming, irrigation, industry) × history (capitals attract, wars and plagues thin out, colonies grow) × tensions (drought) | People per km² |
| `urban` | technology, trade, coast and rivers | Share of people in towns and cities |
| `land_use` | fertility, culture (crops, herds), slope | farmland, pasture, orchards, managed forest, wild, mines, sacred land |
| `settlements` | population, urban share, rivers, coasts, crossings | Seeds of the cell's cities and towns (position inside the cell, rank, founding era) |
| `routes` | settlements, cost of terrain | Trade routes between cities (also across borders and the sea: lanes and ports) |

Uninhabited worlds get no settlements but still land use (wild, barren); spacefarers' worlds get
cities with spaceports; nomadic cultures (pastoral, low urbanisation) get seasonal camps instead of
villages; hive species dense burrow-cities; flyers vertical towns; peoples of the sea stilt
villages and harbours.

**Plan queries** answer questions about any point without generating lands:
`gen.plan.at(G, planet, lat, lon)` → country, culture, biome, population, land use, nearest
settlements and roads. Signals, dialogue ("the city of Ushet is two days' walk upriver"), quests
("carry this to the next village"), the codex and a map use them.

## 4. Region plans and the settlement network

### 4.1 The region plan (32 km)

Generated the first time any of its lands is needed (budget ≤ 20 ms):

* **Terrain**: elevation at 256 m from the planet with the coastal steepening of today, rivers
  traced from the planet's flow (with their names), lakes, coast.
* **Settlements**: the cell's seeds that fall into the region, and smaller places filled in by
  population: about one village per 4–10 km² of farmland, hamlets and farmsteads in between,
  following water and good soil. Each place gets a type, population, founding era (from history),
  culture, faith, specialty (fishing, mining, market, temple town, fortress, port, crossroads inn)
  and condition (thriving, declining, ruined — from history and tensions), named in its language.
* **Roads**: the trade routes crossing the region, then roads between towns and villages and
  tracks to farmsteads, routed by terrain cost (slope, rivers, wetland), with bridges and fords
  where they cross water and harbours where they meet the sea. Roads have a rank (highway, road,
  track, path) that sets their width, surface and traffic.
* **Land use areas**: fields around villages (crops of the local plants), pastures (herds), orchards,
  woods (managed near people, wild beyond), mines where ores are, sacred groves, ruins and
  battlefields of history, irrigated or terraced land where the culture does that.
* **Named features**: hills, forests, lakes and passes named in the local language, so a codex
  entry or a villager can say "beyond the Kafa woods".

### 4.2 Settlement types and sizes

| Type | Buildings | People | Shape |
|---|---|---|---|
| Farmstead | 1–3 | 3–10 | House, barn, yard, fields, animals |
| Hamlet | 3–8 | 10–40 | Along a track, shared well |
| Village | 15–40 | 50–300 | Square or street, shrine, workshops, gardens, fields around |
| Town | 80–300 | 500–3,000 | Market square, main streets, temple, inns, walls if the times need them, suburbs |
| City | 500–3,000 (over several lands) | 5,000–100,000 | Quarters (market, temple, craft, port, palace), walls and gates, plazas, avenues |
| Camp | 5–30 tents | 20–150 | Ring around fires, herds nearby (nomads) |

### 4.3 The country plan

A country node keeps what its people decide across regions: its capital and cities (from the atlas),
the roads it builds (rank, upkeep: a poor or warring country has broken roads), its laws on
building (walls, watchtowers on contested borders), its faith's sacred sites, where its festivals
take place, and the share of its land in each use. It is small (lists, not rasters) and makes
neighbouring regions agree.

### 4.4 History and commitments in the plan

Today's commitments go to fixed land numbers (resident 118, monument 119, traces 115–117). In the
plan they target real places: the founder's statue stands in the main square of the faith's first
city, a ruler lives in the capital's palace quarter, the ruins of a fallen capital lie where that
capital was, a battlefield where the war's region is, a wreck from a galactic war somewhere in the
wild. The ruins of an older era use that era's architecture (as today) and the plan keeps them out
of the living town's way.

## 5. Land layouts: places that look lived in

### 5.1 Buildings at human scale

*Decided: houses are too small next to the player.* Measured today: a generated house is 4–5 m
wide and 3.3–4.3 m deep with storeys of 2.75 m, and the 64 × 64 × 40 voxel grid caps every building
at 8 × 8 × 5 m; the player's eye is at 1.6 m, so a house reads like a garden shed. Buildings are
planned in metres from the people who live in them and only then turned into voxels (0.125 m, as
now, so detail stays):

| | Today | Planned (people 1.7 m tall) |
|---|---|---|
| Storey | 2.75 m | 1.75 × people height, at least 3.0 m (floor to floor) |
| Door | 1.15 × height | 1.25 × height, wider for wings and taurs |
| Cottage / hamlet house | 4–5 × 3.3–4.3 m, 1 storey | 8 × 6 m, 1–1.5 storeys (loft in the roof) |
| Village house | same | 10 × 8 m, 2 storeys, roof 3–5 m |
| Farmhouse + barn | same | 12 × 8 m house, 14 × 9 m barn, yard between |
| Town house | same | 6–8 m frontage × 10–12 m deep, 2–4 storeys, in rows |
| Inn, hall, workshop | 0.85–1 × house | 14 × 10 m (inn, 2–3 storeys), 20 × 10 m (hall), 9 × 8 m (workshop) |
| Temple | 1.3 × house | 14 × 24 m nave or a 6 m tower 12–20 m tall |
| Largest model | 8 × 8 × 5 m | 24 × 24 × 16 m per model; larger buildings (palaces, walls) from several modules |

Peoples of other sizes get buildings to their size (a 2.5 m people's doors and storeys are a third
larger; a small people's are smaller, but never below what the player can walk through). Generation
stays within its time budget: models are cached per style and kind, as now, and meshing uses the
existing greedy voxel mesher.

### 5.2 Layout by culture

A settlement's layout is generated from its type, site and culture:

* **Plan form** from the culture's values and the site: hierarchy → planned grid with a palace axis;
  tradition → organic lanes grown along old paths; collective peoples → a ring around a common hall;
  hives → dense clusters with tunnels; flyers → towers and platforms; peoples of the sea → stilts
  and canals; nomads → camps that change between visits.
* **Streets and lots**: streets from the roads that enter the settlement, a centre (square, market,
  temple close), blocks cut into lots sized to the people's buildings; gardens, yards and commons.
* **Building kinds** (the existing voxel grammar, extended): houses of several sizes and storeys,
  row houses, shops, workshops (smithy, potter, weaver: from the technology), inns and taverns,
  granaries, barns, stables, mills (water mills on rivers, windmills on windy hills), temples and
  shrines of the faith, schools, halls, palaces, towers, walls and gates, bridges, docks, warehouses,
  wells and fountains. Wear, repairs and ruins from the place's condition.
* **Fields and nature**: field parcels with crop rows (crops of the land's plants, harvested or
  green by season), hedges and fences, orchards in rows, gardens behind houses, village trees, and
  denser woods and undergrowth in the wild.

### 5.3 Props and decoration

Street furniture and the things of daily life, chosen from culture, technology and customs:
lamps (oil, lantern, magic, electric), market stalls with the local food (from the customs),
carts and their draught animals, barrels, crates, sacks, washing lines, benches, signposts written in
the native language, banners with faith symbols, statues, gravestones in the people's funeral
custom (no graves where they burn their dead), and decorations on holidays from the calendar
(lanterns for a full-moon feast, flowers for spring).

### 5.4 People and animals

* **How many**: from the settlement's population and the local time of day (the planet's day
  length and the visit's time already exist): a village square at midday is busy, at midnight a
  few lamplighters, guards and tavern guests; a feast night is crowded.
* **Who**: roles from the society (farmers, merchants, priests, guards, crafters, children, elders,
  travellers of other peoples on trade roads), in their culture's dress and body.
* **What they do** (*decided: routines for now*; nobody's life persists between visits beyond the
  characters of p21): simple routines on the layout: walk between home, work, market and temple
  along streets, tend stalls, work fields, sit, chat in pairs, follow processions on holidays,
  shelter from rain; children play; guards patrol walls.
* **Lazy characters**: background people are cheap and nameless until the player talks to them;
  then they become characters with a name in their language, a memory (p21) and lines from the
  grammar. Quest givers and parties are real characters from the start.
* **Animals**: herds in pastures, chickens and dogs in yards, draught animals with carts, pets, and
  the wild creatures of the habitat at the edges.

### 5.5 The van in a living place

The van lands at a fitting spot (an inn yard, a field by the road, a harbour quay), can be driven
along roads and through towns (§ van driving), and parked; people react to it (a crowd gathers
where the Wanderer legend is told).

## 6. Making density affordable

*Decided: full density on every device, phones included; instead, load and unload much more on
demand.* The near world is always complete; what is not near or not ahead is not kept.

**Streaming on demand.** Today 7 × 7 chunks of 32 m are kept around the player and one chunk is built
per tick. Instead:

* chunks are prioritised by distance and by the **direction of travel and speed**: driving loads a
  long corridor ahead (along the road) and drops what falls behind; standing still loads a ring;
* a fixed **resident budget** (entities, meshes, memory) per device class, with least recently used
  chunks, models and textures released first;
* chunk content is generated in **time slices** within the frame budget, nearest first, so arriving
  or driving fast never stalls; the far ring stands in until the near chunk is ready;
* lands, regions and their plans are generated ahead of the player along the predicted path (in the
  background, as travel destinations are today) and forgotten when far behind (they are cheap to
  regenerate; visited lands come back from the save).

| Problem | Proposal |
|---|---|
| One draw call and one entity per object (2,048 max) | **Static batching**: a new engine call merges a chunk's static objects (buildings, props, fences, ground cover) into a few meshes, one per material: one entity per material per chunk |
| Thousands of plants, crops and props of the same kinds | **Instancing** (GL 3.3 and WebGL2 both support it): one entity draws a mesh many times with per-instance position, rotation, scale and tint |
| Crowds | **Sprite batches**: one dynamic mesh of camera-facing quads per chunk, animated in the shader; only the ~30 nearest people are full entities with behaviour |
| Seeing a town from afar (view is ~110 m) | **Far ring**: per land, a low-detail impostor (terrain at low resolution, building blocks, tree clusters, lit windows at night) shown to 2–4 km; fog does the rest |
| 8 lights | Windows and lamps lit by vertex colour (unlit emissive), the 6 nearest real lights chosen per frame |
| Generation time | Budgets per layer (atlas, region, land, chunk) checked in CI as in p24; chunk content generated during streaming within the frame budget |
| Save size | Plans are never stored; a visited land stores its layout (streets, lots, fields: parameters, not instances) and the change log; per-chunk scatter is regenerated from seeds |
| Phones | Full density; the resident budget and the far-ring distance adapt to the device, not the density |

## 7. What it changes in the game

* **Signals** come from named places with a reason: "a call from the town of Ushet, on the river
  road below the Kafa hills".
* **Quests** use the plan: carry word to the next village (real, 3 km away on the road), escort
  someone to the city gate, settle a quarrel between two neighbouring villages, find what was lost
  in the woods; troubles spread over the places they really concern.
* **Driving and walking** have destinations: roads lead somewhere, signposts tell where.
* **The codex** gains places at every scale (regions, towns, roads, rivers, hills) and a **map** in
  the van: the planet atlas, then the region plan as the player explores.
* **World memory** keeps changes per land as now; consequences (p22) can reach a whole town.

## 8. Tests and guards

* Variety (p24 statistics): settlement types and sizes, plan forms, building kinds per place, land
  use mix; monotony thresholds as today.
* Plans: every land of a region agrees with the region plan (roads continue across land and region
  borders, rivers too); settlements never stand in water; ruins never under living houses; the
  checker over many seeds.
* Density: a village has 15–40 buildings, a town 80+; people outdoors follow the time of day.
* Performance: entity count per loaded area under budget, generation budgets per layer, the web
  travel and town frame checks, the save stress test with towns.
* Compatibility: old saves keep their visited lands; fingerprints updated once.

## 9. Phases

| Phase | Change | What |
|---|---|---|
| 25 | `p25-human-scale-buildings` | Buildings planned in metres from their people's size, larger voxel grids, the sizes of §5.1; the player and villagers next to them |
| 26 | `p26-planet-atlas` | Fertility, population, urbanisation, land use, settlement seeds and trade routes per cell; plan queries; statistics |
| 27 | `p27-surface-grid-and-regions` | Planet-wide region grid (cube sphere), region level and addresses, continuous lands across region and country borders, region terrain and rivers, version flag and save compatibility |
| 28 | `p28-settlement-network-and-roads` | Settlements in regions (types, sizes, specialties, condition), road network with bridges and harbours, land use areas, named features; commitments to real places |
| 29 | `p29-streaming-batching-and-lod` | Streaming on demand (direction and speed, resident budgets, time slices, generation ahead), static batching, instancing, sprite batches, far ring, light selection |
| 30 | `p30-settlement-layouts` | Plan forms by culture, streets and lots, more building kinds, fields, gardens and woods |
| 31 | `p31-props-and-decoration` | Street furniture, market goods, graves by custom, signposts in the language, festival decorations |
| 32 | `p32-people-routines-and-animals` | Population to visible people, roles, daily routines, crowds, lazy characters, domestic animals |
| 33 | `p33-road-hops-and-integration` | Road hops of the van, signals from named places, quests over real distances, map and codex, statistics, budgets and the save stress test for towns |

Each phase ends playable with all tests passing, as before.
