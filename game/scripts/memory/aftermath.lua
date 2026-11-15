-- Multiversal Van Life - time passes in visited places (MIT).
--
-- Every visited land keeps a clock (the night of each visit; a night of the
-- player's is about a week there). When a quest ends, how it ended starts
-- the land's aftermath: rules that come true some nights later (new fields
-- and families after help, a festival in the player's honour, a monument of
-- the player and the van, a shrine of the Wanderer, the place renamed; a
-- house in ruins and families leaving after the player gave up; a new
-- trouble caused by the help itself). When the player comes back, every rule
-- whose time has come is applied once and written into the land's change
-- log: marks (objects built in the local style), new fields and villagers,
-- the news people talk about, events of the land's history and follow-ups
-- (needs and invitations, which bring signals back to the land). Mods add
-- rules with the content table "aftermath_rules".
local A = { DAYS_PER_NIGHT = 7 }

-- The human body of the player's statue.
A.PLAYER = { limbs = 4, hands = 2, eyes = 2, mouth = "lips", build = 1 }

-- The troubles a deed itself causes later (by quest kind): text, the kind of
-- quest it calls for, and why.
A.TROUBLES = {
  restore = { kind = "crowded spring", text = "the new families crowd the spring", quest = "gather",
              cause = "since the {source} came back, more people live here than it can serve" },
  relight = { kind = "short of oil", text = "the lamps burn more oil than we have", quest = "gather",
              cause = "since the lamps were lit again, nobody wants them dark" },
  gather = { kind = "no keeper", text = "the machine needs a keeper", quest = "message",
             cause = "the {machine} runs again, but nobody here knows how to tend it" },
  ["return"] = { kind = "jealous neighbours", text = "the neighbours want our keepsakes", quest = "relight",
                 cause = "everyone heard our keepsakes came home" },
  lost = { kind = "wandering children", text = "the children keep wandering off", quest = "lost",
           cause = "every child wants to see where {lost} got lost" },
  message = { kind = "guests are coming", text = "guests are coming and the lamps are out", quest = "relight",
              cause = "the answer you brought was an invitation" },
  mediate = { kind = "redress", text = "the other side wants redress", quest = "message",
              cause = "not everyone was happy with how the quarrel ended" },
  escort = { kind = "herbs for the healer", text = "the healer needs herbs from the hills", quest = "gather",
             cause = "the healer has more to do since you brought help" },
}

local function title_noun(title) return (title or "the Helper"):gsub("^the ", "") end

-- ------------------------------------------------------------------ rules
A.RULES = {
  { id = "regrowth", after = 2, when = function(x) return x.success end,
    apply = function(x)
      local watery = x.outcome.kind == "restore" or x.outcome.kind == "gather" or
                     (x.outcome.issue and x.outcome.issue:find("water", 1, true))
      if watery then
        x:field()
        x:field()
        x:news("new fields are green around " .. x.place .. " since you " .. x.deed)
      else
        x:news("life is better in " .. x.place .. " since you " .. x.deed)
      end
      x:event("the good years after " .. x.title .. " " .. x.deed)
    end },
  { id = "newcomers", after = 4, when = function(x) return x.success end,
    apply = function(x)
      x:person("newcomer1")
      x:person("newcomer2")
      x:news("two families moved to " .. x.place .. " after they heard how you " .. x.deed)
    end },
  { id = "festival", after = 3, when = function(x) return x.success and x.severity >= 0.45 and x.lore.culture ~= nil end,
    apply = function(x)
      local name = "the Feast of the " .. title_noun(x.title)
      x:festival(name)
      x:news(x.place .. " keeps " .. name .. " now, in your honour")
      x:event("the first " .. name)
    end,
    -- an invitation to the festival
    followup = function(x)
      return { kind = "invitation", text = "they hold the Feast of the " .. title_noun(x.title) .. " in your honour",
               short = "an invitation to a feast" }
    end },
  { id = "monument", after = 6, when = function(x) return x.success and x.severity >= 0.5 end,
    apply = function(x)
      local sx, sz = x:spot(9, 13)
      x:mark({ mark = "monument", x = sx, z = sz, yaw = 0, box = { 1.8, 1.4 },
               statue = { anatomy = A.PLAYER, hue = 30, attributes = { "staff" }, name = "the statue of " .. x.title,
                          role = "wanderer" } })
      x:mark({ mark = "monument_van", x = sx + 2.2, z = sz, yaw = 1.2, voxel = "van", scale = 0.3,
               color = { 0.62, 0.6, 0.56, 1 }, box = { 1.6, 1.2 } })
      x:news("the stone-cutters made a statue of you and your wagon, by the square")
      x:event("the raising of the statue of " .. x.title)
    end },
  { id = "shrine", after = 5, when = function(x) return x.success and x.wanderer end,
    apply = function(x)
      local sx, sz = x:spot(14, 18)
      x:mark({ mark = "shrine", x = sx, z = sz, yaw = 0, trace = { kind = "shrine", name = "a shrine to the Wanderer",
                                                                 seed = 7 } })
      x:news("we raised a shrine to the Wanderer, who came back as the old stories said")
    end },
  { id = "renamed", after = 8, when = function(x) return x.success and x.severity >= 0.7 end,
    apply = function(x)
      local name = x.place .. " of the " .. title_noun(x.title)
      x:rename(name)
      x:news("we call our home " .. name .. " now")
    end },
  { id = "decline", after = 3, when = function(x) return x.outcome.result == "abandoned" end,
    apply = function(x)
      x:ruin()
      x:leave()
      x:news("since you left us, " .. (x.outcome.tension or "our trouble") .. " got worse, and a family moved away")
      x:event("the bad years, when nobody came to help")
    end },
  { id = "trouble", after = 5, when = function(x) return x.success and not x.outcome.chapter and A.TROUBLES[x.outcome.kind] end,
    apply = function(x)
      local t = A.TROUBLES[x.outcome.kind]
      x:trouble(t)
      x:news(t.text)
    end,
    -- the land needs the player again
    followup = function(x)
      local t = A.TROUBLES[x.outcome.kind]
      return { kind = "need", text = t.text, short = t.text }
    end },
}

-- The rules with mods' additions.
function A.rules()
  local out = {}
  for _, r in ipairs(A.RULES) do out[#out + 1] = r end
  for _, r in ipairs(require("gen").cosmos:table("aftermath_rules")) do out[#out + 1] = r end
  return out
end

-- ---------------------------------------------------------------- context
local X = {}
X.__index = X

local function context(node, log, outcome, night)
  local d = node.data
  local q = d.quest or {}
  local com = log.community or {}
  local x = setmetatable({
    node = node, log = log, outcome = outcome, night = night, data = d, lore = d.lore or {},
    success = outcome.result ~= "abandoned", severity = outcome.severity or q.severity or 0.5,
    title = com.known_as or "the Helper", deed = com.deed or "helped us", place = d.name, wanderer = d.wanderer ~= nil,
    rng = mvl.rng(mvl.hash(node.seed, "aftermath", outcome.night or 0)),
  }, X)
  log.aftermath = log.aftermath or { applied = {}, news = {}, fields = {}, people = {}, gone = {} }
  x.am = log.aftermath
  return x
end

-- A free spot at `rmin`..`rmax` metres from the square.
function X:spot(rmin, rmax)
  local d = self.data
  local sq = d.spots and d.spots.square or { x = 0, z = 0 }
  local taken = {}
  for _, f in ipairs(d.features) do taken[#taken + 1] = f end
  for _, f in pairs(self.log.placed) do taken[#taken + 1] = f end
  for _ = 1, 40 do
    local a, r = self.rng:next() * 6.2832, rmin + self.rng:next() * (rmax - rmin)
    local x, z = sq.x + math.cos(a) * r, sq.z + math.sin(a) * r
    local ok = true
    for _, f in ipairs(taken) do
      local dx, dz = (f.x or 0) - x, (f.z or 0) - z
      if f.box and f.box[1] > 2 then
        local c, s = math.cos(f.yaw or 0), math.sin(f.yaw or 0)
        local lx, lz = c * dx - s * dz, s * dx + c * dz
        if math.abs(lx) <= f.box[1] / 2 + 3 and math.abs(lz) <= f.box[2] / 2 + 3 then ok = false break end
      elseif dx * dx + dz * dz < 25 then ok = false break end
    end
    if ok then return math.floor(x * 100 + 0.5) / 100, math.floor(z * 100 + 0.5) / 100 end
  end
  return sq.x + rmax, sq.z
end

-- A mark: an object built where it happened (statues, the van in stone,
-- shrines, lanterns; any feature a land may hold).
function X:mark(f)
  f.role = "mark"
  self.log:place(f)
  return f
end

function X:news(text) table.insert(self.am.news, 1, text) end
-- An event of the land's history (the codex tells them).
function X:event(text)
  self.log.events = self.log.events or {}
  self.log.events[#self.log.events + 1] = { night = self.night, text = text }
end

function X:field()
  local fx, fz = self:spot(16, 30)
  local crops = { { "wheat", { 0.95, 0.85, 0.45, 1 } }, { "greens", { 0.55, 0.85, 0.4, 1 } } }
  local c = crops[#self.am.fields % 2 + 1]
  self.am.fields[#self.am.fields + 1] = { x = fx, z = fz, w = 12, d = 9, yaw = math.floor(self.rng:next() * 300) / 100,
                                          crop = c[1], texture = "grass", tint = c[2] }
end

function X:person(id)
  local d = self.data
  local px, pz = self:spot(4, 9)
  local names = self.lore.names or {}
  local n = #self.am.people + 1
  local name = names[n] or require("gen.names").make(mvl.rng(mvl.hash(self.node.seed, id)), "world")
  local p = { id = id, name = type(name) == "table" and name.name or name, x = px, z = pz,
              texture = d.people[1] and d.people[1].texture or "npc_farmer", newcomer = true }
  local b = d.people[1] and d.people[1].body
  if b then p.body = { anatomy = b.anatomy, hue = b.hue, dress = b.dress, accent = b.accent, seed = 3 + n } end
  self.am.people[#self.am.people + 1] = p
end

-- A villager (not the giver, not a legend) leaves.
function X:leave()
  local d = self.data
  for i = #d.people, 2, -1 do
    local p = d.people[i]
    if not p.legend and not self.am.gone[p.id] then self.am.gone[p.id] = true return p end
  end
end

-- A house falls into ruin.
function X:ruin()
  for _, f in ipairs(self.data.features) do
    if f.building == "house" and not (self.log.objects[f.id] or {}).ruined then
      self.log:set(f.id, { ruined = true })
      return f
    end
  end
end

function X:festival(name)
  self.am.festival = name
  -- lanterns around the square for the feast
  local d = self.data
  local sq = d.spots and d.spots.square or { x = 0, z = 0 }
  for i = 1, 6 do
    local a = i / 6 * 6.2832
    self:mark({ mark = "festival", sprite = "lantern_on", unlit = true, x = sq.x + math.cos(a) * 7,
                z = sq.z + math.sin(a) * 7, y = 1.4, w = 0.4, h = 0.8 })
  end
end

function X:rename(name) self.am.name = name end

-- A new trouble caused by the deed: the land's next quest (a chapter).
function X:trouble(t)
  local words = (self.data.quest or {}).words or {}
  local cause = require("gen.quests").fill(t.cause, words)
  self.am.trouble = { kind = t.kind, text = t.text, causes = { cause }, quest = t.quest, severity = 0.5,
                      stakeholders = { self.data.nation or "the villagers" }, caused_by = self.outcome.template }
end

-- ------------------------------------------------------------------ plan
-- When a quest ends: remember when, and queue the follow-ups the rules will
-- bring (needs and invitations) for the nights they come true.
function A.plan(node, log, outcome)
  local x = context(node, log, outcome, outcome.night)
  local spread = require("memory.spread")
  for _, r in ipairs(A.rules()) do
    if r.followup and r.when(x) then
      local f = r.followup(x)
      if f then
        f.address, f.night, f.rule = node.address, outcome.night + r.after, r.id
        f.name = (log.aftermath and log.aftermath.name) or node.data.name
        spread.queue(node, f)
      end
    end
  end
end

-- On arrival: the clock moves on, and every rule whose time has come is
-- applied once. Returns the rules applied now.
function A.update(node, log, night)
  log.clock = log.clock or { visits = 0 }
  local last = log.clock.last
  log.clock.visits, log.clock.last = log.clock.visits + 1, night
  log.clock.days = (log.clock.days or 0) + (last and (night - last) * A.DAYS_PER_NIGHT or 0)
  log.dirty = true
  local outcome = log.outcome
  local applied = {}
  if not outcome then return applied end
  local x = context(node, log, outcome, night)
  for _, r in ipairs(A.rules()) do
    local key = (outcome.chapter and "c" .. outcome.chapter .. ":" or "") .. r.id
    if not x.am.applied[key] and night - outcome.night >= r.after and r.when(x) then
      x.am.applied[key] = night
      r.apply(x)
      applied[#applied + 1] = r.id
    end
  end
  if #applied > 0 then x.am.stamp = (x.am.stamp or 0) + 1 end
  -- a new trouble becomes the land's next quest
  if x.am.trouble and not log.chapter then A.chapter(node, log, x.am.trouble) end
  return applied
end

-- The land's next quest, from a trouble the player's deed caused.
function A.chapter(node, log, tension)
  local gen = require("gen")
  local d = node.data
  local n = 2
  local prefix = "c" .. n .. "_"
  local seed = mvl.hash(node.seed, "chapter", n)
  local ctx = { G = { registry = gen.cosmos }, node = { seed = seed, address = node.address } }
  function ctx:random(name) return mvl.rng(mvl.hash(seed, name)) end
  local people = {}
  for _, p in ipairs(A.people(node, log)) do people[#people + 1] = p end
  local features = {}
  for _, f in ipairs(d.features) do features[#features + 1] = f end
  local first = #features
  local d2 = { people = people, features = features, spots = d.spots, name = A.name(node, log), lore = d.lore,
               tensions = { tension } }
  tension.quest = tension.quest or "gather"
  gen.quests.generate(ctx, d2, gen.provisional.style(d.style), nil, { prefix = prefix })
  local added = {}
  for i = first + 1, #features do added[#added + 1] = features[i] end
  local extra = {}
  for i = #A.people(node, log) + 1, #people do extra[#extra + 1] = people[i] end
  d2.quest.chapter = n
  -- the old quest is history now; the new one starts afresh
  log.past = log.past or {}
  log.past[#log.past + 1] = log.outcome
  log.outcome, log.quest = nil, nil
  log.chapter = { n = n, quest = d2.quest, features = added, people = extra }
  log.dirty = true
end

-- ------------------------------------------------------------------ views
-- The people of a land now: who left, who came.
function A.people(node, log)
  local am = log.aftermath
  if not am then return node.data.people end
  local out = {}
  for _, p in ipairs(node.data.people) do if not am.gone[p.id] then out[#out + 1] = p end end
  for _, p in ipairs(am.people) do out[#out + 1] = p end
  return out
end

function A.name(node, log) return log.aftermath and log.aftermath.name or node.data.name end

-- The land as it is now: a view of the stored node with the aftermath's
-- people, fields, name, festival, news and the current chapter's quest.
function A.view(node, log)
  local am, ch = log.aftermath, log.chapter
  if not am and not ch then return node end
  local d = {}
  for k, v in pairs(node.data) do d[k] = v end
  d.people = A.people(node, log)
  d.name = A.name(node, log)
  if am then
    local fields = {}
    for _, f in ipairs(node.data.fields or {}) do fields[#fields + 1] = f end
    for _, f in ipairs(am.fields) do fields[#fields + 1] = f end
    d.fields = fields
    local lore = {}
    for k, v in pairs(node.data.lore or {}) do lore[k] = v end
    if #am.news > 0 then lore.news = am.news end
    if am.festival then
      lore.holidays = { am.festival }
      for _, h in ipairs(node.data.lore and node.data.lore.holidays or {}) do lore.holidays[#lore.holidays + 1] = h end
    end
    lore.place = d.name
    d.lore = lore
  end
  if ch then
    d.quest = ch.quest
    local features = {}
    for _, f in ipairs(node.data.features) do features[#features + 1] = f end
    for _, f in ipairs(ch.features) do features[#features + 1] = f end
    d.features = features
    local people = {}
    for _, p in ipairs(d.people) do people[#people + 1] = p end
    for _, p in ipairs(ch.people) do people[#people + 1] = p end
    d.people = people
  end
  local v = {}
  for k, val in pairs(node) do v[k] = val end
  v.data = d
  v.stored_node = node
  return v
end

return A
