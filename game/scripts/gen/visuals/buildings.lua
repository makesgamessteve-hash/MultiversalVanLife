-- Multiversal Van Life - voxel buildings from a floor-plan grammar (MIT).
--
-- A building kind (house, workshop, temple, well, wall) and a culture's
-- style vector (gen/culture/architecture.lua) give a footprint (square,
-- round, courtyard, longhouse, burrow or tower), storeys, walls with a
-- door sized to the people and windows, a roof of the style's type, its
-- ornaments and, for winged peoples, a hatch in the roof. Grids are at most
-- 64 x 64 x 48 voxels of 1/8 m, Z up, front towards +y (the world's -z when
-- unturned); the mesh stands on its base, centred.
--
-- Palette: 1 wall, 2 wall shadow, 3 roof, 4 roof shadow, 5 wood, 6 accent,
-- 7 windows and doorways, 8 the roof hatch.
--
-- Mods add roof types: B.ROOFS[name] = function(g, plan, top) ... end
-- draws a roof onto the walls (plan.x0..x1, y0..y1 is the footprint, `top`
-- the height of the walls) and a style with roof = name uses it.
local B = { VOXEL = 0.125, STOREY = 22, ROOFS = {}, ORNAMENTS = {} }

local function color(g, i, c) g:color(i, c[1], c[2], c[3]) end

-- The plan of a building: footprint and heights in voxels.
function B.plan(kind, style, seed)
  local r = mvl.rng(seed)
  local p = { kind = kind, shape = style.plan, storeys = style.storeys, roof = style.roof, pitch = style.pitch }
  local w, d
  if kind == "well" then
    p.shape, w, d, p.storeys, p.roof = "well", 16, 16, 0, "well"
  elseif kind == "wall" then
    p.shape, w, d, p.storeys, p.roof = "wall", 60, 6, 1, "battlements"
  else
    local big = kind == "temple" and 1.3 or (kind == "workshop" and 0.85 or 1)
    if p.shape == "courtyard" then w, d = 52, 52
    elseif p.shape == "longhouse" then w, d = 58, 26
    elseif p.shape == "round" or p.shape == "tower" then w = p.shape == "tower" and 22 or 34; d = w
    elseif p.shape == "burrow" then w, d = 40, 36
    else w, d = 32 + r:int(0, 10), 26 + r:int(0, 8) end
    w, d = math.min(62, math.floor(w * big)), math.min(62, math.floor(d * big))
    if p.shape == "tower" then p.storeys = math.max(p.storeys, 2) + (kind == "temple" and 1 or 0)
    elseif kind == "temple" then p.storeys = p.storeys + 1 end
  end
  p.w, p.d = w, d
  p.x0, p.y0 = math.floor((64 - w) / 2), math.floor((64 - d) / 2)
  p.x1, p.y1 = p.x0 + w - 1, p.y0 + d - 1
  p.top = math.min(40, math.max(6, p.storeys * B.STOREY))
  p.door = { h = math.min(style.door.h, p.top - 2), w = style.door.w }
  p.seed = seed
  return p
end

-- ------------------------------------------------------------------ roofs
B.ROOFS.gable = function(g, p, top)
  local rise = math.max(1, math.floor(p.d / 2 * math.max(p.pitch, 0.3)))
  for k = 0, rise do
    local inset = math.floor(k * (p.d / 2) / rise)
    if p.y0 - 1 + inset > p.y1 + 1 - inset then break end
    g:box(p.x0 - 1, p.y0 - 1 + inset, top + k, p.x1 + 1, p.y1 + 1 - inset, top + k, k % 2 == 0 and 3 or 4)
  end
  return top + rise
end
B.ROOFS.hip = function(g, p, top)
  local rise = math.max(1, math.floor(math.min(p.w, p.d) / 2 * math.max(p.pitch, 0.3)))
  for k = 0, rise do
    local iy = math.floor(k * (p.d / 2) / rise)
    local ix = math.floor(k * (math.min(p.w, p.d) / 2) / rise)
    if p.y0 - 1 + iy > p.y1 + 1 - iy or p.x0 - 1 + ix > p.x1 + 1 - ix then break end
    g:box(p.x0 - 1 + ix, p.y0 - 1 + iy, top + k, p.x1 + 1 - ix, p.y1 + 1 - iy, top + k, k % 2 == 0 and 3 or 4)
  end
  return top + rise
end
B.ROOFS.flat = function(g, p, top)
  g:box(p.x0, p.y0, top, p.x1, p.y1, top, 3)
  g:box(p.x0, p.y0, top + 1, p.x1, p.y0, top + 2, 4)
  g:box(p.x0, p.y1, top + 1, p.x1, p.y1, top + 2, 4)
  g:box(p.x0, p.y0, top + 1, p.x0, p.y1, top + 2, 4)
  g:box(p.x1, p.y0, top + 1, p.x1, p.y1, top + 2, 4)
  return top + 2
end
B.ROOFS.dome = function(g, p, top)
  local cx, cy = (p.x0 + p.x1) / 2, (p.y0 + p.y1) / 2
  local r = math.min(p.w, p.d) / 2
  g:ellipsoid(cx, cy, top, r, r, r * 0.8, 3)
  g:ellipsoid(cx - r * 0.2, cy - r * 0.2, top + r * 0.2, r * 0.6, r * 0.6, r * 0.6, 4)
  return math.floor(top + r * 0.8)
end
B.ROOFS.cone = function(g, p, top)
  local cx, cy = (p.x0 + p.x1) / 2, (p.y0 + p.y1) / 2
  local r = math.min(p.w, p.d) / 2 + 2
  local rise = math.floor(r * math.max(p.pitch, 0.5) * 1.2)
  for k = 0, rise do
    local rr = r * (1 - k / (rise + 1))
    g:cylinder(cx, cy, top + k, top + k, rr, k % 3 == 0 and 4 or 3)
  end
  return top + rise
end
B.ROOFS.turf = function(g, p, top)
  local cx, cy = (p.x0 + p.x1) / 2, (p.y0 + p.y1) / 2
  g:ellipsoid(cx, cy, 0, p.w / 2 + 1, p.d / 2 + 1, top + 6, 3)
  g:ellipsoid(cx, cy, top + 3, p.w / 3, p.d / 3, 3, 4)
  return top + 6
end
B.ROOFS.well = function(g, p, top)
  g:box(p.x0, 7, top, p.x0 + 1, 8, top + 12, 5)
  g:box(p.x1 - 1, 7, top, p.x1, 8, top + 12, 5)
  g:box(p.x0 - 1, 4, top + 13, p.x1 + 1, 11, top + 13, 3)
  return top + 13
end
B.ROOFS.battlements = function(g, p, top)
  for x = p.x0, p.x1, 4 do g:box(x, p.y0, top + 1, math.min(x + 1, p.x1), p.y1, top + 3, 1) end
  return top + 3
end

-- -------------------------------------------------------------- ornaments
B.ORNAMENTS.crescents = function(g, p, peak)
  local cx = (p.x0 + p.x1) / 2
  g:sphere(cx, p.y1 + 1, peak + 2, 2, 6)
  g:sphere(cx + 1, p.y1 + 1, peak + 3, 1.5, 0)
end
B.ORNAMENTS.discs = function(g, p, peak)
  local cx = (p.x0 + p.x1) / 2
  g:cylinder(cx, p.y1 + 1, peak, peak + 1, 2.5, 6)
end
B.ORNAMENTS.flames = function(g, p, peak)
  for _, x in ipairs({ p.x0 + 2, (p.x0 + p.x1) / 2, p.x1 - 2 }) do
    g:line(x, (p.y0 + p.y1) / 2, peak, x, (p.y0 + p.y1) / 2, peak + 4, 0.8, 6)
  end
end
B.ORNAMENTS.waves = function(g, p, _, top)
  for x = p.x0, p.x1 do g:set(x, p.y1, top - 2 - (x % 4 < 2 and 1 or 0), 6) end
end
B.ORNAMENTS.spirals = function(g, p, _, top)
  local cx = (p.x0 + p.x1) / 2
  for k = 0, 5 do g:set(math.floor(cx + (k - 2.5) * 2), p.y1, top - 3 - k % 2, 6) end
end

-- ---------------------------------------------------------------- walls
local function walls(g, p, style)
  local cx, cy = (p.x0 + p.x1) / 2, (p.y0 + p.y1) / 2
  local top = p.top
  if p.shape == "round" or p.shape == "tower" or p.shape == "well" then
    g:cylinder(cx, cy, 0, top - 1, p.w / 2, 1)
    if p.shape == "well" then g:cylinder(cx, cy, 2, top - 1, p.w / 2 - 3, 7) end
  elseif p.shape == "burrow" then
    -- the walls are the mound (drawn with the turf roof)
  elseif p.shape == "courtyard" then
    g:box(p.x0, p.y0, 0, p.x1, p.y1, top - 1, 1)
    g:box(p.x0 + 12, p.y0 + 12, 1, p.x1 - 12, p.y1 - 12, top - 1, 0) -- the open court
  else
    g:box(p.x0, p.y0, 0, p.x1, p.y1, top - 1, 1)
  end
  -- a foundation course and storey bands in shadow colour
  if p.shape ~= "burrow" then
    for s = 0, p.storeys - 1 do
      local z = s * B.STOREY
      if p.shape == "round" or p.shape == "tower" then g:cylinder(cx, cy, z, z, p.w / 2 + 0.3, 2)
      else
        g:box(p.x0, p.y0, z, p.x1, p.y0, z, 2)
        g:box(p.x0, p.y1, z, p.x1, p.y1, z, 2)
      end
    end
  end
end

local function openings(g, p, style)
  if p.kind == "well" or p.kind == "wall" then return end
  local cx = math.floor((p.x0 + p.x1) / 2)
  local cy = (p.y0 + p.y1) / 2
  local front = p.y1
  if p.shape == "round" or p.shape == "tower" then front = math.floor(cy + p.w / 2 - 0.5) end
  if p.shape == "burrow" then front = math.floor(cy + p.d / 2) end
  local dw = math.floor(p.door.w / 2)
  -- the door: a frame of wood around a dark doorway
  g:box(cx - dw - 1, front, 0, cx + dw + 1, front, p.door.h + 1, 5)
  g:box(cx - dw, front, 0, cx + dw, front, p.door.h, 7)
  if p.kind == "workshop" and p.shape == "square" then
    -- an open front between posts
    g:box(p.x0 + 2, p.y1, 0, p.x1 - 2, p.y1, math.floor(p.top * 0.7), 7)
    g:box(p.x0, p.y1, 0, p.x0 + 1, p.y1, p.top - 1, 5)
    g:box(p.x1 - 1, p.y1, 0, p.x1, p.y1, p.top - 1, 5)
  end
  -- windows on every storey
  if p.shape ~= "burrow" then
    for s = 0, p.storeys - 1 do
      local z = s * B.STOREY + 10
      if z + 4 < p.top then
        for _, x in ipairs({ p.x0 + 5, p.x1 - 6 }) do
          if p.shape == "round" or p.shape == "tower" then
            g:box(x, front - 1, z, x + 1, front, z + 4, 7)
          else
            g:box(x, p.y1, z, x + 2, p.y1, z + 4, 7)
            g:box(x, p.y0, z, x + 2, p.y0, z + 4, 7)
          end
        end
      end
    end
  end
end

-- The grid of a building of `kind` in `style` (variation `seed`).
function B.build(kind, style, seed)
  local p = B.plan(kind, style, seed)
  local g = mvl.voxels(64, 64, 48)
  local pal = style.palette
  color(g, 1, pal.wall)
  color(g, 2, pal.wall_dark)
  color(g, 3, pal.roof)
  color(g, 4, pal.roof_dark)
  color(g, 5, pal.wood)
  color(g, 6, pal.accent)
  color(g, 7, { 22, 20, 26 })
  color(g, 8, { 40, 30, 24 })
  walls(g, p, style)
  openings(g, p, style)
  local roof = B.ROOFS[p.roof] or B.ROOFS.gable
  local peak = roof(g, p, p.top)
  local orn = B.ORNAMENTS[style.ornament]
  if orn and kind ~= "well" and kind ~= "wall" then orn(g, p, peak, p.top) end
  if kind == "temple" and style.sky_faith then
    -- a spire towards the sacred sky
    local cx, cy = (p.x0 + p.x1) / 2, (p.y0 + p.y1) / 2
    g:line(cx, cy, peak, cx, cy, math.min(47, peak + 8), 1.2, 6)
  end
  if style.roof_entry and kind ~= "well" and kind ~= "wall" then
    -- a hatch in the roof for those who fly in
    local cx, cy = math.floor((p.x0 + p.x1) / 2), math.floor((p.y0 + p.y1) / 2)
    local z = p.roof == "flat" and p.top or math.min(peak, 47)
    if p.roof ~= "flat" then z = p.top + 1 end
    g:box(cx - 3, cy - 3, z, cx + 3, cy + 3, z, 5)
    g:box(cx - 2, cy - 2, z, cx + 2, cy + 2, math.min(47, peak + 1), 0)
    g:box(cx - 2, cy - 2, z, cx + 2, cy + 2, z, 8)
    p.hatch = { cx, cy, z }
  end
  return g, p
end

-- Weathers a building into a ruin: no roof, broken walls, moss.
function B.weather(g, p, seed)
  local r = mvl.rng(seed)
  g:color(9, 70, 96, 52)
  g:box(0, 0, p.top, 63, 63, 47, 0) -- the roof fell in
  for _ = 1, 10 do
    local x = p.x0 + r:next() * p.w
    local y = p.y0 + r:next() * p.d
    g:sphere(x, y, p.top * (0.3 + r:next() * 0.8), 3 + r:next() * 6, 0)
  end
  g:replace(2, 9) -- moss over the shadowed courses
  g:replace(3, 9)
  return g
end

-- Mesh, collider footprint (metres) and grid hash of a building; with
-- `ruined`, of its ruin.
function B.mesh(kind, style, seed, ruined)
  local g, p = B.build(kind, style, seed)
  if ruined then B.weather(g, p, seed) end
  local hash = g:hash()
  local mesh = g:mesh(B.VOXEL)
  g:free()
  return mesh, { p.w * B.VOXEL, p.d * B.VOXEL }, hash, p
end

return B
