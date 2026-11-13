-- Multiversal Van Life - species: radiation into biomes, adaptation,
-- ecological roles, names and bestiary entries (MIT).
--
-- Every land biome of a living world gets plants and animals drawn from
-- the world's lineages. Each species keeps its lineage's body plan (limbs,
-- covering, ways of moving) and adapts to its world and biome: gravity
-- makes land animals shorter and stockier, thick air lets winged lineages
-- fly (thin air grounds them), cold thickens coats, the star's light
-- colours plants, rich biomes grow larger species, and strong magic or
-- psionic fields give species gifts. Roles follow plausible proportions
-- (about 10 producers to 3 grazers to 1 predator) and every predator has
-- prey in its biome.
local dm = require("gen.dmath")
local names = require("gen.names")
local PAL = require("gen.visuals.palette")

local S = {}

-- How much life a biome carries and how much of its plant life is trees.
S.BIOME_LIFE = {
  rainforest = { 1.0, 0.6 }, ["temperate forest"] = { 0.85, 0.5 }, ["seasonal forest"] = { 0.8, 0.45 },
  taiga = { 0.7, 0.55 }, wetland = { 0.75, 0.25 }, ["crystal forest"] = { 0.8, 0.5 }, savanna = { 0.5, 0.12 },
  grassland = { 0.55, 0.04 }, ["arcane meadow"] = { 0.6, 0.03 }, coast = { 0.35, 0.08 }, tundra = { 0.3, 0 },
  alpine = { 0.2, 0.02 }, ["cold desert"] = { 0.12, 0 }, ["hot desert"] = { 0.1, 0.01 }, ["ash fields"] = { 0.1, 0 },
  barren = { 0, 0 }, ["ice sheet"] = { 0.02, 0 },
}
-- Relative numbers by role (producers 10 : grazers 3 : predators 1).
S.ABUNDANCE = { producer = 10, grazer = 3, predator = 1, scavenger = 0.5, pollinator = 1.5, decomposer = 2 }

local EPITHET = {
  rainforest = "pluvialis", ["temperate forest"] = "silvatica", ["seasonal forest"] = "autumnalis", taiga = "borealis",
  wetland = "palustris", ["crystal forest"] = "crystallina", savanna = "savannae", grassland = "campestris",
  ["arcane meadow"] = "arcana", coast = "litoralis", tundra = "tundrae", alpine = "montana", ["cold desert"] = "frigida",
  ["hot desert"] = "deserti", ["ash fields"] = "cinerea", barren = "nuda", ["ice sheet"] = "glacialis",
}
local NOUN = {
  grazer = { "grazer", "browser", "strider", "nibbler", "trotter" }, predator = { "stalker", "hunter", "prowler", "fang" },
  scavenger = { "picker", "gleaner", "carrion-crawler" }, pollinator = { "flitter", "hummer", "dusting-wing" },
  decomposer = { "burrower", "mulch-worm", "rot-crawler" },
  tree = { "tree", "wood", "spire" }, shrub = { "bush", "thicket", "scrub" }, herb = { "wort", "grass", "bloom" },
  fungus = { "cap", "puffball", "shelf" },
}
local FLY_NOUN = { "wing", "glider", "skimmer", "soarer" }

local function hue_rgb(h, s, v)
  local c = v * s
  local x = c * (1 - math.abs((h / 60) % 2 - 1))
  local r, g, b
  if h < 60 then r, g, b = c, x, 0 elseif h < 120 then r, g, b = x, c, 0 elseif h < 180 then r, g, b = 0, c, x
  elseif h < 240 then r, g, b = 0, x, c elseif h < 300 then r, g, b = x, 0, c else r, g, b = c, 0, x end
  local m = v - c
  return { math.floor((r + m) * 255 + 0.5), math.floor((g + m) * 255 + 0.5), math.floor((b + m) * 255 + 0.5) }
end
local function mix(a, b, t)
  return { math.floor(a[1] + (b[1] - a[1]) * t + 0.5), math.floor(a[2] + (b[2] - a[2]) * t + 0.5),
           math.floor(a[3] + (b[3] - a[3]) * t + 0.5) }
end
local function rgb_hue(c)
  local r, g, b = c[1], c[2], c[3]
  local mx, mn = math.max(r, g, b), math.min(r, g, b)
  if mx == mn then return 0 end
  local h
  if mx == r then h = 60 * ((g - b) / (mx - mn))
  elseif mx == g then h = 60 * ((b - r) / (mx - mn) + 2)
  else h = 60 * ((r - g) / (mx - mn) + 4) end
  return math.floor(h % 360)
end
local function shades(c)
  return { mix(c, { 0, 0, 0 }, 0.45), c, mix(c, { 255, 255, 255 }, 0.3) }
end

local COLOUR_WORDS = { { 15, "russet" }, { 40, "amber" }, { 65, "golden" }, { 100, "olive" }, { 150, "green" },
                       { 190, "teal" }, { 240, "blue" }, { 275, "indigo" }, { 320, "violet" }, { 360, "rose" } }
local function colour_word(h, dark)
  if dark then return "dusk" end
  for _, w in ipairs(COLOUR_WORDS) do if h < w[1] then return w[2] end end
  return "russet"
end

-- Averages of a world's climate and magic over each biome's cells.
function S.biome_stats(d)
  local geo = require("gen.levels.geography")
  local c, out = d.cells, {}
  for i = 1, #c.biome do
    local id = geo.BIOMES[c.biome[i]].id
    local s = out[id]
    if not s then s = { n = 0, temp = 0, precip = 0, magic = 0 } out[id] = s end
    s.n = s.n + 1
    s.temp = s.temp + c.temp[i] - 273.15
    s.precip = s.precip + c.precip[i]
    s.magic = s.magic + (c.magic and c.magic[i] or 0)
  end
  for _, s in pairs(out) do
    s.temp, s.precip, s.magic = dm.round(s.temp / s.n, 2), math.floor(s.precip / s.n + 0.5), dm.round(s.magic / s.n, 4)
  end
  return out
end

local GIFTS = {
  life = "heals the wounds of what it touches", stellar = "glows softly through the night",
  tectonic = "warms itself on emberstone and smells of embers", belief = "changes shape with what is believed of it",
}

local function pick_lineage(rng, list, pred)
  local ok = {}
  for _, l in ipairs(list) do if pred(l) then ok[#ok + 1] = l end end
  if #ok == 0 then return nil end
  return ok[rng:int(1, #ok)]
end

local function flies(l) for _, m in ipairs(l.moves) do if m == "fly" then return true end end return false end

-- Builds one animal species of lineage l in biome b.
local function animal(env, rng, l, b, role)
  local st = env.stats[b]
  local dens = S.BIOME_LIFE[b][1]
  local g, p = env.gravity, env.pressure
  local lo, hi = l.size[1], l.size[2]
  if role == "pollinator" then hi = math.min(hi, 0.3) end
  if role == "predator" then lo = math.max(lo, (lo + hi) * 0.3) end
  local size = (lo + (hi - lo) * rng:next() * rng:next()) * (0.6 + 0.8 * dens) / math.sqrt(g)
  size = dm.clamp(size, 0.03, 8)
  local lift = p / g
  local can_fly = flies(l) and lift >= 0.25 and size < 3
  local glides = not can_fly and flies(l) and lift >= 0.1
  local move = can_fly and "fly" or (l.limbs == 0 and l.moves[1] or (glides and "glide" or l.moves[1]))
  if move == "fly" and not can_fly then move = "walk" end
  local coat = st.temp < 0 and "thick" or (st.temp > 28 and "thin" or "")
  local base = hue_rgb((l.hue + rng:int(-25, 25)) % 360, 0.35 + rng:next() * 0.3, 0.45 + rng:next() * 0.35)
  local ground = env.ground[b] or { 120, 110, 90 }
  local col = mix(base, ground, role == "grazer" and 0.45 or 0.25)
  if env.dark then col = mix(col, { 30, 22, 40 }, 0.45) end
  local sp = {
    kind = "animal", role = role, biome = b, lineage = l.id, limbs = l.limbs, covering = l.covering, coat = coat,
    move = move, flightless = flies(l) and not can_fly or nil,
    size = dm.round(size, 3), height = dm.round(size * l.shape / dm.pow(g, 0.3), 3),
    stockiness = dm.round((0.8 + rng:next() * 0.4) * math.sqrt(g), 3),
    colors = shades(col), hue = l.hue, abundance = S.ABUNDANCE[role],
    diet = role == "predator" and "meat" or (role == "scavenger" and "carrion" or (role == "decomposer" and "rot" or
           (role == "pollinator" and "nectar" or "plants"))),
  }
  if env.gift and st.magic > env.magic_strength * 0.45 and rng:chance(0.5) then sp.gift = GIFTS[env.gift] end
  if env.psionics > 0.6 and role == "predator" and rng:chance(env.psionics - 0.3) then
    sp.psionic = "senses the minds of its prey"
  end
  return sp
end

local function plant(env, rng, l, b, form)
  local fol = env.foliage[b]
  local c
  if l.leaf == "cap" then c = hue_rgb(rng:int(10, 50), 0.3 + rng:next() * 0.3, 0.55 + rng:next() * 0.3)
  elseif l.leaf == "shard" then c = hue_rgb(rng:int(180, 300), 0.4, 0.75)
  else c = fol[2 + rng:int(0, 1)] end
  c = mix(c, { 0, 0, 0 }, dm.clamp(1 - l.tone, 0, 0.5))
  c = mix(c, { 255, 255, 255 }, dm.clamp(l.tone - 1, 0, 0.3))
  local dens = S.BIOME_LIFE[b][1]
  local h = form == "tree" and (4 + rng:next() * 6) or (form == "shrub" and (0.6 + rng:next() * 1.2) or
            (form == "fungus" and (0.1 + rng:next() * 0.5) or (0.15 + rng:next() * 0.6)))
  h = h * (0.6 + 0.6 * dens) / dm.pow(env.gravity, 0.4)
  return {
    kind = "plant", role = form == "fungus" and "decomposer" or "producer", biome = b, lineage = l.id, form = form,
    leaf = l.leaf, height = dm.round(h, 3), colors = shades(c), hue = rgb_hue(c), abundance = S.ABUNDANCE[form == "fungus" and "decomposer" or
    "producer"] * (form == "tree" and 1 or 1.5),
  }
end

-- Names and a bestiary line for a species.
local function name(env, rng, sp, used)
  local l = env.lineage[sp.lineage]
  local noun
  if sp.kind == "plant" then noun = NOUN[sp.form][rng:int(1, #NOUN[sp.form])]
  elseif sp.move == "fly" and sp.role ~= "predator" then noun = FLY_NOUN[rng:int(1, #FLY_NOUN)]
  else noun = NOUN[sp.role][rng:int(1, #NOUN[sp.role])] end
  local adj
  local r = rng:int(1, 4)
  if sp.kind == "animal" and sp.coat == "thick" and r == 1 then adj = "shaggy"
  elseif sp.kind == "animal" and sp.stockiness > 1.3 and r == 2 then adj = "stout"
  elseif sp.gift and r == 3 then adj = "wonder"
  else adj = colour_word(sp.hue or 120, env.dark) end
  local stem = names.make(rng, "world"):lower()
  local common = adj .. " " .. stem .. "-" .. noun
  local genus = l.name:sub(1, 1):upper() .. l.name:sub(2)
  local epithet = EPITHET[sp.biome] or "vulgaris"
  if sp.role == "predator" then epithet = rng:chance(0.5) and "rapax" or epithet end
  if sp.move == "fly" then epithet = rng:chance(0.5) and "volans" or epithet end
  local latin = genus .. " " .. epithet
  local k = 1
  while used[latin] do
    k = k + 1
    latin = genus .. " " .. epithet .. ({ "", "minor", "major", "tertia", "quarta", "quinta", "sexta" })[math.min(k, 7)]
    if k > 7 then latin = genus .. " " .. epithet .. " " .. k end
  end
  used[latin] = true
  sp.name, sp.latin = common:sub(1, 1):upper() .. common:sub(2), latin
end

local function describe(env, sp)
  local where = "the " .. sp.biome
  if sp.kind == "plant" then
    local what = sp.form == "tree" and "tree" or (sp.form == "fungus" and "fungus" or (sp.form == "shrub" and "shrub" or "low plant"))
    return string.format("%s: a %s of %s, about %.1f m tall, with %s leaves; it spreads by %s.", sp.name, what, where,
                         sp.height, sp.leaf == "cap" and "no" or sp.leaf, env.lineage[sp.lineage].spread)
  end
  local legs = sp.limbs == 0 and "legless" or (sp.limbs .. "-limbed")
  local coat = sp.coat ~= "" and (sp.coat .. " ") or ""
  local text = string.format("%s: a %s, %s %s of %s, about %.1f m long and %.1f m tall, with %s%s", sp.name,
                             sp.stockiness > 1.25 and "stocky" or (sp.stockiness < 0.85 and "slender" or "sturdy"),
                             legs, sp.role, where, sp.size, sp.height, coat, sp.covering)
  if sp.move == "fly" then text = text .. "; it flies"
  elseif sp.flightless then text = text .. "; its winged kin fly elsewhere, but here the air is too thin"
  elseif sp.move ~= "walk" then text = text .. "; it " .. sp.move .. "s" end
  if sp.gift then text = text .. "; it " .. sp.gift end
  if sp.psionic then text = text .. "; it " .. sp.psionic end
  return text .. "."
end

-- The species pass: radiation of the lineages into every land biome.
function S.radiate(ctx)
  local d = ctx.data
  local life = d.life
  if not life or not life.lineages then return end
  local rng = ctx:random("species")
  local laws = ctx:ancestor("universe").data.laws
  local geo = require("gen.levels.geography")
  local env = {
    gravity = d.gravity, pressure = d.atmosphere.pressure, stats = S.biome_stats(d), lineage = {},
    dark = d.star_class == "M", psionics = laws.psionics or 0, gift = d.magic and d.magic.source ~= "none" and d.magic.source,
    magic_strength = d.magic and d.magic.strength or 0, foliage = {}, ground = {},
  }
  for _, l in ipairs(life.lineages) do env.lineage[l.id] = l end
  local plants, animals = {}, {}
  for _, l in ipairs(life.lineages) do if l.kind == "plant" then plants[#plants + 1] = l else animals[#animals + 1] = l end end
  local list, by_biome, used = {}, {}, {}
  local biomes = {}
  for b in pairs(env.stats) do if S.BIOME_LIFE[b] and S.BIOME_LIFE[b][1] > 0 then biomes[#biomes + 1] = b end end
  table.sort(biomes)
  local function add(sp)
    list[#list + 1] = sp
    sp.id = "s" .. #list
    name(env, rng, sp, used)
    by_biome[sp.biome] = by_biome[sp.biome] or {}
    table.insert(by_biome[sp.biome], sp.id)
    return sp
  end
  for _, b in ipairs(biomes) do
    local dens, trees = S.BIOME_LIFE[b][1], S.BIOME_LIFE[b][2]
    env.foliage[b] = PAL.foliage(d.star_class or "G", b)
    local bp = geo.BIOMES[geo.BIOME[b]].palette
    env.ground[b] = bp and bp[2] or { 120, 110, 90 }
    -- producers: trees where the biome has them, then shrubs and herbs
    local n = 2 + math.floor(dens * 5)
    local ntree = trees > 0.02 and math.max(1, math.floor(n * trees * 1.2 + 0.5)) or 0
    for k = 1, n do
      local want = k <= ntree and "tree" or (k % 2 == 0 and "shrub" or "herb")
      local l = pick_lineage(rng, plants, function(x)
        for _, f in ipairs(x.forms) do if f == want then return true end end
      end) or pick_lineage(rng, plants, function(x) return x.leaf ~= "cap" end)
      if l then
        local form = want
        local ok = false
        for _, f in ipairs(l.forms) do if f == want then ok = true end end
        if not ok then form = l.forms[#l.forms] end
        add(plant(env, rng, l, b, form))
      end
    end
    local cap = pick_lineage(rng, plants, function(x) return x.leaf == "cap" end)
    if cap and dens >= 0.2 then add(plant(env, rng, cap, b, "fungus")) end
    -- animals
    if #animals > 0 and dens >= 0.1 then
      local grazers = {}
      for _ = 1, 1 + math.floor(dens * 2.5) do
        local l = pick_lineage(rng, animals, function(x) return x.limbs >= 2 end) or animals[rng:int(1, #animals)]
        grazers[#grazers + 1] = add(animal(env, rng, l, b, "grazer"))
      end
      if dens >= 0.25 then
        for _ = 1, dens > 0.7 and 2 or 1 do
          local l = pick_lineage(rng, animals, function(x) return x.limbs >= 2 or x.covering == "chitin" end) or animals[1]
          local sp = add(animal(env, rng, l, b, "predator"))
          sp.prey = {}
          for _, gz in ipairs(grazers) do if gz.size <= sp.size * 2 then sp.prey[#sp.prey + 1] = gz.id end end
          if #sp.prey == 0 then -- pack hunters bring down the smallest grazer
            table.sort(grazers, function(a, c) return a.size < c.size end)
            sp.prey[1] = grazers[1].id
            sp.pack = true
          end
        end
      end
      if dens >= 0.4 and rng:chance(0.6) then
        add(animal(env, rng, pick_lineage(rng, animals, flies) or animals[rng:int(1, #animals)], b, "scavenger"))
      end
      local flyer = pick_lineage(rng, animals, flies)
      if flyer and dens >= 0.3 then add(animal(env, rng, flyer, b, "pollinator")) end
      local crawler = pick_lineage(rng, animals, function(x) return x.limbs == 0 end)
      if crawler and rng:chance(0.6) then add(animal(env, rng, crawler, b, "decomposer")) end
    end
  end
  -- who eats what: grazers the producers of their biome
  for _, sp in ipairs(list) do
    if sp.role == "grazer" or sp.role == "pollinator" then
      sp.eats = {}
      for _, id in ipairs(by_biome[sp.biome]) do
        local o = list[tonumber(id:sub(2))]
        if o.kind == "plant" and o.form ~= "fungus" then sp.eats[#sp.eats + 1] = id end
      end
    end
    sp.description = describe(env, sp)
  end
  life.species, life.by_biome = list, by_biome
  ctx:yield()
end

-- The species of a world by id.
function S.get(life, id) return life.species[tonumber(id:sub(2))] end

return S
