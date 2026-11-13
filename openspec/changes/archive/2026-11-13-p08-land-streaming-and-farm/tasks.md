# Tasks

## 1. Streaming

- [x] 1.1 Add `gen/chunks.lua` (load/unload radii, one per tick, feature spawning, mesh release); verify a game test walking 500 m keeps entity and mesh counts bounded
- [x] 1.2 Place the player and objects on the terrain surface and flatten under features; verify a game test that the player height follows the ground across chunk borders
- [x] 1.3 Generate neighbouring lands on approach with seamless terrain; verify a game test crossing a land border

## 2. Farm

- [x] 2.1 Generate the farm land from the save seed and replace the hand-made home; verify the two-journeys game test and the intro game test
- [x] 2.2 Verify chunk seams in a GL screenshot test and update `docs/WORLDGEN.md` with lands and chunks
