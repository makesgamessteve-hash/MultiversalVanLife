-- Multiversal Van Life - living creatures in the lands (MIT).
--
-- Every animal a chunk spawns becomes a creature with a small state
-- machine suited to its kind (gen/life/habitats.lua):
--
--   grazer    grazes, wanders near home or its herd leader, flees when the
--             player comes close or runs at it (its herd flees with it)
--   prowler   prowls widely and backs away from the player
--   flyer     circles in the air over its home, darts away when approached
--   burrower  crawls about and burrows into the ground when disturbed
--
-- Near the player (NEAR metres) a creature is its body plus parented parts
-- (legs, wings, tail, segments) that are animated each frame: legs swing in
-- alternating pairs, wings flap, tails and crawler bodies sway. Further away
-- it is a single merged model; without a model (over budget, or an older
-- land) it is its species' sprite. Plants near the player sway gently.
local util = require("lib.util")
local creatures_model = require("gen.visuals.creatures")

local C = { NEAR = 40, SWAY = 30, FLEE = 9, NOTICE = 18 }
local M = {}
M.__index = M

function C.new(streamer, cache)
  return setmetatable({ streamer = streamer, cache = cache, list = {}, time = 0, last = nil,
                        stats = { spawned = 0, dropped = 0, fled = 0 } }, M)
end

local TAU = 2 * math.pi
local function forward(yaw) return -math.sin(yaw), -math.cos(yaw) end

-- --------------------------------------------------------------- bodies
local function destroy_body(cr)
  if cr.root and mvl.exists(cr.root) then mvl.destroy(cr.root) end
  cr.root, cr.parts, cr.mode = nil, nil, nil
end

local function spawn_sprite(cr)
  local sp = cr.sp
  cr.root = mvl.spawn({ kind = "sprite", texture = mvl.texture_recolor("textures/" .. sp.sprite .. ".tga", sp.colors, sp.mode),
                        pos = { cr.x, cr.y, cr.z }, scale = { sp.w * cr.scale, sp.h * cr.scale, 1 } })
  cr.mode = "sprite"
end

local function spawn_far(cr)
  cr.root = mvl.spawn({ mesh = cr.model.merged, pos = { cr.x, cr.y, cr.z }, yaw = cr.yaw,
                        scale = { cr.scale, cr.scale, cr.scale } })
  cr.mode = "far"
end

local function spawn_near(cr)
  local m, plan = cr.model, cr.model.plan
  local s = plan.s
  cr.root = mvl.spawn({ mesh = m.body, pos = { cr.x, cr.y, cr.z }, yaw = cr.yaw, scale = { cr.scale, cr.scale, cr.scale } })
  local parts = { legs = {}, wings = {}, segs = {} }
  for k, h in ipairs(creatures_model.hips(plan)) do
    for side = -1, 1, 2 do
      local e = mvl.spawn({ mesh = m.leg, parent = cr.root, pos = { side * h.x * s, h.z * s, -(h.y - 12) * s },
                            roll = math.pi })
      parts.legs[#parts.legs + 1] = { e = e, offset = (k + (side > 0 and 1 or 0)) % 2 * math.pi + k * 0.4 }
    end
  end
  if m.wing > 0 then
    for side = -1, 1, 2 do
      parts.wings[#parts.wings + 1] = mvl.spawn({ mesh = m.wing, parent = cr.root, pos = { 0, plan.rz * 1.6 * s, 2 * s },
                                                  yaw = side < 0 and math.pi or 0 })
    end
  end
  if m.tail > 0 then
    parts.tail = mvl.spawn({ mesh = m.tail, parent = cr.root, pos = { 0, plan.rz * s, (2 + plan.ry) * s } })
  end
  if m.seg > 0 then
    local prev = cr.root
    for k = 1, plan.segments do
      prev = mvl.spawn({ mesh = m.seg, parent = prev, pos = { 0, 0, (k == 1 and 4 or 2.6) * s } })
      parts.segs[k] = prev
    end
  end
  cr.parts = parts
  cr.mode = "near"
end

-- Height of the body above the ground (legs reach down from the hips).
local function lift(cr)
  if cr.mode ~= "near" then return 0 end
  local plan = cr.model.plan
  if plan.pairs == 0 then return 0 end
  local h = creatures_model.hips(plan)[1]
  return math.max(0, (plan.leg - h.z) * plan.s * cr.scale)
end

-- ---------------------------------------------------------------- spawn
-- A creature of habitat animal `sp` at (x, z), in chunk c, maybe following
-- `leader` (a creature of the same herd).
function M:spawn(sp, x, z, c, leader, rng)
  local cr = {
    sp = sp, b = sp.behaviour or { kind = "grazer", speed = 1 }, x = x, z = z, y = mvl.height(x, z),
    home = { x, z }, yaw = rng:next() * TAU, speed = 0, state = "rest", timer = rng:next() * 3, leader = leader,
    chunk = c, phase = rng:next() * TAU, alt = 0, scale = 0.85 + rng:next() * 0.3, seed = rng:int(1, 1000000),
  }
  if cr.b.kind == "flyer" then cr.alt = 2 + rng:next() * 3 end
  if sp.model and self.cache then cr.model = self.cache:acquire(sp.model) end
  if leader then
    leader.herd = leader.herd or { leader }
    table.insert(leader.herd, cr)
  end
  self.list[#self.list + 1] = cr
  c.creatures = c.creatures or {}
  c.creatures[#c.creatures + 1] = cr
  self.stats.spawned = self.stats.spawned + 1
  self:place(cr)
  return cr
end

-- Removes the creatures of a chunk that goes away.
function M:drop_chunk(c)
  if not c.creatures then return end
  local gone = {}
  for _, cr in ipairs(c.creatures) do
    gone[cr] = true
    destroy_body(cr)
    if cr.model then self.cache:release(cr.model.key) end
    cr.dead = true
    self.stats.dropped = self.stats.dropped + 1
  end
  local keep = {}
  for _, cr in ipairs(self.list) do if not gone[cr] then keep[#keep + 1] = cr end end
  self.list = keep
  c.creatures = nil
end

function M:clear()
  for _, cr in ipairs(self.list) do
    destroy_body(cr)
    if cr.model then self.cache:release(cr.model.key) end
    cr.dead = true
  end
  self.list = {}
end

-- ------------------------------------------------------------ behaviour
local function wander_target(cr, rng_next)
  local base = cr.leader and not cr.leader.dead and { cr.leader.x, cr.leader.z } or cr.home
  local reach = cr.b.kind == "prowler" and 18 or (cr.leader and 4 or 10)
  local a, r = rng_next() * TAU, reach * (0.3 + 0.7 * rng_next())
  return base[1] + math.cos(a) * r, base[2] + math.sin(a) * r
end

local function flee(cr, px, pz, time)
  cr.state, cr.timer = "flee", time
  cr.yaw = util.yaw_towards(px, pz, cr.x, cr.z)
end

function M:think(cr, dt, px, pz, closing)
  local b = cr.b
  local dx, dz = cr.x - px, cr.z - pz
  local d = math.sqrt(dx * dx + dz * dz)
  local r = mvl.rng(cr.seed + math.floor(self.time * 2))
  cr.timer = cr.timer - dt
  if b.kind == "grazer" then
    local scared = d < C.FLEE or (d < C.NOTICE and closing > 2.5)
    if scared and cr.state ~= "flee" then
      self.stats.fled = self.stats.fled + 1
      local herd = (cr.leader and cr.leader.herd) or cr.herd or { cr }
      for _, m in ipairs(herd) do if not m.dead then flee(m, px, pz, 4) end end
      flee(cr, px, pz, 4)
    end
    if cr.state == "flee" then
      if d < C.NOTICE then cr.yaw = util.yaw_towards(px, pz, cr.x, cr.z) + math.sin(self.time * 3 + cr.seed) * 0.3 end
      cr.speed = b.speed * 3
      if cr.timer <= 0 then cr.state, cr.timer = "rest", 1 + r:next() * 2 end
    elseif cr.state == "rest" then
      cr.speed = 0
      if cr.timer <= 0 then
        cr.state, cr.timer = "wander", 3 + r:next() * 4
        cr.tx, cr.tz = wander_target(cr, function() return r:next() end)
      end
    else
      cr.yaw = util.yaw_towards(cr.x, cr.z, cr.tx, cr.tz)
      cr.speed = b.speed
      local tx, tz = cr.tx - cr.x, cr.tz - cr.z
      if cr.timer <= 0 or tx * tx + tz * tz < 1 then cr.state, cr.timer = "rest", 2 + r:next() * 4 end
    end
  elseif b.kind == "prowler" then
    if d < 7 and cr.state ~= "wary" then cr.state, cr.timer = "wary", 2.5 end
    if cr.state == "wary" then
      cr.yaw = util.yaw_towards(px, pz, cr.x, cr.z)
      cr.speed = b.speed * 1.2
      if cr.timer <= 0 then cr.state, cr.timer = "prowl", 4 end
    else
      cr.state = "prowl"
      if cr.timer <= 0 or not cr.tx then
        cr.tx, cr.tz = wander_target(cr, function() return r:next() end)
        cr.timer = 5 + r:next() * 5
      end
      cr.yaw = util.yaw_towards(cr.x, cr.z, cr.tx, cr.tz)
      cr.speed = b.speed * 0.6
    end
  elseif b.kind == "flyer" then
    if d < 6 and cr.state ~= "flee" then flee(cr, px, pz, 3) end
    if cr.state == "flee" then
      cr.speed = b.speed * 3
      cr.alt = math.min(cr.alt + dt * 2, 7)
      if cr.timer <= 0 then cr.state = "fly" end
    else
      cr.state = "fly"
      cr.yaw = cr.yaw + dt * 0.7
      cr.speed = b.speed * 1.4
      local hx, hz = cr.home[1] - cr.x, cr.home[2] - cr.z
      if hx * hx + hz * hz > 144 then cr.yaw = util.yaw_towards(cr.x, cr.z, cr.home[1], cr.home[2]) end
      cr.alt = cr.alt + (3 - cr.alt) * dt * 0.5
    end
  else -- burrower
    if d < 4 and cr.state ~= "burrowed" then cr.state, cr.timer = "burrowed", 5 end
    if cr.state == "burrowed" then
      cr.speed = 0
      cr.alt = math.max(cr.alt - dt * 0.8, -1.5)
      if cr.timer <= 0 then cr.state, cr.timer = "crawl", 3 end
    else
      cr.state = "crawl"
      cr.alt = math.min(cr.alt + dt * 0.8, 0)
      if cr.timer <= 0 or not cr.tx then
        cr.tx, cr.tz = wander_target(cr, function() return r:next() end)
        cr.timer = 4 + r:next() * 4
      end
      cr.yaw = util.yaw_towards(cr.x, cr.z, cr.tx, cr.tz)
      cr.speed = b.speed * 0.35
    end
  end
  return d
end

-- Moves a creature along its heading, never into water.
local function move(cr, dt)
  if cr.speed <= 0 then return end
  local fx, fz = forward(cr.yaw)
  local nx, nz = cr.x + fx * cr.speed * dt, cr.z + fz * cr.speed * dt
  if cr.b.kind ~= "flyer" and mvl.height(nx, nz) < 0.3 then
    cr.yaw = cr.yaw + math.pi
    if cr.state == "wander" or cr.state == "prowl" then cr.timer = 0 end
    return
  end
  cr.x, cr.z = nx, nz
end

-- Puts a creature's body where it stands (switching near and far models).
function M:place(cr, d)
  local want = not cr.model and "sprite" or ((d or 0) < C.NEAR and "near" or "far")
  if cr.mode ~= want then
    destroy_body(cr)
    if want == "sprite" then spawn_sprite(cr) elseif want == "near" then spawn_near(cr) else spawn_far(cr) end
  end
  cr.y = mvl.height(cr.x, cr.z) + cr.alt + lift(cr)
  mvl.set(cr.root, { pos = { cr.x, cr.y, cr.z }, yaw = cr.yaw })
  mvl.set_visible(cr.root, cr.alt > -1.2)
end

-- Animates the parts of a creature near the player.
function M:animate(cr, dt)
  local p = cr.parts
  if not p then return end
  cr.phase = cr.phase + dt * (2 + cr.speed * 4)
  local swing = cr.speed > 0.05 and 0.6 or 0.05
  for _, leg in ipairs(p.legs) do mvl.set(leg.e, { pitch = math.sin(cr.phase + leg.offset) * swing }) end
  local flying = cr.b.kind == "flyer" or (cr.state == "flee" and #p.wings > 0)
  local flap = flying and math.sin(self.time * 11 + cr.seed) * 0.75 or 0.25
  for _, wing in ipairs(p.wings) do mvl.set(wing, { roll = flap }) end
  cr.flap = flap
  if p.tail then mvl.set(p.tail, { yaw = math.sin(self.time * 2.3 + cr.seed) * 0.35 }) end
  for k, seg in ipairs(p.segs) do mvl.set(seg, { yaw = math.sin(cr.phase * 0.8 - k * 0.9) * 0.35 }) end
end

-- One frame: behaviour and movement for all, animation for those nearby,
-- and plants swaying near the player.
function M:update(dt, px, pz)
  self.time = self.time + dt
  -- how fast the player closes in on a creature: the player's own speed
  -- along the line to it
  local vx, vz = 0, 0
  if self.last and dt > 0 then vx, vz = (px - self.last[1]) / dt, (pz - self.last[2]) / dt end
  self.last = { px, pz }
  for _, cr in ipairs(self.list) do
    local dx, dz = cr.x - px, cr.z - pz
    local d = math.sqrt(dx * dx + dz * dz)
    local approach = d > 0.01 and (vx * dx + vz * dz) / d or 0
    d = self:think(cr, dt, px, pz, approach)
    move(cr, dt)
    self:place(cr, d)
    if cr.mode == "near" then self:animate(cr, dt) end
  end
  -- plants sway near the player
  local st = self.streamer
  if st then
    local size = 32
    local pcx, pcz = math.floor(px / size), math.floor(pz / size)
    for dzc = -1, 1 do
      for dxc = -1, 1 do
        local c = st.loaded[pcx + dxc .. "," .. pcz + dzc]
        for _, s in ipairs(c and c.sway or {}) do
          mvl.set(s.e, { roll = math.sin(self.time * 1.3 + s.phase) * s.amp })
        end
      end
    end
  end
end

-- Creatures (for tests and the debug view).
function M:all() return self.list end

return C
