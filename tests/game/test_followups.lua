-- Revisits: a town that founded a festival in the player's honour invites
-- them, and a land whose new trouble was caused by the player's help calls
-- them back; the signals keep a slot for such calls.
local D = game.debug
local story = D.story
local spread = require("memory.spread")

local function visit(addr)
  if H.current() ~= "van" then H.use("Enter the van") H.finish_dialogue() end
  H.travel_to(addr)
  H.step_outside()
end

local function nights(n) for _ = 1, n do D.progress.end_night() end end

local function signal_for(addr)
  for _, s in ipairs(story.signals()) do if s.address == addr then return s end end
end

H.new_game_in_van(5353)
local addr
for _, s in ipairs(story.signals()) do
  if s.peopled and not addr then
    local base = s.address:match("^(.*)%.l%d+$")
    for _, a in ipairs(H.settled_lands(base, s.address:match("^(.-%.p%d+)"))) do
      local t, list = D.gen.history.tensions.trouble(D.gen.world, a)
      if not addr and t.kind == "relight" and list[1].severity >= 0.5 then addr = a end
    end
  end
end
test.expect(addr, "a town of a people in serious trouble")
visit(addr)
test.expect(D.world.current.land_node.data.culture, "with a culture of its own")
test.expect(H.complete_quest(), "the player saves the town")
local night0 = D.progress.night()
local planned = {}
for _, f in ipairs(spread.followups()) do if f.address == addr then planned[f.kind] = f end end
test.expect(planned.invitation and planned.need, "an invitation and a new need are on their way")

local other = H.land_with("gather")
visit(other)
nights(2)
test.eq(signal_for(addr), nil, "two nights later nobody calls yet")

-- ------------------------------------------------------------- invitation
nights(1)
local inv = signal_for(addr)
test.expect(inv and inv.followup == "invitation", "three nights later the town invites the player")
test.expect(#story.signals() == 3, "still three signals a night")
test.expect(D.gen.signals.describe(inv):find("An invitation from", 1, true), "Juniper reads the invitation: " ..
            D.gen.signals.describe(inv))
test.expect(inv.text:find("Feast of the Lamplighter", 1, true), "to the feast in the player's honour: " .. inv.text)
visit(addr)
local w = D.world.current
local lanterns = 0
for _, f in pairs(w:memory().placed) do if f.mark == "festival" then lanterns = lanterns + 1 end end
test.expect(lanterns >= 4, "lanterns hang around the square for the feast")
H.use("Talk to " .. w.land_node.data.people[2].name)
local said = table.concat(H.collect_lines(), " ")
test.expect(said:find("Feast of the Lamplighter", 1, true) or said:find("since you", 1, true),
            "the villagers talk about it: " .. said)
test.eq(#spread.due(D.progress.night()), 0, "the invitation is answered")
visit(other)
nights(1)
test.eq(signal_for(addr), nil, "and not repeated")

-- --------------------------------------------------------------- called back
nights(1)
local need = signal_for(addr)
test.expect(need and need.followup == "need", "the town calls the player back: " .. tostring(need and need.text))
test.expect(D.gen.signals.describe(need):find("calling us back", 1, true), "Juniper tells why")
visit(addr)
w = D.world.current
local q = w.state.quest.q
test.eq(q.chapter, 2, "a new chapter of the town's story")
test.eq(q.tension, need.text, "the new trouble, caused by the player's help")
test.expect(not w.state.quest.complete, "not solved yet")
H.use("Talk to " .. w.land_node.data.people[1].name)
local intro = table.concat(H.collect_lines(), " ")
test.expect(intro:lower():find("since the lamps were lit again", 1, true), "the giver tells how it came from the help: " ..
            intro)
test.expect(H.complete_quest(), "and the player helps again")
test.eq(#spread.due(D.progress.night()), 0, "the need is answered")
visit(other)
nights(3)
test.eq(signal_for(addr), nil, "no more calls")
-- a restart keeps everything
visit(addr)
test.expect(D.world.current.state.quest.complete and D.world.current.state.quest.q.chapter == 2,
            "the second chapter stays solved")
