-- Multiversal Van Life - regions of the surface grid (MIT).
--
-- A region is a 32 km square of the planet-wide grid (gen/plan/grid.lua)
-- holding what its 16 x 16 lands share: the rivers and lakes running
-- through it and which country each land belongs to (borders run along the
-- planet's cell boundaries, so two countries can meet inside a region).
--
-- The ground is one function of the planet's surface, sampled by every
-- land on a lattice of 256 m in face coordinates: the planet's elevation
-- (steepened near sea level, so shores are not endless flat beaches), lake
-- basins and river valleys carved into it, and a roughness that scales the
-- engine's detail noise (rough mountains, smooth plains and river banks).
-- Rivers follow the planet's flow from cell to cell along wandering lines on
-- the sphere, their water only ever running downhill. Because all of it is
-- computed from positions on the sphere, it is continuous across land,
-- region and face borders; the detail noise fades out towards face edges,
-- where two faces' coordinates meet.
local dm = require("gen.dmath")
local grid = require("gen.plan.grid")
local prime = require("gen.prime")

local region = {
  CELL = 256,          -- lattice step (m)
  MARGIN = 3,          -- lattice cells around a land's crop
  PERIOD = 128,        -- detail noise lattice period (cells at the first octave): 65,536 m
  FREQ = 1 / 512,      -- detail noise frequency (the noise wraps every PERIOD / FREQ metres)
  OCTAVES = 5,
  FADE = 2000,         -- detail noise fades out over this distance to a face edge (m)
  RIVER_STEP = 1000,   -- river points every ~1 km
  REACH = 3000,        -- rivers and lakes are kept this far around a region (m)
  LAKE_SHORE = 300,    -- a lake's shore rises from the water over this distance (m)
  LAKE_BLEND = 2300,   -- and blends into the land within this distance of the water (m)
}
region.WRAP = region.PERIOD / region.FREQ

-- Heights near the sea are steepened five-fold (continuously): at walking
-- scale the planet's slope would otherwise make every shore a flat beach.
function region.shape(h)
  local a = math.abs(h)
  local s = a <= 40 and a * 5 or 200 + (a - 40)
  return h < 0 and -s or s
end
local shape = region.shape

local function smooth(t)
  t = dm.clamp(t, 0, 1)
  return t * t * (3 - 2 * t)
end

-- ------------------------------------------------------ planet caches
-- Per planet (its data table): the grid, roughness per cell, cell spacing,
-- river segments and names. Derived from the planet only, so caching them
-- changes nothing.
local cache = setmetatable({}, { __mode = "k" })

function region.info(P)
  local c = cache[P]
  if c then return c end
  local cells = P.cells
  local n = #cells.elevation
  local PL = require("gen.levels.planet")
  local rough = {}
  for i = 1, n do
    local s, e = cells.setting and cells.setting[i], cells.elevation[i]
    rough[i] = (s == PL.SETTING.orogen or s == PL.SETTING["volcanic arc"]) and 70 or
               (e > 1.5 and 40 or (e > 0 and 12 or 6))
  end
  local g = grid.of(P)
  local names = {}
  for _, r in ipairs(P.rivers or {}) do
    for _, rc in ipairs(r.cells) do names[rc] = names[rc] or r.name end
  end
  c = { g = g, rough = rough, spacing = math.sqrt(4 * dm.pi / n) * g.radius, segments = {}, names = names }
  cache[P] = c
  return c
end

-- Where a river's water stands at a cell's centre.
local function vertex_level(cells, i)
  if cells.elevation[i] <= 0 then return 0 end
  if cells.lake[i] then return shape(cells.filled[i] * 1000) end -- meeting the lake's surface
  return shape(cells.filled[i] * 1000) - 3
end

-- The river from cell i to the cell it flows to: points on the sphere
-- { x, y, z, level } wandering from centre to centre, the level running
-- down from cell to cell and never above the ground minus 3 m; it ends at
-- the sea. Cached per planet.
local function segment(P, info, seed, i)
  local seg = info.segments[i]
  if seg ~= nil then return seg or nil end
  local cells = P.cells
  local j = cells.flow_to[i]
  if not cells.river[i] or not j or j <= 0 then
    info.segments[i] = false
    return nil
  end
  local ax, ay, az = mvl.planet_cell(P.grid, i)
  local bx, by, bz = mvl.planet_cell(P.grid, j)
  local d = dm.clamp(ax * bx + ay * by + az * bz, -1, 1)
  local len = dm.atan(math.sqrt(1 - d * d), d) * info.g.radius
  local steps = math.max(2, math.floor(len / region.RIVER_STEP + 0.5))
  -- the side direction (perpendicular to the river on the sphere)
  local lx, ly, lz = ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
  local ll = math.sqrt(lx * lx + ly * ly + lz * lz)
  if ll < 1e-12 then ll, lx, ly, lz = 1, 0, 0, 0 end
  lx, ly, lz = lx / ll, ly / ll, lz / ll
  local amp = math.min(0.08 * len, 3000) / info.g.radius
  local wander = mvl.hash(seed, "river", i) % 100000
  local lj = vertex_level(cells, j)
  local running = math.max(vertex_level(cells, i), lj)
  local pts = {}
  for k = 0, steps do
    local u = k / steps
    local off = amp * dm.sin(dm.pi * u) * mvl.noise(u * 3, 0.5, wander, 2)
    local x, y, z = ax + (bx - ax) * u + lx * off, ay + (by - ay) * u + ly * off, az + (bz - az) * u + lz * off
    local l = math.sqrt(x * x + y * y + z * z)
    x, y, z = x / l, y / l, z / l
    local ground = shape(mvl.planet_sample(P.grid, cells.elevation, x, y, z) * 1000)
    running = math.min(running, ground - 3)
    local level = k == steps and lj or math.max(lj, running)
    pts[#pts + 1] = { x, y, z, dm.round(level, 2) }
    if ground < -1 then break end -- the river has reached the sea
  end
  seg = { from = i, to = j, width = dm.round(dm.clamp(cells.flow[i] * 1.5, 10, 40), 1),
          name = info.names[i] or info.names[j] or "the river", points = pts }
  info.segments[i] = seg
  return seg
end

-- The cells around a direction (the nearest and `rings` rings of neighbours).
local function cells_around(P, x, y, z, rings)
  local first = mvl.planet_nearest(P.grid, x, y, z)
  local seen, list, frontier = { [first] = true }, { first }, { first }
  for _ = 1, rings do
    local nxt = {}
    for _, c in ipairs(frontier) do
      for _, nb in ipairs(mvl.planet_neighbours(P.grid, c)) do
        if not seen[nb] then
          seen[nb] = true
          list[#list + 1] = nb
          nxt[#nxt + 1] = nb
        end
      end
    end
    frontier = nxt
  end
  table.sort(list)
  return list
end

-- A lake of lake cell i seen on face f: its centre in face world
-- coordinates, its level, and its shoreline as RAYS radii (where the
-- planet's ground first rises to the level, going out from the centre along
-- rays in face coordinates; capped where the water would spill). Cached.
region.RAYS = 16
local function lake_shape(P, info, f, i)
  info.lakes = info.lakes or {}
  local key = f .. ":" .. i
  if info.lakes[key] ~= nil then return info.lakes[key] or nil end
  local g = info.g
  local px, py, pz = mvl.planet_cell(P.grid, i)
  local F = grid.FACES[f]
  if F.n[1] * px + F.n[2] * py + F.n[3] * pz < 0.1 then
    info.lakes[key] = false
    return nil
  end
  local s, t = grid.to_face(g, f, px, py, pz)
  local cx, cz = s, -t
  local level = shape(P.cells.filled[i] * 1000)
  local function ground(x, z)
    local sx, sy, sz = grid.to_sphere(g, f, x, -z)
    return shape(mvl.planet_sample(P.grid, P.cells.elevation, sx, sy, sz) * 1000)
  end
  local radii, rmax = {}, 0
  local limit, step = info.spacing, info.spacing / 160
  for k = 0, region.RAYS - 1 do
    local a = -dm.pi + (k + 0.5) * 2 * dm.pi / region.RAYS
    local ux, uz = dm.cos(a), dm.sin(a)
    local r = limit
    local prev = 0
    for d = step, limit, step do
      if ground(cx + ux * d, cz + uz * d) >= level then
        -- refine between the last two steps
        local lo, hi = prev, d
        for _ = 1, 12 do
          local mid = (lo + hi) / 2
          if ground(cx + ux * mid, cz + uz * mid) >= level then hi = mid else lo = mid end
        end
        r = hi
        break
      end
      prev = d
    end
    radii[k + 1] = dm.round(math.max(r, 200), 1)
    rmax = math.max(rmax, radii[k + 1])
  end
  local lake = { cell = i, x = dm.round(cx, 2), z = dm.round(cz, 2), level = dm.round(level, 2), radii = radii,
                 rmax = rmax }
  info.lakes[key] = lake
  return lake
end

-- The shoreline radius of a lake towards (x, z), and the distance of (x, z)
-- from its centre.
function region.lake_radius(lake, x, z)
  local dx, dz = x - lake.x, z - lake.z
  local n = #lake.radii
  local u = (dm.atan(dz, dx) + dm.pi) / (2 * dm.pi) * n - 0.5
  local i = math.floor(u)
  local t = u - i
  local r0, r1 = lake.radii[i % n + 1], lake.radii[(i + 1) % n + 1]
  return r0 + (r1 - r0) * t, math.sqrt(dx * dx + dz * dz)
end

-- Is (x, z) on a lake (within `margin` metres beyond its shoreline)? Its
-- level, or nil.
function region.lake_at(lakes, x, z, margin)
  for _, lake in ipairs(lakes or {}) do
    local dx, dz = x - lake.x, z - lake.z
    if math.abs(dx) < lake.rmax + margin and math.abs(dz) < lake.rmax + margin then
      local r, d = region.lake_radius(lake, x, z)
      if d < r + margin then return lake.level, lake end
    end
  end
end

-- ----------------------------------------------------------- the plan
-- Bounds of a region in face world coordinates.
function region.bounds(g, row, col)
  local x0, z0 = -g.H + col * grid.REGION, -g.H + row * grid.REGION
  return x0, z0, x0 + grid.REGION, z0 + grid.REGION
end

-- Projects a point on the sphere to face world coordinates (nil when the
-- point is far round the planet from the face).
local function project(g, f, x, y, z)
  local F = grid.FACES[f]
  if F.n[1] * x + F.n[2] * y + F.n[3] * z < 0.1 then return nil end
  local s, t = grid.to_face(g, f, x, y, z)
  return s, -t
end

local function plan(ctx)
  local planet = ctx.parent
  local P = planet.data
  local d = ctx.data
  local info = region.info(P)
  local g = info.g
  local f, row, col = grid.region(g, ctx.node.index)
  d.face, d.row, d.col, d.N = f, row, col, g.N
  local x0, z0, x1, z1 = region.bounds(g, row, col)
  local cx, cy, cz = grid.to_sphere(g, f, (x0 + x1) / 2, -(z0 + z1) / 2)
  local lat, lon = grid.latlon(cx, cy, cz)
  d.centre = { latitude = dm.round(lat, 3), longitude = dm.round(lon, 3) }
  local cells = P.cells
  local rings = info.spacing > 60000 and 2 or 3
  local near = cells_around(P, cx, cy, cz, rings)
  local m = region.REACH
  local function inside(x, z, extra)
    local e = m + (extra or 0)
    return x >= x0 - e and x <= x1 + e and z >= z0 - e and z <= z1 + e
  end
  -- lakes: basins around the planet's lake cells
  d.lakes = {}
  for _, i in ipairs(near) do
    if cells.lake[i] and cells.elevation[i] > 0 then
      local lake = lake_shape(P, info, f, i)
      if lake and inside(lake.x, lake.z, lake.rmax + region.LAKE_BLEND) then d.lakes[#d.lakes + 1] = lake end
    end
  end
  -- rivers: the planet's flow through and around the region
  d.rivers = {}
  for _, i in ipairs(near) do
    local seg = segment(P, info, planet.seed, i)
    if seg then
      -- the river's points on this face, broken where it runs into a lake
      local pts = {}
      for k, p in ipairs(seg.points) do
        local x, z = project(g, f, p[1], p[2], p[3])
        local pt = x and { dm.round(x, 2), dm.round(z, 2), p[4] } or false
        if pt and region.lake_at(d.lakes, pt[1], pt[2], 0) then pt = false end
        pts[k] = pt
      end
      -- the pieces near the region, one point beyond on each side
      local run = {}
      local function flush()
        if #run >= 2 then d.rivers[#d.rivers + 1] = { name = seg.name, width = seg.width, from = seg.from, points = run } end
        run = {}
      end
      local function near_pt(p) return p and inside(p[1], p[2]) end
      for k = 1, #pts do
        local p = pts[k]
        if p and (near_pt(p) or near_pt(pts[k - 1]) or near_pt(pts[k + 1])) then run[#run + 1] = p else flush() end
      end
      flush()
    end
  end
  -- which country each land belongs to (0: none, the sea)
  local owner, seen = {}, {}
  d.countries = {}
  for L = 0, grid.LANDS * grid.LANDS - 1 do
    local gx, gz = col * grid.LANDS + L % grid.LANDS, row * grid.LANDS + L // grid.LANDS
    local x, y, z = grid.land_direction(g, f, gx, gz)
    local cell = mvl.planet_nearest(P.grid, x, y, z)
    local cid = (cells.country and cells.elevation[cell] > 0 and cells.country[cell]) or 0
    owner[L + 1] = cid
    if cid > 0 and not seen[cid] then
      seen[cid] = true
      d.countries[#d.countries + 1] = cid
    end
    if L % 64 == 63 then ctx:yield() end
  end
  table.sort(d.countries)
  d.land_country = owner
end

-- --------------------------------------------------------- the ground
local function river_pull(rivers, x, z)
  local best, level, width = math.huge, 0, 0
  for _, r in ipairs(rivers) do
    local pts = r.points
    for i = 1, #pts - 1 do
      local a, b = pts[i], pts[i + 1]
      local sx, sz = b[1] - a[1], b[2] - a[2]
      local len2 = sx * sx + sz * sz
      local t = len2 > 0 and dm.clamp(((x - a[1]) * sx + (z - a[2]) * sz) / len2, 0, 1) or 0
      local dx, dz = x - (a[1] + sx * t), z - (a[2] + sz * t)
      local dd = dx * dx + dz * dz
      if dd < best then best, level, width = dd, a[3] + (b[3] - a[3]) * t, r.width end
    end
  end
  return math.sqrt(best), level, width
end

-- Height (m) and detail roughness of face world position (x, z) of face f.
function region.sample(P, info, f, x, z, rivers, lakes)
  local g = info.g
  local sx, sy, sz = grid.to_sphere(g, f, x, -z)
  local h = shape(mvl.planet_sample(P.grid, P.cells.elevation, sx, sy, sz) * 1000)
  local k = math.max(0, mvl.planet_sample(P.grid, info.rough, sx, sy, sz))
  for _, lake in ipairs(lakes) do
    local dx, dz = x - lake.x, z - lake.z
    local reach = lake.rmax + region.LAKE_BLEND
    if math.abs(dx) < reach and math.abs(dz) < reach then
      local r, d = region.lake_radius(lake, x, z)
      if d < r then
        -- under the water: a bowl deepening towards the middle
        local floor = lake.level - 3
        h = floor + (math.min(h, floor) - floor) * smooth((r - d) / region.LAKE_SHORE) - math.min(30, (r - d) * 0.002)
        k = 0
      elseif d < r + region.LAKE_BLEND then
        -- the shore rises from the water, then the land takes over (low
        -- ground near the lake is raised: the water stays in its basin)
        local s = smooth((d - r) / region.LAKE_SHORE)
        local shore = lake.level - 3 + 9 * s
        local target = shore + math.max(0, h - shore) * s
        local w = 1 - smooth((d - r - region.LAKE_SHORE) / (region.LAKE_BLEND - region.LAKE_SHORE))
        h = h + (target - h) * w
        k = k * (1 - w)
      end
    end
  end
  if #rivers > 0 then
    local d, level, width = river_pull(rivers, x, z)
    local w = 1 - smooth((d - width / 2 - 40) / 500)
    if w > 0 then
      h = h + (level + 1 - h) * w
      k = k * (1 - w)
    end
  end
  k = k * smooth(grid.edge_distance(g, x, z) / region.FADE)
  return h, k
end

-- The terrain of a land: the detail noise (periodic, so world coordinates
-- can be wrapped) and the land's crop of the region lattice with heights
-- and roughness, `margin` cells beyond its square on every side.
function region.land_terrain(P, info, f, rd, gx, gz, seed)
  local g, C = info.g, region.CELL
  local cx, cz = grid.land_centre(g, gx, gz)
  local half = grid.LAND / 2
  local i0 = math.floor((cx - half + g.H) / C) - region.MARGIN
  local j0 = math.floor((cz - half + g.H) / C) - region.MARGIN
  local w = grid.LAND // C + 1 + 2 * region.MARGIN
  -- only what is near the land matters for its lattice
  local x0, z0 = -g.H + i0 * C, -g.H + j0 * C
  local x1, z1 = x0 + (w - 1) * C, z0 + (w - 1) * C
  local rivers = {}
  for _, r in ipairs(rd.rivers) do
    local near = false
    for _, p in ipairs(r.points) do
      if p[1] > x0 - 1600 and p[1] < x1 + 1600 and p[2] > z0 - 1600 and p[2] < z1 + 1600 then near = true break end
    end
    if near then rivers[#rivers + 1] = r end
  end
  local data, amp = {}, {}
  for j = 0, w - 1 do
    for i = 0, w - 1 do
      local h, k = region.sample(P, info, f, x0 + i * C, z0 + j * C, rivers, rd.lakes)
      data[j * w + i + 1] = dm.round(h, 2)
      amp[j * w + i + 1] = dm.round(k, 3)
    end
  end
  return {
    seed = seed, base = 0, amp = 1, freq = region.FREQ, octaves = region.OCTAVES, lacunarity = 2, gain = 0.5,
    period = region.PERIOD, wrap = region.WRAP,
    map = { w = w, h = w, x0 = x0, z0 = z0, cell = C, data = data, amp = amp },
  }
end

-- The planet's terrain noise seed (one for the whole surface).
function region.noise_seed(planet) return mvl.hash(planet.seed, "surface") % 1000000 end

-- ------------------------------------------- places from the planet
-- Is the land around a direction dry ground, judging from the planet alone
-- (its elevation and lakes)? Used before regions exist (commitments are made
-- while the planet is generated) and to pick lands for signals.
function region.dry(P, info, x, y, z)
  if shape(mvl.planet_sample(P.grid, P.cells.elevation, x, y, z) * 1000) <= 6 then return false end
  local cell = mvl.planet_nearest(P.grid, x, y, z)
  local list = { cell }
  for _, nb in ipairs(mvl.planet_neighbours(P.grid, cell)) do list[#list + 1] = nb end
  local f = grid.face_of(x, y, z)
  local s, t = grid.to_face(info.g, f, x, y, z)
  for _, c in ipairs(list) do
    local lake = P.cells.lake[c] and P.cells.elevation[c] > 0 and lake_shape(P, info, f, c)
    if lake and region.lake_at({ lake }, s, -t, 2500) then return false end
  end
  return true
end

-- The country a land's centre lies in (0: none), as its region records it.
function region.land_country(P, info, f, gx, gz)
  local x, y, z = grid.land_direction(info.g, f, gx, gz)
  local cell = mvl.planet_nearest(P.grid, x, y, z)
  return (P.cells.country and P.cells.elevation[cell] > 0 and P.cells.country[cell]) or 0, x, y, z
end

-- The addresses of up to n dry lands of country `id` around a direction,
-- nearest first (searching outwards ring by ring, at most `rings` rings).
function region.lands_near(planet_addr, P, id, x, y, z, n, rings)
  local info = region.info(P)
  local g = info.g
  local loc = grid.locate(planet_addr, g, x, y, z)
  local out = {}
  for ring = 0, rings or 12 do
    for dz = -ring, ring do
      for dx = -ring, ring do
        if math.max(math.abs(dx), math.abs(dz)) == ring then
          local gx, gz = loc.gx + dx, loc.gz + dz
          if grid.on_face(g, gx, gz) then
            local cid, lx, ly, lz = region.land_country(P, info, loc.face, gx, gz)
            if cid == id and region.dry(P, info, lx, ly, lz) then
              out[#out + 1] = grid.address(planet_addr, g, loc.face, gx, gz)
              if #out >= n then return out end
            end
          end
        end
      end
    end
  end
  return out
end

-- The k-th of them, or nil.
function region.land_near(planet_addr, P, id, x, y, z, k, rings)
  return region.lands_near(planet_addr, P, id, x, y, z, k or 1, rings)[k or 1]
end

-- Land numbers of the country districts of multiverses from before the
-- grid, for what the planet promises a country there, and on the grid the
-- k-th dry land near the capital for each kind of promise.
region.PROMISED = { shrine = { 115, 4 }, echo = { 116, 5 }, history = { 117, 3 }, resident = { 118, 2 },
                    monument = { 119, 1 } }

-- The land where the planet node `planet` promises country `id` something
-- of kind `what` (a key of PROMISED), or nil.
function region.promised_land(planet, id, what)
  local P = planet.data
  local c = P.countries and P.countries[id]
  if not c then return nil end
  local w = region.PROMISED[what]
  if (planet.version or 1) < 2 then
    return planet.address .. ".k" .. (c.continent - 1) .. ".n" .. c.index .. ".l" .. w[1]
  end
  return region.country_land(planet.address, P, id, w[2])
end

-- The first n dry lands of country `id` around its capital.
function region.country_lands(planet_addr, P, id, n)
  local c = P.countries and P.countries[id]
  if not c then return {} end
  local x, y, z = mvl.planet_cell(P.grid, c.capital)
  return region.lands_near(planet_addr, P, id, x, y, z, n)
end

-- The k-th of them, or nil.
function region.country_land(planet_addr, P, id, k)
  return region.country_lands(planet_addr, P, id, k)[k]
end

-- The country id of the land at `addr` (0 where none), from its region or
-- its country.
function region.country_id(G, addr)
  local address = require("gen.address")
  local parent = G:generate(address.parent(addr))
  if parent.kind == "region" then return parent.data.land_country[address.index(addr) + 1] or 0 end
  return parent.summary.id or 0
end

function region.describe(node)
  local d = node.data
  if not d.face then return "A region" end
  local parts = { string.format("A 32 km region on face %d (row %d, column %d of %d), around %.1f°, %.1f°", d.face,
                                d.row, d.col, d.N, d.centre.latitude, d.centre.longitude) }
  if #d.countries == 0 then parts[#parts + 1] = "open sea or no man's land"
  else parts[#parts + 1] = string.format("%d countr%s", #d.countries, #d.countries == 1 and "y" or "ies") end
  local names = {}
  for _, r in ipairs(d.rivers) do
    if not names[r.name] then
      names[r.name] = true
      names[#names + 1] = r.name
    end
  end
  if #names > 0 then parts[#parts + 1] = "rivers: " .. table.concat(names, ", ") end
  if #d.lakes > 0 then parts[#parts + 1] = #d.lakes .. " lake" .. (#d.lakes == 1 and "" or "s") end
  return table.concat(parts, "; ") .. "."
end

function region.register(R)
  R:skeleton("region", function(parent, index)
    if prime.inside(parent.address) or not (parent.data.cells and parent.data.cells.filled) then return nil end
    local g = region.info(parent.data).g
    if index >= g.regions then return nil end
    local f, row, col = grid.region(g, index)
    return { face = f, row = row, col = col }
  end)
  R:pass("region", "plan", { run = plan })
  R:describe("region", region.describe)
end

return region
