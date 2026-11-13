-- Plants and animals in the lands: each patch of a land shows the species
-- of its habitat, walking from one habitat into another changes them, and
-- chunks hold a bounded number of living things.
local D = game.debug
local gen = D.gen
local HAB = gen.life.habitats
gen.planet.LEVEL = 3
H.new_game_in_van(5150)
local G = gen.world

-- a land between a forest and an open biome, both with animals
local FOREST = { ["temperate forest"] = true, rainforest = true, ["seasonal forest"] = true, taiga = true,
                 ["crystal forest"] = true, wetland = true }
local found
for s = 0, 200 do
  local saddr = "u" .. (1 + s % 7) .. ".g" .. (s % 11) .. ".c" .. (s % 3) .. ".s" .. (s % 5)
  local ok, sys = pcall(G.generate, G, saddr)
  if ok then
    for i = 0, sys.data.planets - 1 do
      if not found and sys.children[i].kind == "rocky" then
        local p = G:generate(saddr .. ".p" .. i)
        if p.data.life and p.data.life.complexity == "animals" then
          for k = 0, (p.data.continents or 0) - 1 do
            local cont = G:generate(p.address .. ".k" .. k)
            for _, n in ipairs(gen.util.sorted_keys(cont.children)) do
              local c = G:generate(cont.address .. ".n" .. n)
              if not found and c.data.district then
                for l = 0, 255, 9 do
                  local gx, gz = gen.land.grid(l)
                  if gen.land.raw_height(c.data.terrain, gx * 2048, gz * 2048) > 3 then
                    local land = G:generate(c.address .. ".l" .. l)
                    local h = land.data.habitats
                    if h and #h == 2 and (FOREST[h[1].biome] ~= FOREST[h[2].biome]) and #h[1].plants > 0 and
                       #h[2].plants > 0 then found = land end
                    break
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  if found then break end
end
test.expect(found, "a land where a forest meets open country")
local habs = found.data.habitats
H.travel_to(found.address)
H.step_outside()
local w = D.world.current
local st = w.streamer

-- the species of each habitat
local members = {}
for i, h in ipairs(habs) do
  members[i] = {}
  for _, sp in ipairs(h.plants) do members[i][sp.id] = true end
  for _, sp in ipairs(h.animals) do members[i][sp.id] = true end
end
-- walk to a patch of each habitat and look at the chunk there
local spot = {}
for x = -900, 900, 32 do
  for z = -900, 900, 32 do
    for i, h in ipairs(habs) do
      if not spot[i] and HAB.habitat_at(habs, found.seed, x + 16, z + 16) == h and mvl.height(x + 16, z + 16) > 2 then
        spot[i] = { x + 16, z + 16 }
      end
    end
  end
end
test.expect(spot[1] and spot[2], "both habitats have dry patches")
local seen = {}
for i = 1, 2 do
  D.player.place(spot[i][1], spot[i][2], 0)
  test.wait(40)
  local c = st:chunk_at(spot[i][1], spot[i][2])
  test.expect(c, "the chunk under the player is built")
  test.eq(c.habitat, habs[i].biome, "the chunk lies in its patch's habitat")
  seen[i] = {}
  for id in pairs(c.species) do
    test.expect(members[i][id], "a species of " .. habs[i].biome .. " grows there")
    seen[i][id] = true
  end
end
test.expect(next(seen[1]) and next(seen[2]), "both patches have living things")
local shared = 0
for id in pairs(seen[1]) do if seen[2][id] then shared = shared + 1 end end
test.eq(shared, 0, "walking from " .. habs[1].biome .. " into " .. habs[2].biome .. " changes the species")
-- all over the loaded land: species of the right habitats, bounded counts
local total, chunks, animals = 0, 0, 0
for _, c in pairs(st.loaded) do
  chunks = chunks + 1
  total = total + #c.entities
  local living = 0
  for id in pairs(c.species or {}) do
    local idx = c.habitat == habs[1].biome and 1 or 2
    test.expect(members[idx][id], "chunks show their habitat's species")
  end
  for _ in pairs(c.species or {}) do living = living + 1 end
  animals = animals + (c.animals or 0)
  test.expect((c.animals or 0) <= HAB.MAX_ANIMALS, "at most a few animals per chunk")
  test.expect(#c.entities <= 60, "a bounded number of entities per chunk: " .. #c.entities)
end
test.expect(total / chunks < 30, "on average fewer than 30 entities per chunk: " .. total / chunks)
test.expect(animals > 0, "animals live in the land")
-- the animals and plants are drawn in their species' colours
local sp = habs[1].plants[1]
test.expect(mvl.texture_recolor("textures/" .. sp.sprite .. ".tga", sp.colors, sp.mode) > 0, "species textures")
