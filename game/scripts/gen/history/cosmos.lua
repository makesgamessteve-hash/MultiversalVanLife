-- Multiversal Van Life - histories of universes, galaxies and clusters (MIT).
--
-- The same chronicle engine at cosmic time scales:
--   universe  steps of 10^8 years over its notable galaxies: elder powers
--             (the gods themselves where gods are real) rise and fall
--   galaxy    steps of 10^3 years over its star clusters: elder empires of
--             the deep past and, with faster-than-light travel, the star
--             nations of the recent past
--   cluster   steps of 10^2 years over its star systems: the spacefaring
--             people of the cluster spread from its homeworld to the
--             colonies it was promised, which may break away
-- Names use the cosmic lexicon until those peoples' languages are known.
local E = require("gen.history.engine")
local EV = require("gen.history.events")
local names = require("gen.names")
local dm = require("gen.dmath")

local C = {}

local function traits(rng)
  return { ambition = rng:next(), aggression = rng:next(), diplomacy = rng:next(), commerce = rng:next(),
           piety = rng:next(), curiosity = rng:next() }
end

local function facts(ctx, st, address_of)
  local fact_of = {}
  for _, ev in ipairs(st.events) do
    local because = {}
    for _, b in ipairs(ev.because) do if fact_of[b] then because[#because + 1] = fact_of[b] end end
    local places = {}
    for i, r in ipairs(ev.places or {}) do places[i] = address_of(r) end
    local who = {}
    for i, fid in ipairs(ev.participants or {}) do who[i] = st.factions[fid].name end
    fact_of[ev.id] = ctx:fact("event", { name = ev.name, kind = ev.kind, year = ev.year, places = places,
                                         factions = who }, because)
    ev.fact = fact_of[ev.id]
    ev.addresses = places
  end
  for _, p in ipairs(st.individuals) do
    p.fact = ctx:fact("individual", { name = p.name, role = p.role, born = p.born, died = p.died,
                                      faction = st.factions[p.faction].name })
  end
end

local function name_era(era, st, used)
  local f = era.dominant and st.factions[era.dominant]
  local name = f and ("the Age of " .. f.name)
  if not name or used[name] then
    local ev = era.defining and st.events[era.defining]
    name = ev and ("the Time of " .. ev.name) or "the Long Silence"
  end
  return name
end

-- Regions from points: neighbours are the three nearest.
local function nearest_regions(points, label)
  local R = {}
  for i, p in pairs(points) do
    local list = {}
    for j, q in pairs(points) do
      if j ~= i then
        local dx, dy, dz = p[1] - q[1], p[2] - q[2], p[3] - q[3]
        list[#list + 1] = { j = j, d = dx * dx + dy * dy + dz * dz }
      end
    end
    table.sort(list, function(a, b) return a.d < b.d or (a.d == b.d and a.j < b.j) end)
    local nb = {}
    for k = 1, math.min(3, #list) do nb[k] = list[k].j end
    R[i] = { name = label(i), neighbours = nb, value = 1 }
  end
  -- neighbours both ways
  for i, r in pairs(R) do
    for _, j in ipairs(r.neighbours) do
      local back = false
      for _, k in ipairs(R[j].neighbours) do if k == i then back = true end end
      if not back then table.insert(R[j].neighbours, i) end
    end
  end
  for _, r in pairs(R) do table.sort(r.neighbours) end
  return R
end

-- ---------------------------------------------------------------- universe
function C.universe(ctx)
  local d = ctx.data
  if ctx.summary.prime or not d.notable then return end
  local rng = ctx:random("history")
  local laws = d.laws
  local points = {}
  local count = 0
  for i, n in pairs(d.notable) do
    count = count + 1
    points[i] = { dm.sin(i * 1.7), dm.cos(i * 2.3), dm.sin(i * 0.9) }
  end
  if count < 2 then return end
  local R = nearest_regions(points, function(i) return d.notable[i].name end)
  local steps = math.min(45, math.floor((d.age or 13) * 10 / 3))
  local st = E.simulate({
    regions = R, step = 1e8, steps = steps, start = -steps * 1e8, rng = rng, actions = EV.table("universe"),
    activity = 0.3, eras = 3,
    setup = function(st0)
      local ids = {}
      for i in pairs(R) do ids[#ids + 1] = i end
      table.sort(ids)
      local powers = rng:int(2, 3)
      for k = 1, powers do
        local god = laws.gods == "real"
        E.found(st0, { name = (god and "the God " or "the Ancients of ") .. names.make(rng, "cosmic"),
                       kind = god and "deity" or "elder power", lifespan = 3e9, traits = traits(rng) },
                { ids[(k - 1) * 2 % #ids + 1] })
      end
    end,
    each = function(st0) EV.drift(st0) end,
    secede = function(f) return { name = "the Heirs of " .. names.make(rng, "cosmic"), kind = f.kind, lifespan = 3e9,
                                  traits = traits(rng) } end,
    name_person = function(_, prng) return names.make(prng, "cosmic") end,
    name_era = name_era,
  })
  facts(ctx, st, function(i) return ctx.node.address .. ".g" .. i end)
  d.history = E.export(st, { level = "universe", lore = "Some worlds were never touched by any of this: the quiet " ..
                                                         "worlds, which the powers overlooked." })
end

-- ------------------------------------------------------------------ galaxy
function C.galaxy(ctx)
  local d = ctx.data
  if ctx.summary.prime or (d.clusters or 0) < 3 then return end
  local rng = ctx:random("history")
  local laws = ctx:ancestor("universe").data.laws
  local points = {}
  for i = 0, d.clusters - 1 do
    local s = ctx.node.children[i]
    points[i] = s and s.pos or { 0, 0, 0 }
  end
  local R = nearest_regions(points, function(i) return ctx.node.children[i].name end)
  local steps = rng:int(60, 100)
  local ftl = laws.ftl ~= "none"
  local st = E.simulate({
    regions = R, step = 1000, steps = steps, start = -steps * 1000, rng = rng, actions = EV.table("galaxy"),
    activity = 0.3, eras = rng:int(3, 5), magic = laws.magic ~= "none",
    setup = function(st0)
      -- elder empires of the deep past
      for _ = 1, rng:int(1, 2) do
        local r = rng:int(0, d.clusters - 1)
        E.found(st0, { name = "the Elder " .. names.make(rng, "cosmic"), kind = "elder empire", lifespan = 400,
                       traits = traits(rng), prosperity = 0.4, stability = 0.35,
                       fall_step = rng:int(math.floor(steps * 0.2), math.floor(steps * 0.6)) }, { r })
      end
    end,
    each = function(st0, step)
      EV.drift(st0)
      -- the elder empires of the deep past fall, leaving ruins
      for _, f in ipairs(st0.factions) do
        if f.alive and f.kind == "elder empire" and step == f.fall_step then
          local places = E.regions_of(st0, f)
          E.collapse(st0, f)
          E.record(st0, { kind = "collapse", name = "the fall of " .. f.name, participants = { f.id }, places = places,
                          importance = 0.9, change = 4, deed = "saw the end of " .. f.name })
        end
      end
      -- star nations rise once ships cross between the stars
      if ftl and step == math.floor(steps * 0.5) then
        for _ = 1, rng:int(1, 3) do
          local free = {}
          for _, r in ipairs(st0.region_ids) do if not st0.owner[r] then free[#free + 1] = r end end
          if #free > 0 then
            local f, founder = E.found(st0, { name = "the " .. names.make(rng, "stellar") .. " Dominion", kind = "star nation",
                                              lifespan = 150, traits = traits(rng) }, { free[rng:int(1, #free)] })
            if f then
              E.record(st0, { kind = "founding", name = "the founding of " .. f.name, participants = { f.id },
                              places = { f.capital }, leader = founder and founder.id, importance = 0.6, change = 2,
                              deed = "founded " .. f.name })
            end
          end
        end
      end
    end,
    secede = function(f) return { name = "the Free " .. names.make(rng, "stellar"), kind = "star nation", lifespan = 150,
                                  traits = traits(rng) } end,
    name_person = function(_, prng) return names.make(prng, "cosmic") end,
    name_era = name_era,
  })
  facts(ctx, st, function(i) return ctx.node.address .. ".c" .. i end)
  d.history = E.export(st, { level = "galaxy" })
end

-- ----------------------------------------------------------------- cluster
function C.cluster(ctx)
  local d = ctx.data
  local sf = d.spacefarers
  if ctx.summary.prime or not sf then return end
  local rng = ctx:random("history")
  local R = {}
  for i = 0, d.stars - 1 do R[i] = { name = ctx.node.children[i].name, neighbours = {}, value = 1 } end
  for _, l in ipairs(d.lanes or {}) do
    table.insert(R[l.a].neighbours, l.b)
    table.insert(R[l.b].neighbours, l.a)
  end
  for _, r in pairs(R) do table.sort(r.neighbours) end
  local steps = rng:int(30, 60)
  local colonies = sf.colonies
  local st = E.simulate({
    regions = R, step = 100, steps = steps, start = -steps * 100, rng = rng, actions = EV.table("cluster"),
    activity = 0.25, eras = 3,
    setup = function(st0)
      E.found(st0, { name = "the " .. sf.name .. " Concord", kind = "spacefaring people", species = sf.name,
                     lifespan = 120, traits = traits(rng) }, { sf.homeworld })
    end,
    each = function(st0, step)
      EV.drift(st0)
      -- the promised colonies are founded one by one
      local f = st0.factions[1]
      for k, j in ipairs(colonies) do
        if step == math.floor(steps * k / (#colonies + 2)) and f and f.alive and st0.owner[j] ~= f.id then
          st0.owner[j] = f.id
          local p = E.ruler(st0, f)
          E.record(st0, { kind = "colonisation", name = "the colonisation of " .. R[j].name, participants = { f.id },
                          places = { j }, leader = p and p.id, importance = 0.6, change = 2,
                          deed = "led the ships to " .. R[j].name })
        end
      end
    end,
    secede = function(f) return { name = "the Free Worlds of " .. names.make(rng, "stellar"), kind = "colony league",
                                  species = f.species, lifespan = 120, traits = traits(rng) } end,
    name_person = function(_, prng) return names.make(prng, "cosmic") end,
    name_era = name_era,
  })
  facts(ctx, st, function(i) return ctx.node.address .. ".s" .. i end)
  d.history = E.export(st, { level = "cluster" })
end

return C
