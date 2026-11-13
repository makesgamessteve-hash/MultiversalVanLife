-- Looking out of the van's front window shows the world in front of the
-- parked van; while travelling the window shows the vortex.
local D = game.debug
D.start(true)
D.progress.set_flag("van_met")
D.van.enter(D.player, D.world)
D.dialogue.skip_all()
D.hud.card = nil
game.draw_ui = function() end
-- a blue marker 6 m in front of the van's windscreen (the van at home faces -Z)
local e = D.van.exterior
local fx, fz = math.cos(e.yaw), -math.sin(e.yaw)
mvl.spawn({ mesh = mvl.box_mesh(2.5, 3.5, 1), pos = { e.x + fx * 9, 0, e.z + fz * 9 }, yaw = e.yaw,
            color = { 0, 0, 1, 1 }, unlit = true, nofog = true })
local P = D.van.P
D.player.place(P[1] + 2.4, P[3], -math.pi / 2)    -- facing the front window
D.player.pitch = -0.2
test.wait(10)
test.screenshot("window.tga")
test.wait(3)
D.story.travel("fen")
test.wait(30)
test.screenshot("travel.tga")
test.wait(3)
