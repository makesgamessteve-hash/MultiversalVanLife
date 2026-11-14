-- Multiversal Van Life - present-day tensions (MIT).
--
-- History ends in the present with troubles. A country's tensions follow
-- from its final state: droughts in dry lands (worse where the river is
-- dammed upstream by another nation), beasts from the wild near
-- settlements, a contested border where two nations' spheres of influence
-- overlap, feuds after recent wars, an old ruler and an uncertain
-- succession, a recent schism, an epidemic after a recent plague, failing
-- magic, a relic lost in old ruins. A land adds a local trouble of its own.
-- Every tension has a kind of quest it calls for, a severity, its causes
-- (facts and plain words) and the people it touches. A land's trouble and
-- the signals the van hears come from its strongest tension.
local dm = require("gen.dmath")

local T = {}

-- Which kind of quest each tension calls for (quest templates have kinds).
T.QUEST = {
  drought = "gather", famine = "gather", epidemic = "gather", incursion = "lost", ["contested border"] = "return",
  feud = "return", ["succession crisis"] = "relight", schism = "relight", ["failing magic"] = "relight",
  ["lost relic"] = "return", ["lost traveller"] = "lost", ["dark nights"] = "relight", ["broken machine"] = "gather",
  ["scattered heirlooms"] = "return",
}

local function event_of(h, kind, since, pred)
  local best
  for _, ev in ipairs(h.events) do
    if ev.kind == kind and ev.year >= since and (not pred or pred(ev)) then best = ev end
  end
  return best
end

-- Tensions of every country of a planet (data P) at the present.
function T.countries(P, pseed)
  local h = P.history
  if not h then return end
  local cells = P.cells
  local geo = require("gen.levels.geography")
  -- country climate and rivers
  local precip, n, river, upstream = {}, {}, {}, {}
  for i = 1, #cells.country do
    local c = cells.country[i]
    if c and c > 0 then
      precip[c] = (precip[c] or 0) + cells.precip[i]
      n[c] = (n[c] or 0) + 1
      if cells.river and cells.river[i] then river[c] = true end
      local to = cells.flow_to and cells.flow_to[i] or 0
      if to > 0 and cells.country[to] and cells.country[to] > 0 and cells.country[to] ~= c then
        upstream[cells.country[to]] = upstream[cells.country[to]] or {}
        upstream[cells.country[to]][c] = true
      end
    end
  end
  -- spheres of influence: a nation's countries and their neighbours
  local sphere = {}
  for id, owner in pairs(h.territories) do
    sphere[id] = sphere[id] or {}
    sphere[id][owner] = true
    for _, nb in ipairs(h.regions and h.regions[id] and h.regions[id].neighbours or {}) do
      sphere[nb] = sphere[nb] or {}
      sphere[nb][owner] = true
    end
  end
  for id, c in ipairs(P.countries) do
    local out = {}
    local owner = h.territories[id]
    local f = owner and h.factions[owner]
    local people = f and f.name or "the scattered folk"
    local rain = n[id] and precip[id] / n[id] or 1000
    if rain < 450 then
      local causes = { "little rain falls here (" .. math.floor(rain) .. " mm a year)" }
      local stake = { people }
      for up in pairs(upstream[id] or {}) do
        local o = h.territories[up]
        if o and o ~= owner and river[id] then
          causes[#causes + 1] = "the river is dammed upstream by " .. h.factions[o].name
          stake[#stake + 1] = h.factions[o].name
        end
      end
      out[#out + 1] = { kind = "drought", severity = dm.round(dm.clamp(0.4 + (450 - rain) / 900 + (#stake - 1) * 0.2, 0, 1), 3),
                        text = "the wells are drying up", causes = causes, stakeholders = stake }
    end
    -- contested border: inside the spheres of two nations
    local rivals = {}
    for fid in pairs(sphere[id] or {}) do if fid ~= owner and h.factions[fid].alive then rivals[#rivals + 1] = fid end end
    table.sort(rivals)
    if f and #rivals > 0 then
      local g = h.factions[rivals[1]]
      out[#out + 1] = { kind = "contested border", severity = 0.6, text = g.name .. " claims these lands",
                        causes = { "the lands of " .. f.name .. " and " .. g.name .. " meet here" },
                        stakeholders = { f.name, g.name } }
    end
    if f then
      local war = event_of(h, "war", -100, function(ev)
        for _, p in ipairs(ev.participants) do if p == owner then return true end end
      end)
      if war then
        out[#out + 1] = { kind = "feud", severity = 0.5, text = "old enmities from " .. war.name .. " still smoulder",
                          causes = { war.name }, cause_facts = { war.fact }, stakeholders = { f.name } }
      end
      local ruler = f.ruler and h.individuals[f.ruler]
      if ruler and not ruler.died and (0 - ruler.born) > ruler.lifespan * 0.75 then
        out[#out + 1] = { kind = "succession crisis", severity = 0.55,
                          text = ruler.name .. " is old and the heirs quarrel", causes = { ruler.name .. " grows old" },
                          cause_facts = { ruler.fact }, stakeholders = { ruler.name, f.name } }
      end
      local schism = event_of(h, "schism", -150, function(ev) return ev.participants[1] == owner end)
      if schism then
        out[#out + 1] = { kind = "schism", severity = 0.5, text = "the faithful are divided", causes = { schism.name },
                          cause_facts = { schism.fact }, stakeholders = { f.name } }
      end
    end
    local plague = event_of(h, "plague", -50)
    if plague then
      out[#out + 1] = { kind = "epidemic", severity = 0.6, text = "the sickness has come back", causes = { plague.name },
                        cause_facts = { plague.fact }, stakeholders = { people } }
    end
    -- beasts from the wild: predators of the country's lands
    local L = P.life
    if L and L.species then
      local biome
      for i = 1, #cells.country do
        if cells.country[i] == id then biome = geo.BIOMES[cells.biome[i]].id break end
      end
      for _, sid in ipairs(biome and L.by_biome[biome] or {}) do
        local sp = L.species[tonumber(sid:sub(2))]
        if sp.role == "predator" and sp.size > 0.8 then
          out[#out + 1] = { kind = "incursion", severity = dm.round(dm.clamp(0.3 + sp.size * 0.1, 0, 0.8), 3),
                            text = sp.name .. "s prowl close to the houses", causes = { sp.name .. " hunts nearby" },
                            species = sp.id, stakeholders = { people } }
          break
        end
      end
    end
    if P.magic and P.magic.source ~= "none" and (mvl.hash(pseed, id, "magic") % 4 == 0) then
      out[#out + 1] = { kind = "failing magic", severity = 0.45, text = "the old magic is fading",
                        causes = { "the " .. P.magic.source .. " magic weakens here" }, stakeholders = { people } }
    end
    if c.ruins then
      out[#out + 1] = { kind = "lost relic", severity = 0.4, text = "a relic was lost in " .. c.ruins,
                        causes = { c.ruins }, stakeholders = { people } }
    end
    table.sort(out, function(a, b) return a.severity > b.severity or (a.severity == b.severity and a.kind < b.kind) end)
    c.tensions = out
  end
end

local LOCAL = {
  { kind = "lost traveller", text = "someone did not come home", cause = "the paths are many and the nights long" },
  { kind = "dark nights", text = "the lights went out", cause = "the lamp oil ran short" },
  { kind = "broken machine", text = "the great machine broke down", cause = "it is old and nobody remembers how it works" },
  { kind = "scattered heirlooms", text = "treasured things were scattered", cause = "a storm tore through the village" },
}

-- The tensions of a land: its country's (none where no history was
-- made), plus a local trouble of its own. Sorted by severity (strongest
-- first); each has `quest`, its quest kind.
function T.for_land(P, country_id, land_seed)
  local c = P.countries and P.countries[country_id]
  if not c then return nil end
  local rng = mvl.rng(mvl.hash(land_seed, "tension"))
  local out = {}
  for _, t in ipairs(c.tensions or {}) do
    local x = {}
    for k, v in pairs(t) do x[k] = v end
    -- each land feels its country's troubles more or less
    x.severity = dm.round(dm.clamp(t.severity * (0.6 + rng:next() * 0.7), 0, 1), 3)
    out[#out + 1] = x
  end
  local l = LOCAL[rng:int(1, #LOCAL)]
  out[#out + 1] = { kind = l.kind, severity = dm.round(0.25 + rng:next() * 0.6, 3), text = l.text, causes = { l.cause },
                    stakeholders = { c.nation or "the villagers" }, local_trouble = true }
  table.sort(out, function(a, b) return a.severity > b.severity or (a.severity == b.severity and a.kind < b.kind) end)
  for _, t in ipairs(out) do t.quest = T.QUEST[t.kind] or "gather" end
  return out
end

-- The trouble template of a land at `addr` (planet and country generated
-- as needed), for signals and tests.
function T.trouble(G, addr)
  local quests = require("gen.quests")
  local address = require("gen.address")
  local seed = address.seed(G.seed, addr)
  local country = G:generate(address.parent(addr))
  local planet = G:generate(addr:match("^(.-%.p%d+)"))
  local list = T.for_land(planet.data, country.summary.id, seed)
  local tmpl = quests.choose(G.registry, seed, list and list[1].quest)
  return tmpl, list
end

return T
