-- Multiversal Van Life - Juniper's interior (MIT License).
-- The interior is a pocket inside the current world's scene, far below the
-- ground, so entering and leaving the van never reloads anything. Its
-- windows are portals to the matching windows of the parked van outside, or
-- to the swirling vortex while travelling.
local audio = require("lib.audio")

local van = {
  P = { 0, -400, 0 },          -- pocket origin (interior floor centre)
  V = { 0, 600, 0 },           -- vortex centre
  built = false, inside = false, travelling = false,
  exterior = nil,              -- { x, z, yaw } of the parked van
  fixed = {},                  -- interactables of the interior (never cleared)
  entities = {},
}

-- Interior windows (local to the pocket) and the exterior windows they look
-- out of (local to the van model: front = +X, left side = +Z).
van.WINDOWS = {
  { pos = { -1.625, 1.6875, 3.875 }, w = 1.5, h = 0.875, yaw = math.pi, ext = { -1.44, 1.75, 1.185 }, ext_yaw = math.pi },
  { pos = { 1.625, 1.4375, 3.875 }, w = 1.75, h = 1.125, yaw = math.pi, ext = { 1.0, 1.75, 1.185 }, ext_yaw = math.pi },
  { pos = { 3.875, 1.3125, 0 }, w = 1.5, h = 1.125, yaw = -math.pi / 2, ext = { 2.435, 1.75, 0 }, ext_yaw = -math.pi / 2 },
  { pos = { 0.0625, 1.3125, -3.875 }, w = 1.125, h = 1.125, yaw = 0, ext = { -0.44, 1.75, -1.185 }, ext_yaw = 0 },
}
van.DOOR = { -3.9, 0 }           -- interior door (local x, z)
van.ENTRY = { -3.2, 0, -math.pi / 2 } -- where the player stands after entering
van.BOUNDS = 3.8

local function local_to_pocket(x, y, z) return van.P[1] + x, van.P[2] + y, van.P[3] + z end

-- Builds the swirling tunnel shown through the windows while travelling.
local function build_vortex()
  local g = mvl.voxels(48, 22, 22)
  local colors = { { 40, 200, 190 }, { 250, 170, 60 }, { 150, 80, 220 }, { 240, 240, 255 }, { 30, 90, 160 }, { 255, 110, 150 } }
  for i, c in ipairs(colors) do g:color(i, c[1], c[2], c[3]) end
  for x = 0, 47 do
    for y = 0, 21 do
      for z = 0, 21 do
        local dy, dz = y - 10.5, z - 10.5
        local r = math.sqrt(dy * dy + dz * dz)
        if r >= 8.5 and r <= 10.5 then
          local a = math.atan(dz, dy)
          local band = math.floor((a / (2 * math.pi) * 6 + x / 6) % 6) + 1
          g:set(x, y, z, band)
        end
      end
    end
  end
  local mesh = g:mesh(1.0)
  g:free()
  local pivot = mvl.spawn({ pos = van.V, persistent = true, visible = false })
  mvl.spawn({ mesh = mesh, pos = { 0, -11, 0 }, parent = pivot, unlit = true, nofog = true, persistent = true })
  return pivot
end

function van.build()
  if van.built then return end
  van.built = true
  local px, py, pz = van.P[1], van.P[2], van.P[3]
  local tint = { 0.95, 0.92, 0.88, 1 }
  van.entities.room = mvl.spawn({ mesh = mvl.mesh("voxels/van_interior.vox", 0.125), pos = { px, py, pz },
                                  unlit = true, nofog = true, persistent = true, color = tint })
  van.entities.ceiling = mvl.spawn({ mesh = mvl.box_mesh(8, 0.1, 8), texture = mvl.texture("textures/metal_panel.tga"),
                                     pos = { px, py + 3.0, pz }, unlit = true, nofog = true, persistent = true, color = tint })
  -- the console blocks walking through it
  van.entities.console = mvl.spawn({ pos = { px, py, pz }, radius = 0.95, solid = true, persistent = true, visible = false })
  van.entities.vortex = build_vortex()
  -- filled in place: the world module holds a reference to this table
  van.fixed[#van.fixed + 1] = { x = px, y = py, z = pz, range = 2.2, prompt = "Use the console",
                                use = function() van.on_console() end }
  van.fixed[#van.fixed + 1] = { x = px + van.DOOR[1], y = py, z = pz + van.DOOR[2], range = 1.6,
                                prompt = "Step outside", use = function() van.on_door() end }
  van.update_windows()
end

-- Callbacks set by the story module.
function van.on_console() end
function van.on_door() end

-- Moves the van exterior (called when a world places the van at ground
-- height y).
function van.set_exterior(x, z, yaw, y)
  van.exterior = { x = x, z = z, yaw = yaw, y = y or 0 }
  van.update_windows()
end

-- Points every window portal at the exterior windows or into the vortex.
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

function van.set_travelling(on)
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
  local def = world.current and world.current.def
  audio.set_ambient(def and def.ambient, def and def.ambient_volume)
end

function van.update(dt)
  if not van.built then return end
  local t = mvl.time()
  mvl.set(van.entities.vortex, { pitch = t * 1.2, yaw = math.sin(t * 0.3) * 0.2 })
  local k = 0.92 + 0.05 * math.sin(t * 2)
  local r, g, b = 0.95 * k, 0.92 * k, 0.88 * k
  if van.travelling then
    local p = 0.75 + 0.35 * math.abs(math.sin(t * 13))
    r, g, b = 0.9 * p, 0.7 * p, 1.0 * p
  end
  mvl.set_color(van.entities.room, r, g, b, 1)
end

return van
