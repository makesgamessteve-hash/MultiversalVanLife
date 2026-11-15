-- The house inside the van: the library's shelves full of books, the
-- kitchen's long table and the bedroom upstairs, all lit by their lamps
-- (no gaps in the rooms' surfaces, no sky showing through).
local D = game.debug
D.progress.reset(20261115)
D.start(false)
D.progress.set_flag("van_met")
D.van.enter(D.player, D.world)
D.dialogue.skip_all()
D.hud.card = nil
game.draw_ui = function() end
local P = D.van.P
local function view(file, x, z, yaw, pitch, level)
  D.player.base_y = P[2] + (level or 0)
  D.player.place(P[1] + x, P[3] + z, yaw)
  D.player.pitch = pitch
  test.wait(4)
  test.screenshot(file)
  test.wait(3)
end
view("library.tga", 4.0, 6.5, -math.pi * 0.85, 0.12)       -- towards the shelves on the far wall
view("kitchen.tga", 3.0, -6.25, -math.pi * 0.3, -0.12)     -- the table and the range
view("bedroom.tga", 9.0, -6.0, -0.3, -0.15, require("gen.house.plan").LEVEL)
