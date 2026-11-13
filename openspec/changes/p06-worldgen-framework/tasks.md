# Tasks

## 1. Core framework

- [ ] 1.1 Add `gen/address.lua` and seed derivation per level and pass; verify game tests for stable seeds and pass isolation
- [ ] 1.2 Add `gen/registry.lua` (levels, passes with ordering, content tables, caps, mod registration); verify game tests with the dummy hierarchy
- [ ] 1.3 Add `gen/run.lua` (coroutine runner with frame budgets, skeleton vs detail, lazy path generation, in-memory cache); verify game tests for laziness (only path nodes in detail) and budget yielding
- [ ] 1.4 Add `gen/facts.lua` (ids, `because` links, shared entities at the common ancestor) and `gen/commit.lua`; verify game tests for causal queries and committed facts
- [ ] 1.5 Record generator version and mods per node; verify a game test

## 2. Tools and checks

- [ ] 2.1 Add the consistency checker framework (commitments, references, chronology, registered checks); verify a test that a deliberately broken commitment fails
- [ ] 2.2 Add the world bible exporter and `--bible` option; verify a test exports a dummy address
- [ ] 2.3 Add the fingerprint test (hash of generated reference nodes compared with a stored value) to CI on all platforms; verify CI passes
- [ ] 2.4 Write `docs/WORLDGEN.md` describing addresses, passes, commitments, facts and budgets; verify its example pass runs in a game test
