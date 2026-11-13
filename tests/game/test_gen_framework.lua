-- The generation framework on a small test hierarchy: addresses and seeds,
-- pass ordering and isolation, lazy and order independent generation,
-- budgets, facts, shared things, commitments and versions.
local gen = require("gen")
local A, util, T = gen.address, gen.util, require("gen.testworld")
local S = A.COSMOS

local function fails(fn, pattern, msg)
  local ok, err = pcall(fn)
  test.expect(not ok, (msg or pattern) .. ": should fail")
  test.expect(tostring(err):find(pattern, 1, true), (msg or pattern) .. ": got " .. tostring(err))
end

-- ------------------------------------------------------------ addresses
test.eq(A.format(S, { 3, 12, 4 }), "u3.g12.c4", "format")
local idx = A.parse(S, "u3.g12.c4.s1.p2.k0.n5.l7")
test.eq(#idx, 8, "eight levels below the multiverse")
test.eq(idx[8], 7, "land index")
for _, bad in ipairs({ "g1", "u1.u2", "u01", "u", "u1.", ".u1", "u1.g2.c3.s4.p5.k6.n7.l8.x9", "u-1", "u99999999999",
                       "U1" }) do
  test.expect(A.parse(S, bad) == nil, "invalid address " .. bad)
end
test.eq(A.parent("u3.g12"), "u3", "parent")
test.eq(A.parent("u3"), "", "parent of a universe is the multiverse")
test.eq(A.parent(""), nil, "the multiverse has no parent")
test.eq(A.level("u3.g12.c4"), 3, "level")
test.eq(A.index("u3.g12"), 12, "index")
test.eq(A.child(S, "u3", 12), "u3.g12", "child")
test.eq(table.concat(A.path("u1.g2"), "|"), "|u1|u1.g2", "path")
test.eq(A.common("u1.g2.c3", "u1.g2.c7.s1"), "u1.g2", "common ancestor")
test.eq(A.common("u1", "u2"), "", "common ancestor of universes")
test.expect(A.is_ancestor("u1", "u1.g2") and not A.is_ancestor("u1", "u10.g2") and not A.is_ancestor("u1", "u1"),
            "ancestry")
test.eq(A.describe(S, "u1.g2"), "Galaxy u1.g2", "describe")

-- seeds depend only on the root seed and the address
test.eq(A.seed(42, "u3.g12"), mvl.hash(mvl.hash(42, 1, 3), 2, 12), "seed derivation")
test.expect(A.seed(42, "u3.g12") ~= A.seed(43, "u3.g12") and A.seed(42, "u3.g12") ~= A.seed(42, "u3.g13"), "seeds differ")
-- a stored reference: changing it would reshuffle every save's multiverse
test.eq(A.seed(1234, "u3.g12.c4", S), 3944827498, "reference seed")

-- pass isolation: adding a pass does not change what the others generate
local function realm(extra)
  local R = T.new()
  if extra then
    R:pass("realm", "aaa_extra", { run = function(ctx)
      for _ = 1, 10 do ctx:rng():next() end
      ctx.data.extra = true
    end })
  end
  local G = gen.run.new(R, { seed = 7, mods = {} })
  G:generate("r1.i0")
  return G
end
local plain, extended = realm(false), realm(true)
test.expect(extended:node("r1").data.extra and not plain:node("r1").data.extra, "extra pass ran")
extended:node("r1").data.extra = nil
test.expect(util.equal(plain:node("r1").data, extended:node("r1").data), "realm unchanged by an extra pass")
test.expect(util.equal(plain:node("r1.i0"), extended:node("r1.i0")), "island unchanged by an extra pass")

-- ------------------------------------------------------------- registry
local R = gen.registry.new({ levels = { { "top", "" }, { "mid", "m", caps = { facts = 3 } } } })
local ran = {}
R:pass("top", "a", { after = { "z" }, run = function() ran[#ran + 1] = "a" end })
R:pass("top", "z", { run = function() ran[#ran + 1] = "z" end })
R:pass("top", "b", { after = { "a" }, run = function() ran[#ran + 1] = "b" end })
local names = {}
for i, p in ipairs(R:ordered("top")) do names[i] = p.name end
test.eq(table.concat(names, ","), "z,a,b", "dependency order")
R:pass("top", "a", { after = { "z" }, run = function() ran[#ran + 1] = "A" end }) -- replaced
gen.run.new(R, { seed = 1 }):generate("")
test.eq(table.concat(ran, ","), "z,A,b", "a replaced pass runs instead")
gen.registry.as_mod("mymod", function() R:pass("mid", "m1", { run = function() end }) end)
test.eq(R.passes[1].m1.mod, "mymod", "passes remember the mod that registered them")
R:content("trees", { "oak" })
R:content("trees", { "elm", "ash" })
test.eq(#R:table("trees"), 3, "content tables collect entries")
R:pass("top", "x", { after = { "y" }, run = function() end })
fails(function() R:ordered("top") end, "not registered", "missing dependency")
R:pass("top", "y", { after = { "x" }, run = function() end })
fails(function() R:ordered("top") end, "cycle", "cyclic dependencies")
R:remove_pass("top", "x")
R:remove_pass("top", "y")
fails(function() R:level("nowhere") end, "unknown level")
-- caps
R:pass("mid", "many", { run = function(ctx) for i = 1, 4 do ctx:fact("thing", { n = i }) end end })
fails(function() gen.run.new(R, { seed = 1 }):generate("m0") end, "the cap is 3", "fact cap")
R:caps("top", { children = 2 })
R:pass("top", "kids", { run = function(ctx) ctx:child(5, {}) end })
fails(function() gen.run.new(R, { seed = 1 }):generate("") end, "beyond the cap", "children cap")

-- ------------------------------------------------- lazy path generation
local G = gen.run.new(T.new(), { seed = 5, mods = {} })
local glade = G:generate("r1.i0.g1")
test.eq(G.stats.detail, 4, "exactly the path is generated in detail")
test.eq(table.concat(G.stats.order, ","), ",r1,r1.i0,r1.i0.g1", "top down")
test.eq(G:node("r0"), nil, "siblings are not generated in detail")
test.expect(G:skeleton("r0") and G:skeleton("r0").name == "Realm 0", "siblings exist as summaries")
test.eq(G:skeleton("r0.i0"), nil, "no summaries below ungenerated places")
fails(function() G:generate("r7") end, "there is no place at r7", "unlisted child")
fails(function() G:generate("r1.x2") end, "invalid address", "bad address")
test.eq(glade.summary.name, "glade 1", "a place starts from its summary")

-- the same address twice, in two runners, gives identical places
local G2 = gen.run.new(T.new(), { seed = 5, mods = {} })
test.expect(util.equal(G2:generate("r1.i0.g1"), glade), "same seed, same place")
test.expect(not util.equal(gen.run.new(T.new(), { seed = 6, mods = {} }):generate("r1.i0.g1"), glade),
            "another seed, another place")

-- order independence
local Ga, Gb = gen.run.new(T.new(), { seed = 9, mods = {} }), gen.run.new(T.new(), { seed = 9, mods = {} })
Ga:generate("r0.i1")
Ga:generate("r2.i0.g0")
Gb:generate("r2.i0.g0")
Gb:generate("r0.i1")
for _, a in ipairs({ "", "r0", "r0.i1", "r2", "r2.i0", "r2.i0.g0" }) do
  test.expect(util.equal(Ga:node(a), Gb:node(a)), "order independent: " .. a)
end

-- ------------------------------------------------------------- budgets
-- a fake clock that advances 1 ms per reading: the 400 unit survey must be
-- spread over many updates of at most the 10 ms budget each
local t = 0
local Gs = gen.run.new(T.new({ survey = 400 }), { seed = 3, budget = 0.010, mods = {},
                                                 clock = function() t = t + 0.001 return t end })
local job = Gs:request("r1.i0")
test.expect(Gs:busy() and not job.done, "queued")
local updates = 0
while Gs:update() do updates = updates + 1 end
test.expect(job.done and job.node and not job.error, "finished")
test.expect(updates > 20, "spread over many updates: " .. updates)
test.expect(Gs.stats.yields >= updates, "yielded between work units")
test.expect(util.equal(job.node, gen.run.new(T.new({ survey = 400 }), { seed = 3, mods = {} }):generate("r1.i0")),
            "budgeted generation gives the same place")
-- with the real clock, while the game keeps running frames
local Gr = gen.run.new(T.new({ survey = 30000 }), { seed = 4, budget = 0.002, mods = {} })
local done_at
local start = mvl.ticks()
Gr:request("r1.i1", function(node) done_at = mvl.ticks() test.expect(node.data.survey, "survey done") end)
local longest = 0
while Gr:busy() do
  local c = os.clock()
  Gr:update()
  longest = math.max(longest, os.clock() - c)
  test.wait(1)
end
test.expect(done_at and done_at > start + 1, "generated over several frames")
test.expect(longest < 0.05, "each frame stays within the budget: " .. longest)
-- a failing pass reports its error on the job
local Rf = T.new()
Rf:pass("glade", "boom", { run = function() error("boom!") end })
local Gf = gen.run.new(Rf, { seed = 1, mods = {} })
local bad = Gf:request("r1.i0.g0")
while Gf:update(1) do end
test.expect(bad.done and bad.error and bad.error:find("boom!"), "errors are reported")
local again = Gf:request("r1.i0")
test.expect(again.done and again.node, "ancestors generated before the failure are kept")

-- --------------------------------------------- facts and commitments
local Gc = gen.run.new(T.new(), { seed = 11, mods = {} })
local g0 = Gc:generate("r1.i0.g0")
local root = Gc:node("")
local cid = root.commits["r1.i0.g0"][1]
local shrine = g0.honoured[cid]
test.expect(shrine and g0.facts[shrine].data.name == "Shrine of Moss", "a commitment two levels down is honoured")
local why = Gc:why(shrine)
test.eq(#why, 1, "one cause")
test.eq(why[1].id, cid, "caused by the commitment")
local lines = Gc:explain(shrine)
test.eq(#lines, 4, "shrine <- commitment <- alliance <- era: " .. table.concat(lines, " / "))
test.expect(lines[4]:find("The Dawn", 1, true), "the chain reaches the era")
local island = Gc:node("r1.i0")
test.expect(next(island.honoured), "the realm's harbor commitment is honoured")
local pact = root.facts[root.data.alliance_id]
test.eq(table.concat(pact.members, ","), "r0,r1", "the alliance lives on the root and names its members")
test.eq(Gc:node("r1").facts["r1/founding/1"].because[2], pact.id, "members refer to the shared alliance")
-- shared things must live on the lowest common ancestor
local Rs = T.new()
Rs:pass("realm", "wrong", { run = function(ctx) ctx:shared("guild", {}, { "r1.i0.g0", "r1.i0.g1" }) end })
fails(function() gen.run.new(Rs, { seed = 1 }):generate("r1") end, "belongs there", "shared below its home")
local Rn = T.new()
Rn:pass("realm", "far", { run = function(ctx) ctx:commit("r3.i0", "x", {}) end })
fails(function() gen.run.new(Rn, { seed = 1 }):generate("r1") end, "can only commit", "commit outside")
local Ro = T.new()
Ro:pass("island", "peek", { run = function(ctx) ctx:ref("r0/founding/1") end })
fails(function() gen.run.new(Ro, { seed = 1 }):generate("r1.i0") end, "not on the path", "reference off the path")

-- ----------------------------------------------------------- versions
test.eq(g0.version, gen.VERSION, "generator version recorded")
test.eq(#g0.mods, 0, "no mods recorded")
local Gm = gen.run.new(T.new(), { seed = 1, mods = { "alpha", "beta" } })
test.eq(table.concat(Gm:generate("r0").mods, ","), "alpha,beta", "active mods recorded")
test.eq(#gen.run.new(T.new(), { seed = 1 }):generate("").mods, #mvl.mods(), "defaults to the active mods")

-- the game starts a cosmos runner per save, seeded from the save
H.new_game()
test.expect(gen.world and gen.world.seed == game.debug.progress.seed(), "the save seeds the cosmos")
test.expect(mvl.save_get("story.seed"), "the seed is saved")
