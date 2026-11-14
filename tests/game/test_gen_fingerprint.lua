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
local G = gen.run.new(T.new(), { seed = 20261113, mods = {} })
local addrs = {}
for a in pairs(EXPECTED) do addrs[#addrs + 1] = a end
table.sort(addrs)
for _, a in ipairs(addrs) do
  local fp = gen.util.fingerprint(G:generate(a))
  test.eq(fp, EXPECTED[a], "fingerprint of '" .. a .. "'")
end
-- the cosmos (multiverse to star systems, including Prime): laws, galaxy
-- fields, cluster placement, stellar masses and orbits
local COSMOS = {
  [""] = "b8bfa3a08d62209d",
  ["u1"] = "7147fa3c43960518",
  ["u1.g2"] = "d3131223bc62a780",
  ["u1.g2.c3"] = "adb113330f368849",
  ["u1.g2.c3.s1"] = "948bc3ac9f9d7c7e",
  ["u0.g0.c0.s0"] = "eebc898325d8a267",
  ["u7.g40.c2.s0"] = "8a344d56d65fb15a",
  -- a rocky planet: physics and the C kernels (grid, tectonics, climate, rivers, territories)
  ["u1.g2.c3.s1.p0"] = "cd871d3ae097d3c7",
}
local C = gen.run.new(gen.cosmos, { seed = 20261113, mods = {} })
addrs = {}
for a in pairs(COSMOS) do addrs[#addrs + 1] = a end
table.sort(addrs)
for _, a in ipairs(addrs) do
  test.eq(gen.util.fingerprint(C:generate(a)), COSMOS[a], "cosmos fingerprint of '" .. a .. "'")
end

-- and the cosmos seeds of reference addresses
test.eq(gen.address.seed(20261113, "u3.g12.c4.s1.p2.k0.n5.l7", gen.address.COSMOS), 4178881845, "deep cosmos seed")
