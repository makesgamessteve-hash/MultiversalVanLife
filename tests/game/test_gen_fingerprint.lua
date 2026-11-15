-- Generation is bit-identical on every platform: fingerprints of reference
-- places of the test hierarchy (integer hashing, random streams and float
-- noise) must match the stored values. If a generator change is intended,
-- update the values; otherwise a mismatch means a platform generates a
-- different multiverse from the same seed.
local gen = require("gen")
local T = require("gen.testworld")

local EXPECTED = {
  [""] = "e09b5c8ca6be9403",
  ["r1"] = "e399cb15ab4ce146",
  ["r1.i0"] = "57b1768dbf040ef8",
  ["r1.i0.g0"] = "3f92c67111d4af63",
  ["r0.i1"] = "85064238bd90fab1",
  ["r2"] = "3dd22a9931f91bda",
}
local G = gen.run.new(T.new(), { seed = 20261113, mods = {}, version = 1 })
local addrs = {}
for a in pairs(EXPECTED) do addrs[#addrs + 1] = a end
table.sort(addrs)
for _, a in ipairs(addrs) do
  local fp = gen.util.fingerprint(G:generate(a))
  test.eq(fp, EXPECTED[a], "fingerprint of '" .. a .. "'")
end
-- the cosmos (multiverse to star systems, including Prime): laws, galaxy
-- fields, cluster placement, stellar masses and orbits
-- (multiverses from before the surface grid, version 1: unchanged)
local COSMOS = {
  [""] = "b8bfa3a08d62209d",
  ["u1"] = "3a2964e9d47f0312",
  ["u1.g2"] = "b4b29ab0e6677c58",
  ["u1.g2.c3"] = "adb113330f368849",
  ["u1.g2.c3.s1"] = "948bc3ac9f9d7c7e",
  ["u0.g0.c0.s0"] = "eebc898325d8a267",
  ["u7.g40.c2.s0"] = "8a344d56d65fb15a",
  -- a rocky planet: physics and the C kernels (grid, tectonics, climate, rivers, territories)
  ["u1.g2.c3.s1.p0"] = "7cbd4dd6aa4e6741",
}
local C = gen.run.new(gen.cosmos, { seed = 20261113, mods = {}, version = 1 })
addrs = {}
for a in pairs(COSMOS) do addrs[#addrs + 1] = a end
table.sort(addrs)
for _, a in ipairs(addrs) do
  test.eq(gen.util.fingerprint(C:generate(a)), COSMOS[a], "cosmos fingerprint of '" .. a .. "'")
end

-- the surface grid (version 2): the same places, a region (its rivers,
-- lakes and borders) and a land of it (its crop of the planet-wide terrain)
local GRID = {
  [""] = "feb97046d9b62858",
  ["u1.g2.c3.s1"] = "eae5361ad97f6805",
  ["u1.g2.c3.s1.p0"] = "3c7d62c3d023c4ef",
  ["u1.g2.c3.s1.p0.r118368"] = "5b401c281377bf8a",
  ["u1.g2.c3.s1.p0.r118368.l49"] = "a6a39c5418d3d541",
}
local V2 = gen.run.new(gen.cosmos, { seed = 20261113, mods = {} })
addrs = {}
for a in pairs(GRID) do addrs[#addrs + 1] = a end
table.sort(addrs)
for _, a in ipairs(addrs) do
  test.eq(gen.util.fingerprint(V2:generate(a)), GRID[a], "grid fingerprint of '" .. a .. "'")
end

-- and the cosmos seeds of reference addresses
test.eq(gen.address.seed(20261113, "u3.g12.c4.s1.p2.k0.n5.l7", gen.address.COSMOS), 4178881845, "deep cosmos seed")
test.eq(gen.address.seed(20261113, "u1.g2.c3.s1.p0.r118368.l49"), V2:generate("u1.g2.c3.s1.p0.r118368.l49").seed,
        "grid land seed")
