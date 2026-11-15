-- Multiversal Van Life - procedural generation of the multiverse (MIT).
--
-- The cosmos is a hierarchy of levels: multiverse, universe, galaxy, star
-- cluster, star system and planet; below a planet its continents and
-- countries (politics, culture, history) and the regions of its surface
-- grid, and the lands of a region (or, in multiverses from before the grid,
-- of a country's district). Every place is generated lazily,
-- deterministically and independently of the order of requests by the
-- passes registered for its level. See docs/WORLDGEN.md.
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
-- Version 1: multiverses from before the surface grid (lands in country
-- districts); version 2: lands in the regions of the surface grid.
gen.run.VERSION = 2
gen.VERSION = gen.run.VERSION
gen.GRID_VERSION = 2

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
    { "land", "l", parent = { "country", "region" }, caps = { children = 0, facts = 1024 } },
    { "region", "r", parent = "planet", caps = { children = 256, facts = 256 } },
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
gen.life = require("gen.life")
gen.life.register(gen.cosmos)
gen.culture = require("gen.culture")
gen.culture.register(gen.cosmos)
gen.history = require("gen.history")
gen.history.register(gen.cosmos)
gen.atlas = require("gen.plan.atlas")
gen.atlas.register(gen.cosmos)
gen.plan = require("gen.plan.query")
gen.sky = require("gen.visuals.sky")
gen.sky.register(gen.cosmos)
gen.grid = require("gen.plan.grid")
gen.region = require("gen.levels.region")
gen.region.register(gen.cosmos)
gen.land = require("gen.levels.land")
gen.land.register(gen.cosmos)
gen.signals = require("gen.signals")
gen.dialogue = { grammar = require("gen.dialogue.grammar"), lore = require("gen.dialogue.lore") }
gen.stats = require("gen.stats")

-- Inside Prime nothing is generated below the planets except the farm and
-- the countryside around it; elsewhere places exist up to their parent's cap.
-- Since the surface grid, lands lie in regions; country districts have lands
-- only in multiverses from before it (and in Prime, the farm's countryside).
gen.prime = require("gen.prime")
for _, level in ipairs({ "continent", "country", "land" }) do
  gen.cosmos:skeleton(level, function(parent, index)
    local addr = gen.address.child(gen.cosmos.scheme, parent.address, index)
    if gen.prime.inside(addr) and not gen.prime.allowed(addr) then return nil end
    if level == "land" and parent.kind == "country" and not gen.prime.inside(addr) and
       (parent.version or 1) >= gen.GRID_VERSION then
      return nil
    end
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

-- Is `addr` a land of the surface grid?
function gen.is_grid_land(addr) return addr:match("%.r%d+%.l%d+$") ~= nil end

-- The land at grid position (gx, gz) next to land `addr`, or nil where there
-- is none. For a land of the surface grid, (gx, gz) are face land positions
-- (its data.grid): the neighbour may lie in another region of the face. For
-- a district land they are positions in the district (0..15).
function gen.neighbour_land(G, addr, gx, gz)
  local target
  if gen.is_grid_land(addr) then
    local paddr = addr:match("^(.*)%.r%d+%.l%d+$")
    local planet = G:generate(paddr)
    local g = gen.region.info(planet.data).g
    if not gen.grid.on_face(g, gx, gz) then return nil end
    local R = tonumber(addr:match("%.r(%d+)%.l%d+$"))
    local f = gen.grid.region(g, R)
    target = gen.grid.address(paddr, g, f, gx, gz)
  else
    local index = gen.land.index(gx, gz)
    if not index then return nil end
    target = gen.address.parent(addr) .. ".l" .. index
  end
  local ok, node = pcall(G.generate, G, target)
  return ok and node or nil
end

-- The k-th land (from 1) of country `cid` of a generated planet node where
-- people live: on the surface grid its k-th dry land around the capital,
-- before it land k - 1 of the country's district. Nil when there is none.
function gen.country_land(planet, cid, k)
  local c = planet.data.countries and planet.data.countries[cid]
  if not c then return nil end
  if (planet.version or 1) < gen.GRID_VERSION then
    return planet.address .. ".k" .. (c.continent - 1) .. ".n" .. c.index .. ".l" .. (k - 1)
  end
  return gen.region.country_land(planet.address, planet.data, cid, k)
end

-- The land of the surface grid at a latitude and longitude of a planet.
function gen.land_at(G, planet_addr, lat, lon)
  local planet = G:generate(planet_addr)
  if not planet.data.cells then return nil end
  local g = gen.region.info(planet.data).g
  local x, y, z = gen.grid.direction(lat, lon)
  return gen.grid.locate(planet_addr, g, x, y, z).address
end

return gen
