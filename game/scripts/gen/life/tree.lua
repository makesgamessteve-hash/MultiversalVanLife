-- Multiversal Van Life - trees of life: biochemistry and lineages (MIT).
--
-- A solid world gets life when its conditions allow a solvent and a
-- chemistry (water and carbon, ammonia in the cold, molten sulphur and
-- silicon in great heat, or the universe's magic itself where life is its
-- source). How complex life became follows from the star's age. Life then
-- branches into 4 to 8 lineages: body plans that every native species
-- inherits (plants: leaf and form; animals: symmetry, segments, limbs,
-- covering, ways of moving, senses and size).
local dm = require("gen.dmath")
local names = require("gen.names")

local T = {}

T.CHEMISTRY = {
  ["carbon-water"] = { solvent = "water", plants = "green-leaved", note = "carbon life in water" },
  ["carbon-ammonia"] = { solvent = "ammonia", plants = "waxy", note = "cold carbon life bathed in ammonia" },
  ["silicon-sulphur"] = { solvent = "molten sulphur", plants = "glassy", note = "slow silicon life in molten sulphur" },
  arcane = { solvent = "mana", plants = "glimmering", note = "life woven from the universe's magic" },
}

-- Plant leaves and the forms they allow.
T.LEAVES = {
  broad = { "tree", "shrub", "herb" }, needle = { "tree", "shrub" }, frond = { "tree", "shrub", "herb" },
  blade = { "herb", "shrub" }, cap = { "fungus" }, shard = { "shrub", "herb", "tree" },
}
T.COVERINGS = { "skin", "scales", "fur", "feathers", "chitin", "shell", "plates" }
T.MOVES = { "walk", "fly", "crawl", "burrow", "glide", "hop" }
T.SENSES = { "sight", "smell", "hearing", "echo", "electric sense", "heat sense", "touch" }

local ROOTS = { "Ptera", "Cheli", "Octo", "Myri", "Sauro", "Lepi", "Gnatho", "Cteno", "Dactyl", "Ophi", "Thero",
                "Arthro", "Placo", "Cyclo", "Helio", "Lito", "Nycto", "Brachi", "Echi", "Rhodo" }
local PLANT_ROOTS = { "Dendro", "Phyllo", "Xylo", "Thallo", "Antho", "Rhizo", "Myco", "Lycho", "Crystallo", "Pteri" }

-- Which chemistry (if any) a world's conditions allow; nil for none.
function T.chemistry(P, laws)
  if not P.surface then return nil end
  local mean, pressure = P.temperature.mean, P.atmosphere.pressure
  if laws and laws.magic == "life" and (laws.magic_strength or 0) >= 0.5 and pressure > 0.01 then return "arcane", 0.6 end
  if P.water == "liquid" then return "carbon-water", 0.9 end
  if mean >= 190 and mean < 250 and pressure >= 0.3 then return "carbon-ammonia", 0.45 end
  if mean >= 390 and mean < 720 and pressure >= 1 then return "silicon-sulphur", 0.25 end
  return nil
end

-- The biochemistry pass: does the world live, how, and how far life came.
function T.biochemistry(ctx, forced)
  local d = ctx.data
  local laws = ctx:ancestor("universe").data.laws
  local chem, chance = T.chemistry(d, laws)
  local rng = ctx:random("biochemistry")
  if forced and not chem then
    chem = d.temperature.mean < 250 and "carbon-ammonia" or (d.temperature.mean > 390 and "silicon-sulphur" or "carbon-water")
    chance = 1
  end
  if not chem or (not forced and not rng:chance(chance)) then
    d.life = { chemistry = "none" }
    return
  end
  local age = ctx.parent.data.star.age or 4
  local complexity = age < 0.8 and "microbial" or (age < 2 and "plants" or "animals")
  if forced then complexity = "animals" end
  local info = T.CHEMISTRY[chem]
  d.life = { chemistry = chem, solvent = info.solvent, complexity = complexity, age = dm.round(age * 0.75, 3),
             note = info.note }
end

local function animal_lineage(rng, i, chem)
  local covering = chem == "silicon-sulphur" and (rng:chance(0.5) and "plates" or "shell") or
                   T.COVERINGS[rng:int(1, #T.COVERINGS)]
  local limbs = ({ 0, 2, 4, 4, 4, 6, 6, 8 })[rng:int(1, 8)]
  local moves = {}
  if limbs == 0 then moves[1] = rng:chance(0.6) and "crawl" or "burrow"
  else
    moves[1] = rng:chance(0.2) and "hop" or "walk"
    if covering == "feathers" or (limbs >= 4 and rng:chance(0.3)) then moves[#moves + 1] = "fly" end
    if rng:chance(0.2) then moves[#moves + 1] = "glide" end
  end
  if covering == "feathers" and moves[2] ~= "fly" then moves[#moves + 1] = "fly" end
  local senses = { T.SENSES[rng:int(1, #T.SENSES)] }
  if rng:chance(0.5) then senses[2] = T.SENSES[rng:int(1, #T.SENSES)] end
  if senses[2] == senses[1] then senses[2] = nil end
  local small = limbs == 0 or covering == "chitin"
  return {
    id = "a" .. i, kind = "animal", name = ROOTS[rng:int(1, #ROOTS)] .. names.make(rng, "world"):lower() .. "a",
    symmetry = rng:chance(0.85) and "bilateral" or "radial",
    segments = limbs == 0 and rng:int(4, 14) or rng:int(1, 4),
    limbs = limbs, covering = covering, moves = moves, senses = senses,
    eyes = senses[1] == "sight" and (rng:chance(0.7) and 2 or rng:int(3, 8)) or rng:int(0, 2),
    tail = rng:chance(0.55),
    size = small and { 0.05, dm.round(0.3 + rng:next() * 0.8, 2) } or { 0.3, dm.round(1.2 + rng:next() * 3.5, 2) },
    shape = dm.round(0.5 + rng:next() * 1.2, 3), -- height to length
    hue = rng:int(0, 359),
    birth = ({ "eggs", "live young", "budding", "eggs" })[rng:int(1, 4)],
  }
end

local function plant_lineage(rng, i, chem, leaf)
  local roots = PLANT_ROOTS
  return {
    id = "p" .. i, kind = "plant", name = roots[rng:int(1, #roots)] .. names.make(rng, "world"):lower() .. "ae",
    leaf = leaf, forms = T.LEAVES[leaf],
    spread = chem == "silicon-sulphur" and "shards" or (leaf == "cap" and "spores" or "seeds"),
    tone = dm.round(0.7 + rng:next() * 0.6, 3), -- lighter or darker than the star's foliage
  }
end

-- The lineages pass: plants (2 or 3 lineages) and animals (2 to 5).
function T.lineages(ctx)
  local d = ctx.data
  if not d.life or d.life.chemistry == "none" or d.life.complexity == "microbial" then return end
  local rng = ctx:random("lineages")
  local chem = d.life.chemistry
  local out = {}
  local leaves = chem == "silicon-sulphur" and { "shard", "shard", "cap" } or
                 (chem == "arcane" and { "shard", "broad", "frond" } or { "broad", "needle", "blade", "frond", "cap" })
  -- a tree-forming lineage first, then grasses or fungi
  local first = leaves[1] == "shard" and "shard" or (rng:chance(0.6) and "broad" or "needle")
  out[1] = plant_lineage(rng, 1, chem, first)
  out[2] = plant_lineage(rng, 2, chem, chem == "carbon-water" and "blade" or leaves[rng:int(1, #leaves)])
  if rng:chance(0.7) then out[3] = plant_lineage(rng, 3, chem, "cap") end
  if d.life.complexity == "animals" then
    local n = rng:int(2, 5)
    for i = 1, n do out[#out + 1] = animal_lineage(rng, i, chem) end
    -- at least one lineage that walks on legs, one that flies or crawls
    local walkers, small = 0, 0
    for _, l in ipairs(out) do
      if l.kind == "animal" and l.limbs >= 4 then walkers = walkers + 1 end
      if l.kind == "animal" and (l.limbs == 0 or l.moves[2] == "fly") then small = small + 1 end
    end
    if walkers == 0 then
      local l = out[#out]
      l.limbs, l.moves, l.size = 4, { "walk" }, { 0.3, dm.round(1.2 + rng:next() * 3, 2) }
      if l.segments > 4 then l.segments = 2 end
    end
  end
  d.life.lineages = out
end

-- Adds a lineage matching a committed species' anatomy (its ancestors).
function T.kin_lineage(d, species)
  local a = species.anatomy
  local moves = { "walk" }
  if a.wings then moves[2] = "fly" end
  local l = {
    id = "a" .. (#d.life.lineages + 1), kind = "animal", name = (species.name:gsub("[^%a]", "")) .. "oida",
    symmetry = "bilateral",
    segments = 1, limbs = a.limbs, covering = a.covering, moves = moves, senses = { species.senses[1] },
    eyes = a.eyes, tail = a.tail, size = { 0.3, dm.round(a.height * 1.5, 2) }, shape = 1.2, hue = species.hue or 30,
    birth = species.reproduction, kin_of = species.name,
  }
  d.life.lineages[#d.life.lineages + 1] = l
  return l
end

return T
