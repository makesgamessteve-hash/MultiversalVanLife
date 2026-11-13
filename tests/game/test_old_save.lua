-- A save from before the save folder existed (a single savegame.ini, see
-- tests/game/saves/test_old_save) is converted and continues where it was.
local D = game.debug
test.eq(game.state, "title", "title screen")
local menu = D.title_menu()
test.expect(menu.items[1].enabled, "Continue is offered for the old save")
H.choose(menu, "Continue")
test.eq(game.state, "play", "playing")
test.eq(D.progress.night(), 3, "night kept")
test.expect(D.progress.flag("van_met"), "the van was met")
test.expect(D.progress.helped("fen"), "Lanternfen was helped")
test.eq(D.world.current.def.id, "market", "parked at the market")
test.eq(H.current(), "van", "the session begins in the van")
-- the converted index is the save from now on
test.eq(mvl.save_get("story.location"), "market", "index holds the old keys")
H.finish_dialogue()
H.travel("Lanternfen")
test.eq(mvl.save_get("story.location"), "fen", "progress is saved to the new index")
