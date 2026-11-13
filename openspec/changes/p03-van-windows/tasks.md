# Tasks

## 1. Assets

- [ ] 1.1 Add window openings to `van_interior.vox` in `tools/gen_assets.py`; verify `gen_assets.py --check` passes and the openings exist

## 2. Interior pocket

- [ ] 2.1 Spawn the interior as a persistent pocket in every world, make doors teleport and swap bounds and ambience; verify game tests for entering and leaving without a world reload
- [ ] 2.2 Keep the interior while travelling and rebuild only the outside world; verify the night-cycle and quest game tests still pass

## 3. Windows

- [ ] 3.1 Define window portals to the exterior van windows and update them when the van moves; verify a game test of portal targets and a GL screenshot showing the outside through a window
- [ ] 3.2 Add the vortex tunnel and switch portals to it during travel; verify a game test of portal targets before, during and after travel
