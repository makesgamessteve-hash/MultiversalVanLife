-- Materials of generated lands: plants coloured by their star's light, stone
-- by the bedrock, boulders of the local rock, textures repainted to match.
local gen = require("gen")
local PAL = require("gen.visuals.palette")
local P = gen.planet
P.LEVEL = 3
local G = gen.run.new(gen.cosmos, { seed = 909, mods = {} })

local function lum(c) return c[1] + c[2] + c[3] end

-- Countries (with a dry land) of rocky worlds around stars of `class` (or any).
local function each_country(class, fn)
  for s = 0, 400 do
    local saddr = "u" .. (1 + s % 9) .. ".g" .. (s % 13) .. ".c" .. (s % 3) .. ".s" .. (s % 7)
    local ok, sys = pcall(G.generate, G, saddr)
    if ok and (not class or sys.data.star.class == class) then
      for i = 0, sys.data.planets - 1 do
        if sys.children[i].kind == "rocky" then
          local p = G:generate(saddr .. ".p" .. i)
          for k = 0, (p.data.continents or 0) - 1 do
            local cont = G:generate(p.address .. ".k" .. k)
            for _, n in ipairs(gen.util.sorted_keys(cont.children)) do
              local c = G:generate(cont.address .. ".n" .. n)
              if c.data.district then
                local r = fn(p, c)
                if r then return r end
              end
            end
          end
        end
      end
    end
  end
end

local function dry_land(c)
  for l = 0, 255, 7 do
    local gx, gz = gen.land.grid(l)
    if gen.land.raw_height(c.data.terrain, gx * 2048, gz * 2048) > 3 then return G:generate(c.address .. ".l" .. l) end
  end
end

local GREEN = { ["temperate forest"] = true, rainforest = true, ["seasonal forest"] = true, grassland = true,
                taiga = true, wetland = true }
local function leafy_land(class)
  return each_country(class, function(p, c)
    if GREEN[c.data.biome] and p.data.water == "liquid" then
      local land = dry_land(c)
      if land and land.data.materials and land.data.materials.foliage then return land end
    end
  end)
end

-- ------------------------------------------------------ red sun foliage
local red = leafy_land("M")
test.expect(red, "a leafy land under a red dwarf")
for _, c in ipairs(red.data.materials.foliage) do
  test.expect(lum(c) < 260, "red-sun foliage is dark")
  test.expect(c[3] >= c[2], "and purple rather than green")
end
local yellow = leafy_land("G")
test.expect(yellow, "a leafy land under a yellow star")
for _, c in ipairs(yellow.data.materials.foliage) do
  test.expect(c[2] > c[1] and c[2] > c[3], "yellow-star foliage is green")
end
test.expect(lum(yellow.data.materials.foliage[3]) > lum(red.data.materials.foliage[3]) * 1.5, "and brighter")
-- blue-white stars: red and orange plants
local hot = PAL.foliage("B", "temperate forest")
test.expect(hot[3][1] > hot[3][2] and hot[3][1] > hot[3][3], "blue-white stars grow red foliage")
-- the terrain's green is repainted along the foliage
for _, c in ipairs(red.data.terrain.palette) do
  test.expect(not (c[2] > c[1] + 6 and c[2] > c[3] + 6), "no green left in the red-sun land's ground colours")
end
-- textures: the plants and grass are repainted, other textures are not
mvl.texture("textures/tree_oak.tga")
local plain = mvl.texture("textures/tree_oak.tga")
local painted = PAL.texture(red.data.materials, "tree_oak")
test.expect(painted > 0 and painted ~= plain, "a red-sun tree texture of its own")
test.eq(PAL.texture(red.data.materials, "tree_oak"), painted, "made once")
test.eq(PAL.texture(red.data.materials, "roof"), mvl.texture("textures/roof.tga"), "roofs keep their texture")
test.eq(PAL.texture(nil, "grass"), mvl.texture("textures/grass.tga"), "places without materials keep the originals")
test.expect(PAL.texture(red.data.materials, "grass") ~= PAL.texture(yellow.data.materials, "grass"),
            "grass differs between the two suns")

-- ------------------------------------------------------------ local stone
local RS = P.ROCK["red sandstone"]
local sand = each_country(nil, function(p, c)
  if p.data.cells.rock[c.data.district.cell] == RS then
    local land = dry_land(c)
    if land and land.data.place and land.data.place.cell == c.data.district.cell then return land end
  end
end)
test.expect(sand, "a land on red sandstone")
local m = sand.data.materials
test.eq(m.rock, "red sandstone", "the land knows its bedrock")
local rock = P.ROCKS[RS].color
test.eq(m.stone[3][1], rock[1], "its stone is the bedrock's colour")
test.eq(m.stone[3][2], rock[2], "(green)")
test.eq(m.stone[3][3], rock[3], "(blue)")
for _, c in ipairs(m.stone) do test.expect(c[1] > c[2] and c[2] > c[3], "red sandstone shades are red") end
test.eq(sand.data.terrain.slope_color[1], m.stone[2][1], "cliffs show the bedrock")
test.expect(PAL.texture(m, "stone") ~= mvl.texture("textures/stone.tga"), "stone textures are repainted")
-- every land's materials follow the rock of its cell
for _, land in ipairs({ red, yellow, sand }) do
  local planet = G:node(land.address:match("^(.-%.p%d+)"))
  test.eq(land.data.materials.rock, P.ROCKS[planet.data.cells.rock[land.data.place.cell]].name, "rock of the cell")
end

-- ------------------------------------------------------ in the game
P.LEVEL = 5
H.new_game_in_van(1002)
local s = game.debug.story.signals()[1]
H.travel_to(s.address)
H.step_outside()
local w = game.debug.world.current
local d = w.land_node.data
test.expect(d.materials, "a generated land has materials")
local rocks = 0
for _, c in pairs(w.streamer.loaded) do rocks = rocks + (c.rocks or 0) end
test.expect(rocks > 0, "boulders of the local rock lie about: " .. rocks)
local shapes = w.streamer.boulders[w.land_node.address]
test.eq(#shapes, 3, "three boulder shapes per land")
test.expect(shapes[1].mesh > 0 and shapes[1].radius > 0, "made of voxels")
local md = gen.bible.export(gen.world, s.address)
test.expect(md:find("**materials**", 1, true) and md:find("**foliage**", 1, true), "the bible lists the palette")
test.expect(md:find("Sky:", 1, true), "and the sky")
