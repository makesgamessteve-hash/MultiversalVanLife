# Proposal

## Why

The game currently has three handmade destinations, so every journey is the same and the "multiverse" ends after three nights. The van's interior is a separate room you load into, so you cannot see where you are parked. Flat decals such as water and roads flicker against the ground, and the dialogue relies on pre-generated voice clips that cannot follow generated content.

## What Changes

- **BREAKING** Remove the handmade destinations (Lanternfen, Clockwork Bazaar, Tidewater Library) and their fixed quests.
- Add an endless, seeded multiverse: every save game gets a seed; the van console offers newly generated destinations every night without limit, and a revisited destination is the same as before.
- Generate every world lazily: terrain, plants, props, settlements and people are generated in chunks around the player as they move, and dropped again when far away.
- Generate the home farm, the neighbour and the destinations from the save seed, using data-driven biome templates that mods can extend.
- Generate quests from templates (relight lights, gather parts, return items, find a lost person) with generated characters, names and dialogue text.
- Put the van interior into the same scene as the world and give it windows that are portals showing the outside where the van is parked, or the travel vortex while travelling.
- Render flat decals (water, roads, paths) on top of the ground without z-fighting, and add hilly terrain.
- **BREAKING** Dialogue becomes text-only: remove the voice clips and the voice generation tool. A soft blip still plays while text types out.
- Replace the procedural sound effects, ambience and music with sounds generated once with ElevenLabs, committed as assets, through a new sound and music generation tool. Add MP3 support so music stays small.

## Capabilities

### New Capabilities
- `multiverse-generation`: Seeded, endless generation of destinations and lazily streamed world chunks (terrain, flora, props, settlements), with data-driven biomes.
- `generated-quests`: Quest templates, generated characters, names and dialogue text, and quest completion rules.
- `van-windows`: The van interior shares the world scene and its windows show the outside through portals.

### Modified Capabilities
- `story-and-worlds`: The farm is generated, the console lists generated destinations, entering and leaving the van no longer loads a separate world, and the fixed destinations are removed.
- `rendering`: Adds terrain, decals without z-fighting and portal rendering.
- `audio-and-voice`: Dialogue becomes text-only, voice clips and the voice tool are removed, and an ElevenLabs sound effect and music tool is added.
- `data-and-mods`: Mods add biomes and quest templates instead of fixed destinations, and MP3 becomes a supported sound format.
- `scripting-api`: Scripts get deterministic noise, terrain and portal functions and can release meshes.
- `save-games`: The save stores the multiverse seed and visited destinations.
- `quality-and-testing`: Game tests cover generated quests, streaming and determinism instead of the fixed worlds.

## Impact

- Engine core: new noise/terrain module, decal and portal data in the scene, releasable mesh slots, MP3 decoding (vendored public-domain decoder), new Lua API functions, unit tests.
- Renderer: stencil buffer, decal pass with polygon offset, portal passes, terrain vertex colours.
- Game scripts: new `gen/` modules (random, names, biomes, chunks, settlements, quests), rewritten `story.lua`, `home.lua` and `van.lua`, removal of `fen.lua`, `market.lua`, `library.lua`.
- Assets: `van_interior.vox` with window openings, ElevenLabs sounds and music in `game/sounds` and `game/music`, removal of `game/voice/*.wav`.
- Tools: `tools/voicegen` replaced by `tools/audiogen`; ElevenLabs music needs a paid plan.
- Tests and docs: game tests rewritten, README, modding guide and specs updated.
