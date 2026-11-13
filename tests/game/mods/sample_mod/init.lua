-- Example mod used by tests/game/test_mods.lua and docs/MODDING.md.
local world = require("lib.world")
local story = require("lib.story")
world.register({
  id = "sample_meadow",
  name = "Sample Meadow",
  destination = true,
  order = 10,
  build = function(w)
    w:ground("grass", 60, 30)
    w:sprite({ texture = "tree_oak", x = 3, z = -5, w = 3, h = 4, radius = 0.4 })
    story.place_van(w, 0, 4, 0)
    return story.van_door.x, story.van_door.z, story.van_door.yaw
  end,
})
