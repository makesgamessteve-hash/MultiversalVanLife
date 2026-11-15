-- Consequences spread: the player ends a feud in one land; people in the
-- next valley have heard of it and call the player by the title the story
-- gave them; the story reaches the rest of the planet later, and each
-- people tells it its own way.
local D = game.debug
local spread = require("memory.spread")
local characters = require("memory.characters")

local function visit(addr)
  if H.current() ~= "van" then H.use("Enter the van") H.finish_dialogue() end
  H.travel_to(addr)
  H.step_outside()
end

-- a land of a people (a feud if there is one)
local addr, any
for seed = 6464, 6480 do
  if addr or any then break end
  H.new_game_in_van(seed)
  for _, s in ipairs(D.story.signals()) do
    local paddr = s.address:match("^(.-%.p%d+)")
    for cid, c in ipairs(D.gen.world:generate(paddr).data.countries or {}) do
      if c.culture and not addr then
        for _, a in ipairs(H.country_lands(paddr, cid, 64)) do
          local tm, list = D.gen.history.tensions.trouble(D.gen.world, a)
          if tm.kind == "mediate" then
            any = any or a
            if list[1].kind == "feud" then addr = addr or a end
          end
        end
      end
    end
  end
end
addr = addr or any
test.expect(addr, "a land torn by a quarrel")
visit(addr)
local d = D.world.current.land_node.data
test.expect(H.complete_quest("compromise"), "the player ends the feud")
local deed = spread.deeds()[1]
test.eq(deed.address, addr, "the deed is remembered")
test.eq(deed.title, "the Peacemaker", "and the story gives the player a title")
test.expect(deed.fame >= 0.5, "a famous deed: " .. deed.fame)
if d.nation then test.expect(characters.reputation(d.nation) > 0, "the nation thinks well of the player") end

-- the next valley: another land of the same country
local planet = addr:match("^(.-%.p%d+)")
local P = D.gen.world:generate(planet)
local cid
for id, c in ipairs(P.data.countries) do
  for _, a in ipairs(H.country_lands(planet, id, 64)) do if a == addr then cid = id end end
end
local next_valley
for _, a in ipairs(H.country_lands(planet, cid, 64)) do
  if a ~= addr and not next_valley then next_valley = a end
end
test.eq(spread.country_key(next_valley), spread.country_key(addr), "of the same country")
visit(next_valley)
local w = D.world.current
test.eq(w:memory().community, nil, "they never met the player")
local p = w.land_node.data.people[2]
H.use("Talk to " .. p.name)
local said = H.collect_lines()
test.expect(said[1]:find("Peacemaker", 1, true), "they call the player by the story's title: " .. said[1])
test.expect(table.concat(said, " "):find(d.name, 1, true), "and know where it happened: " .. table.concat(said, " "))

-- far away nobody has heard yet; on the rest of the planet after two nights
local far, near
for _, s in ipairs(D.story.signals()) do
  if not s.address:find(planet .. ".", 1, true) then far = far or s.address end
end
for id in ipairs(P.data.countries) do
  if id ~= cid and not near then near = H.country_lands(planet, id, 5)[5] end
end
test.expect(far and near, "a land far away and one on the same planet")
local night = D.progress.night()
test.eq(#spread.heard(far, nil, nil, night + 10), 0, "other worlds of other galaxies never hear of a feud")
test.eq(#spread.heard(near, nil, nil, night), 0, "the rest of the planet has not heard it yet")
test.expect(#spread.heard(near, nil, nil, night + 2) > 0, "two nights later it has")
-- each people tells it its own way
local mine = spread.heard(near, deed.culture, nil, night + 2)[1]
test.eq(mine.rule, "glorify", "the player's friends glorify them: " .. mine.told)
local others = spread.heard(near, "Some Other Folk", nil, night + 2)[1]
test.eq(others.rule, "legend", "other peoples make a legend of it: " .. others.told)
test.expect(others.told:find("came out of the sky", 1, true), "a giant from the sky")
local quit = spread.record({ address = H.country_lands(planet, cid, 12)[9], kind = "gather", result = "abandoned",
                             title = "the stranger",
                             text = "gave up on them", place = "Elsewhere", night = night })
test.expect(quit.fame < deed.fame, "giving up is a small story")
local bad = spread.heard(next_valley, nil, nil, night)
local told_bad = false
for _, r in ipairs(bad) do if r.rule == "villainise" and r.told:find("gave up", 1, true) then told_bad = true end end
test.expect(told_bad, "and is told against the player")
