-- Multiversal Van Life - the house inside the van at run time (MIT License).
--
-- Builds the rooms of the plan (gen/house/plan.lua) as persistent entities
-- of the pocket (one mesh per room, invisible solid colliders with heights
-- for its walls, stairs and furniture), keeps their floors and answers the
-- floor under the player: the highest floor at most a step above their
-- feet, so walking up the stairs lifts them to the landing.
local plan = require("gen.house.plan")
local rooms = require("gen.house.rooms")

local house = {
  P = nil,             -- pocket origin (world)
  built = {},          -- room id -> { entity, colliders = {...}, mesh }
  floors = {},         -- { x0, z0, x1, z1, y, holes = {...} } (pocket metres)
  ramps = {},          -- { x0, z0, x1, z1, y, rise } rising towards +X
  rooms = {},          -- room id -> room
  STEP = 0.55,
  seed = 1,
}

local function spawn_collider(P, c)
  local w, d = c.x1 - c.x0, c.z1 - c.z0
  return mvl.spawn({ pos = { P[1] + (c.x0 + c.x1) / 2, P[2] + c.y, P[3] + (c.z0 + c.z1) / 2 }, box = { w, d },
                     height = c.h, solid = true, visible = false, persistent = true })
end

-- Extra colliders of a flight of stairs: the cupboard under it (blocks the
-- floor at its foot only), the banister along its open side (blocks
-- everyone on the flight and on the floor above) and the railing at the
-- top's low end.
local function stair_colliders(st)
  local out = {}
  local run = st.x1 - st.x0
  -- (it starts where the flight is higher than its top for a player's radius)
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
  local rec = { colliders = {}, mesh = b.mesh }
  if b.mesh and b.mesh > 0 then
    local l = room.light or { 1, 1, 1 }
    rec.entity = mvl.spawn({ mesh = b.mesh, pos = { P[1] + b.pos[1], P[2] + b.pos[2], P[3] + b.pos[3] },
                             unlit = true, nofog = true, persistent = true, snap = false,
                             color = { l[1], l[2], l[3], 1 } })
  end
  for _, c in ipairs(b.colliders) do rec.colliders[#rec.colliders + 1] = spawn_collider(P, c) end
  for _, st in ipairs(room.stairs or {}) do
    if room.y <= st.y + 0.01 then
      for _, c in ipairs(stair_colliders(st)) do rec.colliders[#rec.colliders + 1] = spawn_collider(P, c) end
      house.ramps[#house.ramps + 1] = { x0 = st.x0, z0 = st.z0, x1 = st.x1, z1 = st.z1, y = st.y, rise = st.rise }
    end
  end
  house.floors[#house.floors + 1] = { x0 = room.x0, z0 = room.z0, x1 = room.x1, z1 = room.z1, y = room.y,
                                      holes = room.holes, id = room.id }
  house.rooms[room.id] = room
  house.built[room.id] = rec
  return rec
end

-- Builds the house at pocket origin P (the core, every room at once).
function house.build(P, seed)
  house.P = P
  house.seed = seed or 1
  for _, room in ipairs(plan.core()) do house.build_room(room) end
end

local function inside(r, x, z) return x >= r.x0 and x <= r.x1 and z >= r.z0 and z <= r.z1 end

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
  for _, f in ipairs(house.floors) do
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

-- The room the point (pocket metres) is in, on the floor nearest y.
function house.room_at(x, z, y)
  local best, bd
  for id, room in pairs(house.rooms) do
    if inside(room, x, z) and y >= room.y - 0.6 then
      local d = y - room.y
      if not bd or d < bd then best, bd = room, d end
    end
  end
  return best
end

-- Number of entities of the house (rooms and colliders).
function house.entity_count()
  local n = 0
  for _, rec in pairs(house.built) do n = n + (rec.entity and 1 or 0) + #rec.colliders end
  return n
end

return house
