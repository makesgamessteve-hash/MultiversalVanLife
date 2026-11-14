-- Multiversal Van Life - traditions: rites, funerals, food customs, taboos
-- and commemorations (MIT).
--
-- What a culture does at births, comings of age, pairings and deaths, what
-- it eats and refuses to eat follow from its land (the region it lives in),
-- its body and its religion, each with the reason recorded: no burial in
-- deep earth where mountains leave little soil, sea burials on coasts,
-- water sharing in deserts, a food taboo on a real local species (sacred to
-- a god, or dangerous). History calls `commemorate` to add holidays for
-- its events on their dates.
local dm = require("gen.dmath")

local T = {}

local FORESTS = { taiga = true, ["temperate forest"] = true, ["seasonal forest"] = true, rainforest = true,
                  ["crystal forest"] = true, wetland = true }
local BARE = { alpine = true, ["ice sheet"] = true, barren = true, ["ash fields"] = true, ["hot desert"] = true,
               ["cold desert"] = true, tundra = true }
local DRY = { ["hot desert"] = true, ["cold desert"] = true }

local METALS = { "iron", "copper", "tin", "silver", "gold" }
local FUELS = { "coal", "oil", "peat" }

-- What a culture's region (a continent, 0-based index k) offers.
function T.region(P, k, pseed)
  local geo = require("gen.levels.geography")
  local c = P.cells
  local out = { cells = 0, biomes = {}, resources = {}, species = {}, magic = 0 }
  local forest, bare, dry, coast, high = 0, 0, 0, 0, 0
  local rocks = {}
  for i = 1, #c.elevation do
    if c.continent and c.continent[i] == k + 1 then
      out.cells = out.cells + 1
      local b = geo.BIOMES[c.biome[i]].id
      out.biomes[b] = (out.biomes[b] or 0) + 1
      if FORESTS[b] then forest = forest + 1 end
      if BARE[b] then bare = bare + 1 end
      if DRY[b] then dry = dry + 1 end
      if c.elevation[i] > 2.5 then high = high + 1 end
      for _, nb in ipairs(mvl.planet_neighbours(P.grid, i)) do
        if c.elevation[nb] <= 0 then coast = coast + 1 break end
      end
      out.magic = out.magic + (c.magic and c.magic[i] or 0)
      if c.rock and c.elevation[i] > 0 then rocks[c.rock[i]] = (rocks[c.rock[i]] or 0) + 1 end
      local dep = c.deposit and c.deposit[i] or 0
      if dep == 1 then out.resources[METALS[mvl.hash(pseed, i, "ore") % #METALS + 1]] = true end
      if dep == 2 then out.resources[FUELS[mvl.hash(pseed, i, "fuel") % #FUELS + 1]] = true end
    end
  end
  local n = math.max(out.cells, 1)
  out.forest, out.bare, out.dry, out.coast, out.mountains = forest / n, bare / n, dry / n, coast / n, high / n
  out.soil = 1 - math.max(out.bare, out.mountains)
  out.magic = out.magic / n
  for _, dep in ipairs(P.deposits or {}) do
    if c.continent[dep.cell] == k + 1 and dep.kind ~= "gem" then out.resources[dep.name] = true end
  end
  local best, bn = nil, 0
  for b, cnt in pairs(out.biomes) do if cnt > bn or (cnt == bn and b < best) then best, bn = b, cnt end end
  out.biome = best or "barren"
  local rk, rn = nil, 0
  for i, cnt in pairs(rocks) do if cnt > rn or (cnt == rn and i < rk) then rk, rn = i, cnt end end
  local planet = require("gen.levels.planet")
  out.rock = rk and planet.ROCKS[rk].name or "granite"
  out.rock_color = rk and planet.ROCKS[rk].color or { 168, 150, 146 }
  -- the living things of its biomes
  local L = P.life
  if L and L.by_biome then
    for b in pairs(out.biomes) do
      for _, id in ipairs(L.by_biome[b] or {}) do out.species[#out.species + 1] = L.species[tonumber(id:sub(2))] end
    end
  end
  table.sort(out.species, function(a, b) return tonumber(a.id:sub(2)) < tonumber(b.id:sub(2)) end)
  return out
end

-- Funeral kinds and what the land must offer for each.
T.FUNERALS = {
  earth = { needs = function(r) return r.soil >= 0.4 end, text = "burial in the earth" },
  sky = { needs = function(r, s) return r.mountains >= 0.12 or s.anatomy.wings end,
          text = "laying the dead out on high places for the sky and its birds" },
  sea = { needs = function(r, _, P) return r.coast >= 0.12 and P.water == "liquid" end, text = "giving the dead to the sea" },
  fire = { needs = function(r) return r.forest >= 0.12 end, text = "burning on a pyre" },
  ossuary = { needs = function() return true end, text = "laying the bones in a hall of the dead" },
  tree = { needs = function(r) return r.forest >= 0.3 end, text = "burial among the roots of a sacred tree" },
}
local AFTERLIFE_FUNERAL = {
  ["the dead return to the sea"] = "sea", ["souls fly up into the sky"] = "sky", ["the dead join the ancestors' hall"] = "ossuary",
  ["souls are born again"] = "fire", ["the dead return with the spring"] = "tree", ["souls join the river of stars"] = "fire",
}

local function pick_species(rng, list, pred)
  local ok = {}
  for _, sp in ipairs(list) do if pred(sp) then ok[#ok + 1] = sp end end
  return #ok > 0 and ok[rng:int(1, #ok)] or nil
end

-- Rites, funerals, food customs and taboos of a culture of species s in
-- region r, with religion rel. `fact(text)` records a cause of the land.
function T.customs(rng, P, s, r, rel, fact)
  local out = { rites = {}, funerals = {}, food = {}, taboos = {} }
  -- rites of passage
  local adult = math.max(2, math.floor(s.lifespan * 0.18 + 0.5))
  out.rites[#out.rites + 1] = { name = s.reproduction == "eggs" and "the hatching" or
                                       (s.reproduction == "budding" and "the parting" or "the naming"),
                                text = s.reproduction == "eggs" and "the family keeps watch until the egg hatches" or
                                       (s.reproduction == "budding" and "the bud is given its own name when it parts" or
                                        "a child is named on its first new moon") }
  out.rites[#out.rites + 1] = { name = "coming of age", age = adult,
                                text = "at " .. adult .. " years the young " .. (r.mountains > 0.15 and "climb to the high cairn" or
                                       (r.coast > 0.2 and "swim out to the far rock" or "spend a night alone in the wild")) }
  if s.social ~= "hive" then
    out.rites[#out.rites + 1] = { name = s.social == "pair-bonded" and "pairing vows" or "joining the clan",
                                  text = s.social == "pair-bonded" and "partners exchange feathers, shells or stones" or
                                         "a newcomer shares a meal with every household" }
  end
  -- funerals: what the land allows, steered by the afterlife
  local allowed = {}
  for kind, f in pairs(T.FUNERALS) do if f.needs(r, s, P) then allowed[#allowed + 1] = kind end end
  table.sort(allowed)
  local want = AFTERLIFE_FUNERAL[rel.doctrine.afterlife]
  local first
  for _, k in ipairs(allowed) do if k == want then first = k end end
  first = first or allowed[rng:int(1, #allowed)]
  local because = { rel.fact }
  if r.mountains >= 0.12 then because[#because + 1] = fact("high mountains") end
  if r.soil < 0.4 then because[#because + 1] = fact("thin soil") end
  if r.coast >= 0.12 then because[#because + 1] = fact("long coasts") end
  out.funerals[1] = { kind = first, text = T.FUNERALS[first].text, because = because }
  if #allowed > 1 and rng:chance(0.4) then
    local other = allowed[rng:int(1, #allowed)]
    if other ~= first then out.funerals[2] = { kind = other, text = T.FUNERALS[other].text, because = because } end
  end
  -- food: from the living things of the land
  local crop = pick_species(rng, r.species, function(x) return x.kind == "plant" and (x.form == "herb" or x.form == "shrub") end)
  local beast = pick_species(rng, r.species, function(x) return x.role == "grazer" end)
  if crop and s.diet ~= "carnivore" then
    out.food[#out.food + 1] = { text = "bread and porridge of " .. crop.name, species = crop.id }
  end
  if beast then
    out.food[#out.food + 1] = { text = (s.diet == "herbivore" and "the milk of " or "herds of ") .. beast.name, species = beast.id }
  end
  if r.coast >= 0.12 and P.water == "liquid" then out.food[#out.food + 1] = { text = "fish from the shallows" } end
  if r.dry >= 0.2 then
    out.food[#out.food + 1] = { text = "water is shared before any food is eaten", because = { fact("deserts") } }
    out.water_sharing = true
  end
  -- taboos with their reasons: a sacred beast, a dangerous one, doctrine
  local sacred = pick_species(rng, r.species, function(x) return x.kind == "animal" and x.role ~= "predator" end)
  if sacred and rel.deities[1] then
    out.taboos[#out.taboos + 1] = { what = "eating the " .. sacred.name, species = sacred.id,
                                    reason = "it is sacred to " .. rel.deities[1].name, because = { rel.fact } }
  end
  local danger = pick_species(rng, r.species, function(x) return x.gift ~= nil or x.role == "predator" end)
  if danger and rng:chance(0.6) then
    out.taboos[#out.taboos + 1] = { what = "eating the " .. danger.name, species = danger.id,
                                    reason = danger.gift and "its flesh is strange with magic" or "it eats the dead" }
  end
  for _, t in ipairs(rel.doctrine.taboos) do
    out.taboos[#out.taboos + 1] = { what = t, reason = "the teaching of " .. rel.name, because = { rel.fact } }
  end
  return out
end

-- Adds a holiday commemorating an event {name, t (days from the year's
-- start), fact} to a culture's calendar; returns the holiday.
function T.commemorate(culture, event)
  local cal = culture.calendar
  local t = event.t % cal.year
  local h = { name = "Remembrance of " .. event.name, meaning = "the day of " .. event.name, t = dm.round(t, 3),
              day = math.floor(t / cal.day_length) + 1, kind = "commemoration", because = event.fact }
  cal.holidays[#cal.holidays + 1] = h
  table.sort(cal.holidays, function(a, b) return a.t < b.t end)
  return h
end

return T
