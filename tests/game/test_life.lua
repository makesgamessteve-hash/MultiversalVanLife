-- Trees of life: shared ancestry, adaptation to gravity, food chains,
-- names, intelligent species shaped by their ancestors, committed
-- homeworlds and colonies of spacefarers, the bible and the checker.
local gen = require("gen")
gen.planet.LEVEL = 3
local G = gen.run.new(gen.cosmos, { seed = 2024, mods = {} })

local living, systems = {}, {}
for s = 0, 240 do
  local saddr = "u" .. (1 + s % 9) .. ".g" .. (s % 13) .. ".c" .. (s % 4) .. ".s" .. (s % 6)
  local ok, sys = pcall(G.generate, G, saddr)
  if ok then
    systems[#systems + 1] = sys
    for i = 0, sys.data.planets - 1 do
      if sys.children[i].kind == "rocky" then
        local p = G:generate(saddr .. ".p" .. i)
        if p.data.life and p.data.life.species then living[#living + 1] = p end
      end
    end
  end
end
test.expect(#living > 40, "many living worlds: " .. #living)

-- --------------------------------------------------------- shared ancestry
local pairs_checked = 0
for _, p in ipairs(living) do
  local L = p.data.life
  local lineage = {}
  for _, l in ipairs(L.lineages) do lineage[l.id] = l end
  local first = {}
  for _, sp in ipairs(L.species) do
    test.expect(lineage[sp.lineage], "every species descends from a lineage of its world")
    if sp.kind == "animal" then
      local f = first[sp.lineage]
      if f then
        test.eq(sp.limbs, f.limbs, "same lineage, same limb count")
        test.eq(sp.covering, f.covering, "same lineage, same covering")
        pairs_checked = pairs_checked + 1
      else
        first[sp.lineage] = sp
      end
    end
  end
  test.expect(#L.lineages >= 4 or L.complexity == "plants", "4 to 8 lineages on worlds with animals")
  test.expect(#L.lineages <= 9, "(at most 8, plus the ancestors of a committed species)")
end
test.expect(pairs_checked > 200, "many pairs of related species compared: " .. pairs_checked)

-- ------------------------------------------------------------ gravity
local heavy, light = { h = 0, s = 0, n = 0 }, { h = 0, s = 0, n = 0 }
for _, p in ipairs(living) do
  local acc = p.data.gravity > 1.3 and heavy or (p.data.gravity < 0.75 and light or nil)
  if acc then
    for _, sp in ipairs(p.data.life.species) do
      if sp.kind == "animal" and sp.move ~= "fly" then
        acc.h, acc.s, acc.n = acc.h + sp.height, acc.s + sp.stockiness, acc.n + 1
      end
    end
  end
end
test.expect(heavy.n > 20 and light.n > 20, "land animals on heavy and light worlds: " .. heavy.n .. ", " .. light.n)
test.expect(heavy.h / heavy.n < light.h / light.n, "high gravity: shorter land animals on average")
test.expect(heavy.s / heavy.n > light.s / light.n, "high gravity: stockier land animals on average")
-- thin air grounds winged lineages
local grounded = 0
for _, p in ipairs(living) do
  for _, sp in ipairs(p.data.life.species) do
    if sp.flightless then
      grounded = grounded + 1
      test.expect(p.data.atmosphere.pressure / p.data.gravity < 0.25 or sp.size >= 3, "flightless where air is thin")
    end
    if sp.move == "fly" then test.expect(p.data.atmosphere.pressure / p.data.gravity >= 0.25, "flight needs air") end
  end
end

-- ------------------------------------------------------- food chains
local S = gen.life.species
local with_predators = 0
for _, p in ipairs(living) do
  local L = p.data.life
  local roles = {}
  for _, sp in ipairs(L.species) do roles[sp.role] = (roles[sp.role] or 0) + 1 end
  for _, sp in ipairs(L.species) do
    if sp.role == "predator" then
      with_predators = with_predators + 1
      local ok = false
      for _, id in ipairs(sp.prey) do
        local prey = S.get(L, id)
        if prey.biome == sp.biome and prey.kind == "animal" and prey.role ~= "predator" then ok = true end
      end
      test.expect(ok, "a predator has prey in its own biome")
    end
    if sp.role == "grazer" then test.expect(#sp.eats > 0, "grazers have plants to eat") end
  end
  if roles.predator then
    test.expect((roles.producer or 0) > (roles.grazer or 0) and (roles.grazer or 0) >= roles.predator,
                "more producers than grazers, more grazers than predators")
  end
end
test.expect(with_predators > 30, "predators exist: " .. with_predators)

-- ---------------------------------------------------- names, bestiary
for _, p in ipairs(living) do
  local seen = {}
  for _, sp in ipairs(p.data.life.species) do
    test.expect(sp.name and #sp.name > 3 and sp.latin and sp.description:find(sp.name, 1, true), "named and described")
    test.expect(not seen[sp.latin], "scientific names are unique on a world")
    seen[sp.latin] = true
  end
end

-- ------------------------------------------------ intelligent species
local natives, winged = 0, 0
for _, p in ipairs(living) do
  local L = p.data.life
  local lineage = {}
  for _, l in ipairs(L.lineages) do lineage[l.id] = l end
  for _, s in ipairs(L.sapients) do
    local l = lineage[s.lineage]
    test.expect(l, "a sapient species descends from a lineage of its world")
    test.eq(s.anatomy.limbs, l.limbs, "with its ancestors' limbs")
    test.eq(s.anatomy.covering, l.covering, "and covering")
    local flew = false
    for _, m in ipairs(l.moves) do if m == "fly" then flew = true end end
    test.eq(s.anatomy.wings, flew, "descended from flyers: wings")
    if flew then winged = winged + 1 end
    if s.origin == "native" then natives = natives + 1 end
    test.expect(s.lifespan > 0 and s.reproduction and s.diet and s.social and s.senses[1] and s.psionic,
                "physiology for culture: lifespan, reproduction, diet, social instinct, senses, psionics")
    test.expect(p.facts[s.fact] and p.facts[s.fact].kind == "species", "each intelligent species is a fact")
  end
end
test.expect(natives >= 5, "native intelligent species: " .. natives)
test.expect(winged >= 1, "some descend from flyers and have wings")

-- -------------------------------------------- spacefarers and colonies
local cluster
for _, sys in ipairs(systems) do
  local c = G:node(sys.address:match("^(.-)%.s%d+$"))
  if c.data.spacefarers and #c.data.spacefarers.colonies > 0 then cluster = c break end
end
if not cluster then
  for u = 1, 24 do
    for gi = 0, 6 do
      for ci = 0, 5 do
        local ok, c = pcall(G.generate, G, "u" .. u .. ".g" .. gi .. ".c" .. ci)
        if ok and c.data.spacefarers and #c.data.spacefarers.colonies > 0 then cluster = c break end
      end
      if cluster then break end
    end
    if cluster then break end
  end
end
test.expect(cluster, "a cluster with spacefarers")
local sf = cluster.data.spacefarers
local spec = cluster.facts[sf.fact].data
test.eq(cluster.facts[sf.fact].kind, "spacefarers", "the species is shared by the cluster")
local function promised_planet(saddr, kind)
  local sys = G:generate(saddr)
  for _, id in ipairs(sys.fact_order) do
    local f = sys.facts[id]
    if f.kind == "settled" and f.data.kind == kind then return G:generate(saddr .. ".p" .. f.data.planet) end
  end
end
local home = promised_planet(cluster.address .. ".s" .. sf.homeworld, "homeworld")
test.expect(home and home.summary.kind == "rocky", "the homeworld system has a rocky homeworld")
local found
for _, s in ipairs(home.data.life.sapients) do if s.name == spec.name then found = s end end
test.expect(found and found.origin == "committed", "the homeworld's life includes the committed species")
for _, k in ipairs({ "limbs", "hands", "wings", "covering", "tail", "eyes" }) do
  test.eq(found.anatomy[k], spec.anatomy[k], "with consistent anatomy: " .. k)
end
local kin
for _, l in ipairs(home.data.life.lineages) do if l.id == found.lineage then kin = l end end
test.expect(kin and kin.limbs == spec.anatomy.limbs and kin.covering == spec.anatomy.covering,
            "its ancestors are a lineage of the homeworld's tree of life")
local colony_seen, alongside = 0, false
for _, j in ipairs(sf.colonies) do
  local p = promised_planet(cluster.address .. ".s" .. j, "colony")
  test.expect(p, "a colony world in system " .. j)
  local c
  for _, s in ipairs(p.data.life.colonists) do if s.name == spec.name then c = s end end
  test.expect(c, "the colonists live there")
  for _, k in ipairs({ "limbs", "hands", "wings", "covering", "height" }) do
    test.eq(c.anatomy[k], spec.anatomy[k], "colonists keep their homeworld anatomy: " .. k)
  end
  test.eq(c.from, cluster.address .. ".s" .. sf.homeworld, "colonists know where they came from")
  colony_seen = colony_seen + 1
  if p.data.life.species then alongside = true end
end
test.expect(colony_seen > 0, "colonies were visited")

-- --------------------------------------------------- checker and bible
local problems = gen.check.run(G)
test.eq(#problems, 0, "the checker passes: " .. (problems[1] and problems[1].message or ""))
local ref = living[1]
for _, p in ipairs(living) do if #p.data.life.sapients > 0 then ref = p break end end
local md = gen.bible.export(G, ref.address)
test.expect(md:find("Life: ", 1, true) and md:find("Lineages: ", 1, true), "the bible describes life")
test.expect(md:find("Bestiary", 1, true) and md:find("species in", 1, true), "with a bestiary")
test.expect(#ref.data.life.sapients == 0 or md:find("intelligent", 1, true), "and its intelligent species")
-- a world without life says so
for _, sys in ipairs(systems) do
  for i = 0, sys.data.planets - 1 do
    local p = G.nodes[sys.address .. ".p" .. i]
    if p and p.data.life and p.data.life.chemistry == "none" then
      test.expect(gen.bible.export(G, p.address):find("Life: none.", 1, true), "lifeless worlds are described")
      goto done
    end
  end
end
::done::
test.expect(alongside, "colonists live alongside native life")
