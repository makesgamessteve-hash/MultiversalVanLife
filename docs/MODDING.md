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
| Resources | `texture(path)`, `mesh(path [, voxel_size])`, `plane_mesh(sx, sz, tx, tz)`, `box_mesh(sx, sy, sz)`, `mesh_bounds(id)`, `sound(path)`, `sound_length(id)` |
| Entities | `spawn{...}`, `set(e, {...})`, `set_pos`, `get_pos`, `set_yaw`, `get_yaw`, `set_visible`, `set_color`, `destroy`, `exists`, `clear_scene`, `entity_count` |
| World | `camera(x, y, z, yaw, pitch, fov)`, `environment{...}`, `light(i, ...)`, `bounds(...)`, `move(x, y, z, dx, dz, r)`, `overlaps(x, z, r)` |
| Input | `value(action)`, `down`, `pressed`, `released`, `look()`, `touch([on])` |
| Audio | `play(sound, vol, pan, loop, group)`, `stop`, `stop_group`, `fade(voice, vol, secs, stop)`, `playing`, `group_volume(g [, v])` |
| UI | `ui_size()`, `rect`, `image`, `text(x, y, s, scale, r, g, b, a)`, `text_width`, `wrap(s, width)` |
| Data | `config(key, default)`, `save_get`, `save_set`, `save_write`, `save_clear`, `file_exists`, `read`, `mods()`, `run_mod(i)` |
| Misc | `log`, `time`, `ticks`, `quit`, `platform`, `headless`, `testing`, `xr()`, `xr_request()`, `xr_head()`, `version` |

Scripts run in a sandbox: `io`, `loadfile` and the process functions of `os`
are not available, and file access goes through the data folders only.

## Testing a mod

Write a game test like `tests/game/test_mods.lua` and run it headless:

```bash
./build/mvl_headless --data game --mods path/to/mods --save /tmp/save --test my_test.lua
```
