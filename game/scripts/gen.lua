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
    { "planet", "p", caps = { children = 64, facts = 2048 } },
    { "continent", "k", caps = { children = 64, facts = 1024 } },
    { "country", "n", caps = { children = 256, facts = 1024 } },
    { "land", "l", caps = { children = 0, facts = 1024 } },
  },
})

-- The levels of this phase: multiverse down to star systems.
require("gen.levels.multiverse")(gen.cosmos)
require("gen.levels.universe")(gen.cosmos)
require("gen.levels.galaxy").register(gen.cosmos)
require("gen.levels.cluster").register(gen.cosmos)
require("gen.levels.system").register(gen.cosmos)
gen.provisional = require("gen.levels.provisional")
gen.provisional.register(gen.cosmos)
gen.planet = require("gen.levels.planet")
gen.planet.register(gen.cosmos)
gen.quests = require("gen.quests")
gen.quests.register(gen.cosmos)
gen.geography = require("gen.levels.geography")
gen.geography.register(gen.cosmos)
gen.sky = require("gen.visuals.sky")
gen.sky.register(gen.cosmos)
gen.land = require("gen.levels.land")
gen.land.register(gen.cosmos)
gen.signals = require("gen.signals")

-- Inside Prime nothing is generated below the planets except the farm and
-- the countryside around it; elsewhere places exist up to their parent's cap.
gen.prime = require("gen.prime")
for _, level in ipairs({ "continent", "country", "land" }) do
  gen.cosmos:skeleton(level, function(parent, index)
    local addr = gen.address.child(gen.cosmos.scheme, parent.address, index)
    if gen.prime.inside(addr) and not gen.prime.allowed(addr) then return nil end
    if parent.listed_children then return nil end -- the parent named its children
    return index < gen.cosmos.levels[parent.level].caps.children and {} or nil
  end)
end

-- Lore (eras, history, factions, religions, species, cultures, events) of a
-- place and its ancestors. Prime has none: Earth is never simulated.
gen.LORE = { era = true, history = true, event = true, faction = true, religion = true, species = true,
             culture = true, war = true, notable_galaxy = true }
function gen.lore(G, addr, kind)
  if gen.prime.inside(addr) then return gen.prime.lore() end
  local out = {}
  G:generate(addr)
  for _, a in ipairs(gen.address.path(addr)) do
    local node = G.nodes[a]
    for _, id in ipairs(node.fact_order) do
      local f = node.facts[id]
      if (kind and f.kind == kind) or (not kind and gen.LORE[f.kind]) then out[#out + 1] = f end
    end
  end
  return out
end

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

-- The land at grid (gx, gz) of the country containing land `addr`, or nil
-- where there is none (outside the country, or not allowed in Prime).
function gen.neighbour_land(G, addr, gx, gz)
  local index = gen.land.index(gx, gz)
  if not index then return nil end
  local target = gen.address.parent(addr) .. ".l" .. index
  local ok, node = pcall(G.generate, G, target)
  return ok and node or nil
end

return gen
