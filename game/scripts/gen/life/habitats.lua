-- Multiversal Van Life - habitats of a land and the life its chunks show (MIT).
--
-- A land lies in its planet cell's biome, and near the edge of a
-- neighbouring biome: its habitats are the cell's biome and the commonest
-- other land biome around it, each with the species living there (copied
-- into the land, so a stored land needs no planet). Patches of each
-- habitat lie across the land (a slow noise field), and each chunk shows
-- the plants and animals of its patch: more of them where the biome is
-- rich, never more than a fixed number per chunk. Until voxel models exist
-- they are sprites repainted in each species' colours.
local dm = require("gen.dmath")
local species = require("gen.life.species")

local H = { MAX_PLANTS = 16, MAX_ANIMALS = 3, PATCH = 0.006 }

-- How a species is drawn: sprite, recolouring mode and size (metres).
function H.look(sp)
  if sp.kind == "plant" then
    local sprite, w
    if sp.form == "fungus" then sprite, w = "plant_fungus", 1
    elseif sp.leaf == "shard" then sprite, w = "plant_shard", sp.form == "tree" and 0.6 or 1
    elseif sp.form == "tree" then
      sprite = sp.leaf == "needle" and "tree_pine" or "tree_oak"
      w = sprite == "tree_pine" and 0.5 or 0.67
    elseif sp.form == "shrub" then sprite, w = "bush", 1
    else sprite, w = "flowers", 1 end
    local h = dm.round(math.max(sp.height, 0.25), 3)
    local mode = (sprite == "plant_fungus" or sprite == "plant_shard") and "all" or "green"
    return { sprite = sprite, mode = mode, w = dm.round(h * w, 3), h = h, solid = sp.form == "tree" }
  end
  local sprite
  if sp.move == "fly" or sp.move == "glide" then sprite = "critter_flyer"
  elseif sp.limbs == 0 then sprite = "critter_crawler"
  elseif sp.limbs == 2 or sp.move == "hop" then sprite = "critter_hopper"
  else sprite = "critter_walker" end
  local h = dm.round(dm.clamp(math.max(sp.height, sp.size * 0.6), 0.08, 5), 3)
  return { sprite = sprite, mode = "all", w = h, h = h, flies = sp.move == "fly" }
end

-- The parameters of a species' voxel model (gen/visuals/models.lua);
-- `pseed` is the planet's seed.
function H.model(L, sp, pseed)
  local seed = mvl.hash(pseed, sp.id)
  local l
  for _, x in ipairs(L.lineages) do if x.id == sp.lineage then l = x end end
  if sp.kind == "plant" then
    return { kind = "plant", key = "plant:" .. seed, seed = seed, lseed = mvl.hash(pseed, sp.lineage), form = sp.form,
             leaf = sp.leaf, height = sp.height, colors = sp.colors, chemistry = L.chemistry }
  end
  return { kind = "animal", key = "animal:" .. seed, seed = seed, limbs = sp.limbs, covering = sp.covering,
           segments = l and l.segments or 4, eyes = l and l.eyes or 2, tail = l and l.tail or false, move = sp.move,
           size = sp.size, height = sp.height, stockiness = sp.stockiness, colors = sp.colors }
end

-- How an animal behaves (lib/creatures.lua): its role and way of moving.
function H.behaviour(sp)
  if sp.kind ~= "animal" then return nil end
  local kind
  if sp.move == "fly" then kind = "flyer"
  elseif sp.move == "burrow" or sp.limbs == 0 then kind = "burrower"
  elseif sp.role == "predator" then kind = "prowler"
  else kind = "grazer" end
  return { kind = kind, role = sp.role, speed = dm.round(dm.clamp(0.8 + sp.size * 1.2, 0.6, 6), 3) }
end

-- The habitats of a land at `cell` of a living planet `P` (seed `pseed`)
-- whose biome is `biome` (nil when the planet has no species).
function H.for_land(P, cell, biome, pseed)
  local L = P.life
  if not L or not L.species then return nil end
  local geo = require("gen.levels.geography")
  local counts = {}
  for _, nb in ipairs(mvl.planet_neighbours(P.grid, cell)) do
    local b = geo.BIOMES[P.cells.biome[nb]]
    if not b.water and b.id ~= biome.id and L.by_biome[b.id] then counts[b.id] = (counts[b.id] or 0) + 1 end
  end
  local second, best = nil, 0
  for b, n in pairs(counts) do
    if n > best or (n == best and b < second) then second, best = b, n end
  end
  local list = { { biome = biome.id, weight = second and 0.65 or 1 } }
  if second then list[2] = { biome = second, weight = 0.35 } end
  for _, h in ipairs(list) do
    h.density = (species.BIOME_LIFE[h.biome] or { 0 })[1]
    h.plants, h.animals = {}, {}
    for _, id in ipairs(L.by_biome[h.biome] or {}) do
      local sp = species.get(L, id)
      local look = H.look(sp)
      local entry = { id = sp.id, name = sp.name, role = sp.role, abundance = sp.abundance, colors = sp.colors,
                      sprite = look.sprite, mode = look.mode, w = look.w, h = look.h, solid = look.solid,
                      flies = look.flies, model = H.model(L, sp, pseed or 0), behaviour = H.behaviour(sp) }
      table.insert(sp.kind == "plant" and h.plants or h.animals, entry)
    end
  end
  return list
end

local function weighted(rng, list)
  local total = 0
  for _, e in ipairs(list) do total = total + e.abundance end
  local r = rng:next() * total
  for _, e in ipairs(list) do
    r = r - e.abundance
    if r <= 0 then return e end
  end
  return list[#list]
end

-- The habitat of the patch at land-local (lx, lz).
function H.habitat_at(habitats, seed, lx, lz)
  if #habitats == 1 then return habitats[1] end
  local n = mvl.noise(lx * H.PATCH, lz * H.PATCH, seed % 100000, 2)
  local v = dm.clamp(n * 0.8 + 0.5, 0, 1)
  return v < habitats[1].weight and habitats[1] or habitats[2]
end

-- How many plants and animals a chunk of a habitat holds, and which.
function H.sample(habitat, rng)
  local plants, animals = {}, {}
  if #habitat.plants > 0 then
    local n = math.min(H.MAX_PLANTS, math.floor(habitat.density * 13 + rng:next() * 3))
    for i = 1, n do plants[i] = weighted(rng, habitat.plants) end
  end
  if #habitat.animals > 0 and rng:next() < habitat.density * 0.9 then
    local first = weighted(rng, habitat.animals)
    animals[1] = first
    -- grazers keep together
    local herd = first.role == "grazer" and rng:int(0, 2) or 0
    for _ = 1, math.min(herd, H.MAX_ANIMALS - 1) do animals[#animals + 1] = first end
  end
  return plants, animals
end

return H
