-- Multiversal Van Life - quests of generated lands at runtime (MIT).
-- Turns a land's quest data (gen/quests.lua) into interactions: items to
-- pick up, lamps to light, places to fill, a lost person who follows you,
-- word to carry, someone to guide, a failing source to restore, a quarrel
-- to settle by taking a side or a compromise. A quest can be given up.
-- Everything is remembered in the land's change log: progress, items taken,
-- lamps lit, things put down (memory/changes.lua), how the quest ended and
-- what its people think of the player (memory/characters.lua). Carried
-- items can be dropped (the "drop" action) and picked up again later.
local dialogue = require("lib.dialogue")
local progress = require("lib.progress")
local audio = require("lib.audio")
local hud = require("lib.hud")
local player = require("lib.player")
local util = require("lib.util")
local talk = require("lib.talk")
local Menu = require("lib.menu")
local quests = require("gen.quests")
local characters = require("memory.characters")

local LQ = {}

local say_as = talk.say
local function narrate(text) dialogue.say({ speaker = "narrator", text = text }) end
local function story() return require("lib.story") end

local function count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

-- The short name of a party for menus ("the upstream villages of X" ->
-- "the upstream villages").
function LQ.short(label) return #label > 28 and label:match("^(.-) of ") or label end

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
    following = saved.following or false, lost_pos = saved.lost_pos, heard = saved.heard or {},
    delivered = saved.delivered or false,
    complete = progress.helped(node.address) or log.outcome ~= nil, result = log.outcome and log.outcome.result,
    q = q, log = log,
  }
  w.state.quest = s
  local function remember()
    log:set_quest({ carrying = s.carrying, found = s.found, started = s.started, lit = s.lit, placed = s.placed,
                    taken = s.taken, following = s.following, lost_pos = s.lost_pos, heard = s.heard,
                    delivered = s.delivered })
  end
  s.remember = remember
  local giver = d.people[1]
  local words = q.words
  local function text(key, extra) return quests.text(R, q, key, extra) end
  local people = {}
  for _, p in ipairs(d.people) do people[p.id] = p end

  -- how the quest ends: the outcome, and who remembers what
  local function finish(result, extra)
    s.complete, s.result, s.following = true, result, false
    remember()
    local winner = extra and extra.winner
    local deed = text("deed", { winner = winner and winner.label }) or "helped us"
    local outcome = { kind = q.kind, result = result, night = progress.night(), template = q.template }
    if result == "abandoned" then
      characters.community(log, { letdown = true, favour = -1 })
      characters.resent(log, giver.id, "gave up on us", 1)
      log:set_outcome(outcome)
      progress.save()
      return
    end
    characters.community(log, { known_as = characters.TITLES[q.kind] or "the Helper", deed = deed, favour = 1 })
    characters.thank(log, giver.id, deed, 1)
    if q.kind == "mediate" then
      for i, party in ipairs(q.parties) do
        local key = i == 1 and "a" or "b"
        if result == "compromise" then
          characters.thank(log, party.person, deed, 1)
          characters.add_reputation(party.label, 1)
        elseif result == key then
          characters.thank(log, party.person, text("deed_side", { winner = party.label }), 2)
          characters.add_reputation(party.label, 2)
          outcome.favoured = party.label
        else
          characters.resent(log, party.person, text("wrong_side", { winner = winner.label }), 2)
          characters.add_reputation(party.label, -2)
          outcome.wronged = party.label
        end
      end
    end
    log:set_outcome(outcome)
    progress.set_helped(node.address)
    progress.save()
    audio.sfx("quest_done", 0.9)
    hud.notify(d.name .. " is grateful")
  end
  local function complete()
    finish("done")
    say_as(giver.name, text("done"))
  end
  s.finish = complete

  -- items and lamps follow the quest's state whenever their chunk is built
  S.hook = function(f)
    if f.role == "quest_item" and (s.taken[f.id] or s.complete) then return false end
    if f.role == "quest_lamp" and (s.lit[f.id:gsub("_lamp$", "")] or (s.complete and s.result ~= "abandoned")) then
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
    for _, id in ipairs(q.targets) do
      if (s.complete and s.result ~= "abandoned") or s.lit[id] then light_lamp(id) end
    end
  end

  -- -------------------------------------------------------- mediation
  local function party_of(pid)
    for i, party in ipairs(q.parties or {}) do if party.person == pid then return i, party end end
  end
  local function settle()
    local a, b = q.parties[1], q.parties[2]
    local function choose(result, winner)
      story().menu = nil
      finish(result, { winner = winner })
      if result == "compromise" then say_as(giver.name, text("done_compromise"))
      else say_as(giver.name, text("done_side", { winner = winner.label })) end
    end
    story().menu = Menu.new("SETTLE THE QUARREL", {
      { label = "Side with " .. LQ.short(a.label), action = function() choose("a", a) end },
      { label = "Side with " .. LQ.short(b.label), action = function() choose("b", b) end },
      { label = "Share it: a compromise", action = function() choose("compromise") end },
      { label = "Not yet", action = function() story().menu = nil end },
    }, { subtitle = q.issue, cancel = function() story().menu = nil end })
  end
  s.settle = settle
  local function heard_both() return q.parties and s.heard[1] and s.heard[2] end

  -- ------------------------------------------------------------ the giver
  local function left()
    if q.kind == "gather" or q.kind == "restore" then return q.count - s.found end
    if q.kind == "relight" then return q.count - count(s.lit) end
    if q.kind == "return" then return q.count - count(s.placed) end
    if q.kind == "mediate" then return 2 - count(s.heard) end
    return 1
  end
  local function give_up_menu()
    story().menu = Menu.new(giver.name:upper(), {
      { label = "I'll keep at it", action = function() story().menu = nil end },
      { label = "I can't help, sorry (give up)", action = function()
        story().menu = nil
        finish("abandoned")
        say_as(giver.name, "Oh. I see. We'll manage somehow, I suppose.")
      end },
    }, { subtitle = q.short, cancel = function() story().menu = nil end })
  end
  s.give_up_menu = give_up_menu
  w:npc_at(giver, function()
    if s.complete then
      talk.villager(w, node, giver)
      return
    end
    if (q.kind == "gather" and s.found >= q.count) or (q.kind == "message" and s.delivered) then
      characters.meet(log, giver.id)
      complete()
      return
    end
    if q.kind == "mediate" and heard_both() then
      characters.meet(log, giver.id)
      say_as(giver.name, text("heard"), settle)
      return
    end
    if s.started then
      local line = q.kind == "restore" and s.found >= q.count and text("ready") or text("progress", { left = left() })
      say_as(giver.name, line, give_up_menu)
    else
      s.started = true
      characters.meet(log, giver.id)
      remember()
      local intro = quests.intro(R, q)
      -- where the Wanderer legend is told, the van is recognised at once
      if d.wanderer then
        local first = string.format("That wagon! Cream and teal, like the Wanderer in our stories, who came out of the sky " ..
                                    "%d years ago. You came back!", math.floor(d.wanderer.years_ago + 0.5))
        table.insert(intro, 1, first)
      end
      say_as(giver.name, intro)
    end
  end)

  -- villagers who are part of the quest (parties of a dispute)
  s.talk = function(p)
    if s.complete or not s.started then return false end
    local i = party_of(p.id)
    if not i then return false end
    characters.meet(log, p.id)
    s.heard[i] = true
    remember()
    local lines = text(i == 1 and "claim_a" or "claim_b")
    if type(lines) ~= "table" then lines = { lines } end
    table.insert(lines, 1, "I speak for " .. q.parties[i].label .. ".")
    say_as(p.name, lines, function() if heard_both() then settle() end end)
    return true
  end

  -- what the player carries can be put down and picked up again
  local item_word = q.kind == "relight" and words.glow or ((q.kind == "gather" or q.kind == "restore") and words.part
                    or words.keepsake)
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
        if q.kind == "gather" or q.kind == "restore" then
          s.found = s.found + 1
          hud.notify(item_word .. "s found: " .. s.found .. "/" .. q.count)
          if s.found >= q.count then
            narrate(q.kind == "gather" and ("That's all of them. Time to bring them back to " .. giver.name .. ".")
                    or ("That's all of them. Now to the " .. words.source .. "."))
          end
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

  -- a failing source, restored with what was found
  if q.source then
    local src = q.source
    w:interactable({ x = src.x, z = src.z, range = 2.6, prompt = "Restore the " .. words.source,
      enabled = function() return not s.complete end,
      use = function()
        if not s.started or s.found < q.count then
          narrate("The " .. words.source .. " is nearly dead. " .. (s.started and (left() .. " " .. words.part ..
                  "s are still missing.") or ("Perhaps " .. giver.name .. " knows what it needs.")))
          return
        end
        audio.sfx("pickup", 0.8)
        complete()
      end })
  end

  -- someone to carry word to, far away
  if q.recipient then
    local r = q.recipient
    w:npc_at(r, function()
      if s.complete or not s.started then talk.villager(w, node, r) return end
      characters.meet(log, r.id)
      if s.delivered then say_as(r.name, text("waiting")) return end
      s.delivered = true
      remember()
      characters.thank(log, r.id, "brought " .. giver.name .. "'s word", 1)
      say_as(r.name, text("reply"))
    end)
  end

  -- someone who follows the player: the lost person, home to the giver, or
  -- the one to escort, to their destination
  local follower, goal
  if q.lost and not s.complete then
    local L = q.lost
    local at = s.lost_pos or { x = L.x, z = L.z }
    follower = { name = L.name, texture = L.texture, x = at.x, z = at.z, h = 1.2, w = 0.6 }
    goal = function(p) local dx, dz = giver.x - p.x, giver.z - p.z return dx * dx + dz * dz < 25 end
  elseif q.escort and not s.complete then
    local E = q.escort
    local at = s.lost_pos or { x = E.x, z = E.z }
    follower = { name = E.name, texture = E.texture, body = E.body, x = at.x, z = at.z, h = 1.2, w = 0.6, yaw = E.yaw }
    local dest = q.destination
    goal = function(p) local dx, dz = dest.x - p.x, dest.z - p.z return dx * dx + dz * dz < 36 end
  end
  if follower then
    local e, it = w:npc_at(follower, function()
      if s.following then say_as(follower.name, "I'm right behind you.") return end
      if q.escort and not s.started then say_as(follower.name, text("wait_line")) return end
      s.following = true
      remember()
      say_as(follower.name, text(q.escort and "escort_line" or "lost_line") or "Lead the way!")
    end)
    s.lost_entity, s.lost_pos, s.lost_it = e, { x = follower.x, z = follower.z }, it
    s.goal = function(p)
      if not goal(p) then return false end
      if q.escort then
        finish("done")
        say_as(follower.name, text("arrive"))
        say_as(giver.name, text("done"))
      else
        complete()
      end
      return true
    end
  end
end

-- What a villager says when they are part of the land's quest (true when
-- the quest handled the conversation).
function LQ.talk(w, p)
  local s = w.state.quest
  return s ~= nil and s.talk ~= nil and s.talk(p) or false
end

-- Moves the follower, handles dropping, and checks whether they arrived.
function LQ.update(w, dt)
  local s = w.state.quest
  if not s or s.complete then return end
  if player.enabled and mvl.pressed("drop") then s.drop() end
  if not s.following or not s.lost_entity then return end
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
  s.goal(p)
end

return LQ
