-- Multiversal Van Life - every change to a place is remembered (MIT).
--
-- Each land has a change log, records/changes/<address>, holding:
--   objects[id] = overrides of a land object (hidden/taken, x/y/z/yaw,
--                 sprite/texture/color/unlit, state = "lit"/"open"/...,
--                 and any custom fields scripts set)
--   placed[id]  = objects the player put into the world (dropped items,
--                 things built), with their own ids "placed/<n>"
--   quest       = the land's quest progress
-- Chunks apply the log whenever they are built. Writes are buffered and
-- flushed when leaving a land, at the end of the night, on saving and every
-- 30 seconds.
local changes = { logs = {}, FLUSH_EVERY = 30 }

local Log = {}
Log.__index = Log

function changes.record(addr) return "changes/" .. addr end

-- The change log of a land (loaded once, then kept in memory).
function changes.open(addr)
  local log = changes.logs[addr]
  if log then return log end
  local rec = mvl.record_read(changes.record(addr)) or {}
  log = setmetatable({ address = addr, objects = rec.objects or {}, placed = rec.placed or {}, quest = rec.quest,
                       next_id = rec.next_id or 1, dirty = false }, Log)
  changes.logs[addr] = log
  return log
end

-- Overrides of an object (nil if unchanged).
function Log:get(id) return self.objects[id] end

-- Merges fields into an object's overrides.
function Log:set(id, fields)
  local o = self.objects[id]
  if not o then o = {} self.objects[id] = o end
  for k, v in pairs(fields) do o[k] = v end
  self.dirty = true
  return o
end

-- Removes an object for good (taken, destroyed).
function Log:take(id) return self:set(id, { taken = true }) end

function Log:taken(id)
  local o = self.objects[id]
  return o ~= nil and (o.taken or o.hidden) == true
end

-- Puts a new object into the land; returns its id.
function Log:place(obj)
  local id = "placed/" .. self.next_id
  self.next_id = self.next_id + 1
  obj.id = id
  self.placed[id] = obj
  self.dirty = true
  return id
end

function Log:unplace(id)
  self.placed[id] = nil
  self.dirty = true
end

-- Placed objects as a sorted list.
function Log:placed_list()
  local out = {}
  for _, o in pairs(self.placed) do out[#out + 1] = o end
  table.sort(out, function(a, b) return tonumber(a.id:match("%d+$")) < tonumber(b.id:match("%d+$")) end)
  return out
end

function Log:set_quest(q)
  self.quest = q
  self.dirty = true
end

function Log:flush()
  if not self.dirty then return false end
  mvl.record_write(changes.record(self.address), { objects = self.objects, placed = self.placed, quest = self.quest,
                                                   next_id = self.next_id })
  self.dirty = false
  return true
end

-- Writes every log with unsaved changes. Returns how many were written.
function changes.flush_all()
  local n = 0
  for _, log in pairs(changes.logs) do if log:flush() then n = n + 1 end end
  return n
end

-- Drops unsaved changes (a new journey starts from an empty save).
function changes.discard() changes.logs = {} end

-- Forgets the logs in memory (after flushing); used when a session starts.
function changes.reset()
  changes.flush_all()
  changes.logs = {}
end

-- Applies a log to a feature: false (gone), an altered copy, or the feature.
function changes.apply(log, f)
  local o = f.id and log and log.objects[f.id]
  if not o then return f end
  if o.taken or o.hidden then return false end
  local c = {}
  for k, v in pairs(f) do c[k] = v end
  for k, v in pairs(o) do c[k] = v end
  return c
end

return changes
