-- Multiversal Van Life - first person controller (MIT License).
local util = require("lib.util")
local audio = require("lib.audio")

local player = {
  x = 0, z = 0, yaw = 0, pitch = 0,
  base_y = 0,                       -- floor height (the van pocket lies far below the world)
  ground = nil,                     -- function(x, z) -> terrain height of a streamed land
  indoors = false,                  -- inside the van: the floor is base_y
  eye = 1.6, radius = 0.3,
  wade = 1.0,                       -- deepest sea (below sea level 0) the player walks into
  walk_speed = 3.0, run_speed = 5.0, turn_speed = 2.4,
  bob = 0, step_dist = 0, enabled = true, moved = 0,
}

-- Height of the floor under the player.
function player.floor()
  if player.ground and not player.indoors then return player.ground(player.x, player.z) end
  return player.base_y
end

function player.place(x, z, yaw)
  player.x, player.z, player.yaw, player.pitch = x, z, yaw or 0, 0
  player.step_dist = 0
end

-- Direction the player is facing (includes the VR head yaw).
function player.facing()
  local _, xr_active = mvl.xr()
  if xr_active then
    local hy = mvl.xr_head()
    return player.yaw + hy
  end
  return player.yaw
end

function player.update(dt)
  if player.enabled then
    -- look: mouse / touch deltas plus right stick
    local lx, ly = mvl.look()
    player.yaw = player.yaw - lx - mvl.value("look_x") * player.turn_speed * dt
    player.pitch = util.clamp(player.pitch - ly - mvl.value("look_y") * player.turn_speed * dt, -1.3, 1.3)
    player.yaw = player.yaw + mvl.value("turn") * player.turn_speed * dt

    local mx, my = mvl.value("move_x"), mvl.value("move_y")
    local len = math.sqrt(mx * mx + my * my)
    if len > 1 then mx, my = mx / len, my / len end
    local speed = mvl.down("run") and player.run_speed or player.walk_speed
    local face = player.facing()
    local fx, fz = util.forward(face)
    local rx, rz = util.right(face)
    local dx = (fx * my + rx * mx) * speed * dt
    local dz = (fz * my + rz * mx) * speed * dt
    if dx ~= 0 or dz ~= 0 then
      local ox, oz = player.x, player.z
      local nx, _, nz = mvl.move(player.x, player.floor(), player.z, dx, dz, player.radius)
      -- the sea stops the player once it is deeper than wading depth (but
      -- never stops them walking back out of it)
      if player.ground and not player.indoors then
        local h = player.ground(nx, nz)
        if h < -player.wade and h < player.ground(ox, oz) then nx, nz = ox, oz end
      end
      player.x, player.z = nx, nz
      local d = util.dist2(ox, oz, nx, nz)
      player.moved = player.moved + d
      player.step_dist = player.step_dist + d
      player.bob = player.bob + d * 2.2
      if player.step_dist > 1.6 then
        player.step_dist = 0
        audio.sfx("step", 0.35)
      end
    end
  end
  local bob = math.sin(player.bob * 3.1) * 0.03
  mvl.camera(player.x, player.floor() + player.eye + bob, player.z, player.yaw, player.pitch)
end

return player
