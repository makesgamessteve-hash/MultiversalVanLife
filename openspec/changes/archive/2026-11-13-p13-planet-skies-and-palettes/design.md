# Design

## Context

The sky shader draws a gradient and a scrolling star texture. Textures are hand-made TGAs tinted per world. Phase 1 provides texture generation.

## Goals / Non-Goals

**Goals:** skies and materials that reflect generated data, in the retro style.
**Non-Goals:** volumetric clouds, real-time day/night lighting changes beyond the existing environment.

## Decisions

- **Sky data**: star direction from local time; moons as up to 4 sprite discs with phase computed in the shader from sun direction; planets as bright points; galaxy band as a great circle oriented by the planet's position in its galaxy, textured with noise. Uniform arrays carry them.
- **Atmosphere**: colour from star temperature and atmosphere density (thin → dark sky, thick → hazy, fog closer).
- **Palettes**: foliage hue chosen to absorb the star's peak (red dwarf → dark/purple, blue-white → yellow/red), bedrock colours from rock types, soil from climate; recipes feed `texgen` and terrain vertex colours.
- **Prime**: the farm uses real values (Moon phase from the in-game date).

## Risks / Trade-offs

- [Shader cost on phones] → moon and planet counts capped; the band is a single texture lookup.
