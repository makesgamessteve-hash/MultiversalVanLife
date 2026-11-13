-- Multiversal Van Life - palettes of generated places (MIT).
--
-- A land's materials follow from where it is: plants take the colour that
-- best absorbs their star's light (green under a yellow sun, near-black and
-- deep purple under a dim red one, red and orange under blue-white stars),
-- stone takes the colour of the bedrock under the land, soil follows the
-- climate and the bedrock, water the air and the light. The colours repaint
-- the hand-made textures (mvl.texture_recolor), the terrain's vertex
-- palette, the trees and bushes, and the boulders that lie about.
local dm = require("gen.dmath")

local PAL = {}

-- Foliage gradients (dark to light) by the star's spectral class.
PAL.FOLIAGE = {
  O = { { 112, 28, 22 }, { 168, 50, 32 }, { 210, 92, 50 }, { 234, 148, 88 } },
  B = { { 122, 32, 24 }, { 178, 60, 36 }, { 216, 106, 54 }, { 236, 160, 94 } },
  A = { { 120, 54, 28 }, { 174, 92, 38 }, { 210, 136, 54 }, { 230, 182, 94 } },
  F = { { 66, 88, 26 }, { 106, 122, 36 }, { 152, 152, 54 }, { 194, 184, 94 } },
  G = { { 28, 62, 26 }, { 48, 94, 38 }, { 84, 126, 54 }, { 138, 158, 88 } },
  K = { { 50, 56, 28 }, { 80, 82, 38 }, { 116, 110, 56 }, { 158, 146, 94 } },
  M = { { 10, 8, 14 }, { 26, 16, 36 }, { 50, 30, 68 }, { 84, 54, 108 } },
}

-- Biomes whose plants are sparse, dry or cold: their foliage fades
-- towards the colour of dry grass.
local FADED = { savanna = 0.35, ["hot desert"] = 0.5, ["cold desert"] = 0.5, tundra = 0.4, alpine = 0.4,
                barren = 0.6, ["ash fields"] = 0.5 }

local function clamp255(v) return math.floor(dm.clamp(v, 0, 255) + 0.5) end
local function shade(c, k) return { clamp255(c[1] * k), clamp255(c[2] * k), clamp255(c[3] * k) } end
local function mix(a, b, t)
  return { clamp255(a[1] + (b[1] - a[1]) * t), clamp255(a[2] + (b[2] - a[2]) * t), clamp255(a[3] + (b[3] - a[3]) * t) }
end

-- The foliage gradient of a biome under a star class.
function PAL.foliage(class, biome)
  local base = PAL.FOLIAGE[class] or PAL.FOLIAGE.G
  local fade = FADED[biome] or 0
  local out = {}
  for i, c in ipairs(base) do out[i] = mix(c, { 150, 136, 98 }, fade * (0.4 + 0.15 * i)) end
  if biome == "taiga" or biome == "wetland" then
    for i, c in ipairs(out) do out[i] = shade(c, 0.85) end
  end
  return out
end

-- Four shades of a rock (dark to light).
function PAL.stone(rock)
  local c = rock.color
  return { shade(c, 0.55), shade(c, 0.78), shade(c, 1.0), mix(c, { 255, 255, 255 }, 0.25) }
end

-- Soil: the bedrock weathered under the climate.
function PAL.soil(rock, temperature, precipitation)
  local climate
  if temperature < 0 then climate = { 96, 90, 84 }
  elseif precipitation < 300 then climate = { 176, 132, 92 }
  elseif precipitation > 1200 and temperature > 15 then climate = { 78, 52, 34 }
  else climate = { 104, 80, 56 } end
  local c = mix(rock.color, climate, 0.6)
  return { shade(c, 0.6), shade(c, 0.85), c, mix(c, { 255, 255, 255 }, 0.15) }
end

-- Sand: the bedrock ground fine.
function PAL.sand(rock)
  local c = mix(rock.color, { 214, 196, 150 }, 0.5)
  return { shade(c, 0.7), shade(c, 0.88), c, mix(c, { 255, 255, 255 }, 0.2) }
end

-- Water tint (0..1): the air's colour in the star's light.
function PAL.water(gases, light)
  local c = { 0.55, 0.75, 0.9 }
  if gases[1] == "methane" then c = { 0.45, 0.78, 0.72 }
  elseif gases[1] == "sulphur" or gases[2] == "sulphur" then c = { 0.8, 0.78, 0.5 } end
  return { dm.round(c[1] * (0.6 + 0.4 * light[1]), 3), dm.round(c[2] * (0.6 + 0.4 * light[2]), 3),
           dm.round(c[3] * (0.6 + 0.4 * light[3]), 3) }
end

-- Repaints a colour that is green (a plant's) along a foliage gradient,
-- keeping its brightness; other colours are returned as they are.
function PAL.recolor(c, foliage)
  if not (c[2] > c[1] + 6 and c[2] > c[3] + 6) then return { c[1], c[2], c[3] } end
  local t = dm.clamp((c[1] + c[2] + c[3]) / 450, 0, 1)
  local n = #foliage
  local x = t * (n - 1)
  local i = math.min(math.floor(x), n - 2)
  return mix(foliage[i + 1], foliage[i + 2], x - i)
end

-- The materials of a land at `cell` of planet data `P` with biome `biome`
-- (from gen/levels/geography.lua) and climate (°C, mm).
function PAL.materials(P, cell, biome, climate)
  local planet = require("gen.levels.planet")
  local rock = planet.ROCKS[P.cells.rock[cell]] or planet.ROCKS[1]
  local m = {
    rock = rock.name, stone = PAL.stone(rock), sand = PAL.sand(rock),
    soil = PAL.soil(rock, climate.temperature, climate.precipitation),
    water = PAL.water(P.atmosphere.gases, P.light or { 1, 1, 1 }),
    foliage = biome.family == "crystal" and nil or PAL.foliage(P.star_class or "G", biome.id),
  }
  return m
end

-- The terrain palette of a land: its biome's colours with the plants
-- repainted, and its cliffs in the bedrock's colour.
function PAL.terrain(T, m, biome)
  if not m then return end
  if m.foliage and T.palette then
    for i, c in ipairs(T.palette) do T.palette[i] = PAL.recolor(c, m.foliage) end
  end
  if biome.texture == "stone" and biome.id ~= "ice sheet" then
    T.palette = { m.stone[2], m.stone[3], m.stone[3], m.stone[4] }
  elseif biome.texture == "sand" then
    T.palette = { m.sand[2], m.sand[3], m.sand[3], m.sand[4] }
  end
  T.slope_color = m.stone[2]
end

-- Texture recolourings by name: the ground and the plants.
local RECOLOR = {
  grass = { "foliage", "green" }, tree_oak = { "foliage", "green" }, tree_pine = { "foliage", "green" },
  bush = { "foliage", "green" }, flowers = { "foliage", "green" },
  stone = { "stone" }, cobble = { "stone" }, sand = { "sand" }, dirt = { "soil" },
}

-- The texture `name` as the land's materials paint it (or as it is).
function PAL.texture(m, name)
  local path = "textures/" .. name .. ".tga"
  local r = m and RECOLOR[name]
  if r and m[r[1]] then return mvl.texture_recolor(path, m[r[1]], r[2]) end
  return mvl.texture(path)
end

-- Voxel boulders in the bedrock's colours: `count` shapes, built once.
function PAL.boulders(m, seed, count)
  local out = {}
  local rng = mvl.rng(seed)
  for k = 1, count do
    local g = mvl.voxels(16, 16, 12)
    for i, c in ipairs(m.stone) do g:color(i, c[1], c[2], c[3]) end
    local rx, ry, rz = 4 + rng:next() * 3.5, 4 + rng:next() * 3.5, 3 + rng:next() * 3
    g:ellipsoid(8, 8, rz * 0.6, rx, ry, rz, 2)
    for _ = 1, 3 do
      local bx, by = 8 + (rng:next() - 0.5) * rx, 8 + (rng:next() - 0.5) * ry
      g:sphere(bx, by, rz * 0.9, 1.5 + rng:next() * 2, 3)
    end
    g:ellipsoid(8, 8, 0.5, rx * 0.95, ry * 0.95, 1.2, 1) -- the dark, earthy foot
    g:line(8 - rx * 0.5, 8, rz * 0.8, 8 + rx * 0.4, 8 + ry * 0.3, rz * 1.1, 0.9, 4)
    out[k] = { mesh = g:mesh(0.125), radius = math.max(rx, ry) * 0.125 }
    g:free()
  end
  return out
end

return PAL
