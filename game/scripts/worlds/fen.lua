-- Multiversal Van Life - Lanternfen: relight the marsh lanterns (MIT).
local world = require("lib.world")
local story = require("lib.story")
local dialogue = require("lib.dialogue")
local progress = require("lib.progress")
local audio = require("lib.audio")
local hud = require("lib.hud")

local LANTERNS = { { -8, -10 }, { 6, -16 }, { 14, -4 }, { -14, 4 } }
local FIREFLIES = { { -4, -14 }, { 10, -10 }, { 2, -22 }, { -16, -6 } }

world.register({
  id = "fen",
  name = "Lanternfen",
  description = "A misty marsh where the lanterns have gone dark.",
  destination = true,
  order = 1,
  ambient = "sounds/ambient_fen.wav",
  build = function(w)
    local s = w.state
    local helped = progress.helped("fen")
    w:env({
      sky_top = { 0.03, 0.06, 0.07 }, sky_horizon = { 0.12, 0.2, 0.18 }, fog_color = { 0.12, 0.2, 0.18 },
      fog_near = 4, fog_far = 32, ambient = { 0.18, 0.26, 0.24 }, sun_dir = { 0.3, -1, 0.2 },
      sun_color = { 0.2, 0.3, 0.3 }, stars = 0.3,
    })
    w:bounds(-22, -28, 22, 14)
    w:ground("grass", 120, 60)
    w:prop({ mesh = mvl.plane_mesh(30, 18, 10, 6), texture = "water", x = 0, y = 0.02, z = -12, uv_scroll = { 0.02, 0.01 }, color = { 0.7, 0.9, 0.9, 1 } })
    w:scatter({ texture = "bush", count = 40, min_r = 6, max_r = 24, cz = -6, w = 1.2, h = 1.4, seed = 21 })
    w:scatter({ texture = "tree_pine", count = 14, min_r = 22, max_r = 30, cz = -6, w = 3, h = 7, radius = 0.4, seed = 4 })
    for i = 1, 3 do w:prop({ model = "rock", texture = "stone", x = -18 + i * 9, z = 8 - i * 2, yaw = i, scale = 1.2, radius = 0.6 }) end
    s.carrying, s.lit = 0, 0
    -- lanterns
    s.lanterns = {}
    for i, p in ipairs(LANTERNS) do
      w:prop({ voxel = "lantern_post", x = p[1], z = p[2], radius = 0.25 })
      local lamp = w:sprite({ texture = helped and "lantern_on" or "lantern_off", x = p[1] + 0.3, y = 1.6, z = p[2], w = 0.4, h = 0.8, unlit = helped })
      local L = { lit = helped, sprite = lamp, light = i - 1, x = p[1], z = p[2] }
      s.lanterns[i] = L
      if helped then w:light(L.light, p[1], 2.0, p[2], 1.0, 0.75, 0.35, 8) s.lit = s.lit + 1 end
      w:interactable({ x = p[1], z = p[2], range = 2.0, prompt = "Light the lantern",
        enabled = function() return not L.lit end,
        use = function()
          if s.carrying <= 0 then dialogue.say("fen_need") return end
          s.carrying, s.lit, L.lit = s.carrying - 1, s.lit + 1, true
          mvl.set(lamp, { texture = mvl.texture("textures/lantern_on.tga"), unlit = true })
          w:light(L.light, L.x, 2.0, L.z, 1.0, 0.75, 0.35, 8)
          audio.sfx("pickup", 0.7)
          hud.notify("Lanterns lit: " .. s.lit .. "/" .. #LANTERNS)
          if s.lit == #LANTERNS then
            progress.set_helped("fen")
            progress.save()
            audio.sfx("quest_done", 0.9)
            dialogue.say({ "fen_light", "wick_done" })
          else
            dialogue.say("fen_light")
          end
        end })
    end
    -- fireflies
    s.flies = {}
    if not helped then
      for i, p in ipairs(FIREFLIES) do
        local e = w:sprite({ texture = "firefly", x = p[1], y = 1.2, z = p[2], w = 0.35, h = 0.35, unlit = true, nofog = true })
        local F = { e = e, x = p[1], z = p[2], phase = i * 1.7, caught = false }
        s.flies[i] = F
        F.it = w:interactable({ entity = e, range = 2.2, prompt = "Catch the firefly",
          enabled = function() return not F.caught end,
          use = function()
            F.caught = true
            mvl.destroy(F.e)
            s.carrying = s.carrying + 1
            audio.sfx("pickup", 0.6)
            dialogue.say("fen_firefly")
          end })
      end
    end
    -- people
    w:npc({ texture = "npc_fen_keeper", name = "Old Wick", x = -2, z = 6, talk = function()
      if progress.helped("fen") then dialogue.say("wick_done")
      elseif s.lit > 0 or s.carrying > 0 then dialogue.say("wick_progress")
      else dialogue.say({ "wick_1", "wick_2", "wick_3" }) end
    end })
    w:npc({ texture = "npc_child", name = "Pip", x = 12, z = -18, h = 1.2, w = 0.6, talk = function()
      dialogue.say(progress.helped("fen") and "pip_done" or "pip_1")
    end })
    story.place_van(w, 4, 10, -math.pi / 2 + 0.2)
    return story.van_door.x, story.van_door.z, story.van_door.yaw
  end,
  update = function(w, dt)
    local t = mvl.time()
    for _, F in ipairs(w.state.flies or {}) do
      if not F.caught then
        mvl.set_pos(F.e, F.x + math.sin(t * 0.7 + F.phase) * 1.2, 1.1 + math.sin(t * 2.3 + F.phase) * 0.3,
                    F.z + math.cos(t * 0.5 + F.phase) * 1.2)
      end
    end
  end,
})
