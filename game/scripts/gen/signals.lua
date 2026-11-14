-- Multiversal Van Life - Juniper's nightly signals (MIT).
--
-- Every night a few lands in trouble call out across the multiverse. The
-- candidates are drawn from the save's seed and the night number (never in
-- Prime): a universe, a galaxy, a cluster in its habitable band, a star and
-- one of its rocky worlds are generated down to the star system; the land
-- itself is only named and given its trouble (both follow from its seed),
-- so it is generated when the van travels there. Three are chosen by
-- severity and novelty: galaxies not visited yet and troubles not offered
-- recently score higher, and no two signals of a night share a galaxy.
local address = require("gen.address")
local quests = require("gen.quests")
local provisional = require("gen.levels.provisional")
local landgen = require("gen.levels.land")

local S = { PER_NIGHT = 3, CANDIDATES = 5, UNIVERSES = 24 }

-- The star system and rocky planet a candidate signal comes from (cheap:
-- the planet itself is not generated here).
local function origin(G, rng)
  local u = rng:int(1, S.UNIVERSES)
  local gaddr = "u" .. u .. ".g" .. rng:int(0, 999)
  local galaxy = G:generate(gaddr)
  if galaxy.data.clusters == 0 then return nil end
  -- prefer clusters in the habitable band
  local options = {}
  for i = 0, galaxy.data.clusters - 1 do
    if galaxy.children[i].habitable then options[#options + 1] = i end
  end
  local c = #options > 0 and options[rng:int(1, #options)] or rng:int(0, galaxy.data.clusters - 1)
  local cluster = G:generate(gaddr .. ".c" .. c)
  -- the worlds of a spacefaring people call out more often than empty ones
  local sf = cluster.data.spacefarers
  if sf and rng:chance(0.75) then
    local homes = { sf.homeworld }
    for _, j in ipairs(sf.colonies) do homes[#homes + 1] = j end
    local saddr = cluster.address .. ".s" .. homes[rng:int(1, #homes)]
    local system = G:generate(saddr)
    for _, id in ipairs(system.fact_order) do
      local f = system.facts[id]
      if f.kind == "settled" then
        return { planet = saddr .. ".p" .. f.data.planet, galaxy = galaxy, summary = system.children[f.data.planet],
                 universe = "u" .. u }
      end
    end
  end
  local saddr = cluster.address .. ".s" .. rng:int(0, cluster.data.stars - 1)
  local system = G:generate(saddr)
  local rocky = {}
  for i = 0, system.data.planets - 1 do
    if system.children[i].kind == "rocky" then rocky[#rocky + 1] = i end
  end
  if #rocky == 0 then return nil end
  local p = rocky[rng:int(1, #rocky)]
  return { planet = saddr .. ".p" .. p, galaxy = galaxy, summary = system.children[p], universe = "u" .. u }
end

-- The candidate planets of a night, in order (for generating them early).
function S.planets(G, night)
  local rng = mvl.rng(mvl.hash(G.seed, "signals", night))
  local out = {}
  for _ = 1, S.CANDIDATES * 3 do
    if #out >= S.CANDIDATES then break end
    local o = origin(G, rng)
    if o then out[#out + 1] = o end
  end
  return out
end

-- A land of a planet on dry ground: continent, country and land chosen from
-- what the planet really has.
local function dry_land(G, o, rng)
  local planet = G:generate(o.planet)
  if not planet.data.continents or planet.data.continents == 0 then return nil end
  -- where a people lives, a land of theirs
  local peopled = {}
  for id, c in ipairs(planet.data.countries or {}) do if c.culture then peopled[#peopled + 1] = c end end
  for _ = 1, #peopled > 0 and 4 or 0 do
    local c = peopled[rng:int(1, #peopled)]
    local country = G:generate(o.planet .. ".k" .. (c.continent - 1) .. ".n" .. c.index)
    if country.data.district then
      for _ = 1, 24 do
        local l = rng:int(0, 255)
        local gx, gz = landgen.grid(l)
        if landgen.raw_height(country.data.terrain, gx * landgen.SIZE, gz * landgen.SIZE) > 3 then
          return country.address .. ".l" .. l, planet, country
        end
      end
    end
  end
  for _ = 1, 4 do
    local k = rng:int(0, planet.data.continents - 1)
    local cont = G:generate(o.planet .. ".k" .. k)
    local list = {}
    for n in pairs(cont.children) do list[#list + 1] = n end
    table.sort(list)
    if #list > 0 then
      local n = list[rng:int(1, #list)]
      local country = G:generate(cont.address .. ".n" .. n)
      if country.data.district then
        for _ = 1, 24 do
          local l = rng:int(0, 255)
          local gx, gz = landgen.grid(l)
          if landgen.raw_height(country.data.terrain, gx * landgen.SIZE, gz * landgen.SIZE) > 3 then
            return country.address .. ".l" .. l, planet, country
          end
        end
      end
    end
  end
end

local function candidate(G, o, rng)
  local addr, planet, country = dry_land(G, o, rng)
  if not addr then return nil end
  local land_seed = address.seed(G.seed, addr)
  -- the land's trouble is its strongest tension (history), as the land will have it
  local tensions = require("gen.history.tensions").for_land(planet.data, country.summary.id, land_seed)
  local top = tensions and tensions[1]
  local t = quests.choose(G.registry, land_seed, top and top.quest)
  local named = require("gen.culture").land_name(planet.data, country.summary.id, land_seed)
  return {
    address = addr, name = named and named.name or provisional.settlement_name(land_seed), planet = o.summary.name,
    meaning = named and named.meaning, peopled = named ~= nil,
    galaxy = o.galaxy.address, galaxy_name = o.galaxy.data.name, universe = o.universe,
    trouble = t.id, short = t.short or t.id, severity = top and top.severity or quests.severity(land_seed),
    tension = top and top.text, tension_kind = top and top.kind, local_trouble = top and top.local_trouble,
  }
end

-- Tonight's signals: `visited` maps galaxy addresses already visited to
-- true, `recent` maps recently offered trouble ids to true.
function S.tonight(G, night, visited, recent)
  visited, recent = visited or {}, recent or {}
  local rng = mvl.rng(mvl.hash(G.seed, "signals", night, "lands"))
  local cands, galaxies_seen = {}, {}
  local origins = S.planets(G, night)
  local extra = mvl.rng(mvl.hash(G.seed, "signals", night, "more"))
  local i = 0
  -- planets without dry land give no signal; look further until three
  -- different galaxies call (or give up)
  while i < #origins + 12 do
    i = i + 1
    local o = origins[i] or origin(G, extra)
    local c = o and candidate(G, o, rng)
    if c then
      -- strong tensions call loudest, the troubles of history above local ones
      c.score = c.severity + (visited[c.galaxy] and 0 or 0.6) + (recent[c.trouble] and 0 or 0.4) + (c.peopled and 1 or 0)
                + ((c.tension_kind and not c.local_trouble) and 0.3 or 0)
      cands[#cands + 1] = c
      galaxies_seen[c.galaxy] = true
    end
    local distinct = 0
    for _ in pairs(galaxies_seen) do distinct = distinct + 1 end
    if i >= #origins and distinct >= S.PER_NIGHT then break end
  end
  table.sort(cands, function(a, b) return a.score > b.score or (a.score == b.score and a.address < b.address) end)
  local out, galaxies, kinds = {}, {}, {}
  -- two rounds: first distinct galaxies and troubles, then distinct galaxies
  for round = 1, 2 do
    for _, c in ipairs(cands) do
      if #out < S.PER_NIGHT and not galaxies[c.galaxy] and (round == 2 or not kinds[c.trouble]) then
        out[#out + 1] = c
        galaxies[c.galaxy], kinds[c.trouble] = true, true
      end
    end
  end
  return out
end

-- Juniper's description of a signal.
function S.describe(s)
  return string.format("A call from %s, on %s in the %s galaxy: %s.", s.name, s.planet, s.galaxy_name, s.tension or s.short)
end

return S
