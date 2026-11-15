# Modding Multiversal Van Life

The executable contains only the engine. Everything you see and hear comes
from the `game/` folder next to it, and you can change any of it.

## Editing the base game

Change files in `game/` (next to the executable, or in the repository and
rebuild) and restart the game.

| Folder | Contents |
|---|---|
| `config/engine.ini` | Render resolution, dithering, UI size, tick rate, main script, VR eye height |
| `config/input.ini` | Key, mouse and gamepad bindings per action |
| `scripts/` | Lua 5.4 gameplay. `main.lua` is the entry point |
| `scripts/worlds/` | `home.lua` (the farm) and `land.lua` (any generated land) |
| `scripts/gen/` | The multiverse generator (see [WORLDGEN.md](WORLDGEN.md)) |
| `scripts/lib/van.lua` | Juniper's interior, its window portals and the road between worlds |
| `scripts/gen/house/` | The house inside the van: its plan, rooms, furniture and palette |
| `shaders/` | GLSL shaders (written for GLSL 3.30 / GLSL ES 3.00, without `#version`) |
| `textures/` | TGA images (sprites use alpha cut-out) |
| `models/` | Wavefront OBJ models |
| `voxels/` | MagicaVoxel `.vox` models (one voxel = 1/8 m by default) |
| `sounds/` | Sound effects and ambience loops: 8 or 16-bit PCM WAV, mono or stereo |
| `music/` | Music: MP3, mono or stereo |
| `dialogue/lines.txt` | Every fixed dialogue line: `id \| speaker \| text` (shown as text) |

## Mods

Mods live in a `mods/` folder next to the executable (or the folder passed
with `--mods`). List the enabled mods, one folder name per line, in
`mods/mods.txt`:

```
my_world
better_textures
```

Each mod folder mirrors `game/`. A file in a mod replaces the base file with
the same path; mods listed later win. If a mod has an `init.lua` at its root,
the game runs it at start-up, after the base game and its generator are set up.

### Adding a kind of trouble

The places Juniper's signals lead to are generated (see
[WORLDGEN.md](WORLDGEN.md)). Mods extend the generator rather than adding
fixed places: they register generation passes, content tables and quest
templates. This is the complete sample mod, `mods/sample_mod/init.lua`, which
`tests/game/test_mods.lua` runs:

<!-- sample_mod -->
```lua
-- Example mod used by tests/game/test_mods.lua and docs/MODDING.md: a new
-- kind of trouble that generated lands can have.
local gen = require("gen")

gen.cosmos:content("quest_templates", {
  { id = "moonberries", w = 1, kind = "gather", short = "the moonberry harvest spilled",
    part = "moonberry", item = "flowers",
    intro = { "The {folk} of {place} pick moonberries only on nights like this one.",
              "But the baskets tipped over on the hill! Could you find all {n} {part}s?" },
    progress = "{left} {part}s are still out there.",
    done = "A full basket! The {folk} will feast tonight, thanks to you.",
    deed = "saved the moonberry harvest" },
})

-- and a saying villagers may use (see the dialogue grammar in MODDING.md)
gen.cosmos:content("dialogue_rules", {
  { idiom = { "Moonberries ripen for the patient, my mother always said." } },
})

-- and a generation pass: wild moonberry bushes by every settlement of the
-- generated multiverse (Prime stays as it is)
gen.cosmos:pass("land", "moonberry_bushes", { after = { "layout" }, run = function(ctx)
  local sq = ctx.data.spots and ctx.data.spots.square
  if not sq or gen.prime.inside(ctx.node.address) then return end
  local rng = ctx:random("moonberries")
  local a = rng:next() * 6.2832
  ctx.data.features[#ctx.data.features + 1] = {
    id = "moonberry_bush", role = "decor", sprite = "flowers", w = 1.2, h = 0.9,
    x = sq.x + math.floor(math.cos(a) * 1800) / 100, z = sq.z + math.floor(math.sin(a) * 1800) / 100 }
  ctx:fact("decor", { name = "wild moonberries" })
end })

-- and what grows where the harvest was saved, a night later (an aftermath
-- rule that leaves a mark, see "Time passing" in MODDING.md)
gen.cosmos:content("aftermath_rules", {
  { id = "moonberry_bushes", after = 1,
    when = function(x) return x.success and x.outcome.template == "moonberries" end,
    apply = function(x)
      local sx, sz = x:spot(6, 10)
      x:mark({ mark = "moonberry bushes", sprite = "flowers", x = sx, z = sz, w = 1.4, h = 1.0 })
      x:news("moonberry bushes grow by the square now")
    end },
})
```

Quest templates have a `kind`, a weight `w`, the words they use (`part`,
`keepsake`, `light`, `glow`, `spot`, `machine`, `source`, and `item`, the
sprite of collectable items) and text with placeholders: `{giver}`,
`{place}` (the settlement), `{folk}`, `{n}`, `{left}` and the words above.
`deed` is what the land remembers the player did ("saved the moonberry
harvest": "Welcome back, the Finder! You saved the moonberry harvest").

| Kind | The player... | Extra text keys | Extra placeholders |
|---|---|---|---|
| `relight` | gathers glowing things and lights the lamps | | `{light}` `{glow}` |
| `gather` | finds the parts and brings them back | | `{part}` `{machine}` |
| `return` | puts the keepsakes back in their places | | `{keepsake}` `{spot}` |
| `lost` | finds someone and leads them home | `lost_line` | `{lost}` |
| `message` | carries word to someone far away and brings back the answer | `reply`, `waiting` | `{recipient}` `{message}` `{answer}` |
| `mediate` | hears both sides of a dispute and settles it: for one side or a compromise | `claim_a`, `claim_b`, `heard`, `done_side`, `done_compromise`, `deed_side`, `wrong_side` | `{party_a}` `{party_b}` `{issue}` `{winner}` |
| `escort` | walks someone to a place | `escort_line`, `wait_line`, `arrive` | `{escort}` `{destination}` |
| `restore` | finds what fed a failing spring or stone and restores it | `ready` | `{source}` `{part}` |

Every quest comes from a land's strongest **tension** (its history's
troubles, see [WORLDGEN.md](WORLDGEN.md)): the tension kind calls for quest
kinds (`gen.history.tensions.QUEST`, a table mods may change, e.g.
`QUEST["dark nights"] = { "relight", "message" }`), and the land's trouble
is picked from its seed among all registered templates of that kind, so
newly generated lands can get the mod's trouble. The giver adds a line of
lore about the tension (the place, its gods, saint, holidays, the events
and rivals behind it). Every quest can be given up (talking to the giver
mid-quest offers it), and how it ended is remembered by the land (its change
log's `outcome`), its people (favour, the deed or the wrong they remember,
the name they call the player by) and the parties of a dispute
(`memory/characters.lua` reputation).

**Dialogue grammar.** Villagers talk with lines assembled by
`gen/dialogue/grammar.lua`: rules map a symbol to alternatives, and `#name#`
in an alternative expands another rule or fills a slot. Slots come from the
land's lore and the speaker's memory: `place`, `greeting` and
`greeting_meaning` (in the people's language), `stranger`, `deity`,
`moon_deity`, `saint`, `faith`, `virtue`, `holiday`, `beast`, `plant`,
`memory` (how the people tell their history), `news` (the land's tensions)
and `known_as`, `deed`, `wrong` (what the speaker remembers of the player).
An alternative is used only when every slot it needs is known. A
conversation is `hello` (or `hello_known`, `hello_friend`, `hello_resent`,
`hello_letdown`, by memory), a `topic` (`news_line`, `idiom`, `history`,
`faith_line`, `smalltalk`, `holiday_line`) and a `farewell` (often a
`blessing`). Mods add alternatives to any symbol with the content table
`dialogue_rules`, as the sample mod above does:

<!-- example -->
```lua
local gen = require("gen")
local G = gen.dialogue.grammar
local rules = G.rules(gen.cosmos)
rules.blessing = { "May #moon_deity# light your road." }   -- only this blessing here
local lore = { place = "Ushet", moon_deity = "Teeki", news = { "the wells are drying up" } }
local slots = G.slots(lore, { met = true, favour = 2, deed = "lit our lamps again", known_as = "the Lamplighter" })
local used = {}
local line = G.expand(rules, "blessing", slots, mvl.rng(1), 0, used)
assert(line == "May Teeki light your road." and used.moon_deity == "Teeki")
-- a people without a moon god never blesses by one: no alternative fits
assert(G.expand(rules, "blessing", G.slots({ place = "Ushet" }), mvl.rng(1)) == nil)
-- a friend is greeted by the name the village gave them
local talk = G.talk(gen.cosmos, lore, { met = true, favour = 2, deed = "lit our lamps again",
                                        known_as = "the Lamplighter" }, 7, 3)
assert(talk[1]:find("Lamplighter", 1, true) and talk[1]:find("lit our lamps again", 1, true))
```

Other things a mod can extend:

| Table | Contents |
|---|---|
| `gen.cosmos:content("quest_templates", {...})` | Troubles of generated lands |
| `gen.cosmos:content("dialogue_rules", {...})` | What villagers say (`{ symbol = { alternatives } }`) |
| `gen.history.tensions.QUEST` | The quest kinds each tension kind calls for |
| `gen.cosmos:content("magic_sources" / "ftl_modes", {...})` | Universe laws (`{ id, w }`) |
| `gen.provisional.STYLES` | Looks of generated worlds: terrain, sky, sounds, buildings, people, words |
| `gen.names.LEXICONS` | Syllables of generated names |
| `gen.cosmos:pass(level, name, {...})` | Any generation pass (a pass with an existing name replaces it) |

Add your own lines by shipping a `dialogue/lines.txt` (it replaces the base
file, so copy the base lines too), or call `dialogue.say` with existing ids.
Generated characters can speak without a line id: `dialogue.say({ speaker =
"Ostra", text = "Mind the eels.", color = { 0.6, 0.9, 1 } })`. Dialogue is
text only; a soft blip plays while a line types out.

### Soundscapes

Every place has one looping sound. A world names its loop with `ambient` (and
optionally `ambient_volume`); the title music and the van's hum are in
`audio.SCAPES` (`lib/audio.lua`), and travelling plays the `travel` sound over
the hum. Switching places crossfades: the old loop fades out over
`audio.FADE_OUT` seconds while the new one fades in over `audio.FADE_IN`.
Call `audio.scape("van")` for a named soundscape or
`audio.set_ambient("sounds/my_loop.wav", 0.5)` for any file. Loops should be
seamless (`tools/audiogen` crossfades their ends).

`tests/game/mods/sample_mod` is a complete working example.

## World helpers (`lib/world.lua`)

| Helper | Purpose |
|---|---|
| `w:prop{voxel=|model=|mesh=, texture, x, y, z, yaw, scale, box={w,d}\|radius, color, unlit, nofog, uv_scroll}` | Static 3D object. `box`/`radius` make it solid |
| `w:sprite{texture, x, y, z, w, h, radius, unlit, nofog, color}` | Camera-facing billboard, anchored at the bottom centre |
| `w:ground(texture, size, tiles)` | Tiled ground plane |
| `w:scatter{texture, count, min_r, max_r, cx, cz, w, h, radius, seed}` | Deterministic random sprites in a ring |
| `w:npc{texture, name, x, z, w, h, talk}` | Sprite with a "Talk to" interaction |
| `w:interactable{x, z, entity, prompt, range, use, enabled}` | Anything the player can use |
| `w:light(i, x, y, z, r, g, b, range)` | Point light (slots 0..7, the van beacon uses 7) |
| `w:env{...}` | Sky, fog, ambient and sun (see `mvl.environment`) |
| `w:bounds(x0, z0, x1, z1)` | Walkable area |
| `w:land(node, provider)` | Streams a generated land around the player (see [WORLDGEN.md](WORLDGEN.md#lands-and-chunks)) |
| `w:height(x, z)` | Ground height (terrain of a streamed land, else 0) |

`w.state` is a table for your world's own data and is reset on every load.
Progress that must survive should use `progress.set_flag` / `progress.helped`.

## Engine API (`mvl`)

| Group | Functions |
|---|---|
| Resources | `texture(path)`, `mesh(path [, voxel_size])`, `plane_mesh(sx, sz, tx, tz)`, `box_mesh(sx, sy, sz)`, `ribbon_mesh({x, y, z, ...}, width [, v_scale])`, `mesh_bounds(id)`, `sound(path)`, `sound_length(id)`, `release_mesh(id)`, `release_texture(id)` |
| Rendering | `portal(i [, {pos, yaw, w, h, target, target_yaw}])`, `render_stats()`; `spawn{decal = true, layer = n}`, `plane_mesh(sx, sz, tx, tz, segments)` |
| Planets | `planet_grid(level)`, `planet_cell(level, i)`, `planet_neighbours(level, i)`, `planet_nearest(level, x, y, z)`, `planet_sample(level, values, x, y, z)`, `planet_plates(level, seed, n)`, `planet_tectonics{level, seed, plates, continental}`, `planet_climate{level, elevation, axis, tilt_sin, locked, sub, mean, span, lapse, water, iterations}` → `{temp, tmin, tmax, precip, wind}`, `planet_rivers{level, elevation, precip}` → `{filled, flow_to, flow, lake}`, `planet_territory(level, seeds, cost)` → owner per cell, `planet_components(level, mask)` → ids, count (cells and plates are numbered from 1; 0 means none) |
| Procedural | `hash(...)`, `rng(seed [, stream])`, `noise(x, y [, seed, octaves, lacunarity, gain])`, `noise3(...)`, `terrain{...}` (with `slot = 0..3`: independent height fields, 0 is the land's), `height(x, z [, slot])`, `terrain_chunk(cx, cz [, size, cells, slot])`, `voxels(sx, sy, sz)` (grids also have `g:hash()`), `mesh_count()`, `texture_gen{...}`, `texture_recolor(path, colors [, "green"])` |
| Entities | `spawn{...}` (with `parent = e`; a solid one with `height = h` blocks only feet between its base less 0.4 m and its top, so storeys above each other do not block each other; `snap = false` draws it without vertex snapping, for large merged voxel surfaces), `attach(child [, parent])`, `world_pos(e)`, `set(e, {...})`, `set_pos`, `get_pos`, `set_yaw`, `get_yaw`, `get_rotation(e)` (yaw, pitch, roll), `set_visible`, `set_color`, `destroy`, `exists`, `clear_scene`, `entity_count` |
| World | `camera(x, y, z, yaw, pitch, fov)`, `environment{...}`, `environment_save()` → a copy of the sky, fog and light, `environment_load(copy)`, `sky{...}`, `light(i, ...)`, `bounds(...)`, `move(x, y, z, dx, dz, r)`, `overlaps(x, z, r)` |
| Input | `value(action)`, `down`, `pressed`, `released`, `look()`, `touch([on])`, `taps()` (this update's taps: `{ {x, y} }` in UI units) |
| Audio | `play(sound, vol, pan, loop, group)`, `stop`, `stop_group`, `fade(voice, vol, secs, stop)`, `playing`, `group_volume(g [, v])` |
| UI | `ui_size()`, `rect`, `image`, `text(x, y, s, scale, r, g, b, a)`, `text_width`, `wrap(s, width)` |
| Data | `config(key, default)`, `save_get`, `save_set`, `save_write`, `save_clear`, `record_read(name)`, `record_write(name, table)`, `record_list([prefix])`, `record_delete(name)`, `file_exists`, `read`, `mods()`, `run_mod(i)` |
| Misc | `log`, `time`, `ticks`, `quit`, `platform`, `headless`, `testing`, `xr()`, `xr_request()`, `xr_head()`, `version` |

Scripts run in a sandbox: `io`, `loadfile` and the process functions of `os`
are not available, and file access goes through the data folders only.

## Procedural generation API

These functions are deterministic: the same inputs give the same results on
every platform, which is what makes seeded worlds possible. Examples marked
with `<!-- example -->` are run by the test suite (`ctest -R docs`).

### Hashing, random streams and noise

<!-- example -->
```lua
local seed = mvl.hash("my-world", 42)          -- integers and strings, order matters
local rng = mvl.rng(seed, 1)                    -- PCG32 stream; same seed+stream = same numbers
local roll = rng:int(1, 6)                      -- also :next() [0,1), :float(lo, hi), :chance(p), :pick(list), :u32()
local hills = mvl.noise(10.5, 3.25, seed, 4)    -- 2D fractal value noise in [-1, 1] (x, y, seed, octaves, lacunarity, gain)
local caves = mvl.noise3(1, 2, 3, seed, 2)      -- 3D variant
assert(roll >= 1 and roll <= 6 and hills >= -1 and hills <= 1 and caves >= -1)
```

### Terrain

`mvl.terrain{...}` configures the height field (all fields optional):
`seed`, `base`, `amp`, `freq`, `octaves`, `lacunarity`, `gain`,
`origin_x`, `origin_z` (added to positions before sampling the noise),
`flats = {{x, z, radius, falloff, height}, ...}` (up to 128 flattened areas;
with `x2, z2` and `height2` a flat is a graded segment, e.g. under a road),
`map = {w, h, x0, z0, cell, data}` (a coarse elevation map that is added,
bicubic), and colouring: `palette = {{r, g, b}, ...}` (up to 4, low to high),
`color_low`, `color_high`, `slope_color`, `slope_start`, `color_noise`,
`uv_scale` (metres per texture repeat). `mvl.height(x, z)` queries the
surface and `mvl.terrain_chunk(cx, cz, size, cells)` builds the mesh of one
chunk, local to the chunk origin `(cx * size, 0, cz * size)`. Neighbouring
chunks share identical border vertices.

<!-- example -->
```lua
mvl.terrain{ seed = 7, amp = 4, freq = 0.03, palette = {{60, 90, 50}, {120, 130, 90}},
             flats = {{x = 0, z = 0, radius = 6, falloff = 8, height = 1}} }
local size = 32
local mesh = mvl.terrain_chunk(0, 0, size, 16)
local chunk = mvl.spawn{ mesh = mesh, texture = mvl.texture("textures/grass.tga"), pos = {0, 0, 0} }
local y = mvl.height(3, 3)                      -- 1: inside the flat area
assert(math.abs(y - 1) < 1e-6)
mvl.destroy(chunk)
mvl.release_mesh(mesh)                          -- free the slot when the chunk is unloaded
```

### Runtime voxel models

`mvl.voxels(sx, sy, sz)` returns a grid (up to 256 per axis, Z up like
MagicaVoxel) with methods `set`, `get`, `box`, `sphere`, `ellipsoid`,
`cylinder` (vertical), `line`, `mirror_x` (copy the low-X half onto the
high-X half), `replace`, `color(index, r, g, b[, a])`, `count`, `size`,
`mesh(voxel_size)` and `free`. Colours are palette indices 1..255. Meshing
merges the visible faces of one colour on one plane into rectangles of up
to 16 voxels a side, so large flat walls cost few triangles.

<!-- example -->
```lua
local g = mvl.voxels(16, 8, 16)
g:color(1, 120, 90, 60)                         -- trunk colour
g:color(2, 60, 140, 70)                         -- leaf colour
g:cylinder(8, 4, 0, 9, 1.2, 1)                  -- trunk: centre x, y, z from, z to, radius
g:sphere(8, 4, 11, 4, 2)                        -- crown
local tree = mvl.spawn{ mesh = g:mesh(0.125), pos = {4, 0, -6} }
g:free()                                        -- the mesh stays, the grid is released
assert(mvl.exists(tree))
```

### Generated textures

`mvl.texture_gen{kind, size, seed, scale, octaves, contrast, colors}`
returns a seamless texture id (cached by recipe). Kinds: `noise`, `stone`,
`soil`, `bark`, `foliage`, `water`, `cloth`, `brick`. `size` is a power of
two from 16 to 128, `colors` a gradient of up to 6 `{r, g, b[, a]}`.

<!-- example -->
```lua
local sandstone = mvl.texture_gen{ kind = "stone", size = 32, seed = 3, scale = 4,
                                   colors = {{120, 50, 40}, {190, 110, 80}, {230, 170, 130}} }
local wall = mvl.spawn{ mesh = mvl.box_mesh(2, 2, 0.5), texture = sandstone, pos = {0, 0, -4} }
assert(sandstone > 0 and mvl.exists(wall))
```

`mvl.texture_recolor(path, colors [, "green"])` repaints a texture file
along a gradient of up to 6 colours by brightness (darkest pixel to the
first colour, brightest to the last) and returns the new texture id (cached).
With `"green"` only pixels where green dominates (leaves, grass) are
repainted, so trunks, petals and stones keep their colours. Generated lands
use it to colour plants by their star's light and stone by their bedrock
(`gen/visuals/palette.lua`).

<!-- example -->
```lua
local purple_oak = mvl.texture_recolor("textures/tree_oak.tga", {{10, 8, 14}, {50, 30, 68}, {84, 54, 108}}, "green")
local red_stone = mvl.texture_recolor("textures/stone.tga", {{94, 46, 33}, {170, 84, 60}, {191, 127, 109}})
assert(purple_oak > 0 and red_stone > 0 and purple_oak ~= red_stone)
```

### The sky

`mvl.environment{...}` sets the sky's gradient (`sky_top`, `sky_horizon`),
fog, ambient light, the sun's light (`sun_dir`, the direction the light
travels, and `sun_color`) and `stars` (0..1, also dims planets and the
galaxy band). `mvl.sky{...}` sets what stands in the sky, replacing what was
there (`mvl.environment{reset = true}` clears it too):

| Field | Meaning |
|---|---|
| `sun = {dir, color, size, glow}` | the star's disc: direction from the viewer, colour, angular radius (radians), halo |
| `light = {x, y, z}` | direction towards the star for moon phases (default: `sun.dir`; may be below the horizon) |
| `moons = {{dir, color, size}, ...}` | up to 4 discs, lit from `light`, so they show their phases |
| `planets = {{dir, color, size}, ...}` | up to 8 bright points |
| `band = {normal, core, color, strength, width}` | the galaxy: a cloudy great circle around `normal`, brightest towards `core` |

It returns the number of moons and planets taken. Generated places compute
all of it with `gen.sky` (positions for a place and a moment, phases, the
air's colours by day and night).

<!-- example -->
```lua
mvl.environment{ sky_top = {0.01, 0.01, 0.04}, sky_horizon = {0.05, 0.06, 0.12}, stars = 1 }
local moons, planets = mvl.sky{
  light = {1, -0.2, 0},                                  -- the star lies just below the horizon, towards +x
  moons = { { dir = {-0.3, 0.5, -1}, size = 0.08, color = {0.9, 0.9, 0.85} },
            { dir = {0.4, 0.4, -1}, size = 0.05, color = {0.9, 0.6, 0.4} } },
  planets = { { dir = {0, 0.2, -1}, size = 0.006, color = {1, 0.9, 0.7} } },
  band = { normal = {1, 0.3, 0.2}, core = {0, 0.3, -1}, color = {0.8, 0.8, 1}, strength = 0.4, width = 0.15 },
}
assert(moons == 2 and planets == 1)
```

### Decals

Flat things lying on a surface (roads, paths, puddles, rugs, painted marks)
should be decals: they are drawn after the surface below them and never
flicker into it, at any distance. Put them exactly on the surface (`y = 0`
on flat ground) and give overlapping decals a `layer` from 0 to 7 (higher is
drawn on top). Large surfaces should be tessellated with the fifth argument
of `mvl.plane_mesh(sx, sz, tiles_x, tiles_z, segments)`: the retro vertex
snapping moves vertices by up to half a pixel, which bends huge triangles.

<!-- example -->
```lua
local ground = mvl.spawn{ mesh = mvl.plane_mesh(64, 64, 16, 16, 16), texture = mvl.texture("textures/grass.tga") }
local road = mvl.spawn{ mesh = mvl.plane_mesh(4, 64, 1, 16, 16), texture = mvl.texture("textures/dirt.tga"),
                        decal = true, layer = 0 }
local puddle = mvl.spawn{ mesh = mvl.plane_mesh(3, 2, 1, 1, 2), texture = mvl.texture("textures/water.tga"),
                          pos = {0.5, 0, 3}, decal = true, layer = 1, uv_scroll = {0.02, 0.01} }
assert(mvl.exists(road) and mvl.exists(puddle))
```

### Portals

A portal is a rectangle in the scene that shows another place, like a window
(the van's windows use them). `mvl.portal(i, {pos, yaw, w, h, target,
target_yaw})` defines portal `i` (0..7): the rectangle is centred on `pos`,
faces along `yaw` (0 looks along -Z) and is seen from its back side; what
lies beyond `target` in the direction `target_yaw` is shown inside it.
Geometry between the target and the viewer is clipped away. `mvl.portal(i)`
switches it off. Portals are one-sided and do not show other portals.

<!-- example -->
```lua
-- a window at the origin that looks out at a place 500 m away
mvl.portal(0, { pos = {0, 1.5, 0}, yaw = 0, w = 1.2, h = 0.8, target = {500, 1.5, 500}, target_yaw = 0 })
local view = mvl.spawn{ mesh = mvl.box_mesh(4, 4, 4), pos = {500, 0, 490} }   -- seen through the window
mvl.portal(0)                                                                -- close it again
assert(mvl.exists(view))
```

Entities outside the camera's view are not drawn (frustum culling);
`mvl.render_stats()` returns the draw calls of the last frame.

### Composite entities

Entities can be attached to a parent; their position, rotation and scale
then become local to the parent, they move with it, are destroyed with it
and never collide. Use `parent = handle` in `mvl.spawn`, or
`mvl.attach(child, parent)` (`mvl.attach(child)` detaches).
`mvl.world_pos(e)` returns the world position.

<!-- example -->
```lua
local body = mvl.spawn{ mesh = mvl.box_mesh(1, 0.6, 2), pos = {0, 0, -3} }
local head = mvl.spawn{ mesh = mvl.box_mesh(0.5, 0.5, 0.5), pos = {0, 0.6, -1.2}, parent = body }
mvl.set_yaw(body, math.pi / 2)                  -- the head turns with the body
local hx, hy, hz = mvl.world_pos(head)
assert(math.abs(hx - -1.2) < 1e-4 and math.abs(hz - -3) < 1e-4)
mvl.destroy(body)                               -- also destroys the head
assert(not mvl.exists(head))
```

## Plants and creatures

Generated species become voxel models at runtime (`gen/visuals/plants.lua`,
`gen/visuals/creatures.lua`), cached by `gen/visuals/models.lua` and brought
to life by `lib/creatures.lua`.

**Plant grammar.** Each plant lineage has a grammar drawn from its seed
(`plants.grammar(lseed)`): `angle` between a branch and its parent,
`splits` per fork, `depth` of forking, `trunk` (share of the height that is
bare), `lean`, `crown` (size of leaf clusters) and `shrink` (branch length
ratio). A species evaluates it for its form and leaf into a grid of at most
24 x 24 x 32 voxels: broad crowns are leaf blobs at the branch tips, needle
trees stacked tiers, frond trees a curved trunk with drooping fronds,
shards crystal spikes, shrubs short stems with blobs, herbs grass blades with
flowers, fungi stems and caps. Palette indices 1-2 are bark, 3-5 leaves (dark
to light) and 6 a highlight.

**Creature body plans.** `creatures.plan(p)` turns traits (`limbs`,
`covering`, `segments`, `eyes`, `tail`, `move`, `size`, `height`,
`stockiness`, `colors`, `seed`) into voxel proportions: a torso of 12 voxels
along +y (the model faces -z in the world), its width and height from the
build, legs in pairs at hips along the torso, wings for flyers and gliders,
a tail, or a chain of segments for legless crawlers. Each movable part is a
separate mesh (`body`, `leg`, `wing`, `tail`, `seg`) attached to the body by
parenting, and `merged` holds the resting pose for creatures far away.
Palette indices: 1 dark, 2 base, 3 light, 4 eyes, 5 bright accents.

**Adding a body part.** Register a function in `creatures.PARTS`; it is
called (in name order) for every body and merged model with the voxel grid,
the plan and the torso's bottom `z0` and middle `cy`, and may draw anything:

<!-- example -->
```lua
local creatures = require("gen.visuals.creatures")
creatures.PARTS.horn = function(g, plan, z0, cy)
  -- a horn on the head, in the bright accent colour
  g:line(8, cy + plan.ry + 2, z0 + plan.rz * 2, 8, cy + plan.ry + 4, z0 + plan.rz * 2 + 4, 0.6, 5)
end
local beast = creatures.build({ limbs = 4, covering = "fur", segments = 2, eyes = 2, tail = true, move = "walk",
                                size = 1.2, height = 1, stockiness = 1.1, seed = 7,
                                colors = { { 60, 40, 30 }, { 120, 90, 60 }, { 200, 170, 120 } } })
local cow = mvl.spawn{ mesh = beast.merged, pos = { 0, 0, -4 } }
assert(beast.body > 0 and beast.leg > 0 and beast.tail > 0 and mvl.exists(cow))
mvl.destroy(cow)
creatures.release(beast)
creatures.PARTS.horn = nil
```

**Models and budgets.** `models.new{budget, max}` makes a cache: `acquire(p)`
returns the shared model for parameters `p` (with a `key`), building at most
`budget` new models per tick and keeping at most `max` meshes; it returns
nil when over budget (callers then draw the species' sprite). `release(key)`
frees the meshes when the last user is gone. Every land's streamer has one
(`streamer.models`); a herd's members share one model.

**Behaviour.** `streamer.creatures` keeps every animal of the loaded chunks:
grazers graze, wander near home or their herd's leader and flee when the
player comes within 9 m or runs at them from within 18 m (their whole herd
with them); prowlers prowl and back away; flyers circle above their home
and dart off; burrowers crawl and burrow when disturbed. Within 40 m a
creature has its parts and is animated (legs in alternating pairs, flapping
wings, swaying tails, slithering segments); further away it is its merged
model. Plants near the player sway.

## Buildings, people and statues

**Style vectors** (`gen/culture/architecture.lua`): each culture has a
`style` = `{material, plan, roof, pitch, wall, door = {h, w}, roof_entry,
ornament, sky_faith, storeys, palette = {wall, wall_dark, roof, roof_dark,
wood, accent}, dress = {garment, color, trim, status}}`. Materials are
`stone`, `timber`, `mud brick` or `hide`; plans `square`, `round`,
`courtyard`, `longhouse`, `burrow` or `tower`; roofs `gable`, `hip`,
`flat`, `dome`, `cone` or `turf` (or any registered roof); ornaments
`crescents`, `discs`, `flames`, `waves`, `spirals`. A land repaints stone
walls in its own bedrock (`architecture.local_style`), and keeps the result
in `land.data.architecture`.

**Floor-plan grammar** (`gen/visuals/buildings.lua`): buildings are sized
in metres from the height of the people who build them (`style.height`,
1.7 m for humans) and then turned into voxels (1/8 m, Z up, door towards
+y). `buildings.sizes(style)` gives the storey (3 m or 1.75 x the height),
the door (2 m or 1.25 x the height, wide enough for the player) and a
scale for footprints. `buildings.KINDS` holds the footprint range of each
kind in metres at human height (`w`, `d` as `{min, max}`, `storeys` added to
the style's, `min` storeys) — `cottage`, `house`, `workshop`, `barn`, `inn`,
`hall`, `temple`, plus `well` and `wall`; a mod can change them or add
kinds. `buildings.plan(kind, style, seed [, opts])` is the plan (in voxels,
with `p.metres = {w, d, storey, door, door_w, walls}`), `buildings.build(...)`
fills a grid of at most 256 x 256 x 256 cells (a 30 m square), and
`buildings.parts(kind, style, seed, length)` splits a building longer than
24 m into modules that join seamlessly (one with the door; `opts.length`,
`opts.door`, `opts.gable`). Palette indices: 1 wall, 2 wall shadow, 3 roof,
4 roof shadow, 5 wood, 6 accent, 7 openings, 8 hatch.
`buildings.mesh(kind, style, seed [, ruined, opts])` returns the mesh, its
footprint in metres, a hash and the plan. Lands lay buildings out by their
footprints (`land.layout_buildings`): rings around the square, temple
across from the van, the rest along the way in, never overlapping, clear
of the lane, the van and rivers, each on its own flattened ground.

**People** (`gen/visuals/people.lua`): `people.build{anatomy, hue, dress,
accent}` stands a species upright (two legs and arms, or a taur body when it
has more limbs than hands), with wings, tail, eyes and mouth, in its dress;
`statue = true, stone, attributes = {"staff", "crown", "book", "sword",
"halo"}` makes a statue on a plinth. Add attributes through
`people.ATTRIBUTES[name] = function(g, b) ... end`.

**Adding a roof type.** Register a function in `buildings.ROOFS`; it draws
onto the walls of the plan `p` (footprint `p.x0..p.x1`, `p.y0..p.y1`,
`p.w`, `p.d`, `p.pitch`) from height `top` and returns the highest voxel.
Styles with `roof = "<name>"` use it:

<!-- example -->
```lua
local buildings = require("gen.visuals.buildings")
buildings.ROOFS.onion = function(g, p, top)
  local cx, cy = (p.x0 + p.x1) / 2, (p.y0 + p.y1) / 2
  g:ellipsoid(cx, cy, top + 6, p.w / 3, p.d / 3, 7, 3)    -- the bulb in roof colour
  g:line(cx, cy, top + 12, cx, cy, top + 17, 0.6, 6)      -- a finial in the accent colour
  return top + 17
end
local style = {
  material = "stone", plan = "square", roof = "onion", pitch = 0.8, wall = 1, door = { h = 14, w = 7 },
  roof_entry = false, ornament = "none", storeys = 2,
  palette = { wall = { 200, 190, 170 }, wall_dark = { 150, 140, 125 }, roof = { 60, 120, 90 }, roof_dark = { 40, 90, 70 },
              wood = { 112, 78, 48 }, accent = { 230, 200, 90 } },
}
local mesh, footprint = buildings.mesh("temple", style, 1)
local temple = mvl.spawn{ mesh = mesh, pos = { 0, 0, -12 }, box = footprint }
assert(mesh > 0 and mvl.exists(temple))
mvl.destroy(temple)
mvl.release_mesh(mesh)
buildings.ROOFS.onion = nil
```

## The house inside the van

Juniper is a house (`gen/house/`, built by `lib/house.lua` in a pocket of
the scene far below the world). `gen/house/plan.lua` describes its rooms as
rectangles in pocket metres (+X is the van's front, +Z its left) with a
level `y`, a ceiling height `h`, a style (floor `boards`, `tiles`, `carpet`,
`flags` or `mat`; walls `stripes`, `plain`, `panels`, `tiles`, `stone` or
`van`; `dado`, `beams`, `glass` walls, `glass_roof`; `colors` for the
palette names of `gen/house/palette.lua`), doorways (`side` "n" = +Z, "s",
"e" = +X, "w"; `at` along the wall; `closed`, `glass`, `shape = "arch"`),
windows (`portal` = the van window they look out of; others are frosted
panes), stairs, holes and furniture. `gen/house/rooms.lua` turns a room into
one voxel grid and so one mesh, plus box colliders with heights (storeys do
not block each other); the player's floor follows rooms and stairs.

Beyond the core (block 0, 0) the house is a grid of 32 m blocks without end
(`gen/house/blocks.lua`): each block is laid out from the game's seed and
its position by a template (`cross`, `enfilade`, `hall`, `cloister`), has a
doorway in the middle of every side, and is styled and furnished by room
kind (`gen/house/kinds.lua`: `kinds.KINDS[name] = { floor, wall = {
{piece, opts, chance, count} }, middle = function(room, add), ceiling }`;
furniture keeps the way in through every doorway clear). `lib/house.lua`
builds the rooms within 36 m of the player, one per update, and releases
them beyond 48 m; only the core stays while the player is outside. Deeper
in the house than the cab and the hall, far rooms fade into a warm dusk.

**Souvenir wings** (`gen/house/wings.lua`): the first visit to a land of a
people keeps a souvenir of them in the save (`progress.souvenirs()`: name,
species, the land's architecture style, one of them, colours of their
plants). The blocks round the core, in a spiral (`wings.ORDER`), become
their wings in the order of the visits: a grand hall or a courtyard with a
statue of one of them, walls of their material (`stone`, `panels` for
timber, `brick` for mud brick, `hide`) in their colours with friezes of
their ornament, doorways for their height, their plants and a sign.

**The garden** (`gen/house/garden.lua`, `lib/garden.lua`): the
conservatory's door opens onto a garden without end, 1,600 m below the house
on terrain slot 1 (`garden.G.SLOT`) with its own golden-afternoon sky:
a formal garden of hedges and flower beds by the back of the house, then
meadows, woods, orchards and ponds by region, and a path winding away from
the door. Its 32 m chunks are described from the game's seed
(`garden.G.chunk(seed, cx, cz)`) and streamed round the player in the garden,
or round the door while the player is in the conservatory. The door is a
pair of portals: walking through it moves the player between the
conservatory and the lawn in front of the back of the house.

**Adding a piece of furniture.** Register it in `furniture.PIECES`: its size
in voxels (1/8 m) and a draw function using a pen in the piece's own frame
(a across, b from its front to its back, c up); placed `wall = "n"` it backs
onto that wall and faces away from it:

<!-- example -->
```lua
local F = require("gen.house.furniture")
local I = require("gen.house.palette").I
local rooms = require("gen.house.rooms")
F.PIECES.birdcage = {
  solid = true,
  size = function() return 4, 4, 10 end,
  draw = function(p)
    p:box(1, 1, 0, 2, 2, 3, I.wood_dark)        -- a stand
    p:box(0, 0, 4, 3, 3, 9, I.brass)            -- the cage
    p:box(1, 1, 5, 2, 2, 8, 0)                  -- hollow inside
    p:set(1, 1, 6, I.flower2)                   -- a yellow bird
  end,
}
local room = { id = "aviary", x0 = 0, x1 = 4, z0 = 0, z1 = 3, y = 0, h = 2.5,
               style = { floor = "tiles", wall = "stripes" },
               doors = { { side = "s", at = 2, w = 1.0, h = 2.0 } },
               items = { { piece = "birdcage", wall = "n", at = 2 } } }
local built = rooms.build(room, 1)
assert(built.mesh > 0 and #built.colliders >= 6)   -- five wall pieces and the cage
mvl.release_mesh(built.mesh)
F.PIECES.birdcage = nil
```

## World memory

Every place the player visits is stored in the save on the first visit and
loaded on later visits instead of being generated again
(`memory/places.lua`), so it stays exactly as the player found it, even
after a game update changes the generator. Everything the player changes
there is kept in the place's **change log** (`memory/changes.lua`) and
applied whenever its chunks are built.

Objects have stable ids: features of a land have their own `id`
(`"farmhouse"`, `"building3"`, `"q_item2"`, ...), plants are
`"flora/<chunk x>,<chunk z>/<n>"`, and things the player puts into the world
get `"placed/<n>"`. A world's change log is `w:memory()`:

| Call | Effect |
|---|---|
| `log:get(id)` | The recorded overrides of an object (or nil) |
| `log:set(id, fields)` | Overrides fields: `x`, `z`, `y`, `yaw`, `sprite`, `texture`, `color`, `unlit`, `hidden`, `state` or any field of your own |
| `log:take(id)`, `log:taken(id)` | Removes an object for good / asks whether it was |
| `log:place(object)` | Puts a new object (`sprite` or `voxel`/`model`, `x`, `z`, ...) into the land; returns its id |
| `log:unplace(id)` | Removes a placed object |
| `log.quest`, `log:set_quest(t)` | The land's quest progress |
| `log:flush()` | Writes the log now (otherwise it is written when leaving, on saving, at the end of the night and every 30 seconds) |

`w.streamer:add_feature(object)` shows a newly placed object at once;
`w.streamer:remove_feature(id)` removes one from the built world.

The log also keeps what people remember (`log.characters`,
`log.community`, see `memory/characters.lua`), how the quest ended
(`log.outcome`), the land's events since the player came (`log.events`) and
its clock and aftermath (`log.clock`, `log.aftermath`, `log.chapter`).

### Time passing

When a land's quest ends, **aftermath rules** decide what happens there in
the nights after (see [WORLDGEN.md](WORLDGEN.md#world-memory) for the base
rules). A rule is `{ id, after = nights, when = function(x), apply =
function(x), followup = function(x) }`; it is applied once, when the player
comes back at least `after` nights later and `when(x)` is true. Mods add
rules with `gen.cosmos:content("aftermath_rules", {...})`, like the sample
mod's moonberry bushes. The context `x` has:

| Field or call | Meaning |
|---|---|
| `x.outcome` | How the quest ended: `kind`, `result` (`done`, `a`, `b`, `compromise`, `abandoned`), `template`, `severity`, `tension`, `issue`, `favoured`, `wronged`, `night` |
| `x.success`, `x.severity`, `x.title`, `x.deed`, `x.place`, `x.lore`, `x.data` | Helped or not; the name the land calls the player and their deed; the land's data |
| `x:spot(rmin, rmax)` | A free spot that far from the square |
| `x:mark(object)` | Builds a mark: any feature (`sprite`, `voxel`, `statue`, `trace`, `building`...) placed for good |
| `x:news(text)` | What people will tell the player ("...since you ...") |
| `x:event(text)` | An event of the land's history |
| `x:field()`, `x:person(id)`, `x:leave()`, `x:ruin()` | A new field, a newcomer, a villager leaving, a house in ruins |
| `x:festival(name)`, `x:rename(name)` | A festival in the calendar (with lanterns), a new name |
| `x:trouble({ kind, text, quest, cause })` | A new trouble: the land's next quest |

`followup(x)` returns a need or an invitation (`{ kind = "need" |
"invitation", text, short }`) queued when the quest ends for night `night +
after`; the signals keep a slot for it. Deeds spread as stories by
`memory/spread.lua` (`spread.heard(address, culture, nation, night)`).

<!-- example -->
```lua
local world = require("lib.world")
local w = world.current                  -- the farm is a generated land too
local log = w:memory()
local well
for _, f in ipairs(w.land_node.data.features) do if f.role == "well" then well = f end end
-- paint the well blue and move it a little, for good
log:set(well.id, { x = well.x + 0.5, color = { 0.6, 0.7, 1, 1 }, state = "painted" })
-- and leave some flowers next to it
local id = log:place({ sprite = "flowers", x = well.x + 3, z = well.z, w = 0.6, h = 0.6 })
w.streamer:add_feature(log.placed[id])
assert(log:get(well.id).state == "painted" and log.placed[id].x == well.x + 3)
log:flush()
assert(mvl.record_read("changes/" .. w.land_node.address).objects[well.id].state == "painted")
```

### The codex

What the player learns goes into the codex (`memory/codex.lua`, record
`codex`). Generated lands keep snapshots of the entries they can teach
(`d.codex = { entries, keys }`, built by `gen/codex.lua`): each entry is
`{ id, kind, name, gloss, text, believed, truth, links = { ids }, why = {
{ name, category, id } }, universe }`, with kinds `place`, `species`,
`faction`, `language`, `religion`, `individual`, `event`, `creature` and
`tradition`; ids are fact ids where the generator has a fact. Entries are
unlocked by visiting (`codex.visit(node)`: the place and its people),
talking (`codex.heard(node, used, speaker)` with the slots a conversation
used: a saint's story, a remembered event, the faith, a holiday, the
greeting, a beast), reading inscriptions (`codex.read(node, feature)` on
statues and traces) and observing creatures (`codex.observe(node,
species_id)`). A mod can unlock its own: `codex.discover(entry, how, where,
{ by, told })`. The codex screen (`lib/codex.lua`) shows them with links,
the versions people told, Juniper's true version where she knows the
universe (`codex.juniper_knows(entry)`), the why view (causes the player
has not learned are "unknown"), and the Wanderer's chronicle of the
player's deeds and what came of them (`codex.chronicle()` in
`lib/codex.lua`). It opens from the road atlas in the van's cab, the pause menu and the
`codex` action, and works with keyboard, gamepad and taps.

## Saves and records

A save is a folder (the platform's user data folder, `/save` in the browser,
or the folder passed with `--save`):

| Path | Content |
|---|---|
| `index.ini` | Sorted `key = value` lines: seed, night, location, flags. Read and written with `mvl.save_get`, `mvl.save_set` and `mvl.save_write`. |
| `records/<name>.rec` | Data records: `places/<address>` (a visited land), `changes/<address>` (its change log), `logbook`, and whatever mods store. |

A record holds a table of numbers, strings, booleans and nested tables (up to
48 levels; functions and other values are refused). It is stored in a
compact binary format with a checksum and never runs code when it is loaded.
Every write goes to `<name>.rec.tmp` first and is then renamed over the old
file, so a crash leaves either the old or the new version. Record names use
letters, digits, `_`, `-`, `.` and `/` (folders).

| Function | Result |
|---|---|
| `mvl.record_write(name, t)` | Stores `t` now. `true`, or `false, message` if the disk refused. |
| `mvl.record_read(name)` | A fresh copy of the table, or `nil, "missing"` / `nil, "damaged"`. |
| `mvl.record_list([prefix])` | Sorted names of the stored records that start with `prefix`. |
| `mvl.record_delete(name)` | `true` if a record was removed. |
| `mvl.save_clear()` | Empties the index and deletes every record (a new journey). |

Records are written immediately; in the browser the save folder is copied
to IndexedDB at the end of every frame that wrote something. A save from an
older version (a single `savegame.ini`) is converted on start and kept as
`savegame.ini.bak`.

<!-- example -->
```lua
-- remember what happened at a place, across sessions
local name = "places/example/old_farm"
local place = mvl.record_read(name) or { visits = 0, notes = {} }
place.visits = place.visits + 1
place.notes[#place.notes + 1] = { night = 1, text = "the gate was left open" }
assert(mvl.record_write(name, place))

local again = mvl.record_read(name)
assert(again.visits == place.visits and again.notes[1].text == "the gate was left open")
assert(mvl.record_list("places/example/")[1] == name)
mvl.record_delete(name)
```

## Testing a mod

Write a game test like `tests/game/test_mods.lua` and run it headless:

```bash
./build/mvl_headless --data game --mods path/to/mods --save /tmp/save --test my_test.lua
```

Tests drive the game through `test.input(action, value)`, `test.press`,
`test.hold`, `test.look`, `test.touch` and `test.wait(frames)` /
`test.seconds(s)`, and check it with `test.expect`, `test.eq` and
`test.until_true`. They can also inspect audio (`test.mixer_voices([group])`,
`test.voice_volume(voice)`, which is -1 once a voice stopped), count UI quads
(`test.ui_quads()`) and read files next to the test (`test.read_file(path)`).
The headless runner mixes audio like a sound device, so fades progress.

A mod that adds generation content can be checked with the same guards as
the base game: that the multiverse stays varied, generation stays within its
time budgets, and its passes keep their promises:

```bash
./build/mvl_headless --data game --mods path/to/mods --save /tmp/save --stats 200 --thresholds tests/stats_thresholds.ini
```

```bash
./build/mvl_headless --data game --mods path/to/mods --save /tmp/save --budget 12 --budgets tests/budgets.ini
```

```bash
./build/mvl_headless --data game --mods path/to/mods --save /tmp/save --bible u1.g2.c3.s1 --out bible.md
```
