-- Multiversal Van Life - the model cache (MIT).
--
-- Generated models are keyed by the parameters they are built from (a
-- species' model seed), shared by every instance (a whole herd uses one set
-- of meshes) and counted: each user acquires and releases its model, and
-- the meshes are released as soon as nobody uses them. Building is limited
-- per tick (`budget`) and in total (`max` meshes); a caller that gets
-- nothing back draws the hand-made sprite instead.
local plants = require("gen.visuals.plants")
local creatures = require("gen.visuals.creatures")

local M = {}
local Cache = {}
Cache.__index = Cache

function M.new(opts)
  opts = opts or {}
  return setmetatable({ entries = {}, budget = opts.budget or 6, max = opts.max or 400, built = 0, live = 0,
                        stats = { built = 0, released = 0, shared = 0, refused = 0 } }, Cache)
end

-- Starts a new tick (resets the build budget).
function Cache:tick() self.built = 0 end

local function build(p)
  if p.kind == "building" then
    local mesh, box, hash = require("gen.visuals.buildings").mesh(p.building, p.style, p.seed)
    return { mesh = mesh, box = box, hash = hash, count = mesh > 0 and 1 or 0, meshes = { mesh } }
  end
  if p.kind == "person" or p.kind == "statue" then
    local mesh, hash = require("gen.visuals.people").mesh(p)
    return { mesh = mesh, hash = hash, count = mesh > 0 and 1 or 0, meshes = { mesh } }
  end
  if p.kind == "plant" then
    local mesh, hash = plants.mesh(p)
    return { mesh = mesh, hash = hash, count = mesh > 0 and 1 or 0, meshes = { mesh } }
  end
  local m = creatures.build(p)
  m.meshes = { m.body, m.leg, m.wing, m.tail, m.seg, m.merged }
  return m
end

-- The model for parameters p (with p.key), or nil when over budget.
function Cache:acquire(p)
  local e = self.entries[p.key]
  if e then
    e.refs = e.refs + 1
    self.stats.shared = self.stats.shared + 1
    return e
  end
  if self.built >= self.budget or self.live >= self.max then
    self.stats.refused = self.stats.refused + 1
    return nil
  end
  e = build(p)
  e.key, e.refs = p.key, 1
  self.entries[p.key] = e
  self.built = self.built + 1
  self.live = self.live + e.count
  self.stats.built = self.stats.built + 1
  return e
end

function Cache:release(key)
  local e = self.entries[key]
  if not e then return end
  e.refs = e.refs - 1
  if e.refs > 0 then return end
  for _, m in ipairs(e.meshes) do if m and m > 0 then mvl.release_mesh(m) end end
  self.live = self.live - e.count
  self.entries[key] = nil
  self.stats.released = self.stats.released + 1
end

-- Releases everything (when the land goes away).
function Cache:clear()
  for key, e in pairs(self.entries) do
    e.refs = 1
    self:release(key)
  end
end

function Cache:count()
  local n = 0
  for _ in pairs(self.entries) do n = n + 1 end
  return n, self.live
end

return M
