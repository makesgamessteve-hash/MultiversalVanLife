-- Multiversal Van Life - quests of generated lands at runtime (MIT).
-- Turns a land's quest data (gen/quests.lua) into interactions: items to
-- pick up, lamps to light, places to fill, a lost person who follows you.
local dialogue = require("lib.dialogue")
local progress = require("lib.progress")
local audio = require("lib.audio")
local hud = require("lib.hud")
local player = require("lib.player")
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

-- Adds the quest of land `node` to world `w` (after w:land()).
function LQ.start(w, node, R)
  local d, q = node.data, node.data.quest
  if not q then return end
  local S = w.streamer
  local s = { carrying = 0, found = 0, lit = {}, placed = {}, taken = {}, started = false,
              complete = progress.helped(node.address), q = q }
  w.state.quest = s
  local giver = d.people[1]
  local words = q.words
  local function text(key, extra) return quests.text(R, q, key, extra) end
  local function left() return q.count - (q.kind == "gather" and s.found or 0) end

  local function complete()
    if s.complete then return end
    s.complete = true
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
  if s.complete and q.kind == "relight" then for _, id in ipairs(q.targets) do light_lamp(id) end end

  -- the giver
  s.giver_it = select(2, w:npc_at(giver, function()
    if s.complete then say_as(giver.name, text("done")) return end
    if q.kind == "gather" and s.found >= q.count then complete() return end
    if s.started then say_as(giver.name, text("progress", { left = q.count - (q.kind == "gather" and s.found or
                                                       (q.kind == "relight" and s.lit_count or s.placed_count) or 0) }))
    else
      s.started = true
      say_as(giver.name, text("intro"))
    end
  end))
  s.lit_count, s.placed_count = 0, 0

  -- items to pick up
  local item_word = q.kind == "relight" and words.glow or (q.kind == "gather" and words.part or words.keepsake)
  for _, id in ipairs(q.items) do
    local f = feature[id]
    w:interactable({ x = f.x, z = f.z, range = 2.2, prompt = (q.kind == "relight" and "Gather the " or "Pick up the ") .. item_word,
      enabled = function() return not s.taken[id] and not s.complete end,
      use = function()
        s.taken[id] = true
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
          s.carrying, s.lit[id], s.lit_count = s.carrying - 1, true, s.lit_count + 1
          light_lamp(id)
          audio.sfx("pickup", 0.7)
          hud.notify(words.light .. "s lit: " .. s.lit_count .. "/" .. q.count)
          if s.lit_count >= q.count then complete() else narrate("The " .. words.light .. " flickers to life.") end
        end })
    else
      w:interactable({ x = f.x, z = f.z, range = 2.2, prompt = "Place the " .. words.keepsake,
        enabled = function() return s.carrying > 0 and not s.placed[id] and not s.complete end,
        use = function()
          s.carrying, s.placed[id], s.placed_count = s.carrying - 1, true, s.placed_count + 1
          local x, y, z = S:feature_pos(f)
          w:sprite({ texture = "book", x = x, y = y + 1.1, z = z, w = 0.45, h = 0.45 })
          audio.sfx("pickup", 0.7)
          hud.notify(words.keepsake .. "s returned: " .. s.placed_count .. "/" .. q.count)
          if s.placed_count >= q.count then complete() else narrate("It settles into the " .. words.spot .. ".") end
        end })
    end
  end

  -- the lost person waits far away and follows once found
  if q.lost and not s.complete then
    local L = q.lost
    local e, it = w:npc_at({ name = L.name, texture = L.texture, x = L.x, z = L.z, h = 1.2, w = 0.6 }, function()
      if s.following then say_as(L.name, "I'm right behind you.") return end
      s.following = true
      say_as(L.name, text("lost_line") or "Lead the way!")
    end)
    s.lost_entity, s.lost_pos = e, { x = L.x, z = L.z }
    s.lost_it = it
  end
end

-- Moves the follower and checks whether they are home.
function LQ.update(w, dt)
  local s = w.state.quest
  if not s or s.complete or not s.following then return end
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
  local g = w.land_node.data.people[1]
  local gx, gz = g.x - p.x, g.z - p.z
  if gx * gx + gz * gz < 25 then s.finish() end
end

return LQ
