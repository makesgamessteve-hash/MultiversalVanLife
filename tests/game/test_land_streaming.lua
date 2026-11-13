-- Lands stream in chunks around the player: bounded while walking far,
-- rebuilt identically when coming back, the player follows the ground
-- across chunk borders, and neighbouring lands continue without a seam.
local D = game.debug
local gen = D.gen
local chunks = require("gen.chunks")
H.new_game()
H.finish_dialogue()
local w = D.world.current
local S = w.streamer
test.expect(S, "the farm is a streamed land")
local p = D.player

-- the surroundings are built on arrival
local around = (2 * chunks.LOAD + 1) ^ 2
test.eq(S.count, around, "every chunk within the load radius is built")

-- walking 500 m keeps entities and meshes bounded
local function live_meshes()
  local n = 0
  for _, c in pairs(S.loaded) do n = n + #c.meshes end
  return n
end
local start_entities = mvl.entity_count()
local max_entities, max_meshes, max_loaded = 0, 0, 0
local released
p.place(0, 0, -math.pi / 2)
for step = 1, 250 do
  p.x = step * 2
  test.wait(1)
  max_entities = math.max(max_entities, mvl.entity_count())
  max_meshes = math.max(max_meshes, live_meshes())
  max_loaded = math.max(max_loaded, S.count)
  if not released and S.stats.unloaded > 0 then released = true end
end
local window = (2 * chunks.UNLOAD + 1) ^ 2
test.expect(S.stats.built > around + 60, "new chunks were built ahead: " .. S.stats.built)
test.expect(S.stats.unloaded > 60, "chunks behind were removed: " .. S.stats.unloaded)
test.expect(max_loaded <= window, "loaded chunks stay within the unload window: " .. max_loaded)
test.expect(max_entities < start_entities * 3 and max_entities < 1800, "entities stay bounded: " .. max_entities)
test.expect(max_meshes <= window * 4, "meshes stay bounded: " .. max_meshes)
-- unloading releases meshes
local c = S:chunk_at(p.x, p.z)
local mesh = c.meshes[1]
test.expect(mvl.mesh_bounds(mesh), "a loaded chunk's terrain mesh exists")
S:unload(c.cx .. "," .. c.cz)
test.eq(mvl.mesh_bounds(mesh), nil, "an unloaded chunk's mesh is released")

-- coming back: a discarded chunk is rebuilt with the same content
local function snapshot(cx, cz)
  local ch = S.loaded[cx .. "," .. cz]
  local out = {}
  for _, e in ipairs(ch.entities) do
    local x, y, z = mvl.get_pos(e)
    out[#out + 1] = string.format("%.3f,%.3f,%.3f", x, y, z)
  end
  table.sort(out)
  return table.concat(out, ";")
end
p.place(40, 40, 0)
for _ = 1, 30 do test.wait(1) end
local before = snapshot(1, 1)
p.place(400, 40, 0)
for _ = 1, 60 do test.wait(1) end
test.eq(S.loaded["1,1"], nil, "the chunk was discarded")
p.place(40, 40, 0)
for _ = 1, 60 do test.wait(1) end
test.eq(snapshot(1, 1), before, "rebuilt with the same content")

-- the player stands on the ground, continuously across chunk borders
p.place(60, 10, 0)
for _ = 1, 30 do test.wait(1) end
local last
for i = 0, 40 do
  p.x = 60 + i * 0.25 -- crosses the border at x = 64
  test.wait(1)
  local _, cy = mvl.camera()
  local ground = mvl.height(p.x, p.z)
  test.expect(math.abs(cy - p.eye - ground) < 0.05, "eye height above the ground")
  if last then test.expect(math.abs(ground - last) < 0.15, "no jump at x = " .. p.x) end
  last = ground
end
-- objects stand on the surface
local van = D.van.exterior
test.expect(math.abs(van.y - mvl.height(van.x, van.z)) < 0.01, "the van stands on the ground")

-- the neighbouring land is generated on approach and continues seamlessly
local east = gen.prime.COUNTRYSIDE .. ".l1"
test.eq(gen.world:node(east), nil, "the neighbouring land is not generated yet")
p.place(950, 60, -math.pi / 2)
for _ = 1, 120 do test.wait(1) end
test.expect(gen.world:node(east), "approaching the edge generates the neighbouring land")
local h0, h1 = mvl.height(1023.9, 80), mvl.height(1024.1, 80)
test.expect(math.abs(h0 - h1) < 0.05, "terrain continues across the land border")
for i = 0, 40 do
  p.x = 1010 + i
  test.wait(1)
end
test.expect(p.x > 1024, "walked into the neighbouring land")
local ch = S:chunk_at(p.x, p.z)
test.eq(ch.land.node.address, east, "the chunks there belong to the neighbouring land")
test.eq(#gen.check.run(gen.world), 0, "lands pass the checks")
