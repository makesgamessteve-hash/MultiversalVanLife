-- Multiversal Van Life - quests from tensions and templates (MIT).
--
-- A land's trouble is its strongest tension (gen/history/tensions.lua); the
-- tension calls for a kind of quest and the land's seed picks a template of
-- that kind, so a signal can tell what is wrong before the land is
-- generated. Generation fills the template with the land's real people
-- (the giver, the parties of a dispute, someone to escort or to carry word
-- to) and its lore: a line naming the place, the people, the saints,
-- holidays and events behind the tension. It stores the quest as data in
-- the land (counts, positions, names, text, possible outcomes); items and
-- targets are land features streamed with their chunks. At runtime
-- lib/landquest.lua adds the interactions.
--
-- Templates live in the content table "quest_templates":
--   { id, w = weight, kind = "relight" | "gather" | "return" | "lost" |
--     "message" | "mediate" | "escort" | "restore",
--     intro = { lines }, progress = line, done = line, ... words }
-- Text may use {giver} {place} {folk} {light} {glow} {part} {keepsake}
-- {spot} {machine} {lost} {n} {left} and, by kind, {recipient} {message}
-- {answer} {party_a} {party_b} {issue} {winner} {escort} {destination}
-- {source}. Mods add templates of these kinds.
local dm = require("gen.dmath")
local names = require("gen.names")

local Q = {}

Q.KINDS = { "relight", "gather", "return", "lost", "message", "mediate", "escort", "restore" }

Q.BASE = {
  { id = "relight", w = 1, kind = "relight", short = "the lights went out",
    intro = { "The {light}s of {place} went dark tonight, every single one.",
              "Without them the {folk} can't find their way home across the dark.",
              "Gather the {glow} drifting nearby and bring them to the {light}s, one each." },
    progress = "{left} {light}s are still dark.", done = "Every {light} is burning again! {place} won't forget you.",
    deed = "lit our {light}s again" },
  { id = "gather", w = 1, kind = "gather", short = "a machine is broken",
    intro = { "Our {machine} broke down and its {part}s rolled away in every direction.",
              "Could you find all {n} of them? Look between the houses and out past the square." },
    progress = "Still {left} {part}s missing, I'm afraid.", done = "That's every {part}! Listen to the {machine} hum. Thank you, stranger.",
    deed = "found every {part} of our {machine}" },
  { id = "return", w = 1, kind = "return", short = "treasures were scattered",
    intro = { "The wind last night scattered our {keepsake}s all over the hills.",
              "Each belongs in a {spot} here by the square. Any {spot} will do, they know their way." },
    progress = "{left} {keepsake}s are still out there.", done = "Everything is back where it belongs. The square feels whole again.",
    deed = "brought our {keepsake}s home" },
  { id = "lost", w = 1, kind = "lost", short = "someone is lost",
    intro = { "Have you seen {lost}? They wandered off at dusk and never came back.",
              "Please, find {lost} out there and bring them home." },
    progress = "No sign of {lost} yet...", done = "{lost}! You're safe! Thank you, thank you, traveller.",
    lost_line = "I got turned around in the dark... You'll take me back? Lead the way!", deed = "brought {lost} home" },
  { id = "message", w = 1, kind = "message", short = "word must be carried",
    intro = { "Someone has to carry word to {recipient}, out past the last houses.",
              "Tell them this: {message}. And bring me back their answer." },
    progress = "Have you found {recipient}? They're out past the edge of {place}.",
    waiting = "Go on, {giver} is waiting for my answer.",
    reply = { "{giver} sent you? Then listen. {message}... I see.", "Tell {giver}: {answer}." },
    done = "{answer}? Then all will be well. Thank you for carrying our words.", deed = "carried our word to {recipient}" },
  { id = "mediate", w = 1, kind = "mediate", short = "a quarrel must be settled",
    intro = { "{party_a} and {party_b} are at each other's throats over {issue}.",
              "Hear them both out, then tell them how it's to be. They'll listen to a stranger." },
    progress = "Have you heard both sides yet? {party_a} and {party_b} are both here.",
    claim_a = { "{issue}? It is ours, by right, and always has been.", "Tell {party_b} to keep their hands off it." },
    claim_b = { "Without {issue} we have nothing. Nothing!", "{party_a} would see us ruined and call it justice." },
    heard = "You've heard them both. How do you settle it?",
    done_side = "So {winner} keeps {issue}. I hope you know what you've done.",
    done_compromise = "Shared, then. Nobody is happy, which probably means it's fair.",
    deed = "settled the quarrel over {issue}", deed_side = "gave {issue} to us", wrong_side = "gave {issue} to {winner}" },
  { id = "escort", w = 1, kind = "escort", short = "someone needs a guide",
    intro = { "{escort} has to reach {destination} tonight, and the way isn't safe.",
              "Would you walk with them? They're waiting by the square." },
    escort_line = "You'll take me to {destination}? Thank you. I'll stay close.",
    wait_line = "Talk to {giver} first, they'll tell you where I need to go.",
    arrive = "We made it to {destination}! Tell {giver} I'm safe.",
    progress = "Is {escort} safe yet? {destination} is out past the fields.",
    done = "{escort} reached {destination}? Thank you, from all of us.", deed = "brought {escort} safely to {destination}" },
  { id = "restore", w = 1, kind = "restore", short = "a source is failing",
    intro = { "The {source} of {place} is failing. Without it we won't last the season.",
              "The {part}s that fed it are scattered around, {n} of them. Bring them to the {source}." },
    progress = "{left} {part}s still to find.", ready = "That's all of them. Bring them to the {source}.",
    done = "Listen... the {source} is alive again! Thank you, thank you.", deed = "brought our {source} back to life" },
}

-- What the giver asks the recipient to hear, by tension, and what they answer.
local MESSAGES = {
  ["succession crisis"] = { "the council meets at {holiday}, and every heir must come", "we will come, and we will listen" },
  feud = { "we would rather talk than fight again", "then let us talk, before the next blood is spilt" },
  ["urgent news"] = { "a storm is coming, bring the herds down from the hills", "we are coming down tonight" },
  default = { "{place} needs every hand it has", "we are coming as soon as we can" },
}

-- Lore lines: what the giver says about the trouble, naming the place and
-- the people, saints, holidays and events behind it.
local LORE = {
  drought = { "Ever since {cause}, the wells of {place} hold less every day.",
              "We pray to {deity} for rain, but {cause}." },
  ["contested border"] = { "{rival} claims the fields of {place}, and our elders swear by {saint} they are ours." },
  feud = { "Nobody in {place} has forgotten {event}. Old wounds open easily here." },
  ["succession crisis"] = { "{person} is old, and before {holiday} comes the heirs will be at each other's throats." },
  schism = { "Since {event}, half of {place} prays one way to {deity} and half another." },
  epidemic = { "{event} has come back to {place}. We burned herbs for {deity}, and still people fall sick." },
  incursion = { "{beast}s come down to {place} at night now. Not even {holiday} kept them away." },
  ["failing magic"] = { "The {magic} magic of {place} is fading, and {saint} left no word of what to do." },
  ["lost relic"] = { "It was lost in {ruins}, long ago, and {place} has never been the same." },
  default = { "Here in {place}, {cause}. {saint} would know what to do.", "It happened just before {holiday}: {cause}.",
              "{cause}, and we have prayed to {deity} every night since.", "Here in {place}, {cause}." },
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
  return (text:gsub("{([%w_]+)}", function(k) return words[k] ~= nil and tostring(words[k]) or "{" .. k .. "}" end))
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
      if f.box and f.box[1] > 2 then
        -- buildings: not inside or right against their walls
        local c, s = dm.cos(f.yaw or 0), dm.sin(f.yaw or 0)
        local lx, lz = c * dx - s * dz, s * dx + c * dz
        if math.abs(lx) <= f.box[1] / 2 + 2 and math.abs(lz) <= f.box[2] / 2 + 2 then ok = false break end
      elseif dx * dx + dz * dz < 16 then ok = false break end
    end
    if ok then return x, z end
  end
  return dm.round(cx + rmin, 2), cz
end

-- Do all {words} of `text` have values?
local function fillable(text, words)
  for k in text:gmatch("{([%w_]+)}") do if words[k] == nil then return false end end
  return true
end

-- A person of the land made for a quest (named in the culture's language).
local function person(ctx, d, cul, id, x, z, texture)
  local seed = mvl.hash(ctx.node.seed, id)
  local p = { id = id, x = x, z = z, texture = texture or (d.people[1] and d.people[1].texture) or "npc_farmer" }
  local spare = d.lore and d.lore.names
  if cul then
    local n = require("gen.culture").person_name(cul, seed)
    p.name, p.name_meaning, p.species = n.name, n.meaning, cul.species
  elseif spare and #spare > 0 then
    -- runtime quests (chapters): the names the land keeps for newcomers
    local n = spare[seed % #spare + 1]
    p.name, p.name_meaning = n.name, n.meaning
  else
    p.name = names.make(mvl.rng(seed), "world")
  end
  local b = d.people[1] and d.people[1].body
  if b then
    p.body = { anatomy = b.anatomy, hue = b.hue, dress = b.dress, accent = b.accent, seed = seed % 3 }
  end
  return p
end

-- A place name in the culture's language (or a generic one).
local function hamlet(ctx, cul, key)
  local rng = mvl.rng(mvl.hash(ctx.node.seed, "hamlet", key))
  if cul then return require("gen.culture.language").name(cul.language, rng, "place").name end
  return names.make(rng, "world")
end

-- Generates the land's quest into d.quest and its features into d.features.
-- `cul` is the culture of the land's people (or nil); `opts.prefix` prefixes
-- the ids of the quest's features and people (later chapters of a land).
function Q.generate(ctx, d, style, cul, opts)
  local P = opts and opts.prefix or ""
  local R = ctx.G.registry
  -- the land's strongest tension decides its trouble
  local tension = d.tensions and d.tensions[1] or {}
  local t = Q.choose(R, ctx.node.seed, tension.quest)
  local rng = ctx:random("quest")
  local giver = d.people[1]
  local lore = d.lore or {}
  local q = { template = t.id, kind = t.kind, giver = giver.id,
              severity = tension.severity or Q.severity(ctx.node.seed), items = {}, targets = {},
              tension = tension.text, tension_kind = tension.kind, stakeholders = tension.stakeholders,
              outcomes = { "done", "abandoned" } }
  local words = {
    giver = giver.name, place = d.name, folk = style.folk, light = t.light or style.light, glow = t.glow or style.glow,
    part = t.part or style.part, keepsake = t.keepsake or style.keepsake, spot = t.spot or style.place,
    machine = t.machine or MACHINES[rng:int(1, #MACHINES)],
    -- the lore behind the tension
    cause = tension.causes and tension.causes[1], event = tension.event, person = tension.person, beast = tension.beast,
    magic = tension.magic, ruins = tension.ruins, rival = tension.parties and tension.parties[2],
    deity = lore.deities and lore.deities[1], saint = lore.saint, holiday = lore.holidays and lore.holidays[1],
  }
  local gx, gz = giver.x, giver.z
  local sq = d.spots and d.spots.square or { x = gx, z = gz }
  local function items(n, sprite, glow)
    q.count = n
    for i = 1, n do
      local x, z = place(rng, d, gx, gz, 12, 55)
      local id = P .. "q_item" .. i
      local item = { id = id, role = "quest_item", x = x, z = z }
      if glow then
        item.sprite, item.w, item.h, item.y, item.unlit, item.nofog = sprite, 0.35, 0.35, 1.2, true, true
      else
        item.sprite, item.w, item.h, item.y = sprite, 0.45, 0.45, 0.1
      end
      d.features[#d.features + 1] = item
      q.items[i] = id
    end
  end
  if t.kind == "relight" or t.kind == "gather" or t.kind == "return" then
    local n = rng:int(3, t.kind == "return" and 4 or 5)
    if t.kind == "relight" then items(n, t.item or "firefly", true)
    else items(n, t.item or (t.kind == "gather" and "gear" or "book")) end
    if t.kind ~= "gather" then
      for i = 1, n do
        local x, z
        if t.kind == "relight" then x, z = place(rng, d, gx, gz, 15, 50)
        else x, z = place(rng, d, sq.x, sq.z, 5, 10) end
        local id = P .. "q_target" .. i
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
    if cul then q.lost.name = require("gen.culture").person_name(cul, mvl.hash(ctx.node.seed, "lost")).name end
    words.lost = q.lost.name
    q.count = 1
  elseif t.kind == "message" then
    local x, z = place(rng, d, gx, gz, 40, 55)
    q.recipient = person(ctx, d, cul, P .. "recipient", x, z)
    q.recipient.yaw = dm.round(dm.atan(-(gx - x), -(gz - z)), 4)
    words.recipient = q.recipient.name
    local m = MESSAGES[tension.kind] or MESSAGES.default
    if not fillable(m[1], words) then m = MESSAGES.default end
    words.message, words.answer = Q.fill(m[1], words), Q.fill(m[2], words)
    q.count = 1
  elseif t.kind == "mediate" then
    -- two villagers speak for the two sides
    while #d.people < 3 do
      local i = #d.people + 1
      local x, z = place(rng, d, sq.x, sq.z, 3, 7)
      local p = person(ctx, d, cul, P .. "person" .. i, x, z)
      p.yaw = dm.round(dm.atan(-(sq.x - x), -(sq.z - z)), 4)
      d.people[i] = p
    end
    local labels = tension.parties
    if not labels or #labels < 2 then
      labels = { "the family of " .. d.people[2].name, "the family of " .. d.people[3].name }
    elseif tension.local_trouble then
      labels = { labels[1] .. " of " .. hamlet(ctx, cul, 1), labels[2] .. " of " .. hamlet(ctx, cul, 2) }
    end
    q.issue = tension.issue or "the old quarrel"
    q.parties = { { label = labels[1], person = d.people[2].id }, { label = labels[2], person = d.people[3].id } }
    words.party_a, words.party_b, words.issue = labels[1], labels[2], q.issue
    q.outcomes = { "a", "b", "compromise", "abandoned" }
    q.count = 2
  elseif t.kind == "escort" then
    local x, z = place(rng, d, sq.x, sq.z, 3, 6)
    q.escort = person(ctx, d, cul, P .. "escort", x, z, "npc_child")
    words.escort = q.escort.name
    local dx, dz = place(rng, d, gx, gz, 40, 55)
    q.destination = { id = P .. "q_dest", x = dx, z = dz,
                      name = (tension.kind == "sick child" or tension.kind == "epidemic") and "the healer's house" or
                             (words.saint and ("the shrine of " .. words.saint) or "the far farms") }
    d.features[#d.features + 1] = { id = P .. "q_dest", role = "quest_target", voxel = "lantern_post", x = dx, z = dz,
                                     radius = 0.3 }
    d.features[#d.features + 1] = { id = P .. "q_dest_lamp", role = "quest_lamp", sprite = "lantern_on", unlit = true,
                                     x = dx + 0.3, z = dz, y = 1.6, w = 0.4, h = 0.8 }
    words.destination = q.destination.name
    q.count = 1
  elseif t.kind == "restore" then
    local water = tension.source ~= "magic"
    words.source = t.source or (water and "spring" or "old stone")
    words.part = t.part or (water and "spring-stone" or "glow-shard")
    items(rng:int(3, 4), t.item or (water and "crystal" or "firefly"), not water)
    local x, z = place(rng, d, sq.x, sq.z, 8, 12)
    q.source = { id = P .. "q_source", x = x, z = z, water = water }
    d.features[#d.features + 1] = { id = P .. "q_source", role = "quest_source", voxel = water and "well" or "lantern_post",
                                     x = x, z = z, radius = water and 0.9 or 0.3 }
  end
  words.n = q.count
  -- the giver's word on the lore behind the trouble
  -- (lines naming more than the place and the cause come first)
  local function rich(l)
    for k in l:gmatch("{([%w_]+)}") do if k ~= "place" and k ~= "cause" then return true end end
    return false
  end
  local lines = {}
  for _, list in ipairs({ LORE[tension.kind] or {}, LORE.default }) do
    for _, l in ipairs(list) do if fillable(l, words) and rich(l) then lines[#lines + 1] = l end end
    if #lines > 0 then break end
  end
  if #lines == 0 then
    for _, l in ipairs(LORE.default) do if fillable(l, words) then lines[#lines + 1] = l end end
  end
  if #lines > 0 then
    local line = lines[rng:int(1, #lines)]
    q.lore_line = (Q.fill(line, words):gsub("^%l", string.upper))
    q.lore = {}
    for k in line:gmatch("{([%w_]+)}") do
      if k ~= "cause" then q.lore[#q.lore + 1] = tostring(words[k]) end
    end
  end
  q.words = words
  q.short = t.short or t.id
  d.quest = q
  return q
end

-- ---------------------------------------------------------- runtime
-- The giver's introduction: the template's first line, the lore of the
-- trouble, then the rest.
function Q.intro(R, q)
  local lines = Q.text(R, q, "intro") or {}
  if type(lines) ~= "table" then lines = { lines } end
  if q.lore_line then table.insert(lines, math.min(2, #lines + 1), q.lore_line) end
  return lines
end

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
