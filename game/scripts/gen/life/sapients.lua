-- Multiversal Van Life - intelligent species, spacefarers and colonies (MIT).
--
-- A living world with animals may have raised 0 to 2 intelligent species,
-- each descended from one of its lineages and keeping its body plan: a
-- species from a flying lineage has wings, one from a six-limbed lineage
-- six limbs. Their physiology (anatomy, senses, lifespan, reproduction,
-- diet, social instinct, psionic potential) is what later culture passes
-- build on.
--
-- In universes with faster-than-light travel a star cluster may hold a
-- spacefaring species: the cluster describes it once (a fact shared by the
-- systems it reached), commits its homeworld to one system and colonies to
-- systems along the lanes. Each system passes the promise on to one of its
-- rocky worlds (making sure it has one), and that world's life includes
-- the species with the same anatomy: on the homeworld its ancestors are a
-- lineage of the native tree of life, in colonies it lives alongside the
-- native life.
local dm = require("gen.dmath")
local names = require("gen.names")
local tree = require("gen.life.tree")

local SA = {}

local SOCIAL = { "solitary", "pair-bonded", "pack", "herd", "hive", "clan" }
local TEMPER = { "curious", "wary", "playful", "proud", "patient", "restless", "gentle", "fierce" }

local function flies(l) for _, m in ipairs(l.moves) do if m == "fly" then return true end end return false end

-- Physiology of an intelligent species from its lineage and ancestor.
local function physiology(rng, l, ancestor, gravity)
  local height = ancestor and math.max(ancestor.height, 0.6) or (0.8 + rng:next() * 1.4)
  height = dm.clamp(height * (1.1 + rng:next() * 0.6), 0.6, 4) / dm.pow(gravity or 1, 0.3)
  local hands = l.limbs >= 6 and (rng:chance(0.5) and 4 or 2) or (l.limbs >= 2 and 2 or 0)
  local social
  if ancestor and ancestor.role == "predator" then social = rng:chance(0.6) and "pack" or "clan"
  elseif ancestor and ancestor.role == "grazer" then social = rng:chance(0.6) and "herd" or "clan"
  else social = SOCIAL[rng:int(1, #SOCIAL)] end
  local diet = ancestor and (ancestor.role == "predator" and "carnivore" or
               (ancestor.role == "grazer" and (rng:chance(0.6) and "herbivore" or "omnivore") or "omnivore")) or "omnivore"
  return {
    anatomy = { limbs = l.limbs, hands = hands, wings = flies(l), tail = l.tail, eyes = l.eyes, covering = l.covering,
                segments = l.segments, height = dm.round(height, 2),
                build = dm.round((ancestor and ancestor.stockiness or 1) * (0.9 + rng:next() * 0.2), 3),
                manipulators = hands > 0 and (hands .. " hands") or "mouth and tendrils",
                mouth = (l.covering == "feathers" or l.covering == "shell" or l.covering == "plates") and "beak" or
                        (l.covering == "chitin" and "mandibles" or "lips") },
    senses = { l.senses[1], l.senses[2] },
    lifespan = math.floor(25 + height * 20 + rng:next() * 90),
    reproduction = l.birth, diet = diet, social = social,
    temperament = TEMPER[rng:int(1, #TEMPER)],
  }
end

local function plural(n) return n:sub(-1) == "s" and n or (n:sub(-1) == "a" and n .. "ns" or n .. "i") end

-- The sapients pass: native intelligent species, the committed homeworld
-- species and colonists.
function SA.sapients(ctx)
  local d = ctx.data
  local life = d.life
  if not life then return end
  local rng = ctx:random("sapients")
  local laws = ctx:ancestor("universe").data.laws
  life.sapients = {}
  local function add(s, because)
    local id = ctx:fact("species", s, because)
    s.fact = id
    life.sapients[#life.sapients + 1] = s
    return id
  end
  -- committed by a higher level: the species and its ancestors
  for _, c in ipairs(ctx:commitments("homeworld")) do
    local spec = ctx:ref(c.data.data.species).data
    local s = require("gen.util").copy(spec)
    s.origin, s.homeworld = "committed", ctx.node.address
    for _, l in ipairs(life.lineages or {}) do if l.kin_of == spec.name then s.lineage = l.id end end
    ctx:honour(c, add(s, c))
  end
  -- native: from the world's animal lineages
  if life.complexity == "animals" and life.species then
    local roll = rng:next()
    local n = roll < 0.7 and 0 or (roll < 0.95 and 1 or 2)
    if #life.sapients > 0 then n = 0 end
    local candidates = {}
    for _, l in ipairs(life.lineages) do
      if l.kind == "animal" and l.limbs >= 2 and not l.kin_of then candidates[#candidates + 1] = l end
    end
    for k = 1, math.min(n, #candidates) do
      local l = table.remove(candidates, rng:int(1, #candidates))
      local ancestor
      for _, sp in ipairs(life.species) do
        if sp.lineage == l.id and sp.kind == "animal" and (not ancestor or sp.size > ancestor.size) then ancestor = sp end
      end
      local s = physiology(rng, l, ancestor, d.gravity)
      s.name = plural(names.make(ctx:random("sapient" .. k), "cosmic"))
      s.lineage, s.ancestor = l.id, ancestor and ancestor.id
      s.origin, s.homeworld, s.hue = "native", ctx.node.address, l.hue
      s.psionic = dm.round((laws.psionics or 0) * rng:next(), 3)
      add(s)
    end
  end
  -- colonists from other worlds, with their homeworld anatomy
  life.colonists = {}
  for _, c in ipairs(ctx:commitments("colony")) do
    local spec = ctx:ref(c.data.data.species).data
    local s = require("gen.util").copy(spec)
    s.origin, s.from = "colony", c.data.data.from_address
    local id = ctx:fact("colony", { name = "colony of the " .. spec.name, species = c.data.data.species,
                                    from = s.from }, c)
    s.fact = id
    life.colonists[#life.colonists + 1] = s
    ctx:honour(c, id)
  end
end

-- A spacefaring species described by a cluster (no planet yet).
function SA.spacefarer(rng)
  local l = {
    limbs = ({ 4, 4, 6, 2, 8 })[rng:int(1, 5)], covering = tree.COVERINGS[rng:int(1, #tree.COVERINGS)],
    moves = { "walk" }, senses = { tree.SENSES[rng:int(1, #tree.SENSES)], tree.SENSES[rng:int(1, #tree.SENSES)] },
    eyes = rng:int(0, 4), tail = rng:chance(0.5), segments = rng:int(1, 3),
    birth = ({ "eggs", "live young", "budding" })[rng:int(1, 3)],
  }
  if l.covering == "feathers" or rng:chance(0.2) then l.moves[2] = "fly" end
  if l.senses[2] == l.senses[1] then l.senses[2] = nil end
  local s = physiology(rng, l, nil, 1)
  s.name = plural(names.make(rng, "cosmic"))
  s.hue = rng:int(0, 359)
  s.spacefaring = true
  s.psionic = dm.round(rng:next() * 0.5, 3)
  return s
end

-- Cluster pass: a spacefaring species, its homeworld and its colonies.
function SA.spacefarers(ctx)
  if ctx.summary.prime then return end
  local laws = ctx:ancestor("universe").data.laws
  local d = ctx.data
  if laws.ftl == "none" or #(d.lanes or {}) == 0 then return end
  local rng = ctx:random("spacefarers")
  if not rng:chance(0.35) then return end
  local degree, links = {}, {}
  for _, l in ipairs(d.lanes) do
    links[l.a] = links[l.a] or {}
    links[l.b] = links[l.b] or {}
    table.insert(links[l.a], l.b)
    table.insert(links[l.b], l.a)
    degree[l.a], degree[l.b] = (degree[l.a] or 0) + 1, (degree[l.b] or 0) + 1
  end
  local options = {}
  for i = 0, d.stars - 1 do
    local cls = ctx.node.children[i].class
    if degree[i] and (cls == "F" or cls == "G" or cls == "K") then options[#options + 1] = i end
  end
  if #options == 0 then
    for i = 0, d.stars - 1 do if degree[i] then options[#options + 1] = i end end
  end
  local home = options[rng:int(1, #options)]
  local near = links[home]
  table.sort(near)
  local colonies = {}
  for _, j in ipairs(near) do if #colonies < 3 then colonies[#colonies + 1] = j end end
  local species = SA.spacefarer(rng)
  local members = { home }
  for _, j in ipairs(colonies) do members[#members + 1] = j end
  local fid = ctx:shared("spacefarers", species, members)
  ctx:commit(home, "homeworld", { species = fid }, fid)
  for _, j in ipairs(colonies) do
    ctx:commit(j, "colony", { species = fid, from = home }, fid)
  end
  d.spacefarers = { name = species.name, fact = fid, homeworld = home, colonies = colonies }
end

-- Is a planet summary a world colonists and homeworlds can live on?
local function solid(p) return p.kind == "rocky" end

-- Makes sure a system with promises has a rocky world inside its frost
-- line (a dwarf grows into one, or one forms in the habitable zone).
function SA.ensure_rocky(d, planets, rng, period)
  for _, p in ipairs(planets) do if solid(p) then return end end
  local hz = (d.habitable_zone[1] + d.habitable_zone[2]) / 2
  for _, p in ipairs(planets) do
    if p.kind == "dwarf" and p.a < d.frost_line then
      p.kind, p.mass = "rocky", dm.round(0.4 + rng:next() * 1.2, 4)
      return
    end
  end
  local a = dm.round(hz, 4)
  local planet = { kind = "rocky", a = a, period = dm.round(period(a, d.star.mass), 5),
                   mass = dm.round(0.5 + rng:next(), 4), habitable_zone = true, moons = {} }
  local at = #planets + 1
  for i, p in ipairs(planets) do if p.a > a then at = i break end end
  table.insert(planets, at, planet)
end

-- System pass: passes each promise on to the rocky world nearest the
-- habitable zone.
function SA.settlers(ctx)
  local list = {}
  for _, c in ipairs(ctx:commitments("homeworld")) do list[#list + 1] = c end
  for _, c in ipairs(ctx:commitments("colony")) do list[#list + 1] = c end
  if #list == 0 then return end
  local d = ctx.data
  local hz = (d.habitable_zone[1] + d.habitable_zone[2]) / 2
  local best, bd
  for i = 0, (d.planets or 0) - 1 do
    local p = ctx.node.children[i]
    if solid(p) then
      local dist = math.abs(dm.log(p.a / hz))
      if not best or dist < bd then best, bd = i, dist end
    end
  end
  assert(best, ctx.node.address .. ": a promised world without a rocky planet")
  local cluster = ctx.parent.address
  for _, c in ipairs(list) do
    local data = require("gen.util").copy(c.data.data)
    if data.from then data.from_address = cluster .. ".s" .. data.from end
    ctx:commit(best, c.data.kind, data, c)
    ctx:honour(c, ctx:fact("settled", { kind = c.data.kind, planet = best, species = data.species }, c))
  end
end

return SA
