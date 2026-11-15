-- Multiversal Van Life - Juniper's interior (MIT License).
-- The interior is a house in a pocket of the current world's scene, far below
-- the ground, so entering and leaving the van never reloads anything (see
-- lib/house.lua and gen/house/). Its cab and hall windows are portals to the
-- matching windows of the parked van outside, or to the road between worlds
-- while travelling.
local audio = require("lib.audio")
local house = require("lib.house")
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
van.BOUNDS = 4000                 -- the house has walls, not edges

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
  house.build(van.P, 1)
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
  fixed({ x = SP.garden[1], z = SP.garden[2], range = 1.8, prompt = "Open the garden door",
          use = function() van.on_garden() end })
  van.update_windows()
end

-- Callbacks set by the story module.
function van.on_radio() end
function van.on_atlas() end
function van.on_door() end
function van.on_seat() end
function van.on_garden() end

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
end

-- The sky of the road between worlds replaces the world's while travelling;
-- the world's own (kept here) comes back on arrival.
function van.between_sky()
  van.saved_env = mvl.environment_save()
  mvl.environment(van.BETWEEN_ENV)
  mvl.sky(van.BETWEEN_SKY)
end

function van.set_travelling(on)
  if on and not van.travelling then
    van.between_sky()
  elseif not on and van.travelling and van.saved_env then
    mvl.environment_load(van.saved_env)
    van.saved_env = nil
  end
  van.travelling = on
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
  van.inside = true
  player.indoors = true
  player.base_y = van.P[2]
  player.indoor_floor = house.floor
  player.place(van.P[1] + van.ENTRY[1], van.P[3] + van.ENTRY[2], van.ENTRY[3])
  mvl.bounds(van.P[1] - van.BOUNDS, van.P[3] - van.BOUNDS, van.P[1] + van.BOUNDS, van.P[3] + van.BOUNDS)
  audio.scape("van")
end

-- Puts the player outside at (x, z, yaw).
function van.exit(player, world, x, z, yaw)
  van.inside = false
  player.indoors = false
  player.base_y = 0
  player.place(x, z, yaw)
  world.apply_bounds()
  audio.set_ambient(world.ambient())
end

function van.update(dt)
  if not van.built then return end
  local b = van.entities.between
  if van.travelling and b then
    local t = mvl.time()
    -- the road streams past: moved back by one marking every 2 m
    mvl.set_pos(b.road, van.V[1] + 25 - (t * 14) % 2, van.V[2] - 2.5, van.V[3])
  end
end

return van
