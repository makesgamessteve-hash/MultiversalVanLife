# World generation

Multiversal Van Life generates its multiverse lazily from one seed per save.
This document describes the framework every generator plugs into
(`game/scripts/gen.lua` and `game/scripts/gen/`) and every generator built
on it, from the multiverse down to a village square: universe laws,
galaxies, stars and planets with their geology, climate, skies and life,
the peoples living there with their languages, faiths, traditions,
buildings and histories, the troubles of the present that become quests,
what the player's deeds change, and the codex where the player keeps what
they learned. It ends with the guards that keep all of it varied, fast and
small.

**Contents**: [levels and addresses](#levels-and-addresses) ·
[seeds](#seeds) · [passes](#passes) · [laziness](#laziness-summaries-and-detail) ·
[facts and causes](#facts-and-causes) · [commitments](#commitments) ·
[budgets and caps](#budgets-and-caps) · [versions and mods](#versions-and-mods) ·
[checks](#consistency-checks) · [world bible](#world-bible) ·
[the cosmos](#the-cosmos-top-down) · [Prime](#prime) · [life](#life) ·
[languages and religions](#cultures-languages-and-religions) ·
[traditions, society and technology](#cultures-traditions-society-and-technology) ·
[architecture and people](#cultures-architecture-dress-and-people) ·
[history](#history) · [skies](#skies-and-palettes) · [lands](#lands-and-chunks) ·
[signals](#signals-provisional-worlds-and-quests) · [world memory](#world-memory) ·
[the codex](#the-codex) · [variety, budgets and save size](#variety-budgets-and-save-size) ·
[fingerprints](#fingerprints) · [example](#example)

## Levels and addresses

The cosmos has nine levels. Every place has an **address** listing its
index on each level below the multiverse:

| Level | Prefix | Example address |
|---|---|---|
| multiverse | – | `""` (the empty address) |
| universe | `u` | `u3` |
| galaxy | `g` | `u3.g12` |
| star cluster | `c` | `u3.g12.c4` |
| star system | `s` | `u3.g12.c4.s1` |
| planet | `p` | `u3.g12.c4.s1.p2` |
| continent | `k` | `u3.g12.c4.s1.p2.k0` |
| country | `n` | `u3.g12.c4.s1.p2.k0.n5` |
| land | `l` | `u3.g12.c4.s1.p2.k0.n5.l7` |

`gen.address` parses, formats and compares addresses (`parent`, `child`,
`path`, `common`, `is_ancestor`).

## Seeds

A place's seed depends only on the save's multiverse seed and its address:

```
seed("")           = the save's seed (index.ini: story.seed)
seed(parent.child) = hash(seed(parent), level, index)
```

Each generation **pass** draws from its own random stream,
`hash(seed(place), pass name)`. Adding or removing a pass therefore never
changes the numbers any other pass sees, and nothing depends on which places
were generated before: results are identical in any order.

## Passes

A registry (`gen.cosmos` for the game) holds the passes of every level. A
pass reads its place's summary, its parent and ancestors, earlier passes and
the commitments made to it, and writes its own fields:

```lua
gen.cosmos:pass("galaxy", "shape", {
  after = { "age" },            -- passes of the same level that run first
  run = function(ctx)
    local rng = ctx:rng()       -- this pass's random stream
    ctx.data.arms = rng:int(2, 6)
  end,
})
```

Passes run in dependency order, ties broken by name. Registering a pass with
an existing name replaces it, which lets a mod rewrite any part of the game's
generation. `registry:content(name, entries)` collects content tables that
generators draw from and mods extend.

### The pass context

| Call | Purpose |
|---|---|
| `ctx.data`, `ctx.summary`, `ctx.node`, `ctx.parent` | This place's generated fields, its summary from the parent, the place and its parent |
| `ctx:rng()`, `ctx:random(name)` | The pass's random stream, or a further independent one |
| `ctx:ancestor(level)` | A generated ancestor |
| `ctx:child(index, summary)` | Lists a child with a cheap summary (its skeleton) |
| `ctx:fact(kind, data, because)` | Records a fact; returns its id `<address>/<kind>/<n>` |
| `ctx:shared(kind, data, members, because)` | A fact involving several places below (see below) |
| `ctx:commit(target, kind, data, because)` | Promises that a place below will contain something |
| `ctx:commitments(kind)`, `ctx:honour(c, fact_id)` | Commitments made to this place, and marking them kept |
| `ctx:ref(id)` | A fact of this place or an ancestor |
| `ctx:yield()` | Lets the runner pause if the frame budget is spent |
| `ctx:table(name)` | A content table |

## Laziness: summaries and detail

Requesting an address generates that place and every ancestor that is not
generated yet, from the top down, **in detail** (all passes). Siblings and
other places only exist as the summaries their parent listed with
`ctx:child`, or that the level's skeleton function computes on demand
(`registry:skeleton(level, fn)`, for levels with endless children such as
galaxies). Once a place lists children, only listed children exist.

```lua
gen.start(seed)                                   -- the save's runner
gen.world:request("u1.g2", function(node) ... end) -- generated over frames
local node = gen.world:generate("u1.g2")          -- or right now
```

## Facts and causes

Every fact records the facts it was derived from (`because`). The game
answers "why?" by following them: `G:why(id)` lists the causes and
`G:explain(id)` prints the chain:

```
r1.i0.g0/shrine/1: Shrine of Moss
  because /commitment/1: shrine promised to r1.i0.g0
    because /alliance/1: Tide Pact
      because /era/1: The Dawn
```

## Shared things live on the common ancestor

Anything involving more than one child (a faction, a species, a religion, a
trade route) is defined on the lowest place that contains all of them, with
`ctx:shared(kind, data, members)`. Defining it higher or lower is an error;
descendants refer to it by id instead of redefining it. References may only
point to facts on a place's own path, so this rule is also checked.

## Commitments

When a level decides something about a place inside it (a homeworld, a
capital, a battle site, an artifact's resting place), it records a
**commitment** on the target address, even several levels down. The target's
passes read `ctx:commitments(kind)`, generate what was promised and mark it
with `ctx:honour(c, fact_id)`. An unhonoured commitment is a consistency
error.

## Budgets and caps

Generation runs in a coroutine. Passes call `ctx:yield()` between units of
work; the runner pauses once the frame budget (default 6 ms per update) is
spent, so the game keeps rendering while large places are generated.
`gen.update()` is called every tick. Each level has caps on its number of
children and facts (`registry:caps(level, { children = n, facts = n })`).

## Versions and mods

Every generated place records the generator version (`gen.VERSION`) and the
sorted list of active mods. Phase 10 uses this to keep visited places as
they were when the generator changes.

## Consistency checks

`gen.check.run(G)` checks every generated place: commitments honoured,
causes and `*_id` / `*_ids` references resolve to facts on the path, effects
not before their causes (`year`), spans forwards (`from` ≤ `to`), shared
facts on the lowest common ancestor, plus checks generators register with
`registry:check(name, fn(node, report, G))`. Tests run it over many seeds.

## World bible

```bash
./build/mvl_headless --data game --bible u1.g2.c3 --seed 77 --out bible.md
```

writes a Markdown document with one section per place on the path: its
summary, generated fields, children, facts with linked causes and the
promises it kept.

## Deterministic numbers

Generators must produce bit-identical results on Windows, Linux, macOS and
the web. Integer hashing, the random streams and `mvl.noise` are exact; so
are `+ - * /`, `math.sqrt` and `math.floor`. The C library's `math.sin`,
`math.exp`, `math.log` and Lua's `^` operator are **not** (they may differ in
the last bit between platforms). Generators use `gen.dmath` instead:
`dmath.sin/cos/exp/log/pow/atan`, plus `round`, `clamp`, `normal` and
`weighted` (pick from `{ id, w }` tables).

## The cosmos, top down

| Level | Generated (`gen/levels/*.lua`) |
|---|---|
| multiverse | Tendencies of its universes (weights for magic sources and FTL modes). Universes are endless; index 0 is Prime. |
| universe | Laws: magic source (none, life, stellar, tectonic, belief) and strength, psionics, faster-than-light travel (none, gates, jumps with a range), real or silent gods; age; cosmic eras (names and spans); a 3D galaxy density field and notable galaxies (cradle, crown, wound, ...). Galaxy summaries are computed on demand. |
| galaxy | Shape (spiral, barred, elliptical, ring, irregular) with arms, bar, bulge; fields of density, age and metallicity (arms young and metal-rich, the old core metal-poor); its formation in one of the universe's eras; a habitable band; star clusters placed by density. |
| star cluster | Kind (open, globular, nursery) from position and age; stars from a mass function cut off by age, with classes, luminosities and companions; travel lanes as a relative neighbourhood graph, only with faster-than-light travel (jump lanes within the jump range). |
| star system | The star, its habitable zone and frost line; planets on spaced orbits with Kepler periods (rocky and dwarf inside the frost line, giants outside, more planets and rocky worlds around metal-rich stars), their moons, belts. |
| planet | Physics from star and orbit (radius, gravity, composition, air, seas, temperatures, day, tilt, year, tidal locking, starlight); on solid worlds a geodesic grid of 10,242 cells (`mvl.planet_*` kernels in `planet.c`) with tectonic plates, elevation (mountains where plates collide, trenches and island arcs at subduction, ridges and rifts where they part), geological settings, rocks, deposits (metal, fuel, gem, magical minerals) and a magic map following the universe's source. |
| planet (surface) | Climate per cell: temperature (annual mean, coldest and warmest season) from latitude, tilt (or the substellar point of a tidally locked world), height and the sea's moderation; prevailing winds (trade winds, westerlies, polar easterlies) carrying moisture from the sea, raining it out on windward slopes and leaving rain shadows behind mountains. Hydrology: depressions filled into lakes, every cell draining downhill to the sea, flow accumulated from rainfall, rivers where the flow is in the top 7%, the 12 largest named. A biome per cell (below). Continents (connected land), countries grown from capitals across each continent (mountains and rivers are slower to cross). |
| continent | Its name, size and its countries (name, capital). |
| country | The explored district: a window of the planet's surface about 37 km across, centred on the country's shore, else a river, else its capital. Its terrain follows the planet's elevation (sampled every 1024 m, heights near the sea steepened five-fold so shores are walkable) with local detail on top, the biome's palette, a river along the planet's river with its water level falling downstream, and the direction of the open sea. Lands lie on a 16 × 16 grid of 2048 m squares. Without a planet (Prime) a provisional terrain and road network. |
| land | A description, not geometry: its place on the planet (cell, latitude, longitude, climate, biome, continent, country, coast), style, terrain, features (buildings, props) with positions, fields, roads, rivers clipped from the country (beds carved under their water), flat areas under them, flora, spots (spawn, van, gate) and people. |

### Biomes

`gen/levels/geography.lua` classifies each cell from its temperature,
precipitation, height, lakes, coasts, geology, air and magic:

| Group | Biomes |
|---|---|
| Water | ocean, sea ice, reef (warm shallows), lake |
| Cold | ice sheet, tundra, taiga, cold desert, alpine (high and cold) |
| Temperate | temperate forest, grassland |
| Warm | hot desert, savanna, seasonal forest, rainforest, wetland (wet lowlands on large rivers), coast |
| Alien | barren (airless, or scorched above 60 °C where it is dry or the air thin), ash fields (volcanic arcs), crystal forest and arcane meadow (forests and grasslands where magic is strong) |

Thin air turns cold places with less than 900 mm of rain into alpine scrub; dry
worlds get no rain at all, frozen seas become sea ice. Each biome gives
lands their ground texture, terrain palette, trees and the family of words
and buildings their settlements use. Under red dwarf stars foliage darkens
(`dark_foliage`).

Checks registered by these levels: consistent laws, arm clusters richer in
heavy elements than the core, lanes only with faster-than-light travel,
distinct spaced orbits, Kepler periods, rocky worlds inside the frost line,
planet physics and geology on every cell, and water that never flows uphill.

## Prime

Universe `u0` is ours and is never generated: `gen/prime.lua` holds the Milky
Way, the Sun, the eight planets with their real orbits and periods, their
major moons and the belts. Prime has no magic, psionics or faster-than-light
travel and no generated lore: `gen.lore(G, address)` returns nothing for any
place in Prime, and nothing exists below its planets except the way to the
farm (`gen.prime.FARM`), where the story begins.

## Life

`gen/life/*.lua` gives every solid world its tree of life (Prime has none:
its farm keeps its hand-made plants).

- **Biochemistry** (`biochemistry` pass, before biomes): carbon life in
  liquid water (90 % of such worlds), carbon life in ammonia on cold worlds
  with air, slow silicon life in molten sulphur on very hot ones, or arcane
  life wherever the universe's magic is life itself and strong. The star's
  age decides how far it came: microbes, plants, or plants and animals.
  Forests, grasslands and other vegetated biomes are bare on worlds without
  plants.
- **Lineages**: 2 or 3 plant lineages (leaf type and the forms it allows:
  trees, shrubs, herbs, fungi) and 2 to 5 animal body plans (symmetry,
  segments, limbs, covering, ways of moving, senses, eyes, size, birth).
- **Species** (`species` pass): each land biome gets producers (more and
  more trees in richer and forested biomes), grazers, predators, scavengers,
  pollinators and decomposers in roughly 10 : 3 : 1 proportions. A species
  keeps its lineage's limbs and covering and adapts: land animals are
  shorter (height ∝ g^-0.3) and stockier (∝ √g) under strong gravity, winged
  lineages fly only where air pressure / gravity ≥ 0.25 (glide or walk in
  thinner air), coats thicken in the cold, plants take their star's foliage
  palette, rich biomes grow larger species, and strong magic fields or
  psionic universes give gifts. Every predator has prey in its biome, every
  grazer plants to eat. Each species has a common name, a scientific name
  (genus from its lineage, epithet from its biome or habits) and a bestiary
  line.
- **Intelligent species** (`sapients` pass): 0 to 2 on worlds with animals,
  descended from a lineage (wings if it flew, its limbs and covering) with
  physiology for later culture passes: anatomy (height, build, hands),
  senses, lifespan, reproduction, diet, social instinct, temperament and
  psionic potential. Each is a `species` fact.
- **Spacefarers**: in universes with faster-than-light travel a cluster may
  hold a spacefaring species, a fact shared by the systems it reached. The
  cluster commits its homeworld and up to 3 colonies along the lanes; each
  system makes sure it has a rocky world (a dwarf grows into one, or one
  forms in the habitable zone) and passes the promise on to it. The
  homeworld's tree of life gains the species' ancestral lineage and its
  life includes the species with the same anatomy; colony worlds list the
  colonists (with their homeworld anatomy and origin) alongside their
  native life.

Checks: every predator has prey in its biome, every species descends from
a lineage with the same body plan, intelligent species match their
ancestors, and every promise of a homeworld or colony is kept.

**In the lands** (`gen/life/habitats.lua`): a land's habitats are its
cell's biome and the commonest other land biome around the cell (weights
0.65 and 0.35), each with a copy of its species and how to draw them. A slow
noise field lays patches of the habitats across the land; each chunk shows
plants (up to 16, more in rich biomes) and animals (at most 3; grazers in
small herds, flyers above the ground) of its patch. They are
voxel models built from the species' traits (plant branch grammars,
creature body plans; see docs/MODDING.md), shared by all instances of a
species through a reference-counted cache with a build budget per tick;
sprites (trees, bushes, flowers, fungi, crystal shards and four creature
body plans) repainted in each species' colours remain the fallback.
Animals move with behaviours suited to their role and react to the player
(`lib/creatures.lua`); grazers flee as a herd.

## Cultures: languages and religions

`gen/culture.lua` (planet pass `cultures`, after `sapients`) gives every
intelligent species of a world (native, committed or colonists) a
proto-language and a religion; its peoples live on up to three continents
(the largest free ones; colonists in one country), each a culture speaking a
daughter language. Countries belong to the culture of their continent and
are named in its language; lands of a culture name their settlement and
people in it, and signals prefer the lands of peoples (the worlds of a
cluster's spacefarers are found without generating others).

**Languages** (`gen/culture/language.lua`): a sound inventory of 9 to 16
consonants sampled from a feature table, filtered by the speakers' mouth
(sapients have `anatomy.mouth`: lips; beaks for feathered, shelled and
plated peoples, mandibles for chitinous ones, who have no lip sounds and
click instead), 3 to 5 vowels plus long tonal vowels for peoples who live by
hearing, syllable templates (CV, CVC, V, VC, CCV, CVV) and allowed clusters.
A lexicon gives each of about 300 meanings (sky, land, nature, beasts, kin,
colours, numbers, motion, the sacred, places, qualities, virtues) a unique
readable root (short for basic words). `language.name(lang, rng, kind)`
composes place, person, god and country names from two roots by meaning
templates and keeps the gloss ("Where the Blood flows", "Fire Mother");
names are checked for readability (letters only, no three consonants or
vowels in a row, enough vowels) and against a short blocklist of English
look-alikes. `language.split(lang, seed)` applies 2 to 5 regular sound
changes (lenition, vowel shift, raising, cluster loss, final loss,
palatalisation, h-loss) to every root; `language.kinship(a, b)` measures
how many meanings two languages express alike.

**Religions** (`gen/culture/religion.lua`): 28 motifs with a source and a
salience test: the sky (twin moon gods, moon pantheons, a moon mother,
eclipse omens when moons cover the sun, ember, burning or fatherly suns, the
holy twilight of locked worlds, the river of stars, a veiled heaven), the
land (a fire mother where volcanic arcs rise, a flood father of great
rivers, a sea mother, sacred water in deserts, a dying god of hard seasons,
the sky mountain), biology (rebirth for short lives, ancestors for long
ones, the world egg, the divider for budding peoples, a queen mother for
hives, the great hunt, soul wings) and magic and psionics. A religion takes
2 to 4 of the strongest (with some chance), each linked to an `omen` fact of
its source, and gets deities named in the founders' language (or
principles), virtues, taboos, an afterlife, clergy and sacred site kinds.
In universes whose gods are real, the deities of a faith followed in three
or more countries are real (`deity` facts that history can call on).

## Cultures: traditions, society and technology

Each culture (`C.traditions_of` in `gen/culture.lua`) looks at its region
(`traditions.region`: the biomes, forests, bare and dry land, coasts,
mountains, soil, magic, ores and fuels of its continent, and the species
living there; a metal or fuel cell's ore follows from a hash of the cell).

- **Calendar** (`gen/culture/calendar.lua`): days are the world's days, or
  sleeps of a standard day where days are long against the year or the
  world is locked; months follow the most prominent moon (lunar, or
  lunisolar with strong seasons; solar without moons), named in the
  culture's language. Holidays fall on astronomical dates computed from the
  sky's orbits: solstices and equinoxes, every moon's full moons (dates are
  exact: the sky shows a full moon that night), nights when two moons are
  full together, an eclipse season. `traditions.commemorate(culture,
  {name, t, fact})` adds a holiday for a historic event on its date.
- **Customs** (`gen/culture/traditions.lua`): birth, coming-of-age and
  pairing rites from the species' biology; funerals chosen among those the
  land allows (no burial in the earth where mountains leave little soil;
  sea burial needs coasts, pyres need wood, sky burial high places or
  wings), steered by the faith's afterlife and linked to omen facts of the
  land; food from local plants and herds; water sharing in deserts; taboos
  on real local species (sacred to a god, or dangerous) and the faith's own
  taboos, each with its reason.
- **Values and society** (`gen/culture/society.lua`): five axes from -1 to
  1 (hierarchy, honour, tradition, the collective, hospitality) from social
  instinct, diet, lifespan, dryness and dangers; from them a social
  structure (hive court, theocracy, monarchy, chiefdoms, noble houses,
  councils, assemblies), laws, the treatment of strangers and factions
  (rulers, the faithful, traders, commons) for history.
- **Technology** (`gen/culture/technology.lua`): a graph from fire to
  spaceflight; each step needs its predecessors and what the land or trade
  offers (copper and tin for bronze, iron for iron working, fuel for steel
  and steam, crops, beasts to herd and draw carts, coasts, air to fly), and
  each era of development opens about 1.4 tiers. Where magic is common,
  magical traditions grow beside the machines (magelight beside
  electricity); where it is strong they replace them (magelight, scrying,
  skyships); strong psionics replace radio with farspeech. Spacefarers
  have reached spaceflight.

## Cultures: architecture, dress and people

Every culture has a style vector (`gen/culture/architecture.lua`; fields in
docs/MODDING.md): stone where masons live among mountains or few trees,
timber in forests, mud brick in dry lands, hides for herders without
masonry; towers for flyers (with roof hatches: entrances from above),
burrows for hives with mandibles, courtyards in dry hierarchical lands,
longhouses for forest clans, round huts for herders; steep roofs where rain
and snow fall, flat roofs in deserts, cones on round huts and towers, turf
on burrows, domes under sky faiths in heat; thick walls in cold and heat;
doors sized to the people; ornaments from the faith's first motif; dress
from climate and body (robes, furs, wraps, tunics, harnesses for wings and
chitin), dyed from local plants, with headdresses or sashes by values.

Lands of a culture keep `architecture` (its style with the land's own
bedrock as stone) and turn their settlement into generated buildings
(`gen/visuals/buildings.lua`: houses, a workshop, a well and a temple
facing the square, or the east for sky faiths).

**Human scale.** Buildings are planned in metres from the height of their
people (`style.height`): storeys of at least 3 m (1.75 x the height), doors
of at least 2 m (1.25 x the height) and wide enough for the player, and
footprints from `buildings.KINDS` scaled by the people's height — a
village house of humans is about 10 x 8 m with two storeys, a giant
people's (2.5 m) has 4.4 m storeys and 3.1 m doors. Grids reach 256 voxels
a side (32 m); longer halls are joined modules of up to 24 m
(`buildings.parts`). The voxel mesher merges coplanar faces of one colour
into rectangles of up to 16 voxels, so a house is a few thousand triangles
and builds in a few milliseconds. `land.layout_buildings` places the
buildings by their footprints (rotated boxes): rings around the square,
the temple across from the van, the others along both sides of the way in,
1.5 m apart, off the lane, the van and the rivers, each on its own
flattened ground; a building that finds no place is left out
(`buildings_left_out`). Quests, aftermath scenes and villagers keep clear of
the footprints. Villagers have voxel bodies
of their species in their dress (`gen/visuals/people.lua`). Buildings,
people and statues go through the model cache; the hand-made voxel art
remains the fallback.

**Monuments**: each faith's founder (an `individual` fact: a prophet named
in the culture's language, with the species' body and attributes) is
promised a statue in a land of the culture's first country
(`planet.kK.nN.l119`); the land honours the commitment with a statue on a
plinth near its square, in its own stone.

## History

`gen/history/engine.lua` simulates history on every level with one engine:
regions (the level's children, with neighbours), factions (traits:
ambition, aggression, diplomacy, commerce, piety, curiosity; territories,
relations, prosperity, stability, a ruler), a time step and an event table
(`gen/history/events.lua`): expansion, alliance, war, trade, schism,
discovery, plague, migration, revolution (the far half of a realm breaks
away as a new faction), golden age and collapse. Each step every living
faction may act; an action is chosen by weights from its traits, lands and
relations and resolves into an event with its year, participants, places,
leading individual, importance and causes (no event happens before its
causes). Individuals (founders, rulers, heroes, prophets, inventors, mages)
are born and die by their species' lifespans; past the cap of 60 stored
individuals, rulers are remembered by name only. The timeline is cut into
3 to 5 eras where it changed most; each era keeps a snapshot of the
territories and rulers at its end, so fallen kingdoms can be shown later.
Years count up to the present (year 0).

| Level | Step | Regions | Factions |
|---|---|---|---|
| universe | 10^8 years | notable galaxies | elder powers, or the gods themselves where gods are real |
| galaxy | 10^3 years | star clusters (three nearest) | elder empires that fall in the deep past; star nations with faster-than-light travel |
| cluster | 10^2 years | star systems (lanes) | the spacefaring people, settling its promised colonies, and breakaway colony leagues |
| planet | 25 years | countries (across their borders) | a nation per culture, founded in its home country |

**Planet histories** (`gen/history/planet.lua`) drive the cultures:
settling spreads a culture into free countries; a revolution makes the
breakaway half a daughter culture speaking a daughter language; a schism
founds a new faith with its prophet; notable events (importance 0.5 and
more) become commemorations in the calendars of the cultures that lived
them; technology is recomputed per era from the eras a culture lived
through, its discoveries and its trade partners' resources (era snapshots
keep each culture's level). At the present, countries belong to the
nations holding them (their culture, nation and name follow; unheld
countries are wild), and up to three individuals still alive are promised
(`resident` commitments) to a land of their nation's capital country,
where they live by the square and tell of their deeds.

Events, individuals, eras and new faiths are facts with causes; checks keep
events in order, people within their lifespans and their deeds within
their lives, and Prime free of history: no history pass runs in Prime and
no event refers to it. Universe lore remembers the quiet worlds the powers
overlooked.

### History refined, remembered and brought to the present

**Refinement** (`gen/history/refine.lua`): a galaxy's great wars and falls
(importance 0.6 and more, at most 20) are promised (`event_ref`
commitments) to the clusters they touched; each cluster passes the promise
to one of its star systems, each system to its rocky world, and the world
records the event's echo (a fact with the powers of that world alive at the
time as local participants, or the forebears of its peoples when the event
is older than their history). Following the causes of an echo leads back
through the system and the cluster to the galaxy's event. Each echo leaves
a trace in a land (`trace` commitments to land 116 of a country): a wreck
or a battlefield of a war, a crater where a power fell. A planet's own
history leaves traces too, the most important first and at most six: the
ruins of fallen capitals (land 117, built in the architecture style of the
culture that raised them: a weathered house without its roof, moss in its
cracks), battlefields of its wars (land 117) and shrines to the Wanderer
(land 115). Lands place up to three traces, 45 m from their square, and
keep their names (`traces`); the chunk streamer builds ruins as ruined
buildings (`ruin:<style>:<n>` model keys) and the rest as voxel models of
their kind (`gen/visuals/traces.lua`).

**Cultural memory** (`gen/history/memory.lua`): every culture keeps its own
version of the events its nation lived through, beside the true record:
its victories become glorious and the enemy treacherous whoever struck
first (`glorify`), its defeats the enemy's treachery (`villainise`),
plagues are blamed on its enemies or on heretics (`scapegoat`), founders
become holy (`apotheosis`), fallen rivals are remembered as wicked, the
Wanderer becomes a `legend`, and events older than the last two eras (three
for traditional cultures) are forgotten, except foundings and legends. Each
remembered event keeps the rule that shaped it and its true event fact.

**Tensions** (`gen/history/tensions.lua`): history ends with the troubles of
the present. Each country of a planet with history gets tensions from its
final state, each with a severity, causes (in words, and the facts of the
events behind them) and stakeholders:

| Tension | When | Quest kind |
|---|---|---|
| drought | under 450 mm of rain a year; worse where another nation holds the river upstream | gather |
| contested border | inside the spheres (lands and their neighbours) of two living nations | return |
| feud | a war of its nation in the last 100 years | return |
| succession crisis | the ruler is past three quarters of their lifespan | relight |
| schism | a schism of its nation in the last 150 years | relight |
| epidemic | a plague in the last 50 years | gather |
| incursion | a large predator lives in its biome | lost |
| failing magic | where the world has magic, in a seeded quarter of countries | relight |
| lost relic | ruins lie in the country | return |

A land feels each of its country's tensions more or less (severity scaled
by its seed) and adds a local trouble of its own (a lost traveller, dark
nights, a broken machine, scattered heirlooms); lands of worlds without
history have only that. The land's quest is a template of the kind its
strongest tension calls for (mods' templates included) with that severity,
and the signals the van hears describe that tension and score it (history's
tensions above local ones).

**The Wanderer** (`gen/history/wanderer.lua`): long before the player,
Juniper's van wandered the multiverse. In a seeded third of the universes,
a planet's history may (35%) hold a sighting of a cream-and-teal wagon that
came out of the sky; the culture of the nation that saw it keeps it as a
legend, sometimes with a shrine. In its lands the quest giver recognises the
van on the first meeting and a villager speaks of the legend.

### Quests and dialogue

**Quests from tensions** (`gen/quests.lua`): a land's quest comes from its
strongest tension. The tension kind calls for quest kinds (a drought with a
dam upstream becomes a dispute between the villages upstream and
downstream; a failing spring or fading magic a source to restore; a sick
child someone to escort; a succession crisis word to carry to an heir) and
the land's seed picks the kind and a template of it. The quest is filled
with the land's real people: the giver, the two villagers who speak for the
parties of a dispute, the recipient of a message or the one to escort (new
villagers named in the people's language and dressed like them). The giver
adds a line of lore about the trouble naming the place and, where the land
knows them, its gods, saint, holidays and the events or rivals behind it
("Since the Schism of Klafo, half of Ushet prays one way to Teeki and half
another"). Eight kinds: `relight`, `gather`, `return`, `lost`, `message`,
`mediate`, `escort` and `restore`.

**Outcomes**: a dispute is settled for one side or by a compromise once the
player has heard both; any quest can be given up. The land's change log
keeps the outcome (`outcome`: result, favoured and wronged party), its
people remember (`memory/characters.lua`: per character whether they met,
how often they talked, favour from -3 to +3, the deed they are grateful for
or the wrong they hold; for the whole community the deed and the title they
call the player by: "the Lamplighter", "the Peacemaker", ...), and the
parties of a dispute keep a reputation of the player across the multiverse
(record `reputation`).

**Dialogue** (`gen/dialogue/`): generation keeps each land's **lore**
(`d.lore`): the place, country and nation, the culture's greeting in its
language with its meaning, the word for a stranger, the faith's gods (and
which is the moon), saint and virtue, up to three holidays, beasts and
plants of the land, the people's versions of history and the news (the
land's tensions). A small grammar (`grammar.lua`) assembles conversations
from it: a greeting by what the speaker remembers (a stranger is welcomed,
an acquaintance greeted again, a friend thanked by name for their deed, a
wronged villager says little but why), a topic (news, an idiom with the
local beasts and plants, history as they tell it, faith, holidays) and a
farewell, often a blessing by their gods: a moon-worshipping people's
farewell can invoke its moon deity by name. Alternatives that need slots a
land does not know are skipped; choices are seeded per character and per
conversation. Mods add alternatives with the content table
`dialogue_rules`.

The bible's planet sections end with **Today**: the echoes of greater
histories, each country's strongest tension with its causes and
stakeholders, and what each culture remembers differently; land
descriptions give the trouble with its causes, the traces and the legend.

## Skies and palettes

**Skies** (`gen/visuals/sky.lua`): the planet pass `sky` stores what a solid
world's sky holds: its star's colour and apparent size (enlarged four-fold
for the eye), its air by day and night, the moons (radius, distance, a
Kepler period from the planet's mass, colour, enlarged ten-fold), its sister
planets and the band of its galaxy (the plane's orientation against the
planet's equator, brighter for spirals and towards the core). Lands keep a
copy (`heavens`) so a stored land needs no planet to show its sky.

`gen.sky.at(heavens, place, t)` places everything for a land's latitude and
longitude at a moment (days): the planet turns on its tilted axis, the star
moves along the ecliptic once a year (a tidally locked world keeps it still,
overhead at longitude 0, with eternal night on the far side), moons follow
their orbits, and each moon's phase is where it stands against the star.
`gen.sky.view` turns that into the environment (sky gradient blended from
night through dusk to day, ambient and sun light, moonlight at night,
stars fading by day) and the bodies for `mvl.sky`; the sky shader draws the
star's disc and halo, moons lit from the star's side, planets as points and
the band as clouds with dust lanes. A land is visited at a moment of its
planet's clock that moves on every night (`visit_time`), so the same land
may be seen by day and, later, by night.

**Air**: the gas mix sets the colour (nitrogen blue, carbon dioxide
butterscotch, methane teal, sulphur yellow) in the star's light; thin air
darkens the sky towards black (airless worlds show stars by day), thick air
washes it out with haze and brings the fog closer (from 52-95 m on thin
worlds to 5-45 m under a crushing sky).

**Earth**: the farm's sky uses J2000 mean longitudes for the Sun, the Moon
and the planets, Earth's rotation and tilt and the Milky Way's real
orientation (galactic pole and centre). The story's first night is
24 June 2026 at 23:00 at 45° N, under a waxing gibbous Moon; every night
advances the calendar a day, so the Moon waxes and wanes as it really does.

**Palettes** (`gen/visuals/palette.lua`): a land's `materials` follow from
its cell of the planet. Plants take the colour that absorbs their star's
light best (green under G stars, olive under K, near-black and deep purple
under red M dwarfs, yellow-green under F, red and orange under A, B and O
stars), faded in dry and cold biomes; stone takes the colour of the bedrock
(`P.ROCKS`), sand is ground bedrock, soil is bedrock weathered by the
climate, and water is tinted by the air and the light. They repaint the
hand-made textures with `mvl.texture_recolor` (grass and plant sprites only
where green, stone, sand and dirt entirely), the terrain's vertex palette
(its greens recoloured, stone and sand biomes in the rock's shades, cliffs
in the bedrock's colour) and three voxel boulder shapes per land, scattered
through its chunks. Crystal biomes keep their own colours.

## The planet atlas

After history, a planet pass (`gen/plan/atlas.lua`) works out where people
live, per cell:

- `fertility` (0..1): warmth, rain, soil (by biome), slope, fresh water
  (rivers count most in dry lands) and magic.
- `population` (people per km²): fertility times how the people feed
  themselves (farming, herding, foraging) and their technology (industry
  from steam power on), times history (capitals and the cells round them
  attract people; wars, plagues and collapses thin them out; golden ages,
  expansions and migrations grow them) and present tensions (drought,
  famine, epidemics); a people always lives on, thinly, where the land
  feeds little.
- `urban`: the share of people in towns and cities (technology, rivers,
  coasts, hierarchy, capitals; herders almost none).
- `land_use`: farmland, orchards, pasture, managed forest, mines, sacred,
  wild or barren ("water" on the sea and lakes).

`P.atlas` holds the settlement seeds of the cells (cities where many town
people live, towns by the number of people and always one in a fertile
river valley, camps of herders; each with its position inside the cell,
people, founding year, capital, port, river and spaceport flags and a name
in its people's language) and the trade routes between them: one search
over land from every settlement finds where their areas meet; a spanning
network of those links plus the short extra ones become roads, and the
same over open water between the ports of seafaring peoples become sea
lanes. Uninhabited worlds have land use but no people, settlements or
routes. The bible tells the atlas in a paragraph; the variety statistics
count land uses, settlement ranks, settled planets and planets with roads
and sea lanes.

**Asking about a place**: `gen.plan.at(G, planet, lat, lon)` answers from
the planet alone (nothing below it is generated): the cell, water, biome,
elevation, country and culture, fertility and people (interpolated), land
use, the nearest settlements (km and compass direction) and the nearest
route; `gen.plan.tell(answer)` makes a sentence of it ("the town of X is
120 km to the north-east").

## Lands and chunks

`gen/chunks.lua` turns land descriptions into the walkable world. A world
calls `w:land(node, provider)`; world coordinates are then metres around
that land's centre, and neighbouring lands of the same country lie at
multiples of 2048 m (`provider(gx, gz)` generates them on approach).

- **Chunks** are 32 m squares of 16 × 16 terrain cells. Those within 3
  chunks of the player are built, nearest first, one per tick; those beyond
  5 chunks are destroyed and their meshes released. On arrival every chunk
  within reach is built at once (about 16 ms for 49 chunks).
- **Content** of a chunk is the land's features, fields and road pieces
  whose centre lies in it, plus flora seeded by `hash(land seed, chunk)`, so
  a discarded chunk comes back identical.
- **Terrain** is one height field per country (`mvl.terrain` with
  `origin_x/origin_z` set to the anchor land's centre) plus the flat areas
  of every active land: discs under buildings, fields and the van, and
  graded segments under roads (`{x, z, x2, z2, height, height2}`). Chunk
  borders share their vertices exactly, so there are no cracks
  (`tests/gl/test_gl_chunk_seams.lua`).
- **Roads** are draped ribbons (`mvl.ribbon_mesh`) drawn as decals on their
  graded flats.
- **Water**: wherever a chunk's ground dips below sea level (0 m) a sea
  surface is drawn over it; the player wades in up to 1 m deep and no
  further. Rivers are ribbons of water at their own falling level, drawn in
  every chunk they cross, over beds carved into the terrain (graded
  segments 2 m below the water); no flora grows in water or on river beds.
- The player and every object stand on `mvl.height(x, z)`; while the player
  is inside the van, the land streams around the parked van so its windows
  look out at a complete world.

### The farm

Prime's farm (`gen.prime.FARM`, land 0 of the countryside) is generated from
the save's seed: the farmhouse's position and angle, the barn, the well, the
fields and their crops, the trees and the neighbour (name and look) vary
between journeys, while the gate, the van's parking spot and the porch stay
in the same place relative to the farmhouse. The other lands of the farm's
country are open countryside along the old road.

## Signals, provisional worlds and quests

Until the deep generators exist (planned for phases 13 to 22), parts of
places outside Prime are filled by provisional rules
(`gen/levels/provisional.lua`):

- A **land's style** (temperate, marsh, desert, snow, crystal, fungal)
  follows from its biome's family (before phase 12: from the planet's
  temperature, star and magic) and sets the sky, sounds, buildings, people
  and the words its quests use.
- Every **land** gets a named settlement around a square near the landing
  spot, villagers with generated names, a lane to the van, and one trouble.
- A land's **trouble** is a quest template picked from the land's seed alone
  (`gen/quests.lua`), so it is known before the land is generated. The quest
  is stored as data in the land; its items and targets are land features
  that stream with their chunks (taken items never come back, lit lamps stay
  lit). Base templates: relight, gather, return, lost person.
- **Signals** (`gen/signals.lua`): each night candidates are drawn from the
  save's seed and the night number in universes 1 to 24 (never Prime): a
  galaxy, a cluster in its habitable band, a star and one of its rocky
  worlds are generated down to the planet's surface, and a land on dry
  ground of one of its countries is chosen (planets without dry land send
  no signal); the land itself is only named. Tonight's planets are
  generated ahead, in the background, when a day starts.
  Three are chosen by severity plus novelty (an unvisited galaxy, a trouble
  not offered last time), never two from the same galaxy. Choosing one
  requests the land; the van stays on the road between worlds until it is generated
  (at least 3.5 s).

## World memory

Generated places are not regenerated once visited: the first visit stores a
land's description and its ancestors' summaries (`records/places/<address>`),
later visits and restarts load them, and a change log per land
(`records/changes/<address>`) records everything the player changed. See
[MODDING.md](MODDING.md#world-memory).

**Time passes** (`memory/aftermath.lua`): each visited land keeps a clock
(its visits and the days that passed there: a night of the player's is
about a week). How the land's quest ended sets its aftermath in motion:
rules that come true some nights later and are applied, once, when the
player comes back.

| Rule | After | When | What happens |
|---|---|---|---|
| regrowth | 2 nights | helped | new fields where water or machines came back; life is better |
| newcomers | 4 nights | helped | two families move in (named in the people's language) |
| festival | 3 nights | helped, severity 0.45+, a people | the Feast of the (title) in the player's honour, lanterns round the square; an invitation |
| monument | 6 nights | helped, severity 0.5+ | a statue of the player and the van in stone by the square |
| shrine | 5 nights | helped, the Wanderer legend is told there | a shrine to the Wanderer |
| renamed | 8 nights | helped, severity 0.7+ | the place is called "(name) of the (title)" |
| decline | 3 nights | given up | a house falls into ruin, a family moves away, the trouble got worse |
| trouble | 5 nights | helped (first quest) | a new trouble caused by the help (the new families crowd the spring, the lamps burn more oil than there is) becomes the land's next quest; a need |

Results are written to the change log: marks (placed objects built in the
local style), new fields and villagers, villagers who left, the name, the
festival, the news (each villager tells what changed the first time they
see the player again) and events of the land's history. A new trouble
becomes a second **chapter**: a quest generated from it with ids of its own,
its people named from names the land keeps for newcomers.

**Stories spread** (`memory/spread.lua`): every deed is remembered with a
fame (from the trouble's severity; settled disputes are told more; giving
up is a small story). The same country hears of it at once, the rest of the
planet after two nights (fame 0.5+), the rest of the galaxy after four
(fame 0.8+). Its own people glorify the player, the wronged party's nation
villainises them and other peoples make a legend of it ("a giant who came
out of the sky in a cream-and-teal wagon..."). People who have not met the
player greet them by the story's title; deeds also raise or lower the
nation's opinion of the player.

**Follow-ups**: invitations (festivals) and needs (new troubles) wait in a
queue until their night; one signal a night is kept for the earliest due
follow-up, so helped places call the player back.

## The codex

Each land of a people keeps the codex entries it can teach (`d.codex`,
`gen/codex.lua`): the place (with what its name means), the people's
species, nation, language (words with their meanings), faith (and why it is
so: the sky, sea or mountains that inspired it), saint (as the faithful
tell it, and what Juniper knows), the events they remember (their version
and the true record), their traditions (rites, funerals, food, taboos,
holidays, and why: their faith, the land and the events they commemorate)
and the creatures around. Ids are the generator's fact ids, so the same
saint or war is one entry wherever it is learned. Juniper knows the true
story in the universes she wandered through (the Wanderer's universes), so
there the codex shows legends beside what really happened. See
[MODDING.md](MODDING.md#the-codex).

## Variety, budgets and save size

Three guards run in CI on every platform (`gen/stats.lua`, `tests/CMakeLists.txt`):

- **Variety** (`mvl_headless --stats 200 --thresholds tests/stats_thresholds.ini`,
  ctest `tools.stats`): a peopled world from each of 200 seeds (at planet
  grid level 3), counting their biome distributions (the land biomes with
  15% of the land or more), the body plans of their species, the sources
  their religions grew from, their peoples' technology levels and the kinds
  of tension in their countries. Thresholds (`metric = <= value` or `>=`)
  fail the run when, for example, more than half of the planets share one
  biome distribution. `--bias biome` makes every planet a desert, and ctest
  `tools.stats_monotony` checks that the guard catches it.
- **Budgets** (`mvl_headless --budget 12 --budgets tests/budgets.ini`, ctest
  `tools.budget`): places down to a land from 12 seeds at the game's planet
  resolution, with the time of every pass recorded (`G.timing`); the median
  time of each level must stay within its budget, and a level over it fails
  naming its slowest pass. `--delay LEVEL:MS` adds an artificially slow pass
  (ctest `tools.budget_slow`). The web smoke test also measures the frame
  rate while the van travels (`?benchmark=travel` runs a scripted trip on a
  fresh profile), so a generator that stops yielding shows up.
- **Save size** (ctest `stress.save`, `tests/game/stress_save.lua`): 200
  arrivals in generated lands with changes in each (things taken and put
  down, people talked to, troubles solved or given up, nights passing,
  revisits with their aftermath); the save folder must stay below 20 MB
  (about 4.5 MB today).

The same checks from a script:

<!-- example -->
```lua
local gen = require("gen")
local S = gen.stats
local level = gen.planet.LEVEL
gen.planet.LEVEL = 3
local st = S.collect(gen.cosmos, gen.run, 3)            -- three seeds
local m = S.metrics(st)
assert(m.planets >= 1 and m.biomes >= 1)
local fails = S.check(m, S.parse("planets = >= 1\nbiome_distribution_share = <= 1"))
assert(#fails == 0)
assert(#S.check({ biomes = 2 }, S.parse("biomes = >= 10")) == 1)
local times = S.time(gen.cosmos, gen.run, 1)             -- milliseconds per level
assert(times.planet and times.planet.median > 0)
assert(#S.over(times, S.parse("planet = <= 0")) == 1)    -- nothing is that fast
gen.planet.LEVEL = level
```

## Fingerprints

`tests/game/test_gen_fingerprint.lua` compares fingerprints (hashes of the
exact bytes of generated places) of reference addresses, of the test
hierarchy and of the cosmos from the multiverse to star systems, with stored
values on every CI platform, so a platform that generates a different
multiverse from the same seed fails CI. When a generator change is intended,
update the stored values in the same commit.

## Example

A complete pass on the small test hierarchy (`gen/testworld.lua`: world,
realm `r`, island `i`, glade `g`) that adds a lighthouse to every harbour
promised by a realm and explains it:

<!-- example -->
```lua
local gen = require("gen")
local R = require("gen.testworld").new()

R:pass("island", "lighthouse", {
  after = { "harbor" },
  run = function(ctx)
    for _, id in ipairs(ctx.node.fact_order) do
      local harbor = ctx.node.facts[id]
      if harbor.kind == "harbor" then
        ctx:fact("lighthouse", { name = "Light of " .. ctx.summary.name, height = ctx:rng():int(8, 30) }, harbor)
      end
    end
  end,
})

local G = gen.run.new(R, { seed = 42 })
local island = G:generate("r1.i0")
local light = island.facts["r1.i0/lighthouse/1"]
assert(light and light.data.height >= 8)
assert(#G:explain(light.id) >= 4)            -- lighthouse <- harbour <- promise <- founding ...
assert(#gen.check.run(G) == 0)
```
