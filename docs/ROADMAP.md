# Procedural multiverse roadmap

The procedural multiverse is built in small phases (1–25 done, 26–33 planned; Juniper's interior V1–V4 come
before 26). Each phase is a separate
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
| 6 | `p06-worldgen-framework` | 9 | multiverse-generation, quality-and-testing | done |
| 7 | `p07-cosmos-and-prime` | 7 | multiverse-generation, prime-universe | done |
| 8 | `p08-land-streaming-and-farm` | 5 | land-streaming, prime-universe, rendering, story-and-worlds | done |
| 9 | `p09-signals-and-generated-lands` | 7 | data-and-mods, generated-quests, land-streaming, quality-and-testing, signals-and-codex, story-and-worlds | done |
| 10 | `p10-world-memory-basics` | 4 | quality-and-testing, world-memory | done |
| 11 | `p11-planet-geology` | 6 | planet-generation, scripting-api | done |
| 12 | `p12-planet-climate-and-lands` | 6 | land-streaming, planet-generation, scripting-api | done |
| 13 | `p13-planet-skies-and-palettes` | 4 | planet-generation, prime-universe, procedural-visuals | done |
| 14 | `p14-life-and-ecosystems` | 5 | land-streaming, life-generation | done |
| 15 | `p15-voxel-flora-and-fauna` | 6 | life-generation, procedural-visuals | done |
| 16 | `p16-languages-and-religions` | 6 | culture-generation | done |
| 17 | `p17-traditions-society-technology` | 5 | culture-generation | done |
| 18 | `p18-architecture-and-people` | 5 | culture-generation, procedural-visuals | done |
| 19 | `p19-history-engine` | 7 | history-generation, prime-universe | done |
| 20 | `p20-history-refinement-and-tensions` | 6 | history-generation, land-streaming | done |
| 21 | `p21-tension-quests-and-dialogue` | 6 | generated-quests, world-memory | done |
| 22 | `p22-consequences-and-revisits` | 5 | signals-and-codex, world-memory | done |
| 23 | `p23-codex` | 4 | signals-and-codex, world-memory | done |
| 24 | `p24-worldgen-hardening` | 6 | quality-and-testing, save-games | done |
| 25 | `p25-human-scale-buildings` | 4 | procedural-visuals | done |
| 26 | `p26-planet-atlas` | 4 | planet-generation | planned |
| 27 | `p27-surface-grid-and-regions` | 5 | multiverse-generation, land-streaming, save-games | planned |
| 28 | `p28-settlement-network-and-roads` | 5 | settlements (new), history-generation | planned |
| 29 | `p29-streaming-batching-and-lod` | 5 | rendering, land-streaming, engine-core | planned |
| 30 | `p30-settlement-layouts` | 4 | settlements, procedural-visuals | planned |
| 31 | `p31-props-and-decoration` | 4 | settlements | planned |
| 32 | `p32-people-routines-and-animals` | 4 | settlements, life-generation | planned |
| 33 | `p33-road-hops-and-integration` | 5 | story-and-worlds, signals-and-codex, generated-quests, quality-and-testing | planned |

### Juniper's interior

The van's interior is rebuilt as a home without end before phase 26 (see the
[Juniper's interior](concepts/juniper-interior.md) concept). The same rules apply.

| Phase | Change | Tasks | Specs touched | Status |
|---|---|---|---|---|
| V1 | `v1-cosy-core` | 6 | van-interior (new), van-windows, story-and-worlds, scripting-api | done |
| V2 | `v2-endless-house` | 4 | van-interior | done |
| V3 | `v3-souvenir-wings` | 3 | van-interior | planned |
| V4 | `v4-garden-planet` | 4 | van-interior, scripting-api | planned |

## Milestones

- **After phase 4**: the current game with van windows, flicker-free decals, text-only dialogue and ElevenLabs sound and music.
- **After phase 9**: the handmade worlds are gone; Juniper's signals lead to generated lands across a generated cosmos.
- **After phase 10**: visited places and everything the player does there are remembered.
- **After phase 15**: planets with real geography, skies and living, moving wildlife.
- **After phase 18**: peoples with languages, religions, traditions, technology, buildings and dress.
- **After phase 20**: history on every level, ruins and legends, troubles grounded in history.
- **After phase 23**: quests from real tensions with lasting consequences, revisits and the codex.
- **Phase 24**: hardening and release: variety statistics over 200 seeds, generation time budgets, a 200-land save
  budget and the web travel frame check guard every push.

- **After phase 25**: buildings at human scale next to the player.
- **After V4**: Juniper is a cosy home with souvenir wings of the peoples visited, rooms without end and a garden the
  size of a small world.
- **After phase 29**: continuous travel across real-sized planets, every place part of a plan, towns affordable on every device.
- **After phase 33**: living planets: dense villages, towns and cities with their people, things and animals; road hops, a map, signals and quests from real places.

Phases 1–24 are done. Phases 25–33 follow the [living planets](concepts/living-planets.md) concept.
