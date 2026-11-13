-- The top of the cosmos: universe laws, lazy galaxies, galaxy shapes and
-- fields, clusters with lanes, star systems with orbits.
local gen = require("gen")
local util = gen.util

local function runner(seed) return gen.run.new(gen.cosmos, { seed = seed, mods = {} }) end

-- ------------------------------------------------------ law variety
local G = runner(4242)
local magic, ftl, gods, psionic = {}, {}, {}, { zero = 0, some = 0 }
local no_ftl, gates
for i = 1, 200 do
  local u = G:generate("u" .. i)
  local l = u.data.laws
  magic[l.magic] = (magic[l.magic] or 0) + 1
  ftl[l.ftl] = (ftl[l.ftl] or 0) + 1
  gods[l.gods] = true
  if l.psionics == 0 then psionic.zero = psionic.zero + 1 else psionic.some = psionic.some + 1 end
  if l.ftl == "none" and not no_ftl then no_ftl = u.address end
  if l.ftl == "gates" and not gates then gates = u.address end
  test.expect(u.data.age >= 4 and u.data.age <= 40, "age in range")
  test.expect(#u.data.eras >= 3 and u.data.eras[#u.data.eras].to == u.data.age, "eras span the age")
end
for _, source in ipairs({ "none", "life", "stellar", "tectonic", "belief" }) do
  test.expect(magic[source], "magic source occurs: " .. source)
end
for _, mode in ipairs({ "none", "gates", "jumps" }) do test.expect(ftl[mode], "FTL mode occurs: " .. mode) end
test.expect(gods.real and gods.silent, "real and silent gods")
test.expect(psionic.zero > 0 and psionic.some > 0, "universes with and without psionics")
test.eq(#gen.check.run(G), 0, "laws are consistent")

-- determinism
test.expect(util.equal(runner(4242):generate("u17"), G:node("u17")), "same seed, same universe")
test.expect(not util.equal(runner(4243):generate("u17").data, G:node("u17").data), "another seed, another universe")

-- -------------------------------------------- lazy galaxies
local L = runner(7)
local u = L:generate("u3")
test.eq(L.stats.detail, 2, "a universe request generates the multiverse and the universe only")
test.eq(L:node("u3.g0"), nil, "no galaxy detail without a request")
local notable = 0
for index, n in pairs(u.data.notable) do
  notable = notable + 1
  local s = L:skeleton("u3.g" .. index)
  test.eq(s.notable, n.role, "notable galaxy summary")
  test.eq(s.name, n.name, "notable galaxy name")
end
test.expect(notable >= 3, "notable galaxies")
local s = L:skeleton("u3.g123456")
test.expect(s and s.name and s.pos and s.mass, "any galaxy index has a summary")
test.eq(L:skeleton("u3.g1000000"), nil, "galaxy indices are bounded")
L:generate("u3.g5")
test.eq(L.stats.detail, 3, "one galaxy generated in detail")

-- ---------------------------------- spiral arms: young, rich, rocky
local arm, core = { metal = 0, age = 0, n = 0, rocky = 0, planets = 0 }, { metal = 0, age = 0, n = 0, rocky = 0, planets = 0 }
local spirals = 0
local S = runner(31)
local gi = 0
while spirals < 4 and gi < 80 do
  local addr = "u1.g" .. gi
  gi = gi + 1
  local galaxy = S:generate(addr)
  if galaxy.data.morphology == "spiral" or galaxy.data.morphology == "barred" then
    spirals = spirals + 1
    local taken = { arm = 0, core = 0 }
    for i = 0, galaxy.data.clusters - 1 do
      local c = galaxy.children[i]
      local bucket = c.in_arm and "arm" or (c.in_core and "core" or nil)
      if bucket and taken[bucket] < 5 then
        taken[bucket] = taken[bucket] + 1
        local acc = bucket == "arm" and arm or core
        acc.metal, acc.age, acc.n = acc.metal + c.metallicity, acc.age + c.age, acc.n + 1
        local cl = S:generate(addr .. ".c" .. i)
        for k = 0, math.min(3, cl.data.stars - 1) do
          local sys = S:generate(cl.address .. ".s" .. k)
          for p = 0, sys.data.planets - 1 do
            acc.planets = acc.planets + 1
            if sys.children[p].kind == "rocky" then acc.rocky = acc.rocky + 1 end
          end
        end
      end
    end
  end
end
test.eq(spirals, 4, "spiral galaxies found")
test.expect(arm.n > 0 and core.n > 0, "arm and core clusters found")
test.expect(arm.metal / arm.n > core.metal / core.n, "arms are richer in heavy elements")
test.expect(arm.age / arm.n < core.age / core.n, "arms are younger than the core")
test.expect(arm.rocky / arm.planets > core.rocky / core.planets,
            string.format("arm planets are more often rocky (%d/%d vs %d/%d)", arm.rocky, arm.planets, core.rocky, core.planets))
test.eq(#gen.check.run(S), 0, "galaxies, clusters and systems pass the checks")

-- ------------------------------------------------ lanes need FTL
test.expect(no_ftl and gates, "universes with and without FTL")
local function first_cluster(R, uaddr)
  for g = 0, 20 do
    local galaxy = R:generate(uaddr .. ".g" .. g)
    if galaxy.data.clusters > 0 then return R:generate(galaxy.address .. ".c0") end
  end
end
test.eq(#first_cluster(G, no_ftl).data.lanes, 0, "no lanes without faster-than-light travel")
local linked = first_cluster(G, gates)
test.expect(#linked.data.lanes > 0, "gates link the stars of a cluster")
for _, lane in ipairs(linked.data.lanes) do
  test.expect(linked.children[lane.a] and linked.children[lane.b] and lane.kind == "gate", "lanes join stars")
end

-- ------------------------------------- orbits over 200 seeds
local rocky_inside, rocky = 0, 0
for seed = 1, 200 do
  local R = runner(seed * 7919)
  local ok, sys = pcall(R.generate, R, "u1.g0.c0.s0")
  test.expect(ok, "seed " .. seed .. ": " .. tostring(sys))
  local prev
  for p = 0, sys.data.planets - 1 do
    local planet = sys.children[p]
    if prev then test.expect(planet.a > prev.a * 1.4, "distinct, spaced orbits") end
    test.expect(math.abs(planet.period - math.sqrt(planet.a ^ 3 / sys.data.star.mass)) <= 0.01 * planet.period + 1e-6,
                "Kepler periods")
    if planet.kind == "rocky" then
      rocky = rocky + 1
      if planet.a <= sys.data.frost_line then rocky_inside = rocky_inside + 1 end
    end
    prev = planet
  end
  local problems = gen.check.run(R)
  test.eq(#problems, 0, "seed " .. seed .. ": " .. (problems[1] and problems[1].message or ""))
end
test.expect(rocky > 50 and rocky_inside / rocky >= 0.9, "rocky planets lie inside the frost line")
