-- Multiversal Van Life - galaxies: shape, density/age/metallicity fields,
-- a habitable band and star clusters placed along the shape (MIT).
-- Coordinates are kiloparsecs in the galactic plane (x, z), y is height.
local dm = require("gen.dmath")
local names = require("gen.names")
local prime = require("gen.prime")
local util = require("gen.util")

local galaxy = {}

local SHAPES = {
  dwarf = { { id = "irregular", w = 5 }, { id = "elliptical", w = 2 }, { id = "spiral", w = 1 } },
  normal = { { id = "spiral", w = 5 }, { id = "barred", w = 3 }, { id = "elliptical", w = 1.5 },
             { id = "ring", w = 0.8 }, { id = "irregular", w = 0.7 } },
  giant = { { id = "elliptical", w = 4 }, { id = "spiral", w = 2 }, { id = "barred", w = 2 }, { id = "ring", w = 1 } },
}

-- How strongly a point lies in a spiral arm, ring, bar or clump (0..1).
function galaxy.arm(g, x, z)
  local r = math.sqrt(x * x + z * z)
  if g.morphology == "spiral" or g.morphology == "barred" then
    if r < 0.05 then return 0 end
    local base = dm.log(r / g.r0) * g.pitch_k + g.phase
    local theta = dm.atan(z, x)
    local best = math.huge
    for k = 0, g.arms - 1 do
      best = math.min(best, math.abs(dm.wrap(theta - base - 2 * dm.pi * k / g.arms)))
    end
    local d = best * r / g.arm_width
    local fade = r < g.bulge * 1.5 and r / (g.bulge * 1.5) or 1
    return dm.exp(-d * d) * fade
  elseif g.morphology == "ring" then
    local d = (r - g.ring_radius) / g.ring_width
    return dm.exp(-d * d)
  elseif g.morphology == "irregular" then
    return dm.clamp(mvl.noise(x * 0.4, z * 0.4, g.clump_seed, 2) * 1.6, 0, 1)
  end
  return 0
end

-- Fields at a point: density, age (billions of years), metallicity (dex),
-- arm and core strengths. Arms are young and rich in heavy elements, the
-- old core is metal-poor, and metallicity falls slowly outwards (by 0.4 dex
-- from the centre to the edge, whatever the galaxy's size).
function galaxy.field(g, x, z)
  local r = math.sqrt(x * x + z * z)
  local c = r / g.bulge
  local core = dm.exp(-c * c)
  local arm = galaxy.arm(g, x, z)
  local density
  if g.morphology == "elliptical" then
    density = dm.exp(-r / (g.radius * 0.35)) + core
  else
    density = dm.exp(-r / g.scale_length) * (0.35 + 1.4 * arm) + 1.2 * core
  end
  if g.morphology == "barred" then
    local cb, sb = dm.cos(g.bar_angle), dm.sin(g.bar_angle)
    local bx, bz = x * cb + z * sb, -x * sb + z * cb
    if math.abs(bx) < g.bar then
      local w = bz / (0.18 * g.bar)
      density = density + 0.8 * dm.exp(-w * w) * (1 - math.abs(bx) / g.bar)
    end
  end
  local age = g.age * dm.clamp(0.55 + 0.45 * core - 0.5 * arm, 0.03, 1)
  local metal = g.metallicity + 0.35 * arm - 0.6 * core - 0.4 * r / g.radius
  return density, age, metal, arm, core
end

local function shape(ctx)
  local rng = ctx:rng()
  local s = ctx.summary
  local u = ctx.parent.data
  local morph = dm.weighted(rng, SHAPES[s.mass] or SHAPES.normal).id
  local radius = s.mass == "dwarf" and 1.5 + rng:next() * 3 or (s.mass == "giant" and 18 + rng:next() * 35 or
                 6 + rng:next() * 14)
  local pitch = (10 + rng:next() * 22) * dm.pi / 180
  local age = math.max(0.5, u.age * (0.45 + rng:next() * 0.5))
  local g = {
    name = s.name, morphology = morph, radius = dm.round(radius, 3), age = dm.round(age, 3),
    arms = (morph == "spiral" or morph == "barred") and rng:int(2, 6) or 0,
    pitch_k = dm.round(dm.cos(pitch) / dm.sin(pitch), 4), r0 = dm.round(0.3 + rng:next() * 0.7, 3),
    phase = dm.round(rng:next() * 2 * dm.pi, 4), arm_width = dm.round(radius * (0.03 + rng:next() * 0.04), 3),
    bulge = dm.round(radius * (morph == "elliptical" and 0.35 or 0.08 + rng:next() * 0.1), 3),
    scale_length = dm.round(radius * 0.3, 3),
    metallicity = dm.round(-0.5 + rng:next() * 0.5 + math.min(0.3, u.age * 0.01), 3),
    bar = morph == "barred" and dm.round(radius * (0.15 + rng:next() * 0.15), 3) or 0,
    bar_angle = dm.round(rng:next() * dm.pi, 4),
    ring_radius = dm.round(radius * (0.45 + rng:next() * 0.3), 3), ring_width = dm.round(radius * 0.06, 3),
    clump_seed = rng:int(0, 1000000),
  }
  for k, v in pairs(g) do ctx.data[k] = v end
  -- formed during one of the universe's eras
  local formed = dm.round(u.age - g.age, 3)
  local era = u.eras[1]
  for _, e in ipairs(u.eras) do if e.from <= formed then era = e end end
  ctx.data.formed_id = ctx:fact("formation", { name = "Birth of " .. s.name, year = formed }, era.id)
  -- the band where stars are neither scorched by the core nor starved of metals
  ctx.data.habitable = { dm.round(radius * 0.35, 3), dm.round(radius * 0.7, 3) }
end

-- Clusters: Poisson disc samples accepted in proportion to density.
local function clusters(ctx)
  local g = ctx.data
  local rng = ctx:rng()
  local target = math.floor(dm.clamp(g.radius * 7, 24, 300))
  local min_dist = g.radius * math.sqrt(dm.pi / target) * 0.55
  local peak = galaxy.field(g, 0, 0) + 0.8
  local placed, attempts = {}, 0
  while #placed < target and attempts < target * 15 do
    attempts = attempts + 1
    local r, a = g.radius * math.sqrt(rng:next()), rng:next() * 2 * dm.pi
    local x, z = r * dm.cos(a), r * dm.sin(a)
    local density, age, metal, arm, core = galaxy.field(g, x, z)
    if rng:next() < dm.clamp(density / peak, 0.03, 1) then
      local ok = true
      for _, p in ipairs(placed) do
        local dx, dz = p.x - x, p.z - z
        if dx * dx + dz * dz < min_dist * min_dist then ok = false break end
      end
      if ok then
        placed[#placed + 1] = { x = x, z = z, density = density, age = age, metal = metal, arm = arm, core = core }
      end
    end
    if attempts % 64 == 0 then ctx:yield() end
  end
  local band = g.habitable
  for i, p in ipairs(placed) do
    local r = math.sqrt(p.x * p.x + p.z * p.z)
    ctx:child(i - 1, {
      name = names.make(ctx:random("cluster" .. i), "stellar"),
      pos = { dm.round(p.x, 3), dm.round(dm.normal(rng, 0, 0.1), 3), dm.round(p.z, 3) },
      r = dm.round(r, 3), density = dm.round(p.density, 4), age = dm.round(p.age, 3),
      metallicity = dm.round(p.metal, 3), in_arm = p.arm > 0.5, in_core = p.core > 0.5,
      habitable = r >= band[1] and r <= band[2],
    })
  end
  ctx.data.clusters = #placed
end

function galaxy.register(R)
  R:pass("galaxy", "prime", { run = function(ctx)
    if not ctx.summary.prime then return end
    for k, v in pairs(prime.milky_way) do ctx.data[k] = v end
    ctx.data.prime = true
    local hood = util.copy(prime.neighbourhood)
    hood.prime = true
    ctx:child(0, hood)
  end })
  R:pass("galaxy", "shape", { after = { "prime" }, run = function(ctx)
    if not ctx.summary.prime then shape(ctx) end
  end })
  R:pass("galaxy", "clusters", { after = { "shape" }, run = function(ctx)
    if not ctx.summary.prime then clusters(ctx) end
  end })

  -- heavy elements: arm clusters richer than the old core
  R:check("metallicity", function(node, report)
    if node.kind ~= "galaxy" or node.data.prime then return end
    local arm, core = {}, {}
    for _, s in pairs(node.children) do
      if s.in_arm then arm[#arm + 1] = s.metallicity elseif s.in_core then core[#core + 1] = s.metallicity end
    end
    if #arm >= 3 and #core >= 3 then
      local function mean(t) local m = 0 for _, v in ipairs(t) do m = m + v end return m / #t end
      if mean(arm) <= mean(core) then report(node.address .. ": arm clusters are not richer in metals than the core") end
    end
  end)

  R:describe("galaxy", function(node)
    local d = node.data
    if d.prime then
      return "The Milky Way: a barred spiral about 30 kiloparsecs across; the Sun lies 8.2 kiloparsecs from its centre."
    end
    local shapes = { elliptical = "An elliptical galaxy", ring = "A ring galaxy", irregular = "An irregular galaxy",
                     spiral = string.format("A spiral with %d arms", d.arms),
                     barred = string.format("A barred spiral with %d arms", d.arms) }
    local shape_text = shapes[d.morphology]
    return string.format("%s, %.1f kiloparsecs across, %.1f billion years old, with %d star clusters; " ..
                         "the habitable band lies %.1f to %.1f kiloparsecs from the centre.",
                         shape_text, 2 * d.radius, d.age, d.clusters or 0, d.habitable[1], d.habitable[2])
  end)
end

return galaxy
