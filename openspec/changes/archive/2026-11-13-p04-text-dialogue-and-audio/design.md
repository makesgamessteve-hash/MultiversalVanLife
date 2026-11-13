# Design

## Context

Dialogue shows lines from `game/voice/lines.txt` and plays `voice/<id>.wav`. Sounds are procedural from `tools/gen_assets.py`. The engine decodes only WAV.

## Goals / Non-Goals

**Goals:** text-only dialogue that also takes generated lines; small, good-sounding audio from ElevenLabs.
**Non-Goals:** streaming audio from ElevenLabs at runtime.

## Decisions

- **Dialogue**: `dialogue.say` accepts ids or `{speaker = name, color = …, text = …}`; voice code is removed, the blip stays.
- **MP3**: vendored `dr_mp3` (public domain / MIT-0) in `third_party/`, decoded to 16-bit mono at load; excluded from coverage.
- **Formats**: sound effects and ambience loops use `eleven_text_to_sound_v3` with `pcm_22050` output wrapped as WAV (loops stay sample-exact; MP3 encoder padding would cause seams); ambience uses `loop: true`. Music uses `music_v2_5`, instrumental, MP3.
- **Manifest**: `tools/audiogen/manifest.json` with id, kind (sfx, loop, music), prompt, duration and output path; the tool skips existing files unless `--force` and reports plan errors per entry. Node runs with `NODE_USE_ENV_PROXY=1` behind proxies.
- **Looping music**: played by the script with a short crossfade between repeats.

## Risks / Trade-offs

- [Music needs a paid plan] → skipped entries keep the current procedural music.
- [Asset size for the web] → loops ≤ 20 s mono 22 kHz; music as MP3.
