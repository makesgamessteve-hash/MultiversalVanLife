# Proposal

Phase 4 of 24 of the procedural multiverse roadmap (see `docs/ROADMAP.md`). Depends on: p03.

## Why

Generated characters will say generated sentences, which pre-recorded voice clips cannot follow, so dialogue becomes text-only. Sound effects, ambience and music should instead come from ElevenLabs, generated once and shipped as assets.

## What Changes

- **BREAKING** Remove voice playback, the voice clips in `game/voice/` and `tools/voicegen`; fixed lines move to `game/dialogue/lines.txt`; dialogue also accepts generated lines.
- Add MP3 decoding (vendored public-domain `dr_mp3`).
- Add `tools/audiogen`: generates sound effects, ambience loops (WAV) and music (MP3) with ElevenLabs from a manifest.
- Generate the audio once and commit it; worlds, the van, travel and the title get their own soundscapes.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `audio-and-voice`: Text-only dialogue, ElevenLabs sound and music tool, soundscapes; voice tool and voice clips removed.
- `data-and-mods`: MP3 becomes a supported sound format.

## Impact

- `third_party/dr_libs`, `engine/src/core/sound.c`/`resources.c`, `game/scripts/lib/dialogue.lua`, `lines.lua`, `audio.lua`, `game/dialogue/`, `game/sounds/`, `game/music/`, `tools/audiogen`, CI job for the tool. ElevenLabs music needs a paid plan.
