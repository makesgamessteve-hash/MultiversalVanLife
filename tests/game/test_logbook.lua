-- The road atlas in the cab lists the visited lands and takes the van back to them.
local D = game.debug
local story = D.story
H.new_game_in_van(31337)
H.use("atlas")
test.eq(story.menu.title, "ATLAS", "the atlas opened")
test.eq(#story.menu.items, 2, "no places in the atlas at first, only the codex and closing it")
story.menu = nil
local s1, s2 = story.signals()[1], story.signals()[2]
H.travel(s1.name)
H.travel(s2.name)
test.eq(D.progress.location(), "land:" .. s2.address, "at the second land")
test.eq(#D.progress.logbook(), 2, "two lands visited")
H.use("atlas")
local entries = story.menu.items
test.eq(story.menu.title, "ATLAS", "the atlas opened")
test.expect(entries[1].label:find(s1.name, 1, true) and entries[1].enabled, "the first land can be revisited")
test.expect(entries[2].label:find(s2.name, 1, true) and not entries[2].enabled, "the current land is disabled")
H.choose(story.menu, s1.name)
test.until_true(function() return not story.busy end, 1200, "arrived")
test.eq(D.progress.location(), "land:" .. s1.address, "back at the first land")
test.expect(H.said(H.collect_lines(), "van_welcome_back"), "Juniper welcomes us back")
test.eq(#D.progress.logbook(), 2, "no duplicate entries in the atlas")
