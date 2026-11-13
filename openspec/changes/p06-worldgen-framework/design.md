# Design

## Context

No generation exists yet. Scripts are Lua 5.4 in a sandbox; phase 1 provides hashing, random streams and noise; phase 5 provides records.

## Goals / Non-Goals

**Goals:** a small, strict framework every generator plugs into; guarantees tested once.
**Non-Goals:** real content (later phases).

## Decisions

- **Seeds**: `seed(node) = hash(seed(parent), level, index)`; each pass gets `hash(seed(node), pass_name)` as its random stream, so adding a pass never reshuffles others. Seeds never depend on other nodes' contents → order independence.
- **Passes**: `registry.pass(level, name, {after = {...}, run = fn})`; passes run in dependency order; each reads the parent node, earlier passes and its commitments, and writes its own fields. Mods register passes and content tables the same way.
- **Skeleton vs detail**: a parent creates child skeletons (cheap summaries); detail generation runs all passes only on the requested path.
- **Commitments**: `commit(child_address, kind, data, because)` stored in the parent; children's passes call `commitments(kind)` and must consume them; unconsumed commitments are a checker error.
- **Facts**: tables with ids `<address>/<kind>/<n>` and a `because` list; shared entities are stored at the lowest common ancestor and referenced by id.
- **Runner**: generation runs in a coroutine; passes call `gen.yield()` between work units; the runner resumes it until the frame budget (default 6 ms) is spent. Caps per level are enforced by the registry.
- **Version**: `GEN_VERSION` plus the sorted mod list are stored in each node.
- **Bible**: `mvl_headless --bible <address> --out file.md` generates the path and writes every node's facts with causes.
- **Test levels**: a dummy three-level hierarchy registered only in tests exercises seeds, laziness, order independence, commitments, caps and budgets.

## Risks / Trade-offs

- [Coroutine overhead] → yields only between work units, not per fact.
