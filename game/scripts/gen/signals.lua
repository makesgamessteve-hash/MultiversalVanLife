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

local S = { PER_NIGHT = 3, CANDIDATES = 7, UNIVERSES = 24 }

local function candidate(G, rng)
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
  local planet = G:generate(saddr .. ".p" .. p)
  local addr = string.format("%s.k%d.n%d.l%d", planet.address, rng:int(0, 3), rng:int(0, 15), rng:int(0, 255))
  local land_seed = address.seed(G.seed, addr)
  local t = quests.pick(G.registry, land_seed)
  return {
    address = addr, name = provisional.settlement_name(land_seed), planet = planet.data.name, style = planet.data.style,
    galaxy = galaxy.address, galaxy_name = galaxy.data.name, universe = "u" .. u,
    trouble = t.id, short = t.short or t.id, severity = quests.severity(land_seed),
  }
end

-- Tonight's signals: `visited` maps galaxy addresses already visited to
-- true, `recent` maps recently offered trouble ids to true.
function S.tonight(G, night, visited, recent)
  visited, recent = visited or {}, recent or {}
  local rng = mvl.rng(mvl.hash(G.seed, "signals", night))
  local cands = {}
  local tries = 0
  while #cands < S.CANDIDATES and tries < S.CANDIDATES * 4 do
    tries = tries + 1
    local c = candidate(G, rng)
    if c then
      c.score = c.severity + (visited[c.galaxy] and 0 or 0.6) + (recent[c.trouble] and 0 or 0.4)
      cands[#cands + 1] = c
    end
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
