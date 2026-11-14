-- A mod adds a new kind of trouble; newly generated lands can have it and
-- it can be solved like any other. It also adds a saying to the dialogue
-- grammar, which villagers use, generation content (a pass putting wild
-- moonberries by every settlement) and an aftermath rule leaving a mark.
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
-- the land remembers the mod's deed
test.eq(w:memory().community.deed, "saved the moonberry harvest", "the mod's deed is remembered")
-- the mod's saying is part of the grammar and villagers say it
local grammar = D.gen.dialogue.grammar
local rules = grammar.rules(D.gen.cosmos)
local found = false
for _, alt in ipairs(rules.idiom) do if alt:find("Moonberries ripen", 1, true) then found = true end end
test.expect(found, "the mod's saying is in the grammar")
local said = 0
for n = 1, 200 do
  local lines = grammar.talk(D.gen.cosmos, w.land_node.data.lore, nil, 99, n)
  for _, l in ipairs(lines) do if l:find("Moonberries ripen", 1, true) then said = said + 1 end end
end
test.expect(said > 0, "villagers say it: " .. said .. " times in 200 talks")
-- the mod's aftermath rule leaves its mark a night later
local function visit(a)
  if H.current() ~= "van" then H.use("Enter the van") H.finish_dialogue() end
  H.travel_to(a)
  H.step_outside()
end
visit(H.land_with("relight") or H.land_with("return"))
D.progress.end_night()
visit(addr)
local mark
for _, f in pairs(D.world.current:memory().placed) do if f.mark == "moonberry bushes" then mark = f end end
test.expect(mark, "the mod's mark is in the land")
D.player.place(mark.x + 2, mark.z + 2, 0)
test.until_true(function() return D.world.current.streamer.spawned[mark.id] ~= nil end, 600, "and stands there")
test.eq(D.world.current:memory().aftermath.news[1], "moonberry bushes grow by the square now", "people talk about it")
-- the mod's generation pass: wild moonberries by every generated settlement
local bush
for _, f in ipairs(D.world.current.land_node.data.features) do if f.id == "moonberry_bush" then bush = f end end
test.expect(bush, "the mod's pass added content to the land")
D.player.place(bush.x + 1.5, bush.z + 1.5, 0)
test.until_true(function() return D.world.current.streamer.spawned["moonberry_bush"] ~= nil end, 600, "it stands there")
local found = false
for _, f in pairs(D.world.current.land_node.facts) do if f.data.name == "wild moonberries" then found = true end end
test.expect(found, "with a fact of the mod")
test.eq(#D.gen.check.run(D.gen.world), 0, "the checker accepts the mod's content")
-- Prime is left alone
local farm = D.gen.world:generate(D.gen.prime.FARM)
local on_farm = false
for _, f in ipairs(farm.data.features) do if f.id == "moonberry_bush" then on_farm = true end end
test.expect(not on_farm, "the farm in Prime has no wild moonberries")
