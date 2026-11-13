# Procedural multiverse roadmap

The procedural multiverse is built in 24 small phases. Each phase is a separate
OpenSpec change in `openspec/changes/`, implemented, tested and archived on its own,
so the main specs in `openspec/specs/` always describe the game as shipped.

Rules for every phase:

- Phases are applied in order; each depends on the previous one.
- Each phase ends with a playable game, all unit, game, OpenGL and web tests passing
  and at least 95% line coverage of the engine core.
- A phase is archived (`openspec archive <change>`) before the next one starts.

| Phase | Change | Tasks | Specs touched | Status |
|---|---|---|---|---|
| 1 | `p01-procedural-engine-core` | 8 | scripting-api | done |
| 2 | `p02-decals-portals-culling` | 8 | rendering, scripting-api | done |
| 3 | `p03-van-windows` | 5 | story-and-worlds, van-windows | done |
| 4 | `p04-text-dialogue-and-audio` | 6 | audio-and-voice, data-and-mods | done |
| 5 | `p05-save-records` | 5 | save-games, scripting-api | done |
| 6 | `p06-worldgen-framework` | 9 | multiverse-generation, quality-and-testing | planned |
| 7 | `p07-cosmos-and-prime` | 7 | multiverse-generation, prime-universe | planned |
| 8 | `p08-land-streaming-and-farm` | 5 | land-streaming, prime-universe, rendering, story-and-worlds | planned |
| 9 | `p09-signals-and-generated-lands` | 7 | data-and-mods, generated-quests, land-streaming, quality-and-testing, signals-and-codex, story-and-worlds | planned |
| 10 | `p10-world-memory-basics` | 4 | quality-and-testing, world-memory | planned |
| 11 | `p11-planet-geology` | 6 | planet-generation, scripting-api | planned |
| 12 | `p12-planet-climate-and-lands` | 6 | land-streaming, planet-generation, scripting-api | planned |
| 13 | `p13-planet-skies-and-palettes` | 4 | planet-generation, prime-universe, procedural-visuals | planned |
| 14 | `p14-life-and-ecosystems` | 5 | land-streaming, life-generation | planned |
| 15 | `p15-voxel-flora-and-fauna` | 6 | life-generation, procedural-visuals | planned |
| 16 | `p16-languages-and-religions` | 6 | culture-generation | planned |
| 17 | `p17-traditions-society-technology` | 5 | culture-generation | planned |
| 18 | `p18-architecture-and-people` | 5 | culture-generation, procedural-visuals | planned |
| 19 | `p19-history-engine` | 7 | history-generation, prime-universe | planned |
| 20 | `p20-history-refinement-and-tensions` | 6 | history-generation, land-streaming | planned |
| 21 | `p21-tension-quests-and-dialogue` | 6 | generated-quests, world-memory | planned |
| 22 | `p22-consequences-and-revisits` | 5 | signals-and-codex, world-memory | planned |
| 23 | `p23-codex` | 4 | signals-and-codex, world-memory | planned |
| 24 | `p24-worldgen-hardening` | 6 | quality-and-testing, save-games | planned |

## Milestones

- **After phase 4**: the current game with van windows, flicker-free decals, text-only dialogue and ElevenLabs sound and music.
- **After phase 9**: the handmade worlds are gone; Juniper's signals lead to generated lands across a generated cosmos.
- **After phase 10**: visited places and everything the player does there are remembered.
- **After phase 15**: planets with real geography, skies and living, moving wildlife.
- **After phase 18**: peoples with languages, religions, traditions, technology, buildings and dress.
- **After phase 20**: history on every level, ruins and legends, troubles grounded in history.
- **After phase 23**: quests from real tensions with lasting consequences, revisits and the codex.
- **Phase 24**: hardening and release.
