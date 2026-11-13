-- A save from before the save folder existed (a single savegame.ini, see
-- tests/game/saves/test_old_save), parked at a handmade destination that no
-- longer exists, is converted and continues at home without losing progress.
local D = game.debug
test.eq(game.state, "title", "title screen")
local menu = D.title_menu()
test.expect(menu.items[1].enabled, "Continue is offered for the old save")
H.choose(menu, "Continue")
test.eq(game.state, "play", "playing")
test.eq(D.progress.night(), 3, "night kept")
test.expect(D.progress.flag("van_met"), "the van was met")
test.expect(D.progress.helped("fen"), "old helped places are kept")
test.eq(D.world.current.def.id, "home", "a removed destination continues at home")
test.eq(H.current(), "van", "the session begins in the van")
test.eq(mvl.save_get("story.location"), "home", "the location was moved home")
test.expect(D.progress.seed() > 0, "an old save gets a multiverse seed")
H.finish_dialogue()
H.travel("Signal")
test.expect(mvl.save_get("story.location"):find("^land:"), "progress is saved to the new index")
