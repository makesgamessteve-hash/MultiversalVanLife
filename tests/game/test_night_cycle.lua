-- Going home ends the night; every third land helped is celebrated;
-- progress survives a save/continue round trip.
local D = game.debug
local prog = D.progress
local story = D.story
H.new_game_in_van(4)
H.travel("Signal")
-- the console offers going home when away
H.use("console")
H.finish_dialogue()
local labels = {}
for _, it in ipairs(story.menu.items) do labels[#labels + 1] = it.label end
test.expect(table.concat(labels, ","):find("Home", 1, true), "home option offered")
test.expect(table.concat(labels, ","):find("Not yet", 1, true), "cancel offered")
test.press("back")
test.eq(story.menu, nil, "menu closed with back")
-- two lands helped: no milestone yet
prog.set_helped("u5.g1.c0.s0.p0.k0.n0.l1")
prog.set_helped("u5.g1.c0.s0.p0.k0.n0.l2")
H.use("console")
H.finish_dialogue()
H.choose(story.menu, "Home")
test.until_true(function() return not story.busy end, 1200, "home")
local lines = H.collect_lines()
test.expect(H.said(lines, "van_home") and not H.said(lines, "van_milestone"), "home line, no milestone yet")
test.eq(prog.night(), 2, "night advanced")
test.eq(prog.location(), "home", "home again")
-- the third land helped: Juniper celebrates on the way home
H.travel("Signal")
prog.set_helped("u5.g1.c0.s0.p0.k0.n0.l3")
prog.set_helped("u5.g1.c0.s0.p0.k0.n0.l3") -- counted once
test.eq(prog.helped_total(), 3, "three lands helped")
H.use("console")
H.finish_dialogue()
H.choose(story.menu, "Home")
test.until_true(function() return not story.busy end, 1200, "home")
local said = H.collect_lines()
test.expect(H.said(said, "van_home") and H.said(said, "van_milestone"), "the milestone line: " .. table.concat(said, ","))
test.eq(prog.night(), 3, "night advanced again")
-- save / continue
D.open_pause()
H.choose(D.pause_menu(), "Save and return")
test.eq(game.state, "title", "back on title")
local menu = D.title_menu()
test.expect(menu.items[1].enabled ~= false, "continue enabled")
H.choose(menu, "Continue")
test.eq(game.state, "play", "continued")
test.eq(prog.night(), 3, "night restored")
test.eq(prog.helped_total(), 3, "helped lands restored")
test.eq(H.current(), "van", "continue starts in the van")
