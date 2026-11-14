-- Choices with lasting outcomes: settling a water dispute for the upstream
-- village makes it grateful and the downstream village resentful, on every
-- later visit and after a restart; giving up on a quest is remembered too.
local D = game.debug
local story = D.story
local characters = require("memory.characters")

local function restart()
  D.open_pause()
  H.choose(D.pause_menu(), "Save and return")
  H.choose(D.title_menu(), "Continue")
  H.finish_dialogue()
end

local function visit(addr)
  if H.current() ~= "van" then H.use("Enter the van") H.finish_dialogue() end
  H.travel_to(addr)
  H.step_outside()
end

local function talk_to(name)
  H.use("Talk to " .. name)
  return H.collect_lines()
end

-- ----------------------------------------------- a dispute over water
H.new_game_in_van(2121)
local addr = H.land_where(function(t, list)
  return t.kind == "mediate" and list and list[1].issue and list[1].issue:find("water", 1, true) ~= nil
end)
test.expect(addr, "a land quarrels over water")
visit(addr)
local w = D.world.current
local d = w.land_node.data
local q = w.state.quest.q
test.eq(q.kind, "mediate", "a quarrel to settle")
local up, down
for _, party in ipairs(q.parties) do
  if party.label:find("upstream", 1, true) then up = party else down = party end
end
test.expect(up and down, "between upstream and downstream: " .. q.parties[1].label .. " / " .. q.parties[2].label)
local people = {}
for _, p in ipairs(d.people) do people[p.id] = p end
local up_person, down_person = people[up.person], people[down.person]

-- the giver explains, both sides are heard, then the player decides
local intro = talk_to(d.people[1].name)
test.expect(table.concat(intro, " "):find(q.issue, 1, true), "the giver tells what the quarrel is about")
local claim = talk_to(up_person.name)
test.expect(claim[1]:find(up.label, 1, true), "each speaks for their side: " .. claim[1])
test.eq(story.menu, nil, "no decision before both sides are heard")
talk_to(down_person.name)
test.expect(story.menu and story.menu.title == "SETTLE THE QUARREL", "then the player decides")
H.choose(story.menu, "Side with " .. require("lib.landquest").short(up.label))
H.finish_dialogue()
local s = w.state.quest
test.expect(s.complete and s.result == (up == q.parties[1] and "a" or "b"), "the quarrel is settled for upstream")
test.expect(D.progress.helped(addr), "the land counts as helped")
local log = w:memory()
test.eq(log.outcome.favoured, up.label, "the outcome is remembered: who was favoured")
test.eq(log.outcome.wronged, down.label, "and who was wronged")
test.expect(characters.reputation(up.label) > 0 and characters.reputation(down.label) < 0,
            "the parties' opinion of the player changes")

-- later visits, and a restart
for round = 1, 2 do
  visit(H.land_with("relight") or H.land_with("gather"))
  if round == 2 then restart() end
  visit(addr)
  local thanks = talk_to(up_person.name)
  test.expect(thanks[1]:lower():find("peacemaker", 1, true) and thanks[1]:find("gave " .. q.issue .. " to us", 1, true),
              "upstream is grateful (visit " .. round .. "): " .. thanks[1])
  local grudge = talk_to(down_person.name)
  test.eq(#grudge, 1, "downstream has little to say")
  test.expect(grudge[1]:find("gave " .. q.issue .. " to " .. up.label, 1, true),
              "downstream resents the player (visit " .. round .. "): " .. grudge[1])
  test.eq(story.menu, nil, "the quarrel stays settled")
end

-- ------------------------------------------------------- giving up
local gaddr = H.land_with("gather")
visit(gaddr)
w = D.world.current
s = w.state.quest
local giver = w.land_node.data.people[1]
talk_to(giver.name)
H.use("Pick up the")
H.finish_dialogue()
H.use("Talk to " .. giver.name)
H.finish_dialogue()
test.expect(story.menu, "talking mid-quest offers to give up")
H.choose(story.menu, "give up")
H.finish_dialogue()
test.expect(s.complete and s.result == "abandoned", "the quest is given up")
test.expect(not D.progress.helped(gaddr), "the land is not helped")
test.eq(w:memory().outcome.result, "abandoned", "and that is remembered")
test.eq(H.find("Pick up the"), nil, "the trouble's items are gone")
visit(addr)
visit(gaddr)
local cold = talk_to(giver.name)
test.expect(cold[1]:find("gave up on us", 1, true), "the giver remembers: " .. cold[1])
test.eq(D.world.current.state.quest.result, "abandoned", "a given up quest stays given up")
