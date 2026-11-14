-- Pause menu: toggles touch controls, offers VR when WebXR is available and
-- opens the codex, which also works during a VR session.
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
-- the codex: in the pause menu, and usable in a VR session too
test.press("menu")
test.eq(game.state, "pause", "paused again")
local labels = {}
for _, it in ipairs(game.debug.pause_menu().items) do labels[#labels + 1] = it.label end
test.eq(labels[1], "Resume", "resume first")
test.eq(labels[2], "Codex", "then the codex")
H.choose(game.debug.pause_menu(), "Codex")
local C = game.debug.codex
test.expect(C.active and game.state == "play", "the codex opens from the pause menu")
test.press("back")
test.expect(not C.active, "and closes")
test.set_xr(true, true, 0)
test.press("codex")
test.expect(C.active, "the codex action opens it in VR")
test.press("right")
test.eq(C.TABS[C.tab].id, "places", "the controller moves between tabs")
local x0, z0 = p.x, p.z
test.hold("move_y", 20)
test.expect(math.abs(p.x - x0) + math.abs(p.z - z0) < 0.01, "the player does not walk while reading")
test.press("codex")
test.expect(not C.active, "and the same action closes it")
test.set_xr(true, false, 0)
test.press("menu")
H.choose(game.debug.pause_menu(), "Resume")
test.eq(game.state, "play", "resumed")
