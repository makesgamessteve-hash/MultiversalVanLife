-- The Wanderer's chronicle: the codex keeps a chronicle of the player's
-- deeds, with the places and the consequences they led to, updated
-- whenever a consequence develops.
local D = game.debug
local C = D.codex

local function visit(addr)
  if H.current() ~= "van" then H.use("Enter the van") H.finish_dialogue() end
  H.travel_to(addr)
  H.step_outside()
end

H.new_game_in_van(8181)
test.eq(#C.chronicle(), 0, "no deeds yet")
local addr = H.land_with("relight")
visit(addr)
local name = D.world.current.land_node.data.name
test.expect(H.complete_quest(), "the lamps are lit")
local deeds = C.chronicle()
test.eq(#deeds, 1, "the deed is in the chronicle")
local entry = deeds[1]
test.expect(entry.name:find("Lamplighter", 1, true) and entry.name:find(name, 1, true), "named by title and place: " ..
            entry.name)
test.expect(entry.text:find("lit our", 1, true), "it tells the deed: " .. entry.text)
test.eq(entry.links[1], addr, "linked to the place")
test.eq(#entry.consequences, 0, "nothing has come of it yet")

-- the codex shows it, linked to the place
C.open()
C.set_tab(#C.TABS)
test.eq(C.TABS[C.tab].id, "chronicle", "the chronicle tab")
test.eq(#C.list, 1, "one deed")
C.show(C.list[1].id)
local body = table.concat(C.body(C.entry, C.mode), "\n")
test.expect(body:find("Nothing has come of it yet", 1, true), "no consequence yet")
local to_place
for _, it in ipairs(C.items()) do if it.kind == "link" and it.label == name then to_place = it end end
test.expect(to_place, "the deed links to the place")
to_place.action()
test.eq(C.entry.kind, "place", "following it opens the place")
C.close()

-- consequences develop while the player is away, and show on a revisit
local other = H.land_with("gather")
visit(other)
for _ = 1, 4 do D.progress.end_night() end
test.eq(#C.chronicle()[1].consequences, 0, "the chronicle only knows what the player saw")
visit(addr)
local now = C.chronicle()[1]
test.expect(#now.consequences > 0, "the revisit logs the consequences")
local text = table.concat(now.consequences, " ")
test.expect(text:find("the good years after", 1, true), "the land's good years: " .. text)
test.expect(text:find("since you", 1, true), "and what people say about it: " .. text)
C.open()
C.set_tab(#C.TABS)
C.show(C.list[1].id)
body = table.concat(C.body(C.entry, C.mode), "\n")
test.expect(body:find("the good years after", 1, true), "the chronicle entry lists the new consequence:\n" .. body)
C.close()
-- more deeds, in order
visit(other)
test.expect(H.complete_quest(), "another deed")
test.eq(#C.chronicle(), 2, "two deeds")
test.expect(C.chronicle()[2].name:find("Finder", 1, true), "the second one: " .. C.chronicle()[2].name)
