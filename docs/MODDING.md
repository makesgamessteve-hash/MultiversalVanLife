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
| `scripts/worlds/` | One file per world (home, van interior, destinations) |
| `shaders/` | GLSL shaders (written for GLSL 3.30 / GLSL ES 3.00, without `#version`) |
| `textures/` | TGA images (sprites use alpha cut-out) |
| `models/` | Wavefront OBJ models |
| `voxels/` | MagicaVoxel `.vox` models (one voxel = 1/8 m by default) |
| `sounds/` | 16-bit PCM WAV files |
| `voice/lines.txt` | Every dialogue line: `id \| speaker \| text` |
| `voice/<id>.wav` | Optional recorded or generated voice for a line |

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

Add your own lines by shipping a `voice/lines.txt` (it replaces the base file,
so copy the base lines too), or call `dialogue.say` with existing ids.

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
