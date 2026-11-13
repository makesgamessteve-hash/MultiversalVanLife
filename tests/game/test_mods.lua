-- A mod adds a new kind of trouble; newly generated lands can have it and
-- it can be solved like any other.
local D = game.debug
local mods = mvl.mods()
test.eq(mods[1], "sample_mod", "mod enabled")
test.expect(D.gen.quests.template(D.gen.cosmos, "moonberries"), "the mod registered a quest template")
H.new_game_in_van(5150)
local addr = H.land_with("moonberries")
test.expect(addr, "a generated land has the mod's trouble")
H.travel_to(addr)
H.step_outside()
local w = D.world.current
test.eq(w.state.quest.q.template, "moonberries", "the land uses the mod's template")
local giver = w.land_node.data.people[1]
H.use("Talk to " .. giver.name)
test.expect(D.dialogue.current.text:find("moonberries", 1, true), "the mod's text is used")
H.finish_dialogue()
test.expect(H.find("Pick up the moonberry"), "the mod's items")
test.expect(H.complete_quest(), "the mod's quest can be completed")
test.expect(D.progress.helped(addr), "the land is helped")
-- generated places record the active mods
test.eq(w.land_node.mods[1], "sample_mod", "the land records the mod it was generated with")
