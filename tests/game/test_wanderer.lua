-- The Wanderer legend: long before the player, Juniper's van was seen on
-- some worlds; where the legend is told, people recognise the van.
local D = game.debug
local gen = D.gen
gen.planet.LEVEL = 3
H.new_game_in_van(2026)
local G = gen.world
local W = gen.history.wanderer

-- in a seeded share of the universes
local visited = 0
for u = 1, 60 do if W.visited(G, u) then visited = visited + 1 end end
test.expect(visited >= 10 and visited <= 35, "Juniper wandered through some universes: " .. visited .. " of 60")

local target, planet, cul
for s = 0, 900 do
  local saddr = "u" .. (1 + s % 9) .. ".g" .. (s % 11) .. ".c" .. (s % 3) .. ".s" .. (s % 5)
  local u = tonumber(saddr:match("^u(%d+)"))
  local ok, sys = false, nil
  if W.visited(G, u) then ok, sys = pcall(G.generate, G, saddr) end
  if ok then
    for i = 0, sys.data.planets - 1 do
      if not target and sys.children[i].kind == "rocky" then
        local p = G:generate(saddr .. ".p" .. i)
        for id, c in ipairs(p.data.countries or {}) do
          local k = gen.culture.of_country(p.data, id)
          if not target and k and k.wanderer then
            target, planet, cul = p.address .. ".k" .. (c.continent - 1) .. ".n" .. c.index .. ".l5", p, k
          end
        end
      end
    end
  end
  if target then break end
end
test.expect(target, "a people with a legend of the Wanderer")
-- the sighting is in the true record, and the legend in the culture's memory
local seen
for _, ev in ipairs(planet.data.history.events) do if ev.kind == "sighting" then seen = ev end end
test.expect(seen and seen.name == "the coming of the Wanderer", "the history records the sighting")
test.expect(cul.wanderer.told:find("cream-and-teal", 1, true), "the legend: " .. cul.wanderer.told)
test.eq(cul.wanderer.years_ago, -seen.year, "of the sighting")
test.expect(planet.data.history.events[#planet.data.history.events].year <= 0, "all of it before the player arrives")

H.travel_to(target)
H.step_outside()
local d = D.world.current.land_node.data
test.expect(d.wanderer, "the land keeps the legend")
local giver = d.people[1]
H.use("Talk to " .. giver.name)
local said = {}
for _ = 1, 20 do
  if not D.dialogue.active() then break end
  local cur = D.dialogue.current
  if said[#said] ~= cur.text then said[#said + 1] = cur.text end
  test.press("interact")
end
test.expect(said[1] and said[1]:find("Cream and teal", 1, true), "the giver recognises the van: " .. tostring(said[1]))
test.expect(said[1]:find(tostring(math.floor(cul.wanderer.years_ago + 0.5)) .. " years ago", 1, true),
            "from the legend of long ago")
test.expect(#said >= 2, "and then tells of the trouble")
-- another villager too
local other = d.people[2]
if other and not other.lines then
  H.use("Talk to " .. other.name)
  local line = D.dialogue.current and D.dialogue.current.text or ""
  test.expect(line:find("Wanderer", 1, true), "villagers know the legend: " .. line)
  H.finish_dialogue()
end
-- a second visit: the giver remembers you rather than the legend
H.use("Talk to " .. giver.name)
test.expect(not tostring(D.dialogue.current and D.dialogue.current.text):find("Cream and teal", 1, true),
            "the recognition happens once")
H.finish_dialogue()
-- a people without the legend does not know the van
test.eq(#gen.check.run(G), 0, "the checker passes")
