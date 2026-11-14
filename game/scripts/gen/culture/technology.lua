-- Multiversal Van Life - technology and magic traditions (MIT).
--
-- A dependency graph from fire to spaceflight. Each technology needs the
-- ones before it and what the culture's lands (or its trade partners)
-- offer: ores, fuels, crops and beasts to tame, a coast, air to fly in,
-- stable times. How far a culture gets also depends on how many eras it has
-- had to develop (history decides that per era from phase 19 on). Where
-- magic is strong and common, magical traditions grow beside the machines
-- and replace some of them (magelight instead of electricity, skyships
-- instead of engines); where minds touch, psionic arts do the same.
local T = {}

T.NODES = {
  { id = "fire", tier = 0 }, { id = "stone tools", tier = 0 },
  { id = "pottery", tier = 1, requires = { "fire" } },
  { id = "agriculture", tier = 1, needs = { crops = true } },
  { id = "herding", tier = 1, needs = { herd = true } },
  { id = "weaving", tier = 1, any = { "agriculture", "herding" } },
  { id = "boats", tier = 1, needs = { coast = true } },
  { id = "copper working", tier = 2, requires = { "pottery" }, needs = { resource = "copper" } },
  { id = "writing", tier = 2, any = { "agriculture", "herding" }, needs = { stability = 0.3 } },
  { id = "the wheel", tier = 2, requires = { "pottery" }, needs = { draught = true } },
  { id = "masonry", tier = 2, requires = { "stone tools", "pottery" } },
  { id = "bronze", tier = 3, requires = { "copper working" }, needs = { resource = "tin" } },
  { id = "sailing", tier = 3, requires = { "boats", "weaving" } },
  { id = "mathematics", tier = 3, requires = { "writing" } },
  { id = "iron working", tier = 4, requires = { "copper working" }, needs = { resource = "iron" } },
  { id = "steel", tier = 5, requires = { "iron working" }, needs = { fuel = true } },
  { id = "printing", tier = 5, requires = { "writing", "iron working" } },
  { id = "optics", tier = 5, requires = { "mathematics", "masonry" } },
  { id = "steam power", tier = 6, requires = { "steel" }, needs = { fuel = true } },
  { id = "electricity", tier = 7, requires = { "steam power", "mathematics" },
    magic = "magelight", note = "light and power drawn from magic" },
  { id = "radio", tier = 8, requires = { "electricity" }, magic = "scrying", psionic = "farspeech" },
  { id = "powered flight", tier = 8, requires = { "electricity" }, needs = { air = 0.3 }, magic = "skyships" },
  { id = "computing", tier = 9, requires = { "electricity" }, psionic = "the shared mind" },
  { id = "spaceflight", tier = 10, requires = { "computing", "powered flight" }, needs = { fuel = true } },
}
T.MAIN = { fire = true, pottery = true, ["copper working"] = true, bronze = true, ["iron working"] = true, steel = true,
           ["steam power"] = true, electricity = true, radio = true, computing = true, spaceflight = true }
T.NODE = {}
for _, n in ipairs(T.NODES) do T.NODE[n.id] = n end

T.TRADITIONS = {
  life = "green healers who mend flesh and grow living houses",
  stellar = "star-singers who weave light into tools",
  tectonic = "earth-shapers who raise walls and draw heat from the deep",
  belief = "dream-weavers who make what many believe come true",
}

local function has(cond, r)
  return cond.resources[r] or (cond.trade and cond.trade[r]) or false
end

local function met(n, cond, known)
  for _, req in ipairs(n.requires or {}) do if not known[req] then return false end end
  if n.any then
    local ok = false
    for _, req in ipairs(n.any) do if known[req] then ok = true end end
    if not ok then return false end
  end
  local need = n.needs or {}
  if need.crops and not cond.crops then return false end
  if need.herd and not cond.herd then return false end
  if need.draught and not cond.draught then return false end
  if need.coast and not cond.coast then return false end
  if need.stability and (cond.stability or 0.5) < need.stability then return false end
  if need.resource and not has(cond, need.resource) then return false end
  if need.fuel and not (has(cond, "coal") or has(cond, "oil") or has(cond, "peat")) then return false end
  if need.air and (cond.air or 0) < need.air then return false end
  return true
end

-- What a culture can reach. cond = {resources = set, trade = set or nil,
-- crops, herd, draught, coast, air, stability, eras, magic (0..1), source,
-- psionics (0..1), mineral}. Returns {known = list, has = set, level,
-- replaced = {tech = tradition}, traditions = list}.
function T.reachable(cond)
  local top = math.min(10, math.floor((cond.eras or 3) * 1.4))
  local known, list, replaced = {}, {}, {}
  local strong, common = (cond.magic or 0) >= 0.7, (cond.magic or 0) >= 0.45
  for tier = 0, top do
    for _, n in ipairs(T.NODES) do
      if n.tier == tier and not known[n.id] and met(n, cond, known) then
        known[n.id] = true
        if n.magic and strong then
          replaced[n.id] = n.magic
          list[#list + 1] = n.magic
        elseif n.psionic and (cond.psionics or 0) >= 0.7 then
          replaced[n.id] = n.psionic
          list[#list + 1] = n.psionic
        else
          list[#list + 1] = n.id
          if n.magic and common then list[#list + 1] = n.magic end
        end
      end
    end
  end
  -- the age: the furthest step along the main line of tools and power
  local level = 0
  for id in pairs(known) do if T.MAIN[id] then level = math.max(level, T.NODE[id].tier) end end
  local traditions = {}
  if common and cond.source and T.TRADITIONS[cond.source] then
    traditions[#traditions + 1] = T.TRADITIONS[cond.source]
    if cond.mineral and known["iron working"] then
      traditions[#traditions + 1] = "smiths who forge " .. cond.mineral .. " into enchanted tools"
    end
  end
  if (cond.psionics or 0) >= 0.5 then traditions[#traditions + 1] = "mind-walkers who speak without words" end
  local set = {}
  for _, id in ipairs(list) do set[id] = true end
  return { known = list, has = set, level = level, replaced = replaced, traditions = traditions }
end

T.AGES = { [0] = "the stone age", "the age of clay", "the age of copper", "the age of bronze", "the age of iron",
           "the age of steel", "the age of steam", "the electric age", "the age of radio", "the age of computing",
           "the space age" }

return T
