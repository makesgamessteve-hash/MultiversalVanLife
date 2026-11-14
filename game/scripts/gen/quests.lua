-- Multiversal Van Life - quests from templates (MIT).
--
-- A land's trouble is a quest template picked from its seed alone, so a
-- signal can tell what is wrong before the land is generated. Generation
-- stores the quest as data in the land (counts, positions, names, text);
-- items and targets are land features streamed with their chunks, so they
-- exist wherever the player goes and are never duplicated. At runtime
-- `quests.start(w, ...)` adds the interactions.
--
-- Templates live in the content table "quest_templates":
--   { id, w = weight, kind = "relight" | "gather" | "return" | "lost",
--     intro = { lines }, progress = line, done = line, ... words }
-- Text may use {giver} {place} {folk} {light} {glow} {part} {keepsake}
-- {spot} {machine} {lost} {n} {left}. Mods add templates of these kinds.
local dm = require("gen.dmath")
local names = require("gen.names")

local Q = {}

Q.BASE = {
  { id = "relight", w = 1, kind = "relight", short = "the lights went out",
    intro = { "The {light}s of {place} went dark tonight, every single one.",
              "Without them the {folk} can't find their way home across the dark.",
              "Gather the {glow} drifting nearby and bring them to the {light}s, one each." },
    progress = "{left} {light}s are still dark.", done = "Every {light} is burning again! {place} won't forget you." },
  { id = "gather", w = 1, kind = "gather", short = "a machine is broken",
    intro = { "Our {machine} broke down and its {part}s rolled away in every direction.",
              "Could you find all {n} of them? Look between the houses and out past the square." },
    progress = "Still {left} {part}s missing, I'm afraid.", done = "That's every {part}! Listen to the {machine} hum. Thank you, stranger." },
  { id = "return", w = 1, kind = "return", short = "treasures were scattered",
    intro = { "The wind last night scattered our {keepsake}s all over the hills.",
              "Each belongs in a {spot} here by the square. Any {spot} will do, they know their way." },
    progress = "{left} {keepsake}s are still out there.", done = "Everything is back where it belongs. The square feels whole again." },
  { id = "lost", w = 1, kind = "lost", short = "someone is lost",
    intro = { "Have you seen {lost}? They wandered off at dusk and never came back.",
              "Please, find {lost} out there and bring them home." },
    progress = "No sign of {lost} yet...", done = "{lost}! You're safe! Thank you, thank you, traveller.",
    lost_line = "I got turned around in the dark... You'll take me back? Lead the way!" },
}

local MACHINES = { "mill", "water pump", "loom", "bell tower", "clock", "lift" }

function Q.register(R) R:content("quest_templates", Q.BASE) end

-- Templates sorted by id (registration order never matters).
function Q.templates(R)
  local list = {}
  for _, t in ipairs(R:table("quest_templates")) do list[#list + 1] = t end
  table.sort(list, function(a, b) return a.id < b.id end)
  return list
end

-- The trouble of a land: a template picked from the land's seed.
function Q.pick(R, land_seed)
  local list = Q.templates(R)
  local total = 0
  for _, t in ipairs(list) do total = total + (t.w or 1) end
  local x = mvl.rng(mvl.hash(land_seed, "trouble")):next() * total
  for _, t in ipairs(list) do
    x = x - (t.w or 1)
    if x < 0 then return t end
  end
  return list[#list]
end

-- The trouble of a land with a tension calling for a kind of quest: a
-- template of that kind (mods' templates included), picked from the seed;
-- without a kind (lands nobody lives in), any template.
function Q.choose(R, land_seed, kind)
  if not kind then return Q.pick(R, land_seed) end
  local list, total = {}, 0
  for _, t in ipairs(Q.templates(R)) do
    if t.kind == kind then list[#list + 1] = t; total = total + (t.w or 1) end
  end
  if #list == 0 then return Q.pick(R, land_seed) end
  local x = mvl.rng(mvl.hash(land_seed, "trouble")):next() * total
  for _, t in ipairs(list) do
    x = x - (t.w or 1)
    if x < 0 then return t end
  end
  return list[#list]
end

function Q.severity(land_seed) return dm.round(0.2 + 0.8 * mvl.rng(mvl.hash(land_seed, "severity")):next(), 3) end

function Q.template(R, id)
  for _, t in ipairs(R:table("quest_templates")) do if t.id == id then return t end end
end

-- Fills {words} from a table.
function Q.fill(text, words)
  return (text:gsub("{(%w+)}", function(k) return words[k] ~= nil and tostring(words[k]) or "{" .. k .. "}" end))
end

-- --------------------------------------------------------- generation
-- A point on open ground within [rmin, rmax] metres of (cx, cz).
local function place(rng, d, cx, cz, rmin, rmax)
  for _ = 1, 30 do
    local a, r = rng:next() * 2 * dm.pi, rmin + rng:next() * (rmax - rmin)
    local x, z = dm.round(cx + dm.cos(a) * r, 2), dm.round(cz + dm.sin(a) * r, 2)
    local ok = true
    for _, f in ipairs(d.features) do
      local dx, dz = f.x - x, f.z - z
      if dx * dx + dz * dz < 16 then ok = false break end
    end
    if ok then return x, z end
  end
  return dm.round(cx + rmin, 2), cz
end

-- Generates the land's quest into d.quest and its features into d.features.
function Q.generate(ctx, d, style)
  local R = ctx.G.registry
  -- the land's strongest tension decides its trouble (history, phase 20)
  local tension = d.tensions and d.tensions[1]
  local t = Q.choose(R, ctx.node.seed, tension and tension.quest)
  local rng = ctx:random("quest")
  local giver = d.people[1]
  local q = { template = t.id, kind = t.kind, giver = giver.id,
              severity = tension and tension.severity or Q.severity(ctx.node.seed), items = {}, targets = {},
              tension = tension and tension.text }
  local words = {
    giver = giver.name, place = d.name, folk = style.folk, light = t.light or style.light, glow = t.glow or style.glow,
    part = t.part or style.part, keepsake = t.keepsake or style.keepsake, spot = t.spot or style.place,
    machine = t.machine or MACHINES[rng:int(1, #MACHINES)],
  }
  local gx, gz = giver.x, giver.z
  if t.kind == "relight" or t.kind == "gather" or t.kind == "return" then
    local n = rng:int(3, t.kind == "return" and 4 or 5)
    q.count = n
    for i = 1, n do
      local x, z = place(rng, d, gx, gz, 12, 55)
      local id = "q_item" .. i
      local item = { id = id, role = "quest_item", x = x, z = z }
      if t.kind == "relight" then
        item.sprite, item.w, item.h, item.y, item.unlit, item.nofog = t.item or "firefly", 0.35, 0.35, 1.2, true, true
      else
        item.sprite, item.w, item.h, item.y = t.item or (t.kind == "gather" and "gear" or "book"), 0.45, 0.45, 0.1
      end
      d.features[#d.features + 1] = item
      q.items[i] = id
    end
    if t.kind ~= "gather" then
      for i = 1, n do
        local x, z
        if t.kind == "relight" then x, z = place(rng, d, gx, gz, 15, 50)
        else x, z = place(rng, d, d.spots.square.x, d.spots.square.z, 5, 10) end
        local id = "q_target" .. i
        d.features[#d.features + 1] = { id = id, role = "quest_target",
                                         voxel = t.kind == "relight" and "lantern_post" or (t.target_voxel or "well"),
                                         x = x, z = z, radius = 0.4 }
        if t.kind == "relight" then
          d.features[#d.features + 1] = { id = id .. "_lamp", role = "quest_lamp", sprite = "lantern_off", x = x + 0.3,
                                          z = z, y = 1.6, w = 0.4, h = 0.8 }
        end
        q.targets[i] = id
      end
    end
  elseif t.kind == "lost" then
    local x, z = place(rng, d, gx, gz, 40, 58)
    q.lost = { name = names.make(ctx:random("lost"), "world"), texture = "npc_child", x = x, z = z }
    words.lost = q.lost.name
    q.count = 1
  end
  words.n = q.count
  q.words = words
  q.short = t.short or t.id
  d.quest = q
  return q
end

-- ---------------------------------------------------------- runtime
-- Lines of a template, filled with the quest's words.
function Q.text(R, q, key, extra)
  local t = Q.template(R, q.template) or {}
  local words = {}
  for k, v in pairs(q.words) do words[k] = v end
  for k, v in pairs(extra or {}) do words[k] = v end
  local src = t[key]
  if type(src) == "table" then
    local out = {}
    for i, s in ipairs(src) do out[i] = Q.fill(s, words) end
    return out
  end
  return src and Q.fill(src, words) or nil
end

return Q
