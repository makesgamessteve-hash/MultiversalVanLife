-- Multiversal Van Life - what the player has learned (MIT).
--
-- The codex record ("codex") keeps every discovered entry: a snapshot of the
-- entry as the land knew it (gen/codex.lua), how and where it was found
-- (visiting, talking, reading an inscription, observing) and the versions
-- people told of it (who told it, and how). Juniper knows the true story of
-- the universes she wandered through (the Wanderer's universes), so there
-- the codex shows what really happened beside what people believe.
local K = { cache = nil }

local function rec()
  if not K.cache then
    local r = mvl.record_read("codex") or {}
    K.cache = { entries = r.entries or {}, order = r.order or {}, opened = r.opened or 0 }
  end
  return K.cache
end

local function save() mvl.record_write("codex", rec()) end

-- Forgets the cached record (a new journey or a restart reads it again).
function K.reset() K.cache = nil end

function K.get(id) return rec().entries[id] end
function K.known(id) return rec().entries[id] ~= nil end
function K.count() return #rec().order end

-- Every discovered entry (of `kind`, or all), in the order found.
function K.list(kind)
  local out = {}
  for _, id in ipairs(rec().order) do
    local e = rec().entries[id]
    if e and (not kind or e.kind == kind) then out[#out + 1] = e end
  end
  return out
end

-- Discovers entry snapshot `e` ({ id, kind, name, ... }): `how` ("visit",
-- "talk", "inscription", "observation"), `where` (a place name) and an
-- optional `version` ({ by, told }). Returns true when something is new.
function K.discover(e, how, where, version)
  if not e or not e.id then return false end
  local r = rec()
  local cur = r.entries[e.id]
  local new = false
  if not cur then
    cur = {}
    for k, v in pairs(e) do cur[k] = v end
    cur.found = { how = how, where = where, night = require("lib.progress").night() }
    cur.versions = {}
    r.entries[e.id] = cur
    r.order[#r.order + 1] = e.id
    new = true
  else
    -- a richer snapshot of the same thing (a saint first read on a statue)
    for k, v in pairs(e) do if cur[k] == nil then cur[k] = v; new = true end end
  end
  if version and version.told then
    local dup = false
    for _, v in ipairs(cur.versions) do if v.told == version.told then dup = true end end
    if not dup then
      cur.versions[#cur.versions + 1] = { by = version.by, told = version.told, where = where }
      new = true
    end
  end
  if new then save() end
  return new
end

-- Does Juniper know the true story of entry `e`?
function K.juniper_knows(e)
  local gen = require("gen")
  if not e or not e.universe or not gen.world then return false end
  return gen.history.wanderer.visited(gen.world, e.universe)
end

function K.opened()
  local r = rec()
  r.opened = r.opened + 1
  save()
end

-- ------------------------------------------------------------- triggers
local function entries(node) return node.data.codex and node.data.codex.entries or {} end
local function keys(node) return node.data.codex and node.data.codex.keys or {} end

-- Arriving in a land: the place and the people seen there.
function K.visit(node)
  local E, k = entries(node), keys(node)
  local n = 0
  for _, key in ipairs({ "place", "species", "language", "faith", "traditions", "nation" }) do
    if k[key] and K.discover(E[k[key]], "visit", node.data.name) then n = n + 1 end
  end
  return n
end

-- A conversation told about things (the grammar's used slots).
function K.heard(node, used, speaker)
  local E, k = entries(node), keys(node)
  local where = node.data.name
  local by = speaker and speaker.name
  local n = 0
  local function found(id, version) if id and K.discover(E[id], "talk", where, version) then n = n + 1 end end
  -- a saint is learned from their story (a blessing in their name is not one)
  if used.saint_story then found(k.saint, { by = by, told = used.saint_story }) end
  if used.memory then found(k.events[used.memory], { by = by, told = used.memory }) end
  if used.deity or used.faith or used.moon_deity or used.virtue then found(k.faith) end
  if used.holiday then found(k.traditions) end
  if used.greeting or used.stranger then found(k.language) end
  for _, slot in ipairs({ "beast", "plant" }) do
    if used[slot] then
      for id, e in pairs(E) do if e.kind == "creature" and e.name == used[slot] then found(id) end end
    end
  end
  return n
end

-- Reading an inscription (a statue, a ruin, a battlefield, a shrine).
function K.read(node, f)
  local e, text = require("gen.codex").inscription(node.data, f, node.address)
  if not e then return nil end
  -- the land may know more of it (the saint a statue shows, a war remembered)
  local full = entries(node)[e.id]
  K.discover(full or e, "inscription", node.data.name)
  return text, e
end

-- Watching a creature of species `sp_id` (a habitat species id).
function K.observe(node, sp_id)
  local id = keys(node).creatures and keys(node).creatures[sp_id]
  return id and K.discover(entries(node)[id], "observation", node.data.name) or false
end

return K
