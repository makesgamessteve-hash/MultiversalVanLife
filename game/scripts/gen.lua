-- Multiversal Van Life - procedural generation of the multiverse (MIT).
--
-- The cosmos is a hierarchy of nine levels: multiverse, universe, galaxy,
-- star cluster, star system, planet, continent, country and land. Every
-- place is generated lazily, deterministically and independently of the
-- order of requests by the passes registered for its level. See
-- docs/WORLDGEN.md.
--
--   local gen = require("gen")
--   gen.cosmos:pass("galaxy", "shape", { run = function(ctx) ... end })
--   gen.start(seed)                  -- a runner for the current save
--   gen.world:request("u1.g2", function(node) ... end)
local gen = {
  address = require("gen.address"),
  registry = require("gen.registry"),
  run = require("gen.run"),
  facts = require("gen.facts"),
  check = require("gen.check"),
  bible = require("gen.bible"),
  util = require("gen.util"),
}
gen.VERSION = gen.run.VERSION

-- Caps per level keep frame time and memory bounded.
gen.cosmos = gen.registry.new({
  name = "cosmos",
  levels = {
    { "multiverse", "", caps = { facts = 512 } },
    { "universe", "u", caps = { facts = 2048 } },
    { "galaxy", "g", caps = { facts = 2048 } },
    { "cluster", "c", caps = { children = 4096, facts = 1024 } },
    { "system", "s", caps = { children = 64, facts = 1024 } },
    { "planet", "p", caps = { children = 32, facts = 2048 } },
    { "continent", "k", caps = { children = 64, facts = 1024 } },
    { "country", "n", caps = { children = 256, facts = 1024 } },
    { "land", "l", caps = { children = 0, facts = 1024 } },
  },
})

gen.world = nil

-- Starts the runner of the current save.
function gen.start(seed, opts)
  opts = opts or {}
  opts.seed = seed
  gen.world = gen.run.new(gen.cosmos, opts)
  return gen.world
end

-- Called every tick: generates within the frame budget.
function gen.update()
  if gen.world then gen.world:update() end
end

return gen
