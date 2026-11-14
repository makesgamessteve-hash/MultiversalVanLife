-- People remember the player: whom they met, what the player did for them,
-- and the name their community knows the player by, across leaving the
-- land and restarting the game.
local D = game.debug
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

H.new_game_in_van(3131)
local addr = H.land_with("relight")
test.expect(addr, "a land whose lights went out")
visit(addr)
local w = D.world.current
local d = w.land_node.data
local giver, other = d.people[1], d.people[2]
-- a stranger at first, then someone they have met
local first = talk_to(other.name)
local again = talk_to(other.name)
test.expect(#first >= 2 and #again >= 2, "villagers talk")
test.expect(first[1] ~= again[1], "and greet an acquaintance differently: " .. first[1] .. " / " .. again[1])
test.eq(characters.get(w:memory(), other.id).talks, 2, "they remember talking twice")
test.expect(H.complete_quest(), "the lamps are lit again")
local deed = w:memory().community.deed
test.expect(deed and deed:find("lit our", 1, true), "the community remembers the deed: " .. tostring(deed))
test.eq(w:memory().community.known_as, "the Lamplighter", "and gives the player a name")

-- leave, restart, come back
visit(H.land_with("gather"))
restart()
visit(addr)
local hello = talk_to(giver.name)
test.expect(hello[1]:lower():find("the lamplighter", 1, true), "the giver greets the player by their name: " .. hello[1])
test.expect(hello[1]:find(deed, 1, true), "and mentions the help")
local hi = talk_to(other.name)
test.expect(hi[1]:lower():find("the lamplighter", 1, true), "so does the rest of the village: " .. hi[1])
test.expect(characters.get(D.world.current:memory(), giver.id).favour > 0, "the giver's favour")
-- a different village does not know the player
local elsewhere = H.land_with("return")
visit(elsewhere)
local stranger = talk_to(D.world.current.land_node.data.people[1].name)
test.expect(not table.concat(stranger, " "):lower():find("lamplighter", 1, true), "strangers elsewhere: " .. stranger[1])
