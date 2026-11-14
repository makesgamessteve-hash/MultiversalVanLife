-- Time passes in visited places: ten nights after the player brought a
-- village's spring back to life, there are new fields and new families and
-- people talk about it; the town the player saved raised a monument of the
-- player and the van; a village the player gave up on declined.
local D = game.debug
local A = require("memory.aftermath")

local function visit(addr)
  if H.current() ~= "van" then H.use("Enter the van") H.finish_dialogue() end
  H.travel_to(addr)
  H.step_outside()
end

local function talk_to(name)
  H.use("Talk to " .. name)
  return H.collect_lines()
end

local function nights(n) for _ = 1, n do D.progress.end_night() end end

H.new_game_in_van(4242)
local addr = H.land_where(function(t, list)
  return t.kind == "restore" and list[1].source ~= "magic" and list[1].severity >= 0.5
end)
test.expect(addr, "a village whose spring is failing")
visit(addr)
local w = D.world.current
local before = w.land_node.data
local people0, fields0 = #before.people, #(before.fields or {})
test.expect(w.state.quest.q.source.water, "a spring of water")
test.expect(H.complete_quest(), "the spring is restored")
local log = w:memory()
test.eq(log.clock.visits, 1, "the land's clock counts the visit")
local night0 = D.progress.night()

-- the next night nothing has changed yet
local other = H.land_with("gather")
visit(other)
nights(1)
visit(addr)
test.eq(#D.world.current.land_node.data.people, people0, "a night later, nothing new")

-- ten nights later
visit(other)
nights(9)
test.eq(D.progress.night() - night0, 10, "ten nights later")
visit(addr)
w = D.world.current
local d = w.land_node.data
log = w:memory()
test.expect(log.clock.days >= 70, "about ten weeks passed there: " .. log.clock.days .. " days")
test.expect(#d.fields > fields0, "new fields: " .. fields0 .. " -> " .. #d.fields)
test.expect(#d.people > people0, "new villagers: " .. people0 .. " -> " .. #d.people)
local newcomer
for _, p in ipairs(d.people) do if p.newcomer then newcomer = p end end
test.expect(newcomer and newcomer.name, "a newcomer with a name of the people")
test.expect(H.find("Talk to " .. newcomer.name), "who can be talked to")
-- people talk about the change
local said = table.concat(talk_to(d.people[2].name), " ")
local about = false
for _, news in ipairs(log.aftermath.news) do if said:find(news, 1, true) then about = true end end
test.expect(about, "a villager talks about the change: " .. said)
local again = table.concat(talk_to(d.people[2].name), " ")
test.expect(again ~= said, "and does not repeat it")
-- the aftermath is history: events of the land
local events = {}
for _, e in ipairs(log.events or {}) do events[#events + 1] = e.text end
test.expect(#events >= 2, "the land's history grows: " .. table.concat(events, "; "))

-- ------------------------------------------------------------ monument
local monument, van
for _, f in pairs(log.placed) do
  if f.mark == "monument" then monument = f end
  if f.mark == "monument_van" then van = f end
end
test.expect(monument and van, "the saved town raised a monument of the player and the van")
test.expect(monument.statue and monument.statue.anatomy.hands == 2, "a statue of the player")
test.eq(van.voxel, "van", "and their van in stone")
D.player.place(monument.x + 3, monument.z + 3, 0)
test.until_true(function() return w.streamer.spawned[monument.id] ~= nil end, 600, "the monument's chunk is built")
local carved = false
for _, e in pairs(w.streamer.models.entries) do if e.key:find("^statue:") and e.key:find("statue of", 1, true) then carved = true end end
test.expect(carved, "the statue is a voxel model")
test.expect(w.streamer.spawned[van.id], "the stone van stands next to it")
-- the aftermath is applied once: coming back again changes nothing more
local placed = 0
for _ in pairs(log.placed) do placed = placed + 1 end
visit(other)
visit(addr)
local placed2 = 0
for _ in pairs(D.world.current:memory().placed) do placed2 = placed2 + 1 end
test.eq(placed2, placed, "marks are made once")

-- --------------------------------------------------------- decline
local gave = H.land_where(function(t) return t.kind == "gather" end)
visit(gave)
w = D.world.current
local giver = w.land_node.data.people[1]
talk_to(giver.name)
H.use("Talk to " .. giver.name)
H.finish_dialogue()
H.choose(D.story.menu, "give up")
H.finish_dialogue()
local n0 = #w.land_node.data.people
visit(other)
nights(4)
visit(gave)
w = D.world.current
test.expect(#w.land_node.data.people < n0, "a family moved away")
local ruined
for id, o in pairs(w:memory().objects) do if o.ruined then ruined = id end end
test.expect(ruined, "a house fell into ruin")
test.expect(H.find("Talk to " .. giver.name), "the giver stayed")
