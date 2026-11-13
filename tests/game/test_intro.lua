-- Night 1: the van calls out, the player walks in, meets Juniper and flies
-- to one of tonight's signals, then steps outside into the new world.
H.new_game()
test.eq(H.current(), "home", "at home")
test.until_true(function() return game.debug.dialogue.active() end, 300, "the van calls")
test.eq(game.debug.dialogue.current.id, "van_call_1", "first line")
H.finish_dialogue()

-- walk a few steps with real movement input
local p = game.debug.player
local x0, z0 = p.x, p.z
test.hold("move_y", 40)
test.expect(math.abs(p.x - x0) + math.abs(p.z - z0) > 1.0, "player walked forward")

H.use("Enter the van")
H.wait_idle()
test.eq(H.current(), "van", "inside the van")
test.expect(game.debug.progress.flag("van_met"), "van met flag")
test.until_true(function() return game.debug.dialogue.active() end, 60, "intro starts")
test.eq(game.debug.dialogue.current.id, "van_intro_1", "intro line")
H.finish_dialogue()

H.travel("Signal")
test.expect(game.debug.progress.location():find("^land:u%d+"), "location saved")
H.step_outside()
test.eq(H.current(), "land", "outside in the generated land")
