-- Multiversal Van Life - the endless house beyond the core (MIT License).
--
-- The house is a grid of 32 m blocks; block (0, 0) is the hand-planned core
-- (gen/house/plan.lua). Every other block is laid out from its seed by one
-- of a few templates and has a doorway in the middle of each side, so all
-- blocks connect to their neighbours and every room can be reached from
-- the core (each template connects all its rooms to its side doorways).
-- The two blocks touching the core's closed front (the cab) and back (the
-- garden door) keep that side shut.
local kinds = require("gen.house.kinds")

local B = { SIZE = 32, DOOR = 2.0 }
local SZ = B.SIZE

-- house styles of the generated blocks (palette names of gen/house/palette.lua)
B.STYLES = {
  { name = "rose", wall = "stripes", dado = true,
    colors = { wall = { 206, 160, 152 }, wall2 = { 192, 144, 138 }, dado = { 96, 62, 44 }, dado2 = { 80, 50, 36 },
               floor = { 158, 110, 66 }, floor2 = { 142, 98, 58 } } },
  { name = "sage", wall = "panels", dado = false,
    colors = { wall = { 150, 170, 136 }, wall2 = { 134, 154, 120 }, floor = { 176, 136, 90 }, floor2 = { 160, 122, 80 } } },
  { name = "ochre", wall = "plain", dado = true, beams = true,
    colors = { wall = { 222, 186, 112 }, dado = { 140, 80, 50 }, dado2 = { 120, 66, 40 }, floor = { 170, 92, 64 },
               floor2 = { 150, 80, 56 }, floor3 = { 120, 64, 44 } } },
  { name = "navy", wall = "stripes", dado = true,
    colors = { wall = { 70, 86, 130 }, wall2 = { 60, 74, 116 }, dado = { 220, 214, 196 }, dado2 = { 200, 194, 176 },
               floor = { 128, 86, 54 }, floor2 = { 112, 74, 46 } } },
  { name = "cream", wall = "panels", dado = false,
    colors = { wall = { 232, 222, 196 }, wall2 = { 214, 202, 174 }, floor = { 150, 104, 64 }, floor2 = { 136, 92, 56 } } },
  { name = "plum", wall = "stripes", dado = true,
    colors = { wall = { 130, 84, 120 }, wall2 = { 116, 72, 106 }, dado = { 70, 46, 34 }, dado2 = { 58, 38, 28 },
               floor = { 104, 66, 42 }, floor2 = { 92, 58, 36 } } },
  { name = "teal", wall = "panels", dado = true,
    colors = { wall = { 70, 130, 128 }, wall2 = { 60, 114, 112 }, dado = { 112, 76, 48 }, dado2 = { 96, 64, 40 },
               floor = { 186, 150, 104 }, floor2 = { 170, 136, 94 } } },
  { name = "stone", wall = "stone", dado = false, beams = true,
    colors = { wall = { 176, 168, 152 }, wall2 = { 150, 142, 128 }, floor = { 168, 158, 140 }, floor2 = { 150, 140, 124 },
               floor3 = { 110, 104, 94 } } },
}

local ROOM_KINDS = { "bedroom", "bedroom", "bathroom", "sitting", "sitting", "study", "library", "music", "gallery",
                     "store", "linen", "games", "workshop" }
local GRAND_KINDS = { "ballroom", "great_library", "gallery", "winter_garden" }

function B.of(x, z) return math.floor((x + SZ / 2) / SZ), math.floor((z + SZ / 2) / SZ) end
function B.origin(bx, bz) return bx * SZ - SZ / 2, bz * SZ - SZ / 2 end

-- Adds matching doorways to rooms a and b where they share a wall.
local function connect(a, b, rng, w, shape)
  w = w or 1.25
  local function door(r, side, at) r.doors[#r.doors + 1] = { side = side, at = at, w = w, h = shape and 2.5 or 2.25, shape = shape } end
  local function along(lo, hi)
    local a0, a1 = lo + w / 2 + 0.6, hi - w / 2 - 0.6
    if a1 < a0 then return (lo + hi) / 2 end
    return a0 + math.floor(rng:next() * (a1 - a0) * 8) / 8
  end
  if math.abs(a.x1 - b.x0) < 1e-6 or math.abs(b.x1 - a.x0) < 1e-6 then
    local lo, hi = math.max(a.z0, b.z0), math.min(a.z1, b.z1)
    if hi - lo < w + 0.6 then return false end
    local at = along(lo, hi)
    local east = math.abs(a.x1 - b.x0) < 1e-6
    door(a, east and "e" or "w", at)
    door(b, east and "w" or "e", at)
    return true
  end
  if math.abs(a.z1 - b.z0) < 1e-6 or math.abs(b.z1 - a.z0) < 1e-6 then
    local lo, hi = math.max(a.x0, b.x0), math.min(a.x1, b.x1)
    if hi - lo < w + 0.6 then return false end
    local at = along(lo, hi)
    local north = math.abs(a.z1 - b.z0) < 1e-6
    door(a, north and "n" or "s", at)
    door(b, north and "s" or "n", at)
    return true
  end
  return false
end
B.connect = connect

local function room(t, ox, oz, x0, z0, x1, z1)
  t.x0, t.z0, t.x1, t.z1 = ox + x0, oz + z0, ox + x1, oz + z1
  t.doors = t.doors or {}
  t.y = 0
  return t
end

-- a side doorway in the middle of a block side, on the room that touches it
local function side_door(r, side, ox, oz)
  local at = (side == "n" or side == "s") and ox + SZ / 2 or oz + SZ / 2
  r.doors[#r.doors + 1] = { side = side, at = at, w = B.DOOR, h = 2.5, shape = "arch", outer = true }
end

-- --------------------------------------------------------- templates
local T = {}

-- corridors from the side doorways to the middle; rooms in the quarters
function T.cross(ox, oz, rng, out)
  local h = room({ kind = "corridor" }, ox, oz, 0, 14.5, 32, 17.5)
  local vn = room({ kind = "corridor" }, ox, oz, 14.5, 17.5, 17.5, 32)
  local vs = room({ kind = "corridor" }, ox, oz, 14.5, 0, 17.5, 14.5)
  out[#out + 1], out[#out + 2], out[#out + 3] = h, vn, vs
  h.doors[#h.doors + 1] = { side = "n", at = ox + 16, w = 2.5, h = 2.5, shape = "arch" }
  vn.doors[#vn.doors + 1] = { side = "s", at = ox + 16, w = 2.5, h = 2.5, shape = "arch" }
  h.doors[#h.doors + 1] = { side = "s", at = ox + 16, w = 2.5, h = 2.5, shape = "arch" }
  vs.doors[#vs.doors + 1] = { side = "n", at = ox + 16, w = 2.5, h = 2.5, shape = "arch" }
  local sides = { w = h, e = h, n = vn, s = vs }
  local corridors = { h, vn, vs }
  -- the quarters: one, two or three rooms
  for _, q in ipairs({ { 0, 0 }, { 17.5, 0 }, { 0, 17.5 }, { 17.5, 17.5 } }) do
    local qx, qz = q[1], q[2]
    local parts = {}
    local r = rng:next()
    if r < 0.25 then
      parts[1] = { qx, qz, qx + 14.5, qz + 14.5 }
    elseif r < 0.55 then
      if rng:next() < 0.5 then
        parts[1], parts[2] = { qx, qz, qx + 7.25, qz + 14.5 }, { qx + 7.25, qz, qx + 14.5, qz + 14.5 }
      else
        parts[1], parts[2] = { qx, qz, qx + 14.5, qz + 7.25 }, { qx, qz + 7.25, qx + 14.5, qz + 14.5 }
      end
    else
      parts[1] = { qx, qz, qx + 14.5, qz + 7.25 }
      parts[2] = { qx, qz + 7.25, qx + 7.25, qz + 14.5 }
      parts[3] = { qx + 7.25, qz + 7.25, qx + 14.5, qz + 14.5 }
      if rng:next() < 0.5 then
        parts[1] = { qx, qz + 7.25, qx + 14.5, qz + 14.5 }
        parts[2] = { qx, qz, qx + 7.25, qz + 7.25 }
        parts[3] = { qx + 7.25, qz, qx + 14.5, qz + 7.25 }
      end
    end
    local rooms = {}
    for _, p in ipairs(parts) do
      local big = (p[3] - p[1]) * (p[4] - p[2]) > 150
      local k = big and (rng:next() < 0.5 and "library" or (rng:next() < 0.5 and "sitting" or "gallery"))
                or ROOM_KINDS[rng:int(1, #ROOM_KINDS)]
      local rm = room({ kind = k }, ox, oz, p[1], p[2], p[3], p[4])
      rooms[#rooms + 1] = rm
      out[#out + 1] = rm
    end
    -- each room opens onto a corridor, or onto a sibling that does
    local linked = {}
    for i, rm in ipairs(rooms) do
      for _, c in ipairs(corridors) do
        if not linked[i] and connect(rm, c, rng, 1.25) then linked[i] = true end
      end
    end
    for i, rm in ipairs(rooms) do
      if not linked[i] then
        for j, o in ipairs(rooms) do
          if j ~= i and linked[j] and not linked[i] and connect(rm, o, rng, 1.0) then linked[i] = true end
        end
      end
    end
  end
  return sides
end

-- three by three rooms opening into each other
function T.enfilade(ox, oz, rng, out)
  local cuts = { 0, 10.75, 21.25, 32 }
  local grid = {}
  for i = 1, 3 do
    grid[i] = {}
    for j = 1, 3 do
      local k = ROOM_KINDS[rng:int(1, #ROOM_KINDS)]
      if i == 2 and j == 2 then k = rng:next() < 0.5 and "sitting" or "music" end
      local rm = room({ kind = k }, ox, oz, cuts[i], cuts[j], cuts[i + 1], cuts[j + 1])
      grid[i][j] = rm
      out[#out + 1] = rm
    end
  end
  for i = 1, 3 do
    for j = 1, 3 do
      if i < 3 then connect(grid[i][j], grid[i + 1][j], rng, 1.5, "arch") end
      if j < 3 then connect(grid[i][j], grid[i][j + 1], rng, 1.5, "arch") end
    end
  end
  return { w = grid[1][2], e = grid[3][2], s = grid[2][1], n = grid[2][3] }
end

-- a grand room in a ring of corridors
function T.hall(ox, oz, rng, out)
  local n = room({ kind = "corridor" }, ox, oz, 0, 28, 32, 32)
  local s = room({ kind = "corridor" }, ox, oz, 0, 0, 32, 4)
  local w = room({ kind = "corridor" }, ox, oz, 0, 4, 4, 28)
  local e = room({ kind = "corridor" }, ox, oz, 28, 4, 32, 28)
  local grand = room({ kind = GRAND_KINDS[rng:int(1, #GRAND_KINDS)], grand = true }, ox, oz, 4, 4, 28, 28)
  for _, r in ipairs({ n, s, w, e, grand }) do out[#out + 1] = r end
  for _, pair in ipairs({ { w, n }, { w, s }, { e, n }, { e, s } }) do
    local a, b = pair[1], pair[2]
    local at = a.x0 + 2
    local north = math.abs(a.z1 - b.z0) < 1e-6
    a.doors[#a.doors + 1] = { side = north and "n" or "s", at = at, w = 3.0, h = 2.5 }
    b.doors[#b.doors + 1] = { side = north and "s" or "n", at = at, w = 3.0, h = 2.5 }
  end
  for _, c in ipairs({ n, s, w, e }) do
    local horizontal = c == n or c == s
    local at = horizontal and ox + 16 or oz + 16
    local side_c = c == n and "s" or c == s and "n" or c == w and "e" or "w"
    local side_g = c == n and "n" or c == s and "s" or c == w and "w" or "e"
    c.doors[#c.doors + 1] = { side = side_c, at = at, w = 2.5, h = 3.0, shape = "arch" }
    grand.doors[#grand.doors + 1] = { side = side_g, at = at, w = 2.5, h = 3.0, shape = "arch" }
  end
  return { n = n, s = s, w = w, e = e }
end

-- a ring corridor round an indoor courtyard, rooms outside the ring
function T.cloister(ox, oz, rng, out)
  local ring = {
    n = room({ kind = "corridor" }, ox, oz, 6.5, 22.5, 25.5, 25.5),
    s = room({ kind = "corridor" }, ox, oz, 6.5, 6.5, 25.5, 9.5),
    w = room({ kind = "corridor" }, ox, oz, 6.5, 9.5, 9.5, 22.5),
    e = room({ kind = "corridor" }, ox, oz, 22.5, 9.5, 25.5, 22.5),
  }
  local court = room({ kind = "courtyard", grand = true }, ox, oz, 9.5, 9.5, 22.5, 22.5)
  for _, k in ipairs({ "n", "s", "w", "e" }) do out[#out + 1] = ring[k] end
  out[#out + 1] = court
  for _, pair in ipairs({ { ring.w, ring.n }, { ring.w, ring.s }, { ring.e, ring.n }, { ring.e, ring.s } }) do
    local a, b = pair[1], pair[2]
    local north = math.abs(a.z1 - b.z0) < 1e-6
    a.doors[#a.doors + 1] = { side = north and "n" or "s", at = a.x0 + 1.5, w = 2.5, h = 2.5 }
    b.doors[#b.doors + 1] = { side = north and "s" or "n", at = a.x0 + 1.5, w = 2.5, h = 2.5 }
  end
  for k, c in pairs(ring) do
    local horizontal = k == "n" or k == "s"
    local at = horizontal and ox + 16 or oz + 16
    local inward = ({ n = "s", s = "n", w = "e", e = "w" })[k]
    c.doors[#c.doors + 1] = { side = inward, at = at, w = 2.0, h = 2.5, shape = "arch" }
    court.doors[#court.doors + 1] = { side = k, at = at, w = 2.0, h = 2.5, shape = "arch" }
  end
  -- the rooms round the outside: three along each side
  local bands = {
    n = { { 0, 25.5, 10.5, 32 }, { 10.5, 25.5, 21.5, 32 }, { 21.5, 25.5, 32, 32 } },
    s = { { 0, 0, 10.5, 6.5 }, { 10.5, 0, 21.5, 6.5 }, { 21.5, 0, 32, 6.5 } },
    w = { { 0, 6.5, 6.5, 12.5 }, { 0, 12.5, 6.5, 19.5 }, { 0, 19.5, 6.5, 25.5 } },
    e = { { 25.5, 6.5, 32, 12.5 }, { 25.5, 12.5, 32, 19.5 }, { 25.5, 19.5, 32, 25.5 } },
  }
  local sides = {}
  for k, list in pairs(bands) do
    for i, p in ipairs(list) do
      local rm = room({ kind = ROOM_KINDS[rng:int(1, #ROOM_KINDS)] }, ox, oz, p[1], p[2], p[3], p[4])
      out[#out + 1] = rm
      if not connect(rm, ring[k], rng, 1.25) then
        -- the corner rooms of the n and s bands meet the w and e ring strips' ends
        for _, c in pairs(ring) do if connect(rm, c, rng, 1.25) then break end end
      end
      if i == 2 then sides[k] = rm end
    end
  end
  return sides
end

B.TEMPLATES = { "cross", "enfilade", "hall", "cloister" }

local WING_KINDS = { "gallery", "gallery", "sitting", "study", "music" }

-- The rooms of block (bx, bz) for a game of seed `seed` (not the core); a
-- `wing` ({ souvenir, index }, gen/house/wings.lua) makes it the wing of a
-- people visited.
function B.rooms(seed, bx, bz, wing)
  local rng = mvl.rng(mvl.hash(seed, "block", bx, bz))
  local ox, oz = B.origin(bx, bz)
  local template = B.TEMPLATES[rng:int(1, #B.TEMPLATES)]
  if wing then template = wing.index % 2 == 1 and "hall" or "cloister" end
  local out = {}
  local sides = T[template](ox, oz, rng, out)
  -- the side doorways (shut towards the core's front and back)
  for side, r in pairs(sides) do
    local shut = (bz == 0 and bx == 1 and side == "w") or (bz == 0 and bx == -1 and side == "e")
    if not shut then side_door(r, side, ox, oz) end
  end
  -- style, heights, furniture
  local style = B.STYLES[rng:int(1, #B.STYLES)]
  local h = 3.0 + rng:int(0, 4) * 0.125
  local wing_style, door_h, wing_h
  if wing then
    local W = require("gen.house.wings")
    wing_style = W.style(wing.souvenir)
    door_h, wing_h = W.sizes(wing.souvenir)
  end
  for i, r in ipairs(out) do
    r.id = string.format("b%d_%d_%d", bx, bz, i)
    r.block = { bx, bz }
    r.template = template
    if wing then
      if r.grand then
        r.kind = template == "hall" and "wing_hall" or "wing_court"
        local s0 = wing.souvenir
        r.statue = s0.person
        r.sign = { name = s0.name, species = s0.species, planet = s0.planet, land = s0.land, night = s0.night }
      elseif r.kind ~= "corridor" then
        r.kind = WING_KINDS[rng:int(1, #WING_KINDS)]
      end
      r.wing = wing.souvenir.key
    end
    local def = kinds.KINDS[r.kind] or {}
    r.h = r.grand and 6.5 or (def.tall and 4.5 or h)
    local st
    if wing then
      r.h = r.grand and math.max(7.0, wing_h + 2) or wing_h
      st = { wall = wing_style.wall, dado = wing_style.dado, beams = wing_style.beams, floor = wing_style.floor,
             glass_roof = def.glass_roof, colors = wing_style.colors, frieze = wing_style.frieze }
    else
      st = { wall = def.wall_finish or style.wall, dado = style.dado and not def.wall_finish, beams = style.beams,
             floor = def.floor or "boards", glass_roof = def.glass_roof, colors = style.colors, rail = r.h > 3.4 }
      if r.kind == "bathroom" then
        st.colors = { floor = { 236, 236, 232 }, floor2 = { 50, 70, 80 }, wall = { 226, 236, 232 }, wall2 = { 192, 208, 206 } }
      end
    end
    r.style = st
    r.light = r.kind == "store" and { 0.92, 0.9, 0.86 } or { 1, 0.95, 0.87 }
    r.fog = true
  end
  -- doorways of a wing are sized to its people (both sides of each match)
  if wing then
    local lowest = math.huge
    for _, r in ipairs(out) do lowest = math.min(lowest, r.h) end
    for _, r in ipairs(out) do
      for _, d in ipairs(r.doors) do d.h = math.max(d.h, math.min(door_h, lowest - 0.75)) end
    end
  end
  for _, r in ipairs(out) do
    -- the sign stands inside the hall's south doorway
    if r.sign then
      local x = (r.x0 + r.x1) / 2
      r.sign.x, r.sign.z = x + 2.25, r.z0 + 2.0
      r.items = { { piece = "sign", x = r.sign.x, z = r.sign.z, face = "-z" } }
    end
    kinds.furnish(r, mvl.rng(mvl.hash(seed, r.id)))
  end
  return out, template
end

return B
