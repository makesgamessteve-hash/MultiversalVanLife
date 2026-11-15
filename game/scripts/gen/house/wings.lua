-- Multiversal Van Life - souvenir wings of the house (MIT License).
--
-- Every people the player visits leaves a souvenir (`wings.souvenir`): their
-- name, species, the architecture of the land visited (materials, colours,
-- ornaments, door sizes, height), one of them (body and dress) and colours
-- of their plants. The blocks round the core, in a spiral (`wings.ORDER`),
-- become their wings in the order of the visits: built in their style
-- (`wings.style`), with a statue of one of them in a hall, their plants in
-- pots and a sign with their name.
local W = {}

local function rgb(c)
  if not c then return nil end
  local k = (c[1] <= 1 and c[2] <= 1 and c[3] <= 1) and 255 or 1
  return { math.floor(c[1] * k + 0.5), math.floor(c[2] * k + 0.5), math.floor(c[3] * k + 0.5) }
end
local function copy(t)
  if type(t) ~= "table" then return t end
  local o = {}
  for k, v in pairs(t) do o[k] = copy(v) end
  return o
end

-- The souvenir of the people of a land node (nil when nobody lives there).
function W.souvenir(node, planet_name, night)
  local d = node.data
  if not d.culture or not d.architecture then return nil end
  local planet = node.address:match("^(.-%.p%d+)") or node.address
  local a = d.architecture
  local person
  for _, p in ipairs(d.people or {}) do
    if p.body and p.body.anatomy then person = p.body break end
  end
  local plants = {}
  for _, h in ipairs(d.habitats or {}) do
    for _, sp in ipairs(h.plants or {}) do
      if #plants < 2 and sp.colors and sp.colors[1] then
        plants[#plants + 1] = { name = sp.name, color = rgb(sp.colors[#sp.colors] or sp.colors[1]) }
      end
    end
  end
  local foliage = {}
  for i, c in ipairs(d.materials and d.materials.foliage or {}) do if i <= 3 then foliage[i] = rgb(c) end end
  return {
    key = planet .. "#" .. tostring(d.culture.id), name = d.culture.name, species = d.culture.species,
    planet = planet_name, land = d.name, night = night,
    style = { material = a.material, ornament = a.ornament, height = a.height or 1.7, roof = a.roof,
              door = copy(a.door), palette = copy(a.palette) },
    person = person and { anatomy = copy(person.anatomy), hue = person.hue, dress = copy(person.dress),
                          accent = copy(person.accent) } or nil,
    plants = plants, foliage = foliage,
  }
end

-- The blocks given to wings, in order: rings round the core, each from the
-- north going round; never the blocks in front of the cab or behind the
-- garden door.
W.ORDER = {}
do
  for ring = 1, 9 do
    local ring_blocks = {}
    for bx = -ring, ring do
      for bz = -ring, ring do
        if math.max(math.abs(bx), math.abs(bz)) == ring and not (bz == 0 and math.abs(bx) == 1) then
          ring_blocks[#ring_blocks + 1] = { bx, bz, math.atan(bx, bz) % (2 * math.pi) }
        end
      end
    end
    table.sort(ring_blocks, function(p, q) return p[3] < q[3] end)
    for _, b in ipairs(ring_blocks) do W.ORDER[#W.ORDER + 1] = { b[1], b[2] } end
  end
end

-- block key -> { souvenir, index } for a list of souvenirs
function W.assign(list)
  local out = {}
  for i, s in ipairs(list) do
    local b = W.ORDER[(i - 1) % #W.ORDER + 1]
    out[b[1] .. "," .. b[2]] = { souvenir = s, index = i }
  end
  return out
end

local function mix(a, b, t)
  return { math.floor(a[1] + (b[1] - a[1]) * t), math.floor(a[2] + (b[2] - a[2]) * t), math.floor(a[3] + (b[3] - a[3]) * t) }
end
local function shade(c, k) return { math.min(255, math.floor(c[1] * k)), math.min(255, math.floor(c[2] * k)), math.min(255, math.floor(c[3] * k)) } end

local FINISH = { stone = { wall = "stone", floor = "flags" }, timber = { wall = "panels", floor = "boards" },
                 ["mud brick"] = { wall = "brick", floor = "tiles" }, hide = { wall = "hide", floor = "carpet" } }

-- The room style of a wing (gen/house/rooms.lua) from its souvenir.
function W.style(s)
  local st = s.style or {}
  local p = st.palette or {}
  local wall = p.wall or { 180, 170, 150 }
  local dark = p.wall_dark or shade(wall, 0.75)
  local wood = p.wood or { 120, 80, 50 }
  local accent = p.accent or { 200, 160, 60 }
  local roof = p.roof or shade(wood, 1.1)
  local f = FINISH[st.material] or FINISH.stone
  local fol = s.foliage or {}
  local colors = {
    wall = wall, wall2 = mix(wall, dark, 0.5), wall_dark = dark, trim = accent, accent = accent,
    dado = wood, dado2 = shade(wood, 0.8), beam = shade(wood, 0.8), ceiling = mix(wall, { 240, 236, 226 }, 0.5),
    floor = f.floor == "boards" and shade(wood, 1.1) or mix(dark, roof, 0.4),
    floor2 = f.floor == "boards" and wood or mix(wall, roof, 0.5), floor3 = shade(dark, 0.8),
    rug = roof, rug2 = accent, rug3 = dark, fabric = roof, fabric2 = accent,
    leaf = fol[1], leaf2 = fol[2], leaf3 = fol[3],
    flower = s.plants and s.plants[1] and s.plants[1].color or nil,
    flower2 = s.plants and s.plants[2] and s.plants[2].color or nil,
  }
  return { wall = f.wall, floor = f.floor, dado = st.material ~= "hide", beams = st.material == "timber",
           frieze = st.ornament ~= "none" and st.ornament or "bands", colors = colors }
end

-- Doorways sized to the people (taller for tall peoples, never too low for
-- the player) and the height of the wing's rooms.
function W.sizes(s)
  local h = (s.style and s.style.height) or 1.7
  return math.max(2.25, math.min(4.5, 1.35 * h)), math.max(3.5, math.min(7.5, 2.2 * h))
end

return W
