# Voice line generator (ElevenLabs)

Turns the dialogue in `game/voice/lines.txt` into `game/voice/<id>.wav` files
with [ElevenLabs](https://elevenlabs.io) text to speech. The game plays a
line's WAV automatically when the line is shown; without one it plays a soft
blip. The game itself never talks to ElevenLabs and never needs a key.

## Setup

1. Create an API key at <https://elevenlabs.io/app/api/api-keys>.
2. Make it available as the `ELEVENLABS_API_KEY` environment variable (for
   example in your shell profile or a git-ignored `.env.local`). Never commit
   it.
3. Install the dependencies:

```bash
cd tools/voicegen
```

```bash
npm install
```

## Use

```bash
npm run generate
```

Generates every missing line (narrator lines are skipped). Options:

- `npm run generate -- --only van_intro_1,van_call_1` generates just these ids.
- `npm run generate -- --force` regenerates existing files.
- `npm run voices` lists the pre-made voices your account can use.

Each request uses ElevenLabs credits (one credit per character on most plans).
The full script is 34 voiced lines, about 2,600 characters.

## Voices

`voices.json` maps speakers to voices. Every speaker uses George by default,
because pre-made voices work on every plan. Give each character their own voice
by adding entries under `speakers`, for example:

```json
"mabel": { "voice_id": "<voice id>", "stability": 0.5, "similarity_boost": 0.75 }
```

The model is `eleven_v4`. Audio is requested as raw 22.05 kHz PCM
(`pcm_22050`) and wrapped into WAV files, which the engine loads directly.
Generated voice files fall under the asset license (CC BY 4.0), subject to your
ElevenLabs plan's terms for commercial use.

## Tests

```bash
npm test
```
