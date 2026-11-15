-- Multiversal Van Life - the garden behind the van's conservatory at run
-- time (MIT License).
--
-- Configures the garden's terrain slot, builds the back of the house that
-- stands in it, and streams the garden in 32 m chunks (gen/house/garden.lua)
-- around a point: the player while they are in the garden, the garden door
-- while they are in the conservatory (the door shows the garden). Its
-- pieces (trees, fruit trees, bushes, hedges, flower beds, benches, lamp
-- posts, a bird bath, beehives, gazebos) are voxel models built once and
-- shared.
local G = require("gen.house.garden")

local garden = { G = G, seed = nil, loaded = {}, count = 0, meshes = {}, house = nil, LOAD = 3, UNLOAD = 4,
                 NEAR = 2, stats = { built = 0, max = 0 } }

local function key(a, b) return a .. "," .. b end

function garden.height(x, z) return mvl.height(x, z, G.SLOT) end

-- ------------------------------------------------------------- pieces
local PIECES = {}
local function colors(g, list) for i, c in ipairs(list) do g:color(i, c[1], c[2], c[3]) end end

PIECES.tree = { size = 0.25, radius = 0.45, build = function()
  local g = mvl.voxels(20, 20, 24)
  colors(g, { { 100, 70, 46 }, { 60, 118, 54 }, { 76, 140, 62 }, { 48, 98, 46 } })
  g:cylinder(10, 10, 0, 10, 1.3, 1)
  g:ellipsoid(10, 10, 15, 8, 8, 7, 2)
  g:ellipsoid(8, 11, 18, 5, 5, 4, 3)
  g:ellipsoid(12, 8, 13, 5, 5, 4, 4)
  return g
end }
PIECES.fruit_tree = { size = 0.25, radius = 0.35, build = function()
  local g = mvl.voxels(16, 16, 18)
  colors(g, { { 110, 76, 50 }, { 80, 140, 60 }, { 96, 156, 70 }, { 220, 60, 50 }, { 240, 160, 50 } })
  g:cylinder(8, 8, 0, 7, 1.0, 1)
  g:ellipsoid(8, 8, 11, 6.5, 6.5, 5, 2)
  g:ellipsoid(7, 9, 13, 4, 4, 3, 3)
  local rng = mvl.rng(7)
  for _ = 1, 26 do
    local a, r = rng:next() * 6.283, 5 + rng:next() * 1.5
    g:set(math.floor(8 + math.cos(a) * r), math.floor(8 + math.sin(a) * r), rng:int(8, 14), rng:next() < 0.6 and 4 or 5)
  end
  return g
end }
PIECES.bush = { size = 0.25, radius = 0.5, build = function()
  local g = mvl.voxels(9, 9, 6)
  colors(g, { { 64, 124, 56 }, { 84, 146, 66 }, { 230, 120, 150 } })
  g:ellipsoid(4.5, 4.5, 2.5, 4, 4, 3, 1)
  g:ellipsoid(4, 5, 3.5, 3, 3, 2, 2)
  g:set(2, 6, 4, 3)
  g:set(6, 3, 3, 3)
  return g
end }
PIECES.hedge = { size = 0.25, box = { 4, 1 }, build = function()
  local g = mvl.voxels(16, 4, 6)
  colors(g, { { 52, 104, 48 }, { 66, 122, 56 } })
  g:box(0, 0, 0, 15, 3, 5, 1)
  for x = 0, 15, 3 do g:box(x, 0, 5, x, 3, 5, 2) end
  return g
end }
PIECES.flower_bed = { size = 0.25, box = { 4, 2.5 }, build = function()
  local g = mvl.voxels(16, 10, 2)
  colors(g, { { 150, 140, 128 }, { 86, 62, 44 }, { 230, 90, 120 }, { 250, 210, 80 }, { 160, 120, 220 }, { 70, 130, 60 } })
  g:box(0, 0, 0, 15, 9, 0, 1)
  g:box(1, 1, 0, 14, 8, 0, 2)
  local rng = mvl.rng(11)
  for x = 1, 14 do
    for y = 1, 8 do
      local r = rng:next()
      g:set(x, y, 1, r < 0.25 and 3 or (r < 0.45 and 4 or (r < 0.6 and 5 or 6)))
    end
  end
  return g
end }
PIECES.bench = { size = 0.25, box = { 2, 0.75 }, build = function()
  local g = mvl.voxels(8, 3, 4)
  colors(g, { { 140, 96, 60 }, { 50, 48, 50 } })
  g:box(0, 0, 1, 7, 2, 1, 1)
  g:box(0, 2, 2, 7, 2, 3, 1)
  g:box(0, 0, 0, 0, 2, 0, 2)
  g:box(7, 0, 0, 7, 2, 0, 2)
  return g
end }
PIECES.lamp_post = { size = 0.25, radius = 0.2, build = function()
  local g = mvl.voxels(3, 3, 14)
  colors(g, { { 40, 40, 44 }, { 255, 220, 150 } })
  g:box(1, 1, 0, 1, 1, 11, 1)
  g:box(0, 0, 11, 2, 2, 11, 1)
  g:box(0, 0, 12, 2, 2, 12, 2)
  g:box(1, 1, 13, 1, 1, 13, 1)
  return g
end }
PIECES.bird_bath = { size = 0.25, radius = 0.6, build = function()
  local g = mvl.voxels(6, 6, 5)
  colors(g, { { 176, 170, 160 }, { 120, 180, 210 } })
  g:cylinder(3, 3, 0, 3, 0.8, 1)
  g:cylinder(3, 3, 3, 4, 2.6, 1)
  g:cylinder(3, 3, 4, 4, 1.8, 2)
  return g
end }
PIECES.beehive = { size = 0.25, box = { 1, 1 }, build = function()
  local g = mvl.voxels(4, 4, 6)
  colors(g, { { 240, 236, 220 }, { 230, 190, 70 }, { 120, 90, 60 } })
  g:box(0, 0, 0, 3, 3, 1, 1)
  g:box(0, 0, 2, 3, 3, 2, 2)
  g:box(0, 0, 3, 3, 3, 4, 1)
  g:box(0, 0, 5, 3, 3, 5, 3)
  return g
end }
PIECES.gazebo = { size = 0.25, build = function()
  local g = mvl.voxels(28, 28, 22)
  colors(g, { { 236, 232, 222 }, { 150, 70, 60 }, { 150, 110, 70 } })
  g:cylinder(14, 14, 0, 0, 13, 3)
  for k = 0, 7 do
    local a = k * math.pi / 4
    g:box(math.floor(14 + math.cos(a) * 12), math.floor(14 + math.sin(a) * 12), 1,
          math.floor(14 + math.cos(a) * 12), math.floor(14 + math.sin(a) * 12), 12, 1)
  end
  for z = 13, 21 do g:cylinder(14, 14, z, z, 14 * (21 - z) / 8 + 0.5, 2) end
  return g
end }

local function piece_mesh(name)
  local m = garden.meshes[name]
  if m then return m end
  local def = PIECES[name]
  local g = def.build()
  m = g:mesh(def.size)
  g:free()
  garden.meshes[name] = m
  return m
end

-- ------------------------------------------------- the back of the house
-- A long cottage front with two storeys of lit windows, a red roof, two
-- chimneys, ivy and the door (a recess, through which the conservatory is
-- seen) facing -X at G.DOOR.
local function build_house()
  local H = G.HOUSE
  local W, D, T = math.floor((H.x1 - H.x0) / 0.25), math.floor((H.z1 - H.z0) / 0.25), 46
  local g = mvl.voxels(W, D, T)
  colors(g, { { 222, 206, 172 }, { 196, 180, 146 }, { 150, 66, 54 }, { 120, 52, 44 }, { 255, 222, 150 },
              { 236, 232, 222 }, { 70, 120, 60 }, { 110, 76, 50 }, { 160, 150, 140 } })
  g:box(0, 0, 0, W - 1, D - 1, 27, 1)
  for z = 0, 27, 4 do g:box(0, 0, z, 0, D - 1, z, 2) end
  -- the roof: a gable along the front
  for k = 0, 17 do
    g:box(k - 1 >= 0 and k - 1 or 0, 0, 28 + k, W - k, D - 1, 28 + k, k % 2 == 0 and 3 or 4)
  end
  g:box(0, 0, 28, 0, D - 1, 28, 4)
  -- chimneys
  for _, y in ipairs({ 22, D - 23 }) do g:box(W - 12, y, 28, W - 9, y + 3, T - 1, 9) end
  -- windows on the front (grid Y runs along -Z; the front is x = 0)
  local mid = math.floor(D / 2)
  for y = 8, D - 9, 12 do
    if math.abs(y + 2 - mid) > 8 then
      for _, z0 in ipairs({ 3, 16 }) do
        g:box(0, y, z0, 0, y + 4, z0 + 6, 6)
        g:box(0, y + 1, z0 + 1, 0, y + 3, z0 + 5, 5)
        g:box(0, y + 2, z0 + 1, 0, y + 2, z0 + 5, 6)
      end
    else
      g:box(0, y, 16, 0, y + 4, 22, 6)
      g:box(0, y + 1, 17, 0, y + 3, 21, 5)
    end
  end
  -- the door: a recess 0.5 m deep with a white frame
  local d0, d1 = mid - 4, mid + 3
  g:box(0, d0 - 1, 0, 0, d1 + 1, 11, 6)
  g:box(0, d0, 0, 1, d1, 10, 0)
  g:box(2, d0, 0, 2, d1, 10, 8)
  -- ivy
  local rng = mvl.rng(5)
  for _ = 1, 120 do
    local y, z = rng:int(0, D - 1), rng:int(0, 26)
    if math.abs(y - mid) > 7 and g:get(0, y, z) == 1 then g:set(0, y, z, 7) end
  end
  local mesh = g:mesh(0.25)
  g:free()
  local P = { (H.x0 + H.x1) / 2, G.Y, (H.z0 + H.z1) / 2 }
  local e = mvl.spawn({ mesh = mesh, pos = P, persistent = true })
  -- solid, but for the door's recess
  local cols = {
    mvl.spawn({ pos = { (H.x0 + H.x1) / 2, G.Y, (H.z0 - 1.0) / 2 }, box = { H.x1 - H.x0, -1.0 - H.z0 }, solid = true,
                visible = false, persistent = true, height = 10 }),
    mvl.spawn({ pos = { (H.x0 + H.x1) / 2, G.Y, (H.z1 + 1.0) / 2 }, box = { H.x1 - H.x0, H.z1 - 1.0 }, solid = true,
                visible = false, persistent = true, height = 10 }),
    mvl.spawn({ pos = { (0.5 + H.x1) / 2, G.Y, 0 }, box = { H.x1 - 0.5, 2.0 }, solid = true, visible = false,
                persistent = true, height = 10 }),
  }
  return { entity = e, mesh = mesh, colliders = cols }
end

-- Sets up the garden of a game (its terrain and the back of the house).
function garden.setup(seed)
  if garden.seed == seed then return end
  garden.clear()
  garden.seed = seed
  mvl.terrain(G.terrain(seed))
  if not garden.house then garden.house = build_house() end
end

-- ------------------------------------------------------------ streaming
local water_mesh
function garden.build(cx, cz)
  local size = G.CHUNK
  local x0, z0 = cx * size, cz * size
  local c = { cx = cx, cz = cz, entities = {}, meshes = {} }
  local mesh = mvl.terrain_chunk(cx, cz, size, G.CELLS, G.SLOT)
  c.meshes[1] = mesh
  c.entities[#c.entities + 1] = mvl.spawn({ mesh = mesh, texture = mvl.texture("textures/grass.tga"), pos = { x0, 0, z0 },
                                            persistent = true })
  -- ponds
  local _, ylo = mvl.mesh_bounds(mesh)
  if ylo and ylo < G.WATER then
    if not water_mesh then water_mesh = mvl.plane_mesh(size, size, size / 8, size / 8, 4) end
    c.entities[#c.entities + 1] = mvl.spawn({ mesh = water_mesh, texture = mvl.texture("textures/water.tga"),
                                              pos = { x0 + size / 2, G.WATER, z0 + size / 2 }, uv_scroll = { 0.01, 0.006 },
                                              color = { 0.55, 0.78, 0.86, 1 }, persistent = true })
  end
  -- the path: gravel draped every 4 m
  if x0 < 0 then
    local pts, mx = {}, x0 + size / 2
    local mz = G.path_z(mx)
    if mz > z0 - 4 and mz < z0 + size + 4 then
      for k = 0, 8 do
        local x = x0 + k * 4
        local z = G.path_z(x)
        pts[#pts + 1] = x - mx
        pts[#pts + 1] = garden.height(x, z) + 0.05
        pts[#pts + 1] = z - mz
      end
      local m = mvl.ribbon_mesh(pts, 2.4, 4)
      c.meshes[#c.meshes + 1] = m
      c.entities[#c.entities + 1] = mvl.spawn({ mesh = m, texture = mvl.texture("textures/dirt.tga"), pos = { mx, 0, mz },
                                                decal = true, persistent = true })
    end
  end
  -- the garden's things
  for _, o in ipairs((G.chunk(garden.seed, cx, cz))) do
    local h = garden.height(o.x, o.z)
    if h > G.WATER + 0.3 then
      if o.piece then
        local def = PIECES[o.piece]
        local s = o.scale or 1
        c.entities[#c.entities + 1] = mvl.spawn({ mesh = piece_mesh(o.piece), pos = { o.x, h - 0.05, o.z }, yaw = o.yaw or 0,
                                                  scale = { s, s, s }, solid = def.radius ~= nil or def.box ~= nil,
                                                  radius = def.radius and def.radius * s, box = def.box, persistent = true })
      else
        c.entities[#c.entities + 1] = mvl.spawn({ kind = "sprite", texture = mvl.texture("textures/" .. o.sprite .. ".tga"),
                                                  pos = { o.x, h, o.z }, scale = { o.w, o.h, 1 }, persistent = true })
      end
    end
  end
  garden.loaded[key(cx, cz)] = c
  garden.count = garden.count + 1
  garden.stats.built = garden.stats.built + 1
  garden.stats.max = math.max(garden.stats.max, garden.count)
  return c
end

function garden.unload(k)
  local c = garden.loaded[k]
  for _, e in ipairs(c.entities) do mvl.destroy(e) end
  for _, m in ipairs(c.meshes) do mvl.release_mesh(m) end
  garden.loaded[k] = nil
  garden.count = garden.count - 1
end

-- Streams the garden around (x, z): chunks within `load` (default LOAD) are
-- built, nearest first, at most `budget` per call; those beyond UNLOAD go.
function garden.update(x, z, load, budget)
  local size = G.CHUNK
  local pcx, pcz = math.floor(x / size), math.floor(z / size)
  load = load or garden.LOAD
  local far = {}
  for k, c in pairs(garden.loaded) do
    if math.max(math.abs(c.cx - pcx), math.abs(c.cz - pcz)) > math.max(load + 1, load == garden.LOAD and garden.UNLOAD or 0) then
      far[#far + 1] = k
    end
  end
  for _, k in ipairs(far) do garden.unload(k) end
  local built, limit = 0, budget or 1
  for r = 0, load do
    for dz = -r, r do
      for dx = -r, r do
        if math.max(math.abs(dx), math.abs(dz)) == r and not garden.loaded[key(pcx + dx, pcz + dz)] then
          garden.build(pcx + dx, pcz + dz)
          built = built + 1
          if built >= limit then return built end
        end
      end
    end
  end
  return built
end

-- Unloads every chunk (the player is far from the garden).
function garden.clear()
  local ks = {}
  for k in pairs(garden.loaded) do ks[#ks + 1] = k end
  for _, k in ipairs(ks) do garden.unload(k) end
end

-- Entities of the garden (chunks and the back of the house).
function garden.entity_count()
  local n = garden.house and (1 + #garden.house.colliders) or 0
  for _, c in pairs(garden.loaded) do n = n + #c.entities end
  return n
end

return garden
