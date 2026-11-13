-- Multiversal Van Life - climate, water, biomes and the division of a planet
-- into continents, countries and lands (MIT).
--
-- Planet passes add per-cell climate (temperature, seasons, precipitation,
-- wind), hydrology (filled surface, flow, rivers, lakes), biomes, and the
-- continents and countries. A country plays out in a district: a 32 km
-- window on the planet's surface (16 x 16 lands of 2048 m) placed on its
-- shore, or else on a river, or else around its capital. The district's
-- terrain samples the planet's elevation, so coasts and rivers cross it.
local dm = require("gen.dmath")
local names = require("gen.names")

local G = { LAND = 2048, LANDS = 16, EARTH_RADIUS = 6371000 }

-- Biomes. family: the look and words of provisional settlements
-- (gen/levels/provisional.lua styles).
G.BIOMES = {
  { id = "ocean", family = "marsh", water = true },
  { id = "sea ice", family = "snow", water = true },
  { id = "reef", family = "marsh", water = true },
  { id = "lake", family = "marsh", water = true },
  { id = "ice sheet", family = "snow", texture = "stone", palette = { { 200, 210, 222 }, { 226, 232, 240 }, { 240, 244, 248 }, { 250, 252, 255 } } },
  { id = "tundra", family = "snow", texture = "grass", palette = { { 96, 104, 88 }, { 128, 132, 110 }, { 160, 160, 140 }, { 210, 214, 210 } } },
  { id = "taiga", family = "snow", texture = "grass", trees = { "tree_pine" }, palette = { { 40, 64, 44 }, { 60, 84, 56 }, { 92, 104, 80 }, { 150, 156, 150 } } },
  { id = "temperate forest", family = "temperate", texture = "grass", trees = { "tree_oak", "tree_pine" }, palette = { { 42, 72, 36 }, { 64, 98, 46 }, { 98, 116, 66 }, { 128, 126, 98 } } },
  { id = "grassland", family = "temperate", texture = "grass", trees = { "bush" }, palette = { { 84, 112, 52 }, { 112, 132, 64 }, { 140, 144, 84 }, { 160, 150, 110 } } },
  { id = "cold desert", family = "desert", texture = "sand", trees = { "bush" }, palette = { { 140, 128, 108 }, { 164, 150, 126 }, { 184, 172, 150 }, { 206, 198, 182 } } },
  { id = "hot desert", family = "desert", texture = "sand", trees = { "bush" }, palette = { { 176, 140, 90 }, { 200, 164, 108 }, { 220, 188, 130 }, { 232, 208, 160 } } },
  { id = "savanna", family = "desert", texture = "grass", trees = { "tree_oak", "bush" }, palette = { { 138, 132, 70 }, { 164, 150, 80 }, { 186, 166, 98 }, { 200, 180, 120 } } },
  { id = "seasonal forest", family = "temperate", texture = "grass", trees = { "tree_oak" }, palette = { { 60, 84, 36 }, { 88, 106, 46 }, { 120, 120, 64 }, { 140, 132, 96 } } },
  { id = "rainforest", family = "fungal", texture = "grass", trees = { "tree_oak", "bush", "flowers" }, palette = { { 24, 64, 32 }, { 36, 88, 40 }, { 60, 106, 52 }, { 96, 120, 80 } } },
  { id = "wetland", family = "marsh", texture = "grass", trees = { "bush", "tree_pine" }, palette = { { 34, 62, 54 }, { 50, 80, 62 }, { 76, 96, 70 }, { 96, 106, 84 } } },
  { id = "coast", family = "marsh", texture = "sand", trees = { "bush" }, palette = { { 150, 140, 104 }, { 120, 130, 86 }, { 96, 120, 70 }, { 128, 128, 104 } } },
  { id = "alpine", family = "snow", texture = "stone", trees = { "bush" }, palette = { { 96, 100, 88 }, { 128, 128, 120 }, { 170, 172, 170 }, { 236, 240, 244 } } },
  { id = "barren", family = "desert", texture = "stone", trees = {}, palette = { { 92, 84, 80 }, { 120, 110, 100 }, { 146, 136, 124 }, { 170, 162, 152 } } },
  { id = "ash fields", family = "desert", texture = "stone", trees = { "bush" }, palette = { { 40, 38, 40 }, { 60, 58, 58 }, { 84, 80, 76 }, { 110, 104, 98 } } },
  { id = "crystal forest", family = "crystal", texture = "crystal", trees = { "bush", "flowers" }, palette = { { 60, 40, 90 }, { 90, 60, 130 }, { 130, 100, 170 }, { 180, 160, 210 } } },
  { id = "arcane meadow", family = "crystal", texture = "grass", trees = { "flowers" }, palette = { { 70, 60, 110 }, { 96, 90, 140 }, { 130, 120, 170 }, { 170, 160, 200 } } },
}
G.BIOME = {}
for i, b in ipairs(G.BIOMES) do G.BIOME[b.id] = i end

local function biome_of(t, p, e, setting, magic, strong, thin, lake, coast, flow_high, volcanic_ok, hash)
  local c = t - 273.15
  if e <= 0 then
    if c < -2 then return "sea ice" end
    if c > 24 and e > -0.4 then return "reef" end
    return "ocean"
  end
  if lake then return c < -2 and "sea ice" or "lake" end
  if thin == "airless" then return "barren" end
  if volcanic_ok and hash % 3 == 0 then return "ash fields" end
  -- scorched and dry (or under thin air): nothing grows
  if c > 60 and (p < 500 or thin) then return "barren" end
  -- high, or under thin air, and cold: alpine scrub
  if (e > 3.2 or (thin and p < 900)) and c < 10 then return "alpine" end
  local b
  if c < -12 then b = "ice sheet"
  elseif c < -2 then b = "tundra"
  elseif c < 6 then b = p > 350 and "taiga" or "cold desert"
  elseif c < 19 then b = p > 750 and "temperate forest" or (p > 280 and "grassland" or "cold desert")
  else
    if p > 2000 then b = "rainforest"
    elseif p > 1250 then b = "seasonal forest"
    elseif p > 500 then b = "savanna"
    else b = "hot desert" end
  end
  if p > 1500 and e < 0.4 and flow_high and c > 0 then b = "wetland" end
  if coast and c > -2 and b ~= "wetland" and b ~= "rainforest" and hash % 2 == 0 then b = "coast" end
  if magic > strong then
    if b == "temperate forest" or b == "seasonal forest" or b == "rainforest" or b == "taiga" then b = "crystal forest"
    elseif b == "grassland" or b == "savanna" or b == "tundra" then b = "arcane meadow" end
  end
  return b
end

-- ------------------------------------------------------------- climate
local function climate(ctx)
  local d = ctx.data
  if not d.cells then return end
  local T = d.temperature
  local tilt = d.tilt * dm.pi / 180
  local water = d.water == "liquid" and dm.clamp(d.composition.water + 0.2, 0.2, 1) or (d.water == "ice" and 0.1 or 0.02)
  local span = d.locked and (T.max - T.min) or 70 / (1 + math.min(d.atmosphere.pressure, 30) * 0.08)
  local C = mvl.planet_climate({ level = d.grid, elevation = d.cells.elevation, axis = { 0, 1, 0 }, sub = { 1, 0, 0 },
                                 tilt_sin = dm.sin(tilt), locked = d.locked, mean = T.mean, span = span, lapse = 6.5,
                                 water = water })
  ctx:yield()
  local cells = d.cells
  local temp, tmin, tmax, precip = {}, {}, {}, {}
  -- no air or no water: no rain; frozen worlds get little snow
  local wet = d.water == "none" and 0 or (d.water == "ice" and 0.3 or 1)
  for i = 1, #C.temp do
    temp[i] = dm.round(C.temp[i], 2)
    tmin[i] = dm.round(C.tmin[i], 2)
    tmax[i] = dm.round(C.tmax[i], 2)
    precip[i] = math.floor(C.precip[i] * 1000 * wet + 0.5) -- mm a year
  end
  cells.temp, cells.tmin, cells.tmax, cells.precip, cells.wind = temp, tmin, tmax, precip, C.wind
end

-- ----------------------------------------------------------- hydrology
local function hydrology(ctx)
  local d = ctx.data
  if not d.cells or not d.cells.precip then return end
  local cells, n = d.cells, #d.cells.elevation
  local rain = {}
  for i = 1, n do rain[i] = (cells.elevation[i] > 0 and d.water == "liquid") and cells.precip[i] / 1000 or 0 end
  local H = mvl.planet_rivers({ level = d.grid, elevation = cells.elevation, precip = rain })
  ctx:yield()
  local flow, sorted = {}, {}
  for i = 1, n do
    flow[i] = dm.round(H.flow[i], 3)
    if cells.elevation[i] > 0 then sorted[#sorted + 1] = flow[i] end
  end
  table.sort(sorted)
  local threshold = math.max(2.5, sorted[math.max(1, math.floor(#sorted * 0.93))] or 1e9)
  local river, filled = {}, {}
  for i = 1, n do
    filled[i] = dm.round(H.filled[i], 4)
    river[i] = d.water == "liquid" and cells.elevation[i] > 0 and flow[i] >= threshold
  end
  cells.filled, cells.flow_to, cells.flow, cells.lake, cells.river = filled, H.flow_to, flow, H.lake, river
  d.river_threshold = threshold
  -- the great rivers: the strongest mouths, traced upstream along the main stem
  local mouths = {}
  for i = 1, n do
    if river[i] and (H.flow_to[i] == 0 or cells.elevation[H.flow_to[i]] <= 0) then mouths[#mouths + 1] = i end
  end
  table.sort(mouths, function(a, b) return flow[a] > flow[b] or (flow[a] == flow[b] and a < b) end)
  local upstream = {}
  for i = 1, n do
    local to = H.flow_to[i]
    if to > 0 and river[i] then
      if not upstream[to] or flow[i] > flow[upstream[to]] then upstream[to] = i end
    end
  end
  d.rivers = {}
  for k = 1, math.min(12, #mouths) do
    local path, c = {}, mouths[k]
    while c and #path < 400 do
      table.insert(path, 1, c)
      c = upstream[c]
    end
    d.rivers[k] = { name = names.make(ctx:random("river" .. k), "world") .. " river", cells = path,
                    flow = flow[mouths[k]] }
  end
end

-- -------------------------------------------------------------- biomes
local function biomes(ctx)
  local d = ctx.data
  if not d.cells or not d.cells.temp then return end
  local cells, n = d.cells, #d.cells.elevation
  local pressure = d.atmosphere.pressure
  local thin = pressure < 0.05 and "airless" or (pressure < 0.3 and "thin" or nil)
  local strong = (d.magic and d.magic.strength or 0) * 0.55
  local life = require("gen.life")
  local plants = life.has_plants(d)
  local biome, counts = {}, {}
  for i = 1, n do
    local e = cells.elevation[i]
    local coast = false
    if e > 0 then
      for _, nb in ipairs(mvl.planet_neighbours(d.grid, i)) do
        if cells.elevation[nb] <= 0 then coast = true break end
      end
    end
    local id = biome_of(cells.temp[i], cells.precip[i], e, cells.setting[i], cells.magic and cells.magic[i] or 0,
                        strong > 0 and strong or 99, thin, cells.lake[i], coast,
                        cells.flow[i] >= d.river_threshold * 0.5,
                        cells.setting[i] == require("gen.levels.planet").SETTING["volcanic arc"],
                        mvl.hash(ctx.seed, i) % 7)
    if d.water ~= "liquid" and (id == "ocean" or id == "reef" or id == "lake") then
      id = d.water == "ice" and "sea ice" or "barren"
    end
    -- forests and grasslands need plants: lifeless worlds are bare there
    if not plants and life.VEGETATED[id] then id = "barren" end
    if not plants and id == "reef" then id = "ocean" end
    biome[i] = G.BIOME[id]
    counts[id] = (counts[id] or 0) + 1
    if i % 2500 == 0 then ctx:yield() end
  end
  cells.biome = biome
  d.biome_counts = counts
  -- foliage darkens under red suns (absorbing the little light there is)
  d.dark_foliage = d.star_class == "M"
end

-- --------------------------------------------- continents and countries
local function subdivide(ctx)
  local d = ctx.data
  if not d.cells or not d.cells.biome then return end
  local cells, n = d.cells, #d.cells.elevation
  local rng = ctx:rng()
  local mask = {}
  for i = 1, n do mask[i] = cells.elevation[i] > 0 and not cells.lake[i] end
  local comp, count = mvl.planet_components(d.grid, mask)
  -- continents: landmasses by size (small islands are not continents)
  local size = {}
  for i = 1, n do if comp[i] > 0 then size[comp[i]] = (size[comp[i]] or 0) + 1 end end
  local order = {}
  for c = 1, count do if (size[c] or 0) >= 4 then order[#order + 1] = c end end
  table.sort(order, function(a, b) return size[a] > size[b] or (size[a] == size[b] and a < b) end)
  local cap = ctx.G.registry.levels[ctx.node.level].caps.children
  local continent_of, continent = {}, {}
  for k = 1, math.min(#order, cap) do continent_of[order[k]] = k end
  for i = 1, n do continent[i] = continent_of[comp[i]] or 0 end
  cells.continent = continent
  -- countries: territories grown from seeds spread over each continent
  local seeds, seed_continent = {}, {}
  local members = {}
  for i = 1, n do
    local k = continent[i]
    if k > 0 then
      members[k] = members[k] or {}
      members[k][#members[k] + 1] = i
    end
  end
  d.countries = {}
  for k = 1, #order do
    if not members[k] then break end
    local list = members[k]
    local want = dm.clamp(math.floor(#list / 45) + 1, 1, 24)
    local picked = {}
    for _ = 1, want * 6 do
      if #picked >= want then break end
      local c = list[rng:int(1, #list)]
      local x, y, z = mvl.planet_cell(d.grid, c)
      local ok = true
      for _, o in ipairs(picked) do
        local ox, oy, oz = mvl.planet_cell(d.grid, o)
        if (x - ox) * (x - ox) + (y - oy) * (y - oy) + (z - oz) * (z - oz) < 0.04 then ok = false break end
      end
      if ok then picked[#picked + 1] = c end
    end
    for _, c in ipairs(picked) do
      seeds[#seeds + 1] = c
      seed_continent[#seeds] = k
    end
  end
  local cost = {}
  for i = 1, n do
    if continent[i] == 0 then cost[i] = -1
    else cost[i] = 1 + (cells.elevation[i] > 2.5 and 3 or 0) + (cells.river[i] and 1.5 or 0) end
  end
  local owner = mvl.planet_territory(d.grid, seeds, cost)
  ctx:yield()
  cells.country = owner
  local per_continent = {}
  for id, c in ipairs(seeds) do
    local k = seed_continent[id]
    per_continent[k] = (per_continent[k] or 0) + 1
    d.countries[id] = { continent = k, index = per_continent[k] - 1, capital = c }
  end
  local r_km = d.radius * G.EARTH_RADIUS / 1000
  local area_km2 = 4 * dm.pi * r_km * r_km / n
  for k = 1, math.min(#order, cap) do
    ctx:child(k - 1, { name = names.make(ctx:random("continent" .. k), "cosmic"), cells = size[order[k]],
                       area = math.floor(size[order[k]] * area_km2), countries = per_continent[k] or 0 })
  end
  d.continents = math.min(#order, cap)
end

-- ------------------------------------------------- continent and country
local function continent_pass(ctx)
  local planet = ctx.parent.data
  if not planet.countries then return end
  local k = ctx.node.index + 1
  ctx.data.name = ctx.summary.name
  for id, c in ipairs(planet.countries) do
    if c.continent == k then
      ctx:child(c.index, { name = names.make(ctx:random("country" .. id), "world"), id = id, capital = c.capital })
    end
  end
end

-- Unit vectors east and north at a point of the unit sphere.
local function frame(px, py, pz)
  local ex, ey, ez = pz, 0, -px -- axis (0,1,0) x p
  local l = math.sqrt(ex * ex + ey * ey + ez * ez)
  if l < 1e-6 then ex, ey, ez, l = 1, 0, 0, 1 end
  ex, ey, ez = ex / l, ey / l, ez / l
  local nx, ny, nz = py * ez - pz * ey, pz * ex - px * ez, px * ey - py * ex
  return ex, ey, ez, nx, ny, nz
end

local function normalized(x, y, z)
  local l = math.sqrt(x * x + y * y + z * z)
  return x / l, y / l, z / l
end

-- Picks the district centre of a country: its shore, a river or its capital.
local function district_centre(planet, id, capital)
  local cells, gl = planet.cells, planet.grid
  local best, best_d, kind = nil, math.huge, "inland"
  local cx, cy, cz = mvl.planet_cell(gl, capital)
  for i = 1, #cells.country do
    if cells.country[i] == id then
      local x, y, z = mvl.planet_cell(gl, i)
      local dist = (x - cx) * (x - cx) + (y - cy) * (y - cy) + (z - cz) * (z - cz)
      local shore
      for _, nb in ipairs(mvl.planet_neighbours(gl, i)) do if cells.elevation[nb] <= 0 then shore = nb end end
      local rank = shore and 0 or (cells.river[i] and 1 or 2)
      local cur = kind == "shore" and 0 or (kind == "river" and 1 or 2)
      if rank < cur or (rank == cur and dist < best_d) then
        best, best_d, kind = { cell = i, toward = shore or cells.flow_to[i] }, dist, rank == 0 and "shore" or (rank == 1 and "river" or "inland")
      end
    end
  end
  best = best or { cell = capital }
  local px, py, pz = mvl.planet_cell(gl, best.cell)
  if kind == "shore" then
    -- walk towards the sea until the surface meets sea level, then back a little
    local ox, oy, oz = mvl.planet_cell(gl, best.toward)
    local lo, hi = 0, 1
    for _ = 1, 24 do
      local t = (lo + hi) / 2
      local x, y, z = normalized(px + (ox - px) * t, py + (oy - py) * t, pz + (oz - pz) * t)
      if mvl.planet_sample(gl, cells.elevation, x, y, z) > 0 then lo = t else hi = t end
    end
    local t = lo * 0.98
    px, py, pz = normalized(px + (ox - px) * t, py + (oy - py) * t, pz + (oz - pz) * t)
  end
  return kind, px, py, pz, best
end

-- The country's district: a terrain map sampled from the planet, its river
-- and its roads, in country coordinates (lands at gx * 2048, gz * 2048).
local function district(ctx)
  local d = ctx.data
  local planet = ctx:ancestor("planet").data
  if not planet.cells or not ctx.summary.id then return false end
  local rng = ctx:rng()
  local kind, px, py, pz, spot = district_centre(planet, ctx.summary.id, ctx.summary.capital)
  local ex, ey, ez, nx, ny, nz = frame(px, py, pz)
  local radius_m = planet.radius * G.EARTH_RADIUS
  local half = G.LAND * G.LANDS / 2 - G.LAND / 2 -- centre of the land grid
  local sea_dir
  if kind == "shore" then
    local qx, qy, qz = mvl.planet_cell(planet.grid, spot.toward)
    local sx = (qx - px) * ex + (qy - py) * ey + (qz - pz) * ez
    local sz = -((qx - px) * nx + (qy - py) * ny + (qz - pz) * nz)
    local l = math.sqrt(sx * sx + sz * sz)
    sea_dir = { dm.round(sx / l, 5), dm.round(sz / l, 5) }
  end
  local function to_sphere(x, z)
    local u, v = (x - half) / radius_m, -(z - half) / radius_m
    return normalized(px + ex * u + nx * v, py + ey * u + ny * v, pz + ez * u + nz * v)
  end
  d.district = { kind = kind, centre = { dm.round(px, 6), dm.round(py, 6), dm.round(pz, 6) }, cell = spot.cell,
                 east = { dm.round(ex, 6), dm.round(ey, 6), dm.round(ez, 6) },
                 north = { dm.round(nx, 6), dm.round(ny, 6), dm.round(nz, 6) }, radius = radius_m, -- planet radius (m)
                 sea_dir = sea_dir } -- towards the open sea (country coordinates), on a shore
  -- coarse elevation map every 1024 m, metres above sea level. Heights near
  -- the sea are steepened five-fold (continuously): at walking scale the
  -- planet's slope would otherwise make every shore an endless flat beach.
  local function shape(h)
    local a = math.abs(h)
    local s = a <= 40 and a * 5 or 200 + (a - 40)
    return h < 0 and -s or s
  end
  local step, w = 1024, 37
  local x0 = -G.LAND / 2 - 2 * step
  local data = {}
  local e = planet.cells.elevation
  for j = 0, w - 1 do
    for i = 0, w - 1 do
      local x, y, z = to_sphere(x0 + i * step, x0 + j * step)
      data[j * w + i + 1] = dm.round(shape(mvl.planet_sample(planet.grid, e, x, y, z) * 1000), 2)
    end
    if j % 12 == 0 then ctx:yield() end
  end
  local cell = spot.cell
  local setting = planet.cells.setting[cell]
  local P = require("gen.levels.planet")
  local rough = (setting == P.SETTING.orogen or setting == P.SETTING["volcanic arc"]) and 70 or
                (planet.cells.elevation[cell] > 1.5 and 40 or 12)
  local biome = G.BIOMES[planet.cells.biome[cell]]
  d.terrain = {
    seed = rng:int(0, 1000000), base = 0, amp = rough, freq = dm.round(0.002 + rng:next() * 0.002, 5), octaves = 5,
    lacunarity = 2, gain = 0.5, palette = biome.palette and require("gen.util").copy(biome.palette) or
                                          { { 70, 98, 50 }, { 100, 116, 70 }, { 128, 126, 98 }, { 150, 150, 140 } },
    color_low = -20, color_high = 120, slope_color = { 96, 86, 70 }, slope_start = 0.22, color_noise = 0.1, uv_scale = 4,
    map = { w = w, h = w, x0 = x0, z0 = x0, cell = step, data = data },
  }
  d.style = biome.family
  d.biome = biome.id
  -- a river through the district, from upstream to downstream
  d.rivers = {}
  local through = kind == "river" or (planet.cells.river[cell] and kind ~= "shore")
  if through and planet.cells.flow_to[cell] > 0 then
    local to = planet.cells.flow_to[cell]
    local qx, qy, qz = mvl.planet_cell(planet.grid, to)
    -- downstream direction in district coordinates
    local dx = (qx - px) * ex + (qy - py) * ey + (qz - pz) * ez
    local dz = -((qx - px) * nx + (qy - py) * ny + (qz - pz) * nz)
    local l = math.sqrt(dx * dx + dz * dz)
    dx, dz = dx / l, dz / l
    local pts, level = {}, math.huge
    local wander = rng:int(0, 100000)
    for s = -22, 22 do
      local along = s * 1024
      local side = 400 * mvl.noise(s * 0.37, 0.5, wander, 2)
      local x, z = half + dx * along - dz * side, half + dz * along + dx * side
      local sx, sy, sz = to_sphere(x, z)
      local ground = shape(mvl.planet_sample(planet.grid, e, sx, sy, sz) * 1000)
      level = math.min(level, ground - 3) -- water only flows down
      pts[#pts + 1] = { dm.round(x, 2), dm.round(z, 2), dm.round(level, 2) }
    end
    -- the planet's named river, when the district lies on one
    local rname = "the river"
    for _, r in ipairs(planet.rivers or {}) do
      for _, rc in ipairs(r.cells) do
        if rc == cell or rc == to then rname = r.name end
      end
    end
    d.rivers[1] = { name = rname, width = dm.round(dm.clamp(planet.cells.flow[cell] * 1.5, 10, 40), 1),
                    points = pts }
  end
  return true
end

-- ------------------------------------------------------- world bible
local function top_biomes(counts, k)
  local list = {}
  for id, n in pairs(counts or {}) do list[#list + 1] = { id = id, n = n } end
  table.sort(list, function(a, b) return a.n > b.n or (a.n == b.n and a.id < b.id) end)
  local out = {}
  for i = 1, math.min(k, #list) do out[i] = string.format("%s (%d)", list[i].id, list[i].n) end
  return table.concat(out, ", ")
end

function G.describe_planet(node)
  local text = require("gen.levels.planet").describe(node)
  local d = node.data
  if d.sky then text = text .. "\n\n" .. require("gen.visuals.sky").describe(d.sky) end
  local lives = require("gen.life").describe(d)
  if lives then text = text .. "\n\n" .. lives end
  if not d.cells or not d.cells.temp then return text end
  local c = d.cells
  local lo, hi, wet, land = math.huge, -math.huge, 0, 0
  for i = 1, #c.temp do
    lo, hi = math.min(lo, c.tmin[i]), math.max(hi, c.tmax[i])
    if c.elevation[i] > 0 then land, wet = land + 1, wet + c.precip[i] end
  end
  local parts = { string.format("Climate: %.0f to %.0f K over the year, %.0f mm of rain a year on average over land",
                                lo, hi, land > 0 and wet / land or 0) }
  if #d.rivers > 0 then
    local rn = {}
    for i = 1, math.min(3, #d.rivers) do rn[i] = d.rivers[i].name end
    parts[#parts + 1] = string.format("%d great rivers (%s)", #d.rivers, table.concat(rn, ", "))
  end
  parts[#parts + 1] = "biomes: " .. top_biomes(d.biome_counts, 5)
  if d.dark_foliage then parts[#parts + 1] = "dark foliage under a red sun" end
  parts[#parts + 1] = string.format("%d continents, %d countries", d.continents or 0, #(d.countries or {}))
  return text .. "\n\n" .. table.concat(parts, "; ") .. "."
end

function G.describe_continent(node)
  local s = node.summary
  if not s.cells then return tostring(s.name) end
  return string.format("%s: a continent of %d regions, about %d km², divided into %d countries.", s.name, s.cells,
                       s.area, s.countries)
end

function G.describe_country(node)
  local d, s = node.data, node.summary
  if not d.district then return tostring(s.name) end
  local where = d.district.kind == "shore" and "on the coast" or
                (d.district.kind == "river" and "along a river" or "inland, around its capital")
  local text = string.format("%s: the explored district lies %s; its land is %s.", s.name, where, d.biome)
  if d.rivers[1] then
    text = text .. string.format(" %s runs through it, %.0f m wide.", d.rivers[1].name, d.rivers[1].width)
  end
  return text
end

function G.register(R)
  R:describe("planet", G.describe_planet)
  R:describe("continent", G.describe_continent)
  R:describe("country", G.describe_country)
  R:pass("planet", "climate", { after = { "magic" }, run = function(ctx) if not ctx.summary.prime then climate(ctx) end end })
  R:pass("planet", "hydrology", { after = { "climate" }, run = function(ctx) if not ctx.summary.prime then hydrology(ctx) end end })
  R:pass("planet", "biomes", { after = { "hydrology", "biochemistry" }, run = function(ctx) if not ctx.summary.prime then biomes(ctx) end end })
  R:pass("planet", "subdivision", { after = { "biomes" }, run = function(ctx) if not ctx.summary.prime then subdivide(ctx) end end })
  R:pass("continent", "countries", { run = function(ctx) if not ctx.summary.prime then continent_pass(ctx) end end })

  -- rivers run downhill and lakes sit in basins
  R:check("hydrology", function(node, report)
    if node.kind ~= "planet" or not (node.data.cells and node.data.cells.flow_to) then return end
    local c = node.data.cells
    for i = 1, #c.flow_to do
      local to = c.flow_to[i]
      if to > 0 and c.filled[to] > c.filled[i] then
        report(node.address .. ": water flows uphill from cell " .. i)
        return
      end
    end
  end)
end

G.district = district
G.to_sphere_frame = frame
return G
