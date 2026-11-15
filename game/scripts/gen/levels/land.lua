-- Multiversal Van Life - countries and lands (MIT).
--
-- Lands lie on 16 x 16 grids of 2048 m squares; land index i sits at grid
-- (i % 16, i // 16). Since the surface grid a land belongs to a region
-- (gen/levels/region.lua): it is centred on its face position, samples the
-- region's ground on its own crop of the planet-wide lattice, takes the
-- rivers and lakes the region plan gives and belongs to the country the
-- atlas puts there. In multiverses from before the grid a land belongs to a
-- country's district, which holds one continuous terrain and its road
-- network, the land centred on (gx * 2048, gz * 2048) in country
-- coordinates. A land's description (features, fields, roads, flat areas,
-- flora, spots) uses land-local metres around its centre; gen/chunks turns
-- it into the walkable world.
local dm = require("gen.dmath")
local prime = require("gen.prime")
local util = require("gen.util")
local provisional = require("gen.levels.provisional")
local quests = require("gen.quests")

local land = { SIZE = 2048, GRID = 16, ROAD_STEP = 128 }

function land.grid(index) return index % land.GRID, index // land.GRID end

function land.index(gx, gz)
  if gx < 0 or gz < 0 or gx >= land.GRID or gz >= land.GRID then return nil end
  return gz * land.GRID + gx
end

-- Catmull-Rom, as the engine's terrain map (terrain.c).
local function cubic(p0, p1, p2, p3, s)
  return p1 + 0.5 * s * (p2 - p0 + s * (2 * p0 - 5 * p1 + 4 * p2 - p3 + s * (3 * (p1 - p2) + p3 - p0)))
end

local function map_at(m, x, z)
  x = x < 0 and 0 or (x >= m.w and m.w - 1 or x)
  z = z < 0 and 0 or (z >= m.h and m.h - 1 or z)
  return m.data[z * m.w + x + 1]
end

function land.sample_map(m, x, z, data)
  local gx, gz = (x - m.x0) / m.cell, (z - m.z0) / m.cell
  if data then m = { w = m.w, h = m.h, data = data } end
  local fx, fz = math.floor(gx), math.floor(gz)
  local sx, sz = gx - fx, gz - fz
  local rows = {}
  for j = 0, 3 do
    rows[j + 1] = cubic(map_at(m, fx - 1, fz - 1 + j), map_at(m, fx, fz - 1 + j), map_at(m, fx + 1, fz - 1 + j),
                        map_at(m, fx + 2, fz - 1 + j), sx)
  end
  return cubic(rows[1], rows[2], rows[3], rows[4], sz)
end

-- Terrain height before any flattening, in country (or face) coordinates,
-- as the engine computes it (terrain.c): the detail noise, periodic on the
-- surface grid and scaled by the map's roughness, plus the map.
function land.raw_height(t, x, z)
  local k, add = 1, 0
  if t.map then
    add = land.sample_map(t.map, x, z)
    if t.map.amp then k = math.max(0, land.sample_map(t.map, x, z, t.map.amp)) end
  end
  local n
  if t.period then
    n = mvl.noise((x % t.wrap) * t.freq, (z % t.wrap) * t.freq, t.seed, t.octaves, 2, t.gain, t.period)
  else
    n = mvl.noise(x * t.freq, z * t.freq, t.seed, t.octaves, t.lacunarity, t.gain)
  end
  return t.base + t.amp * k * n + add
end

local NEIGHBOURS = { "Mabel", "Agnes", "Walter", "Edith", "Arthur", "Hazel", "Ruth", "Albert", "Ivy", "Frank",
                     "Doris", "Harold", "Elsie", "Stanley", "Winnie", "Cecil" }
local TINTS = { { 1, 1, 1, 1 }, { 1, 0.85, 0.75, 1 }, { 0.8, 0.9, 1, 1 }, { 0.95, 1, 0.8, 1 }, { 1, 0.8, 0.9, 1 } }
local CROPS = {
  { name = "ploughed", texture = "dirt", tint = { 0.85, 0.75, 0.65, 1 } },
  { name = "wheat", texture = "grass", tint = { 1.6, 1.35, 0.55, 1 } },
  { name = "barley", texture = "grass", tint = { 1.3, 1.25, 0.7, 1 } },
  { name = "cabbages", texture = "grass", tint = { 0.7, 1.15, 0.8, 1 } },
}

land.STYLES = {
  countryside = { trees = { "tree_oak", "tree_pine" }, tree_count = 4, bush_count = 3, flower_count = 1, texture = "grass" },
  farm = { trees = { "tree_oak", "tree_pine" }, tree_count = 3, bush_count = 3, flower_count = 2, texture = "grass" },
}

-- ---------------------------------------------------------------- country
local function country_terrain(ctx)
  local rng = ctx:rng()
  local d = ctx.data
  local planet = ctx:ancestor("planet")
  if not ctx.summary.prime and require("gen.levels.geography").district(ctx) then
    -- the old road crosses the district, broken where it would run into water
    local wander = rng:int(0, 100000)
    d.roads = {}
    local run = {}
    local x = -land.SIZE / 2
    while x <= (land.GRID - 0.5) * land.SIZE do
      local z = 60 + 30 * mvl.noise(x * 0.0021, 0.5, wander, 2) + 4 * land.SIZE
      local dry = land.raw_height(d.terrain, x, z) > 1.5
      if dry then run[#run + 1] = { dm.round(x, 2), dm.round(z, 2) } end
      if (not dry or x + land.ROAD_STEP > (land.GRID - 0.5) * land.SIZE) and #run > 0 then
        if #run >= 2 then d.roads[#d.roads + 1] = { name = "the old road", width = 4, points = run } end
        run = {}
      end
      x = x + land.ROAD_STEP
    end
    return
  end
  d.style = planet.data.style or "countryside"
  local st = planet.data.style and provisional.style(planet.data.style).terrain
  d.terrain = {
    seed = rng:int(0, 1000000), base = 0, amp = dm.round((st and st.amp or 5) + rng:next() * 4, 3),
    freq = dm.round((st and st.freq or 0.005) + rng:next() * 0.003, 5), octaves = 4, lacunarity = 2, gain = 0.5,
    palette = st and util.copy(st.palette) or { { 46, 70, 36 }, { 68, 96, 48 }, { 100, 116, 70 }, { 128, 126, 98 } },
    color_low = -7, color_high = 9, slope_color = { 96, 86, 70 }, slope_start = 0.22, color_noise = 0.1, uv_scale = 4,
  }
  -- the old road: west to east along the first row of lands, wandering
  local pts, wander = {}, rng:int(0, 100000)
  local x = -land.SIZE / 2
  while x <= (land.GRID - 0.5) * land.SIZE do
    local z = 60 + 30 * mvl.noise(x * 0.0021, 0.5, wander, 2)
    pts[#pts + 1] = { dm.round(x, 2), dm.round(z, 2) }
    x = x + land.ROAD_STEP
  end
  d.roads = { { name = "the old road", width = 4, points = pts } }
end

-- ------------------------------------------------------------------ lands
local function add_flat(d, x, z, radius, falloff, h)
  d.flats[#d.flats + 1] = { x = dm.round(x, 3), z = dm.round(z, 3), radius = radius, falloff = falloff, height = dm.round(h, 3) }
end

-- Country roads crossing this land, with graded heights and segment flats.
local function clip_roads(ctx, d, country)
  local cx, cz, half = d.center[1], d.center[2], land.SIZE / 2
  for _, road in ipairs(country.roads) do
    local local_pts = {}
    for i, p in ipairs(road.points) do
      local next_p, prev_p = road.points[i + 1], road.points[i - 1]
      local inside = math.abs(p[1] - cx) <= half and math.abs(p[2] - cz) <= half
      local near = (next_p and math.abs(next_p[1] - cx) <= half and math.abs(next_p[2] - cz) <= half) or
                   (prev_p and math.abs(prev_p[1] - cx) <= half and math.abs(prev_p[2] - cz) <= half)
      if inside or near then
        local_pts[#local_pts + 1] = { dm.round(p[1] - cx, 2), dm.round(p[2] - cz, 2), dm.round(land.raw_height(country.terrain, p[1], p[2]), 3) }
      end
    end
    if #local_pts >= 2 then
      d.roads[#d.roads + 1] = { name = road.name, width = road.width, texture = "dirt", points = local_pts }
      for i = 1, #local_pts - 1 do
        local a, b = local_pts[i], local_pts[i + 1]
        d.flats[#d.flats + 1] = { x = a[1], z = a[2], x2 = b[1], z2 = b[2], radius = road.width / 2 + 0.6, falloff = 4,
                                  height = a[3], height2 = b[3] }
      end
    end
  end
end

-- The country's river through this land: a graded bed (segment flats) and a
-- water surface, both following the planet's river course.
local function clip_rivers(d, country)
  local cx, cz, half = d.center[1], d.center[2], land.SIZE / 2 + 1100
  d.rivers = {}
  for _, river in ipairs(country.rivers or {}) do
    local pts = {}
    for _, p in ipairs(river.points) do
      if math.abs(p[1] - cx) <= half and math.abs(p[2] - cz) <= half then
        pts[#pts + 1] = { dm.round(p[1] - cx, 2), dm.round(p[2] - cz, 2), p[3] }
      end
    end
    if #pts >= 2 then
      d.rivers[#d.rivers + 1] = { name = river.name, width = river.width, points = pts }
      for i = 1, #pts - 1 do
        local a, b = pts[i], pts[i + 1]
        d.flats[#d.flats + 1] = { x = a[1], z = a[2], x2 = b[1], z2 = b[2], radius = river.width / 2 + 2, falloff = 14,
                                  height = dm.round(a[3] - 2, 2), height2 = dm.round(b[3] - 2, 2) }
      end
    end
  end
end

-- Where the land lies on its planet: cell, biome, climate, continent, country.
local function place_on_planet(ctx, d, country, view)
  local planet = ctx:ancestor("planet")
  local dist = country.district
  if not (dist or country.direction) or not planet.data.cells then return end
  local cells = planet.data.cells
  local x, y, z
  if country.direction then
    x, y, z = country.direction[1], country.direction[2], country.direction[3]
  else
    local half = land.SIZE * land.GRID / 2 - land.SIZE / 2
    local u, v = (d.center[1] - half) / dist.radius, -(d.center[2] - half) / dist.radius
    local c, e, n = dist.centre, dist.east, dist.north
    x, y, z = c[1] + e[1] * u + n[1] * v, c[2] + e[2] * u + n[2] * v, c[3] + e[3] * u + n[3] * v
  end
  local cell = mvl.planet_nearest(planet.data.grid, x, y, z)
  if cells.elevation[cell] <= 0 then
    -- on the shore: the land side tells the biome and climate
    local best, bd = nil, -2
    for _, nb in ipairs(mvl.planet_neighbours(planet.data.grid, cell)) do
      local qx, qy, qz = mvl.planet_cell(planet.data.grid, nb)
      local dd = qx * x + qy * y + qz * z
      if cells.elevation[nb] > 0 and dd > bd then best, bd = nb, dd end
    end
    cell = best or cell
  end
  local geo = require("gen.levels.geography")
  local biome = geo.BIOMES[cells.biome[cell]]
  local l = math.sqrt(x * x + y * y + z * z)
  d.place = { cell = cell, latitude = dm.round(dm.atan(y / l, math.sqrt(x * x + z * z) / l) * 180 / dm.pi, 3),
              longitude = dm.round(dm.atan(z, x) * 180 / dm.pi, 3) }
  d.biome = biome.id
  d.heavens = require("gen.visuals.sky").heavens(planet.data)
  d.climate = { temperature = dm.round(cells.temp[cell] - 273.15, 1), coldest = dm.round(cells.tmin[cell] - 273.15, 1),
                warmest = dm.round(cells.tmax[cell] - 273.15, 1), precipitation = cells.precip[cell] }
  d.materials = require("gen.visuals.palette").materials(planet.data, cell, biome, d.climate)
  d.habitats = require("gen.life.habitats").for_land(planet.data, cell, biome, planet.seed)
  d.continent = view.continent
  d.country = view.summary.name
  d.coast = false
  for _, nb in ipairs(mvl.planet_neighbours(planet.data.grid, cell)) do
    if cells.elevation[nb] <= 0 then d.coast = true end
  end
  return biome
end

-- A dry, open spot near the land's middle for a settlement (land-local).
local function dry_spot(d, height)
  local function ok(x, z)
    local h = height(x, z)
    if h < 2.5 then return false end
    local level = d.lakes and require("gen.levels.region").lake_at(d.lakes, x, z, 200)
    if level and h < level + 2.5 then return false end
    for _, r in ipairs(d.rivers or {}) do
      for i = 1, #r.points - 1 do
        local a, b = r.points[i], r.points[i + 1]
        local sx, sz = b[1] - a[1], b[2] - a[2]
        local len2 = sx * sx + sz * sz
        local t = len2 > 0 and math.max(0, math.min(1, ((x - a[1]) * sx + (z - a[2]) * sz) / len2)) or 0
        local dx, dz = x - (a[1] + sx * t), z - (a[2] + sz * t)
        if dx * dx + dz * dz < (r.width + 45) * (r.width + 45) then return false end
      end
    end
    for _, o in ipairs({ { 0, 0 }, { 30, 0 }, { -30, 0 }, { 0, 30 }, { 0, -30 } }) do
      if height(x + o[1], z + o[2]) < 2.0 then return false end
    end
    return true
  end
  for ring = 0, 12 do
    for k = 0, math.max(0, ring * 6 - 1) do
      local a = ring == 0 and 0 or (k / (ring * 6)) * 2 * dm.pi
      local x, z = dm.round(dm.cos(a) * ring * 70, 2), dm.round(dm.sin(a) * ring * 70, 2)
      if ok(x, z) then return x, z end
    end
  end
  return nil
end

-- Where the road crosses local x (for lanes joining it).
local function road_z_at(d, x)
  local road = d.roads[1]
  if not road then return nil end
  for i = 1, #road.points - 1 do
    local a, b = road.points[i], road.points[i + 1]
    if x >= a[1] and x <= b[1] then
      local t = (x - a[1]) / (b[1] - a[1])
      return a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
    end
  end
end

local function farm(ctx, d, country)
  local rng = ctx:rng()
  local T = country.terrain
  local cx, cz = d.center[1], d.center[2]
  local function h(x, z) return land.raw_height(T, x + cx, z + cz) end
  -- the farmhouse anchors everything recognisable: gate, van spot, door
  local hx, hz = dm.round(rng:float(-8, 8), 3), dm.round(rng:float(-14, -4), 3)
  local yaw = dm.round(rng:float(-0.45, 0.45), 4)
  local c, s = dm.cos(yaw), dm.sin(yaw)
  local function at(lx, lz) return dm.round(hx + c * lx + s * lz, 3), dm.round(hz - s * lx + c * lz, 3) end
  local yard = h(hx, hz)
  add_flat(d, hx, hz, 17, 10, yard)
  local f = d.features
  f[#f + 1] = { id = "farmhouse", role = "farmhouse", voxel = "house", x = hx, z = hz, yaw = yaw, box = { 6.0, 5.0 } }
  local lx, lz = at(4.2, 3.5)
  f[#f + 1] = { id = "lamp", role = "lamp", model = "lamp", x = lx, z = lz, radius = 0.2 }
  -- barn somewhere behind the house, well in the yard
  local bx, bz = at(rng:float(-17, -11), rng:float(-11, -4))
  add_flat(d, bx, bz, 6, 6, yard)
  f[#f + 1] = { id = "barn", role = "barn", voxel = "barn", x = bx, z = bz, yaw = dm.round(yaw + rng:float(-0.5, 0.5), 4),
                box = { 5.0, 4.0 } }
  local wx, wz = at(rng:float(-7, -3), rng:float(5, 9))
  f[#f + 1] = { id = "well", role = "well", voxel = "well", x = wx, z = wz, radius = 0.9 }
  -- fence along the front of the yard with a gap for the gate
  for i = 0, 8 do
    if i ~= 6 then
      local fx, fz = at(9.5, i * 2.0)
      f[#f + 1] = { id = "fence" .. i, role = "fence", voxel = "fence", x = fx, z = fz, yaw = dm.round(yaw + dm.pi / 2, 4),
                    box = { 2.0, 0.3 } }
    end
  end
  local gx, gz = at(9.5, 12)
  local vx, vz = at(11.8, 9)
  add_flat(d, vx, vz, 4, 7, yard)
  local sx, sz = at(3.6, 1.5)
  local nx, nz = at(rng:float(-4, -1), rng:float(10, 13))
  d.spots = {
    gate = { x = gx, z = gz }, van = { x = vx, z = vz, yaw = dm.round(yaw + dm.pi / 2, 4) },
    spawn = { x = sx, z = sz, yaw = dm.round(yaw - 0.9, 4) },
  }
  d.neighbour = { name = NEIGHBOURS[rng:int(1, #NEIGHBOURS)], texture = "npc_farmer", tint = TINTS[rng:int(1, #TINTS)],
                  x = nx, z = nz }
  -- a lane from the van spot to the old road
  local rz, rh = road_z_at(d, vx)
  if rz then
    local pts, steps = {}, 4
    local ez = rz - 2
    for i = 0, steps do
      local t = i / steps
      local px, pz = dm.round(vx + (rng:next() - 0.5) * (i > 0 and i < steps and 3 or 0), 2), dm.round(vz + (ez - vz) * t, 2)
      pts[#pts + 1] = { px, pz, dm.round(i == 0 and yard or (i == steps and rh or h(px, pz)), 3) }
    end
    d.roads[#d.roads + 1] = { name = "the farm lane", width = 3, texture = "dirt", points = pts }
    for i = 1, #pts - 1 do
      local a, b = pts[i], pts[i + 1]
      d.flats[#d.flats + 1] = { x = a[1], z = a[2], x2 = b[1], z2 = b[2], radius = 2.1, falloff = 4, height = a[3],
                                height2 = b[3] }
    end
  end
  -- fields around the farm
  d.clear = { { x = hx, z = hz, r = 24 }, { x = vx, z = vz, r = 7 } }
  for _ = 1, rng:int(2, 4) do
    for _ = 1, 12 do
      local a, dist = rng:next() * 2 * dm.pi, rng:float(32, 75)
      local fx, fz = dm.round(hx + dm.cos(a) * dist, 2), dm.round(hz + dm.sin(a) * dist, 2)
      local w, dd = dm.round(rng:float(14, 26), 2), dm.round(rng:float(12, 22), 2)
      local r = math.sqrt(w * w + dd * dd) / 2
      local ok = math.abs(fz - (road_z_at(d, fx) or 1e9)) > r + 6
      for _, c2 in ipairs(d.clear) do
        local dx, dz, rr = fx - c2.x, fz - c2.z, r + c2.r
        if dx * dx + dz * dz < rr * rr then ok = false end
      end
      if ok then
        local crop = CROPS[rng:int(1, #CROPS)]
        add_flat(d, fx, fz, r, 6, h(fx, fz))
        d.fields[#d.fields + 1] = { x = fx, z = fz, w = w, d = dd, yaw = dm.round(rng:next() * dm.pi, 4), crop = crop.name,
                                    texture = crop.texture, tint = crop.tint }
        d.clear[#d.clear + 1] = { x = fx, z = fz, r = r + 1 }
        break
      end
    end
  end
end

-- ------------------------------------------------- buildings at human scale
-- The hand-made models used where no people's architecture is known, and how
-- much they are enlarged to human scale (their size in metres at scale 1).
land.FALLBACK = {
  house = { w = 6, d = 5, scale = 1.6 }, barn = { w = 5, d = 4, scale = 2.4 },
  market_stall = { w = 3, d = 2, scale = 1.3 }, bookshelf = { w = 2, d = 0.75, scale = 1.2 },
  well = { w = 1.75, d = 1.75, scale = 1.4 },
}

-- Do two boxes { x, z, hw, hd, yaw } (half sizes) overlap?
local function boxes_overlap(a, b)
  local axes = {}
  for _, q in ipairs({ a, b }) do
    local c, s = dm.cos(q.yaw), dm.sin(q.yaw)
    axes[#axes + 1] = { c, -s }
    axes[#axes + 1] = { s, c }
  end
  local dx, dz = b.x - a.x, b.z - a.z
  for _, ax in ipairs(axes) do
    local function extent(q)
      local c, s = dm.cos(q.yaw), dm.sin(q.yaw)
      return q.hw * math.abs(c * ax[1] - s * ax[2]) + q.hd * math.abs(s * ax[1] + c * ax[2])
    end
    if math.abs(dx * ax[1] + dz * ax[2]) > extent(a) + extent(b) then return false end
  end
  return true
end
land.boxes_overlap = boxes_overlap

-- Is the point (x, z) inside box q (grown by `margin`)?
local function inside_box(q, x, z, margin)
  local c, s = dm.cos(q.yaw), dm.sin(q.yaw)
  local dx, dz = x - q.x, z - q.z
  local lx, lz = c * dx - s * dz, s * dx + c * dz
  return math.abs(lx) <= q.hw + margin and math.abs(lz) <= q.hd + margin
end
land.inside_box = inside_box

-- Lays a settlement's buildings out by their real footprints: in rings
-- around the square, their doors facing it (temples of sky faiths face the
-- east), never overlapping, off the lane to the van, on dry ground, each on
-- levelled ground and clear of trees. Buildings that do not fit are left out.
function land.layout_buildings(ctx, d, height)
  local sq, van = d.spots and d.spots.square, d.spots and d.spots.van
  if not sq or not van then return end
  local B = require("gen.visuals.buildings")
  local list = {}
  for _, f in ipairs(d.features) do
    if f.building and d.architecture then
      local p = B.plan(f.building, d.architecture, f.variant or 0)
      f.box = { dm.round(p.metres.w, 3), dm.round(p.metres.d, 3) }
      list[#list + 1] = f
    elseif f.role == "building" and land.FALLBACK[f.voxel] then
      local s = land.FALLBACK[f.voxel]
      f.scale = s.scale
      f.box = { dm.round(s.w * s.scale, 3), dm.round(s.d * s.scale, 3) }
      f.radius = nil
      list[#list + 1] = f
    end
  end
  table.sort(list, function(a, b)
    local ta, tb = a.building == "temple", b.building == "temple"
    if ta ~= tb then return ta end
    local aa, ab = a.box[1] * a.box[2], b.box[1] * b.box[2]
    if aa ~= ab then return aa > ab end
    return a.id < b.id
  end)
  local rng = ctx:random("layout")
  local to_van = dm.atan(van.z - sq.z, van.x - sq.x)
  local lane = {}
  local lx, lz = van.x - sq.x, van.z - sq.z
  local llen = math.sqrt(lx * lx + lz * lz)
  for k = 0, math.floor(llen / 2) do
    local t = k * 2 / math.max(llen, 1e-6)
    lane[#lane + 1] = { sq.x + lx * t, sq.z + lz * t }
  end
  local placed, keep = {}, {}
  for _, f in ipairs(list) do
    local hw, hd = f.box[1] / 2, f.box[2] / 2
    local sky = f.building == "temple" and d.architecture and d.architecture.sky_faith
    local spot
    for ring = 0, 5 do
      if spot then break end
      local r = 11 + hd + ring * 14 + rng:next() * 2
      local step = math.min(0.4, (2 * hw + 3) / r * 0.5)
      -- the temple across the square from the van, the others along both
      -- sides of the way in (the van arrives into the village)
      local first = f.building == "temple" and dm.pi or 0.75
      for k = 0, math.floor(dm.pi / step) do
        if spot then break end
        for _, sgn in ipairs({ 1, -1 }) do
          local a = to_van + sgn * (first + (f.building == "temple" and -k or k) * step)
          local bx, bz = sq.x + dm.cos(a) * r, sq.z + dm.sin(a) * r
          local yaw = sky and -dm.pi / 2 or dm.atan(dm.cos(a), dm.sin(a))
          local q = { x = bx, z = bz, hw = hw, hd = hd, yaw = yaw }
          local ok = height(bx, bz) > 1.2
          for _, o in ipairs(placed) do
            if ok and boxes_overlap({ x = o.x, z = o.z, hw = o.hw + 1.5, hd = o.hd + 1.5, yaw = o.yaw }, q) then ok = false end
          end
          for _, pt in ipairs(lane) do if ok and inside_box(q, pt[1], pt[2], 2.5) then ok = false end end
          if ok and inside_box(q, van.x, van.z, 6) then ok = false end
          for _, rv in ipairs(ok and d.rivers or {}) do
            for i = 1, #rv.points - 1 do
              local p1, p2 = rv.points[i], rv.points[i + 1]
              if ok and (inside_box(q, p1[1], p1[2], rv.width + 4) or
                         inside_box(q, (p1[1] + p2[1]) / 2, (p1[2] + p2[2]) / 2, rv.width + 4)) then ok = false end
            end
          end
          if ok then spot = q break end
        end
      end
    end
    if spot then
      f.x, f.z, f.yaw = dm.round(spot.x, 2), dm.round(spot.z, 2), dm.round(spot.yaw, 4)
      placed[#placed + 1] = { x = f.x, z = f.z, hw = hw, hd = hd, yaw = f.yaw }
      local r = math.sqrt(hw * hw + hd * hd)
      add_flat(d, f.x, f.z, r + 0.5, 4, height(f.x, f.z))
      d.clear = d.clear or {}
      d.clear[#d.clear + 1] = { x = f.x, z = f.z, r = dm.round(r + 1.5, 2) }
    else
      keep[f] = false
    end
  end
  -- what did not fit is not built
  local out = {}
  for _, f in ipairs(d.features) do if keep[f] ~= false then out[#out + 1] = f end end
  d.features = out
  d.buildings_left_out = 0
  for _ in pairs(keep) do d.buildings_left_out = d.buildings_left_out + 1 end
end

local function countryside(ctx, d)
  local rng = ctx:rng()
  d.clear = {}
  -- the odd haystack
  for i = 1, rng:int(0, 3) do
    local x, z = dm.round(rng:float(-900, 900), 2), dm.round(rng:float(-900, 900), 2)
    d.features[#d.features + 1] = { id = "haystack" .. i, role = "haystack", model = "cube", x = x, z = z,
                                    scale = { 1.6, 1.4, 1.6 }, color = { 0.85, 0.72, 0.35, 1 }, box = { 1.6, 1.6 } }
  end
end

-- A settlement with people and a trouble around (ax, az): named in the
-- language of the people living here, its people of history, monuments,
-- traces, troubles, lore, codex entries and quest.
local function settle(ctx, d, view, height, ax, az)
  provisional.settlement(ctx, d, d.style, height, ax, az)
  -- a people of the planet lives here: names in their language
  local culture = require("gen.culture")
  local planet = ctx:ancestor("planet")
  local cul = culture.of_country(planet.data, view.summary.id)
  if cul then
    local n = culture.land_name(planet.data, view.summary.id, ctx.node.seed)
    d.name, d.name_meaning = n.name, n.meaning
    d.culture = { id = cul.id, name = cul.name, species = cul.species, religion = planet.data.religions[cul.religion].name }
    d.nation = view.summary.nation
    for i, p in ipairs(d.people) do
      local pn = culture.person_name(cul, mvl.hash(ctx.node.seed, "person", i))
      p.name, p.name_meaning, p.species = pn.name, pn.meaning, cul.species
      -- a voxel body of their species in their culture's dress
      p.body = { anatomy = util.copy(cul.anatomy), hue = cul.hue, dress = util.copy(cul.style.dress),
                 accent = cul.style.palette.accent, seed = mvl.hash(ctx.node.seed, "body", i) % 3 }
      -- the first waits for the van, the others face the square
      local tx, tz = d.spots.square.x, d.spots.square.z
      if i == 1 then tx, tz = d.spots.van.x, d.spots.van.z end
      p.yaw = dm.round(dm.atan(-(tx - p.x), -(tz - p.z)), 4)
    end
    -- buildings in the culture's style, in the land's own stone
    d.architecture = require("gen.culture.architecture").local_style(cul.style, d.materials and d.materials.stone)
    local KIND = { house = "house", barn = "barn", market_stall = "workshop", bookshelf = "inn", well = "well" }
    local temple = false
    for _, f in ipairs(d.features) do
      if f.role == "building" and KIND[f.voxel] then
        f.building = KIND[f.voxel]
        if not temple and f.building == "house" then f.building, temple = "temple", true end
        f.variant = mvl.hash(ctx.node.seed, f.id) % 3
      end
    end
    -- people of the planet's history who live here now
    for k, c in ipairs(ctx:commitments("resident")) do
      local who = c.data.data.individual
      local sq = d.spots.square
      local lines = { string.format("I am %s, %s of the %s.", who.name, who.role, who.nation) }
      for i = #who.deeds, math.max(1, #who.deeds - 2), -1 do
        local deed = who.deeds[i]
        lines[#lines + 1] = string.format("%d years ago I %s.", math.floor(deed.ago + 0.5), deed.text)
      end
      local person = { id = "resident" .. k, name = who.name, name_meaning = who.meaning, legend = true,
                       role = who.role, nation = who.nation, lines = lines,
                       x = dm.round(sq.x + 4 + k * 2, 2), z = dm.round(sq.z + 3, 2) }
      person.yaw = dm.round(dm.atan(-(sq.x - person.x), -(sq.z - person.z)), 4)
      if who.anatomy then
        person.body = { anatomy = util.copy(who.anatomy), hue = who.hue, dress = who.dress, accent = who.accent,
                        seed = k }
      end
      person.texture, person.species = d.people[1] and d.people[1].texture or "npc_farmer", cul.species
      d.people[#d.people + 1] = person
      ctx:honour(c, ctx:fact("resident", { name = who.name, role = who.role }, c))
    end
    -- the legend of the Wanderer
    if cul.wanderer then
      d.wanderer = { years_ago = cul.wanderer.years_ago, told = cul.wanderer.told }
    end
    -- monuments promised by the planet: the statue of an individual
    for _, c in ipairs(ctx:commitments("monument")) do
      local who = c.data.data.individual
      local sq = d.spots.square
      local st = d.materials and d.materials.stone
      d.features[#d.features + 1] = {
        id = "monument", role = "monument", x = sq.x, z = sq.z - 3, yaw = 0, box = { 1.8, 1.4 },
        statue = { anatomy = util.copy(who.anatomy), hue = who.hue, attributes = util.copy(who.attributes),
                   name = who.name, role = who.role, stone = st and { st[1], st[3], st[4] } or nil, fact = who.fact },
      }
      ctx:honour(c, ctx:fact("monument", { name = "the statue of " .. who.name, individual = who.name }, c))
    end
  end
  -- buildings at human scale, laid out by their footprints
  land.layout_buildings(ctx, d, height)
  -- traces history left here: ruins, battlefields, wrecks, craters, shrines
  local sq = d.spots.square
  for k, c in ipairs(ctx:commitments("trace")) do
    local tr = c.data.data
    if k <= 3 then
      local a = k * 2.1 + 0.7
      local f = { id = "trace" .. k, role = "trace", x = dm.round(sq.x + dm.cos(a) * 45, 2),
                  z = dm.round(sq.z + dm.sin(a) * 45, 2), yaw = dm.round(a, 4),
                  trace = { kind = tr.kind, name = tr.name, year = tr.year, event = tr.event, culture = tr.culture,
                            style = tr.style, seed = k, fact = c.because and c.because[1] } }
      if tr.kind == "ruin" then f.box = { 6, 6 } end
      d.features[#d.features + 1] = f
      d.traces = d.traces or {}
      d.traces[#d.traces + 1] = { kind = tr.kind, name = tr.name, year = tr.year, culture = tr.culture }
    end
    ctx:honour(c, ctx:fact("trace", { name = tr.name, kind = tr.kind }, c))
  end
  -- the troubles of the present: the land's trouble is the strongest
  d.tensions = require("gen.history.tensions").for_land(planet.data, view.summary.id, ctx.node.seed)
  -- what its people know and talk about (kept with the land for dialogue)
  d.lore = require("gen.dialogue.lore").build(d, cul, planet.data, view.summary)
  -- and what the player can learn here (codex entries)
  d.codex = require("gen.codex").build(d, ctx.node.address, cul, planet, view.summary)
  quests.generate(ctx, d, provisional.style(d.style), cul)
end

-- What a land of the surface grid takes from its region and planet, shaped
-- like a country district: its terrain (with the land's crop of the lattice),
-- the region's rivers and lakes, no roads yet, where it lies on the sphere,
-- and the country the atlas puts there (with its summary, as its continent
-- lists it).
local function grid_view(ctx, d)
  local region = require("gen.levels.region")
  local grid = require("gen.plan.grid")
  local rnode = ctx.parent
  local planet = ctx:ancestor("planet")
  local P = planet.data
  local info = region.info(P)
  local f, gx, gz = grid.land_of(info.g, rnode.index, ctx.node.index)
  local cx, cz = grid.land_centre(info.g, gx, gz)
  d.grid, d.face, d.center, d.region = { gx, gz }, f, { cx, cz }, rnode.address
  d.face_lands = info.g.N * grid.LANDS
  local T = region.land_terrain(P, info, f, rnode.data, gx, gz, region.noise_seed(planet))
  T.palette = { { 70, 98, 50 }, { 100, 116, 70 }, { 128, 126, 98 }, { 150, 150, 140 } }
  T.color_low, T.color_high, T.slope_color, T.slope_start, T.color_noise, T.uv_scale = -20, 120, { 96, 86, 70 }, 0.22,
                                                                                         0.1, 4
  local x, y, z = grid.to_sphere(info.g, f, cx, -cz)
  local view = { data = { terrain = T, roads = {}, rivers = rnode.data.rivers, direction = { x, y, z } },
                 summary = {} }
  -- lakes near the land, in land-local metres
  d.lakes = {}
  for _, lake in ipairs(rnode.data.lakes) do
    local dx, dz = lake.x - cx, lake.z - cz
    local reach = lake.rmax + region.LAKE_BLEND + land.SIZE
    if math.abs(dx) < reach and math.abs(dz) < reach then
      d.lakes[#d.lakes + 1] = { x = dm.round(dx, 2), z = dm.round(dz, 2), radii = util.copy(lake.radii),
                                rmax = lake.rmax, level = lake.level }
    end
  end
  local cid = rnode.data.land_country[ctx.node.index + 1]
  if cid and cid > 0 then
    view.summary = require("gen.levels.geography").country_summary(planet, cid) or {}
    local c = P.countries[cid]
    local cont = c and planet.children[c.continent - 1]
    view.continent = cont and cont.name
  end
  return view
end

function land.register(R)
  R:pass("country", "terrain", { run = function(ctx)
    -- since the surface grid, a country has no district (its lands lie in regions)
    if (ctx.node.version or 1) >= 2 and not prime.inside(ctx.node.address) then return end
    country_terrain(ctx)
  end })

  R:pass("land", "layout", { run = function(ctx)
    local d = ctx.data
    local view
    if ctx.parent.kind == "region" then
      view = grid_view(ctx, d)
      d.size = land.SIZE
      d.terrain = view.data.terrain
    else
      view = { data = ctx.parent.data, summary = ctx.parent.summary }
      local cont = ctx:ancestor("continent")
      view.continent = cont and cont.data.name
      local gx, gz = land.grid(ctx.node.index)
      d.size, d.grid, d.center = land.SIZE, { gx, gz }, { gx * land.SIZE, gz * land.SIZE }
      d.terrain = util.copy(view.data.terrain)
    end
    local country = view.data
    d.features, d.flats, d.roads, d.fields = {}, {}, {}, {}
    d.style = ctx.node.address == prime.FARM and "farm" or (country.style or "countryside")
    clip_roads(ctx, d, country)
    if d.style == "farm" then
      farm(ctx, d, country)
      local sky = require("gen.visuals.sky")
      d.place = { latitude = sky.FARM.latitude, longitude = sky.FARM.longitude }
      d.heavens = sky.heavens(ctx:ancestor("planet").data)
    elseif prime.inside(ctx.node.address) then
      countryside(ctx, d)
    else
      -- a settlement with people and a trouble on dry ground near the middle
      local T = country.terrain
      local cx, cz = d.center[1], d.center[2]
      local biome = place_on_planet(ctx, d, country, view)
      clip_rivers(d, country)
      if biome then d.style = biome.family end
      local height = function(x, z) return land.raw_height(T, x + cx, z + cz) end
      local ax, az = dry_spot(d, height)
      if not ax and d.region then
        -- a land under water (the sea or a lake): no one lives here
        d.wild, d.people = true, {}
        d.name = view.summary.name and ("the waters of " .. view.summary.name) or "open water"
      else
        settle(ctx, d, view, height, ax or 0, az or 0)
      end
      if biome then
        d.biome_trees = biome.trees
        d.texture_override = biome.texture
        require("gen.visuals.palette").terrain(d.terrain, d.materials, biome)
      end
    end
    local ps = provisional.STYLES[d.style]
    d.flora = util.copy(land.STYLES[d.style] or (ps and { trees = ps.trees, tree_count = ps.tree_count, bush_count = 2,
                                                          flower_count = 1, texture = ps.texture }) or land.STYLES.countryside)
    if d.biome_trees then
      d.flora.trees = #d.biome_trees > 0 and util.copy(d.biome_trees) or { "bush" }
      d.flora.tree_count = #d.biome_trees > 0 and d.flora.tree_count or 0
      d.flora.texture = d.texture_override
      d.biome_trees, d.texture_override = nil, nil
    end
    d.texture = d.flora.texture
    d.spots = d.spots or { spawn = { x = 0, z = (road_z_at(d, 0) or 0) + 6, yaw = 0 } }
  end })

  R:describe("land", function(node)
    local d = node.data
    if d.style == "farm" then
      return string.format("The farm: a farmhouse, a barn, a well and %d fields; %s lives next door.", #d.fields,
                           d.neighbour.name)
    end
    if d.quest then
      local where = d.biome and string.format(" in the %s of %s, %s (%.0f °C, %d mm of rain a year%s%s)", d.biome,
                                             d.country, d.continent, d.climate.temperature, d.climate.precipitation,
                                             d.coast and ", on the coast" or "",
                                             #(d.rivers or {}) > 0 and ", by a river" or "") or ""
      local who = d.culture and string.format(" (\"%s\"), a settlement of the %s of %s, followers of %s,",
                                             d.name_meaning, d.culture.species, d.culture.name, d.culture.religion) or
                  string.format(", a %s settlement", d.style)
      local top = d.tensions and d.tensions[1]
      local trouble = top and string.format("%s, because %s%s", top.text, table.concat(top.causes, " and "),
                                            top.text == d.quest.short and "" or (" (" .. d.quest.short .. ")"))
                      or d.quest.short
      local text = string.format("%s%s %d people%s. Trouble: %s.", d.name, who, #d.people, where, trouble)
      local seen = {}
      for _, tr in ipairs(d.traces or {}) do seen[#seen + 1] = tr.name end
      if #seen > 0 then text = text .. " Here lie " .. table.concat(seen, ", ") .. "." end
      if d.wanderer then text = text .. " They tell of the Wanderer, seen " .. math.floor(d.wanderer.years_ago + 0.5) ..
                                       " years ago." end
      return text
    end
    return string.format("Rolling %s, crossed by %s.", d.style, #d.roads > 0 and d.roads[1].name or "no road")
  end)
end

return land
