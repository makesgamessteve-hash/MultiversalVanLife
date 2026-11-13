-- Multiversal Van Life - universes: laws, age, cosmic eras, the galaxy
-- density field and notable galaxies (MIT). Everything below derives its
-- magic, technology and religion from these laws.
local dm = require("gen.dmath")
local names = require("gen.names")
local prime = require("gen.prime")
local util = require("gen.util")

local GALAXIES = 1000000 -- galaxy indices per universe

local ERA_NAMES = { "First Light", "the Kindling", "the Long Quiet", "the Burning", "the Gathering", "the Thaw",
                    "the Weave", "the Sundering", "the Bloom", "the Reckoning", "the Dimming", "the Return",
                    "the Choir", "the Drift" }
local ROLES = {
  { role = "cradle", what = "where life first stirred" },
  { role = "crown", what = "the largest and brightest" },
  { role = "wound", what = "torn by an ancient collision" },
  { role = "far_shore", what = "the most distant ever seen" },
  { role = "hearth", what = "rich in old, quiet worlds" },
  { role = "silence", what = "where nothing answers" },
  { role = "forge", what = "full of newborn stars" },
}

return function(R)
  R:pass("universe", "prime", { run = function(ctx)
    if not ctx.summary.prime then return end
    ctx.data.name, ctx.data.age, ctx.data.prime = prime.universe.name, prime.universe.age, true
    ctx.data.laws = util.copy(prime.universe.laws)
    ctx:child(0, { name = prime.milky_way.name, prime = true })
  end })

  R:pass("universe", "laws", { after = { "prime" }, run = function(ctx)
    if ctx.summary.prime then return end
    local rng = ctx:rng()
    local mv = ctx.parent.data
    local source = dm.weighted(rng, ctx:table("magic_sources"), mv.magic_tendency).id
    local laws = { magic = source }
    laws.magic_strength = source == "none" and 0 or dm.round(0.1 + 0.9 * rng:next(), 3)
    laws.psionics = rng:chance(0.35) and 0 or dm.round(rng:next(), 3)
    laws.ftl = dm.weighted(rng, ctx:table("ftl_modes"), mv.ftl_tendency).id
    if laws.ftl == "jumps" then laws.jump_range = dm.round(3 + rng:next() * 9, 2) end -- parsecs
    laws.gods = rng:chance(source == "belief" and 0.75 or 0.25) and "real" or "silent"
    ctx.data.name = ctx.summary.name
    ctx.data.laws = laws
    ctx.data.age = dm.round(4 + rng:next() * 36, 2) -- billions of years
    ctx.data.laws_id = ctx:fact("laws", { name = "Laws of " .. ctx.summary.name, magic = source, ftl = laws.ftl,
                                          gods = laws.gods }, "/branching/1")
  end })

  -- Cosmic eras: names and spans only; history fills them later.
  R:pass("universe", "eras", { after = { "laws" }, run = function(ctx)
    if ctx.summary.prime then return end
    local rng = ctx:rng()
    local pool = util.copy(ERA_NAMES)
    local n = rng:int(3, 7)
    local weights, total = {}, 0
    for i = 1, n do
      weights[i] = 0.5 + rng:next()
      total = total + weights[i]
    end
    local eras, t, prev = {}, 0, ctx.data.laws_id
    for i = 1, n do
      local name = table.remove(pool, rng:int(1, #pool))
      local span = ctx.data.age * weights[i] / total
      local from, to = dm.round(t, 3), dm.round(i == n and ctx.data.age or t + span, 3)
      local id = ctx:fact("era", { name = name, from = from, to = to, year = from }, prev)
      eras[i] = { name = name, from = from, to = to, id = id }
      prev, t = id, t + span
    end
    ctx.data.eras = eras
  end })

  -- Galaxies fill space according to a 3D density field; a few notable
  -- galaxies are singled out for history to come back to.
  R:pass("universe", "galaxies", { after = { "eras" }, run = function(ctx)
    if ctx.summary.prime then return end
    local rng = ctx:rng()
    ctx.data.galaxy_field = { size = 300, scale = dm.round(25 + rng:next() * 50, 2), seed = rng:int(0, 1000000),
                              richness = dm.round(0.6 + rng:next() * 0.8, 3) }
    local roles = util.copy(ROLES)
    local notable = {}
    for _ = 1, rng:int(4, 6) do
      local index = rng:int(0, 999)
      if not notable[index] then
        local r = table.remove(roles, rng:int(1, #roles))
        local era = ctx.data.eras[rng:int(1, #ctx.data.eras)]
        local name = names.make(rng, "cosmic")
        notable[index] = { name = name, role = r.role }
        ctx:fact("notable_galaxy", { name = name, role = r.role, what = r.what, galaxy = ctx.node.address .. ".g" .. index,
                                     year = era.from }, era.id)
      end
    end
    ctx.data.notable = notable
  end })

  -- Galaxy summaries are computed on demand from the density field.
  R:skeleton("galaxy", function(parent, index, seed)
    if parent.data.prime or not parent.data.galaxy_field or index >= GALAXIES then return nil end
    local f = parent.data.galaxy_field
    local rng = mvl.rng(seed)
    local x, y, z = (rng:next() - 0.5) * f.size, (rng:next() - 0.5) * f.size, (rng:next() - 0.5) * f.size
    local density = dm.clamp(0.5 + 0.6 * mvl.noise3(x / f.scale, y / f.scale, z / f.scale, f.seed, 2), 0, 1)
    local m = density * f.richness + rng:next() * 0.6
    local n = parent.data.notable[index]
    return {
      name = n and n.name or names.make(rng, "cosmic"),
      pos = { dm.round(x, 3), dm.round(y, 3), dm.round(z, 3) }, -- megaparsecs
      density = dm.round(density, 4),
      mass = n and n.role == "crown" and "giant" or (m < 0.55 and "dwarf" or (m < 1.15 and "normal" or "giant")),
      notable = n and n.role or nil,
    }
  end)

  R:check("laws", function(node, report)
    if node.kind ~= "universe" or not node.data.laws then return end
    local l = node.data.laws
    if (l.magic == "none") ~= (l.magic_strength == 0) then report(node.address .. ": magic strength contradicts its source") end
    if l.ftl ~= "none" and l.ftl ~= "gates" and l.ftl ~= "jumps" then report(node.address .. ": unknown FTL " .. l.ftl) end
  end)

  R:describe("universe", function(node)
    local d = node.data
    if d.prime then
      return "Prime, our own universe: 13.8 billion years old, without magic or psionics; its history is not simulated."
    end
    local l = d.laws
    local magic = l.magic == "none" and "There is no magic" or
                  string.format("Magic flows from %s (strength %.2f)", l.magic == "belief" and "belief" or
                                (l.magic == "life" and "living things" or (l.magic == "stellar" and "the stars" or
                                "the turning of worlds")), l.magic_strength)
    local ftl = l.ftl == "none" and "nothing travels faster than light" or
                (l.ftl == "gates" and "stars are linked by gates" or
                 string.format("ships jump up to %.1f parsecs", l.jump_range))
    local eras = {}
    for i, e in ipairs(d.eras) do eras[i] = e.name end
    return string.format("%s, %.1f billion years old. %s; psionics %s; %s; its gods are %s. Eras: %s.", d.name, d.age,
                         magic, l.psionics == 0 and "absent" or string.format("%.2f", l.psionics), ftl, l.gods,
                         table.concat(eras, ", "))
  end)
end
