-- A save from before the surface grid (tests/game/saves/test_grid_old_save,
-- made with the game as it was: a new game, the first signal followed to a
-- land of a country's district, saved there) keeps its multiverse: it is
-- continued as a version 1 multiverse, the visited land loads as it was
-- stored, the district's other lands, its terrain and the night's signals
-- are generated exactly as before, and walking on streams the district.
local D = game.debug
local gen = D.gen
local VISITED = "u3.g871.c34.s2.p2.k3.n1.l226"
-- recorded with the game before the change (features and people of a land)
local BEFORE = {
  ["u3.g871.c34.s2.p2.k3.n1.l226"] = 2949131278,
  ["u3.g871.c34.s2.p2.k3.n1.l227"] = 4272692758,
  ["u3.g871.c34.s2.p2.k3.n1.l242"] = 2413931452,
  ["u3.g871.c34.s2.p2.k3.n1.l225"] = 798134198,
}
local function fp(d)
  local parts = {}
  for _, f in ipairs(d.features) do parts[#parts + 1] = string.format("%s@%.2f,%.2f", f.id, f.x, f.z) end
  for _, p in ipairs(d.people or {}) do parts[#parts + 1] = p.name end
  return mvl.hash(table.concat(parts, " "))
end

test.eq(game.state, "title", "title screen")
test.expect(not mvl.save_get("story.version"), "the save has no version: it is from before the grid")
H.choose(D.title_menu(), "Continue")
test.eq(game.state, "play", "playing")
H.finish_dialogue()
test.eq(D.progress.version(), 1, "a multiverse from before the surface grid")
local G = gen.world
test.eq(G.version, 1, "generated as it was")
test.eq(D.progress.seed(), 27001, "its own seed")

-- the visited land, where and as it was
local w = D.world.current
test.eq(w.def.id, "land", "continued in the land")
local node = w.land_node
test.eq(node.address, VISITED, "the land visited before")
test.expect(node.stored, "loaded from the save")
test.eq(fp(node.data), BEFORE[VISITED], "exactly as it was")
test.expect(not node.data.region and node.data.terrain.map, "a land of its country's district")

-- the district's other lands and its terrain are generated as before
local gx, gz = gen.land.grid(node.index)
for _, o in ipairs({ { 1, 0 }, { 0, 1 }, { -1, 0 } }) do
  local n = gen.neighbour_land(G, VISITED, gx + o[1], gz + o[2])
  test.expect(n, "a neighbouring land of the district")
  test.eq(fp(n.data), BEFORE[n.address], "generated as before: " .. n.address)
end
local country = G:generate(gen.address.parent(VISITED))
local t = country.data.terrain
test.eq(t.seed, 745364, "the district's terrain seed")
test.eq(t.amp, 70, "its roughness")
test.eq(t.freq, 0.0025, "its frequency")
test.eq(mvl.hash(table.concat(t.map.data, ",")), 1728640649, "and its elevation map")

-- the night's signals still lead to district lands, as before
local V1 = gen.run.new(gen.cosmos, { seed = 27001, version = 1 })
local list = gen.signals.tonight(V1, 2, {}, {}, {})
local addrs = {}
for _, s in ipairs(list) do addrs[#addrs + 1] = s.address end
test.eq(table.concat(addrs, " "),
        "u13.g878.c118.s4.p0.k4.n0.l71 u9.g69.c21.s10.p1.k0.n23.l119 u10.g365.c76.s8.p1.k3.n0.l93",
        "the signals of a night are those of before")

-- walking on streams the district's next land
local S = w.streamer
test.expect(not S.grid, "streamed as a district")
H.step_outside()
local p = D.player
for x = 900, 1200, 4 do
  p.place(x, p.z, -math.pi / 2)
  test.wait(1)
end
local rec = S:land_at(p.x, p.z)
test.eq(rec and rec.node.address, "u3.g871.c34.s2.p2.k3.n1.l227", "the next land of the district")

-- a new game explores the surface grid
H.new_game_in_van(27001)
test.eq(D.progress.version(), gen.VERSION, "a new multiverse has the current version")
test.eq(gen.world.version, 2, "and lands on the grid")
test.expect(gen.is_grid_land(D.story.signals()[1].address), "its signals lead to lands of regions")
