-- Multiversal Van Life - home: the farm in the Prime universe, generated
-- from the save's seed (MIT). The farmhouse, gate and van spot are always
-- there; the barn, fields, trees and the neighbour vary between journeys.
local world = require("lib.world")
local story = require("lib.story")
local dialogue = require("lib.dialogue")
local lines = require("lib.lines")
local progress = require("lib.progress")
local gen = require("gen")

local neighbour_lines = { "mabel_1", "mabel_2", "mabel_3" }

-- The neighbour's lines, spoken under the generated neighbour's name.
local function neighbour_line(id, who)
  local l = lines.get(id)
  return { id = id, speaker = "neighbour", name = who.name, text = l.text, color = { 0.75, 0.9, 0.6 } }
end

world.register({
  id = "home",
  name = "Home",
  ambient = "sounds/ambient_night.wav",
  ambient_volume = 0.5,
  build = function(w)
    w:env({
      sky_top = { 0.02, 0.03, 0.09 }, sky_horizon = { 0.10, 0.12, 0.24 }, fog_color = { 0.08, 0.1, 0.2 },
      fog_near = 14, fog_far = 75, ambient = { 0.22, 0.24, 0.34 }, sun_dir = { -0.4, -1, -0.3 },
      sun_color = { 0.35, 0.4, 0.55 }, stars = 1,
    })
    local G = gen.world or gen.start(1)
    local farm = G:generate(gen.prime.FARM)
    local d = farm.data
    w:land(farm, function(gx, gz) return gen.neighbour_land(G, farm.address, gx, gz) end)
    -- lights of the farmhouse
    for _, f in ipairs(d.features) do
      if f.role == "lamp" then w:light(0, f.x, w:height(f.x, f.z) + 2.8, f.z, 1.0, 0.8, 0.5, 9) end
      if f.role == "farmhouse" then
        local c, s = math.cos(f.yaw), math.sin(f.yaw)
        local lx, lz = f.x + c * 3.4, f.z - s * 3.4
        w:light(1, lx, w:height(lx, lz) + 1.6, lz, 1.0, 0.75, 0.4, 5) -- porch window glow
      end
    end
    w:sprite({ texture = "moon", x = -50, y = 40, z = -70, w = 9, h = 9, unlit = true, nofog = true })
    -- the neighbour
    local n = d.neighbour
    local e, it = w:npc({ texture = n.texture, name = n.name, x = n.x, z = n.z, talk = function()
      local i = (w.state.neighbour or 0) % #neighbour_lines + 1
      w.state.neighbour = i
      dialogue.say(neighbour_line(neighbour_lines[i], n))
    end })
    mvl.set_pos(e, n.x, w:height(n.x, n.z), n.z)
    mvl.set_color(e, n.tint[1], n.tint[2], n.tint[3], n.tint[4])
    w.state.neighbour_npc = it
    -- the van at the gate
    local v = d.spots.van
    story.place_van(w, v.x, v.z, v.yaw)
    w.state.call_timer = progress.flag("van_met") and nil or 2.0
    return d.spots.spawn.x, d.spots.spawn.z, d.spots.spawn.yaw
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
