-- Multiversal Van Life - the house inside the van at run time (MIT License).
--
-- Builds the rooms of the plan (gen/house/plan.lua, gen/house/blocks.lua) as
-- persistent entities of the pocket: one mesh per room and invisible solid
-- colliders with heights for its walls, stairs and furniture. The core is
-- always built; the endless house beyond it is built room by room near the
-- player (nearest first, one per update) and released behind them. The
-- floor under the player is the highest floor at most a step above their
-- feet, so walking up the stairs lifts them to the landing.
local plan = require("gen.house.plan")
local rooms = require("gen.house.rooms")

local house = {
  P = nil,             -- pocket origin (world)
  seed = 1,            -- the game's seed (the endless house depends on it)
  built = {},          -- room id -> { entity, colliders = {...}, mesh, room }
  ramps = {},          -- { x0, z0, x1, z1, y, rise } rising towards +X
  STEP = 0.55,
  BUILD = 36,          -- rooms within this distance (m) are built ...
  DROP = 48,           -- ... and released beyond this one
  core = {},           -- ids of the core's rooms (never released)
  front = { cab = true, hall = true }, -- rooms that look out of the van's windows
  fixed = {},          -- where the house's interactables go (the van's, see lib/van.lua)
  on_sign = function() end, -- reading a wing's sign (set by the story)
}

local function spawn_collider(P, c)
  local w, d = c.x1 - c.x0, c.z1 - c.z0
  return mvl.spawn({ pos = { P[1] + (c.x0 + c.x1) / 2, P[2] + c.y, P[3] + (c.z0 + c.z1) / 2 }, box = { w, d },
                     height = c.h, solid = true, visible = false, persistent = true })
end

-- Extra colliders of a flight of stairs: the cupboard under it (blocks the
-- floor at its foot only, where the flight is higher than its top for a
-- player's radius), the banister along its open side (blocks everyone on
-- the flight and on the floor above) and the railing at the top's low end.
local function stair_colliders(st)
  local out = {}
  local run = st.x1 - st.x0
  out[#out + 1] = { x0 = st.x0 + run * 0.21, x1 = st.x1, z0 = st.z0, z1 = st.z1, y = st.y, h = 0.4 }
  local zb = st.open == "n" and st.z1 or st.z0 - 0.125
  out[#out + 1] = { x0 = st.x0 + run * 0.12, x1 = st.x1, z0 = zb, z1 = zb + 0.125, y = st.y + 0.5, h = st.rise + 0.6 }
  out[#out + 1] = { x0 = st.x0 - 0.125, x1 = st.x0, z0 = st.z0, z1 = st.z1, y = st.y + st.rise, h = 1.0 }
  return out
end

-- Builds one room (once).
function house.build_room(room)
  if house.built[room.id] then return house.built[room.id] end
  local P = house.P
  local b = rooms.build(room, house.seed)
  local rec = { colliders = {}, mesh = b.mesh, room = room }
  if b.mesh and b.mesh > 0 then
    local l = room.light or { 1, 1, 1 }
    rec.entity = mvl.spawn({ mesh = b.mesh, pos = { P[1] + b.pos[1], P[2] + b.pos[2], P[3] + b.pos[3] },
                             unlit = true, nofog = not room.fog, persistent = true, snap = false,
                             color = { l[1], l[2], l[3], 1 } })
  end
  for _, c in ipairs(b.colliders) do rec.colliders[#rec.colliders + 1] = spawn_collider(P, c) end
  for _, st in ipairs(room.stairs or {}) do
    if room.y <= st.y + 0.01 then
      for _, c in ipairs(stair_colliders(st)) do rec.colliders[#rec.colliders + 1] = spawn_collider(P, c) end
    end
  end
  local cx, cz = (room.x0 + room.x1) / 2, (room.z0 + room.z1) / 2
  -- a wing's statue of one of its people, in stone of the wing's colours
  if room.statue and room.statue.anatomy then
    local c = room.style and room.style.colors or {}
    local mesh = require("gen.visuals.people").mesh({ anatomy = room.statue.anatomy, statue = true,
      stone = { c.wall_dark or { 110, 104, 96 }, c.wall or { 150, 144, 134 }, c.ceiling or { 200, 196, 186 } } })
    if mesh and mesh > 0 then
      rec.statue_mesh = mesh
      rec.statue = mvl.spawn({ mesh = mesh, pos = { P[1] + cx, P[2] + room.y, P[3] + cz }, unlit = true,
                               nofog = not room.fog, persistent = true, snap = false, color = { 1, 0.96, 0.9, 1 } })
      rec.colliders[#rec.colliders + 1] = spawn_collider(P, { x0 = cx - 0.8, x1 = cx + 0.8, z0 = cz - 0.65, z1 = cz + 0.65,
                                                              y = room.y, h = 3 })
    end
  end
  -- a wing's sign
  if room.sign then
    local it = { x = P[1] + room.sign.x, y = P[2] + room.y, z = P[3] + room.sign.z, range = 1.8,
                 prompt = "Read the sign", use = function() house.on_sign(room.sign) end }
    house.fixed[#house.fixed + 1] = it
    rec.interactable = it
  end
  house.built[room.id] = rec
  return rec
end

-- Releases a built room (its mesh and colliders).
function house.release_room(id)
  local rec = house.built[id]
  if not rec or house.core[id] then return end
  if rec.entity then mvl.destroy(rec.entity) end
  for _, c in ipairs(rec.colliders) do mvl.destroy(c) end
  if rec.mesh and rec.mesh > 0 then mvl.release_mesh(rec.mesh) end
  if rec.statue then mvl.destroy(rec.statue) end
  if rec.statue_mesh then mvl.release_mesh(rec.statue_mesh) end
  if rec.interactable then
    for i, it in ipairs(house.fixed) do
      if it == rec.interactable then table.remove(house.fixed, i) break end
    end
  end
  house.built[id] = nil
end

-- Builds the house at pocket origin P: the core, every room at once.
function house.build(P, seed)
  house.P = P
  house.seed = seed or 1
  house.ramps = {}
  for _, room in ipairs(plan.core()) do
    house.core[room.id] = true
    house.build_room(room)
    for _, st in ipairs(room.stairs or {}) do
      if room.y <= st.y + 0.01 then
        house.ramps[#house.ramps + 1] = { x0 = st.x0, z0 = st.z0, x1 = st.x1, z1 = st.z1, y = st.y, rise = st.rise }
      end
    end
  end
end

-- Releases every room but the core's (the player has left the van).
function house.release_all()
  local ids = {}
  for id in pairs(house.built) do if not house.core[id] then ids[#ids + 1] = id end end
  for _, id in ipairs(ids) do house.release_room(id) end
end

-- The wings of the peoples visited (souvenirs in the order of the visits):
-- blocks that change are planned again and their built rooms released.
function house.set_wings(list)
  local changed = {}
  for _, k in ipairs(plan.set_wings(list)) do changed[k] = true end
  local ids = {}
  for id, rec in pairs(house.built) do
    local b = rec.room.block
    if b and changed[b[1] .. "," .. b[2]] then ids[#ids + 1] = id end
  end
  for _, id in ipairs(ids) do house.release_room(id) end
  return changed
end

-- A new game: the endless house of another seed.
function house.set_seed(seed)
  if seed == house.seed then return end
  house.release_all()
  house.seed = seed
end

local function inside(r, x, z) return x >= r.x0 and x <= r.x1 and z >= r.z0 and z <= r.z1 end

-- the rooms of the block a point (pocket metres) is in
local function block_rooms(x, z)
  local bx, bz = plan.block_of(x, z)
  return plan.block(house.seed, bx, bz)
end

-- The floor height (pocket metres) under (x, z) for feet at height y.
function house.floor_local(x, z, y)
  local best, below
  local function try(h)
    if h <= y + house.STEP then
      if not best or h > best then best = h end
    elseif not below or h < below then
      below = h
    end
  end
  for _, f in ipairs(block_rooms(x, z)) do
    if inside(f, x, z) then
      local hole = false
      for _, h in ipairs(f.holes or {}) do if x > h.x0 and x < h.x1 and z > h.z0 and z < h.z1 then hole = true end end
      if not hole then try(f.y) end
    end
  end
  for _, r in ipairs(house.ramps) do
    if inside(r, x, z) then try(r.y + r.rise * math.max(0, math.min(1, (x - r.x0) / (r.x1 - r.x0)))) end
  end
  return best or below or y
end

-- The same in world coordinates.
function house.floor(x, z, y)
  local P = house.P
  return P[2] + house.floor_local(x - P[1], z - P[3], y - P[2])
end

-- The room a point (pocket metres) is in, on the floor nearest y.
function house.room_at(x, z, y)
  local best, bd
  for _, room in ipairs(block_rooms(x, z)) do
    if inside(room, x, z) and y >= room.y - 0.6 then
      local d = y - room.y
      if not bd or d < bd then best, bd = room, d end
    end
  end
  return best
end

-- Where the player is: "front" (the cab and the hall, which look out of the
-- van) or "house".
function house.zone(x, z, y)
  local r = house.room_at(x, z, y)
  return (r and house.front[r.id]) and "front" or "house"
end

local function dist(r, x, z)
  local dx = math.max(r.x0 - x, 0, x - r.x1)
  local dz = math.max(r.z0 - z, 0, z - r.z1)
  return math.sqrt(dx * dx + dz * dz)
end

-- The rooms within r metres of (x, z) (pocket metres), nearest first.
function house.rooms_near(x, z, r)
  local out = {}
  local bx0, bz0 = plan.block_of(x - r, z - r)
  local bx1, bz1 = plan.block_of(x + r, z + r)
  for bx = bx0, bx1 do
    for bz = bz0, bz1 do
      for _, room in ipairs(plan.block(house.seed, bx, bz)) do
        local d = dist(room, x, z)
        if d <= r then out[#out + 1] = { room = room, d = d } end
      end
    end
  end
  table.sort(out, function(a, b)
    if a.d ~= b.d then return a.d < b.d end
    return a.room.id < b.room.id
  end)
  return out
end

-- Every update while the player is inside: builds the nearest missing room
-- (up to `budget` rooms) and releases rooms far behind. Coordinates are
-- pocket metres.
function house.update(x, z, budget)
  local far = {}
  for id, rec in pairs(house.built) do
    if not house.core[id] and dist(rec.room, x, z) > house.DROP then far[#far + 1] = id end
  end
  for _, id in ipairs(far) do house.release_room(id) end
  local n = 0
  for _, e in ipairs(house.rooms_near(x, z, house.BUILD)) do
    if not house.built[e.room.id] then
      house.build_room(e.room)
      n = n + 1
      if n >= (budget or 1) then break end
    end
  end
  return n
end

-- Builds everything near (x, z) at once (entering the van, tests).
function house.fill(x, z) return house.update(x, z, math.huge) end

-- Number of entities of the house (rooms and colliders) and of built rooms.
function house.entity_count()
  local n, r = 0, 0
  for _, rec in pairs(house.built) do
    n = n + (rec.entity and 1 or 0) + (rec.statue and 1 or 0) + #rec.colliders
    r = r + 1
  end
  return n, r
end

return house
