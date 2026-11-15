-- Multiversal Van Life - kinds of rooms and how they are furnished (MIT
-- License).
--
-- `kinds.furnish(room, rng)` fills `room.items` for the room's kind: pieces
-- against the walls (never in front of a doorway, so every doorway stays
-- reachable), pieces in the middle of large rooms (with room to walk round
-- them) and lamps on the ceiling. Recipes list pieces with options, a
-- chance and how many; mods can add kinds to `kinds.KINDS`.
local F = require("gen.house.furniture")

local K = { KINDS = {} }
local S = 0.125

local function kind(name, t) K.KINDS[name] = t end

-- ------------------------------------------------------------- recipes
-- wall = { {piece, opts, chance, count} }, middle = function(room, add, rng)
kind("bedroom", {
  floor = "boards", tall = false,
  wall = { { "bed", {}, 1, 1, first = true }, { "nightstand", {}, 0.9, 2 }, { "wardrobe", { w = 1.25 }, 0.9, 1 },
           { "dresser", {}, 0.7, 1 }, { "armchair", {}, 0.5, 1 }, { "plant", { small = true, flowers = true }, 0.6, 1 },
           { "painting", { y = 1.375 }, 0.8, 2 }, { "chest", {}, 0.3, 1 } },
  middle = function(room, add) add({ piece = "rug", w = math.min(3.5, room.w - 3), d = math.min(3, room.d - 3) }) end,
})
kind("bathroom", {
  floor = "tiles", wall_finish = "tiles",
  wall = { { "bath", { face_along = true }, 1, 1, first = true }, { "basin", {}, 1, 1 }, { "mirror", { y = 1.125, w = 0.625, h = 0.75 }, 1, 1 },
           { "toilet", {}, 0.9, 1 }, { "towel_rail", { y = 0.5 }, 0.8, 1 }, { "plant", { small = true }, 0.5, 1 } },
  middle = function(room, add) add({ piece = "rug", w = 1.25, d = 0.75 }) end,
})
kind("sitting", {
  floor = "boards",
  wall = { { "fireplace", {}, 0.4, 1, first = true }, { "sofa", { w = 2.25 }, 0.9, 1 }, { "bookshelf", { w = 2.0, h = 2.0 }, 0.7, 2 },
           { "floor_lamp", {}, 0.8, 2 }, { "plant", {}, 0.8, 2 }, { "painting", { y = 1.375 }, 0.9, 3 }, { "cabinet", { w = 1.0 }, 0.3, 1 },
           { "clock", {}, 0.3, 1 } },
  middle = function(room, add)
    if room.w >= 6 and room.d >= 6 then
      add({ piece = "rug", w = room.w * 0.5, d = room.d * 0.5 })
      add({ piece = "table", w = 1.0, d = 0.75, low = true })
      add({ piece = "armchair", dx = -1.5, face = "+x" })
      add({ piece = "armchair", dx = 1.5, face = "-x" })
    end
  end,
})
kind("study", {
  floor = "boards",
  wall = { { "desk", { w = 1.5 }, 1, 1, first = true }, { "bookshelf", { w = 2.5, h = 2.5 }, 1, 3 }, { "globe", {}, 0.6, 1 },
           { "armchair", {}, 0.7, 1 }, { "floor_lamp", {}, 0.7, 1 }, { "painting", { y = 1.375 }, 0.6, 1 } },
  middle = function(room, add) if room.w >= 5 and room.d >= 5 then add({ piece = "rug", w = 3, d = 2.5 }) end end,
})
kind("library", {
  floor = "boards", tall = true,
  wall = { { "bookshelf", { w = 3.0, h = 3.0 }, 1, 8 }, { "ladder", { h = 2.75, gap = 0.375 }, 0.6, 1, after = "bookshelf" },
           { "armchair", {}, 0.6, 2 } },
  middle = function(room, add)
    if room.w >= 6 and room.d >= 6 then
      add({ piece = "rug", w = room.w * 0.55, d = room.d * 0.55 })
      add({ piece = "table", w = 2.0, d = 1.0, candles = true })
      add({ piece = "chair", dz = -0.95, face = "+z" })
      add({ piece = "chair", dz = 0.95, face = "-z" })
    end
  end,
  ceiling = "chandelier",
})
kind("music", {
  floor = "boards",
  wall = { { "piano", {}, 1, 1, first = true }, { "stool", {}, 0.6, 1 }, { "sofa", { w = 2.0 }, 0.7, 1 },
           { "painting", { y = 1.5 }, 0.9, 3 }, { "plant", {}, 0.7, 2 }, { "chair", {}, 0.6, 3 } },
  middle = function(room, add) if room.w >= 6 and room.d >= 6 then add({ piece = "rug", w = 4, d = 3 }) end end,
  ceiling = "chandelier",
})
kind("gallery", {
  floor = "boards",
  wall = { { "painting", { y = 1.25, w = 1.25, h = 1.0 }, 1, 8 }, { "bust", {}, 0.7, 2 }, { "plant", { small = true }, 0.5, 2 } },
  middle = function(room, add)
    if room.w >= 6 and room.d >= 6 then
      add({ piece = "bench", w = 1.5, face = room.w > room.d and "-z" or "+x" })
    end
  end,
})
kind("store", {
  floor = "flags",
  wall = { { "pantry", { w = 2.0, h = 2.25 }, 1, 3 }, { "chest", {}, 0.9, 3 }, { "wardrobe", { w = 1.25 }, 0.5, 1 },
           { "cabinet", { w = 1.0 }, 0.5, 1 } },
})
kind("linen", {
  floor = "carpet",
  wall = { { "wardrobe", { w = 1.5 }, 1, 3 }, { "chest", {}, 0.8, 2 }, { "dresser", {}, 0.5, 1 } },
})
kind("games", {
  floor = "carpet",
  wall = { { "pantry", { w = 1.5, h = 2.0 }, 0.8, 1 }, { "armchair", {}, 0.8, 2 }, { "globe", {}, 0.5, 1 },
           { "painting", { y = 1.375 }, 0.8, 2 }, { "floor_lamp", {}, 0.6, 1 } },
  middle = function(room, add)
    if room.w >= 5 and room.d >= 5 then
      add({ piece = "rug", w = 3.5, d = 3.5 })
      add({ piece = "table", w = 1.0, d = 1.0, cloth = "green" })
      for _, o in ipairs({ { 0, -0.9, "+z" }, { 0, 0.9, "-z" }, { -0.9, 0, "+x" }, { 0.9, 0, "-x" } }) do
        add({ piece = "chair", dx = o[1], dz = o[2], face = o[3] })
      end
    end
  end,
})
kind("workshop", {
  floor = "flags",
  wall = { { "counter", { w = 3.0, things = true, top = "wood_light" }, 1, 2 }, { "pantry", { w = 1.5, h = 2.0 }, 0.8, 2 },
           { "stool", {}, 0.8, 2 }, { "chest", {}, 0.6, 2 } },
})
kind("corridor", {
  floor = "boards", narrow = true,
  wall = { { "painting", { y = 1.375, w = 0.875, h = 0.75 }, 0.9, 6 }, { "plant", { small = true, flowers = true }, 0.4, 2 },
           { "bust", {}, 0.25, 1 } },
  middle = function(room, add)
    local long = math.max(room.w, room.d)
    if long > 5 then
      add({ piece = "rug", w = room.w > room.d and long - 2 or 1.25, d = room.w > room.d and 1.25 or long - 2 })
    end
  end,
  ceiling = "pendant",
})
kind("ballroom", {
  floor = "boards", tall = true,
  wall = { { "piano", {}, 1, 1, first = true }, { "chair", {}, 1, 10 }, { "plant", {}, 0.9, 4 },
           { "painting", { y = 2.0, w = 2.0, h = 1.5 }, 0.9, 4 }, { "clock", {}, 0.5, 1 } },
  ceiling = "chandelier", lamps = 4,
})
kind("great_library", {
  floor = "boards", tall = true,
  wall = { { "bookshelf", { w = 4.0, h = 5.0 }, 1, 12 }, { "ladder", { h = 4.5, gap = 0.375 }, 1, 2, after = "bookshelf" } },
  middle = function(room, add)
    -- rows of shelves back to back, and tables between them
    for k = -1, 1, 2 do
      add({ piece = "bookshelf", w = room.w * 0.45, h = 2.5, dz = k * 3.5, face = "-z", deep = true })
      add({ piece = "bookshelf", w = room.w * 0.45, h = 2.5, dz = k * 3.5 + 0.5, face = "+z", deep = true })
    end
    add({ piece = "rug", w = room.w * 0.5, d = 4 })
    add({ piece = "table", w = 3.0, d = 1.25, candles = true })
  end,
  ceiling = "chandelier", lamps = 4,
})
kind("winter_garden", {
  floor = "tiles", glass_roof = true, tall = true,
  wall = { { "plant", {}, 1, 14 }, { "wicker_chair", {}, 0.9, 3 }, { "bench", { w = 1.5 }, 0.8, 2 } },
  middle = function(room, add)
    add({ piece = "fountain" })
    for _, o in ipairs({ { -3.5, -3.5 }, { 3.5, -3.5 }, { -3.5, 3.5 }, { 3.5, 3.5 } }) do
      add({ piece = "plant", dx = o[1], dz = o[2], flowers = true })
    end
  end,
})
kind("courtyard", {
  floor = "flags", glass_roof = true, tall = true,
  wall = { { "plant", {}, 1, 10 }, { "bench", { w = 1.5 }, 0.9, 4 } },
  middle = function(room, add) add({ piece = "fountain" }) end,
})

-- ----------------------------------------------------------- placing
local function piece_size(name, opts)
  local W, D = F.PIECES[name].size(opts)
  return W * S, D * S
end

-- free stretches of a wall (metres from the room's corner along it), keeping
-- a metre and a bit clear in front of every doorway
local function free_spans(room, side)
  local horizontal = side == "n" or side == "s"
  local base = horizontal and room.x0 or room.z0
  local len = horizontal and (room.x1 - room.x0) or (room.z1 - room.z0)
  local blocked = {}
  for _, d in ipairs(room.doors or {}) do
    if d.side == side then blocked[#blocked + 1] = { d.at - base - d.w / 2 - 0.7, d.at - base + d.w / 2 + 0.7 } end
  end
  table.sort(blocked, function(a, b) return a[1] < b[1] end)
  local spans, from = {}, 0.4
  for _, b in ipairs(blocked) do
    if b[1] - from > 0.4 then spans[#spans + 1] = { from, b[1] } end
    from = math.max(from, b[2])
  end
  if len - 0.4 - from > 0.4 then spans[#spans + 1] = { from, len - 0.4 } end
  return spans, base
end

-- Fills room.items (pocket metres) for its kind.
function K.furnish(room, rng)
  local def = K.KINDS[room.kind] or K.KINDS.sitting
  local items = room.items or {}
  room.items = items
  local w, d = room.x1 - room.x0, room.z1 - room.z0
  -- the walls' free stretches, largest first; doorways on adjacent walls
  -- also keep the corners next to them free
  local walls = {}
  for _, side in ipairs({ "n", "s", "e", "w" }) do
    local spans, base = free_spans(room, side)
    for _, sp in ipairs(spans) do walls[#walls + 1] = { side = side, a = sp[1], b = sp[2], base = base } end
  end
  -- the way in through every doorway stays clear: no solid piece in front of it
  local zones = {}
  for _, dr in ipairs(room.doors or {}) do
    local lo, hi = dr.at - dr.w / 2 - 0.45, dr.at + dr.w / 2 + 0.45
    if dr.side == "n" then zones[#zones + 1] = { lo, room.z1 - 1.6, hi, room.z1 }
    elseif dr.side == "s" then zones[#zones + 1] = { lo, room.z0, hi, room.z0 + 1.6 }
    elseif dr.side == "e" then zones[#zones + 1] = { room.x1 - 1.6, lo, room.x1, hi }
    else zones[#zones + 1] = { room.x0, lo, room.x0 + 1.6, hi } end
  end
  local function clear(x0, z0, x1, z1)
    for _, zn in ipairs(zones) do
      if x0 < zn[3] and x1 > zn[1] and z0 < zn[4] and z1 > zn[2] then return false end
    end
    return true
  end
  -- the footprint (pocket metres) of a piece pw wide and pd deep against a wall
  local function footprint(side, base, at, pw, pd)
    local t = 0.25
    if side == "n" then return base + at - pw / 2, room.z1 - t - pd, base + at + pw / 2, room.z1 - t
    elseif side == "s" then return base + at - pw / 2, room.z0 + t, base + at + pw / 2, room.z0 + t + pd
    elseif side == "e" then return room.x1 - t - pd, base + at - pw / 2, room.x1 - t, base + at + pw / 2
    else return room.x0 + t, base + at - pw / 2, room.x0 + t + pd, base + at + pw / 2 end
  end
  local depth_limit = math.min(w, d) * (def.narrow and 0.2 or 0.3)
  local placed_middle = {}
  local function try_wall(name, opts)
    local pw, pd = piece_size(name, opts)
    if opts.face_along then pw, pd = pd, pw end
    if pd > depth_limit and name ~= "bed" and name ~= "bath" then return false end
    -- a bed or a bath needs a deep enough room
    if pd > math.min(w, d) * 0.45 then return false end
    local solid = F.PIECES[name].solid
    local order = {}
    for i = 1, #walls do order[i] = i end
    for i = #order, 2, -1 do
      local j = rng:int(1, i)
      order[i], order[j] = order[j], order[i]
    end
    for _, i in ipairs(order) do
      local wl = walls[i]
      -- clear of the corners: pieces deeper than the side walls' margins
      local a0, b0 = wl.a + (pd > 0.6 and 0.3 or 0), wl.b - (pd > 0.6 and 0.3 or 0)
      local at
      for _ = 1, 6 do
        if b0 - a0 < pw then break end
        local c = a0 + pw / 2 + rng:next() * (b0 - a0 - pw)
        if not solid or clear(footprint(wl.side, wl.base, c, pw, pd)) then
          at = c
          break
        end
      end
      if at then
        local it = { piece = name, wall = wl.side, at = wl.base + at }
        for k, v in pairs(opts) do if k ~= "face_along" then it[k] = v end end
        if opts.face_along then it.face = (wl.side == "n" or wl.side == "s") and "+x" or "+z" end
        items[#items + 1] = it
        -- split the stretch around the piece (wall-hung pieces leave room below
        -- only for other wall-hung ones: keep it simple and take the space)
        local left, right = { side = wl.side, a = wl.a, b = at - pw / 2 - 0.15, base = wl.base },
                            { side = wl.side, a = at + pw / 2 + 0.15, b = wl.b, base = wl.base }
        table.remove(walls, i)
        if left.b - left.a > 0.4 then walls[#walls + 1] = left end
        if right.b - right.a > 0.4 then walls[#walls + 1] = right end
        return true
      end
    end
    return false
  end
  for _, r in ipairs(def.wall or {}) do
    local name, opts, chance, count = r[1], r[2], r[3], r[4]
    for _ = 1, count do
      if rng:next() < chance then try_wall(name, opts) end
    end
  end
  -- the middle of the room
  if def.middle then
    local cx, cz = (room.x0 + room.x1) / 2, (room.z0 + room.z1) / 2
    def.middle({ w = w, d = d }, function(it)
      it.x = cx + (it.dx or 0)
      it.z = cz + (it.dz or 0)
      it.dx, it.dz = nil, nil
      items[#items + 1] = it
      placed_middle[#placed_middle + 1] = it
    end, rng)
  end
  -- lamps
  local lamp = def.ceiling or "pendant"
  local n = def.lamps or (math.max(w, d) > 10 and 2 or 1)
  for k = 1, n do
    local t = (k - 0.5) / n
    local x, z
    if n == 4 then
      x = room.x0 + w * ((k - 1) % 2 == 0 and 0.3 or 0.7)
      z = room.z0 + d * (k <= 2 and 0.3 or 0.7)
    elseif w >= d then
      x, z = room.x0 + w * t, room.z0 + d / 2
    else
      x, z = room.x0 + w / 2, room.z0 + d * t
    end
    items[#items + 1] = { piece = lamp, x = x, z = z, ceiling = true }
  end
  return items
end

return K
