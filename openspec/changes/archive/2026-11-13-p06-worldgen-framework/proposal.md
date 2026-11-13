# Proposal

Phase 6 of 24 of the procedural multiverse roadmap (see `docs/ROADMAP.md`). Depends on: p05.

## Why

The cosmos will be generated across nine levels by many generators added over later phases. They need one shared framework that guarantees laziness, determinism, order independence, consistency between levels and explainable results, before any real content generator is written.

## What Changes

- Addresses (`u.g.c.s.p.k.n.l`) and seeds derived per level and per generation pass.
- A pass registry per level (extensible by mods) and a coroutine runner with frame budgets and per-level caps.
- A fact store with stable ids and causal (`because`) links.
- Commitments from parents to children and the lowest-common-ancestor rule for shared things.
- Generator version and active mods recorded per generated node.
- A consistency checker framework and a world-bible Markdown exporter.
- Test levels (a dummy hierarchy) exercising the framework; no player-visible change yet.

## Capabilities

### New Capabilities
- `multiverse-generation`: The generation hierarchy contract: addresses, lazy and order-independent generation, commitments, shared entities, causal links, budgets and versioning.

### Modified Capabilities
- `quality-and-testing`: Determinism tests, the consistency checker and the world-bible export.

## Impact

- New `game/scripts/gen/` (address, registry, run, facts, commit, check, bible), headless runner option `--bible <address>`, game tests.
