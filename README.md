# Multiversal Van Life

A retro 3D exploration game. You live on a quiet farm. One night an old camper
van is parked at your gate, and a voice calls you in. The van is **Juniper**:
sentient, much bigger on the inside, and able to travel between worlds. Every
night Juniper picks up signals from places in trouble somewhere in an endless,
generated multiverse; you choose one, visit, and help the people who live there.

- **Retro 3D**: low-resolution rendering, per-vertex lighting, wobbly vertex
  snapping, fog and ordered dithering. Scenes mix OBJ models, billboard
  sprites and MagicaVoxel voxel models.
- **Platforms**: Windows, Linux, macOS, the web (Emscripten/WebGL2) with touch
  controls on phones, and WebXR virtual reality.
- **Moddable**: the C engine only runs what it finds in the `game/` folder next
  to the executable (Lua scripts, shaders, textures, models, voxels, sounds,
  dialogue). Mods in `mods/` can override anything and extend the generator
  with new troubles, styles and generation passes. See
  [docs/MODDING.md](docs/MODDING.md).
- **Generated multiverse**: every place, from universes down to single lands,
  is generated lazily and deterministically from the save's seed, with causes
  for every fact: galaxies and stars, planets with plates, climate, rivers,
  skies and living, moving wildlife, peoples with their own languages,
  faiths, calendars, customs, buildings and dress, and histories that leave
  ruins and legends. See [docs/WORLDGEN.md](docs/WORLDGEN.md) and the
  roadmap in [docs/ROADMAP.md](docs/ROADMAP.md).
- **Troubles with consequences**: every signal comes from a real tension of
  the place (a drought made worse by a dam upstream, a quarrel over a
  border...). Help, take a side or give up: people remember you, stories of
  your deeds travel, and when you come back time has passed, with festivals,
  statues, new troubles and invitations calling you back.
- **At the wheel**: sit in the driver's seat at the front of the van and drive
  it around the place you travelled to, watching from behind the van or
  through the windscreen; it stays where you park it.
- **The codex**: what you learn by visiting, talking, reading old stones and
  watching creatures, with what people believe beside what really happened,
  why things are as they are, and the chronicle of your own deeds.

## Layout

| Path | What |
|---|---|
| `engine/src/core` | Platform-independent C engine core (no SDL/GL). Unit tested. |
| `engine/src/platform` | SDL3 window/input/audio, OpenGL renderer, WebXR glue. |
| `engine/src/headless_main.c` | Runs the game without window/GPU/audio (tests, CI). |
| `game/` | Everything the game loads at runtime: `scripts/`, `shaders/`, `textures/`, `models/`, `voxels/`, `sounds/`, `music/`, `dialogue/`, `config/`. |
| `third_party/lua` | Lua 5.4.7 (MIT). |
| `third_party/dr_libs` | dr_mp3 MP3 decoder (public domain / MIT-0). |
| `tests/unit` | C unit tests. |
| `tests/game` | Automated game tests: Lua play-throughs of the real game. |
| `tests/web` | Playwright smoke test of the web build (desktop + phone). |
| `tools/gen_assets.py` | Regenerates the procedural textures, sprites and models (stdlib only). |
| `tools/audiogen` | Generates the sound effects, ambience and music with ElevenLabs. |
| `openspec/` | OpenSpec specifications of every capability. |
| `web/` | Web shell, WebXR bridge and pre-run script for Emscripten. |

## Building

You need CMake 3.20+ and a C11 compiler. SDL3 is used when installed;
otherwise CMake downloads and builds it (release-3.2.24).

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
```

```bash
cmake --build build
```

```bash
./build/multiversal_van_life
```

The build copies `game/` next to the executable; edit the files there or in
the repository and rebuild. Command line options: `--data DIR`, `--mods DIR`,
`--save DIR`, `--width W --height H`, `--fullscreen`, `--touch`, `--mute`,
`--benchmark travel` (a scripted trip on a fresh save, for measuring).

The headless runner (`mvl_headless`) is also a tool: `--bible ADDRESS --out
FILE` writes the world bible of a place, `--stats SEEDS --thresholds FILE`
prints variety statistics and `--budget SEEDS --budgets FILE` generation
times (see [docs/WORLDGEN.md](docs/WORLDGEN.md#variety-budgets-and-save-size)).

### Web (and WebXR)

With the [Emscripten SDK](https://emscripten.org) active:

```bash
emcmake cmake -S . -B build-web -DCMAKE_BUILD_TYPE=Release
```

```bash
cmake --build build-web
```

```bash
python3 -m http.server -d build-web 8000
```

Open `http://localhost:8000/multiversal_van_life.html`. Every push to `main`
also publishes the web build to GitHub Pages:
<https://makesgamessteve-hash.github.io/MultiversalVanLife/>. Phones and tablets get
touch controls automatically. In a WebXR-capable browser with a headset, an
**Enter VR** button appears (also available in the pause menu). WebXR needs
HTTPS or `localhost`.

## Controls

| | Keyboard / mouse | Gamepad | Touch | VR |
|---|---|---|---|---|
| Move | W A S D / arrows | left stick | left stick (drag) | left thumbstick |
| Look | mouse (click to capture) | right stick | drag on the right | head / right thumbstick turns |
| Use / talk / confirm | E, Space, Enter, left click | A | USE | right trigger |
| Back | Backspace | B | X | right grip |
| Pause | Esc, Tab | Start | II | left menu button |
| Run | Shift | X | | |
| Put down a carried item | Q | Y | | |
| Codex | C (left/right: tabs and buttons) | Back / Select (d-pad) | pause menu, then tap | pause menu |
| Drive (at the wheel) | W/S speed and reverse, A/D steer, Shift faster, E view, Backspace get up | left stick, X faster, A view, B get up | stick, USE view, X get up | thumbstick, trigger view, grip get up |
| Menus | arrows, E | d-pad, A | tap an item | thumbstick, trigger |

Bindings live in `game/config/input.ini`.

## Tests

```bash
cmake -S . -B build-cov -G Ninja -DMVL_BUILD_GAME=OFF -DMVL_COVERAGE=ON
```

```bash
cmake --build build-cov
```

```bash
ctest --test-dir build-cov --output-on-failure
```

```bash
cmake --build build-cov --target coverage
```

- **Unit tests** (`tests/unit`) cover the engine core.
- **Automated game tests** (`tests/game/test_*.lua`) play the real game through
  the headless runner: the intro, every kind of quest and its choices, the
  night cycle, save/continue, generation of every level, history and its
  traces, what people remember and what comes of the player's deeds, the
  codex, touch controls, the pause menu with a simulated VR session, and
  mods with their own troubles, generation passes, sayings and consequences.
- **Guards** against monotony, slowness and save bloat: variety statistics
  over 200 seeds, per-level generation time budgets and a 200-land save stress
  test (`tools.*` and `stress.save` in ctest).
- **Coverage gate**: the `coverage` target fails below 95% line coverage of
  `engine/src/core` (currently about 99%).
- With `-DMVL_GL_TESTS=ON` the game tests also run through the real OpenGL
  game (use `xvfb-run` on a headless Linux machine).
- `node tests/web/smoke.mjs build-web` checks the web build in headless
  Chromium as a desktop browser and as a phone (the codex by tapping), and
  measures the frame rate while the van travels.

CI (`.github/workflows/ci.yml`) runs all of this on Linux, Windows, macOS and
the web, and validates the OpenSpec specs.

## Dialogue, sound and music

Dialogue is text only: fixed lines live in `game/dialogue/lines.txt` and
generated characters speak through scripts. The sound effects, ambience loops
(`game/sounds/*.wav`) and the title music (`game/music/title.mp3`) were
generated once with ElevenLabs and are shipped as normal assets; the game
itself never talks to ElevenLabs and never needs an API key. To regenerate or
add sounds, see [tools/audiogen/README.md](tools/audiogen/README.md).

## Specifications

The behaviour of every part of the game is specified with
[OpenSpec](https://github.com/Fission-AI/OpenSpec) in `openspec/specs/`.
Propose changes with `openspec` (the Claude Code skills are in `.claude/skills`)
and validate with `openspec validate --specs --strict`.

## Licenses

- **Code** (engine, scripts, shaders, tools, tests): [MIT](LICENSE).
- **Art, sound and dialogue text** (`game/textures`, `game/models`,
  `game/voxels`, `game/sounds`, `game/music`, `game/dialogue`): [CC BY 4.0](LICENSE-ART.md).
- Lua 5.4: MIT, see `third_party/lua/LICENSE`. dr_mp3: public domain or MIT-0,
  see `third_party/dr_libs/LICENSE`. SDL3: zlib license.

See [CREDITS.md](CREDITS.md).
