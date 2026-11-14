-- Multiversal Van Life - religions: motifs from what a people sees and
-- lives through, deities or principles, doctrines, clergy, sacred sites
-- (MIT).
--
-- Every motif has a source on the people's world (the sky, the land, their
-- biology, magic and psionics) and a test of how strongly that source is
-- felt there; a religion takes the strongest motifs (with a little chance)
-- and keeps `because` links to facts recording each source ("two moons",
-- "volcanoes"). Its deities are named in the founders' language. In
-- universes whose gods are real, the deities of a widely followed religion
-- are real and can act in history.
local dm = require("gen.dmath")
local language = require("gen.culture.language")

local R = {}

-- What a world shows its people (from planet data, species and laws).
function R.conditions(P, s, laws)
  local sky = P.sky or { moons = {}, star = { size = 0.02 }, atmosphere = { haze = 0 }, band = { strength = 0 } }
  local moons, big = #sky.moons, 0
  for _, m in ipairs(sky.moons) do big = math.max(big, m.size) end
  local eclipses = moons > 0 and big >= sky.star.size * 0.8
  local planet = require("gen.levels.planet")
  local volcanic, desert, cells = 0, 0, P.cells
  if cells and cells.setting then
    local arc = planet.SETTING["volcanic arc"]
    for i = 1, #cells.setting do if cells.setting[i] == arc and cells.elevation[i] > 0 then volcanic = volcanic + 1 end end
    volcanic = volcanic / #cells.setting
  end
  for b, n in pairs(P.biome_counts or {}) do
    if b == "hot desert" or b == "cold desert" then desert = desert + n end
  end
  desert = cells and desert / #cells.elevation or 0
  local a = s.anatomy
  return {
    moons = moons, big_moon = big, eclipses = eclipses, star = P.star_class or "G", locked = P.locked,
    haze = sky.atmosphere.haze or 0, band = sky.band.strength or 0, volcanic = volcanic, desert = desert,
    rivers = #(P.rivers or {}), ocean = P.ocean or 0, sea = P.water == "liquid", tilt = P.tilt or 0,
    highest = P.highest or 0, lifespan = s.lifespan, reproduction = s.reproduction, social = s.social,
    diet = s.diet, wings = a.wings, magic = laws.magic, magic_strength = laws.magic_strength or 0,
    psionics = laws.psionics or 0,
  }
end

-- Motifs: source, salience for conditions c (0 = absent), a deity (two
-- meanings for its name) or a principle, and what it adds to doctrine.
R.MOTIFS = {
  { id = "twin moon gods", source = "two moons", sky = true, deity = { "twin", "god" },
    test = function(c) return c.moons == 2 and 0.9 or 0 end, sites = "stone circles", virtue = "balance" },
  { id = "moon pantheon", source = "many moons", sky = true, deity = { "moon", "kin" },
    test = function(c) return c.moons >= 3 and 0.85 or 0 end, sites = "stone circles", virtue = "harmony" },
  { id = "moon mother", source = "the moon", sky = true, deity = { "moon", "mother" },
    test = function(c) return c.moons == 1 and (0.35 + c.big_moon * 6) or 0 end, sites = "hilltops", virtue = "patience" },
  { id = "eclipse omens", source = "eclipses", sky = true, principle = "eclipses are omens of change",
    test = function(c) return c.eclipses and (0.4 + 0.15 * c.moons) or 0 end, taboo = "looking at an eclipse" },
  { id = "ember sun", source = "a dim red sun", sky = true, deity = { "ember", "father" },
    test = function(c) return c.star == "M" and 0.75 or 0 end, virtue = "endurance" },
  { id = "burning eye", source = "a fierce white sun", sky = true, deity = { "sun", "lord" },
    test = function(c) return (c.star == "O" or c.star == "B" or c.star == "A") and 0.75 or 0 end, virtue = "humility" },
  { id = "sun father", source = "the sun", sky = true, deity = { "sun", "father" },
    test = function(c) return (c.star == "G" or c.star == "K" or c.star == "F") and 0.45 or 0 end, virtue = "generosity" },
  { id = "eternal noon", source = "a sun that never moves", sky = true, principle = "the twilight band is holy ground",
    test = function(c) return c.locked and 0.8 or 0 end, sites = "twilight cairns" },
  { id = "river of stars", source = "the galaxy's band", sky = true, deity = { "star", "mother" },
    test = function(c) return (c.band > 0.35 and c.haze < 0.5) and 0.4 or 0 end, afterlife = "souls join the river of stars" },
  { id = "veiled heaven", source = "a sky without stars", sky = true, principle = "the heavens are hidden from the unworthy",
    test = function(c) return c.haze > 0.6 and 0.6 or 0 end },
  { id = "fire mother", source = "volcanoes", deity = { "fire", "mother" },
    test = function(c) return c.volcanic > 0.01 and math.min(0.9, 0.3 + c.volcanic * 20) or 0 end, sites = "volcano slopes",
    taboo = "quenching a hearth fire" },
  { id = "flood father", source = "great rivers", deity = { "river", "father" },
    test = function(c) return c.rivers >= 6 and 0.55 or (c.rivers >= 3 and 0.3 or 0) end, sites = "river springs" },
  { id = "sea mother", source = "the sea", deity = { "sea", "mother" },
    test = function(c) return (c.sea and c.ocean > 0.4) and (0.3 + c.ocean * 0.5) or 0 end, sites = "shore shrines",
    afterlife = "the dead return to the sea" },
  { id = "sacred water", source = "deserts", principle = "water is holy and must be shared",
    test = function(c) return c.desert > 0.15 and math.min(0.8, c.desert * 2) or 0 end, taboo = "wasting water",
    virtue = "hospitality" },
  { id = "dying god", source = "hard seasons", deity = { "winter", "lord" },
    test = function(c) return c.tilt > 25 and 0.55 or 0 end, afterlife = "the dead return with the spring" },
  { id = "sky mountain", source = "the highest peaks", deity = { "peak", "elder" },
    test = function(c) return c.highest > 8 and 0.45 or 0 end, sites = "mountaintops" },
  { id = "rebirth", source = "short lives", principle = "every soul is born again",
    test = function(c) return c.lifespan < 50 and 0.7 or 0 end, afterlife = "souls are born again" },
  { id = "ancestors", source = "long lives", principle = "the elders who went before still guide the living",
    test = function(c) return c.lifespan > 140 and 0.65 or 0 end, afterlife = "the dead join the ancestors' hall",
    virtue = "respect" },
  { id = "world egg", source = "birth from eggs", deity = { "egg", "mother" },
    test = function(c) return c.reproduction == "eggs" and 0.4 or 0 end },
  { id = "the divider", source = "birth by budding", principle = "every self is a part of one first self",
    test = function(c) return c.reproduction == "budding" and 0.55 or 0 end },
  { id = "queen mother", source = "the hive", deity = { "queen", "mother" },
    test = function(c) return c.social == "hive" and 0.75 or 0 end, virtue = "duty" },
  { id = "the great hunt", source = "a hunter's body", deity = { "hunter", "lord" },
    test = function(c) return c.diet == "carnivore" and 0.5 or 0 end, virtue = "courage" },
  { id = "soul wings", source = "wings", principle = "the soul is a bird that leaves the body",
    test = function(c) return c.wings and 0.55 or 0 end, afterlife = "souls fly up into the sky" },
  { id = "green flame", source = "the magic of life", deity = { "life", "spirit" },
    test = function(c) return c.magic == "life" and c.magic_strength * 0.9 or 0 end, sites = "groves" },
  { id = "star touched", source = "the magic of the stars", deity = { "star", "spirit" },
    test = function(c) return c.magic == "stellar" and c.magic_strength * 0.9 or 0 end, sites = "observatories" },
  { id = "stone blood", source = "the magic of the deep earth", deity = { "stone", "spirit" },
    test = function(c) return c.magic == "tectonic" and c.magic_strength * 0.9 or 0 end, sites = "caves" },
  { id = "the dreamed gods", source = "the magic of belief", principle = "what many believe becomes true",
    test = function(c) return c.magic == "belief" and c.magic_strength * 0.95 or 0 end },
  { id = "shared mind", source = "minds that touch", principle = "all minds are one mind dreaming",
    test = function(c) return c.psionics > 0.5 and c.psionics * 0.7 or 0 end },
}
R.MOTIF = {}
for _, m in ipairs(R.MOTIFS) do R.MOTIF[m.id] = m end

local CLERGY = { hive = "brood-priests", pack = "shamans", clan = "shamans", herd = "elders", solitary = "hermit sages",
                 ["pair-bonded"] = "priestly couples" }

-- A religion for species s on planet data P, named in language lang.
-- `fact(source)` returns the id of a fact recording a motif's source.
function R.generate(rng, P, s, laws, lang, fact)
  local c = R.conditions(P, s, laws)
  local scored = {}
  for _, m in ipairs(R.MOTIFS) do
    local v = m.test(c)
    if v > 0 then scored[#scored + 1] = { m = m, v = v * (0.75 + rng:next() * 0.5) } end
  end
  table.sort(scored, function(a, b) return a.v > b.v or (a.v == b.v and a.m.id < b.m.id) end)
  local motifs, because = {}, {}
  for i = 1, math.min(#scored, rng:int(2, 4)) do
    if scored[i].v > 0.2 then
      local m = scored[i].m
      local f = fact(m.source)
      motifs[#motifs + 1] = { id = m.id, source = m.source, because = f }
      because[#because + 1] = f
    end
  end
  if #motifs == 0 then
    motifs[1] = { id = "ancestors", source = "the dead", because = fact("the dead") }
    because[1] = motifs[1].because
  end
  local deities, principles, virtues, sites, taboos = {}, {}, {}, {}, {}
  local afterlife
  for _, x in ipairs(motifs) do
    local m = R.MOTIF[x.id]
    if m.deity then
      local n = language.name(lang, rng, "god", { m.deity[1], m.deity[2], format = "%s %s" })
      deities[#deities + 1] = { name = n.name, meaning = n.meaning, domain = m.source, motif = m.id }
    end
    if m.principle then principles[#principles + 1] = m.principle end
    if m.virtue then virtues[#virtues + 1] = m.virtue end
    if m.sites then sites[#sites + 1] = m.sites end
    if m.taboo then taboos[#taboos + 1] = m.taboo end
    afterlife = afterlife or m.afterlife
  end
  local form
  if #deities == 0 then form = "philosophy"
  elseif #deities == 1 then form = "monotheism"
  else form = "pantheon" end
  local head = deities[1] and deities[1].name or language.name(lang, rng, "god").name
  local title = form == "philosophy" and ("the Way of " .. head) or ("the Faith of " .. head)
  local virtues2 = #virtues > 0 and virtues or { ({ "honesty", "patience", "courage", "kindness" })[rng:int(1, 4)] }
  local clergy = CLERGY[s.social] or "priests"
  for _, x in ipairs(motifs) do if R.MOTIF[x.id].sky then clergy = clergy == "priests" and "star-readers" or clergy end end
  return {
    name = title, form = form, motifs = motifs, deities = deities, principles = principles,
    doctrine = { virtues = virtues2, taboos = taboos, afterlife = afterlife or "the dead sleep in the earth" },
    clergy = clergy, sites = #sites > 0 and sites or { "shrines" }, because = because,
  }
end

-- A line for the bible.
function R.describe(r)
  local ms = {}
  for i, m in ipairs(r.motifs) do ms[i] = m.id .. " (from " .. m.source .. ")" end
  local ds = {}
  for i, d in ipairs(r.deities) do ds[i] = d.name .. " \"" .. d.meaning .. "\"" .. (d.real and " (real)" or "") end
  return string.format("%s, a %s: %s; %s; virtues: %s%s; %s; clergy: %s; sacred sites: %s.",
                       r.name:sub(1, 1):upper() .. r.name:sub(2), r.form, table.concat(ms, ", "),
                       #ds > 0 and ("gods: " .. table.concat(ds, ", ")) or ("teaching: " .. table.concat(r.principles, "; ")),
                       table.concat(r.doctrine.virtues, ", "),
                       #r.doctrine.taboos > 0 and ("; taboo: " .. table.concat(r.doctrine.taboos, ", ")) or "",
                       r.doctrine.afterlife, r.clergy, table.concat(r.sites, ", "))
end

return R
