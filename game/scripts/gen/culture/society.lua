-- Multiversal Van Life - values and society (MIT).
--
-- Five value axes (each from -1 to 1) grow from a people's social instinct,
-- its body and its land: hierarchy (or equality), honour (or harmony),
-- tradition (or innovation), the collective (or the individual) and
-- hospitality (or wariness). Harsh, dry lands make peoples hospitable and
-- careful with water; hunters prize honour; long lives keep traditions.
-- From the values follow the social structure, a few laws, how strangers
-- are met and the factions history will set against each other.
local dm = require("gen.dmath")
local language = require("gen.culture.language")

local S = {}
S.AXES = { "hierarchy", "honour", "tradition", "collective", "hospitality" }

local HIERARCHY = { hive = 0.8, pack = 0.45, clan = 0.3, herd = -0.1, ["pair-bonded"] = 0, solitary = -0.4 }
local COLLECTIVE = { hive = 0.9, herd = 0.5, clan = 0.3, pack = 0.3, ["pair-bonded"] = -0.1, solitary = -0.6 }
local HONOUR = { carnivore = 0.5, omnivore = 0.1, herbivore = -0.4 }

local function clamp(v) return dm.round(dm.clamp(v, -1, 1), 3) end

-- Values of species s in region r (from traditions.region) with religion rel.
function S.values(rng, s, r, rel)
  local harsh = math.max(r.dry, r.bare * 0.7)
  local predators = 0
  for _, sp in ipairs(r.species) do if sp.role == "predator" then predators = predators + 1 end end
  local courage = 0
  for _, v in ipairs(rel.doctrine.virtues) do if v == "courage" then courage = 0.2 end end
  local function jitter() return (rng:next() - 0.5) * 0.4 end
  return {
    hierarchy = clamp((HIERARCHY[s.social] or 0) + harsh * 0.2 + jitter()),
    honour = clamp((HONOUR[s.diet] or 0) + courage + jitter()),
    tradition = clamp((s.lifespan > 140 and 0.5 or (s.lifespan < 50 and -0.4 or 0)) + jitter()),
    collective = clamp((COLLECTIVE[s.social] or 0) + harsh * 0.2 + jitter()),
    hospitality = clamp(r.dry * 1.8 + r.bare * 0.25 - math.min(predators, 6) * 0.05 + (r.dry >= 0.2 and 0.25 or 0) - 0.1
                        + jitter()),
  }
end

-- Social structure, laws, strangers and factions from values.
function S.society(rng, v, s, rel, lang, customs)
  local structure
  if s.social == "hive" then structure = "a hive court around a queen"
  elseif v.hierarchy > 0.5 then structure = (rel.form ~= "philosophy" and rng:chance(0.5)) and "a theocracy" or "a monarchy"
  elseif v.hierarchy > 0.1 then structure = rng:chance(0.5) and "chiefdoms of great clans" or "noble houses"
  elseif v.tradition > 0 then structure = "councils of elders"
  else structure = "open assemblies" end
  local laws = {}
  if v.hospitality > 0.3 then laws[#laws + 1] = "a guest must be fed and sheltered for three days" end
  if customs.water_sharing then laws[#laws + 1] = "water may never be sold or refused" end
  if v.honour > 0.3 then laws[#laws + 1] = "insults are settled by a trial of courage" end
  if v.honour < -0.3 then laws[#laws + 1] = "quarrels go before a mediator" end
  if v.collective > 0.4 then laws[#laws + 1] = "the land belongs to all" end
  if v.collective < -0.3 then laws[#laws + 1] = "every grown person owns their own field" end
  if v.tradition > 0.4 then laws[#laws + 1] = "the old laws may not be changed" end
  if #laws == 0 then laws[1] = "the elders' word settles what custom does not" end
  local strangers = v.hospitality > 0.3 and "welcomed as guests" or
                    (v.hospitality < -0.3 and "watched with suspicion" or "met with polite caution")
  -- factions history will play with
  local factions = {}
  local kinds = { { "rulers", { "high", "hall" } }, { "faithful", { "holy", "temple" } },
                  { "traders", { "gold", "market" } }, { "commons", { "field", "people" } } }
  if s.social == "hive" then kinds[1] = { "rulers", { "queen", "hall" } } end
  for i, k in ipairs(kinds) do
    if i <= 2 or rng:chance(0.6) then
      local n = language.name(lang, rng, "place", { k[2][1], k[2][2], format = "the %s %s" })
      factions[#factions + 1] = { kind = k[1], name = n.name, meaning = n.meaning }
    end
  end
  return { structure = structure, laws = laws, strangers = strangers, factions = factions }
end

function S.describe(v)
  local parts = {}
  local names = { hierarchy = { "hierarchy", "equality" }, honour = { "honour", "harmony" },
                  tradition = { "tradition", "innovation" }, collective = { "the collective", "the individual" },
                  hospitality = { "hospitality", "wariness" } }
  for _, a in ipairs(S.AXES) do
    local x = v[a]
    if math.abs(x) >= 0.25 then parts[#parts + 1] = (x > 0 and names[a][1] or names[a][2]) end
  end
  return #parts > 0 and table.concat(parts, ", ") or "balance in all things"
end

return S
