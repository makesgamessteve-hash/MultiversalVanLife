-- Traditions, society and technology: lunar feasts on the right nights,
-- commemorations, funerals that fit the land, taboos with reasons,
-- hospitality born of scarcity, iron that needs iron and magic that
-- replaces machines.
local gen = require("gen")
local C = gen.culture
local L, CAL, T, S, TECH = C.language, C.calendar, C.traditions, C.society, C.technology
local sky = gen.sky
gen.planet.LEVEL = 3
local lang = L.generate(11, "lips", false)

-- ------------------------------------------------- lunar feasts on time
local H = { year = 365.25, day = 1, tilt = 23, locked = false, orbit = 1, sky = {
  longitude0 = 1.2, rotation0 = 0, star = { size = 0.02, color = { 1, 1, 1 } },
  moons = { { name = "A", period = 27.3, longitude0 = 0.4, size = 0.05, incline = 0.05, color = { 1, 1, 1 } },
            { name = "B", period = 9.7, longitude0 = 2.9, size = 0.03, incline = 0.02, color = { 1, 1, 1 } } },
  planets = {}, band = { normal = { 0, 0, 1 }, core = { 1, 0, 0 }, strength = 0.3, width = 0.1 },
  atmosphere = { haze = 0.1 } } }
local cal = CAL.generate(H, lang, mvl.rng(3), 1000)
test.eq(cal.kind, "lunisolar", "two moons and seasons make a lunisolar calendar")
test.eq(#cal.months, 12, "months follow the brighter moon (12 synodic months a year)")
local feasts = { 0, 0 }
for _, h in ipairs(cal.holidays) do
  test.expect(h.day >= 1 and h.day <= cal.days, "holidays fall inside the year")
  if h.kind == "full moon" then
    feasts[h.moon] = feasts[h.moon] + 1
    local at = sky.at(H, { latitude = 0, longitude = 0 }, CAL.when(cal, h))
    test.expect(at.moons[h.moon].lit > 0.98, "a lunar feast falls on a full moon of its moon: " .. at.moons[h.moon].lit)
  end
end
test.expect(feasts[1] >= 12 and feasts[2] >= 12, "both moons have their feasts: " .. feasts[1] .. ", " .. feasts[2])
local solstice
for _, h in ipairs(cal.holidays) do if h.kind == "midsummer" then solstice = h end end
local at = sky.at(H, { latitude = 45, longitude = 0 }, CAL.when(cal, solstice) + 0.5)
local at2 = sky.at(H, { latitude = 45, longitude = 0 }, CAL.when(cal, solstice) + 90.5)
test.expect(solstice and at.sun[2] > at2.sun[2], "midsummer's noon sun is higher than three months later")
-- a generated two-moon world with a people: its feasts too
local G = gen.run.new(gen.cosmos, { seed = 12, mods = {} })
local cultures = {}
for s = 0, 400 do
  local saddr = "u" .. (1 + s % 7) .. ".g" .. (s % 11) .. ".c" .. (s % 3) .. ".s" .. (s % 5)
  local ok, sys = pcall(G.generate, G, saddr)
  if ok then
    for i = 0, sys.data.planets - 1 do
      if sys.children[i].kind == "rocky" then
        local p = G:generate(saddr .. ".p" .. i)
        for _, c in ipairs(p.data.cultures or {}) do cultures[#cultures + 1] = { c = c, p = p } end
      end
    end
  end
  if #cultures >= 40 then break end
end
test.expect(#cultures >= 20, "many cultures: " .. #cultures)
for _, x in ipairs(cultures) do
  local Hp = sky.heavens(x.p.data)
  for _, h in ipairs(x.c.calendar.holidays) do
    if h.kind == "full moon" then
      local lit = sky.at(Hp, { latitude = 0, longitude = 0 }, CAL.when(x.c.calendar, h)).moons[h.moon].lit
      test.expect(lit > 0.97, "generated lunar feasts fall on full moons")
    end
  end
end

-- ---------------------------------------------------- commemorations
local culture = { calendar = cal }
local h = T.commemorate(culture, { name = "the Great Flood", t = 3 * cal.year + 100.5, fact = "x/flood/1" })
test.eq(h.kind, "commemoration", "a commemoration")
test.eq(h.day, 101, "on the flood's date")
test.eq(h.because, "x/flood/1", "linked to the event")
local found = false
for _, x in ipairs(cal.holidays) do if x == h then found = true end end
test.expect(found, "in the culture's calendar")

-- ------------------------------------------------------------ funerals
local function region(over)
  local r = { cells = 100, biomes = {}, resources = {}, species = {}, magic = 0, forest = 0.3, bare = 0, dry = 0,
              coast = 0.2, mountains = 0, soil = 0.9, biome = "grassland" }
  for k, v in pairs(over or {}) do r[k] = v end
  return r
end
local species = { anatomy = { wings = false, mouth = "lips" }, lifespan = 70, reproduction = "live young",
                  social = "clan", diet = "omnivore", senses = { "sight" } }
local rel = { fact = "x/religion/1", deities = { { name = "Ka" } }, name = "the Faith of Ka",
              doctrine = { virtues = { "courage" }, taboos = {}, afterlife = "the dead sleep in the earth" } }
local P = { water = "liquid" }
local function fact(text) return "x/omen/" .. text end
local earth = 0
for seed = 1, 100 do
  local cu = T.customs(mvl.rng(seed), P, species, region({ mountains = 0.6, soil = 0.2, bare = 0.8, forest = 0 }), rel, fact)
  for _, f in ipairs(cu.funerals) do test.expect(f.kind ~= "earth", "no burial in deep earth among bare mountains") end
  local cu2 = T.customs(mvl.rng(seed), P, species, region(), rel, fact)
  for _, f in ipairs(cu2.funerals) do if f.kind == "earth" then earth = earth + 1 end end
end
test.expect(earth > 5, "where soil is deep, some bury their dead: " .. earth)
-- the afterlife steers the funeral where the land allows
local sea_rel = { fact = "x/religion/2", deities = {}, name = "the Way", doctrine = { virtues = {}, taboos = {},
                  afterlife = "the dead return to the sea" } }
test.eq(T.customs(mvl.rng(1), P, species, region(), sea_rel, fact).funerals[1].kind, "sea", "sea faiths give the dead to the sea")

-- ------------------------------------------------- taboos with reasons
local taboos = 0
for _, x in ipairs(cultures) do
  local known = {}
  for _, sp in ipairs(x.p.data.life.species or {}) do known[sp.id] = sp end
  for _, tb in ipairs(x.c.customs.taboos) do
    taboos = taboos + 1
    local linked = (tb.species and known[tb.species]) or (tb.because and x.p.facts[tb.because[1]])
    test.expect(linked and tb.reason, "a taboo is linked to a local species or a doctrine: " .. tb.what)
  end
end
test.expect(taboos > 10, "cultures have taboos: " .. taboos)

-- --------------------------------------------------------------- scarcity
local desert, lush, sharing = 0, 0, 0
for seed = 1, 100 do
  local rd = region({ dry = 0.6, bare = 0.3, forest = 0, biome = "hot desert" })
  local v = S.values(mvl.rng(seed), species, rd, rel)
  local cu = T.customs(mvl.rng(seed), P, species, rd, rel, fact)
  if v.hospitality > 0.3 then desert = desert + 1 end
  if cu.water_sharing then sharing = sharing + 1 end
  local soc = S.society(mvl.rng(seed), v, species, rel, lang, cu)
  if v.hospitality > 0.3 then
    local guest = false
    for _, law in ipairs(soc.laws) do if law:find("guest") then guest = true end end
    test.expect(guest and soc.strangers == "welcomed as guests", "hospitable peoples feed their guests")
  end
  if S.values(mvl.rng(seed), species, region(), rel).hospitality > 0.3 then lush = lush + 1 end
end
test.expect(desert >= 85, "desert peoples are hospitable: " .. desert)
test.eq(sharing, 100, "and share water")
test.expect(lush < desert / 2, "more than peoples of green lands: " .. lush)

-- -------------------------------------------------------------- technology
local base = { crops = true, herd = true, draught = true, coast = true, air = 1, stability = 0.8, eras = 8,
               resources = { copper = true, tin = true, coal = true } }
local no_iron = TECH.reachable(base)
test.expect(no_iron.has.bronze, "copper and tin make bronze")
test.expect(not no_iron.has["iron working"], "no iron in the land and no trade: no iron working")
test.expect(no_iron.level <= 3, "and the culture stays in the bronze age")
local traded = TECH.reachable(setmetatable({ trade = { iron = true } }, { __index = base }))
test.expect(traded.has["iron working"], "iron bought from traders is worked")
local iron = TECH.reachable(setmetatable({ resources = { copper = true, tin = true, coal = true, iron = true } },
                                         { __index = base }))
test.expect(iron.has["iron working"] and iron.has.steel, "iron and coal at home: iron and steel")
-- magic instead of machines
local plain = TECH.reachable(setmetatable({ resources = { copper = true, tin = true, coal = true, iron = true }, eras = 12 },
                                          { __index = base }))
test.expect(plain.has.electricity and not plain.has.magelight, "without magic, electricity")
local magical = TECH.reachable(setmetatable({ resources = { copper = true, tin = true, coal = true, iron = true },
                                              eras = 12, magic = 0.9, source = "stellar", mineral = "starglass" },
                                            { __index = base }))
test.expect(magical.has.magelight and not magical.has.electricity, "strong magic replaces electricity with magelight")
test.eq(magical.replaced.electricity, "magelight", "the replacement is recorded")
test.expect(#magical.traditions >= 2, "magical traditions grow, including enchanted tools")
local some = TECH.reachable(setmetatable({ resources = { copper = true, tin = true, coal = true, iron = true },
                                           eras = 12, magic = 0.5, source = "life" }, { __index = base }))
test.expect(some.has.magelight and some.has.electricity, "common magic complements the machines")
local psi = TECH.reachable(setmetatable({ resources = { copper = true, tin = true, coal = true, iron = true },
                                          eras = 12, psionics = 0.8 }, { __index = base }))
test.expect(psi.has.farspeech and not psi.has.radio, "strong psionics replace radio with farspeech")
test.expect(TECH.reachable(setmetatable({ eras = 1 }, { __index = base })).level <= 1, "young cultures stay simple")

-- --------------------------------------------------------- the bible
local ref = cultures[1].p
local md = gen.bible.export(G, ref.address)
test.expect(md:find("Ways of life:", 1, true) and md:find("calendar of", 1, true) and md:find("Technology:", 1, true),
            "the bible describes calendars, customs, values and technology")
test.eq(#gen.check.run(G), 0, "the checker passes")
