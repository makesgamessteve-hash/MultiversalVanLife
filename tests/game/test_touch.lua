-- Touch controls: a virtual stick moves the player, the USE button interacts,
-- the on-screen controls are drawn and menus can be tapped.
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
-- menus can be tapped: the console (once Juniper has spoken), then the pause menu
H.finish_dialogue()
local menu = game.debug.story.menu
test.wait(2)
local w, h = mvl.ui_size()
local function tap_item(m, i)
  local r = m.rects[i]
  test.touch("down", 4, (r[1] + r[3] / 2) / w, (r[2] + r[4] / 2) / h)
  test.wait(1)
  test.touch("up", 4)
  test.wait(2)
end
local not_yet
for i, it in ipairs(menu.items) do if it.label == "Not yet" then not_yet = i end end
tap_item(menu, not_yet)
test.eq(game.debug.story.menu, nil, "tapping 'Not yet' closes the console")
game.debug.open_pause()
test.wait(2)
local pm = game.debug.pause_menu()
tap_item(pm, 1)
test.eq(game.state, "play", "tapping Resume resumes")
-- a drag across a menu is not a tap
game.debug.open_pause()
test.wait(2)
pm = game.debug.pause_menu()
local r = pm.rects[1]
test.touch("down", 5, (r[1] + r[3] / 2) / w, (r[2] + r[4] / 2) / h)
test.touch("move", 5, (r[1] + r[3] / 2) / w + 0.2, (r[2] + r[4] / 2) / h + 0.2)
test.wait(1)
test.touch("up", 5)
test.wait(2)
test.eq(game.state, "pause", "dragging does not choose")
