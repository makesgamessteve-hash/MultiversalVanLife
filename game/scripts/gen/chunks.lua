-- Multiversal Van Life - streaming lands in chunks around the player (MIT).
--
-- World coordinates are metres around the centre of the land the world was
-- loaded for (the anchor); neighbouring lands of the same country lie at
-- multiples of 2048 m. Chunks are 32 m squares: those within LOAD chunks of
-- the player are built (nearest first, PER_TICK per update), those beyond
-- UNLOAD are destroyed and their meshes released. A chunk's content (terrain,
-- the land's features, fields and road pieces inside it, flora) depends only
-- on the land and the chunk, so a discarded chunk comes back identical.
local landgen = require("gen.levels.land")
local changes = require("memory.changes")
local PAL = require("gen.visuals.palette")

local chunks = { SIZE = 32, CELLS = 16, LOAD = 3, UNLOAD = 5, PER_TICK = 1 }
local S = {}
S.__index = S

local function key(a, b) return a .. "," .. b end

-- anchor: a land node. provider(gx, gz): the land node at a grid position
-- of the same country (generating it lazily), or nil where there is none.
function chunks.new(anchor, provider)
  local self = setmetatable({
    anchor = anchor, provider = provider, lands = {}, land_list = {}, loaded = {}, count = 0,
    spawned = {},     -- feature id -> entity, for features in built chunks
    hook = nil,       -- function(feature, land) -> false (skip), a replacement feature, or nil
    remember = true,  -- apply each land's change log (memory/changes.lua)
    stats = { built = 0, unloaded = 0, max_loaded = 0, lands = 0 },
    agx = anchor.data.grid[1], agz = anchor.data.grid[2],
  }, S)
  self:activate(anchor, anchor.data.grid[1], anchor.data.grid[2])
  return self
end

-- World offset of a land at grid (gx, gz).
function S:offset(gx, gz) return (gx - self.agx) * landgen.SIZE, (gz - self.agz) * landgen.SIZE end

function S:activate(node, gx, gz)
  local ox, oz = self:offset(gx, gz)
  local rec = { node = node, gx = gx, gz = gz, ox = ox, oz = oz }
  if self.remember then rec.memory = changes.open(node.address) end
  self.lands[key(gx, gz)] = rec
  self.land_list[#self.land_list + 1] = rec
  self.stats.lands = self.stats.lands + 1
  self:apply_terrain()
  return rec
end

-- One continuous height field for the country, plus every active land's
-- flat areas in world coordinates.
function S:apply_terrain()
  local cfg = {}
  for k, v in pairs(self.anchor.data.terrain) do cfg[k] = v end
  cfg.origin_x, cfg.origin_z = self.anchor.data.center[1], self.anchor.data.center[2]
  cfg.flats = {}
  for _, rec in ipairs(self.land_list) do
    for _, f in ipairs(rec.node.data.flats) do
      local g = { radius = f.radius, falloff = f.falloff, height = f.height, height2 = f.height2,
                  x = f.x + rec.ox, z = f.z + rec.oz }
      if f.x2 then g.x2, g.z2 = f.x2 + rec.ox, f.z2 + rec.oz end
      cfg.flats[#cfg.flats + 1] = g
    end
  end
  mvl.terrain(cfg)
end

-- The land containing a world position (activating it), or nil.
function S:land_at(wx, wz)
  local half = landgen.SIZE / 2
  local gx = self.agx + math.floor((wx + half) / landgen.SIZE)
  local gz = self.agz + math.floor((wz + half) / landgen.SIZE)
  local k = key(gx, gz)
  local rec = self.lands[k]
  if rec ~= nil then return rec or nil end
  local node = self.provider(gx, gz)
  if not node then
    self.lands[k] = false
    return nil
  end
  return self:activate(node, gx, gz)
end

-- The walkable rectangle: every land of the country.
function S:bounds()
  local half = landgen.SIZE / 2
  local x0, z0 = self:offset(0, 0)
  local x1, z1 = self:offset(landgen.GRID - 1, landgen.GRID - 1)
  return x0 - half + 2, z0 - half + 2, x1 + half - 2, z1 + half - 2
end

-- ------------------------------------------------------------- content
local function resolve_mesh(f)
  if f.voxel then return mvl.mesh("voxels/" .. f.voxel .. ".vox", f.voxel_size or 0.125) end
  if f.model then return mvl.mesh("models/" .. f.model .. ".obj") end
  return 0
end

local function inside(x, z, x0, z0) return x >= x0 and x < x0 + chunks.SIZE and z >= z0 and z < z0 + chunks.SIZE end

local function cleared(d, lx, lz)
  for _, c in ipairs(d.clear or {}) do
    local dx, dz = lx - c.x, lz - c.z
    if dx * dx + dz * dz < c.r * c.r then return false end
  end
  local ways = d.roads
  if d.rivers and #d.rivers > 0 then
    ways = {}
    for _, r in ipairs(d.roads) do ways[#ways + 1] = r end
    for _, r in ipairs(d.rivers) do ways[#ways + 1] = r end
  end
  for _, road in ipairs(ways) do
    local r = road.width / 2 + 2
    for i = 1, #road.points - 1 do
      local a, b = road.points[i], road.points[i + 1]
      local sx, sz = b[1] - a[1], b[2] - a[2]
      local len2 = sx * sx + sz * sz
      local t = len2 > 0 and math.max(0, math.min(1, ((lx - a[1]) * sx + (lz - a[2]) * sz) / len2)) or 0
      local dx, dz = lx - (a[1] + sx * t), lz - (a[2] + sz * t)
      if dx * dx + dz * dz < r * r then return false end
    end
  end
  return true
end

function S:build(cx, cz, rec)
  local size, d = chunks.SIZE, rec.node.data
  local x0, z0 = cx * size, cz * size
  local c = { cx = cx, cz = cz, entities = {}, meshes = {}, land = rec }
  local mesh = mvl.terrain_chunk(cx, cz, size, chunks.CELLS)
  c.meshes[#c.meshes + 1] = mesh
  c.entities[#c.entities + 1] = mvl.spawn({ mesh = mesh, texture = PAL.texture(d.materials, d.texture or "grass"),
                                            pos = { x0, 0, z0 } })
  -- the land's features standing in this chunk, plus what the player put
  -- there; the change log and a hook may hide or alter them (items taken,
  -- lamps lit, things moved)
  local list = d.features
  if rec.memory and next(rec.memory.placed) then
    list = {}
    for _, f in ipairs(d.features) do list[#list + 1] = f end
    for _, f in ipairs(rec.memory:placed_list()) do list[#list + 1] = f end
  end
  for _, f0 in ipairs(list) do
    local wx, wz = f0.x + rec.ox, f0.z + rec.oz
    local f = f0
    if inside(wx, wz, x0, z0) then
      if rec.memory then f = changes.apply(rec.memory, f) end
      if f and self.hook then
        local h = self.hook(f, rec)
        if h ~= nil then f = h end
      end
    end
    if f and inside(wx, wz, x0, z0) then
      wx, wz = f.x + rec.ox, f.z + rec.oz
      local e
      if f.sprite then
        e = mvl.spawn({ kind = "sprite", texture = PAL.texture(d.materials, f.sprite),
                        pos = { wx, mvl.height(wx, wz) + (f.y or 0), wz }, scale = { f.w or 1, f.h or 1, 1 },
                        unlit = f.unlit, nofog = f.nofog, color = f.color, solid = f.radius ~= nil, radius = f.radius })
      else
        local s = f.scale or 1
        e = mvl.spawn({
          mesh = resolve_mesh(f), texture = f.texture and PAL.texture(d.materials, f.texture) or 0,
          pos = { wx, mvl.height(wx, wz) + (f.y or 0), wz }, yaw = f.yaw or 0,
          scale = type(s) == "number" and { s, s, s } or s, color = f.color,
          solid = f.box ~= nil or f.radius ~= nil, box = f.box, radius = f.radius,
        })
      end
      c.entities[#c.entities + 1] = e
      if f.id then
        self.spawned[f.id] = e
        self.owner = self.owner or {}
        self.owner[f.id] = c
        c.ids = c.ids or {}
        c.ids[#c.ids + 1] = f.id
      end
    end
  end
  -- fields: decals on their flattened ground
  for _, fl in ipairs(d.fields) do
    local wx, wz = fl.x + rec.ox, fl.z + rec.oz
    if inside(wx, wz, x0, z0) then
      local m = mvl.plane_mesh(fl.w, fl.d, fl.w / 4, fl.d / 4, math.max(1, math.floor(math.max(fl.w, fl.d) / 4)))
      c.meshes[#c.meshes + 1] = m
      c.entities[#c.entities + 1] = mvl.spawn({ mesh = m, texture = PAL.texture(d.materials, fl.texture),
                                                pos = { wx, mvl.height(wx, wz) + 0.02, wz }, yaw = fl.yaw, color = fl.tint,
                                                decal = true })
    end
  end
  -- road pieces whose middle lies in this chunk, draped every 4 m
  for _, road in ipairs(d.roads) do
    for i = 1, #road.points - 1 do
      local a, b = road.points[i], road.points[i + 1]
      local mx, mz = (a[1] + b[1]) / 2 + rec.ox, (a[2] + b[2]) / 2 + rec.oz
      if inside(mx, mz, x0, z0) then
        local ax, az, bx, bz = a[1] + rec.ox, a[2] + rec.oz, b[1] + rec.ox, b[2] + rec.oz
        local len = math.sqrt((bx - ax) * (bx - ax) + (bz - az) * (bz - az))
        local n = math.max(1, math.floor(len / 4))
        local pts = {}
        for k = 0, n do
          local t = k / n
          local x, z = ax + (bx - ax) * t, az + (bz - az) * t
          pts[#pts + 1] = x - mx
          pts[#pts + 1] = mvl.height(x, z) + 0.04
          pts[#pts + 1] = z - mz
        end
        local m = mvl.ribbon_mesh(pts, road.width, 4)
        c.meshes[#c.meshes + 1] = m
        c.entities[#c.entities + 1] = mvl.spawn({ mesh = m, texture = PAL.texture(d.materials, road.texture),
                                                  pos = { mx, 0, mz }, decal = true })
      end
    end
  end
  -- water: the sea wherever the ground dips below sea level, and rivers
  local wc = d.materials and d.materials.water or { 0.55, 0.75, 0.9 }
  local water = { wc[1], wc[2], wc[3], 1 }
  local _, ylo = mvl.mesh_bounds(mesh)
  if ylo and ylo < 0 then
    if not self.sea_mesh then self.sea_mesh = mvl.plane_mesh(size, size, size / 8, size / 8, 4) end
    c.sea = true
    c.entities[#c.entities + 1] = mvl.spawn({ mesh = self.sea_mesh, texture = mvl.texture("textures/water.tga"),
                                              pos = { x0 + size / 2, 0, z0 + size / 2 }, uv_scroll = { 0.01, 0.006 },
                                              color = water })
  end
  -- each chunk draws the part of a river inside its square, so the water
  -- is there wherever the player is and pieces meet at chunk borders
  for _, river in ipairs(d.rivers or {}) do
    for i = 1, #river.points - 1 do
      local a, b = river.points[i], river.points[i + 1]
      local ax, az, bx, bz = a[1] + rec.ox, a[2] + rec.oz, b[1] + rec.ox, b[2] + rec.oz
      local t0, t1 = 0, 1
      for axis = 1, 2 do
        local p0, dp = axis == 1 and ax or az, axis == 1 and (bx - ax) or (bz - az)
        local lo, hi = axis == 1 and x0 or z0, (axis == 1 and x0 or z0) + size
        if dp == 0 then
          if p0 < lo or p0 > hi then t0 = 2 end
        else
          local ta, tb = (lo - p0) / dp, (hi - p0) / dp
          if ta > tb then ta, tb = tb, ta end
          t0, t1 = math.max(t0, ta), math.min(t1, tb)
        end
      end
      if t1 - t0 > 1e-6 then
        local mx, mz = x0 + size / 2, z0 + size / 2
        local len = math.sqrt((bx - ax) * (bx - ax) + (bz - az) * (bz - az)) * (t1 - t0)
        local n = math.max(1, math.floor(len / 8))
        local pts = {}
        for k = 0, n do
          local t = t0 + (t1 - t0) * k / n
          pts[#pts + 1] = ax + (bx - ax) * t - mx
          pts[#pts + 1] = a[3] + (b[3] - a[3]) * t - 0.6
          pts[#pts + 1] = az + (bz - az) * t - mz
        end
        local m = mvl.ribbon_mesh(pts, river.width, 8)
        c.river = true
        c.meshes[#c.meshes + 1] = m
        c.entities[#c.entities + 1] = mvl.spawn({ mesh = m, texture = mvl.texture("textures/water.tga"),
                                                  pos = { mx, 0, mz }, uv_scroll = { 0.0, 0.05 },
                                                  color = water })
      end
    end
  end
  -- flora, seeded by the land and the chunk's place in it
  local flora = d.flora
  local lcx, lcz = cx - math.floor(rec.ox / size), cz - math.floor(rec.oz / size)
  local rng = mvl.rng(mvl.hash(rec.node.seed, lcx, lcz))
  local planted = 0
  local function plant(texture, w, h, radius)
    local lx, lz = (lcx + rng:next()) * size, (lcz + rng:next()) * size
    local sc = 0.8 + rng:next() * 0.5
    planted = planted + 1
    -- stable id: the chunk's place in the land and the plant's number
    local id = "flora/" .. lcx .. "," .. lcz .. "/" .. planted
    if not cleared(d, lx, lz) or (rec.memory and rec.memory:taken(id)) then return end
    if mvl.height(lx + rec.ox, lz + rec.oz) < 0.3 then return end -- nothing grows under water
    local wx, wz = lx + rec.ox, lz + rec.oz
    c.entities[#c.entities + 1] = mvl.spawn({
      kind = "sprite", texture = PAL.texture(d.materials, texture),
      pos = { wx, mvl.height(wx, wz), wz }, scale = { w * sc, h * sc, 1 }, solid = radius ~= nil, radius = radius,
    })
  end
  for _ = 1, rng:int(0, flora.tree_count * 2) do
    local tree = flora.trees[rng:int(1, #flora.trees)]
    plant(tree, tree == "tree_pine" and 3 or 3.5, tree == "tree_pine" and 6 or 5, 0.4)
  end
  for _ = 1, rng:int(0, flora.bush_count * 2) do plant("bush", 1, 1) end
  for _ = 1, rng:int(0, flora.flower_count * 2) do plant("flowers", 0.6, 0.6) end
  -- boulders of the land's bedrock
  if d.materials then
    self.boulders = self.boulders or {}
    local shapes = self.boulders[rec.node.address]
    if not shapes then
      shapes = PAL.boulders(d.materials, mvl.hash(rec.node.seed, "boulders"), 3)
      self.boulders[rec.node.address] = shapes
    end
    for _ = 1, rng:int(0, 2) do
      local lx, lz = (lcx + rng:next()) * size, (lcz + rng:next()) * size
      local shape = shapes[rng:int(1, #shapes)]
      local wx, wz = lx + rec.ox, lz + rec.oz
      local sc = 0.6 + rng:next() * 0.9
      if cleared(d, lx, lz) and mvl.height(wx, wz) > 0.3 and shape.mesh > 0 then
        c.rocks = (c.rocks or 0) + 1
        c.entities[#c.entities + 1] = mvl.spawn({ mesh = shape.mesh, pos = { wx, mvl.height(wx, wz) - 0.15, wz },
                                                  yaw = rng:next() * 6.283, scale = { sc, sc, sc },
                                                  solid = true, radius = shape.radius * sc })
      end
    end
  end
  self.loaded[key(cx, cz)] = c
  self.count = self.count + 1
  self.stats.built = self.stats.built + 1
  self.stats.max_loaded = math.max(self.stats.max_loaded, self.count)
  return c
end

function S:unload(k)
  local c = self.loaded[k]
  for _, e in ipairs(c.entities) do mvl.destroy(e) end
  for _, id in ipairs(c.ids or {}) do self.spawned[id] = nil end
  for _, m in ipairs(c.meshes) do mvl.release_mesh(m) end
  self.loaded[k] = nil
  self.count = self.count - 1
  self.stats.unloaded = self.stats.unloaded + 1
end

-- Streams around (px, pz): drops far chunks and builds the nearest missing
-- ones (at most `budget`, default PER_TICK). Returns the number built.
function S:update(px, pz, budget)
  local size = chunks.SIZE
  local pcx, pcz = math.floor(px / size), math.floor(pz / size)
  for k, c in pairs(self.loaded) do
    if math.max(math.abs(c.cx - pcx), math.abs(c.cz - pcz)) > chunks.UNLOAD then self:unload(k) end
  end
  local built, limit = 0, budget or chunks.PER_TICK
  for r = 0, chunks.LOAD do
    for dz = -r, r do
      for dx = -r, r do
        if math.max(math.abs(dx), math.abs(dz)) == r then
          local cx, cz = pcx + dx, pcz + dz
          if not self.loaded[key(cx, cz)] then
            local rec = self:land_at((cx + 0.5) * size, (cz + 0.5) * size)
            if rec then
              self:build(cx, cz, rec)
              built = built + 1
              if built >= limit then return built end
            end
          end
        end
      end
    end
  end
  return built
end

-- Builds everything within LOAD at once (on arrival).
function S:fill(px, pz) return self:update(px, pz, math.huge) end

-- Destroys every chunk.
function S:clear()
  for k in pairs(self.loaded) do self:unload(k) end
  if self.sea_mesh then
    mvl.release_mesh(self.sea_mesh)
    self.sea_mesh = nil
  end
  for _, shapes in pairs(self.boulders or {}) do
    for _, s in ipairs(shapes) do if s.mesh > 0 then mvl.release_mesh(s.mesh) end end
  end
  self.boulders = nil
end

-- Spawns a feature added at runtime (e.g. a dropped item) if its chunk is
-- built; otherwise it appears when the chunk is built (if it is in the
-- land's change log).
function S:add_feature(f, rec)
  rec = rec or self.land_list[1]
  local wx, wz = f.x + rec.ox, f.z + rec.oz
  local c = self:chunk_at(wx, wz)
  if not c then return nil end
  local e = mvl.spawn({ kind = f.sprite and "sprite" or nil,
                        texture = f.sprite and PAL.texture(rec.node.data.materials, f.sprite) or 0,
                        mesh = (not f.sprite) and resolve_mesh(f) or nil,
                        pos = { wx, mvl.height(wx, wz) + (f.y or 0), wz }, yaw = f.yaw or 0,
                        scale = f.sprite and { f.w or 1, f.h or 1, 1 } or
                                (type(f.scale) == "table" and f.scale or { f.scale or 1, f.scale or 1, f.scale or 1 }),
                        unlit = f.unlit, nofog = f.nofog, color = f.color })
  c.entities[#c.entities + 1] = e
  if f.id then
    self.spawned[f.id] = e
    self.owner = self.owner or {}
    self.owner[f.id] = c
    c.ids = c.ids or {}
    c.ids[#c.ids + 1] = f.id
  end
  return e
end

-- World position of a feature of a land.
function S:feature_pos(f, rec)
  rec = rec or self.land_list[1]
  local x, z = f.x + rec.ox, f.z + rec.oz
  return x, mvl.height(x, z), z
end

-- Destroys a feature's entity now (it is rebuilt from the hook's view later).
function S:remove_feature(id)
  local e = self.spawned[id]
  if not e then return end
  mvl.destroy(e)
  self.spawned[id] = nil
  local c = self.owner and self.owner[id]
  if c then
    for i, x in ipairs(c.entities) do
      if x == e then table.remove(c.entities, i) break end
    end
  end
end

-- Chunk record at a world position (nil if not built).
function S:chunk_at(x, z) return self.loaded[key(math.floor(x / chunks.SIZE), math.floor(z / chunks.SIZE))] end

return chunks
