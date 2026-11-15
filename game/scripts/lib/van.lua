-- Multiversal Van Life - Juniper's interior (MIT License).
-- The interior is a house in a pocket of the current world's scene, far below
-- the ground, so entering and leaving the van never reloads anything (see
-- lib/house.lua and gen/house/). Its cab and hall windows are portals to the
-- matching windows of the parked van outside, or to the road between worlds
-- while travelling.
local audio = require("lib.audio")
local house = require("lib.house")
local garden = require("lib.garden")
local plan = require("gen.house.plan")

local van = {
  P = { 0, -400, 0 },          -- pocket origin (the ground floor of the house)
  V = { 0, 600, 0 },           -- the road between worlds
  built = false, inside = false, travelling = false,
  exterior = nil,              -- { x, z, yaw } of the parked van
  fixed = {},                  -- interactables of the interior (never cleared)
  entities = {},
  house = house,
}

-- Interior windows (pocket metres) and the exterior windows they look out of
-- (local to the van model: front = +X, left side = +Z).
van.WINDOWS = plan.WINDOWS
local SP = plan.SPOTS
van.DOOR = SP.door                -- the door outside (pocket x, z)
van.SEAT = SP.seat                -- the driver's seat in the cab
van.RADIO = SP.radio
van.ATLAS = SP.atlas
van.ENTRY = SP.entry              -- where the player stands after entering
van.BOUNDS = 60000                -- the house and the garden have walls and hedges, not edges
van.garden = garden
-- the garden door: its plane in the conservatory (pocket) and in the
-- garden's back of the house (both look out along -X)
local GD = garden.G.DOOR
van.GARDEN_PORTAL = { 5, 6 }       -- portal numbers (1-based) of the door, both ways

local function local_to_pocket(x, y, z) return van.P[1] + x, van.P[2] + y, van.P[3] + z end

-- ------------------------------------------------- between worlds
-- A night scene above the world seen through the windows while travelling:
-- the sky full of stars and the galaxy's band (the environment is swapped
-- for the trip), a sea of clouds streaming past and a glowing road the van
-- drives along (+X), unlit and without fog.
van.BETWEEN_ENV = {
  sky_top = { 0.02, 0.03, 0.10 }, sky_horizon = { 0.16, 0.30, 0.42 }, fog_color = { 0.14, 0.2, 0.32 },
  fog_near = 150, fog_far = 220, ambient = { 0.5, 0.5, 0.6 }, sun_dir = { -0.3, -1, -0.2 },
  sun_color = { 0.2, 0.2, 0.3 }, stars = 1,
}
van.BETWEEN_SKY = {
  light = { 0.3, 0.6, 0.2 },
  moons = { { dir = { 0.75, 0.32, -0.45 }, color = { 0.95, 0.9, 0.8 }, size = 0.05 } },
  band = { normal = { 0.2, 0.3, 0.93 }, core = { 1, 0.15, 0 }, color = { 0.85, 0.7, 1.0 }, strength = 1.2, width = 0.16 },
}

local function build_between()
  -- the sea of clouds
  local clouds = mvl.texture_gen({ kind = "noise", seed = 77, size = 64, scale = 4, octaves = 4,
                                   colors = { { 70, 64, 120 }, { 150, 140, 200 }, { 230, 220, 245 } } })
  local sea = mvl.spawn({ mesh = mvl.plane_mesh(80, 80, 6, 6, 8), texture = clouds, pos = { van.V[1], van.V[2] - 4, van.V[3] },
                          unlit = true, nofog = true, persistent = true, uv_scroll = { -0.05, 0 } })
  -- the road: dark stones with glowing markings, moved along so it streams past
  local rg = mvl.voxels(240, 9, 2)
  rg:color(1, 40, 38, 54)
  rg:color(2, 255, 214, 120)
  rg:color(3, 140, 220, 255)
  rg:box(0, 0, 0, 239, 8, 0, 1)
  for x = 0, 239, 8 do rg:box(x, 4, 1, x + 3, 4, 1, 2) end
  rg:box(0, 0, 1, 239, 0, 1, 3)
  rg:box(0, 8, 1, 239, 8, 1, 3)
  local road_mesh = rg:mesh(0.25)
  rg:free()
  local road = mvl.spawn({ mesh = road_mesh, pos = { van.V[1] + 25, van.V[2] - 2.5, van.V[3] }, unlit = true, nofog = true,
                           persistent = true })
  return { sea = sea, road = road }
end

function van.build()
  if van.built then return end
  van.built = true
  local px, py, pz = van.P[1], van.P[2], van.P[3]
  house.fixed = van.fixed
  house.build(van.P, require("lib.progress").seed())
  garden.setup(require("lib.progress").seed())
  van.entities.between = build_between()
  -- filled in place: the world module holds a reference to this table
  local function fixed(t)
    t.x, t.y, t.z = px + t.x, py + (t.y or 0), pz + t.z
    van.fixed[#van.fixed + 1] = t
  end
  fixed({ x = SP.radio[1], z = SP.radio[2], range = 1.9, prompt = "Tune the radio", use = function() van.on_radio() end })
  fixed({ x = SP.atlas[1], z = SP.atlas[2], range = 1.5, prompt = "Open the atlas", use = function() van.on_atlas() end })
  fixed({ x = SP.door[1], z = SP.door[2], range = 1.6, prompt = "Step outside", use = function() van.on_door() end })
  fixed({ x = SP.seat[1], z = SP.seat[2], range = 1.5, prompt = "Sit in the driver's seat",
          use = function() van.on_seat() end })
  van.update_windows()
end

-- Callbacks set by the story module.
function van.on_radio() end
function van.on_atlas() end
function van.on_door() end
function van.on_seat() end

-- Moves the van exterior (called when a world places the van at ground
-- height y).
function van.set_exterior(x, z, yaw, y)
  van.exterior = { x = x, z = z, yaw = yaw, y = y or 0 }
  van.update_windows()
end

-- Points every window portal at the exterior windows or onto the road
-- between worlds.
function van.update_windows()
  for i, win in ipairs(van.WINDOWS) do
    local px, py, pz = local_to_pocket(win.pos[1], win.pos[2], win.pos[3])
    local def = { pos = { px, py, pz }, yaw = win.yaw, w = win.w, h = win.h }
    if van.travelling then
      def.target = { van.V[1] + i * 0.3, van.V[2], van.V[3] }
      def.target_yaw = win.yaw
    elseif van.exterior then
      local e = van.exterior
      local c, s = math.cos(e.yaw), math.sin(e.yaw)
      local lx, ly, lz = win.ext[1], win.ext[2], win.ext[3]
      def.target = { e.x + c * lx + s * lz, e.y + ly, e.z - s * lx + c * lz }
      def.target_yaw = e.yaw + win.ext_yaw
    end
    if def.target then mvl.portal(i - 1, def) else mvl.portal(i - 1) end
  end
  -- the garden door, both ways: the conservatory looks out into the garden,
  -- the back of the house in the garden looks into the conservatory
  local hx, hy, hz = local_to_pocket(SP.garden[1], 1.375, SP.garden[2])
  local gy = garden.G.Y + 1.375
  mvl.portal(van.GARDEN_PORTAL[1] - 1, { pos = { hx, hy, hz }, yaw = math.pi / 2, w = 2.25, h = 2.75,
                                         target = { GD.x, gy, GD.z }, target_yaw = math.pi / 2 })
  mvl.portal(van.GARDEN_PORTAL[2] - 1, { pos = { GD.x, gy, GD.z }, yaw = -math.pi / 2, w = 2.0, h = 2.5,
                                         target = { hx, hy, hz }, target_yaw = -math.pi / 2 })
end

-- ------------------------------------------------------ light and sky
-- What the player sees beyond the house follows where they are: the world's
-- sky in the cab and the hall (whose windows look out), a warm dusk deeper
-- in the house (far rooms fade into it), the road between worlds' night
-- while travelling.
-- the garden's own golden afternoon
van.GARDEN_ENV = {
  reset = true, sky_top = { 0.36, 0.56, 0.86 }, sky_horizon = { 0.9, 0.82, 0.64 }, fog_color = { 0.84, 0.8, 0.68 },
  fog_near = 70, fog_far = 240, ambient = { 0.55, 0.55, 0.5 }, sun_dir = { 0.55, -0.55, 0.35 }, sun_color = { 1.0, 0.88, 0.66 },
  stars = 0,
}
van.GARDEN_SKY = {
  sun = { dir = { -0.55, 0.55, -0.35 }, color = { 1, 0.9, 0.7 }, size = 0.035, glow = 0.6 },
  light = { -0.55, 0.55, -0.35 },
  moons = { { dir = { 0.6, 0.35, 0.5 }, color = { 0.9, 0.9, 0.95 }, size = 0.02 } },
}

van.HOUSE_ENV = {
  reset = true, sky_top = { 0.12, 0.08, 0.06 }, sky_horizon = { 0.2, 0.14, 0.1 }, fog_color = { 0.2, 0.14, 0.1 },
  fog_near = 24, fog_far = 46, ambient = { 1, 1, 1 }, sun_dir = { -0.3, -1, -0.2 }, sun_color = { 0.4, 0.38, 0.34 },
  stars = 0,
}

-- The world's own environment, kept when a world has been built.
function van.world_loaded()
  van.world_env = mvl.environment_save()
  van.env = nil
  van.apply_env()
end

function van.apply_env()
  local want = "world"
  if van.travelling then
    want = "between"
  elseif van.inside and (van.zone == "garden" or van.zone == "conservatory") then
    want = "garden"
  elseif van.inside and van.zone == "house" then
    want = "house"
  end
  if want == van.env then return end
  van.env = want
  if want == "between" then
    mvl.environment(van.BETWEEN_ENV)
    mvl.sky(van.BETWEEN_SKY)
  elseif want == "garden" then
    mvl.environment(van.GARDEN_ENV)
    mvl.sky(van.GARDEN_SKY)
  elseif want == "house" then
    mvl.environment(van.HOUSE_ENV)
    mvl.sky({})
  elseif van.world_env then
    mvl.environment_load(van.world_env)
  end
end

function van.set_travelling(on)
  -- the destination needs the room: only the core stays during a trip
  if on then
    house.release_all()
    garden.clear()
  end
  van.travelling = on
  van.apply_env()
  van.update_windows()
end

-- The window portal definitions (for tests and tools).
function van.window_target(i)
  local win = van.WINDOWS[i]
  if van.travelling then return van.V[1] + i * 0.3, van.V[2], van.V[3] end
  if not van.exterior then return nil end
  local e = van.exterior
  local c, s = math.cos(e.yaw), math.sin(e.yaw)
  return e.x + c * win.ext[1] + s * win.ext[3], e.y + win.ext[2], e.z - s * win.ext[1] + c * win.ext[3]
end

-- Puts the player inside. `player` and `world` are passed in to avoid
-- circular module dependencies.
function van.enter(player, world)
  van.build()
  van.player = player
  house.set_seed(require("lib.progress").seed())
  house.set_wings(require("lib.progress").souvenirs())
  garden.setup(require("lib.progress").seed())
  van.inside = true
  van.zone = "front"
  player.indoors = true
  player.base_y = van.P[2]
  player.indoor_floor = house.floor
  player.place(van.P[1] + van.ENTRY[1], van.P[3] + van.ENTRY[2], van.ENTRY[3])
  mvl.bounds(van.P[1] - van.BOUNDS, van.P[3] - van.BOUNDS, van.P[1] + van.BOUNDS, van.P[3] + van.BOUNDS)
  house.fill(van.ENTRY[1], van.ENTRY[2], house.FRONT)
  van.apply_env()
  audio.scape("van")
end

-- Puts the player outside at (x, z, yaw).
function van.exit(player, world, x, z, yaw)
  van.inside = false
  house.release_all()           -- only the core stays while the player is out
  garden.clear()
  van.apply_env()
  player.indoors = false
  player.base_y = 0
  player.place(x, z, yaw)
  world.apply_bounds()
  audio.set_ambient(world.ambient())
end

-- Walking through the garden door: from the conservatory into the garden
-- in front of the back of the house, and back. Keeps the way the player
-- looks.
function van.to_garden(pl)
  local dz = pl.z - (van.P[3] + SP.garden[2])
  local x, z = GD.x - 0.6, GD.z + dz
  local yaw, pitch = pl.yaw, pl.pitch
  house.release_all()
  garden.update(x, z, garden.LOAD, math.huge)
  pl.base_y = garden.height(x, z)
  pl.place(x, z, yaw)
  pl.pitch = pitch
  audio.sfx("door", 0.5)
end

function van.to_house(pl)
  local dz = pl.z - GD.z
  local x, z = van.P[1] + SP.garden[1] + 0.6, van.P[3] + SP.garden[2] + dz
  local yaw, pitch = pl.yaw, pl.pitch
  pl.base_y = van.P[2]
  pl.place(x, z, yaw)
  pl.pitch = pitch
  house.fill(x - van.P[1], z - van.P[3])
  audio.sfx("door", 0.5)
end

function van.update(dt)
  if not van.built then return end
  local pl = van.player
  if van.inside and pl then
    local lx, lz, ly = pl.x - van.P[1], pl.z - van.P[3], (pl.base_y or van.P[2]) - van.P[2]
    local zone = house.zone(lx, lz, ly)
    if zone == "conservatory" and lx < SP.garden[1] + 0.25 and math.abs(lz - SP.garden[2]) < 0.9 then
      van.to_garden(pl)
      zone = "garden"
    elseif zone == "garden" and pl.x > GD.x - 0.05 and math.abs(pl.z - GD.z) < 0.8 then
      van.to_house(pl)
      zone = "conservatory"
    end
    if zone == "garden" then
      garden.update(pl.x, pl.z)
    elseif not van.travelling then
      house.update(lx, lz, 1, zone == "front" and house.FRONT or house.BUILD)
      if zone == "conservatory" then
        garden.update(GD.x - 16, GD.z, garden.NEAR)   -- what the door shows
      elseif garden.count > 0 then
        garden.clear()
      end
    end
    if zone ~= van.zone then
      local was = van.zone
      van.zone = zone
      van.apply_env()
      if zone == "garden" then
        audio.scape("garden")
      elseif was == "garden" then
        audio.scape("van")
      end
    end
  end
  local b = van.entities.between
  if van.travelling and b then
    local t = mvl.time()
    -- the road streams past: moved back by one marking every 2 m
    mvl.set_pos(b.road, van.V[1] + 25 - (t * 14) % 2, van.V[2] - 2.5, van.V[3])
  end
end

return van
