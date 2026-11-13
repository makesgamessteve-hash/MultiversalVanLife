-- Pause menu: toggles touch controls and offers VR when WebXR is available.
H.new_game_in_van()
test.set_xr(true, false, 0)
test.press("menu")
test.eq(game.state, "pause", "paused")
local menu = game.debug.pause_menu()
local has_vr = false
for _, it in ipairs(menu.items) do if it.label == "Enter VR" then has_vr = true end end
test.expect(has_vr, "VR entry offered")
H.choose(menu, "Touch controls")
test.expect(mvl.touch(), "touch toggled on")
H.choose(game.debug.pause_menu(), "Enter VR")
local _, active = mvl.xr()
test.eq(game.state, "play", "resumed")
-- simulated XR session: head yaw changes the walking direction
test.set_xr(true, true, math.pi / 2)
local p = game.debug.player
p.place(0, 2.5, 0)
test.hold("move_y", 30)
test.expect(p.x < -0.5, "walks where the head looks: " .. p.x .. "," .. p.z .. " " .. tostring(p.enabled) .. " " .. tostring(game.debug.dialogue.active()) .. " " .. game.state)
test.set_xr(true, false, 0)
