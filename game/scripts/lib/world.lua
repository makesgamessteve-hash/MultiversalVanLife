-- Multiversal Van Life - world loading, prop helpers and interaction (MIT).
-- A world module is a table: { id, name, description, destination, order,
-- ambient, build = function(w) ... end, update = function(w, dt) end }.
local util = require("lib.util")
local player = require("lib.player")
local audio = require("lib.audio")

local world = { current = nil, interactables = {}, updaters = {}, focus = nil, registry = {}, order = {},
                fixed = {}, inside = function() return false end }

-- ---------------------------------------------------------- registry
function world.register(def)
  assert(def.id, "world needs an id")
  if not world.registry[def.id] then world.order[#world.order + 1] = def.id end
  world.registry[def.id] = def
end

function world.get(id) return world.registry[id] end

function world.destinations()
  local list = {}
  for _, id in ipairs(world.order) do
    local def = world.registry[id]
    if def.destination then list[#list + 1] = def end
  end
  table.sort(list, function(a, b) return (a.order or 99) < (b.order or 99) end)
  return list
end

-- ----------------------------------------------------------- helpers
local W = {}
W.__index = W

local function resolve_mesh(t)
  if t.voxel then return mvl.mesh("voxels/" .. t.voxel .. ".vox", t.voxel_size or 0.125) end
  if t.model then return mvl.mesh("models/" .. t.model .. ".obj") end
  return t.mesh or 0
end

local function tex(name) return name and mvl.texture("textures/" .. name .. ".tga") or 0 end

-- Static mesh prop. Options: voxel|model|mesh, texture, x, y, z, yaw,
-- scale (number or {x,y,z}), box = {w, d} or radius (makes it solid).
function W:prop(t)
  local s = t.scale or 1
  if type(s) == "number" then s = { s, s, s } end
  local solid = t.box ~= nil or t.radius ~= nil
  return mvl.spawn({
    mesh = resolve_mesh(t), texture = tex(t.texture), pos = { t.x or 0, t.y or 0, t.z or 0 },
    yaw = t.yaw or 0, scale = s, solid = solid, box = t.box, radius = t.radius,
    color = t.color, unlit = t.unlit, nofog = t.nofog, uv_scroll = t.uv_scroll,
    decal = t.decal, layer = t.layer,
  })
end

-- Billboard sprite. Options: texture, x, y, z, w, h, radius, unlit, color.
function W:sprite(t)
  return mvl.spawn({
    kind = "sprite", texture = tex(t.texture), pos = { t.x or 0, t.y or 0, t.z or 0 },
    scale = { t.w or 1, t.h or 1, 1 }, solid = t.radius ~= nil, radius = t.radius,
    unlit = t.unlit, nofog = t.nofog, color = t.color,
  })
end

-- Large surfaces are tessellated (4 m cells): retro vertex snapping would
-- otherwise bend huge triangles and make decals on them flicker.
function W:ground(texture, size, tiles, y)
  local seg = math.max(1, math.floor(size / 4))
  return mvl.spawn({ mesh = mvl.plane_mesh(size, size, tiles, tiles, seg), texture = tex(texture), pos = { 0, y or 0, 0 } })
end

-- Scatters sprites with a deterministic random generator.
function W:scatter(t)
  local seed = t.seed or 1
  local function rnd()
    seed = (seed * 1103515245 + 12345) % 2147483648
    return seed / 2147483648
  end
  local out = {}
  for i = 1, t.count do
    local a, r = rnd() * math.pi * 2, t.min_r + rnd() * (t.max_r - t.min_r)
    local x, z = (t.cx or 0) + math.cos(a) * r, (t.cz or 0) + math.sin(a) * r
    local sc = 0.8 + rnd() * 0.5
    out[i] = self:sprite({ texture = t.texture, x = x, z = z, w = t.w * sc, h = t.h * sc, radius = t.radius })
  end
  return out
end

function W:light(i, x, y, z, r, g, b, range) mvl.light(i, x, y, z, r, g, b, range) end
function W:env(t) mvl.environment(t) end
-- Walkable area of the world (applied unless the player is inside the van).
function W:bounds(x0, z0, x1, z1)
  self.bounds_rect = { x0, z0, x1, z1 }
  world.apply_bounds()
end

function world.apply_bounds()
  local w = world.current
  if world.inside() or not w then return end
  local b = w.bounds_rect or { -60, -60, 60, 60 }
  mvl.bounds(b[1], b[2], b[3], b[4])
end

-- Something the player can use. t = { x, z, name, prompt, range, use = fn,
-- entity = handle (optional, its position is followed), enabled = fn }
function W:interactable(t)
  t.range = t.range or 2.2
  world.interactables[#world.interactables + 1] = t
  return t
end

function W:remove_interactable(t)
  for i, it in ipairs(world.interactables) do
    if it == t then table.remove(world.interactables, i) return end
  end
end

function W:on_update(fn) world.updaters[#world.updaters + 1] = fn end

-- NPC: a sprite with a talk interaction.
function W:npc(t)
  local e = self:sprite({ texture = t.texture, x = t.x, z = t.z, w = t.w or 0.8, h = t.h or 1.7, radius = 0.35 })
  local it = self:interactable({ x = t.x, z = t.z, entity = e, name = t.name, prompt = "Talk to " .. t.name, use = t.talk })
  return e, it
end

-- --------------------------------------------------------- lifecycle
-- Builds a world around the player. Persistent entities (the van interior)
-- survive. While the player is inside the van they stay where they are and
-- hear the van, not the world.
function world.load(id, spawn)
  local def = world.registry[id]
  assert(def, "unknown world " .. tostring(id))
  mvl.clear_scene()
  world.interactables, world.updaters, world.focus = {}, {}, nil
  mvl.environment({ reset = true })
  for i = 0, 7 do mvl.light(i) end
  local w = setmetatable({ def = def, state = {} }, W)
  world.current = w
  world.apply_bounds()
  local sx, sz, syaw = def.build(w, spawn)
  if spawn and spawn.x then sx, sz, syaw = spawn.x, spawn.z, spawn.yaw end
  w.spawn = { x = sx or 0, z = sz or 0, yaw = syaw or 0 }
  if not world.inside() then
    player.place(w.spawn.x, w.spawn.z, w.spawn.yaw)
    audio.set_ambient(def.ambient, def.ambient_volume)
  end
  return w
end

local function it_pos(it)
  if it.entity and mvl.exists(it.entity) then
    local x, _, z = mvl.get_pos(it.entity)
    return x, z
  end
  return it.x, it.z
end

-- Finds the interactable in front of the player.
function world.find_focus()
  local best, best_score = nil, -1
  local face = player.facing()
  local fx, fz = util.forward(face)
  local lists = { world.interactables, world.fixed }
  for _, list in ipairs(lists) do
  for _, it in ipairs(list) do
    -- only things on the player's level (the van pocket lies far below)
    if (not it.enabled or it.enabled()) and math.abs((it.y or 0) - (player.base_y or 0)) < 3 then
      local x, z = it_pos(it)
      local dx, dz = x - player.x, z - player.z
      local d = math.sqrt(dx * dx + dz * dz)
      if d <= it.range then
        local dot = d > 0.01 and (dx * fx + dz * fz) / d or 1
        local score = dot - d * 0.1
        if dot > 0.45 and score > best_score then best, best_score = it, score end
      end
    end
  end
  end
  return best
end

function world.update(dt, allow_interact)
  local w = world.current
  if not w then return end
  if w.def.update then w.def.update(w, dt) end
  for _, fn in ipairs(world.updaters) do fn(dt) end
  world.focus = allow_interact and world.find_focus() or nil
  if world.focus and mvl.pressed("interact") then
    audio.sfx("interact", 0.5)
    world.focus.use(world.focus)
  end
end

return world
