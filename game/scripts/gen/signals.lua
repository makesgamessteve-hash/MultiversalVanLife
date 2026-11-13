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
            return country.address .. ".l" .. l
          end
        end
      end
    end
  end
end

local function candidate(G, o, rng)
  local addr = dry_land(G, o, rng)
  if not addr then return nil end
  local land_seed = address.seed(G.seed, addr)
  local t = quests.pick(G.registry, land_seed)
  return {
    address = addr, name = provisional.settlement_name(land_seed), planet = o.summary.name,
    galaxy = o.galaxy.address, galaxy_name = o.galaxy.data.name, universe = o.universe,
    trouble = t.id, short = t.short or t.id, severity = quests.severity(land_seed),
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
      c.score = c.severity + (visited[c.galaxy] and 0 or 0.6) + (recent[c.trouble] and 0 or 0.4)
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
  return string.format("A call from %s, on %s in the %s galaxy: %s.", s.name, s.planet, s.galaxy_name, s.short)
end

return S
