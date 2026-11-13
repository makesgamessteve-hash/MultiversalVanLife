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
| `scripts/worlds/` | One file per world (home and the destinations) |
| `scripts/lib/van.lua` | Juniper's interior, its window portals and the vortex |
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
the game runs it at start-up, after the base worlds are registered.

### Adding a destination

`mods/my_world/init.lua`:

```lua
local world = require("lib.world")
local story = require("lib.story")
local dialogue = require("lib.dialogue")

world.register({
  id = "my_world",
  name = "Glass Dunes",
  destination = true,       -- listed on the van console
  order = 10,               -- position in the list
  ambient = "sounds/ambient_night.wav",
  build = function(w)
    w:env({ sky_top = {0.3, 0.1, 0.4}, sky_horizon = {0.9, 0.5, 0.6}, fog_far = 50 })
    w:bounds(-30, -30, 30, 30)
    w:ground("sand", 100, 50)
    w:prop({ voxel = "well", x = 4, z = -6, radius = 1 })
    w:sprite({ texture = "tree_oak", x = -5, z = -8, w = 3, h = 4, radius = 0.4 })
    w:npc({ texture = "npc_robot", name = "Dune Bot", x = 0, z = -4, talk = function()
      dialogue.say("tock_1")
    end })
    story.place_van(w, 0, 6, -math.pi / 2)
    return story.van_door.x, story.van_door.z, story.van_door.yaw
  end,
})
```

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

`w.state` is a table for your world's own data and is reset on every load.
Progress that must survive should use `progress.set_flag` / `progress.helped`.

## Engine API (`mvl`)

| Group | Functions |
|---|---|
| Resources | `texture(path)`, `mesh(path [, voxel_size])`, `plane_mesh(sx, sz, tx, tz)`, `box_mesh(sx, sy, sz)`, `mesh_bounds(id)`, `sound(path)`, `sound_length(id)`, `release_mesh(id)`, `release_texture(id)` |
| Rendering | `portal(i [, {pos, yaw, w, h, target, target_yaw}])`, `render_stats()`; `spawn{decal = true, layer = n}`, `plane_mesh(sx, sz, tx, tz, segments)` |
| Procedural | `hash(...)`, `rng(seed [, stream])`, `noise(x, y [, seed, octaves, lacunarity, gain])`, `noise3(...)`, `terrain{...}`, `height(x, z)`, `terrain_chunk(cx, cz [, size, cells])`, `voxels(sx, sy, sz)`, `texture_gen{...}` |
| Entities | `spawn{...}` (with `parent = e`), `attach(child [, parent])`, `world_pos(e)`, `set(e, {...})`, `set_pos`, `get_pos`, `set_yaw`, `get_yaw`, `set_visible`, `set_color`, `destroy`, `exists`, `clear_scene`, `entity_count` |
| World | `camera(x, y, z, yaw, pitch, fov)`, `environment{...}`, `light(i, ...)`, `bounds(...)`, `move(x, y, z, dx, dz, r)`, `overlaps(x, z, r)` |
| Input | `value(action)`, `down`, `pressed`, `released`, `look()`, `touch([on])` |
| Audio | `play(sound, vol, pan, loop, group)`, `stop`, `stop_group`, `fade(voice, vol, secs, stop)`, `playing`, `group_volume(g [, v])` |
| UI | `ui_size()`, `rect`, `image`, `text(x, y, s, scale, r, g, b, a)`, `text_width`, `wrap(s, width)` |
| Data | `config(key, default)`, `save_get`, `save_set`, `save_write`, `save_clear`, `file_exists`, `read`, `mods()`, `run_mod(i)` |
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
`flats = {{x, z, radius, falloff, height}, ...}` (up to 16 flattened areas),
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

`mvl.voxels(sx, sy, sz)` returns a grid (up to 128 per axis, Z up like
MagicaVoxel) with methods `set`, `get`, `box`, `sphere`, `ellipsoid`,
`cylinder` (vertical), `line`, `mirror_x` (copy the low-X half onto the
high-X half), `replace`, `color(index, r, g, b[, a])`, `count`, `size`,
`mesh(voxel_size)` and `free`. Colours are palette indices 1..255.

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
