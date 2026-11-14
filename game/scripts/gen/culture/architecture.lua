-- Multiversal Van Life - architecture styles and dress (MIT).
--
-- A culture's style vector follows from its land, its body, its faith and
-- what it can build:
--   material   stone where masons live among mountains or few trees, timber
--              in forests, mud brick in dry lands, hides for herders who
--              have not learnt masonry
--   plan       towers for flyers, burrows for hives with mandibles,
--              courtyards in dry hierarchical lands, longhouses for forest
--              clans, round huts for herders, squares otherwise
--   roof       steep where rain and snow fall, flat in deserts, cones on
--              round huts, turf on burrows, domes under sky faiths in heat
--   walls      thick in cold and heat
--   openings   doors sized to the people's height and build; hatches in the
--              roof for peoples with wings
--   ornament   from the faith's first motif (crescents, discs, flames,
--              waves, spirals); temples face the sacred sky object
--   palette    stone in the colours of the bedrock (a land repaints it in
--              its own rock), timber, roofs and accents
-- Dress: robes in heat, furs in the cold, harnesses for winged and
-- chitinous bodies, wraps in wet lands, tunics otherwise; dyed from local
-- plants; headdresses where hierarchy is high, sashes for collectives.
local dm = require("gen.dmath")

local A = {}

local WET = { rainforest = true, wetland = true, ["temperate forest"] = true, ["seasonal forest"] = true, coast = true }
local COLD = { taiga = true, tundra = true, alpine = true, ["ice sheet"] = true, ["cold desert"] = true }
local DRY = { ["hot desert"] = true, ["cold desert"] = true, savanna = true, barren = true, ["ash fields"] = true }

local ORNAMENTS = {
  ["twin moon gods"] = "crescents", ["moon pantheon"] = "crescents", ["moon mother"] = "crescents",
  ["eclipse omens"] = "discs", ["sun father"] = "discs", ["burning eye"] = "discs", ["ember sun"] = "discs",
  ["fire mother"] = "flames", ["sea mother"] = "waves", ["flood father"] = "waves", ["river of stars"] = "spirals",
  ["world egg"] = "spirals", ["queen mother"] = "spirals",
}

local function shade(c, k) return { math.floor(dm.clamp(c[1] * k, 0, 255)), math.floor(dm.clamp(c[2] * k, 0, 255)),
                                    math.floor(dm.clamp(c[3] * k, 0, 255)) } end

-- The style of a culture: species s, region r (traditions.region), faith
-- rel, values v, technology tech, rock colour (bedrock of the region).
function A.style(rng, s, r, rel, v, tech, rock, chemistry)
  local a = s.anatomy
  local biome = r.biome
  local masonry = tech.has.masonry or tech.level >= 2
  local material
  if masonry and (r.mountains > 0.15 or r.forest < 0.15) then material = "stone"
  elseif r.forest >= 0.3 then material = "timber"
  elseif r.dry >= 0.3 then material = "mud brick"
  elseif tech.has.herding and not masonry then material = "hide"
  else material = masonry and "stone" or "timber" end
  local plan
  if a.wings then plan = "tower"
  elseif a.mouth == "mandibles" and s.social == "hive" then plan = "burrow"
  elseif r.dry >= 0.25 and v.hierarchy > 0 then plan = "courtyard"
  elseif v.collective > 0.3 and r.forest > 0.2 then plan = "longhouse"
  elseif material == "hide" then plan = "round"
  else plan = rng:chance(0.2) and "round" or "square" end
  local roof, pitch
  if plan == "burrow" then roof, pitch = "turf", 0.5
  elseif plan == "round" or (plan == "tower" and not (DRY[biome] or r.dry >= 0.3)) then roof, pitch = "cone", 0.8
  elseif DRY[biome] or r.dry >= 0.3 then roof, pitch = "flat", 0
  elseif COLD[biome] or WET[biome] then roof, pitch = "gable", 0.95
  else roof, pitch = rng:chance(0.5) and "hip" or "gable", 0.6 end
  local sky_faith = false
  for _, m in ipairs(rel.motifs) do if m.id:find("sun") or m.id:find("moon") or m.id == "burning eye" then sky_faith = true end end
  if sky_faith and DRY[biome] and rng:chance(0.5) then roof, pitch = "dome", 0.7 end
  local first = rel.motifs[1] and rel.motifs[1].id
  -- colours
  local stone = rock or { 150, 140, 125 }
  local timber = chemistry == "silicon-sulphur" and { 170, 160, 130 } or { 112, 78, 48 }
  local wall
  if material == "stone" then wall = stone
  elseif material == "timber" then wall = timber
  elseif material == "mud brick" then wall = { 176, 132, 92 }
  else wall = { 168, 140, 104 } end
  local roofc
  if roof == "turf" then roofc = { 80, 104, 56 }
  elseif roof == "flat" or roof == "dome" then roofc = shade(wall, 1.1)
  elseif material == "stone" and tech.has.pottery then roofc = { 156, 72, 48 }
  else roofc = { 168, 150, 86 } end
  local hue = s.hue or 30
  local accent = ({ { 180, 60, 50 }, { 60, 90, 170 }, { 200, 160, 60 }, { 70, 130, 90 }, { 140, 80, 150 } })[hue % 5 + 1]
  local h = a.height or 1.7
  return {
    material = material, plan = plan, roof = roof, pitch = pitch,
    wall = (COLD[biome] or DRY[biome]) and 2 or 1,
    door = { h = math.floor(dm.clamp(h * 1.15 / 0.125, 10, 40)), w = math.floor(dm.clamp(4 + (a.build or 1) * 3 + (a.wings and 4 or 0), 5, 14)) },
    roof_entry = a.wings or false,
    ornament = ORNAMENTS[first] or "none",
    sky_faith = sky_faith,
    storeys = math.min(3, 1 + (tech.level >= 4 and 1 or 0) + ((v.hierarchy > 0.5 and plan ~= "burrow") and 1 or 0)),
    palette = { wall = wall, wall_dark = shade(wall, 0.72), roof = roofc, roof_dark = shade(roofc, 0.72), wood = timber,
                accent = accent },
    dress = A.dress(rng, s, r, v),
  }
end

-- Clothing of a people.
function A.dress(rng, s, r, v)
  local a = s.anatomy
  local garment
  if a.wings or a.covering == "chitin" then garment = "harness"
  elseif COLD[r.biome] then garment = "furs"
  elseif DRY[r.biome] or r.dry >= 0.25 then garment = "robe"
  elseif WET[r.biome] then garment = "wrap"
  else garment = "tunic" end
  local dye
  for _, sp in ipairs(r.species) do if sp.kind == "plant" and sp.form ~= "tree" then dye = sp.colors[2] break end end
  dye = dye or ({ { 150, 60, 50 }, { 60, 80, 140 }, { 170, 140, 60 } })[rng:int(1, 3)]
  local trim = ({ { 220, 200, 150 }, { 40, 40, 50 }, { 200, 80, 60 }, { 230, 230, 230 } })[rng:int(1, 4)]
  if garment == "furs" then dye = { 120, 96, 70 } end
  return { garment = garment, color = dye, trim = trim,
           status = v.hierarchy > 0.4 and "headdress" or (v.collective > 0.4 and "sash" or "none") }
end

-- The style a land builds in: the culture's style with its own bedrock.
function A.local_style(style, stone)
  local out = require("gen.util").copy(style)
  if stone and style.material == "stone" then
    out.palette.wall = { stone[3][1], stone[3][2], stone[3][3] }
    out.palette.wall_dark = { stone[2][1], stone[2][2], stone[2][3] }
    if out.roof == "flat" or out.roof == "dome" then out.palette.roof, out.palette.roof_dark = out.palette.wall, out.palette.wall_dark end
  end
  return out
end

function A.describe(st)
  return string.format("%s %s houses with %s roofs%s, %s ornaments; dress: %s%s", st.material, st.plan, st.roof,
                       st.roof_entry and " (entered from above)" or "", st.ornament, st.dress.garment,
                       st.dress.status ~= "none" and (" with " .. st.dress.status .. "s") or "")
end

return A
