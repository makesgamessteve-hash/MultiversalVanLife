-- Touch controls: a virtual stick moves the player, the USE button interacts
-- and the on-screen controls are drawn.
H.new_game_in_van()
test.expect(not mvl.touch(), "touch off by default")
local p = game.debug.player
p.place(-3.2, 0, -math.pi / 2)
local q0 = test.ui_quads()
test.touch("down", 1, 0.2, 0.75)
test.wait(1)
test.touch("move", 1, 0.2, 0.55) -- push the stick up = forward
test.wait(30)
test.expect(mvl.touch(), "touch enabled by first finger")
test.expect(p.x > -2.5, "player moved forward with the stick")
test.expect(test.ui_quads() > q0, "touch controls drawn")
test.touch("up", 1)
-- look by dragging on the right half
local yaw0 = p.yaw
test.touch("down", 2, 0.7, 0.4)
test.touch("move", 2, 0.75, 0.4)
test.wait(2)
test.touch("up", 2)
test.expect(p.yaw ~= yaw0, "dragging turned the camera")
-- USE button (bottom right) talks to the console
H.face(0, 0, 1.4)
local aspect = 16 / 9
local bx = (aspect - 0.17) / aspect
test.touch("down", 3, bx, 0.78)
test.wait(2)
test.touch("up", 3)
test.wait(2)
test.expect(game.debug.story.menu ~= nil, "console opened via touch")
