-- The garden: from the conservatory the open door shows the garden (its
-- grass and its sky); in the garden, a sunny sky over the lawn and the
-- path; and the back of the house whose door shows the conservatory.
local D = game.debug
D.progress.reset(20261115)
D.start(false)
D.progress.set_flag("van_met")
D.van.enter(D.player, D.world)
D.dialogue.skip_all()
D.hud.card = nil
game.draw_ui = function() end
local P = D.van.P
local pl = D.player
pl.base_y = P[2]
pl.place(P[1] - 9, P[3] - 8.75, math.pi / 2)
pl.pitch = 0.05
for _ = 1, 40 do test.wait(1) end
test.screenshot("door.tga")
test.wait(3)
D.van.to_garden(pl)
pl.place(pl.x - 2, pl.z, math.pi / 2)
pl.pitch = 0
for _ = 1, 60 do test.wait(1) end
test.screenshot("garden.tga")
test.wait(3)
pl.place(-6, 0, -math.pi / 2)
pl.base_y = D.van.garden.height(-6, 0)
pl.pitch = 0.1
for _ = 1, 10 do test.wait(1) end
test.screenshot("back.tga")
test.wait(3)
