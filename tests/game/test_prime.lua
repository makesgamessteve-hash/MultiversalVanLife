-- The Prime universe: fixed real data, always universe 0, nothing
-- generated inside it except the way to the farm, and no Earth lore.
local gen = require("gen")
local prime = gen.prime

for _, seed in ipairs({ 1, 99, 123456 }) do
  local G = gen.run.new(gen.cosmos, { seed = seed, mods = {} })
  test.expect(G:generate("") and G:skeleton("u0").prime, "universe zero is Prime (seed " .. seed .. ")")
  local u0 = G:generate("u0")
  test.expect(u0.data.prime and u0.data.name == "Prime", "Prime universe data")
  test.eq(u0.data.laws.magic, "none", "no magic in Prime")
  test.eq(u0.data.laws.magic_strength, 0, "no magic strength")
  test.eq(u0.data.laws.psionics, 0, "no psionics in Prime")
  test.eq(u0.data.laws.ftl, "none", "no faster-than-light travel")
  test.expect(not u0.data.eras, "Prime has no generated eras")
  test.expect(not G:generate("u1").data.prime, "other universes are generated")
end

local G = gen.run.new(gen.cosmos, { seed = 5, mods = {} })
local sol = G:generate(prime.SOLAR_SYSTEM)
test.eq(G:node(prime.GALAXY).data.name, "Milky Way", "the Milky Way")
test.eq(sol.data.star.name, "Sun", "the Sun")
test.eq(sol.data.planets, 8, "eight planets")
local REAL = { Mercury = 0.2408, Venus = 0.6152, Earth = 1.0, Mars = 1.8808, Jupiter = 11.862, Saturn = 29.457,
               Uranus = 84.02, Neptune = 164.8 }
for i = 0, 7 do
  local p = sol.children[i]
  test.eq(p.period, REAL[p.name], p.name .. "'s real orbital period")
  -- real orbits follow Kepler's third law within half a percent
  test.expect(math.abs(p.period - math.sqrt(p.a ^ 3)) < 0.005 * p.period, p.name .. " obeys Kepler")
end
local earth = G:generate(prime.EARTH)
test.eq(earth.summary.name, "Earth", "Earth is the third planet")
test.eq(earth.summary.moons[1].name, "Moon", "the Moon")
test.expect(math.abs(earth.summary.moons[1].period - 27.32) < 0.01, "the Moon's real period")
test.eq(#gen.check.run(G), 0, "Prime passes the checks")

-- nothing else exists in Prime
for _, addr in ipairs({ "u0.g1", "u0.g0.c1", "u0.g0.c0.s1", "u0.g0.c0.s0.p8", "u0.g0.c0.s0.p2.k1",
                        "u0.g0.c0.s0.p2.k0.n1", "u0.g0.c0.s0.p3.k0", "u0.g0.c0.s0.p2.k0.n0.l300" }) do
  local ok, err = pcall(G.generate, G, addr)
  test.expect(not ok and tostring(err):find("there is no place", 1, true), "not generated in Prime: " .. addr)
end
test.expect(G:generate(prime.FARM), "the way to the farm exists")
test.expect(G:generate("u0.g0.c0.s0.p2.k0.n0.l1"), "the countryside around the farm exists")

-- Earth's history, factions and religions are never generated
for _, kind in ipairs({ "history", "faction", "religion", "era", "species", "culture" }) do
  test.eq(#gen.lore(G, prime.EARTH, kind), 0, "no Earth " .. kind)
end
test.eq(#gen.lore(G, prime.FARM), 0, "no lore around the farm")
for addr, node in pairs(G.nodes) do
  if prime.inside(addr) then
    for _, id in ipairs(node.fact_order) do
      test.expect(not gen.LORE[node.facts[id].kind], "no lore facts in Prime: " .. id)
    end
  end
end
-- lore does exist elsewhere
test.expect(#gen.lore(G, "u1", "era") >= 3, "generated universes have eras")
