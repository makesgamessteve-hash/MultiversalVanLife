-- Multiversal Van Life - the garden behind the van's conservatory (MIT
-- License).
--
-- The garden is a small world of its own, 1,600 m below the house (y around
-- GARDEN.Y), on its own terrain slot: rolling meadows, woods, orchards and
-- ponds without end, a formal garden of hedges and flower beds by the back
-- of the house, and a path winding away from its door. Everything here is
-- described per 32 m chunk from the game's seed, so a chunk comes back the
-- same; lib/garden.lua builds and streams it.
local G = {
  Y = -2000, WATER = -2001.4, SLOT = 1, CHUNK = 32, CELLS = 16,
  DOOR = { x = 0, z = 0 },                       -- the back door of the house (it faces -X)
  HOUSE = { x0 = 0, x1 = 9, z0 = -15, z1 = 15 }, -- the back of the house, solid
}

-- The garden's terrain (mvl.terrain settings for slot G.SLOT).
function G.terrain(seed)
  return {
    slot = G.SLOT, seed = mvl.hash(seed, "garden") % 1000000, base = G.Y, amp = 7, freq = 0.0045, octaves = 4,
    lacunarity = 2, gain = 0.5, origin_x = 0, origin_z = 0,
    palette = { { 70, 120, 56 }, { 92, 142, 64 }, { 120, 160, 78 }, { 150, 168, 96 } },
    color_low = G.Y - 6, color_high = G.Y + 9, slope_color = { 112, 100, 70 }, slope_start = 0.3, color_noise = 0.12,
    uv_scale = 4,
    -- a level lawn in front of the house and under it
    flats = { { x = -8, z = 0, radius = 18, falloff = 14, height = G.Y }, { x = 4.5, z = 0, radius = 17, falloff = 4, height = G.Y } },
  }
end

-- The winding path from the back door: its z at x (x < 0), and whether a
-- point is on it (with a margin).
function G.path_z(x) return 14 * math.sin(x / 60) + 6 * (math.sin(x / 23 + 1.3) - math.sin(1.3)) end
function G.on_path(x, z, margin)
  return x < 2 and math.abs(z - G.path_z(x)) < 1.4 + (margin or 0)
end

-- What kind of garden a chunk is: "formal" by the house, else a meadow, a
-- wood or an orchard from low noise.
function G.region(seed, cx, cz)
  local x, z = (cx + 0.5) * G.CHUNK, (cz + 0.5) * G.CHUNK
  if x > -56 and math.abs(z) < 48 then return "formal" end
  local n = mvl.noise(x * 0.004, z * 0.004, mvl.hash(seed, "garden-region") % 100000, 2)
  if n > 0.28 then return "wood" end
  if n < -0.28 then return "orchard" end
  return "meadow"
end

-- The things of chunk (cx, cz): { piece, x, z, yaw, scale } (garden pieces
-- of lib/garden.lua) and { sprite, x, z, w, h } (flowers and grass).
function G.chunk(seed, cx, cz)
  local rng = mvl.rng(mvl.hash(seed, "garden", cx, cz))
  local x0, z0 = cx * G.CHUNK, cz * G.CHUNK
  local out = {}
  local region = G.region(seed, cx, cz)
  local function free(x, z, r)
    if G.on_path(x, z, r) then return false end
    if x > G.HOUSE.x0 - 3 - r and x < G.HOUSE.x1 + 3 and z > G.HOUSE.z0 - 3 and z < G.HOUSE.z1 + 3 then return false end
    if x > -12 and x < 0 and math.abs(z) < 4 then return false end -- the way to the door
    for _, o in ipairs(out) do
      if o.piece then
        local dx, dz = o.x - x, o.z - z
        if dx * dx + dz * dz < (r + (o.r or 1)) ^ 2 then return false end
      end
    end
    return true
  end
  local function add(piece, x, z, r, extra)
    if not free(x, z, r) then return end
    local o = { piece = piece, x = x, z = z, r = r, yaw = rng:int(0, 3) * math.pi / 2 }
    for k, v in pairs(extra or {}) do o[k] = v end
    out[#out + 1] = o
    return o
  end
  local function anywhere() return x0 + 1 + rng:next() * (G.CHUNK - 2), z0 + 1 + rng:next() * (G.CHUNK - 2) end
  if region == "formal" then
    -- hedges in a grid, flower beds between them, benches, a bird bath
    for gx = 0, 1 do
      for gz = 0, 1 do
        local x, z = x0 + 8 + gx * 16, z0 + 8 + gz * 16
        if rng:next() < 0.7 then add("flower_bed", x, z, 2.2, { yaw = 0 }) end
        if rng:next() < 0.5 then add("hedge", x - 5, z, 0.8, { yaw = math.pi / 2 }) end
        if rng:next() < 0.5 then add("hedge", x, z - 5, 0.8, { yaw = 0 }) end
      end
    end
    for _ = 1, 2 do
      local x, z = anywhere()
      add(rng:next() < 0.5 and "bench" or "lamp_post", x, z, 1.0)
    end
    if rng:next() < 0.3 then add("bird_bath", x0 + 16, z0 + 16, 1.2) end
    for _ = 1, rng:int(1, 3) do
      local x, z = anywhere()
      add("bush", x, z, 0.9)
    end
  elseif region == "orchard" then
    local ox, oz = rng:next() * 2, rng:next() * 2
    for gx = 0, 3 do
      for gz = 0, 3 do
        if rng:next() < 0.75 then
          add("fruit_tree", x0 + 4 + gx * 8 + ox, z0 + 4 + gz * 8 + oz, 1.4, { scale = 0.85 + rng:next() * 0.3 })
        end
      end
    end
    if rng:next() < 0.4 then
      local x, z = anywhere()
      add("beehive", x, z, 0.8)
    end
  elseif region == "wood" then
    for _ = 1, rng:int(6, 10) do
      local x, z = anywhere()
      add("tree", x, z, 1.6, { scale = 0.8 + rng:next() * 0.6 })
    end
    for _ = 1, rng:int(2, 4) do
      local x, z = anywhere()
      add("bush", x, z, 0.9)
    end
  else
    for _ = 1, rng:int(1, 3) do
      local x, z = anywhere()
      add("tree", x, z, 1.6, { scale = 0.9 + rng:next() * 0.5 })
    end
    for _ = 1, rng:int(1, 4) do
      local x, z = anywhere()
      add("bush", x, z, 0.9)
    end
    if rng:next() < 0.12 then add("gazebo", x0 + 16, z0 + 16, 3.6) end
    if rng:next() < 0.25 then
      local x, z = anywhere()
      add("bench", x, z, 1.0)
    end
  end
  -- flowers and tufts everywhere but the path
  local n = region == "meadow" and rng:int(4, 7) or (region == "wood" and rng:int(0, 2) or rng:int(2, 4))
  for _ = 1, n do
    local x, z = anywhere()
    if not G.on_path(x, z, 0.3) and free(x, z, 0.2) then
      local flower = rng:next() < 0.6
      out[#out + 1] = { sprite = flower and "flowers" or "bush", x = x, z = z, w = flower and 0.7 or 0.9,
                        h = flower and 0.6 or 0.7 }
    end
  end
  return out, region
end

return G
