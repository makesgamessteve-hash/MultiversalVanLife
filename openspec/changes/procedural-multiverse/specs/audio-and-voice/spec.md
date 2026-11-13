# Spec Delta

## ADDED Requirements

### Requirement: Text-only dialogue lines
Fixed dialogue (Juniper's lines and narration) SHALL be defined in `game/dialogue/lines.txt` as `id | speaker | text`, where only the first two `|` separate fields; generated characters' lines are assembled from templates. All dialogue SHALL be shown as text only.

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

### Requirement: Biome soundscapes
Each biome SHALL name its ambience loop, and the van interior, the title screen and travelling SHALL each have their own sound.

#### Scenario: Entering the van
- **WHEN** the player steps into the van
- **THEN** the world ambience fades out and the van hum fades in

## REMOVED Requirements

### Requirement: Dialogue lines as data
**Reason**: Replaced by "Text-only dialogue lines": the voice clips are removed and the file moves to `game/dialogue/lines.txt`.
**Migration**: Move custom `voice/lines.txt` files to `dialogue/lines.txt`; recorded voice clips are no longer played automatically.

### Requirement: ElevenLabs voice generation tool
**Reason**: Dialogue is text-only; generated characters cannot be pre-voiced.
**Migration**: Use `tools/audiogen` for sound effects and music. Mods can still play their own sounds with `mvl.play`.
