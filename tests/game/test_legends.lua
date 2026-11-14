-- Meeting a legend: a person of a planet's history who is still alive lives
-- in a land of their nation, and talks about their deeds.
local D = game.debug
local gen = D.gen
gen.planet.LEVEL = 3
H.new_game_in_van(2026)
local G = gen.world

local target, who
for s = 0, 400 do
  local saddr = "u" .. (1 + s % 7) .. ".g" .. (s % 11) .. ".c" .. (s % 3) .. ".s" .. (s % 5)
  local ok, sys = pcall(G.generate, G, saddr)
  if ok then
    for i = 0, sys.data.planets - 1 do
      if not target and sys.children[i].kind == "rocky" then
        local p = G:generate(saddr .. ".p" .. i)
        for addr, ids in pairs(p.commits) do
          for _, id in ipairs(ids) do
            local c = p.facts[id]
            if not target and c.data.kind == "resident" then target, who = addr, c.data.data.individual end
          end
        end
      end
    end
  end
  if target then break end
end
test.expect(target, "a living person of history has a home")
test.expect(#who.deeds > 0, "with deeds")
H.travel_to(target)
H.step_outside()
local d = D.world.current.land_node.data
local person
for _, p in ipairs(d.people) do if p.name == who.name then person = p end end
test.expect(person and person.legend, "the legend lives in the land")
H.use("Talk to " .. who.name)
local said = {}
for _ = 1, 20 do
  if not D.dialogue.active() then break end
  local cur = D.dialogue.current
  if said[#said] ~= cur.text then said[#said + 1] = cur.text end
  test.press("interact")
end
test.expect(said[1] and said[1]:find(who.name, 1, true), "the legend introduces themself: " .. tostring(said[1]))
local heard = table.concat(said, " ")
test.expect(heard:find("years ago I", 1, true), "and speaks of what they did")
local text = table.concat(person.lines, " ")
test.expect(text:find(who.name, 1, true) and text:find("years ago I", 1, true), "and tells of their deeds")
test.expect(text:find(who.deeds[#who.deeds].text, 1, true), "in their own words: " .. who.deeds[#who.deeds].text)
test.eq(#gen.check.run(G), 0, "the promise of a home is kept")
