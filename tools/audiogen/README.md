# Sound and music generator (ElevenLabs)

Generates the game's sound effects, ambience loops and music with
[ElevenLabs](https://elevenlabs.io) from the prompts in `manifest.json`. The
results are committed in `game/sounds/` and `game/music/`, so this only needs
to run again after adding or changing an entry. The game itself never talks to
ElevenLabs and never needs a key.

## Setup

1. Create an API key at <https://elevenlabs.io/app/api/api-keys>.
2. Make it available as the `ELEVENLABS_API_KEY` environment variable (for
   example in your shell profile or a git-ignored `.env.local`). Never commit
   it.
3. Install the dependencies (Node 18 or newer):

```bash
cd tools/audiogen
```

```bash
npm install
```

## Use

```bash
node generate.mjs --help
```

```bash
npm run plan
```

```bash
npm run generate
```

`plan` lists what would be generated without calling the API; `generate`
creates every entry whose file is missing. Options (after `--` with npm):

- `--only step,door` generates just these ids.
- `--force` regenerates files that already exist.
- `--out DIR` writes into another game folder.

Behind an HTTPS proxy run it with `NODE_USE_ENV_PROXY=1` (Node 22.21+) so
Node's fetch uses the proxy.

## Manifest

Each entry has an `id`, a `kind`, a `prompt`, a `duration` in seconds and an
`out` path relative to `game/`:

| Kind | Model | Output |
|---|---|---|
| `sfx` | `eleven_text_to_sound_v3` | One-shot WAV: leading and trailing silence trimmed, short fades |
| `loop` | `eleven_text_to_sound_v3` with `loop` | Seamless WAV loop: its last 60 ms are crossfaded into its start |
| `music` | `music_v2_5`, instrumental | MP3 (44.1 kHz, 128 kbit/s) |

Sound effects arrive as 22.05 kHz stereo PCM. They are mixed down to mono (the
engine mixes in mono), normalised to -3 dBFS and wrapped in a WAV header. A
clip that comes back silent fails with a message so you can change its
prompt. The optional `influence` (0..1) sets how literally a prompt is followed.

Music needs a paid ElevenLabs plan. On a plan without music the tool reports
the skipped tracks and keeps the existing files.

## Tests

```bash
npm test
```

The tests cover manifest validation, request building, plan-error detection
and the audio processing; they make no API calls. The game test
`tests/game/test_audio_assets.lua` checks that every manifest entry is shipped
and loads.
