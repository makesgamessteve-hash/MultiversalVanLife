-- Multiversal Van Life - the multiverse: tendencies of its universes and
-- the endless list of universes, Prime first (MIT).
local dm = require("gen.dmath")
local names = require("gen.names")
local prime = require("gen.prime")

return function(R)
  -- law tables (mods may add entries)
  R:content("magic_sources", {
    { id = "none", w = 3 }, { id = "life", w = 2 }, { id = "stellar", w = 1.5 }, { id = "tectonic", w = 1.5 },
    { id = "belief", w = 2 },
  })
  R:content("ftl_modes", { { id = "none", w = 3 }, { id = "gates", w = 3.5 }, { id = "jumps", w = 3.5 } })

  -- Each multiverse leans towards some laws: the same seed always favours
  -- the same kinds of universes.
  R:pass("multiverse", "tendencies", { run = function(ctx)
    local rng = ctx:rng()
    local magic, ftl = {}, {}
    for _, e in ipairs(ctx:table("magic_sources")) do magic[e.id] = dm.round(0.6 + rng:next() * 0.8, 3) end
    for _, e in ipairs(ctx:table("ftl_modes")) do ftl[e.id] = dm.round(0.6 + rng:next() * 0.8, 3) end
    ctx.data.name = "The Multiverse"
    ctx.data.magic_tendency, ctx.data.ftl_tendency = magic, ftl
    ctx.data.prime = prime.UNIVERSE
    ctx:fact("branching", { name = "The Branching", what = "every universe splits from a single root" })
  end })

  -- Universes are endless; index 0 is always the fixed Prime universe.
  R:skeleton("universe", function(parent, index, seed)
    if index == 0 then return { name = prime.universe.name, prime = true } end
    return { name = names.make(mvl.rng(seed), "cosmic") }
  end)

  R:describe("multiverse", function(node)
    return "An endless multiverse. Universe u0 is Prime, our own; every other universe is generated from the save's seed."
  end)
end
