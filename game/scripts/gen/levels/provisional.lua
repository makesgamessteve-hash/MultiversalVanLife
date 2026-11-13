-- Multiversal Van Life - provisional planets and settlements (MIT).
--
-- Until the deep generators arrive (geology, climate, life, peoples and
-- history), a planet's style is derived from its temperature, its star and
-- its universe's magic, and every land outside Prime gets a settlement near
-- the landing spot with villagers and one trouble. This module is replaced
-- in phase 20; signals and quests do not depend on how it works.
local dm = require("gen.dmath")
local names = require("gen.names")
local prime = require("gen.prime")

local P = {}

-- Styles: how a world looks, sounds and what its people use. Mods may add
-- styles with gen.cosmos:content("land_styles", {...}).
P.STYLES = {
  temperate = {
    terrain = { amp = 7, freq = 0.007, palette = { { 46, 76, 40 }, { 70, 104, 52 }, { 108, 120, 72 }, { 132, 128, 100 } } },
    texture = "grass", env = { sky_top = { 0.03, 0.05, 0.12 }, sky_horizon = { 0.14, 0.18, 0.3 }, fog = { 0.1, 0.13, 0.22 },
                               ambient = { 0.24, 0.26, 0.34 }, stars = 1 },
    ambient = "sounds/ambient_night.wav", trees = { "tree_oak", "tree_pine" }, tree_count = 4,
    buildings = { "house", "barn", "well" }, tint = { 1, 1, 1, 1 }, npcs = { "npc_farmer", "npc_merchant", "npc_child" },
    folk = "villagers", light = "lantern", glow = "fireflies", part = "gear", keepsake = "book", place = "shelf",
  },
  marsh = {
    terrain = { amp = 3, freq = 0.01, palette = { { 30, 60, 56 }, { 46, 80, 64 }, { 80, 96, 72 }, { 96, 104, 84 } } },
    texture = "grass", env = { sky_top = { 0.03, 0.06, 0.07 }, sky_horizon = { 0.12, 0.2, 0.18 }, fog = { 0.12, 0.2, 0.18 },
                               ambient = { 0.18, 0.26, 0.24 }, stars = 0.3, fog_far = 40 },
    ambient = "sounds/ambient_fen.wav", trees = { "tree_pine", "bush" }, tree_count = 3,
    buildings = { "house", "lantern_post", "well" }, tint = { 0.75, 0.9, 0.85, 1 }, npcs = { "npc_fen_keeper", "npc_child" },
    folk = "marsh-folk", light = "lantern", glow = "fireflies", part = "float", keepsake = "charm", place = "cairn",
  },
  desert = {
    terrain = { amp = 10, freq = 0.006, palette = { { 150, 120, 80 }, { 186, 152, 100 }, { 210, 180, 120 }, { 224, 200, 150 } } },
    texture = "sand", env = { sky_top = { 0.1, 0.06, 0.16 }, sky_horizon = { 0.5, 0.3, 0.3 }, fog = { 0.4, 0.28, 0.26 },
                              ambient = { 0.4, 0.34, 0.3 }, stars = 0.8 },
    ambient = "sounds/ambient_market.wav", trees = { "bush" }, tree_count = 1,
    buildings = { "market_stall", "house", "well" }, tint = { 1.1, 0.95, 0.75, 1 }, npcs = { "npc_merchant", "npc_robot" },
    folk = "caravan folk", light = "beacon", glow = "sun-stones", part = "cog", keepsake = "scroll", place = "niche",
  },
  snow = {
    terrain = { amp = 12, freq = 0.006, palette = { { 150, 160, 176 }, { 190, 200, 214 }, { 220, 228, 236 }, { 244, 248, 252 } } },
    texture = "stone", env = { sky_top = { 0.02, 0.04, 0.1 }, sky_horizon = { 0.2, 0.26, 0.36 }, fog = { 0.3, 0.34, 0.42 },
                               ambient = { 0.34, 0.38, 0.46 }, stars = 1 },
    ambient = "sounds/ambient_night.wav", trees = { "tree_pine" }, tree_count = 3,
    buildings = { "house", "barn", "lantern_post" }, tint = { 0.85, 0.9, 1.05, 1 }, npcs = { "npc_farmer", "npc_librarian" },
    folk = "hill people", light = "brazier", glow = "embers", part = "runner", keepsake = "carving", place = "shrine",
  },
  crystal = {
    terrain = { amp = 8, freq = 0.009, palette = { { 60, 40, 90 }, { 90, 60, 130 }, { 130, 100, 170 }, { 180, 160, 210 } } },
    texture = "crystal", env = { sky_top = { 0.05, 0.02, 0.12 }, sky_horizon = { 0.3, 0.16, 0.4 }, fog = { 0.22, 0.12, 0.3 },
                                 ambient = { 0.36, 0.28, 0.44 }, stars = 1 },
    ambient = "sounds/ambient_library.wav", trees = { "bush", "flowers" }, tree_count = 3,
    buildings = { "bookshelf", "house", "lantern_post" }, tint = { 0.85, 0.75, 1.1, 1 }, npcs = { "npc_librarian", "npc_robot" },
    folk = "glass-singers", light = "prism", glow = "light-shards", part = "lens", keepsake = "tuning fork", place = "plinth",
  },
  fungal = {
    terrain = { amp = 6, freq = 0.008, palette = { { 70, 40, 50 }, { 100, 60, 70 }, { 130, 90, 80 }, { 160, 120, 110 } } },
    texture = "grass", env = { sky_top = { 0.06, 0.02, 0.05 }, sky_horizon = { 0.26, 0.12, 0.2 }, fog = { 0.2, 0.1, 0.16 },
                                ambient = { 0.34, 0.24, 0.3 }, stars = 0.5 },
    ambient = "sounds/ambient_fen.wav", trees = { "bush", "flowers" }, tree_count = 4,
    buildings = { "house", "market_stall", "well" }, tint = { 1.05, 0.8, 0.9, 1 }, npcs = { "npc_fen_keeper", "npc_child" },
    folk = "sporekin", light = "glowcap", glow = "spore-lights", part = "seed-pod", keepsake = "shell", place = "hollow",
  },
}

function P.style(name) return P.STYLES[name] or P.STYLES.temperate end

-- The planet's style from its temperature, star and universe.
local function planet_style(ctx)
  local s = ctx.summary
  local rng = ctx:rng()
  local laws = ctx:ancestor("universe").data.laws
  local star = ctx.parent.data.star
  local t = s.temperature or 280
  local style
  if s.kind == "gas_giant" or s.kind == "ice_giant" then style = rng:chance(0.5) and "crystal" or "snow"
  elseif t < 210 then style = "snow"
  elseif t < 250 then style = rng:chance(0.6) and "snow" or "temperate"
  elseif t <= 320 then style = rng:chance(0.65) and "temperate" or "marsh"
  else style = rng:chance(0.8) and "desert" or "fungal" end
  if laws.magic ~= "none" and rng:chance(laws.magic_strength * 0.4) then style = "crystal" end
  if (star.class == "M" or star.class == "K") and style ~= "snow" and rng:chance(0.2) then style = "fungal" end
  return style
end

-- Name of a land's settlement: depends only on the land's seed and style,
-- so signals can name a land before it is generated.
function P.settlement_name(land_seed) return names.make(mvl.rng(mvl.hash(land_seed, "settlement")), "world") end

function P.register(R)
  R:pass("planet", "provisional", { run = function(ctx)
    if ctx.summary.prime then
      ctx.data.name, ctx.data.prime = ctx.summary.name, true
      return
    end
    ctx.data.name = ctx.summary.name
    ctx.data.style = planet_style(ctx)
  end })

  R:describe("planet", function(node)
    if node.data.prime then return node.data.name .. ", a planet of the Solar System." end
    return string.format("%s, a %s world.", node.data.name, node.data.style)
  end)
end

-- A settlement around a square near the landing spot, its villagers and
-- its trouble (land-local coordinates; the van lands at d.spots.van).
function P.settlement(ctx, d, style_name, height)
  local rng = ctx:rng()
  local style = P.style(style_name)
  d.name = P.settlement_name(ctx.node.seed)
  local vx, vz, vyaw = 0, 14, dm.round(-dm.pi / 2 + rng:float(-0.3, 0.3), 4)
  local sx, sz = dm.round(rng:float(-6, 6), 2), dm.round(rng:float(-22, -14), 2)
  d.spots = { van = { x = vx, z = vz, yaw = vyaw }, square = { x = sx, z = sz } }
  local h0 = height(sx, sz)
  d.flats[#d.flats + 1] = { x = sx, z = sz, radius = 18, falloff = 12, height = dm.round(h0, 3) }
  d.flats[#d.flats + 1] = { x = vx, z = vz, radius = 5, falloff = 8, height = dm.round(height(vx, vz), 3) }
  d.clear = { { x = sx, z = sz, r = 24 }, { x = vx, z = vz, r = 7 } }
  -- buildings around the square, facing it
  local n = rng:int(3, 6)
  local start = rng:next() * 2 * dm.pi
  for i = 1, n do
    local a = start + (i - 1) * 2 * dm.pi / n + rng:float(-0.25, 0.25)
    local r = rng:float(11, 15)
    local bx, bz = dm.round(sx + dm.cos(a) * r, 2), dm.round(sz + dm.sin(a) * r, 2)
    -- skip the side towards the van so the square stays open to it
    local tx, tz = vx - sx, vz - sz
    if (bx - sx) * tx + (bz - sz) * tz < 0.5 * r * math.sqrt(tx * tx + tz * tz) then
      local voxel = style.buildings[rng:int(1, #style.buildings)]
      local b = { id = "building" .. i, role = "building", voxel = voxel, x = bx, z = bz,
                  yaw = dm.round(-a - dm.pi / 2, 4), color = style.tint }
      if voxel == "lantern_post" then b.radius = 0.3 elseif voxel == "well" then b.radius = 0.9 else b.box = { 4.5, 4.5 } end
      d.features[#d.features + 1] = b
    end
  end
  -- villagers: the first one waits between the square and the van
  d.people = {}
  for i = 1, rng:int(2, 4) do
    local px, pz
    if i == 1 then
      px, pz = dm.round(vx + (sx - vx) * 0.45 + rng:float(-2, 2), 2), dm.round(vz + (sz - vz) * 0.45, 2)
    else
      px, pz = dm.round(sx + rng:float(-6, 6), 2), dm.round(sz + rng:float(-6, 6), 2)
    end
    d.people[i] = { id = "person" .. i, name = names.make(ctx:random("person" .. i), "world"),
                    texture = style.npcs[rng:int(1, #style.npcs)], x = px, z = pz,
                    tint = { dm.round(0.8 + rng:next() * 0.3, 3), dm.round(0.8 + rng:next() * 0.3, 3),
                             dm.round(0.8 + rng:next() * 0.3, 3), 1 } }
  end
  -- a lane from the van to the square
  local pts = {}
  for i = 0, 3 do
    local t = i / 3
    local x, z = dm.round(vx + (sx - vx) * t, 2), dm.round(vz + (sz - vz) * t, 2)
    pts[#pts + 1] = { x, z, dm.round(height(x, z), 3) }
  end
  for i = 1, #pts - 1 do
    local a, b = pts[i], pts[i + 1]
    d.flats[#d.flats + 1] = { x = a[1], z = a[2], x2 = b[1], z2 = b[2], radius = 2.1, falloff = 4, height = a[3],
                              height2 = b[3] }
  end
  d.roads[#d.roads + 1] = { name = "the lane", width = 3, texture = style.texture == "sand" and "stone" or "dirt",
                            points = pts }
  d.spots.spawn = { x = vx - 3.6, z = vz, yaw = vyaw }
  d.style_name = style_name
end

return P
