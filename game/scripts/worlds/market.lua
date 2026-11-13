-- Multiversal Van Life - the Clockwork Bazaar: find Tock's gears (MIT).
local world = require("lib.world")
local story = require("lib.story")
local dialogue = require("lib.dialogue")
local progress = require("lib.progress")
local audio = require("lib.audio")
local hud = require("lib.hud")

local GEARS = { { -9, -6 }, { 8, -11 }, { -3, -17 } }
local STALLS = { { -8, -9, 0.3 }, { 7, -8, -0.4 }, { -10, -2, 1.4 }, { 10, -15, -1.2 }, { 0, -20, 0 } }

world.register({
  id = "market",
  name = "Clockwork Bazaar",
  description = "A brass market under an amber sky where the great clock has stopped.",
  destination = true,
  order = 2,
  ambient = "sounds/ambient_market.wav",
  build = function(w)
    local s = w.state
    local helped = progress.helped("market")
    w:env({
      sky_top = { 0.25, 0.12, 0.2 }, sky_horizon = { 0.85, 0.5, 0.3 }, fog_color = { 0.6, 0.38, 0.28 },
      fog_near = 15, fog_far = 55, ambient = { 0.45, 0.38, 0.35 }, sun_dir = { 0.6, -0.5, -0.4 },
      sun_color = { 0.7, 0.45, 0.3 }, stars = 0,
    })
    w:bounds(-18, -26, 18, 12)
    w:ground("cobble", 100, 50)
    for i, p in ipairs(STALLS) do w:prop({ voxel = "market_stall", x = p[1], z = p[2], yaw = p[3], box = { 3.0, 2.0 } }) end
    for i = 1, 4 do
      local x, z = (i % 2 == 0) and 4 or -4, -4 - i * 4
      w:prop({ model = "lamp", x = x, z = z, radius = 0.2, color = { 0.9, 0.7, 0.4, 1 } })
      w:light(i - 1, x, 2.8, z, 1.0, 0.75, 0.4, 8)
    end
    -- the great clock: a tall tower of cubes with a spinning gear face
    w:prop({ model = "cube", texture = "metal_panel", x = 0, y = 0, z = -26, scale = { 4, 10, 2 }, box = { 4, 2 } })
    s.clock = w:sprite({ texture = "gear", x = 0, y = 6, z = -24.9, w = 3, h = 3, unlit = helped })
    s.found = 0
    s.gears = {}
    if not helped then
      for i, p in ipairs(GEARS) do
        local e = w:sprite({ texture = "gear", x = p[1], y = 0.1, z = p[2], w = 0.4, h = 0.4 })
        local G = { e = e }
        G.it = w:interactable({ entity = e, range = 2.0, prompt = "Pick up the gear",
          use = function()
            mvl.destroy(G.e)
            w:remove_interactable(G.it)
            s.found = s.found + 1
            audio.sfx("pickup", 0.7)
            hud.notify("Gears found: " .. s.found .. "/" .. #GEARS)
            dialogue.say("market_gear")
          end })
        s.gears[i] = G
      end
    end
    w:npc({ texture = "npc_merchant", name = "Brassa", x = -3, z = 4, talk = function()
      dialogue.say(progress.helped("market") and "brassa_done" or { "brassa_1", "brassa_2" })
    end })
    w:npc({ texture = "npc_robot", name = "Tock", x = 3, z = -22, h = 1.3, talk = function()
      if progress.helped("market") then dialogue.say("tock_done") return end
      if s.found >= #GEARS then
        progress.set_helped("market")
        progress.save()
        audio.sfx("quest_done", 0.9)
        mvl.set(s.clock, { unlit = true })
        dialogue.say({ "tock_done", "brassa_done" })
      else
        dialogue.say("tock_1")
      end
    end })
    story.place_van(w, 6, 7, -math.pi / 2)
    return story.van_door.x, story.van_door.z, story.van_door.yaw
  end,
  update = function(w, dt)
    if progress.helped("market") and w.state.clock then
      mvl.set(w.state.clock, { roll = mvl.time() })
    end
  end,
})
