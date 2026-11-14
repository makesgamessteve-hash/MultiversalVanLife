-- Multiversal Van Life - the lore of a land, for quests and dialogue (MIT).
--
-- A stored land must speak without its planet, so generation keeps a short
-- summary of what its people know and say: the culture and nation, the
-- country, their faith's gods (and which of them is the moon), its saint,
-- holidays, a greeting in their language, the word for a stranger, the
-- beasts and plants around, the versions of history they tell and the news
-- of the day (the land's tensions).
local language = require("gen.culture.language")

local Lore = {}

-- The greeting of a culture: two words of its language and what they mean.
local function greeting(cul)
  local v = cul.values or {}
  local sky = ({ "dawn", "light", "sun", "day" })[mvl.hash(cul.name, "greet") % 4 + 1]
  local kin = (v.hierarchy or 0) > 0.6 and "guest" or ((v.hospitality or 0) > 0.5 and "friend" or "kin")
  local a, b = language.word(cul.language, sky), language.word(cul.language, kin)
  if not a or not b then return nil end
  local w = a:sub(1, 1):upper() .. a:sub(2) .. " " .. b
  return { word = w, meaning = sky .. " to you, " .. kin }
end

-- The lore of land data `d` of country `country` (summary), people `cul`
-- (or nil) on planet data `P`.
function Lore.build(d, cul, P, country)
  local L = { place = d.name, country = d.country or (country and country.name), nation = d.nation, news = {} }
  for i, t in ipairs(d.tensions or {}) do
    if i <= 3 then L.news[#L.news + 1] = t.text end
  end
  for _, h in ipairs(d.habitats or {}) do
    for _, a in ipairs(h.animals) do
      L.beasts = L.beasts or {}
      if #L.beasts < 3 then L.beasts[#L.beasts + 1] = a.name end
    end
    for _, p in ipairs(h.plants) do
      L.plants = L.plants or {}
      if #L.plants < 3 then L.plants[#L.plants + 1] = p.name end
    end
  end
  if not cul then return L end
  L.culture, L.species = cul.name, cul.species
  local rel = P.religions and P.religions[cul.religion]
  if rel then
    L.faith = rel.name
    L.deities = {}
    for _, g in ipairs(rel.deities) do
      L.deities[#L.deities + 1] = g.name
      if not L.moon_deity and g.domain and g.domain:find("moon") then L.moon_deity = g.name end
    end
    if #L.deities == 0 then L.deities = nil end
    L.saint = rel.founder and rel.founder.name
    L.virtue = rel.doctrine and rel.doctrine.virtues[1]
  end
  local seen = {}
  for _, h in ipairs(cul.calendar and cul.calendar.holidays or {}) do
    if not seen[h.name] then
      seen[h.name] = true
      L.holidays = L.holidays or {}
      if #L.holidays < 3 then L.holidays[#L.holidays + 1] = h.name end
    end
  end
  -- names for people who come later (newcomers, the people of new troubles)
  L.names = {}
  for i = 1, 4 do
    local n = language.name(cul.language, mvl.rng(mvl.hash(d.name, "newcomer", i)), "person")
    L.names[i] = { name = n.name, meaning = n.meaning }
  end
  L.greeting = greeting(cul)
  L.stranger = language.word(cul.language, "stranger")
  L.memory = {}
  for _, m in ipairs(cul.memory or {}) do
    if m.rule ~= "as it was" and #L.memory < 4 then L.memory[#L.memory + 1] = m.told end
  end
  if #L.memory == 0 then L.memory = nil end
  return L
end

return Lore
