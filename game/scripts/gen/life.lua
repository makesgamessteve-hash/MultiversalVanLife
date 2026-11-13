-- Multiversal Van Life - life: trees of life, species, ecosystems and
-- intelligent species (MIT). See gen/life/*.lua and docs/WORLDGEN.md.
local tree = require("gen.life.tree")
local species = require("gen.life.species")
local sapients = require("gen.life.sapients")

local life = { tree = tree, species = species, sapients = sapients, habitats = require("gen.life.habitats") }

-- Biomes where plants grow: on a world without plant life they are bare.
life.VEGETATED = {
  taiga = true, ["temperate forest"] = true, grassland = true, savanna = true, ["seasonal forest"] = true,
  rainforest = true, wetland = true, tundra = true, ["crystal forest"] = true, ["arcane meadow"] = true,
}

function life.has_plants(d)
  return d.life ~= nil and (d.life.complexity == "plants" or d.life.complexity == "animals")
end

-- A paragraph for the world bible: chemistry, lineages, species and a
-- bestiary of the commonest ones, intelligent species and colonists.
function life.describe(d)
  local L = d.life
  if not L then return nil end
  if L.chemistry == "none" then return "Life: none." end
  local out = {}
  out[1] = string.format("Life: %s (%s), %s.", L.chemistry, L.note, L.complexity == "microbial" and
                         "still only microbes" or (L.complexity == "plants" and "plants but no animals" or "plants and animals"))
  if L.lineages then
    local ls = {}
    for i, l in ipairs(L.lineages) do
      ls[i] = l.kind == "plant" and string.format("%s (%s leaves)", l.name, l.leaf) or
              string.format("%s (%d limbs, %s, %s)", l.name, l.limbs, l.covering, table.concat(l.moves, "/"))
    end
    out[#out + 1] = "Lineages: " .. table.concat(ls, "; ") .. "."
  end
  if L.species then
    local nb = 0
    for _ in pairs(L.by_biome) do nb = nb + 1 end
    out[#out + 1] = string.format("%d species in %d biomes.", #L.species, nb)
    out[#out + 1] = ""
    out[#out + 1] = "Bestiary (a selection):"
    local shown = 0
    for _, role in ipairs({ "predator", "grazer", "pollinator", "scavenger", "decomposer", "producer" }) do
      for _, sp in ipairs(L.species) do
        if sp.role == role and shown < 12 then
          shown = shown + 1
          out[#out + 1] = "- " .. sp.description .. " *(" .. sp.latin .. ")*"
          break
        end
      end
    end
  end
  for _, s in ipairs(L.sapients or {}) do
    local a = s.anatomy
    out[#out + 1] = string.format("- **The %s** (%s, intelligent): %.1f m tall, %d limbs (%s)%s, %s; senses: %s; " ..
                                  "live %d years; %s, %s, %s.", s.name, s.origin, a.height, a.limbs, a.manipulators,
                                  a.wings and ", winged" or "", a.covering, table.concat(s.senses, ", "), s.lifespan,
                                  s.reproduction, s.diet, s.social)
  end
  for _, s in ipairs(L.colonists or {}) do
    out[#out + 1] = string.format("- **The %s** live here as colonists from %s.", s.name, s.from or "elsewhere")
  end
  return table.concat(out, "\n")
end

function life.register(R)
  R:pass("planet", "biochemistry", { after = { "physics" }, run = function(ctx)
    if ctx.summary.prime then return end
    tree.biochemistry(ctx, #ctx:commitments("homeworld") > 0)
  end })
  R:pass("planet", "lineages", { after = { "biochemistry" }, run = function(ctx)
    if ctx.summary.prime then return end
    tree.lineages(ctx)
    for _, c in ipairs(ctx:commitments("homeworld")) do
      tree.kin_lineage(ctx.data, ctx:ref(c.data.data.species).data)
    end
  end })
  R:pass("planet", "species", { after = { "lineages", "biomes", "magic" }, run = function(ctx)
    if ctx.summary.prime then return end
    species.radiate(ctx)
  end })
  R:pass("planet", "sapients", { after = { "species" }, run = function(ctx)
    if ctx.summary.prime then return end
    sapients.sapients(ctx)
  end })
  R:pass("cluster", "spacefarers", { after = { "lanes" }, run = sapients.spacefarers })
  R:pass("system", "settlers", { after = { "planets" }, run = sapients.settlers })

  -- every predator has prey in its biome; every species has a lineage
  R:check("food_chain", function(node, report)
    local L = node.kind == "planet" and node.data.life
    if not L or not L.species then return end
    for _, sp in ipairs(L.species) do
      if sp.role == "predator" then
        local ok = false
        for _, id in ipairs(sp.prey or {}) do
          local p = species.get(L, id)
          if p and p.biome == sp.biome and p.kind == "animal" then ok = true end
        end
        if not ok then report(node.address .. ": " .. sp.name .. " has nothing to hunt") end
      end
    end
  end)
  R:check("lineage", function(node, report)
    local L = node.kind == "planet" and node.data.life
    if not L or not L.species then return end
    local known = {}
    for _, l in ipairs(L.lineages) do known[l.id] = l end
    for _, sp in ipairs(L.species) do
      local l = known[sp.lineage]
      if not l then report(node.address .. ": " .. sp.name .. " descends from nothing")
      elseif sp.kind == "animal" and (sp.limbs ~= l.limbs or sp.covering ~= l.covering) then
        report(node.address .. ": " .. sp.name .. " lost its lineage's body plan")
      end
    end
    for _, s in ipairs(L.sapients or {}) do
      local l = known[s.lineage]
      if not s.anatomy or not l or l.limbs ~= s.anatomy.limbs then
        report(node.address .. ": the " .. tostring(s.name) .. " do not match their ancestors")
      end
    end
  end)
end

return life
