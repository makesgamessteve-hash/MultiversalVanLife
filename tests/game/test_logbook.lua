-- The logbook lists visited lands and takes the van back to them.
local D = game.debug
local story = D.story
H.new_game_in_van(31337)
H.use("console")
H.finish_dialogue()
local logbook
for _, it in ipairs(story.menu.items) do if it.label == "Logbook" then logbook = it end end
test.expect(logbook and not logbook.enabled, "the logbook is empty at first")
story.menu = nil
local s1, s2 = story.signals()[1], story.signals()[2]
H.travel(s1.name)
H.travel(s2.name)
test.eq(D.progress.location(), "land:" .. s2.address, "at the second land")
test.eq(#D.progress.logbook(), 2, "two lands visited")
H.use("console")
H.finish_dialogue()
H.choose(story.menu, "Logbook")
local entries = story.menu.items
test.eq(story.menu.title, "LOGBOOK", "the logbook opened")
test.expect(entries[1].label:find(s1.name, 1, true) and entries[1].enabled, "the first land can be revisited")
test.expect(entries[2].label:find(s2.name, 1, true) and not entries[2].enabled, "the current land is disabled")
H.choose(story.menu, s1.name)
test.until_true(function() return not story.busy end, 1200, "arrived")
test.eq(D.progress.location(), "land:" .. s1.address, "back at the first land")
test.expect(H.said(H.collect_lines(), "van_welcome_back"), "Juniper welcomes us back")
test.eq(#D.progress.logbook(), 2, "no duplicate logbook entries")
