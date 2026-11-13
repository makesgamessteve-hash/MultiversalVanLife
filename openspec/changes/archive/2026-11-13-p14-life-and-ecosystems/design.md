# Design

## Context

Phase 12 provides biomes and climate per cell; phase 13 palettes.

## Goals / Non-Goals

**Goals:** coherent, varied life as data; species ready for culture passes.
**Non-Goals:** voxel visuals and behaviour (phase 15), evolution simulation over time.

## Decisions

- **Biochemistry**: chosen from planet temperature and solvent availability (carbon/water, ammonia, silicon at extremes) and universe laws (magical life where magic is strong).
- **Lineages**: 4–8 body plans as trait vectors (symmetry, segments, limb count, covering, locomotion modes, sense organs, size range, sessile vs mobile).
- **Radiation**: per biome, species are sampled from lineages and adapted by environmental pressure functions (gravity → build, air density → flight, temperature → covering, light → pigments, magic → traits); roles assigned with population ratios (e.g. 10 producers : 3 grazers : 1 predator).
- **Sapients**: 0–2 per living planet unless committed; physiology traits derived from their lineage; stored at the planet (or at the common ancestor for spacefarers).
- **Names**: a scientific-sounding lexicon for now; replaced by the observing culture's language in phase 16 when available.
- **Population**: chunks sample species by biome density with Poisson disc; fallback visuals use existing sprites tinted by species colours.

## Risks / Trade-offs

- [Implausible food webs] → checker rule: every predator has prey in its biome.
