-- Multiversal Van Life - a generated land reached through a signal (MIT).
-- Everything comes from the land's generated description: its world's style
-- (sky, sounds, ground), the settlement and its people, the trouble.
local world = require("lib.world")
local story = require("lib.story")
local dialogue = require("lib.dialogue")
local progress = require("lib.progress")
local LQ = require("lib.landquest")
local gen = require("gen")

local CHATTER = {
  "A van? Out here? Well, I've seen stranger things fall out of the sky.",
  "Mind the {spot}s, the little ones built them.",
  "The {folk} of {place} don't get many visitors. Welcome!",
  "If you're looking for {giver}, they're by the square.",
}

world.register({
  id = "land",
  name = "A generated land",
  ambient = "sounds/ambient_night.wav",
  build = function(w)
    local addr = w.args.address or progress.land_address()
    local G = gen.world
    local node = G:generate(addr)
    local d = node.data
    local style = gen.provisional.style(d.style)
    local planet = G:node(gen.address.parent(gen.address.parent(gen.address.parent(addr))))
    w.name = d.name .. ", " .. planet.data.name
    w.ambient, w.ambient_volume = style.ambient, 0.5
    local e = style.env
    w:env({ sky_top = e.sky_top, sky_horizon = e.sky_horizon, fog_color = e.fog, fog_near = 14, fog_far = e.fog_far or 70,
            ambient = e.ambient, sun_dir = { -0.4, -1, -0.3 }, sun_color = { 0.3, 0.32, 0.4 }, stars = e.stars })
    w:land(node, function(gx, gz) return gen.neighbour_land(G, addr, gx, gz) end)
    -- people (the first one has the trouble)
    for i = 2, #d.people do
      local p = d.people[i]
      local line = gen.quests.fill(CHATTER[(i - 2) % #CHATTER + 1], d.quest and d.quest.words or {})
      w:npc_at(p, function()
        dialogue.say({ speaker = "villager", name = p.name, text = line, color = { 0.85, 0.85, 1 } })
      end)
    end
    LQ.start(w, node, gen.cosmos)
    local v = d.spots.van
    story.place_van(w, v.x, v.z, v.yaw)
    return story.van_door.x, story.van_door.z, story.van_door.yaw
  end,
  update = function(w, dt) LQ.update(w, dt) end,
})
