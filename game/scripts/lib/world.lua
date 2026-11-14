-- Multiversal Van Life - world loading, prop helpers and interaction (MIT).
-- A world module is a table: { id, name, ambient, build = function(w) ... end,
-- update = function(w, dt) end }. Generated lands use the "land" world.
local util = require("lib.util")
local changes = require("memory.changes")
local player = require("lib.player")
local audio = require("lib.audio")

local world = { current = nil, interactables = {}, updaters = {}, focus = nil, registry = {}, order = {},
                fixed = {}, inside = function() return false end, anchor = function() return nil end }

-- ---------------------------------------------------------- registry
function world.register(def)
  assert(def.id, "world needs an id")
  if not world.registry[def.id] then world.order[#world.order + 1] = def.id end
  world.registry[def.id] = def
end

function world.get(id) return world.registry[id] end


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

-- Ground height at (x, z): the streamed terrain of a land, else flat 0.
function W:height(x, z) return self.streamer and mvl.height(x, z) or 0 end

-- Turns this world into a generated land streamed in chunks around the
-- player (see gen/chunks.lua). `provider(gx, gz)` returns neighbouring land
-- nodes of the same country. Coordinates are metres around the land's centre.
-- Every change the player makes is kept in the land's change log
-- (w:memory(), memory/changes.lua) and applied whenever chunks are built.
-- The change log of this world's land (or of another land of it).
function W:memory(node) return changes.open((node or self.land_node).address) end

function W:land(node, provider)
  local chunks = require("gen.chunks")
  self.land_node = node
  self.streamer = chunks.new(node, provider or function() return nil end)
  self:bounds(self.streamer:bounds())
  player.ground = function(x, z) return mvl.height(x, z) end
  return self.streamer
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

-- NPC standing on the ground: t = { name, texture, x, z, w, h, tint }.
function W:npc_at(t, talk)
  -- a voxel person of their species and culture where the land knows them
  local model
  if t.body and self.streamer then
    local b = t.body
    model = self.streamer.models:acquire({
      kind = "person", key = "person:" .. self.land_node.address .. ":" .. (b.seed or 0) .. ":" .. tostring(t.name),
      anatomy = b.anatomy, hue = b.hue, dress = b.dress, accent = b.accent })
    if model and model.mesh == 0 then model = nil end
  end
  if model then
    local e = mvl.spawn({ mesh = model.mesh, pos = { t.x, self:height(t.x, t.z), t.z }, yaw = t.yaw or 0,
                          solid = true, radius = 0.35 })
    local it = self:interactable({ x = t.x, z = t.z, entity = e, name = t.name, prompt = "Talk to " .. t.name, use = talk })
    return e, it
  end
  local e, it = self:npc({ texture = t.texture, name = t.name, x = t.x, z = t.z, w = t.w, h = t.h, talk = talk })
  mvl.set_pos(e, t.x, self:height(t.x, t.z), t.z)
  if t.tint then mvl.set_color(e, t.tint[1], t.tint[2], t.tint[3], t.tint[4] or 1) end
  return e, it
end

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
-- `args` are passed to the world's build as w.args (e.g. a land address).
function world.load(id, spawn, args)
  local def = world.registry[id]
  assert(def, "unknown world " .. tostring(id))
  if world.current and world.current.streamer then world.current.streamer:clear() end
  changes.flush_all() -- leaving a place: write what changed there
  player.ground = nil
  mvl.clear_scene()
  world.interactables, world.updaters, world.focus = {}, {}, nil
  mvl.environment({ reset = true })
  for i = 0, 7 do mvl.light(i) end
  local w = setmetatable({ def = def, state = {}, args = args or {} }, W)
  world.current = w
  world.apply_bounds()
  local sx, sz, syaw = def.build(w, spawn)
  if spawn and spawn.x then sx, sz, syaw = spawn.x, spawn.z, spawn.yaw end
  w.spawn = { x = sx or 0, z = sz or 0, yaw = syaw or 0 }
  if w.streamer then
    -- build the surroundings at once: around the player, or the parked van
    local a = world.inside() and world.anchor() or nil
    w.streamer:fill(a and a.x or w.spawn.x, a and a.z or w.spawn.z)
  end
  if not world.inside() then
    player.place(w.spawn.x, w.spawn.z, w.spawn.yaw)
    audio.set_ambient(world.ambient())
  end
  return w
end

-- The current world's soundscape (a world may choose one per place).
function world.ambient()
  local w = world.current
  if not w then return nil end
  return w.ambient or w.def.ambient, w.ambient_volume or w.def.ambient_volume
end

-- Display name of the current place.
function world.place_name()
  local w = world.current
  return w and (w.name or w.def.name) or "?"
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
  if w.streamer then
    -- stream around the player, or around the parked van while inside it
    local a = world.inside() and world.anchor() or nil
    w.streamer:update(a and a.x or player.x, a and a.z or player.z)
    w.streamer.creatures:update(dt, a and a.x or player.x, a and a.z or player.z)
  end
  world.flush_timer = (world.flush_timer or 0) + dt
  if world.flush_timer >= changes.FLUSH_EVERY then
    world.flush_timer = 0
    changes.flush_all()
  end
  if w.def.update then w.def.update(w, dt) end
  for _, fn in ipairs(world.updaters) do fn(dt) end
  world.focus = allow_interact and world.find_focus() or nil
  if world.focus and mvl.pressed("interact") then
    audio.sfx("interact", 0.5)
    world.focus.use(world.focus)
  end
end

return world
