-- Multiversal Van Life - star systems: the star, planets on orbits around a
-- frost line, their moons, and belts (MIT). Distances are AU, periods Earth
-- years, masses Earth masses (planets) or solar masses (stars).
local dm = require("gen.dmath")
local names = require("gen.names")
local prime = require("gen.prime")
local util = require("gen.util")

local system = {}

-- Normalised heavy-element richness (0 poor .. 1 rich).
local function richness(metallicity) return dm.clamp((metallicity + 1.2) / 1.6, 0, 1) end

function system.period(a, star_mass) return math.sqrt(a * a * a / star_mass) end

local function planet_mass(rng, kind)
  if kind == "rocky" then return 0.05 + rng:next() * rng:next() * 4 end
  if kind == "dwarf" then return 0.001 + rng:next() * 0.04 end
  if kind == "ice_giant" then return 8 + rng:next() * 17 end
  return 30 + rng:next() * rng:next() * 1000
end

local function moons(rng, kind, star_name, n)
  local count = kind == "rocky" and (rng:chance(0.4) and rng:int(1, 2) or 0) or
                (kind == "dwarf" and (rng:chance(0.2) and 1 or 0) or rng:int(2, 8))
  local out, a = {}, kind == "rocky" and 60000 or 180000
  for i = 1, count do
    a = a * (1.3 + rng:next())
    out[i] = { name = names.make(rng, "world"), a = math.floor(a) }
  end
  return out
end

function system.register(R)
  R:pass("system", "prime", { run = function(ctx)
    if not ctx.summary.prime then return end
    ctx.data.star = util.copy(prime.sun)
    ctx.data.prime = true
    ctx.data.frost_line = 2.7
    ctx.data.habitable_zone = { 0.95, 1.37 }
    ctx.data.belts = util.copy(prime.belts)
    for i, p in ipairs(prime.planets) do
      local s = util.copy(p)
      s.prime = true
      ctx:child(i - 1, s)
    end
    ctx.data.planets = #prime.planets
  end })

  R:pass("system", "star", { after = { "prime" }, run = function(ctx)
    if ctx.summary.prime then return end
    local s = ctx.summary
    local root = math.sqrt(s.luminosity)
    ctx.data.star = { name = s.name, class = s.class, mass = s.mass, luminosity = s.luminosity, age = s.age,
                      metallicity = s.metallicity, companion = s.companion }
    ctx.data.frost_line = dm.round(2.7 * root, 4)
    ctx.data.habitable_zone = { dm.round(0.95 * root, 4), dm.round(1.37 * root, 4) }
  end })

  R:pass("system", "planets", { after = { "star" }, run = function(ctx)
    if ctx.summary.prime then return end
    local rng, d = ctx:rng(), ctx.data
    local star = d.star
    local rich = richness(star.metallicity)
    local root = math.sqrt(star.luminosity)
    local inner, outer = math.max(0.02, 0.07 * root), 40 * math.sqrt(star.mass)
    local count = math.floor(1 + rich * 7 + rng:next() * 2) - (star.companion and 1 or 0)
    local a = inner * (1 + rng:next() * 0.5)
    local planets = {}
    while #planets < count and a < outer do
      local kind
      if a < d.frost_line then
        kind = rng:chance(0.45 + 0.5 * rich) and "rocky" or "dwarf"
      elseif a < d.frost_line * 4 then
        kind = rng:chance(0.35 + 0.5 * rich) and "gas_giant" or "ice_giant"
      else
        kind = rng:chance(0.6) and "ice_giant" or "dwarf"
      end
      local mass = planet_mass(rng, kind)
      local au = dm.round(a, 4)
      planets[#planets + 1] = {
        name = names.planet(star.name, #planets + 1), kind = kind, a = au,
        period = dm.round(system.period(au, star.mass), 5), mass = dm.round(mass, 4),
        temperature = math.floor(278 * math.sqrt(root) / math.sqrt(au)),
        habitable_zone = au >= d.habitable_zone[1] and au <= d.habitable_zone[2],
        moons = moons(rng, kind),
      }
      a = a * (1.45 + rng:next() * 0.75) -- spacing keeps orbits apart
    end
    -- a promised homeworld or colony needs a rocky world
    if #ctx:commitments("homeworld") + #ctx:commitments("colony") > 0 then
      require("gen.life.sapients").ensure_rocky(d, planets, ctx:random("settlers"), system.period)
      for i, p in ipairs(planets) do
        p.name = names.planet(star.name, i)
        p.temperature = math.floor(278 * math.sqrt(root) / math.sqrt(p.a))
      end
    end
    for i, p in ipairs(planets) do ctx:child(i - 1, p) end
    d.planets = #planets
    -- belts: in a wide gap across the frost line, and beyond the last planet
    d.belts = {}
    for i = 1, #planets - 1 do
      local p, q = planets[i], planets[i + 1]
      if p.a < d.frost_line and q.a >= d.frost_line and q.a / p.a > 2.4 then
        d.belts[#d.belts + 1] = { name = "inner belt", inner = dm.round(p.a * 1.3, 4), outer = dm.round(q.a * 0.75, 4) }
      end
    end
    if #planets > 0 and rng:chance(0.6) then
      local last = planets[#planets].a
      d.belts[#d.belts + 1] = { name = "outer belt", inner = dm.round(last * 1.5, 4), outer = dm.round(last * 2.5, 4) }
    end
  end })

  -- orbits: distinct and spaced, Kepler periods, rocky worlds inside the frost line
  R:check("orbits", function(node, report)
    if node.kind ~= "system" then return end
    local prev
    for i = 0, (node.data.planets or 0) - 1 do
      local p = node.children[i]
      if prev and p.a / prev.a < (node.data.prime and 1.3 or 1.44) then
        report(string.format("%s: %s orbits too close to %s", node.address, p.name, prev.name))
      end
      if not node.data.prime then
        local expect = system.period(p.a, node.data.star.mass)
        if math.abs(p.period - expect) > 0.01 * expect then report(node.address .. ": " .. p.name .. " breaks Kepler's law") end
        if p.kind == "rocky" and p.a > node.data.frost_line then
          report(node.address .. ": rocky " .. p.name .. " beyond the frost line")
        end
      end
      prev = p
    end
  end)

  R:describe("system", function(node)
    local d = node.data
    local kinds = {}
    for i = 0, (d.planets or 0) - 1 do
      local p = node.children[i]
      kinds[#kinds + 1] = string.format("%s (%s, %.2f AU)", p.name, (p.kind:gsub("_", " ")), p.a)
    end
    return string.format("%s, a %s star of %.2f solar masses%s; frost line at %.2f AU. Planets: %s.", d.star.name,
                         d.star.subclass or d.star.class, d.star.mass,
                         d.star.companion and (" with a " .. d.star.companion .. " companion") or "",
                         d.frost_line, #kinds > 0 and table.concat(kinds, ", ") or "none")
  end)
end

return system
