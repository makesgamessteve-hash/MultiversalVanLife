# Proposal

Phase 30 of 33 of the roadmap (see `docs/ROADMAP.md` and `docs/concepts/living-planets.md`). Depends on: p29.

## Why

With a network and affordable density, each settlement needs a real layout: streets, lots, squares and the buildings of its people and trade.

## What Changes

- Plan forms by culture and site: planned grids, organic lanes, rings around a hall, burrow clusters, towers for flyers, stilts and canals, nomad camps.
- Streets from the roads entering the settlement, a centre (square, market, temple close), blocks cut into lots sized to the buildings.
- More building kinds: row houses, shops, workshops by technology, inns and taverns, granaries, barns, stables, water mills and windmills, schools, halls, palaces, towers, walls and gates, bridges, docks, warehouses, wells and fountains; wear and ruin from the place's condition.
- Fields with crop rows, hedges and fences, orchards, gardens and village trees; denser woods and undergrowth in the wild.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `settlements`: See the requirements of this change.
- `procedural-visuals`: See the requirements of this change.

## Impact

- New `gen/settle/layout.lua`, `gen/settle/lots.lua`, `gen/visuals/buildings.lua` (kinds), `gen/levels/land.lua`, `gen/chunks.lua`, tests.
