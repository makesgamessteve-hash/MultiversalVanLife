# Tasks

## 1. Kernels

- [ ] 1.1 Add the geodesic grid and plate kernels (seeding, growth, motion, boundaries, elevation) in `planet.c` with Lua bindings; verify unit tests for cell counts, neighbour symmetry, determinism and mountains on convergent boundaries

## 2. Planet passes

- [ ] 2.1 Add the planet physics pass; verify the red-dwarf test and plausibility checks over 200 seeds
- [ ] 2.2 Add the tectonics and elevation pass; verify the collision-mountains game test
- [ ] 2.3 Add geology and resources; verify the ore-distribution test
- [ ] 2.4 Add magic geography per universe source; verify the tectonic-magic test
- [ ] 2.5 Add planet bible sections and checker rules; verify a bible export of a reference planet and the checker over 200 seeds
