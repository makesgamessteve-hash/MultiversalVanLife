-- Multiversal Van Life - building the rooms of the house (MIT License).
--
-- A room of the plan (gen/house/plan.lua) becomes one voxel grid and so one
-- mesh: its floor layer, walls two voxels thick inside its rectangle (a wall
-- between two rooms is therefore half a metre), doorways cut through them,
-- windows, the ceiling, finishes (floorboards, tiles, wallpaper, panelling,
-- skirting and rails, beams, glass) and its furniture. Everything in a plan is
-- in pocket metres (+X the van's front, +Z its left, y up from the ground
-- floor); `rooms.build` returns the mesh, where to put it and the room's
-- colliders and floors in the same coordinates.
local Canvas = require("gen.house.canvas")
local PAL = require("gen.house.palette")
local F = require("gen.house.furniture")
local I = PAL.I
local S = Canvas.S

local R = {}
local T = 2 -- wall thickness in voxels

local function vox(m) return math.floor(m / S + 0.5) end

-- ---------------------------------------------------------- finishes
local FLOORS = {}
function FLOORS.boards(cv, rng, dir)
  local W, D = cv.W, cv.D
  if dir == "z" then
    for u = 0, W - 1 do
      cv:box(u, 0, 0, u, D - 1, 0, (mvl.hash(u, 7) % 3 == 0) and I.floor2 or I.floor)
      local v = rng:int(0, 31)
      while v < D do
        cv:set(u, v, 0, I.floor3)
        v = v + rng:int(24, 48)
      end
    end
  else
    for v = 0, D - 1 do
      cv:box(0, v, 0, W - 1, v, 0, (mvl.hash(v, 7) % 3 == 0) and I.floor2 or I.floor)
      local u = rng:int(0, 31)
      while u < W do
        cv:set(u, v, 0, I.floor3)
        u = u + rng:int(24, 48)
      end
    end
  end
end
function FLOORS.tiles(cv)
  cv:box(0, 0, 0, cv.W - 1, cv.D - 1, 0, I.floor)
  for u = 0, cv.W - 1, 4 do
    for v = (u / 4) % 2 * 2, cv.D - 1, 4 do cv:box(u, v, 0, math.min(cv.W - 1, u + 1), math.min(cv.D - 1, v + 1), 0, I.floor2) end
  end
  for v = 2, cv.D - 1, 4 do
    for u = 2 - (v / 2) % 2 * 2 + 2, cv.W - 1, 4 do cv:box(u, v, 0, math.min(cv.W - 1, u + 1), math.min(cv.D - 1, v + 1), 0, I.floor2) end
  end
end
function FLOORS.carpet(cv)
  cv:box(0, 0, 0, cv.W - 1, cv.D - 1, 0, I.floor2)
  cv:box(3, 3, 0, cv.W - 4, cv.D - 4, 0, I.floor)
end
function FLOORS.flags(cv, rng)
  cv:box(0, 0, 0, cv.W - 1, cv.D - 1, 0, I.floor3)
  for u = 0, cv.W - 1, 5 do
    for v = 0, cv.D - 1, 4 do
      local w, d = rng:int(3, 4), rng:int(2, 3)
      cv:box(u, v, 0, math.min(cv.W - 1, u + w), math.min(cv.D - 1, v + d), 0, rng:next() < 0.5 and I.floor or I.floor2)
    end
  end
end
function FLOORS.mat(cv)
  cv:box(0, 0, 0, cv.W - 1, cv.D - 1, 0, I.floor)
  for u = 1, cv.W - 1, 3 do cv:box(u, 0, 0, u, cv.D - 1, 0, I.floor2) end
end

-- the inner face of a wall: `face(cv, side, a0, a1, h0, h1, c)` paints the
-- wall's inner layer from a0 to a1 along it
local function face(cv, side, a0, a1, h0, h1, c)
  if side == "w" then cv:box(T - 1, a0, h0, T - 1, a1, h1, c)
  elseif side == "e" then cv:box(cv.W - T, a0, h0, cv.W - T, a1, h1, c)
  elseif side == "s" then cv:box(a0, T - 1, h0, a1, T - 1, h1, c)
  else cv:box(a0, cv.D - T, h0, a1, cv.D - T, h1, c) end
end
-- through the whole wall
local function through(cv, side, a0, a1, h0, h1, c)
  if side == "w" then cv:box(0, a0, h0, T - 1, a1, h1, c)
  elseif side == "e" then cv:box(cv.W - T, a0, h0, cv.W - 1, a1, h1, c)
  elseif side == "s" then cv:box(a0, 0, h0, a1, T - 1, h1, c)
  else cv:box(a0, cv.D - T, h0, a1, cv.D - 1, h1, c) end
end
-- one voxel into the room from the inner face (sills, ledges)
local function ledge(cv, side, a0, a1, h, c)
  if side == "w" then cv:box(T, a0, h, T, a1, h, c)
  elseif side == "e" then cv:box(cv.W - T - 1, a0, h, cv.W - T - 1, a1, h, c)
  elseif side == "s" then cv:box(a0, T, h, a1, T, h, c)
  else cv:box(a0, cv.D - T - 1, h, a1, cv.D - T - 1, h, c) end
end
local function wall_len(cv, side) return (side == "n" or side == "s") and cv.W or cv.D end

local WALLS = {}
function WALLS.stripes(cv, side, top)
  local n = wall_len(cv, side)
  face(cv, side, 0, n - 1, 1, top, I.wall)
  for a = 0, n - 1, 4 do face(cv, side, a, a + 1, 1, top, I.wall2) end
end
function WALLS.plain(cv, side, top) face(cv, side, 0, wall_len(cv, side) - 1, 1, top, I.wall) end
function WALLS.panels(cv, side, top)
  local n = wall_len(cv, side)
  face(cv, side, 0, n - 1, 1, top, I.wall)
  for a = 0, n - 1, 8 do face(cv, side, a, a, 1, top, I.wall2) end
  for h = 8, top, 8 do face(cv, side, 0, n - 1, h, h, I.wall2) end
end
function WALLS.tiles(cv, side, top)
  local n = wall_len(cv, side)
  face(cv, side, 0, n - 1, 1, top, I.wall)
  for a = 0, n - 1, 3 do face(cv, side, a, a, 1, math.min(top, 12), I.wall2) end
  for h = 3, math.min(top, 12), 3 do face(cv, side, 0, n - 1, h, h, I.wall2) end
  face(cv, side, 0, n - 1, 13, 13, I.tile2)
end
function WALLS.stone(cv, side, top, rng)
  local n = wall_len(cv, side)
  face(cv, side, 0, n - 1, 1, top, I.wall)
  for h = 1, top, 3 do
    local a = (h % 2) * 3
    while a < n do
      face(cv, side, a, a, h, math.min(top, h + 2), I.wall2)
      a = a + rng:int(4, 7)
    end
    face(cv, side, 0, n - 1, h, h, I.wall2)
  end
end
function WALLS.van(cv, side, top)
  local n = wall_len(cv, side)
  face(cv, side, 0, n - 1, 1, top, I.wall)
  for a = 0, n - 1, 6 do face(cv, side, a, a, 1, top, I.wall2) end
  face(cv, side, 0, n - 1, 6, 6, I.trim)
end

-- -------------------------------------------------------------- shell
local function local_span(room, side, at, w)
  -- metres along the wall from the room's corner -> voxel range
  local base = (side == "n" or side == "s") and room.x0 or room.z0
  local c = at - base
  return vox(c - w / 2), vox(c + w / 2) - 1
end

local function draw_door(cv, room, d)
  local a0, a1 = local_span(room, d.side, d.at, d.w)
  local top = vox(d.h or 2.2)
  if d.closed then
    -- a closed door, drawn on the wall: two leaves (or glass panes)
    local leaf = d.glass and I.pane or I.wood
    face(cv, d.side, a0, a1, 1, top, leaf)
    face(cv, d.side, a0 - 1, a0 - 1, 1, top + 1, I.trim)
    face(cv, d.side, a1 + 1, a1 + 1, 1, top + 1, I.trim)
    face(cv, d.side, a0 - 1, a1 + 1, top + 1, top + 1, I.trim)
    local mid = math.floor((a0 + a1) / 2)
    if d.glass then
      for a = a0 + 3, a1 - 1, 4 do face(cv, d.side, a, a, 1, top, I.white) end
      for h = 6, top, 6 do face(cv, d.side, a0, a1, h, h, I.white) end
      face(cv, d.side, a0, a1, 1, 2, I.white)
    else
      if a1 - a0 > 9 then face(cv, d.side, mid, mid, 1, top, I.wood_dark) end
      for h = 3, top - 2, 7 do
        face(cv, d.side, a0 + 1, a1 - 1, h, h, I.wood_dark)
      end
      face(cv, d.side, mid - 1, mid - 1, math.floor(top / 2), math.floor(top / 2), I.brass)
      if a1 - a0 > 9 then face(cv, d.side, mid + 1, mid + 1, math.floor(top / 2), math.floor(top / 2), I.brass) end
    end
    return
  end
  through(cv, d.side, a0, a1, 1, top, 0)
  if d.shape == "arch" then
    local r = (a1 - a0 + 1) / 2
    for j = 1, math.floor(r) do
      local half = math.sqrt(math.max(0, r * r - j * j))
      local c = (a0 + a1 + 1) / 2
      local b0, b1 = math.floor(c - half + 0.5), math.floor(c + half + 0.5) - 1
      if b1 >= b0 then through(cv, d.side, b0, b1, top + j, top + j, 0) end
    end
  else
    face(cv, d.side, a0 - 1, a1 + 1, top + 1, top + 1, I.trim)
  end
  face(cv, d.side, a0 - 1, a0 - 1, 1, top, I.trim)
  face(cv, d.side, a1 + 1, a1 + 1, 1, top, I.trim)
end

local function draw_window(cv, room, w)
  local a0, a1 = local_span(room, w.side, w.at, w.w)
  local h0, h1 = 1 + vox(w.y - w.h / 2), vox(w.y + w.h / 2)
  if w.portal then
    through(cv, w.side, a0, a1, h0, h1, 0)
  else
    -- frosted glass, lit from outside
    face(cv, w.side, a0, a1, h0, h1, I.pane)
    for a = a0 + 3, a1 - 1, 4 do face(cv, w.side, a, a, h0, h1, I.trim) end
    face(cv, w.side, a0, a1, math.floor((h0 + h1) / 2), math.floor((h0 + h1) / 2), I.trim)
  end
  face(cv, w.side, a0 - 1, a1 + 1, h1 + 1, h1 + 1, I.trim)
  face(cv, w.side, a0 - 1, a0 - 1, h0, h1, I.trim)
  face(cv, w.side, a1 + 1, a1 + 1, h0, h1, I.trim)
  ledge(cv, w.side, a0 - 1, a1 + 1, h0 - 1, I.wood_light)
  face(cv, w.side, a0 - 1, a1 + 1, h0 - 1, h0 - 1, I.trim)
end

local function draw_glass_wall(cv, side, top)
  local n = wall_len(cv, side)
  face(cv, side, 0, n - 1, 1, 6, I.dado)
  face(cv, side, 0, n - 1, 7, top, I.pane)
  for a = 0, n - 1, 8 do face(cv, side, a, a, 7, top, I.white) end
  for h = 7, top, 8 do face(cv, side, 0, n - 1, h, h, I.white) end
end

-- rectangle in pocket metres -> voxel range in the room (clamped)
local function rect(cv, room, r)
  local u0, u1 = vox(r.x0 - room.x0), vox(r.x1 - room.x0) - 1
  local v0, v1 = vox(r.z0 - room.z0), vox(r.z1 - room.z0) - 1
  return math.max(0, u0), math.max(0, v0), math.min(cv.W - 1, u1), math.min(cv.D - 1, v1)
end

-- the part of a flight of stairs inside this room's height: the room at its
-- foot draws the steps up to its ceiling, the banister and the cupboard
-- door; the room above fills its stairwell's floor layer with the top step
local function draw_stairs(cv, room, st)
  local u0, v0, u1, v1 = rect(cv, room, st)
  local n = st.steps or 16
  local base = room.y - S                         -- pocket height of layer 0's bottom
  local function layer(y) return math.floor((y - base) / S + 0.5) end
  local foot = room.y <= st.y + 0.01
  local len = u1 - u0 + 1
  for k = 0, n - 1 do
    local a0 = u0 + math.floor(k * len / n)
    local a1 = u0 + math.floor((k + 1) * len / n) - 1
    local top = layer(st.y + st.rise * (k + 1) / n) - 1
    if foot then
      local hi = math.min(top, cv.H - 2)
      if hi >= 1 then
        if hi > 1 then cv:box(a0, v0, 1, a1, v1, hi - 1, I.wood_dark) end
        cv:box(a0, v0, hi, a1, v1, hi, top <= cv.H - 2 and I.wood or I.wood_dark)
      end
    elseif top == 0 then
      cv:box(a0, v0, 0, a1, v1, 0, I.wood)
    end
  end
  if not foot then return end
  -- the banister along the open side, and its posts
  local side_v = st.open == "n" and v1 or v0
  for k = 4, n, 4 do
    local a = u0 + math.min(len - 1, math.floor(k * len / n))
    local h0 = layer(st.y + st.rise * k / n)
    local h1 = math.min(cv.H - 2, h0 + 7)
    if h0 <= h1 then cv:box(a, side_v, math.max(1, h0), a, side_v, h1, I.wood_dark) end
  end
  local ha, hb = layer(st.y + 0.95), layer(st.y + st.rise + 0.95)
  for k = math.floor(len * 4 / n), len - 1 do
    local h = ha + math.floor(k * (hb - ha) / len)
    if h >= 1 and h <= cv.H - 2 then cv:set(u0 + k, side_v, h, I.wood_light) end
  end
  -- a little door into the cupboard under the stairs
  local mid = math.floor((u0 + u1) / 2) + 4
  cv:box(mid, side_v, 1, mid + 4, side_v, 6, I.wood_light)
  cv:set(mid + 1, side_v, 4, I.brass)
end

-- the railing round a stairwell on the floor above
local function draw_railing(cv, room, rl)
  local u0, v0, u1, v1 = rect(cv, room, rl)
  cv:box(u0, v0, 8, u1, v1, 8, I.wood_light)
  if u1 - u0 > v1 - v0 then
    for u = u0, u1, 4 do cv:box(u, v0, 1, u, v1, 7, I.wood_dark) end
  else
    for v = v0, v1, 4 do cv:box(u0, v, 1, u1, v, 7, I.wood_dark) end
  end
end

-- Wall colliders of one side, split around the open doorways.
local function wall_colliders(room, side, out)
  local horizontal = side == "n" or side == "s"
  local lo, hi = horizontal and room.x0 or room.z0, horizontal and room.x1 or room.z1
  local gaps = {}
  for _, d in ipairs(room.doors or {}) do
    if d.side == side and not d.closed then gaps[#gaps + 1] = { d.at - d.w / 2, d.at + d.w / 2 } end
  end
  table.sort(gaps, function(a, b) return a[1] < b[1] end)
  local t = T * S
  local from = lo
  local function seg(a, b)
    if b - a < 0.05 then return end
    local c
    if side == "n" then c = { x0 = a, x1 = b, z0 = room.z1 - t, z1 = room.z1 }
    elseif side == "s" then c = { x0 = a, x1 = b, z0 = room.z0, z1 = room.z0 + t }
    elseif side == "e" then c = { x0 = room.x1 - t, x1 = room.x1, z0 = a, z1 = b }
    else c = { x0 = room.x0, x1 = room.x0 + t, z0 = a, z1 = b } end
    c.y, c.h = room.y, room.h
    out[#out + 1] = c
  end
  for _, g in ipairs(gaps) do
    seg(from, g[1])
    from = g[2]
  end
  seg(from, hi)
end

-- Builds room `room` (with `seed` for its details). Returns { mesh, pos =
-- {x, y, z} (pocket), colliders = { {x0, z0, x1, z1, y, h} } }.
function R.build(room, seed)
  local w, d = room.x1 - room.x0, room.z1 - room.z0
  local cv = Canvas.new(w, d, room.h)
  local st = room.style or {}
  PAL.apply(cv, st.colors)
  local rng = mvl.rng(mvl.hash(seed or 1, room.id))
  local top = cv.H - 2                            -- the highest wall layer
  -- floor and ceiling
  local floor = FLOORS[st.floor or "boards"] or FLOORS.boards
  floor(cv, rng, st.boards)
  if st.glass_roof then
    cv:box(0, 0, cv.H - 1, cv.W - 1, cv.D - 1, cv.H - 1, I.pane)
    for u = 0, cv.W - 1, 8 do cv:box(u, 0, cv.H - 1, u, cv.D - 1, cv.H - 1, I.white) end
    for v = 0, cv.D - 1, 8 do cv:box(0, v, cv.H - 1, cv.W - 1, v, cv.H - 1, I.white) end
  else
    cv:box(0, 0, cv.H - 1, cv.W - 1, cv.D - 1, cv.H - 1, I.ceiling)
  end
  -- walls: the outer layer dark, the inner one finished
  cv:box(0, 0, 1, T - 1, cv.D - 1, top, I.wall_dark)
  cv:box(cv.W - T, 0, 1, cv.W - 1, cv.D - 1, top, I.wall_dark)
  cv:box(0, 0, 1, cv.W - 1, T - 1, top, I.wall_dark)
  cv:box(0, cv.D - T, 1, cv.W - 1, cv.D - 1, top, I.wall_dark)
  local glass = {}
  for _, s in ipairs(st.glass or {}) do glass[s] = true end
  local finish = WALLS[st.wall or "stripes"] or WALLS.stripes
  for _, side in ipairs({ "n", "s", "e", "w" }) do
    local n = wall_len(cv, side)
    if glass[side] then
      draw_glass_wall(cv, side, top)
    else
      finish(cv, side, top, rng)
      if st.dado then
        face(cv, side, 0, n - 1, 1, 7, I.dado)
        for a = 0, n - 1, 6 do face(cv, side, a, a, 2, 6, I.dado2) end
        face(cv, side, 0, n - 1, 8, 8, I.trim)
      end
      if st.rail ~= false and top > 20 then face(cv, side, 0, n - 1, top - 2, top - 2, I.trim) end
      face(cv, side, 0, n - 1, 1, 1, I.trim)      -- skirting
    end
  end
  -- beams across the short side
  if st.beams then
    if cv.W >= cv.D then
      for u = 8, cv.W - 9, 16 do cv:box(u, 0, top, u + 1, cv.D - 1, top, I.beam) end
    else
      for v = 8, cv.D - 9, 16 do cv:box(0, v, top, cv.W - 1, v + 1, top, I.beam) end
    end
  end
  -- openings
  for _, dr in ipairs(room.doors or {}) do draw_door(cv, room, dr) end
  for _, wn in ipairs(room.windows or {}) do draw_window(cv, room, wn) end
  for _, h in ipairs(room.holes or {}) do
    local u0, v0, u1, v1 = rect(cv, room, h)
    cv:clear(u0, v0, 0, u1, v1, 0)
  end
  for _, h in ipairs(room.ceiling_holes or {}) do
    local u0, v0, u1, v1 = rect(cv, room, h)
    cv:clear(u0, v0, cv.H - 1, u1, v1, cv.H - 1)
  end
  for _, s in ipairs(room.stairs or {}) do draw_stairs(cv, room, s) end
  for _, rl in ipairs(room.railings or {}) do draw_railing(cv, room, rl) end
  -- furniture
  local colliders = {}
  for _, side in ipairs({ "n", "s", "e", "w" }) do wall_colliders(room, side, colliders) end
  for _, it0 in ipairs(room.items or {}) do
    local it = {}
    for k, v in pairs(it0) do it[k] = v end
    if it.x then it.x = it.x - room.x0 end
    if it.z then it.z = it.z - room.z0 end
    if it.at then it.at = it.at - ((it.wall == "n" or it.wall == "s") and room.x0 or room.z0) end
    local c = F.place(cv, room, it, seed)
    if c then
      colliders[#colliders + 1] = { x0 = c.x0 + room.x0, z0 = c.z0 + room.z0, x1 = c.x1 + room.x0, z1 = c.z1 + room.z0,
                                    y = room.y + c.y, h = c.h }
    end
  end
  local mesh = cv:mesh()
  local hash = cv.g:hash()
  cv:free()
  return {
    mesh = mesh, hash = hash,
    pos = { (room.x0 + room.x1) / 2, room.y - S, (room.z0 + room.z1) / 2 },
    colliders = colliders,
  }
end

R.WALL = T * S
return R
