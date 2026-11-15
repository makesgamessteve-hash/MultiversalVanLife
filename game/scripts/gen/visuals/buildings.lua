-- Multiversal Van Life - voxel buildings from a floor-plan grammar (MIT).
--
-- A building kind (cottage, house, workshop, barn, inn, hall, temple, well,
-- wall) and a culture's style vector (gen/culture/architecture.lua) give a
-- plan in metres, sized to the people who live there: storeys of 1.75 times
-- their height (at least 3 m), doors of 1.25 times their height (at least
-- 2 m), footprints by kind (a village house of people 1.7 m tall is about
-- 10 x 8 m). The plan becomes a grid of 1/8 m voxels just large enough for
-- it (at most 24 x 24 x 16 m): a footprint (square, round, courtyard,
-- longhouse, burrow or tower), walls with a door and windows on every
-- storey, a roof of the style's type (gable ridges along the long side),
-- its ornaments and, for winged peoples, a hatch in the roof. Buildings
-- longer than 24 m are built as joined modules (B.parts). Z up, front
-- towards +y (the world's -z when unturned); the mesh stands on its base,
-- centred.
--
-- Palette: 1 wall, 2 wall shadow, 3 roof, 4 roof shadow, 5 wood, 6 accent,
-- 7 windows and doorways, 8 the roof hatch.
--
-- Mods add roof types: B.ROOFS[name] = function(g, plan, top) ... end
-- draws a roof onto the walls (plan.x0..x1, y0..y1 is the footprint, `top`
-- the height of the walls) and a style with roof = name uses it.
local B = { VOXEL = 0.125, ROOFS = {}, ORNAMENTS = {}, MODULE = 24, STOREY_MIN = 3.0, DOOR_MIN = 2.0 }

-- Sizes of building kinds for people 1.7 m tall, in metres: footprint
-- ranges (w along the front, d deep), storeys added to the culture's (at
-- least `min`, with a chance `extra` of one more), and how tall their storeys
-- are. Mods add kinds: B.KINDS.granary = { w = { 6, 7 }, d = { 6, 7 }, storeys = -1 }.
B.KINDS = {
  cottage = { w = { 7, 8.5 }, d = { 5.5, 6.5 }, storeys = -1 },
  house = { w = { 9, 11 }, d = { 7, 9 }, storeys = 0, min = 2, extra = 0.25 },
  workshop = { w = { 8, 10 }, d = { 7, 9 }, storeys = -1, tall = 1.2 },
  barn = { w = { 13, 15 }, d = { 8.5, 9.5 }, storeys = -9, tall = 1.6 },
  inn = { w = { 13, 15 }, d = { 9, 11 }, storeys = 1 },
  hall = { w = { 18, 22 }, d = { 9, 11 }, storeys = -9, tall = 1.7 },
  temple = { w = { 13, 15 }, d = { 22, 26 }, storeys = 0, tall = 1.4 },
}

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function color(g, i, c) g:color(i, c[1], c[2], c[3]) end

-- What a people's buildings measure (metres): their height, storeys, doors
-- and how much larger than for people 1.7 m tall everything is.
function B.sizes(style)
  local h = style.height or 1.7
  local door_w = (style.door and style.door.w or 7) * 0.125 * 1.3
  return { height = h, storey = math.max(B.STOREY_MIN, 1.75 * h), door_h = math.max(B.DOOR_MIN, 1.25 * h),
           door_w = clamp(door_w * math.max(1, h / 1.7), 0.9, 2.6), scale = clamp(h / 1.7, 0.85, 2.5) }
end

-- The plan of a building: sizes in metres turned into voxels. opts.length
-- sets the width along the front (modules), opts.door = false leaves the
-- door out, opts.gable forces a gable or flat roof (modules join).
function B.plan(kind, style, seed, opts)
  opts = opts or {}
  local r = mvl.rng(seed)
  local z = B.sizes(style)
  local V = B.VOXEL
  local p = { kind = kind, shape = style.plan, roof = style.roof, pitch = style.pitch, seed = seed }
  local wm, dm_, storeys, storey_m
  if kind == "well" then
    p.shape, p.roof, wm, dm_, storeys, storey_m = "well", "well", 2.5, 2.5, 1, 1.0
  elseif kind == "wall" then
    p.shape, p.roof, wm, dm_, storeys, storey_m = "wall", "battlements", opts.length or 12, 1.5, 1, 4.5
  else
    local k = B.KINDS[kind] or B.KINDS.house
    wm = (k.w[1] + r:next() * (k.w[2] - k.w[1])) * z.scale
    dm_ = (k.d[1] + r:next() * (k.d[2] - k.d[1])) * z.scale
    storeys = clamp(math.max(k.min or 1, (style.storeys or 1) + (k.storeys or 0)) +
                    ((k.extra and r:chance(k.extra)) and 1 or 0), 1, 4)
    storey_m = z.storey * (k.tall or 1)
    if p.shape == "round" then
      wm = (wm + dm_) / 2
      dm_ = wm
    elseif p.shape == "tower" then
      wm = math.max(5 * z.scale, math.min(wm, dm_) * 0.65)
      dm_ = wm
      storeys = math.max(storeys, 2) + 1 + (kind == "temple" and 1 or 0)
    elseif p.shape == "courtyard" then
      wm = math.max(wm, dm_) * 1.4
      dm_ = wm
    elseif p.shape == "longhouse" then
      wm, dm_ = math.max(wm, dm_) * 1.6, 7 * z.scale
    elseif p.shape == "burrow" then
      wm, dm_, storeys = wm * 1.15, dm_ * 1.15, 1
    end
    if kind == "temple" and p.shape ~= "tower" then storeys = storeys + 1 end
    if opts.length then
      wm = opts.length
      if p.shape == "round" or p.shape == "tower" or p.shape == "courtyard" or p.shape == "burrow" then
        p.shape = "square"
      end
    end
    if opts.gable and p.roof ~= "flat" then p.roof = "gable" end
  end
  -- metres to voxels, within the largest model
  p.w = clamp(math.floor(wm / V + 0.5), 8, B.MODULE / V)
  p.d = clamp(math.floor(dm_ / V + 0.5), 8, B.MODULE / V)
  p.storeys = storeys
  p.storey = math.floor(storey_m / V + 0.5)
  p.top = p.storeys * p.storey
  -- doors: at least 2 m tall and 9 voxels (1.1 m) wide, an odd width so they are centred
  local dw = math.max(9, math.floor(z.door_w / V + 0.5))
  p.door = { h = math.min(math.floor(z.door_h / V + 0.5), p.storey - 3), w = dw + (dw + 1) % 2, none = opts.door == false }
  -- the grid: room for the roof's overhang, ornaments and spires
  local rise = math.ceil(math.min(p.w, p.d) / 2 * math.max(p.pitch or 0.6, 0.5) * 1.25) + 10
  p.gx, p.gy = p.w + 10, p.d + 10
  p.gz = math.min(255, p.top + rise + 14)
  p.x0, p.y0 = math.floor((p.gx - p.w) / 2), math.floor((p.gy - p.d) / 2)
  p.x1, p.y1 = p.x0 + p.w - 1, p.y0 + p.d - 1
  p.metres = { w = p.w * V, d = p.d * V, storey = p.storey * V, door = p.door.h * V, door_w = p.door.w * V,
               walls = p.top * V }
  return p
end

-- The modules of a building `length` metres wide along its front: one
-- plan per module ({ plan options, offset in metres along the front }).
-- Modules have the same depth, storeys and roof, so they join without gaps.
function B.parts(kind, style, seed, length)
  if not length or length <= B.MODULE then return { { opts = { length = length }, offset = 0 } } end
  local n = math.ceil(length / B.MODULE)
  local each = length / n
  local out = {}
  for i = 1, n do
    out[i] = { opts = { length = each, door = i == math.ceil(n / 2), gable = true },
               offset = -length / 2 + (i - 0.5) * each }
  end
  return out
end

-- ------------------------------------------------------------------ roofs
B.ROOFS.gable = function(g, p, top)
  -- the ridge runs along the longer side
  local along_x = p.w >= p.d
  local span = along_x and p.d or p.w
  local rise = math.max(1, math.floor(span / 2 * math.max(p.pitch, 0.3)))
  for k = 0, rise do
    local inset = math.floor(k * (span / 2) / rise)
    local c = k % 2 == 0 and 3 or 4
    if along_x then
      if p.y0 - 1 + inset > p.y1 + 1 - inset then break end
      g:box(p.x0 - 1, p.y0 - 1 + inset, top + k, p.x1 + 1, p.y1 + 1 - inset, top + k, c)
    else
      if p.x0 - 1 + inset > p.x1 + 1 - inset then break end
      g:box(p.x0 - 1 + inset, p.y0 - 1, top + k, p.x1 + 1 - inset, p.y1 + 1, top + k, c)
    end
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
  local cy = math.floor((p.y0 + p.y1) / 2)
  g:box(p.x0, cy - 1, top, p.x0 + 1, cy, top + 14, 5)
  g:box(p.x1 - 1, cy - 1, top, p.x1, cy, top + 14, 5)
  g:box(p.x0 - 1, p.y0 + 2, top + 15, p.x1 + 1, p.y1 - 2, top + 15, 3)
  return top + 15
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
    local inset = math.floor(math.min(p.w, p.d) * 0.28)
    g:box(p.x0 + inset, p.y0 + inset, 1, p.x1 - inset, p.y1 - inset, top - 1, 0) -- the open court
  else
    g:box(p.x0, p.y0, 0, p.x1, p.y1, top - 1, 1)
  end
  -- a foundation course and storey bands in shadow colour
  if p.shape ~= "burrow" then
    for s = 0, p.storeys - 1 do
      local z = s * p.storey
      if p.shape == "round" or p.shape == "tower" then g:cylinder(cx, cy, z, z, p.w / 2 + 0.3, 2)
      else
        g:box(p.x0, p.y0, z, p.x1, p.y0, z, 2)
        g:box(p.x0, p.y1, z, p.x1, p.y1, z, 2)
      end
    end
  end
end

-- Positions of windows along a wall from a0 to a1, about every 2.5 m,
-- away from [skip0, skip1].
local function window_spots(a0, a1, skip0, skip1)
  local out = {}
  local span = a1 - a0
  local n = math.max(1, math.floor(span / 20))
  for i = 1, n do
    local a = a0 + math.floor(i * span / (n + 1)) - 3
    if a > a0 + 1 and a + 5 < a1 and (a + 5 < skip0 or a > skip1) then out[#out + 1] = a end
  end
  return out
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
  if not p.door.none then
    g:box(cx - dw - 1, front, 0, cx + dw + 1, front, p.door.h + 1, 5)
    g:box(cx - dw, front, 0, cx + dw, front, p.door.h, 7)
  end
  if p.kind == "workshop" and p.shape == "square" then
    -- an open front between posts
    g:box(p.x0 + 2, p.y1, 0, p.x1 - 2, p.y1, math.floor(p.top * 0.7), 7)
    g:box(p.x0, p.y1, 0, p.x0 + 1, p.y1, p.top - 1, 5)
    g:box(p.x1 - 1, p.y1, 0, p.x1, p.y1, p.top - 1, 5)
  end
  if p.kind == "barn" and p.shape ~= "burrow" and not p.door.none then
    -- wide doors for carts
    local half = math.min(math.floor(p.w / 4), 14)
    g:box(cx - half - 1, p.y1, 0, cx + half + 1, p.y1, math.floor(p.top * 0.75) + 1, 5)
    g:box(cx - half, p.y1, 0, cx + half, p.y1, math.floor(p.top * 0.75), 7)
  end
  -- windows on every storey, about every 2.5 m (sill 1 m above the floor)
  if p.shape == "burrow" then return end
  for s = 0, p.storeys - 1 do
    local z = s * p.storey + 8
    if z + 9 < p.top then
      if p.shape == "round" or p.shape == "tower" then
        for _, x in ipairs({ cx - math.floor(p.w / 4) - 2, cx + math.floor(p.w / 4) - 1 }) do
          g:box(x, front - 1, z, x + 3, front, z + 8, 7)
        end
      else
        local skip0, skip1 = s == 0 and cx - dw - 4 or 1e9, s == 0 and cx + dw + 4 or -1e9
        for _, x in ipairs(window_spots(p.x0, p.x1, skip0, skip1)) do
          g:box(x, p.y1, z, x + 5, p.y1, z + 8, 7)
        end
        for _, x in ipairs(window_spots(p.x0, p.x1, 1e9, -1e9)) do g:box(x, p.y0, z, x + 5, p.y0, z + 8, 7) end
        for _, y in ipairs(window_spots(p.y0, p.y1, 1e9, -1e9)) do
          g:box(p.x0, y, z, p.x0, y + 5, z + 8, 7)
          g:box(p.x1, y, z, p.x1, y + 5, z + 8, 7)
        end
      end
    end
  end
end

-- The grid of a building of `kind` in `style` (variation `seed`; `opts`
-- as for B.plan).
function B.build(kind, style, seed, opts)
  local p = B.plan(kind, style, seed, opts)
  local g = mvl.voxels(p.gx, p.gy, p.gz)
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
  if orn and kind ~= "well" and kind ~= "wall" and not p.door.none then orn(g, p, peak, p.top) end
  if kind == "temple" and style.sky_faith then
    -- a spire towards the sacred sky
    local cx, cy = (p.x0 + p.x1) / 2, (p.y0 + p.y1) / 2
    g:line(cx, cy, peak, cx, cy, math.min(p.gz - 1, peak + 12), 1.2, 6)
  end
  if style.roof_entry and kind ~= "well" and kind ~= "wall" then
    -- a hatch in the roof for those who fly in
    local cx, cy = math.floor((p.x0 + p.x1) / 2), math.floor((p.y0 + p.y1) / 2)
    local z = p.roof == "flat" and p.top or math.min(peak, p.gz - 1)
    if p.roof ~= "flat" then z = p.top + 1 end
    g:box(cx - 3, cy - 3, z, cx + 3, cy + 3, z, 5)
    g:box(cx - 2, cy - 2, z, cx + 2, cy + 2, math.min(p.gz - 1, peak + 1), 0)
    g:box(cx - 2, cy - 2, z, cx + 2, cy + 2, z, 8)
    p.hatch = { cx, cy, z }
  end
  return g, p
end

-- Weathers a building into a ruin: no roof, broken walls, moss.
function B.weather(g, p, seed)
  local r = mvl.rng(seed)
  g:color(9, 70, 96, 52)
  g:box(0, 0, p.top, p.gx - 1, p.gy - 1, p.gz - 1, 0) -- the roof fell in
  for _ = 1, 10 do
    local x = p.x0 + r:next() * p.w
    local y = p.y0 + r:next() * p.d
    g:sphere(x, y, p.top * (0.3 + r:next() * 0.8), (3 + r:next() * 6) * math.max(1, p.w / 36), 0)
  end
  g:replace(2, 9) -- moss over the shadowed courses
  g:replace(3, 9)
  return g
end

-- Mesh, collider footprint (metres) and grid hash of a building; with
-- `ruined`, of its ruin; `opts` as for B.plan (a module).
function B.mesh(kind, style, seed, ruined, opts)
  local g, p = B.build(kind, style, seed, opts)
  if ruined then B.weather(g, p, seed) end
  local hash = g:hash()
  local mesh = g:mesh(B.VOXEL)
  g:free()
  return mesh, { p.w * B.VOXEL, p.d * B.VOXEL }, hash, p
end

return B
