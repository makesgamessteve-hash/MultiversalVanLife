-- Multiversal Van Life - a small hierarchy used only by tests and docs (MIT).
-- world ("") > realm (r) > island (i) > glade (g). It exercises every part
-- of the framework: listed children, ordered passes, random streams, float
-- noise, shared facts, commitments across one and two levels, chronology
-- and long passes that yield.
--   opts.survey        work units of the island survey pass (default 20)
--   opts.break_shrine  glades ignore their shrine commitment (checker tests)
local registry = require("gen.registry")

local T = {}

function T.new(opts)
  opts = opts or {}
  local R = registry.new({
    name = "testworld",
    levels = {
      { "world", "" },
      { "realm", "r", caps = { children = 8 } },
      { "island", "i", caps = { children = 6, facts = 64 } },
      { "glade", "g", caps = { children = 0 } },
    },
  })
  R:content("trees", { "oak", "pine", "willow", "glowcap" })

  R:pass("world", "lore", { run = function(ctx)
    local rng = ctx:rng()
    local n = rng:int(3, 5)
    for i = 0, n - 1 do ctx:child(i, { name = "Realm " .. i, warmth = rng:float(-1, 1) }) end
    ctx.data.realms = n
    local dawn = ctx:fact("era", { name = "The Dawn", from = 0, to = 100 })
    local pact = ctx:shared("alliance", { name = "Tide Pact", year = 40 }, { 0, 1 }, dawn)
    ctx.data.alliance_id = pact
    -- two levels down: realm 1 always has island 0 and island 0 glade 0
    ctx:commit("r1.i0.g0", "shrine", { god = "Moss" }, pact)
  end })

  R:pass("realm", "climate", { run = function(ctx)
    local rng = ctx:rng()
    ctx.data.temperature = ctx.summary.warmth * 20 + rng:float(-2, 2)
    ctx.data.rain = mvl.noise(ctx.node.index * 1.37, 0.5, ctx.seed % 100000, 3)
  end })

  R:pass("realm", "islands", { after = { "climate" }, run = function(ctx)
    local rng = ctx:rng()
    local n = ctx.data.temperature > 0 and 4 or 2
    for i = 0, n - 1 do ctx:child(i, { name = ctx.summary.name .. " isle " .. i, size = rng:float(1, 9) }) end
    local because = { "/era/1" }
    if ctx.node.index <= 1 then because[2] = ctx:ref("/alliance/1").id end
    local founding = ctx:fact("founding", { name = "Founding of " .. ctx.summary.name, year = 50 + rng:int(0, 40) },
                              because)
    ctx:commit(0, "harbor", { size = rng:int(1, 5) }, founding)
  end })

  R:pass("island", "harbor", { run = function(ctx)
    for _, c in ipairs(ctx:commitments("harbor")) do
      local id = ctx:fact("harbor", { name = "Harbor of " .. ctx.summary.name, size = c.data.data.size }, c)
      ctx:honour(c, id)
    end
  end })

  R:pass("island", "glades", { after = { "harbor" }, run = function(ctx)
    local rng = ctx:rng()
    for i = 0, rng:int(1, 3) do ctx:child(i, { name = "glade " .. i }) end
  end })

  R:pass("island", "survey", { after = { "glades" }, run = function(ctx)
    local sum = 0
    for i = 1, opts.survey or 20 do
      sum = sum + mvl.noise(i * 0.173, ctx.summary.size, ctx.seed % 100000, 2)
      ctx:yield()
    end
    ctx.data.survey = sum
  end })

  R:pass("glade", "contents", { run = function(ctx)
    ctx.data.tree = ctx:rng():pick(ctx:table("trees"))
    if opts.break_shrine then return end
    for _, c in ipairs(ctx:commitments("shrine")) do
      local id = ctx:fact("shrine", { name = "Shrine of " .. c.data.data.god }, c)
      ctx:honour(c, id)
    end
  end })
  return R
end

return T
