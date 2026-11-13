# Tasks

## 1. Text-only dialogue

- [ ] 1.1 Move fixed lines to `game/dialogue/lines.txt`, support generated `{speaker, text}` lines, remove voice playback, `game/voice/*.wav` and `tools/voicegen`; verify a game test that dialogue types text with blips and no voice-group sound

## 2. MP3

- [ ] 2.1 Vendor `dr_mp3` with its license and decode `.mp3` in the sound loader; verify a unit test that decodes a small committed fixture

## 3. Audio generation

- [ ] 3.1 Add `tools/audiogen` (manifest, sound effects, loops, music, skip-on-plan-error) with node tests and a CI step; verify `npm test` passes in CI
- [ ] 3.2 Generate all manifest entries once with ElevenLabs and commit them; verify a game test that every manifest entry loads
- [ ] 3.3 Wire soundscapes for worlds, van interior, title and travel with crossfades; verify a game test that entering the van fades the world ambience out and the van hum in
- [ ] 3.4 Update README, CREDITS (ElevenLabs audio, dr_mp3) and `tools/audiogen/README.md`; verify the documented command runs with `--help`
