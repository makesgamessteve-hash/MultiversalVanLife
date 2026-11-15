-- A souvenir wing: after a visit, the hall of the people's wing in their
-- stone and colours, with a statue of one of them in the middle.
local D = game.debug
D.progress.reset(20261115)
D.start(false)
D.progress.set_flag("van_met")
D.van.enter(D.player, D.world)
D.dialogue.skip_all()
D.story.travel(D.story.signals()[1].address)
test.until_true(function() return not D.story.busy end, 1500, "arrived")
D.dialogue.skip_all()
D.hud.card = nil
game.draw_ui = function() end
local P = D.van.P
local plan = require("gen.house.plan")
local W = require("gen.house.wings")
local b = W.ORDER[1]
local hall
for _, r in ipairs(plan.block(D.progress.seed(), b[1], b[2])) do if r.statue then hall = r end end
test.expect(hall, "the wing's hall")
local x, z = (hall.x0 + hall.x1) / 2, hall.z0 + 1.5
D.player.base_y = P[2]
D.player.place(P[1] + x, P[3] + z, math.pi)
D.player.pitch = 0.12
D.van.house.fill(x, z)
test.wait(5)
test.screenshot("wing.tga")
test.wait(3)
