-- Climate, water and biomes on planets, and lands that know their place.
local gen = require("gen")
local P, GEO = gen.planet, gen.geography
local function runner(seed) return gen.run.new(gen.cosmos, { seed = seed, mods = {} }) end

local function rocky_planets(G, saddr)
  local sys = G:generate(saddr)
  local out = {}
  for i = 0, sys.data.planets - 1 do
    if sys.children[i].kind == "rocky" then out[#out + 1] = saddr .. ".p" .. i end
  end
  return out
end

-- ---------------------------------- rivers run downhill (200 seeds)
P.LEVEL = 3
local traced, biomes_seen, wet_hot, rainforestish = 0, {}, 0, 0
for seed = 1, 200 do
  local G = runner(seed * 13)
  for _, addr in ipairs(rocky_planets(G, "u3.g2.c0.s" .. (seed % 5))) do
    local p = G:generate(addr)
    local c = p.data.cells
    if c and c.flow_to then
      for i = 1, #c.flow_to do
        if c.river[i] then
          local cur, steps = i, 0
          while c.flow_to[cur] > 0 and steps < #c.flow_to do
            local nxt = c.flow_to[cur]
            if c.filled[nxt] > c.filled[cur] then error("river flows uphill at seed " .. seed) end
            cur, steps = nxt, steps + 1
          end
          traced = traced + 1
        end
        local b = GEO.BIOMES[c.biome[i]].id
        biomes_seen[b] = true
        local magic = c.magic and c.magic[i] or 0
        -- (under thin air the scorched places above 60 °C are barren)
        local thin = p.data.atmosphere.pressure < 0.3
        if c.temp[i] > 273.15 + 22 and c.precip[i] > 2200 and c.elevation[i] > 0 and c.elevation[i] < 3 and
           not (thin and c.temp[i] > 273.15 + 60) and
           not c.lake[i] and c.setting[i] ~= P.SETTING["volcanic arc"] and magic < 0.3 then
          wet_hot = wet_hot + 1
          -- (a crystal forest is the rainforest of a strongly magical world)
          if b == "rainforest" or b == "wetland" or b == "crystal forest" then rainforestish = rainforestish + 1 end
        end
      end
    end
  end
  local problems = gen.check.run(G)
  test.eq(#problems, 0, "seed " .. seed .. ": " .. (problems[1] and problems[1].message or ""))
end
test.expect(traced > 500, "river paths traced downhill: " .. traced)
test.expect(wet_hot > 0, "hot and very wet places exist")
test.eq(rainforestish, wet_hot, "hot and very wet places are rainforest or wetland (or their magical variant)")
local n = 0
for _ in pairs(biomes_seen) do n = n + 1 end
test.expect(n >= 14, "biome variety: " .. n .. " different biomes")

-- -------------------------------------------- lands know their place
P.LEVEL = 5
H.new_game_in_van(6006)
local s = game.debug.story.signals()[1]
local G = gen.world
local land = G:generate(s.address)
local d = land.data
test.expect(d.continent and d.country and d.biome and d.climate, "the land names its continent, country, biome, climate")
test.expect(d.climate.temperature and d.climate.precipitation and d.place.cell, "and its climate and cell")
test.eq(d.country, G:node(gen.address.parent(s.address)).summary.name, "the country it belongs to")
test.eq(d.continent, G:node(gen.address.parent(gen.address.parent(s.address))).data.name, "the continent")
local planet = G:node(s.address:match("^(.-)%.k%d+"))
test.eq(GEO.BIOMES[planet.data.cells.biome[d.place.cell]].id, d.biome, "the biome of its planet cell")
test.expect(not GEO.BIOMES[GEO.BIOME[d.biome]].water, "signals lead to dry land")
local md = gen.bible.export(G, s.address)
test.expect(md:find("in the " .. d.biome .. " of " .. d.country, 1, true), "the bible tells where the land lies")
