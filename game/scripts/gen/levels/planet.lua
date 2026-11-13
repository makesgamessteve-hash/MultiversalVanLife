-- Multiversal Van Life - planets: physics, tectonics, geology and magic
-- geography (MIT). Per-cell fields live in node.data.cells (arrays over the
-- planet grid, see engine/src/core/planet.h); summaries in node.data.
local dm = require("gen.dmath")
local util = require("gen.util")

local P = { LEVEL = 5 }

-- Geological settings and the rocks found in them.
P.SETTINGS = { "ocean floor", "shelf", "ridge", "trench", "island arc", "volcanic arc", "orogen", "old orogen", "rift",
               "craton", "basin" }
P.ROCKS = {
  { name = "basalt", color = { 52, 52, 56 } }, { name = "granite", color = { 168, 150, 146 } },
  { name = "gneiss", color = { 130, 124, 120 } }, { name = "schist", color = { 110, 112, 104 } },
  { name = "marble", color = { 214, 210, 200 } }, { name = "andesite", color = { 96, 92, 90 } },
  { name = "obsidian", color = { 24, 22, 30 } }, { name = "tuff", color = { 176, 160, 130 } },
  { name = "sandstone", color = { 196, 168, 120 } }, { name = "red sandstone", color = { 170, 84, 60 } },
  { name = "shale", color = { 84, 80, 76 } }, { name = "limestone", color = { 200, 192, 168 } },
  { name = "quartzite", color = { 222, 214, 206 } }, { name = "slate", color = { 70, 76, 84 } },
}
local ROCK = {}
for i, r in ipairs(P.ROCKS) do ROCK[r.name] = i end
P.ROCK = ROCK
local SETTING = {}
for i, s in ipairs(P.SETTINGS) do SETTING[s] = i end
P.SETTING = SETTING

local ROCKS_IN = {
  ["ocean floor"] = { "basalt" }, shelf = { "limestone", "shale", "sandstone" }, ridge = { "basalt" },
  trench = { "basalt", "shale" }, ["island arc"] = { "andesite", "basalt", "tuff" },
  ["volcanic arc"] = { "andesite", "obsidian", "tuff", "basalt" }, orogen = { "granite", "schist", "gneiss", "marble" },
  ["old orogen"] = { "quartzite", "slate", "schist", "gneiss" }, rift = { "basalt", "sandstone", "tuff" },
  craton = { "granite", "gneiss", "quartzite" }, basin = { "sandstone", "red sandstone", "shale", "limestone" },
}

-- Deposits: chance per land cell by setting.
P.DEPOSITS = {
  { kind = "metal", names = { "iron", "copper", "tin", "silver", "gold" },
    chance = { orogen = 0.25, ["old orogen"] = 0.45, ["volcanic arc"] = 0.3, ["island arc"] = 0.2, craton = 0.2,
               rift = 0.15, basin = 0.04, shelf = 0.02 } },
  { kind = "fuel", names = { "coal", "oil", "peat" },
    chance = { basin = 0.4, shelf = 0.25, rift = 0.1, ["old orogen"] = 0.05 } },
  { kind = "gem", names = { "diamond", "ruby", "sapphire", "opal", "emerald" },
    chance = { craton = 0.12, orogen = 0.08, ["old orogen"] = 0.1, ["volcanic arc"] = 0.05 } },
}
P.MAGIC_MINERALS = { life = "heartwood amber", stellar = "starglass", tectonic = "emberstone", belief = "dreamquartz" }

-- Star colour (light) from spectral class.
P.STAR_LIGHT = {
  O = { 0.62, 0.72, 1.0 }, B = { 0.72, 0.8, 1.0 }, A = { 0.85, 0.88, 1.0 }, F = { 1.0, 0.97, 0.9 },
  G = { 1.0, 0.93, 0.8 }, K = { 1.0, 0.8, 0.6 }, M = { 1.0, 0.6, 0.42 },
}
P.STAR_TEMP = { O = 35000, B = 18000, A = 8500, F = 6600, G = 5700, K = 4500, M = 3200 }

-- ------------------------------------------------------------- physics
local function physics(ctx)
  local s, d = ctx.summary, ctx.data
  local rng = ctx:rng()
  local star = ctx.parent.data.star
  local system = ctx.parent.data
  local m = s.mass
  local radius
  if s.kind == "gas_giant" then radius = 11.2 * dm.pow(m / 318, 0.05)
  elseif s.kind == "ice_giant" then radius = 3.9 * dm.pow(m / 15, 0.2)
  else radius = dm.pow(m, 0.27) end
  d.radius = dm.round(radius, 4)           -- Earth radii
  d.gravity = dm.round(m / (radius * radius), 4) -- Earth g
  d.surface = s.kind == "rocky" or s.kind == "dwarf"
  -- what it is made of: iron from the star's metals, water from the frost line
  local rich = dm.clamp((star.metallicity + 1.2) / 1.6, 0, 1)
  local water
  if not d.surface then water = 0
  elseif s.a >= system.frost_line then water = 0.95
  elseif s.a >= system.habitable_zone[1] * 0.8 then water = 0.45 + rng:next() * 0.4
  else water = rng:next() * 0.25 end
  d.composition = { iron = dm.round(0.2 + 0.2 * rich + rng:next() * 0.1, 3), water = dm.round(water, 3),
                    silicate = dm.round(0.6 - 0.1 * rich, 3) }
  -- atmosphere: kept if escape speed beats the heat of the gas
  local escape = math.sqrt(m / radius)
  local hold = escape / math.sqrt(math.max(s.temperature, 30) / 300)
  local pressure = 0
  if not d.surface then pressure = 1000
  elseif hold > 0.45 then pressure = dm.pow(m, 1.3) * dm.exp(dm.normal(rng, 0, 0.9)) * dm.clamp((hold - 0.45) * 2, 0, 1) end
  d.atmosphere = { pressure = dm.round(pressure, 4) }
  local t = s.temperature
  d.atmosphere.gases = t > 380 and { "carbon dioxide", "sulphur" } or
                       (t > 240 and { "nitrogen", "carbon dioxide" } or { "nitrogen", "methane" })
  -- rotation: close to a small star a planet is tidally locked or slowed
  local reach = 0.5 * dm.pow(star.mass, 0.66)
  if s.a < reach and rng:chance(0.8) then
    d.locked, d.day = true, dm.round(s.period * 365.25, 3)
  elseif s.a < reach then
    d.locked, d.day = false, dm.round(10 + rng:next() * 150, 3)
  else
    d.locked, d.day = false, dm.round((8 + rng:next() * 60) / 24, 4)
  end
  d.tilt = d.locked and 0 or dm.round(rng:chance(0.08) and 45 + rng:next() * 50 or rng:next() * 40, 2) -- degrees
  d.year = dm.round(s.period * 365.25, 3)                                                              -- days
  -- temperatures: radiative equilibrium plus greenhouse warming
  local greenhouse = pressure > 0 and 33 * dm.pow(math.min(pressure, 200), 0.35) or 0
  local mean = t + greenhouse
  local swing = (d.locked and 120 or 15 + d.tilt * 0.8) / (1 + math.min(pressure, 50))
  if pressure < 0.01 then swing = d.locked and 300 or 150 end
  d.temperature = { mean = dm.round(mean, 2), min = dm.round(math.max(3, mean - swing), 2),
                    max = dm.round(mean + swing, 2) }
  -- seas need air and the right warmth: liquid, frozen or boiled away
  if not d.surface or water == 0 then d.water = "none"
  elseif pressure < 0.05 or mean > 400 then d.water = "none"
  elseif mean < 245 then d.water = "ice"
  else d.water = "liquid" end
  d.light = util.copy(P.STAR_LIGHT[star.class] or P.STAR_LIGHT.G)
  d.star_class = star.class
end

-- ----------------------------------------------------------- tectonics
local function tectonics(ctx)
  local d = ctx.data
  if not d.surface then return end
  local rng = ctx:rng()
  local active = ctx.summary.mass >= 0.15
  local n = active and dm.clamp(math.floor(6 + 8 * dm.pow(ctx.summary.mass, 0.5) + rng:int(0, 6)), 6, 24) or 1
  local continental = dm.round(0.25 + rng:next() * 0.2, 3)
  d.grid = P.LEVEL -- the grid level every per-cell field of this planet uses
  local T = mvl.planet_tectonics({ level = d.grid, seed = ctx.seed % 2147483647, plates = n,
                                   continental = continental })
  ctx:yield()
  local count = #T.elevation
  -- sea level: the ocean covers the share of the surface the water allows
  local sorted = {}
  for i = 1, count do sorted[i] = T.elevation[i] end
  table.sort(sorted)
  local ocean = d.water == "none" and 0 or dm.clamp(d.composition.water, 0, 0.92)
  local sea = sorted[math.max(1, math.floor(count * ocean))]
  if ocean < 0.02 then sea = sorted[1] - 0.01 end
  local elevation = {}
  for i = 1, count do elevation[i] = dm.round(T.elevation[i] - sea, 3) end
  d.cells = { elevation = elevation, plate = T.plate, boundary = T.boundary, dist = T.dist }
  d.active = active
  d.plates = {}
  for k, p in ipairs(T.plates) do
    d.plates[k] = { continental = p.continental, area = dm.round(p.area, 4), speed = dm.round(p.speed, 3) }
  end
  local land = 0
  for i = 1, count do if elevation[i] > 0 then land = land + 1 end end
  d.ocean = dm.round(1 - land / count, 4)
  local high = 0
  for i = 1, count do high = math.max(high, elevation[i]) end
  d.highest = dm.round(high, 3)
  ctx:fact("tectonics", { name = n .. " plates", plates = n, active = active })
end

-- --------------------------------------------------- geology and deposits
local function geology(ctx)
  local d = ctx.data
  if not d.cells then return end
  local rng = ctx:rng()
  local cells = d.cells
  local count = #cells.elevation
  -- ancient plate boundaries: worn-down mountain belts inside continents
  local paleo = mvl.planet_plates(d.grid, (ctx.seed + 7919) % 2147483647, math.max(4, #d.plates - 3))
  local land_sorted = {}
  for i = 1, count do if cells.elevation[i] > 0 then land_sorted[#land_sorted + 1] = cells.elevation[i] end end
  table.sort(land_sorted)
  local low_land = land_sorted[math.max(1, math.floor(#land_sorted * 0.3))] or 0
  local setting, rock = {}, {}
  for i = 1, count do
    local e, b, dist = cells.elevation[i], cells.boundary[i], cells.dist[i]
    local cont = d.plates[cells.plate[i]].continental
    local s
    if b == 1 and dist < 2.5 and cont and e > 0 then s = "orogen"
    elseif b == 1 and dist < 1.5 and not cont and e > -0.5 then s = "island arc"
    elseif b == 1 and dist < 1.2 and not cont then s = "trench"
    elseif b == 2 and dist < 1.5 and cont then s = "rift"
    elseif b == 2 and dist < 1.5 then s = "ridge"
    elseif e < 0 then s = cont and "shelf" or "ocean floor"
    else
      local old = false
      for _, nb in ipairs(mvl.planet_neighbours(d.grid, i)) do if paleo[nb] ~= paleo[i] then old = true break end end
      if old and dist > 3 then s = "old orogen"
      elseif e <= low_land then s = "basin"
      else s = "craton" end
    end
    if s == "orogen" and not cont then s = "volcanic arc" end
    setting[i] = SETTING[s]
    local options = ROCKS_IN[s]
    rock[i] = ROCK[options[mvl.hash(ctx.seed, i) % #options + 1]]
    if i % 2000 == 0 then ctx:yield() end
  end
  -- volcanic arcs: continental cells above subducting ocean
  for i = 1, count do
    if cells.boundary[i] == 1 and cells.dist[i] < 2 and cells.elevation[i] > 0 and setting[i] == SETTING.orogen
       and mvl.hash(ctx.seed, i, 7) % 3 == 0 then
      setting[i] = SETTING["volcanic arc"]
      rock[i] = ROCK[ROCKS_IN["volcanic arc"][mvl.hash(ctx.seed, i, 8) % 4 + 1]]
    end
  end
  cells.setting, cells.rock = setting, rock
  -- deposits: at most one per cell (kind index into P.DEPOSITS), plus the
  -- richest ones listed by name
  local laws = ctx:ancestor("universe").data.laws
  local deposit, notable = {}, {}
  for i = 1, count do
    deposit[i] = 0
    if cells.elevation[i] > -0.2 then
      local sname = P.SETTINGS[setting[i]]
      for k, dep in ipairs(P.DEPOSITS) do
        local p = (dep.chance[sname] or 0) * (dep.kind == "metal" and (0.7 + d.composition.iron) or 1)
        if deposit[i] == 0 and p > 0 and rng:next() < p then
          deposit[i] = k
          local rich = rng:next()
          if rich > 0.985 and #notable < 48 then
            notable[#notable + 1] = { cell = i, kind = dep.kind, name = dep.names[rng:int(1, #dep.names)],
                                      richness = dm.round(rich, 3) }
          end
        end
      end
    end
  end
  cells.deposit = deposit
  d.deposits = notable
  d.magic_mineral = laws.magic ~= "none" and P.MAGIC_MINERALS[laws.magic] or nil
end

-- ------------------------------------------------------ magic geography
local function magic(ctx)
  local d = ctx.data
  if not d.cells then return end
  local u = ctx:ancestor("universe")
  local laws = u.data.laws
  if laws.magic == "none" then
    d.magic = { source = "none", strength = 0 }
    return
  end
  local cells, count = d.cells, #d.cells.elevation
  local field = {}
  local star_heat = (P.STAR_TEMP[d.star_class] or 5700) / 5700
  for i = 1, count do
    local x, y, z = mvl.planet_cell(d.grid, i)
    local v
    if laws.magic == "tectonic" then
      local near = cells.boundary[i] ~= 0 and math.max(0, 1 - cells.dist[i] / 3) or 0
      local volcanic = (cells.setting[i] == SETTING["volcanic arc"] or cells.setting[i] == SETTING["island arc"]) and 0.4 or 0
      v = 0.08 + near * 0.8 + volcanic
    elseif laws.magic == "stellar" then
      -- starlight: towards the substellar point of locked worlds, the equator otherwise
      local light = d.locked and math.max(0, x) or math.sqrt(math.max(0, 1 - y * y))
      v = 0.1 + 0.8 * light * dm.clamp(star_heat, 0.4, 1.6) / 1.6
    elseif laws.magic == "life" then
      -- strongest where life will be dense (refined once life exists)
      local mild = cells.elevation[i] > 0 and math.max(0, 1 - math.abs(y) * 1.4) or 0.2
      v = 0.1 + 0.6 * mild
    else
      -- belief: faint everywhere until holy sites exist
      v = 0.1 + 0.1 * (mvl.noise3(x * 3, y * 3, z * 3, ctx.seed % 100000, 2) + 1)
    end
    field[i] = dm.round(dm.clamp(v, 0, 1.5) * laws.magic_strength, 4)
  end
  cells.magic = field
  local best, where = -1, 1
  for i = 1, count do if field[i] > best then best, where = field[i], i end end
  d.magic = { source = laws.magic, strength = laws.magic_strength, peak = dm.round(best, 4), peak_cell = where,
              mineral = d.magic_mineral }
  d.magic_id = ctx:fact("magic", { name = "Magic of " .. ctx.summary.name, source = laws.magic, peak_cell = where },
                        u.data.laws_id)
end

function P.register(R)
  R:pass("planet", "physics", { after = { "provisional" }, run = function(ctx)
    if not ctx.summary.prime then physics(ctx) end
  end })
  R:pass("planet", "tectonics", { after = { "physics" }, run = function(ctx)
    if not ctx.summary.prime then tectonics(ctx) end
  end })
  R:pass("planet", "geology", { after = { "tectonics" }, run = function(ctx)
    if not ctx.summary.prime then geology(ctx) end
  end })
  R:pass("planet", "magic", { after = { "geology" }, run = function(ctx)
    if not ctx.summary.prime then magic(ctx) end
  end })

  -- physics must hang together
  R:describe("planet", P.describe)

  R:check("planet_physics", function(node, report)
    if node.kind ~= "planet" or node.data.prime or not node.data.radius then return end
    local d = node.data
    local g = node.summary.mass / (d.radius * d.radius)
    if math.abs(g - d.gravity) > 0.01 * g + 1e-4 then report(node.address .. ": gravity does not follow mass and radius") end
    if d.locked and (d.tilt ~= 0 or math.abs(d.day - d.year) > 0.01) then report(node.address .. ": a locked world turns once a year") end
    if d.atmosphere.pressure < 0 then report(node.address .. ": negative pressure") end
    if d.temperature.min > d.temperature.mean or d.temperature.max < d.temperature.mean then
      report(node.address .. ": temperature range around the mean")
    end
    if d.ocean and (d.ocean < 0 or d.ocean > 1) then report(node.address .. ": ocean share out of range") end
  end)
  R:check("planet_geology", function(node, report)
    if node.kind ~= "planet" or not (node.data.cells and node.data.cells.setting) then return end
    local c = node.data.cells
    for i = 1, #c.elevation do
      if not c.plate[i] or not P.SETTINGS[c.setting[i]] or not P.ROCKS[c.rock[i]] then
        report(node.address .. ": cell " .. i .. " lacks geology")
        return
      end
    end
  end)
end

-- Text for the world bible.
function P.describe(node)
  local d = node.data
  if d.prime then return node.data.name .. ", a planet of the Solar System." end
  if not d.radius then return node.summary.name end
  local parts = { string.format("%s: %.2f Earth radii, gravity %.2f g, %s", node.summary.name, d.radius, d.gravity,
                                d.surface and string.format("air %.2f bar (%s)", d.atmosphere.pressure,
                                                            table.concat(d.atmosphere.gases, ", ")) or "no solid surface") }
  parts[#parts + 1] = d.locked and "tidally locked, one face always towards its star" or
                      string.format("a day of %.1f hours, axial tilt %.0f°", d.day * 24, d.tilt)
  parts[#parts + 1] = string.format("a year of %.0f days, %.0f to %.0f K", d.year, d.temperature.min, d.temperature.max)
  if d.plates then
    parts[#parts + 1] = string.format("%d tectonic plates, %.0f%% ocean, highest point %.1f km", #d.plates,
                                      d.ocean * 100, d.highest)
  end
  if d.cells and d.cells.deposit then
    local kinds = {}
    for _, k in ipairs(d.cells.deposit) do kinds[k] = (kinds[k] or 0) + 1 end
    parts[#parts + 1] = string.format("ore in %d regions, fuels in %d, gems in %d; %d notable deposits", kinds[1] or 0,
                                      kinds[2] or 0, kinds[3] or 0, #d.deposits)
  end
  parts[#parts + 1] = d.water == "liquid" and "liquid seas" or (d.water == "ice" and "frozen seas" or "no open water")
  if d.magic and d.magic.source ~= "none" then
    parts[#parts + 1] = string.format("magic from %s, strongest at cell %d%s", d.magic.source, d.magic.peak_cell,
                                      d.magic.mineral and (", where " .. d.magic.mineral .. " forms") or "")
  end
  return table.concat(parts, "; ") .. "."
end

return P
