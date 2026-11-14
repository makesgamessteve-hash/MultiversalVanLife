-- Multiversal Van Life - the history of a planet (MIT).
--
-- Each culture founds a nation in its home country; over 40 to 100 steps
-- of 25 years nations settle free countries (spreading their culture),
-- make pacts and trade, wage wars, break apart (the breakaway half becomes
-- a new culture speaking a daughter language), found new faiths in
-- schisms, discover, suffer plagues, migrate, flourish and fall. When it
-- ends at the present, the countries belong to the nations holding them:
-- their culture and name follow; countries nobody holds are wild. Notable
-- events become holidays of the cultures that lived them, technology grows
-- era by era with stability, discoveries and trade, and the people still
-- alive (long-lived species keep their founders and heroes) are promised
-- to lands of their nation's capital country, where they can be met.
local E = require("gen.history.engine")
local EV = require("gen.history.events")
local util = require("gen.util")
local names = require("gen.names")

local H = { STEP = 25, RESIDENT_LAND = 118 }

local KIND = {
  ["a monarchy"] = "Kingdom", ["a theocracy"] = "Holy Realm", ["a hive court around a queen"] = "Hive",
  ["chiefdoms of great clans"] = "Clans", ["noble houses"] = "Houses", ["councils of elders"] = "League",
  ["open assemblies"] = "Commonwealth",
}

-- Countries as regions, with neighbours across their borders.
local function regions(P)
  local out = {}
  for id, c in ipairs(P.countries) do
    out[id] = { name = c.name or ("country " .. id), neighbours = {}, value = 1, continent = c.continent, cells = 0 }
  end
  local cells = P.cells
  local seen = {}
  for i = 1, #cells.country do
    local o = cells.country[i]
    if o and o > 0 and out[o] then
      out[o].cells = out[o].cells + 1
      for _, nb in ipairs(mvl.planet_neighbours(P.grid, i)) do
        local q = cells.country[nb]
        if q and q > 0 and q ~= o and out[q] then
          local key = math.min(o, q) * 100000 + math.max(o, q)
          if not seen[key] then
            seen[key] = true
            table.insert(out[o].neighbours, q)
            table.insert(out[q].neighbours, o)
          end
        end
      end
    end
  end
  for _, r in pairs(out) do
    table.sort(r.neighbours)
    r.value = 1 + r.cells / 20
  end
  return out
end

local function species_of(P, name)
  for _, s in ipairs(P.life.sapients or {}) do if s.name == name then return s end end
  for _, s in ipairs(P.life.colonists or {}) do if s.name == name then return s end end
end

-- The history pass of a planet.
function H.run(ctx)
  local d = ctx.data
  if not d.cultures or #d.cultures == 0 then return end
  local language = require("gen.culture.language")
  local culture_mod = require("gen.culture")
  local rng = ctx:random("history")
  local laws = ctx:ancestor("universe").data.laws
  -- country names, in their first culture's language (until history decides)
  for id, c in ipairs(d.countries) do
    local cul = c.culture and d.cultures[c.culture]
    local n = cul and language.name(cul.language, mvl.rng(mvl.hash(ctx.seed, "country", id)), "country")
    c.name = n and n.name or names.make(mvl.rng(mvl.hash(ctx.seed, "country", id)), "world")
    c.meaning = n and n.meaning
  end
  local R = regions(d)
  local steps = rng:int(40, 100)
  local cultures = d.cultures
  local function faction_of(cul, founded_regions)
    local s = species_of(d, cul.species) or {}
    local v = cul.values
    return {
      name = cul.name .. " " .. (KIND[cul.society.structure] or "Realm"), kind = KIND[cul.society.structure] or "Realm",
      culture = cul.id, religion = cul.religion, species = cul.species, lifespan = s.lifespan or 70,
      traits = { ambition = 0.5 + v.hierarchy * 0.3, aggression = 0.35 + v.honour * 0.35,
                 diplomacy = 0.4 + v.hospitality * 0.3, commerce = 0.4 + (cul.region.coast or 0),
                 piety = cul.religion and 0.5 or 0.2, curiosity = 0.45 - v.tradition * 0.3 },
    }
  end
  local spec
  spec = {
    regions = R, step = H.STEP, steps = steps, start = -steps * H.STEP, rng = rng, actions = EV.table("planet"),
    activity = 0.4, eras = rng:int(3, 5), magic = laws.magic ~= "none", year_days = d.year or 365.25,
    setup = function(st)
      for _, cul in ipairs(cultures) do
        if cul.origin ~= "colony" then
          local home
          for id, c in ipairs(d.countries) do if c.culture == cul.id and not home then home = id end end
          if home then E.found(st, faction_of(cul), { home }) end
        end
      end
    end,
    each = function(st, step)
      EV.drift(st)
      -- colonists arrive late in the story, in their colony country
      if step == math.floor(steps * 0.6) then
        for _, cul in ipairs(cultures) do
          if cul.origin == "colony" then
            local home
            for id, c in ipairs(d.countries) do if c.culture == cul.id and not home then home = id end end
            if home then
              local f, founder = E.found(st, faction_of(cul), { home })
              if f then
                E.record(st, { kind = "landing", name = "the landing of the " .. cul.species, participants = { f.id },
                               places = { home }, leader = founder and founder.id, importance = 0.8, change = 3,
                               deed = "brought our people down from the stars" })
              end
            end
          end
        end
      end
    end,
    secede = function(f, st)
      -- the breakaway people: a daughter culture speaking a daughter language
      local parent = cultures[f.culture]
      local child = util.copy(parent)
      child.id = #cultures + 1
      child.language = language.split(parent.language, mvl.hash(ctx.seed, "split", st.year))
      local n = language.name(child.language, mvl.rng(mvl.hash(ctx.seed, "split name", st.year)), "country")
      child.name, child.meaning, child.parent = n.name, n.meaning, parent.id
      child.fact = nil
      cultures[child.id] = child
      local g = faction_of(child)
      g.traits.aggression = math.min(1, g.traits.aggression + 0.1)
      return g
    end,
    name_person = function(f, prng)
      local cul = cultures[f.culture]
      return language.name(cul.language, prng, "person")
    end,
    name_era = function(era, st, used)
      local f = era.dominant and st.factions[era.dominant]
      local name = f and ("the Age of the " .. f.name)
      if not name or used[name] then
        local ev = era.defining and st.events[era.defining]
        name = ev and ("the Years of " .. ev.name) or "the Quiet Years"
      end
      return name
    end,
  }
  local st = E.simulate(spec)
  -- events and people become facts; causes link events
  local fact_of = {}
  for _, ev in ipairs(st.events) do
    local because = {}
    for _, b in ipairs(ev.because) do if fact_of[b] then because[#because + 1] = fact_of[b] end end
    local places = {}
    for i, r in ipairs(ev.places or {}) do places[i] = R[r] and R[r].name end
    local who = {}
    for i, fid in ipairs(ev.participants or {}) do who[i] = st.factions[fid].name end
    fact_of[ev.id] = ctx:fact("event", { name = ev.name, kind = ev.kind, year = ev.year, places = places,
                                         factions = who }, because)
    ev.fact = fact_of[ev.id]
  end
  for _, p in ipairs(st.individuals) do
    local because = {}
    for _, eid in ipairs(p.deeds) do if fact_of[eid] then because[#because + 1] = fact_of[eid] end end
    p.fact = ctx:fact("individual", { name = p.name, role = p.role, born = p.born, died = p.died,
                                      faction = st.factions[p.faction].name, species = p.species }, because)
  end
  -- culture hooks: new faiths from schisms, holidays for notable events
  for _, ev in ipairs(st.events) do
    local f = st.factions[ev.participants[1]]
    local cul = f and cultures[f.culture]
    if ev.kind == "schism" and cul then
      local old = d.religions[cul.religion]
      local rel = util.copy(old)
      rel.id = #d.religions + 1
      local prophet = st.individuals[ev.leader]
      rel.name = "the Way of " .. (prophet and prophet.name or cul.name)
      rel.parent, rel.schism = old.id, ev.fact
      rel.founder = prophet and { name = prophet.name, role = "prophet" } or nil
      rel.fact = ctx:fact("religion", { name = rel.name, form = rel.form, species = cul.species }, { ev.fact, old.fact })
      d.religions[rel.id] = rel
      cul.religion = rel.id
      f.religion = rel.id
    end
    if cul and ev.importance >= 0.5 and (cul.commemorated or 0) < 3 and cul.calendar then
      cul.commemorated = (cul.commemorated or 0) + 1
      culture_mod.traditions.commemorate(cul, { name = ev.name, t = ev.t, fact = ev.fact })
    end
  end
  -- borders follow history: countries belong to the nations holding them
  for id, c in ipairs(d.countries) do
    local fid = st.owner[id]
    local f = fid and st.factions[fid]
    c.nation = f and f.name or nil
    c.culture = f and f.culture or nil
    local cul = c.culture and cultures[c.culture]
    if cul then
      local n = language.name(cul.language, mvl.rng(mvl.hash(ctx.seed, "country", id)), "country")
      c.name, c.meaning = n.name, n.meaning
    end
  end
  -- every culture of the present gets its religion, style, technology
  for _, cul in ipairs(cultures) do
    if not cul.fact then
      cul.fact = ctx:fact("culture", { name = cul.name, meaning = cul.meaning, species = cul.species,
                                       parent = cul.parent and cultures[cul.parent].name }, nil)
    end
    -- technology grows with the eras it lived through, discoveries and trade
    local f
    for _, x in ipairs(st.factions) do if x.culture == cul.id then f = x end end
    if f and cul.conditions then
      local lived = 0
      for _, era in ipairs(st.eras) do if era.to >= f.founded then lived = lived + 1 end end
      local trade = cul.conditions.trade and util.copy(cul.conditions.trade) or {}
      for gid in pairs(f.trade or {}) do
        local other = cultures[st.factions[gid].culture]
        if other and other.conditions then
          for k in pairs(other.conditions.resources) do trade[k] = true end
        end
      end
      local base = cul.conditions.eras
      cul.tech_by_era = {}
      for k = 1, #st.eras do
        cul.conditions.eras = base + math.min(k, lived) * 0.6 + (f.progress or 0) * 0.5 * k / #st.eras
        cul.conditions.trade = trade
        cul.tech_by_era[k] = culture_mod.technology.reachable(cul.conditions).level
      end
      cul.tech = culture_mod.technology.reachable(cul.conditions)
      if f.species and species_of(d, f.species) and species_of(d, f.species).spacefaring then
        cul.tech.known[#cul.tech.known + 1] = "spaceflight"
        cul.tech.has.spaceflight, cul.tech.level = true, 10
      end
    end
  end
  for k, era in ipairs(st.eras) do
    era.tech = {}
    for _, cul in ipairs(cultures) do if cul.tech_by_era then era.tech[cul.id] = cul.tech_by_era[k] end end
  end
  -- the living are promised to lands of their nation's capital country
  local placed = 0
  for _, p in ipairs(E.living(st)) do
    local f = st.factions[p.faction]
    if placed < 3 and f.alive and f.capital and #p.deeds > 0 then
      local c = d.countries[f.capital]
      local target = ctx.node.address .. ".k" .. (c.continent - 1) .. ".n" .. c.index .. ".l" .. H.RESIDENT_LAND
      local deeds = {}
      for _, eid in ipairs(p.deeds) do
        local ev = st.events[eid]
        deeds[#deeds + 1] = { text = ev.deed, ago = -ev.year, event = ev.name }
      end
      local s = species_of(d, p.species)
      local cul = cultures[f.culture]
      ctx:commit(target, "resident", {
        individual = { name = p.name, meaning = p.meaning, role = p.role, nation = f.name, born = p.born,
                       deeds = deeds, anatomy = s and util.copy(s.anatomy), hue = s and s.hue,
                       dress = cul.style and util.copy(cul.style.dress), accent = cul.style and cul.style.palette.accent },
      }, p.fact)
      p.residence = target
      placed = placed + 1
    end
  end
  d.history = E.export(st, { level = "planet", regions = R })
  for _, era in ipairs(d.history.eras) do era.fact = ctx:fact("era", { name = era.name, from = era.from, to = era.to }) end
end

return H
