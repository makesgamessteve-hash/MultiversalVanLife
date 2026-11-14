-- A gallery of one living world's voxel plants and animals, against a plain
-- blue backdrop: every model shows up, models are deterministic (the same
-- species builds the same grid) and different body plans look different.
G.freeze()
local gen = require("gen")
gen.planet.LEVEL = 3
local R = gen.run.new(gen.cosmos, { seed = 31, mods = {} })
local HAB = gen.life.habitats
local CR = require("gen.visuals.creatures")
local PL = require("gen.visuals.plants")
local cache = require("gen.visuals.models").new({ budget = 1000 })

local planet
for s = 0, 300 do
  local saddr = "u" .. (1 + s % 7) .. ".g" .. (s % 11) .. ".c" .. (s % 3) .. ".s" .. (s % 5)
  local ok, sys = pcall(R.generate, R, saddr)
  if ok then
    for i = 0, sys.data.planets - 1 do
      if not planet and sys.children[i].kind == "rocky" then
        local p = R:generate(saddr .. ".p" .. i)
        if p.data.life and p.data.life.complexity == "animals" then planet = p end
      end
    end
  end
  if planet then break end
end
test.expect(planet, "a world with plants and animals")
local L = planet.data.life
mvl.environment({ sky_top = { 0, 0, 1 }, sky_horizon = { 0, 0, 1 }, fog_color = { 0, 0, 1 }, fog_near = 400, fog_far = 500,
                  ambient = { 1, 1, 1 }, stars = 0 })
mvl.sky({})
-- four plants with different forms, four animals with different body plans
local plants, animals, forms, plans = {}, {}, {}, {}
for _, sp in ipairs(L.species) do
  if sp.kind == "plant" and #plants < 4 and not forms[sp.form .. sp.leaf] then
    plants[#plants + 1], forms[sp.form .. sp.leaf] = sp, true
  elseif sp.kind == "animal" and #animals < 4 and not plans[sp.lineage] then
    animals[#animals + 1], plans[sp.lineage] = sp, true
  end
end
test.expect(#plants >= 2 and #animals >= 2, "several plant forms and animal body plans")
local hashes = {}
for i, sp in ipairs(plants) do
  local p = HAB.model(L, sp, planet.seed)
  local m = cache:acquire(p)
  test.expect(m and m.mesh > 0, "plant model built")
  local _, again = PL.mesh(p)
  test.eq(again, m.hash, "a plant model is the same every time it is built")
  hashes[m.hash] = true
  local sc = 1.6 / math.max(sp.height, 0.3)
  mvl.spawn({ mesh = m.mesh, pos = { -4.5 + (i - 1) * 3, 0, -9 }, scale = { sc, sc, sc }, unlit = true })
end
for i, sp in ipairs(animals) do
  local p = HAB.model(L, sp, planet.seed)
  local m = cache:acquire(p)
  test.expect(m and m.merged > 0 and m.body > 0, "animal model built")
  local again = CR.build(p)
  test.eq(again.hash, m.hash, "an animal model is the same every time it is built")
  CR.release(again)
  test.expect(not hashes[m.hash], "different species, different models")
  hashes[m.hash] = true
  local sc = 1.3 / math.max(sp.size, 0.2)
  mvl.spawn({ mesh = m.merged, pos = { -4.5 + (i - 1) * 3, 0, -6 }, yaw = -0.7, scale = { sc, sc, sc }, unlit = true })
end
mvl.camera(0, 2.2, -1, 0, -0.3, 70)
test.wait(3)
test.screenshot("gallery.tga")
test.wait(2)
local before = mvl.mesh_count()
cache:clear()
test.expect(mvl.mesh_count() < before, "released models free their meshes")
