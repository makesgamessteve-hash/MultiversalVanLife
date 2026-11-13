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

### Requirement: Text-only dialogue lines
Fixed dialogue (Juniper's lines and narration) SHALL be defined in `game/dialogue/lines.txt` as `id | speaker | text`, where only the first two `|` separate fields; scripts SHALL also be able to show generated lines with a speaker and text. All dialogue SHALL be shown as text only.

#### Scenario: Typing text
- **WHEN** a line of a non-narrator speaker is shown
- **THEN** its text types out with a soft blip and no recorded voice plays

#### Scenario: Missing line id
- **WHEN** a script shows a line id that is not in `lines.txt`
- **THEN** the id itself is shown in brackets instead of failing

### Requirement: ElevenLabs sound and music generation tool
`tools/audiogen` SHALL generate the game's sound effects, ambience loops and music once with ElevenLabs from a manifest of prompts, reading the API key only from `ELEVENLABS_API_KEY`, skipping existing files unless forced; the results SHALL be committed as game assets.

#### Scenario: Missing key
- **WHEN** the tool runs without `ELEVENLABS_API_KEY`
- **THEN** it exits with an error explaining how to create a key and sends no request

#### Scenario: Looping ambience
- **WHEN** an ambience entry is generated
- **THEN** it is requested as a seamless loop and plays in the game without an audible seam

#### Scenario: Music on a free plan
- **WHEN** music generation is refused because the account's plan does not include it
- **THEN** the tool reports which tracks were skipped and keeps the existing music files

### Requirement: Soundscapes
Each world or biome SHALL name its ambience loop, and the van interior, the title screen and travelling SHALL each have their own sound.

#### Scenario: Entering the van
- **WHEN** the player steps into the van
- **THEN** the world ambience fades out and the van hum fades in
