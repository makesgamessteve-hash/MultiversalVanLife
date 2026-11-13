# Spec Delta

## MODIFIED Requirements

### Requirement: Supported asset formats
The engine SHALL load TGA images (uncompressed and RLE; 8, 24 or 32 bit), PCM WAV sounds (8 or 16 bit, mono or stereo), MP3 sounds (mono or stereo), Wavefront OBJ meshes and MagicaVoxel `.vox` models.

#### Scenario: Voxel model
- **WHEN** a `.vox` file is loaded with a voxel size
- **THEN** the engine builds a mesh with hidden faces removed, converts Z-up to Y-up, centres it on X/Z and puts its base at y = 0

#### Scenario: MP3 music
- **WHEN** a script loads `music/title.mp3`
- **THEN** it is decoded to the same sound format as WAV files and can be played and looped
