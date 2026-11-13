-- Signals: three a night, varied over consecutive nights, never in Prime,
-- and the destination is generated and ready when the trip ends.
local D = game.debug
local story = D.story
H.new_game_in_van(2026)
local galaxies, troubles, all = {}, {}, {}
for night = 1, 3 do
  local list = story.signals()
  test.eq(#list, 3, "three signals on night " .. night)
  local g = {}
  for _, s in ipairs(list) do
    test.expect(not g[s.galaxy], "no two signals of a night share a galaxy")
    g[s.galaxy] = true
    galaxies[s.galaxy] = true
    troubles[s.trouble] = true
    all[#all + 1] = s
    test.expect(s.name and s.planet and s.galaxy_name and s.short, "signals are described")
  end
  test.eq(story.signals(), list, "the same signals all night")
  D.progress.end_night()
end
local n = 0
for _ in pairs(galaxies) do n = n + 1 end
test.expect(n >= 5, "signals come from many galaxies: " .. n)
n = 0
for _ in pairs(troubles) do n = n + 1 end
test.expect(n >= 3, "signals concern different troubles: " .. n)

-- never in Prime
local G = D.gen.world
for night = 1, 40 do
  for _, s in ipairs(D.gen.signals.tonight(G, night, {}, {})) do
    test.expect(not s.address:find("^u0%."), "signal outside Prime: " .. s.address)
  end
end

-- the console describes them in Juniper's words
H.use("console")
local said, calls = H.collect_lines(), 0
for _, text in ipairs(said) do if tostring(text):find("A call from", 1, true) then calls = calls + 1 end end
test.eq(calls, 3, "Juniper describes the three signals")
-- choosing one: the land is generated during the trip and ready on arrival
local first = story.signals()[1]
test.eq(G:node(first.address), nil, "the land is not generated before travelling")
local start = mvl.ticks()
H.choose(story.menu, first.name)
test.until_true(function() return not story.busy end, 1200, "arrived")
test.expect(mvl.ticks() - start >= 3.5 * 60 - 2, "the trip lasts at least 3.5 s")
test.expect(G:node(first.address), "the land was generated during the trip")
test.eq(D.world.current.def.id, "land", "the destination is loaded")
test.eq(D.world.current.land_node.address, first.address, "the right land")
test.eq(D.progress.location(), "land:" .. first.address, "the location is saved")
H.finish_dialogue()
