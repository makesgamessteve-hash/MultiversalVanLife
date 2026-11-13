-- Multiversal Van Life - quests of generated lands at runtime (MIT).
-- Turns a land's quest data (gen/quests.lua) into interactions: items to
-- pick up, lamps to light, places to fill, a lost person who follows you.
-- Everything is remembered in the land's change log: progress, items taken,
-- lamps lit, things put down (memory/changes.lua). Carried items can be
-- dropped (the "drop" action) and picked up again later, even after leaving.
local dialogue = require("lib.dialogue")
local progress = require("lib.progress")
local audio = require("lib.audio")
local hud = require("lib.hud")
local player = require("lib.player")
local util = require("lib.util")
local quests = require("gen.quests")

local LQ = {}

local function say_as(who, text)
  if type(text) == "table" then
    local lines = {}
    for i, t in ipairs(text) do lines[i] = { speaker = "villager", name = who, text = t, color = { 0.85, 0.85, 1 } } end
    dialogue.say(lines)
  elseif text then
    dialogue.say({ speaker = "villager", name = who, text = text, color = { 0.85, 0.85, 1 } })
  end
end

local function narrate(text) dialogue.say({ speaker = "narrator", text = text }) end

local function count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

-- Adds the quest of land `node` to world `w` (after w:land()).
function LQ.start(w, node, R)
  local d, q = node.data, node.data.quest
  if not q then return end
  local S = w.streamer
  local log = w:memory()
  local saved = log.quest or {}
  local s = {
    carrying = saved.carrying or 0, found = saved.found or 0, started = saved.started or false,
    lit = saved.lit or {}, placed = saved.placed or {}, taken = saved.taken or {},
    following = saved.following or false, lost_pos = saved.lost_pos,
    complete = progress.helped(node.address), q = q, log = log,
  }
  w.state.quest = s
  local function remember()
    log:set_quest({ carrying = s.carrying, found = s.found, started = s.started, lit = s.lit, placed = s.placed,
                    taken = s.taken, following = s.following, lost_pos = s.lost_pos })
  end
  s.remember = remember
  local giver = d.people[1]
  local words = q.words
  local function text(key, extra) return quests.text(R, q, key, extra) end

  local function complete()
    if s.complete then return end
    s.complete = true
    s.following = false
    remember()
    progress.set_helped(node.address)
    progress.save()
    audio.sfx("quest_done", 0.9)
    hud.notify(d.name .. " is grateful")
    say_as(giver.name, text("done"))
  end
  s.finish = complete

  -- items and lamps follow the quest's state whenever their chunk is built
  S.hook = function(f)
    if f.role == "quest_item" and (s.taken[f.id] or s.complete) then return false end
    if f.role == "quest_lamp" and (s.lit[f.id:gsub("_lamp$", "")] or s.complete) then
      return { id = f.id, role = f.role, x = f.x, z = f.z, y = f.y, w = f.w, h = f.h, sprite = "lantern_on", unlit = true }
    end
  end

  local feature = {}
  for _, f in ipairs(d.features) do feature[f.id] = f end
  local slot = 0
  local function light_lamp(id)
    local e = S.spawned[id .. "_lamp"]
    if e then mvl.set(e, { texture = mvl.texture("textures/lantern_on.tga"), unlit = true }) end
    local f = feature[id]
    if slot < 6 then
      local x, y, z = S:feature_pos(f)
      w:light(slot, x, y + 2.0, z, 1.0, 0.75, 0.35, 8)
      slot = slot + 1
    end
  end
  if q.kind == "relight" then
    for _, id in ipairs(q.targets) do if s.complete or s.lit[id] then light_lamp(id) end end
  end

  -- the giver
  local function left()
    if q.kind == "gather" then return q.count - s.found end
    if q.kind == "relight" then return q.count - count(s.lit) end
    if q.kind == "return" then return q.count - count(s.placed) end
    return 1
  end
  w:npc_at(giver, function()
    if s.complete then say_as(giver.name, text("done")) return end
    if q.kind == "gather" and s.found >= q.count then complete() return end
    if s.started then
      say_as(giver.name, text("progress", { left = left() }))
    else
      s.started = true
      remember()
      say_as(giver.name, text("intro"))
    end
  end)

  -- what the player carries can be put down and picked up again
  local item_word = q.kind == "relight" and words.glow or (q.kind == "gather" and words.part or words.keepsake)
  local item_sprite = q.kind == "relight" and "firefly" or (q.kind == "return" and "book" or nil)
  local function add_pickup(obj)
    local it
    it = w:interactable({ x = obj.x, z = obj.z, range = 2.2, prompt = "Pick up the " .. item_word .. " you left",
      enabled = function() return log.placed[obj.id] ~= nil end,
      use = function()
        log:unplace(obj.id)
        S:remove_feature(obj.id)
        w:remove_interactable(it)
        s.carrying = s.carrying + 1
        remember()
        audio.sfx("pickup", 0.6)
        hud.notify("Carrying " .. s.carrying .. " " .. item_word)
      end })
  end
  for _, obj in ipairs(log:placed_list()) do if obj.role == "dropped" then add_pickup(obj) end end
  s.drop = function()
    if s.carrying <= 0 or not item_sprite then return false end
    local fx, fz = util.forward(player.facing())
    local obj = { role = "dropped", sprite = item_sprite, x = player.x + fx * 1.2, z = player.z + fz * 1.2,
                  y = q.kind == "relight" and 0.6 or 0.1, w = 0.4, h = 0.4, unlit = q.kind == "relight" or nil }
    log:place(obj)
    S:add_feature(obj)
    add_pickup(obj)
    s.carrying = s.carrying - 1
    remember()
    audio.sfx("interact", 0.5)
    hud.notify("You put down a " .. item_word)
    return true
  end

  -- items to pick up
  for _, id in ipairs(q.items) do
    local f = feature[id]
    w:interactable({ x = f.x, z = f.z, range = 2.2, prompt = (q.kind == "relight" and "Gather the " or "Pick up the ") .. item_word,
      enabled = function() return not s.taken[id] and not s.complete end,
      use = function()
        s.taken[id] = true
        log:take(id)
        S:remove_feature(id)
        audio.sfx("pickup", 0.7)
        if q.kind == "gather" then
          s.found = s.found + 1
          hud.notify(item_word .. "s found: " .. s.found .. "/" .. q.count)
          if s.found >= q.count then narrate("That's all of them. Time to bring them back to " .. giver.name .. ".") end
        else
          s.carrying = s.carrying + 1
          hud.notify("Carrying " .. s.carrying .. " " .. item_word)
        end
        remember()
      end })
  end

  -- targets: lamps to light or places to fill
  for _, id in ipairs(q.targets) do
    local f = feature[id]
    if q.kind == "relight" then
      w:interactable({ x = f.x, z = f.z, range = 2.2, prompt = "Light the " .. words.light,
        enabled = function() return not s.lit[id] and not s.complete end,
        use = function()
          if s.carrying <= 0 then narrate("A dark " .. words.light .. ". If only you had some " .. words.glow .. ".") return end
          s.carrying, s.lit[id] = s.carrying - 1, true
          log:set(id .. "_lamp", { sprite = "lantern_on", unlit = true, state = "lit" })
          remember()
          light_lamp(id)
          audio.sfx("pickup", 0.7)
          hud.notify(words.light .. "s lit: " .. count(s.lit) .. "/" .. q.count)
          if count(s.lit) >= q.count then complete() else narrate("The " .. words.light .. " flickers to life.") end
        end })
    else
      w:interactable({ x = f.x, z = f.z, range = 2.2, prompt = "Place the " .. words.keepsake,
        enabled = function() return s.carrying > 0 and not s.placed[id] and not s.complete end,
        use = function()
          s.carrying, s.placed[id] = s.carrying - 1, true
          -- the keepsake stays where it was put, on every later visit
          local obj = { role = "returned", sprite = "book", x = f.x, z = f.z, y = 1.1, w = 0.45, h = 0.45 }
          log:place(obj)
          S:add_feature(obj)
          remember()
          audio.sfx("pickup", 0.7)
          hud.notify(words.keepsake .. "s returned: " .. count(s.placed) .. "/" .. q.count)
          if count(s.placed) >= q.count then complete() else narrate("It settles into the " .. words.spot .. ".") end
        end })
    end
  end

  -- the lost person waits far away (or where you left them) and follows once found
  if q.lost and not s.complete then
    local L = q.lost
    local at = s.lost_pos or { x = L.x, z = L.z }
    local e, it = w:npc_at({ name = L.name, texture = L.texture, x = at.x, z = at.z, h = 1.2, w = 0.6 }, function()
      if s.following then say_as(L.name, "I'm right behind you.") return end
      s.following = true
      remember()
      say_as(L.name, text("lost_line") or "Lead the way!")
    end)
    s.lost_entity, s.lost_pos, s.lost_it = e, { x = at.x, z = at.z }, it
  end
end

-- Moves the follower, handles dropping, and checks whether the lost person is home.
function LQ.update(w, dt)
  local s = w.state.quest
  if not s or s.complete then return end
  if player.enabled and mvl.pressed("drop") then s.drop() end
  if not s.following then return end
  local p = s.lost_pos
  local dx, dz = player.x - p.x, player.z - p.z
  local dist = math.sqrt(dx * dx + dz * dz)
  if dist > 25 then
    -- the player hurried ahead: catch up
    p.x, p.z = player.x - dx / dist * 2, player.z - dz / dist * 2
  elseif dist > 2 then
    local step = math.min(dist - 2, 4.5 * dt)
    p.x, p.z = p.x + dx / dist * step, p.z + dz / dist * step
  end
  mvl.set_pos(s.lost_entity, p.x, w:height(p.x, p.z), p.z)
  s.lost_it.x, s.lost_it.z = p.x, p.z
  s.lost_moved = (s.lost_moved or 0) + dt
  if s.lost_moved > 2 then -- remember where they are now and then
    s.lost_moved = 0
    s.remember()
  end
  local g = w.land_node.data.people[1]
  local gx, gz = g.x - p.x, g.z - p.z
  if gx * gx + gz * gz < 25 then s.finish() end
end

return LQ
