-- Going home ends the night; after all three worlds Juniper celebrates;
-- progress survives a save/continue round trip.
H.new_game_in_van()
local prog = game.debug.progress
H.travel("Lanternfen")
-- the console offers going home when away
local story = game.debug.story
H.use("console")
H.finish_dialogue()
local labels = {}
for _, it in ipairs(story.menu.items) do labels[#labels + 1] = it.label end
test.expect(table.concat(labels, ","):find("Home", 1, true), "home option offered")
test.press("back")
test.eq(story.menu, nil, "menu closed with back")
prog.set_helped("fen"); prog.set_helped("market"); prog.set_helped("library")
H.travel("Home")
test.eq(prog.night(), 2, "night advanced")
test.eq(prog.location(), "home", "home again")
-- the last travel queued van_home + van_all_done; H.travel finished them
test.expect(story.all_helped(), "everyone helped")
-- save / continue
game.debug.open_pause()
H.choose(game.debug.pause_menu(), "Save and return")
test.eq(game.state, "title", "back on title")
local menu = game.debug.title_menu()
test.expect(menu.items[1].enabled ~= false, "continue enabled")
H.choose(menu, "Continue")
test.eq(game.state, "play", "continued")
test.eq(prog.night(), 2, "night restored")
test.eq(H.current(), "van", "continue starts in the van")
