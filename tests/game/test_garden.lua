-- The garden behind the conservatory: its own terrain slot, the door both
-- ways (walking through it, the garden's sky; the door behind shows the
-- conservatory), and a two kilometre walk along the path that keeps the
-- garden coming within the entity budget, and the way back to the house.
local D = game.debug
local van = D.van
local garden = van.garden
local G = garden.G
H.new_game_in_van(2468)
H.finish_dialogue()
local P = van.P
local pl = D.player

-- -------------------------------------------------------- terrain slots
test.expect(math.abs(mvl.height(0, 0, G.SLOT) - G.Y) < 0.5, "the garden's ground lies on its own slot")
test.expect(math.abs(mvl.height(0, 0, G.SLOT) - mvl.height(0, 0)) > 100, "apart from the land's")
test.eq(mvl.height(-300, 77, G.SLOT), mvl.height(-300, 77, G.SLOT), "the same height every time")
local ok = pcall(mvl.height, 0, 0, 9)
test.expect(not ok, "no slot 9")
local m = mvl.terrain_chunk(-3, 2, 32, 8, G.SLOT)
local _, ylo, _, _, yhi = mvl.mesh_bounds(m)
test.expect(ylo and ylo < G.Y + 30 and ylo > G.Y - 30, "a chunk of the garden's slot")
mvl.release_mesh(m)

local function walk(frames)
  for _ = 1, math.ceil(frames / 10) do
    H.finish_dialogue()
    test.hold("move_y", 10)
  end
end

-- ------------------------------------------------ through the garden door
pl.base_y = P[2]
pl.place(P[1] - 12, P[3] - 8.75, math.pi / 2)  -- in the conservatory, facing the door (-X)
walk(20)
test.eq(van.zone, "conservatory", "in the conservatory")
test.eq(van.env, "garden", "the door shows the garden's sky")
test.expect(garden.count > 0, "the garden is there behind the door")
walk(120)
test.eq(van.zone, "garden", "through the door: in the garden")
test.expect(math.abs(pl.base_y - garden.height(pl.x, pl.z)) < 0.01 and pl.base_y < G.Y + 10, "standing on the garden's ground")
test.eq(van.env, "garden", "under the garden's sky")
test.expect(pl.x < G.DOOR.x - 1, "walked on into the garden: " .. pl.x)
local ok2, _ = pcall(function() return mvl.portal end)
test.expect(ok2, "the door behind shows the conservatory (a portal)")
-- and back in
pl.place(G.DOOR.x - 3, G.DOOR.z, -math.pi / 2)     -- facing the door (+X)
walk(60)
test.eq(van.zone, "conservatory", "back in the conservatory")
test.expect(math.abs(pl.base_y - P[2]) < 0.01, "on the conservatory's floor")

-- --------------------------------------------------- a long walk
pl.base_y = P[2]
pl.place(P[1] - 13, P[3] - 8.75, math.pi / 2)
walk(80)
test.eq(van.zone, "garden", "in the garden again")
local most, chunks = 0, 0
local x = G.DOOR.x - 4
while x > -2000 do
  x = x - 8
  local z = G.path_z(x)
  pl.place(x, z, math.pi / 2)
  pl.base_y = garden.height(x, z)
  test.wait(1)
  garden.update(x, z, garden.LOAD, 4)
  most = math.max(most, garden.entity_count())
  chunks = math.max(chunks, garden.count)
end
test.expect(garden.loaded[math.floor(x / G.CHUNK) .. "," .. math.floor(G.path_z(x) / G.CHUNK)],
            "two kilometres on, the garden is still there")
test.expect(most < 1100, "the garden stays within its entity budget: " .. most)
mvl.log("garden: most entities " .. most .. ", chunks " .. chunks .. ", all entities " .. mvl.entity_count())
test.expect(chunks <= 81, "chunks behind are released: " .. chunks)
-- the path is never blocked by the garden's things near it
local blocked = 0
for xx = -10, -1500, -25 do
  local zz = G.path_z(xx)
  garden.update(xx, zz, 1, math.huge)
  if mvl.overlaps(xx, zz, 0.3, garden.height(xx, zz)) then blocked = blocked + 1 end
end
test.eq(blocked, 0, "the path is clear")
-- the way back leads to the house
pl.place(G.DOOR.x - 2, G.path_z(G.DOOR.x - 2), -math.pi / 2)
pl.base_y = garden.height(pl.x, pl.z)
garden.update(pl.x, pl.z, garden.LOAD, math.huge)
walk(60)
test.eq(van.zone, "conservatory", "the path leads back to the house")
-- leaving the van clears the garden
H.use("Step outside")
H.finish_dialogue()
test.eq(garden.count, 0, "the garden is put away while the player is outside")
