-- Multiversal Van Life - home: a farm at night where the van appears (MIT).
local world = require("lib.world")
local story = require("lib.story")
local dialogue = require("lib.dialogue")
local progress = require("lib.progress")

local mabel_lines = { "mabel_1", "mabel_2", "mabel_3" }

world.register({
  id = "home",
  name = "Home",
  ambient = "sounds/ambient_night.wav",
  ambient_volume = 0.5,
  build = function(w)
    w:env({
      sky_top = { 0.02, 0.03, 0.09 }, sky_horizon = { 0.10, 0.12, 0.24 }, fog_color = { 0.08, 0.1, 0.2 },
      fog_near = 12, fog_far = 70, ambient = { 0.22, 0.24, 0.34 }, sun_dir = { -0.4, -1, -0.3 },
      sun_color = { 0.35, 0.4, 0.55 }, stars = 1,
    })
    w:bounds(-30, -30, 30, 30)
    w:ground("grass", 140, 70)
    w:prop({ mesh = mvl.plane_mesh(4, 40, 2, 20), texture = "dirt", x = 7, y = 0.01, z = 4 })
    -- farmhouse (door on +X) and barn
    w:prop({ voxel = "house", x = 0, z = -8, box = { 6.0, 5.0 } })
    w:prop({ voxel = "barn", x = -13, z = -15, yaw = 0.3, box = { 5.0, 4.0 } })
    w:prop({ voxel = "well", x = -5, z = 1, radius = 0.9 })
    w:prop({ model = "lamp", x = 4.2, z = -4.5, radius = 0.2 })
    w:light(0, 4.2, 2.8, -4.5, 1.0, 0.8, 0.5, 9)
    w:light(1, 3.4, 1.6, -8, 1.0, 0.75, 0.4, 5) -- porch window glow
    for i = -4, 4 do
      if i ~= 2 then -- the gate gap leads to the van
        w:prop({ voxel = "fence", x = 9.5, z = i * 2.0, yaw = math.pi / 2, box = { 2.0, 0.3 } })
      end
    end
    w:scatter({ texture = "tree_pine", count = 22, min_r = 18, max_r = 28, w = 3, h = 6, radius = 0.4, seed = 7 })
    w:scatter({ texture = "tree_oak", count = 8, min_r = 11, max_r = 17, cx = -6, cz = -4, w = 3.5, h = 5, radius = 0.4, seed = 3 })
    w:scatter({ texture = "bush", count = 18, min_r = 5, max_r = 16, w = 1, h = 1, seed = 11 })
    w:scatter({ texture = "flowers", count = 14, min_r = 2, max_r = 8, cx = 2, cz = -3, w = 0.6, h = 0.6, seed = 5 })
    w:sprite({ texture = "moon", x = -50, y = 28, z = -70, w = 9, h = 9, unlit = true, nofog = true })
    -- neighbour
    w:npc({ texture = "npc_farmer", name = "Mabel", x = -3.5, z = 3.5, talk = function()
      local n = (w.state.mabel or 0) % #mabel_lines + 1
      w.state.mabel = n
      dialogue.say(mabel_lines[n])
    end })
    -- the van at the gate
    story.place_van(w, 11.5, 1.0, math.pi / 2)
    w.state.call_timer = progress.flag("van_met") and nil or 2.0
    return 3.6, -6.5, -0.9
  end,
  update = function(w, dt)
    if w.state.call_timer then
      w.state.call_timer = w.state.call_timer - dt
      if w.state.call_timer <= 0 then
        w.state.call_timer = nil
        dialogue.say({ "van_call_1", "van_call_2" })
      end
    end
  end,
})
