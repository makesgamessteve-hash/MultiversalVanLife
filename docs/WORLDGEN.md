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

## Fingerprints

`tests/game/test_gen_fingerprint.lua` compares fingerprints (hashes of the
exact bytes of generated places) of reference addresses with stored values on
every CI platform, so a platform that generates a different multiverse from
the same seed fails CI.

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
