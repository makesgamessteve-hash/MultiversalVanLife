-- The consistency checker over many seeds, deliberately broken generators,
-- and the world bible export.
local gen = require("gen")
local T = require("gen.testworld")

-- correct generators pass the checks over many seeds
for seed = 1, 40 do
  local G = gen.run.new(T.new(), { seed = seed, mods = {} })
  G:generate("r1.i0.g0")
  G:generate("r0.i1")
  local root = G:node("")
  G:generate("r" .. (root.data.realms - 1) .. ".i0")
  local problems = gen.check.run(G)
  test.eq(#problems, 0, "seed " .. seed .. ": " .. (problems[1] and problems[1].message or ""))
end

local function problems_of(R, addr)
  local G = gen.run.new(R, { seed = 3, mods = {} })
  G:generate(addr)
  local list = gen.check.run(G)
  local text = {}
  for i, p in ipairs(list) do text[i] = p.check .. ": " .. p.message end
  return list, table.concat(text, "\n")
end

-- a generator that leaves a commitment unhonoured fails, naming it
local list, text = problems_of(T.new({ break_shrine = true }), "r1.i0.g0")
test.eq(#list, 1, "one problem")
test.eq(list[1].check, "commitments", "the commitment check")
test.expect(text:find("commitment /commitment/1 (shrine) to r1.i0.g0 was not honoured", 1, true), text)
local ok, err = pcall(gen.check.assert_ok, gen.run.new(T.new({ break_shrine = true }), { seed = 3 }))
test.expect(ok, "nothing generated, nothing to complain about")
local G = gen.run.new(T.new({ break_shrine = true }), { seed = 3 })
G:generate("r1.i0.g0")
ok, err = pcall(gen.check.assert_ok, G)
test.expect(not ok and tostring(err):find("not honoured", 1, true), "assert_ok raises")

-- references to missing facts and to places off the path
local R = T.new()
R:pass("island", "bad_refs", { run = function(ctx)
  ctx:fact("rumour", { about_id = "r1/founding/9" })
  ctx:fact("echo", {}, { "r0.i0/harbor/1" })
end })
list, text = problems_of(R, "r1.i0")
test.expect(text:find("about_id", 1, true) and text:find("does not exist", 1, true), text)
test.expect(text:find("is not on the path", 1, true), text)

-- chronology: effects after causes, spans forwards
R = T.new()
R:pass("realm", "time", { run = function(ctx)
  local late = ctx:fact("comet", { year = 900 })
  ctx:fact("omen", { year = 100 }, late)
  ctx:fact("reign", { from = 50, to = 10 })
end })
list, text = problems_of(R, "r0")
test.expect(text:find("happens later", 1, true), text)
test.expect(text:find("ends (10) before it starts (50)", 1, true), text)

-- checks registered by generators
R = T.new()
R:check("warm_realms", function(node, report)
  if node.kind == "realm" and node.data.temperature < 100 then report(node.address .. " is too cold") end
end)
list, text = problems_of(R, "r0")
test.expect(text:find("warm_realms: r0 is too cold", 1, true), text)

-- the world bible lists every place on the path with its facts and causes
G = gen.run.new(T.new(), { seed = 20261113, mods = { "sample" } })
local md = gen.bible.export(G, "r1.i0.g0")
for _, want in ipairs({ "# World bible: Glade r1.i0.g0", "mods: sample", "## World", "## Realm r1", "## Island r1.i0",
                        "## Glade r1.i0.g0", "**r1.i0.g0/shrine/1** — shrine: Shrine of Moss",
                        "because [/commitment/1](#-commitment-1)", "### Promises kept", "shared by: r0, r1",
                        "### Places inside" }) do
  test.expect(md:find(want, 1, true), "bible contains: " .. want)
end
local sections = 0
for _ in md:gmatch("\n## ") do sections = sections + 1 end
test.eq(sections, 4, "one section per place on the path")
