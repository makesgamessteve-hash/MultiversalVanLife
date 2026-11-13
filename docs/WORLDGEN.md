# World generation

Multiversal Van Life generates its multiverse lazily from one seed per save.
This document describes the framework every generator plugs into
(`game/scripts/gen.lua` and `game/scripts/gen/`). Later phases add the real
content: universe laws, galaxies, stars, planets, peoples and their history.

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

| country | One continuous terrain (seed, height, palette) shared by its lands, and its road network. Lands lie on a 16 × 16 grid of 2048 m squares. |
| land | A description, not geometry: style, terrain, features (buildings, props) with positions, fields, roads clipped from the country with graded heights, flat areas under them, flora, spots (spawn, van, gate) and people. |

Checks registered by these levels: consistent laws, arm clusters richer in
heavy elements than the core, lanes only with faster-than-light travel,
distinct spaced orbits, Kepler periods and rocky worlds inside the frost line.

## Prime

Universe `u0` is ours and is never generated: `gen/prime.lua` holds the Milky
Way, the Sun, the eight planets with their real orbits and periods, their
major moons and the belts. Prime has no magic, psionics or faster-than-light
travel and no generated lore: `gen.lore(G, address)` returns nothing for any
place in Prime, and nothing exists below its planets except the way to the
farm (`gen.prime.FARM`), where the story begins.

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

Until the deep generators exist (planned for phases 11 to 22), places
outside Prime are filled by provisional rules (`gen/levels/provisional.lua`):

- A **planet's style** (temperate, marsh, desert, snow, crystal, fungal)
  follows from its temperature, its star and its universe's magic, and sets
  the terrain, sky, sounds, buildings, people and the words its quests use.
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
  worlds are generated down to the star system; the land is only named.
  Three are chosen by severity plus novelty (an unvisited galaxy, a trouble
  not offered last time), never two from the same galaxy. Choosing one
  requests the land; the van stays in the vortex until it is generated
  (at least 3.5 s).

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
