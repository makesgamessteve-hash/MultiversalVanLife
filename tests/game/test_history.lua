-- History: time scales, chronology, culture hooks, borders, individuals and
-- their lifespans, eras and their snapshots, and a quiet Prime.
local gen = require("gen")
local L = gen.culture.language
gen.planet.LEVEL = 3
local G = gen.run.new(gen.cosmos, { seed = 31, mods = {} })

local planets, galaxies = {}, {}
for s = 0, 600 do
  local saddr = "u" .. (1 + s % 9) .. ".g" .. (s % 13) .. ".c" .. (s % 3) .. ".s" .. (s % 5)
  local ok, sys = pcall(G.generate, G, saddr)
  if ok then
    local gal = G:node(saddr:match("^(u%d+%.g%d+)"))
    if gal.data.history then galaxies[gal.address] = gal end
    for i = 0, sys.data.planets - 1 do
      if sys.children[i].kind == "rocky" then
        local p = G:generate(saddr .. ".p" .. i)
        if p.data.history then planets[#planets + 1] = p end
      end
    end
  end
  if #planets >= 40 then break end
end
test.expect(#planets >= 25, "planets with history: " .. #planets)

-- ---------------------------------------------------------- time scales
local function span(h) return -h.start end
local function median_gap(h)
  local gaps = {}
  for i = 2, #h.events do gaps[#gaps + 1] = h.events[i].year - h.events[i - 1].year end
  table.sort(gaps)
  return gaps[math.max(1, math.floor(#gaps / 2))] or 0
end
local gal
for _, g in pairs(galaxies) do if #g.data.history.events >= 5 then gal = g end end
test.expect(gal, "a galaxy with a history")
local ph = planets[1].data.history
test.eq(gal.data.history.step, 1000, "galaxies count in thousands of years")
test.eq(ph.step, 25, "planets in generations")
test.expect(span(gal.data.history) > 20 * span(ph), "a galaxy's history spans far longer")
test.expect(median_gap(gal.data.history) > 10 * math.max(1, median_gap(ph)), "with coarser events")
local u = G:node("u1")
test.expect(u.data.history and u.data.history.step == 1e8, "universes count in hundreds of millions of years")

-- -------------------------------------------- chronology over many seeds
for seed = 1, 200 do
  local R = gen.run.new(gen.cosmos, { seed = seed, mods = {} })
  local g = R:generate("u" .. (1 + seed % 9) .. ".g" .. (seed % 7))
  local h = g.data.history
  if h then
    for i = 2, #h.events do
      test.expect(h.events[i].year >= h.events[i - 1].year - h.step, "events in order")
    end
  end
  if seed % 20 == 0 then test.eq(#gen.check.run(R), 0, "the chronology checker passes for seed " .. seed) end
end
test.eq(#gen.check.run(G), 0, "the checker passes: chronology, lifespans, causes, promises")

-- ------------------------------------------------------- culture hooks
local splits, commemorations, schisms = 0, 0, 0
for _, p in ipairs(planets) do
  local d = p.data
  for _, c in ipairs(d.cultures) do
    if c.parent then
      splits = splits + 1
      test.expect(L.kinship(c.language, d.cultures[c.parent].language) > 0.35, "a breakaway culture speaks a daughter language")
    end
    for _, h in ipairs(c.calendar.holidays) do
      if h.kind == "commemoration" then
        commemorations = commemorations + 1
        local f = p.facts[h.because]
        test.expect(f and f.kind == "event" and h.name:find(f.data.name, 1, true), "a holiday remembers its event")
      end
    end
  end
  for _, r in ipairs(d.religions) do
    if r.schism then
      schisms = schisms + 1
      test.expect(p.facts[r.schism].data.kind == "schism", "a new faith comes from a schism")
    end
  end
end
test.expect(splits > 0, "revolutions split cultures: " .. splits)
test.expect(commemorations > 0, "notable events are commemorated: " .. commemorations)
test.expect(schisms > 0, "schisms found faiths: " .. schisms)

-- ------------------------------------------------------ borders follow history
local held = 0
for _, p in ipairs(planets) do
  local h = p.data.history
  for id, c in ipairs(p.data.countries) do
    local fid = h.territories[id]
    if fid then
      held = held + 1
      test.eq(c.nation, h.factions[fid].name, "a country belongs to the nation holding it")
      test.eq(c.culture, h.factions[fid].culture, "and to its people")
    else
      test.expect(c.nation == nil, "unheld countries are wild")
    end
  end
end
test.expect(held > 20, "countries held at the present: " .. held)
-- a land of a held country
local land
for _, p in ipairs(planets) do
  for id, c in ipairs(p.data.countries) do
    if c.nation and not land then
      local country = G:generate(p.address .. ".k" .. (c.continent - 1) .. ".n" .. c.index)
      test.eq(country.summary.nation, c.nation, "the country's summary names its nation")
      for l = 0, 255, 9 do
        local gx, gz = gen.land.grid(l)
        if gen.land.raw_height(country.data.terrain, gx * 2048, gz * 2048) > 3 then
          land = G:generate(country.address .. ".l" .. l)
          test.eq(land.data.nation, c.nation, "its lands belong to the nation")
          break
        end
      end
    end
  end
end
test.expect(land, "a land of a nation")

-- ----------------------------------------------------- individuals
local people = 0
for _, p in ipairs(planets) do
  local h = p.data.history
  for _, ind in ipairs(h.individuals) do
    people = people + 1
    local s
    for _, x in ipairs(p.data.life.sapients) do if x.name == ind.species then s = x end end
    for _, x in ipairs(p.data.life.colonists or {}) do if x.name == ind.species then s = x end end
    if s then
      test.expect((ind.died or 0) - ind.born <= s.lifespan * 1.2 + 1, "nobody outlives their species")
    end
    test.expect(ind.died == nil or ind.died > ind.born, "born before they die")
  end
end
test.expect(people > 50, "history has its people: " .. people)

-- ------------------------------------------------------------ eras
local fallen = 0
for _, p in ipairs(planets) do
  local h = p.data.history
  for _, ev in ipairs(h.events) do
    if ev.kind == "collapse" then
      local fid = ev.participants[1]
      -- the era before the fall still shows the kingdom and its ruler
      local before
      for _, era in ipairs(h.eras) do if era.to < ev.year then before = era end end
      if before then
        local had = false
        for _, o in pairs(before.territories) do if o == fid then had = true end end
        if had then
          fallen = fallen + 1
          test.expect(before.rulers[fid], "the stored era names the fallen kingdom's ruler")
        end
      end
    end
  end
  test.expect(#h.eras >= 2, "a history is stored as eras")
  for _, era in ipairs(h.eras) do test.expect(era.name and era.to >= era.from and era.territories, "named eras with snapshots") end
end
test.expect(fallen > 0, "the past state of fallen kingdoms is kept: " .. fallen)

-- ------------------------------------------------------- quiet Prime
for _, addr in ipairs({ "u0", gen.prime.GALAXY, gen.prime.NEIGHBOURHOOD, gen.prime.EARTH }) do
  test.expect(not G:generate(addr).data.history, "no history in Prime: " .. addr)
end
for _, node in pairs(G.nodes) do
  for _, ev in ipairs(node.data.history and node.data.history.events or {}) do
    for _, a in ipairs(ev.addresses or {}) do
      test.expect(not gen.prime.inside(a), "no event refers to Prime")
    end
  end
end
test.expect(u.data.history.lore:find("quiet worlds", 1, true), "lore remembers the quiet worlds")

-- --------------------------------------------------------------- bible
local md = gen.bible.export(G, planets[1].address)
test.expect(md:find("History (planet", 1, true) and md:find("Powers today", 1, true), "the bible tells the history")
