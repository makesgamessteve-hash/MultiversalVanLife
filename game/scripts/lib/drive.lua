-- Multiversal Van Life - driving Juniper around a land (MIT License).
--
-- In a generated land the player can sit in the driver's seat in the cab at
-- the front of the house and drive the van: move forward/back accelerates, brakes
-- and reverses, left/right steers (more at speed), run gives a little more
-- speed. The player stays seated in the interior pocket; the van outside
-- (its model, roof lamp and light, door, window portals and the streaming
-- around it) moves every frame. The body follows the terrain under its
-- wheels, buildings, people and trees stop it and so does deep water. The
-- view is from behind the van or, seated, through the windscreen window
-- (interact switches); back gets up and parks the van, and the land
-- remembers where.
local van = require("lib.van")
local player = require("lib.player")
local dialogue = require("lib.dialogue")
local hud = require("lib.hud")
local audio = require("lib.audio")

local D = {
  active = false, view = "chase", speed = 0,
  ACCEL = 5.0, BRAKE = 12.0, DRAG = 1.4, MAX = 11.0, BOOST = 16.0, REVERSE = 4.0,
  TURN = 1.5,                 -- radians per second at full lock and speed
  RADIUS = 1.3,               -- collision circle of the van
  LENGTH = 3.0, WIDTH = 1.8,  -- wheelbase and track (for following the ground)
  WADE = -0.4,                -- deeper than this below sea level stops the van
  SEAT = { 13.25, 1.0 },      -- the driver's head in the cab (pocket x, z)
  STAND = { 12.5, 0 },        -- where the player stands after getting up
  SEATED_EYE = 1.35,
  orbit = 0, cam = nil,
}

-- Why the van cannot be driven now (nil when it can).
function D.blocked()
  local world = require("lib.world")
  local story = require("lib.story")
  if van.travelling or story.busy then return "We're between worlds! Hold on, we'll land soon." end
  local w = world.current
  if not w or not w.def or w.def.id ~= "land" or not van.exterior or not w.streamer then
    return "We're home. I'd rather stay parked by the farm; your neighbour's fences are very close."
  end
  return nil
end

local function land_bounds()
  local w = require("lib.world").current
  return w and w.bounds_rect or { -60, -60, 60, 60 }
end

local function pocket_bounds()
  mvl.bounds(van.P[1] - van.BOUNDS, van.P[3] - van.BOUNDS, van.P[1] + van.BOUNDS, van.P[3] + van.BOUNDS)
end

-- Sits down at the wheel (the seat's interactable).
function D.sit()
  local why = D.blocked()
  if why then
    dialogue.say({ speaker = "juniper", text = why })
    return false
  end
  local story = require("lib.story")
  D.active, D.speed, D.orbit, D.cam = true, 0, 0, nil
  local _, xr_active = mvl.xr()
  D.view = xr_active and "cab" or "chase"
  -- the van's own body must not block it
  if story.van_parts and story.van_parts.model then mvl.set(story.van_parts.model, { solid = false }) end
  player.place(van.P[1] + D.SEAT[1], van.P[3] + D.SEAT[2], -math.pi / 2)
  audio.sfx("door", 0.4)
  hud.notify(mvl.touch() and "Stick: drive - USE: view - X: get up" or "W/S: drive - A/D: steer - E: view - Backspace: get up")
  return true
end

-- Forgets the driving state (a new session or another world).
function D.reset()
  D.active, D.speed, D.cam, D.orbit = false, 0, nil, 0
end

-- Gets up and parks the van where it is; the land remembers the place.
function D.stand()
  if not D.active then return end
  local story = require("lib.story")
  local world = require("lib.world")
  D.active, D.speed = false, 0
  if story.van_parts and story.van_parts.model then mvl.set(story.van_parts.model, { solid = true }) end
  pocket_bounds()
  player.place(van.P[1] + D.STAND[1], van.P[3] + D.STAND[2], -math.pi / 2)
  local w = world.current
  if w and w.land_node and van.exterior then
    local log = w:memory()
    local e = van.exterior
    log.van = { x = math.floor(e.x * 100 + 0.5) / 100, z = math.floor(e.z * 100 + 0.5) / 100,
                yaw = math.floor(e.yaw * 10000 + 0.5) / 10000 }
    log.dirty = true
  end
  audio.sfx("door", 0.4)
end

-- The ground under the van's wheels: height at the centre, nose and side
-- tilts (radians).
local function ground(x, z, yaw)
  local c, s = math.cos(yaw), math.sin(yaw)
  local hl, hw = D.LENGTH / 2, D.WIDTH / 2
  local function h(fx, fz) return mvl.height(x + c * fx + s * fz, z - s * fx + c * fz) end
  local front, back = (h(hl, -hw) + h(hl, hw)) / 2, (h(-hl, -hw) + h(-hl, hw)) / 2
  local left, right = (h(-hl, hw) + h(hl, hw)) / 2, (h(-hl, -hw) + h(hl, -hw)) / 2
  local y = math.max(mvl.height(x, z), (front + back) / 2)
  return y, math.atan(front - back, D.LENGTH), -math.atan(left - right, D.WIDTH)
end
D.ground = ground

-- One step of driving with throttle (-1..1), steering (-1 left .. 1 right)
-- and boost; moves the van and returns how far it went.
function D.step(dt, throttle, steer, boost)
  local story = require("lib.story")
  local e = van.exterior
  local top = boost and D.BOOST or D.MAX
  local v = D.speed
  if throttle > 0.05 then
    v = v + (v < 0 and D.BRAKE or D.ACCEL) * throttle * dt
  elseif throttle < -0.05 then
    v = v + (v > 0 and D.BRAKE or D.ACCEL) * throttle * dt
  else
    local drag = D.DRAG * dt * (v > 0 and 1 or -1)
    v = math.abs(drag) >= math.abs(v) and 0 or v - drag
  end
  v = math.max(-D.REVERSE, math.min(top, v))
  -- steering turns more with speed (and the other way round in reverse)
  local turn = math.max(-1, math.min(1, v / 3)) * D.TURN
  local yaw = e.yaw - steer * turn * dt
  local c, s = math.cos(yaw), math.sin(yaw)
  local dx, dz = c * v * dt, -s * v * dt
  -- move against the land's solids within the land's bounds
  local b = land_bounds()
  mvl.bounds(b[1], b[2], b[3], b[4])
  local nx, _, nz = mvl.move(e.x, e.y + 0.6, e.z, dx, dz, D.RADIUS)
  pocket_bounds()
  -- deep water stops the van
  if mvl.height(nx, nz) < D.WADE and mvl.height(nx, nz) < mvl.height(e.x, e.z) then nx, nz = e.x, e.z end
  local moved = math.sqrt((nx - e.x) ^ 2 + (nz - e.z) ^ 2)
  local wanted = math.abs(v * dt)
  if wanted > 1e-4 and moved < wanted * 0.4 then
    -- bumped into something
    if math.abs(v) > 3 then audio.sfx("door", math.min(0.6, math.abs(v) / 15)) end
    v = v * 0.2
  end
  D.speed = v
  local y, nose, side = ground(nx, nz, yaw)
  story.move_van(nx, nz, yaw, y, nose, side)
  return moved
end

-- The view: behind the van (orbiting with look) or seated at the wheel.
local function camera(dt)
  local e = van.exterior
  local lx, ly = mvl.look()
  if D.view == "chase" then
    D.orbit = D.orbit - lx - mvl.value("look_x") * 2 * dt
    D.orbit = D.orbit * (1 - math.min(1, dt * 0.6)) -- drifts back behind the van
    local yaw = e.yaw + D.orbit
    local c, s = math.cos(yaw), math.sin(yaw)
    local tx, tz = e.x - c * 8, e.z + s * 8
    local ty = math.max(mvl.height(tx, tz) + 1.5, e.y + 3.4)
    local cam = D.cam
    if not cam then cam = { x = tx, y = ty, z = tz } end
    local k = math.min(1, dt * 6)
    cam.x, cam.y, cam.z = cam.x + (tx - cam.x) * k, cam.y + (ty - cam.y) * k, cam.z + (tz - cam.z) * k
    D.cam = cam
    -- look at the van's roof
    local ax, az = e.x - cam.x, e.z - cam.z
    local cy = math.atan(-ax, -az)
    local pitch = math.atan(e.y + 1.6 - cam.y, math.sqrt(ax * ax + az * az))
    mvl.camera(cam.x, cam.y, cam.z, cy, pitch)
  else
    D.cam = nil
    player.yaw = math.max(-math.pi / 2 - 1.2, math.min(-math.pi / 2 + 1.2, player.yaw - lx - mvl.value("look_x") * 2 * dt))
    player.pitch = math.max(-0.8, math.min(0.6, player.pitch - ly - mvl.value("look_y") * 2 * dt))
    mvl.camera(player.x, van.P[2] + D.SEATED_EYE, player.z, player.yaw, player.pitch)
  end
end

-- Every frame while driving (after the player module set its camera).
function D.update(dt)
  if not D.active then return end
  if mvl.pressed("back") then D.stand() return end
  if mvl.pressed("interact") then
    D.view = D.view == "chase" and "cab" or "chase"
    audio.sfx("ui_move", 0.5)
  end
  if D.blocked() then D.stand() return end
  D.step(dt, mvl.value("move_y"), mvl.value("move_x"), mvl.down("run"))
  camera(dt)
end

return D
