# audio-and-voice Specification

## Purpose
A small software mixer plays sound effects, looping ambience and voice lines. Dialogue text lives in a data file and can be voiced with pre-generated ElevenLabs audio.

## Requirements
### Requirement: Software mixer
The mixer SHALL mix up to 32 mono voices into stereo with linear resampling, panning, looping, three volume groups (sfx, ambience, voice) and timed fades, replacing the quietest non-looping voice when full.

#### Scenario: Fade out and stop
- **WHEN** a voice is faded to 0 with `stop` set
- **THEN** it stops once the fade completes

### Requirement: Main-thread audio pump
The platform layer SHALL keep about 100 ms of mixed audio queued on an SDL audio stream from the main loop so no locking is needed.

#### Scenario: Muted run
- **WHEN** the game is started with `--mute`
- **THEN** no audio device is opened and the game still runs

### Requirement: Dialogue lines as data
All dialogue SHALL be defined in `game/voice/lines.txt` as `id | speaker | text`, where only the first two `|` separate fields.

#### Scenario: Voiced line
- **WHEN** a line with id X is shown and `voice/X.wav` exists
- **THEN** the clip plays on the voice group

#### Scenario: Shipped voice clips
- **WHEN** the game is built
- **THEN** every non-narrator line in `lines.txt` has a voice clip in `game/voice/`, generated once with ElevenLabs and committed as an asset

#### Scenario: Unvoiced line
- **WHEN** no clip exists for a non-narrator line
- **THEN** a soft blip plays while the text types out

### Requirement: ElevenLabs voice generation tool
`tools/voicegen` SHALL generate `game/voice/<id>.wav` files with ElevenLabs text to speech using the speaker voices in `voices.json`, reading the API key only from the `ELEVENLABS_API_KEY` environment variable, skipping narrator lines and existing files unless forced.

#### Scenario: Missing key
- **WHEN** the tool runs without `ELEVENLABS_API_KEY`
- **THEN** it exits with an error explaining how to create a key and sends no request

#### Scenario: Output format
- **WHEN** audio is generated
- **THEN** it is requested as raw 16-bit PCM and written as a WAV file the engine can decode
