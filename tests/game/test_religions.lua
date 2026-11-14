-- Religions: motifs from the sky, the land, biology and magic with their
-- causes, moon gods under two moons, variety, and real gods.
local gen = require("gen")
local R = gen.culture.religion
local L = gen.culture.language
gen.planet.LEVEL = 3

local function species(over)
  local s = { anatomy = { wings = false, mouth = "lips" }, lifespan = 80, reproduction = "live young", social = "clan",
              diet = "omnivore", senses = { "sight" } }
  for k, v in pairs(over or {}) do s[k] = v end
  return s
end
local function sky(moons, star)
  local list = {}
  for i = 1, moons do list[i] = { size = 0.05 + i * 0.01 } end
  return { moons = list, star = { size = star or 0.02 }, atmosphere = { haze = 0.1 }, band = { strength = 0.3 } }
end
local laws = { magic = "none", magic_strength = 0, psionics = 0, gods = "silent" }
local function causes()
  local n = 0
  return function(text) n = n + 1 return "/omen/" .. text end
end

-- ------------------------------------------------------------ moon gods
local twin, eclipse, plain_moon = 0, 0, 0
for seed = 1, 200 do
  local P = { sky = sky(2, 0.02), star_class = "G", tilt = 20, water = "liquid", ocean = 0.6 }
  local r = R.generate(mvl.rng(seed), P, species(), laws, L.generate(seed, "lips"), causes())
  for _, m in ipairs(r.motifs) do
    if m.id == "twin moon gods" then twin = twin + 1 end
    if m.id == "eclipse omens" then eclipse = eclipse + 1 end
  end
  local none = R.generate(mvl.rng(seed), { sky = sky(0), star_class = "G", tilt = 20 }, species(), laws,
                          L.generate(seed, "lips"), causes())
  for _, m in ipairs(none.motifs) do
    if m.id:find("moon") or m.id == "eclipse omens" then plain_moon = plain_moon + 1 end
  end
end
test.expect(twin >= 170, "two prominent moons: the religion features them (" .. twin .. " of 200)")
test.expect(eclipse >= 100, "and eclipses matter (" .. eclipse .. " of 200)")
test.eq(plain_moon, 0, "without moons, no moon gods")

-- ------------------------------------------------------- motif variety
local G = gen.run.new(gen.cosmos, { seed = 77, mods = {} })
local seen, religions, worlds = {}, 0, {}
for s = 0, 400 do
  local saddr = "u" .. (1 + s % 9) .. ".g" .. (s % 13) .. ".c" .. (s % 4) .. ".s" .. (s % 6)
  local ok, sys = pcall(G.generate, G, saddr)
  if ok then
    for i = 0, sys.data.planets - 1 do
      if sys.children[i].kind == "rocky" then
        local p = G:generate(saddr .. ".p" .. i)
        for _, r in ipairs(p.data.religions or {}) do
          religions = religions + 1
          worlds[#worlds + 1] = p
          for _, m in ipairs(r.motifs) do
            seen[m.id] = true
            local f = p.facts[m.because]
            test.expect(f and f.kind == "omen" and f.data.name == m.source, "each motif is linked to its cause")
          end
          test.expect(#r.deities > 0 or #r.principles > 0, "gods or teachings")
          test.expect(r.clergy and #r.sites > 0 and r.doctrine.afterlife, "clergy, sacred sites and an afterlife")
        end
      end
    end
  end
end
local n = 0
for _ in pairs(seen) do n = n + 1 end
test.expect(religions >= 30, "many religions: " .. religions)
test.expect(n >= 14, "motif variety: " .. n .. " different motifs")
-- synthetic worlds reach the rest: biology and magic
for _, case in ipairs({ { species({ social = "hive" }), "queen mother" }, { species({ anatomy = { wings = true } }), "soul wings" },
                        { species({ lifespan = 30 }), "rebirth" } }) do
  local found = false
  for seed = 1, 40 do
    local r = R.generate(mvl.rng(seed), { sky = sky(0), star_class = "K" }, case[1], laws, L.generate(seed, "lips"), causes())
    for _, m in ipairs(r.motifs) do if m.id == case[2] then found = true end end
  end
  test.expect(found, case[2] .. " arises from biology")
end
local magic = { magic = "tectonic", magic_strength = 0.9, psionics = 0, gods = "silent" }
local found = false
for seed = 1, 20 do
  local r = R.generate(mvl.rng(seed), { sky = sky(0), star_class = "K" }, species(), magic, L.generate(seed, "lips"), causes())
  for _, m in ipairs(r.motifs) do if m.id == "stone blood" then found = true end end
end
test.expect(found, "strong tectonic magic brings earth spirits")

-- ------------------------------------------------------------ real gods
local real, silent = 0, 0
for _, p in ipairs(worlds) do
  local u = G:node(p.address:match("^(u%d+)"))
  for _, r in ipairs(p.data.religions) do
    for _, d in ipairs(r.deities) do
      if d.real then
        real = real + 1
        test.eq(u.data.laws.gods, "real", "real gods only where the universe allows them")
        test.expect(r.countries >= 3, "only widely followed faiths have real gods")
        test.expect(p.facts[d.fact] and p.facts[d.fact].data.real, "a real deity is a fact history can use")
      elseif u.data.laws.gods == "real" and r.countries >= 3 then
        test.expect(false, "a widely followed faith in a universe of real gods has real gods")
      else
        silent = silent + 1
      end
    end
  end
end
test.expect(real > 0 and silent > 0, "real and silent gods both exist: " .. real .. ", " .. silent)

-- -------------------------------------------------- checker and bible
test.eq(#gen.check.run(G), 0, "the checker passes")
local md = gen.bible.export(G, worlds[1].address)
test.expect(md:find("Peoples:", 1, true) and md:find("Religions:", 1, true), "the bible describes peoples and religions")
