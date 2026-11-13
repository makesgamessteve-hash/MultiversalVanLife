-- Multiversal Van Life - the generation runner (MIT).
--
-- A runner generates places of one registry from one root seed, lazily:
-- requesting an address generates that place and every ancestor not yet
-- generated, top down, and nothing else in detail. Siblings exist only as
-- the summaries ("skeletons") their parent produced. Generation runs in a
-- coroutine and yields between work units once the frame budget is spent,
-- so the game keeps rendering while a big place is generated.
local address = require("gen.address")
local facts = require("gen.facts")
local util = require("gen.util")

local run = { VERSION = 1 }
local G = {}
G.__index = G
local Ctx = {}
Ctx.__index = Ctx

local function sorted_mods()
  local list = {}
  for i, m in ipairs(mvl.mods and mvl.mods() or {}) do list[i] = m end
  table.sort(list)
  return list
end

-- opts: seed (root seed), budget (seconds per update, default 6 ms),
-- clock (function returning seconds), mods (list), version (number)
function run.new(registry, opts)
  opts = opts or {}
  return setmetatable({
    registry = registry, scheme = registry.scheme, seed = opts.seed or 0,
    budget = opts.budget or 0.006, clock = opts.clock or os.clock,
    mods = opts.mods or sorted_mods(), version = opts.version or run.VERSION,
    nodes = {}, skeletons = {}, queue = {},
    stats = { detail = 0, order = {}, passes = 0, yields = 0, updates = 0 },
  }, G)
end

-- --------------------------------------------------------------- places
function G:node(addr) return self.nodes[addr] end

local function count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

-- Summary of child `index` of a generated parent, or nil if no such child.
local function child_summary(self, parent, index, addr)
  local level = self.registry.levels[parent.level + 1]
  if not level then return nil end
  if parent.children[index] then return parent.children[index] end
  if level.skeleton then
    local cached = self.skeletons[addr]
    if cached == nil then
      cached = level.skeleton(parent, index, mvl.hash(parent.seed, level.n, index)) or false
      self.skeletons[addr] = cached
    end
    return cached or nil
  end
  if parent.listed_children then return nil end -- the parent listed all its children
  return index < self.registry.levels[parent.level].caps.children and {} or nil
end

-- Summary of any place whose parent is generated (nil otherwise).
function G:skeleton(addr)
  if addr == "" then return {} end
  local parent = self.nodes[address.parent(addr)]
  return parent and child_summary(self, parent, address.index(addr), addr) or nil
end

function G:_generate(addr)
  local node = self.nodes[addr]
  if node then return node end
  local parent = addr ~= "" and self:_generate(address.parent(addr)) or nil
  local summary = {}
  if parent then summary = child_summary(self, parent, address.index(addr), addr) end
  if not summary then error("there is no place at " .. addr, 0) end
  local level = self.registry.levels[address.level(addr)]
  local index = address.index(addr)
  node = {
    address = addr, level = level.n, kind = level.name, index = index,
    seed = parent and mvl.hash(parent.seed, level.n, index) or self.seed,
    summary = util.copy(summary), data = {}, children = {}, facts = {}, fact_order = {}, counts = {},
    commits = {}, honoured = {}, version = self.version, mods = self.mods,
  }
  local outer = self.building
  self.building = node
  for _, pass in ipairs(self.registry:ordered(level.n)) do
    local ctx = setmetatable({ G = self, node = node, parent = parent, pass = pass, data = node.data,
                               summary = node.summary, seed = address.pass_seed(node.seed, pass.name) }, Ctx)
    pass.run(ctx)
    self.stats.passes = self.stats.passes + 1
    ctx:yield()
  end
  self.building = outer
  if count(node.children) > level.caps.children then
    error(string.format("%s lists %d children, the cap is %d", addr, count(node.children), level.caps.children), 0)
  end
  if #node.fact_order > level.caps.facts then
    error(string.format("%s has %d facts, the cap is %d", addr, #node.fact_order, level.caps.facts), 0)
  end
  self.nodes[addr] = node
  self.stats.detail = self.stats.detail + 1
  self.stats.order[#self.stats.order + 1] = addr
  return node
end

-- ------------------------------------------------------------- running
-- Queues a place; on_done(node) runs once it is generated. Returns a job
-- table: { address, done, node, error }.
function G:request(addr, on_done)
  address.check(self.scheme, addr)
  local job = { address = addr, on_done = on_done }
  if self.nodes[addr] then
    job.done, job.node = true, self.nodes[addr]
    if on_done then on_done(job.node) end
  else
    self.queue[#self.queue + 1] = job
  end
  return job
end

function G:busy() return self.co ~= nil or #self.queue > 0 end

-- Works on queued requests for at most `budget` seconds (default: the
-- runner's budget). Returns true while work remains.
function G:update(budget)
  if not self:busy() then return false end
  self.deadline = self.clock() + (budget or self.budget)
  self.stats.updates = self.stats.updates + 1
  while true do
    if not self.co then
      local job = table.remove(self.queue, 1)
      if not job then return false end
      self.job = job
      self.co = coroutine.create(function() return self:_generate(job.address) end)
    end
    local ok, result = coroutine.resume(self.co)
    if coroutine.status(self.co) == "dead" then
      local job = self.job
      self.co, self.job, self.building = nil, nil, nil
      job.done = true
      if ok then
        job.node = result
        if job.on_done then job.on_done(result) end
      else
        job.error = tostring(result)
        mvl.log("generation of '" .. job.address .. "' failed: " .. job.error)
      end
    end
    if self.clock() >= self.deadline then return self:busy() end
  end
end

-- Generates a place right now (finishing queued work first) and returns it.
function G:generate(addr)
  address.check(self.scheme, addr)
  while self:busy() do self:update(math.huge) end
  local prev = self.deadline
  self.deadline = math.huge
  local ok, node = pcall(self._generate, self, addr)
  self.deadline, self.building = prev, nil
  if not ok then error(node, 0) end
  return node
end

-- Drops generated places at or below `addr` from memory.
function G:forget(addr)
  for a in pairs(self.nodes) do
    if address.is_ancestor(addr, a, true) then self.nodes[a] = nil end
  end
  for a in pairs(self.skeletons) do
    if address.is_ancestor(addr, a) then self.skeletons[a] = nil end
  end
end

function G:fact(id) return facts.resolve(self, id) end
function G:why(id) return facts.why(self, id) end
function G:explain(id, depth) return facts.explain(self, id, depth) end

-- ------------------------------------------------------ pass context
-- The random stream of this pass (independent of every other pass).
function Ctx:rng()
  self._rng = self._rng or mvl.rng(self.seed)
  return self._rng
end

-- A further independent stream, e.g. one per item a pass generates.
function Ctx:random(name) return mvl.rng(mvl.hash(self.seed, name)) end

-- Lets the runner pause here if the frame budget is spent.
function Ctx:yield()
  local G = self.G
  if G.co and coroutine.running() == G.co and G.clock() >= G.deadline then
    G.stats.yields = G.stats.yields + 1
    coroutine.yield()
  end
end

-- The generated ancestor on a level (by name or number).
function Ctx:ancestor(level)
  local l = self.G.registry:level(level)
  local path = address.path(self.node.address)
  return l.n == self.node.level and self.node or self.G.nodes[path[l.n + 1]]
end

function Ctx:table(name) return self.G.registry:table(name) end

-- Lists child `index` with a summary (its skeleton). Once a place lists
-- children, only listed children (and those of a skeleton function) exist.
function Ctx:child(index, summary)
  local own = self.G.registry.levels[self.node.level]
  assert(self.G.registry.levels[self.node.level + 1], "the deepest level has no children")
  assert(math.type(index) == "integer" and index >= 0 and index < own.caps.children,
         string.format("child index %s is beyond the cap of %d children of a %s", tostring(index), own.caps.children,
                       own.name))
  self.node.children[index] = summary or {}
  self.node.listed_children = true
  return address.child(self.G.scheme, self.node.address, index)
end

-- Records a fact; returns its id and the fact.
function Ctx:fact(kind, data, because)
  assert(type(kind) == "string" and kind:match("^[%a_][%w_]*$"), "fact kinds are words")
  local node = self.node
  local n = (node.counts[kind] or 0) + 1
  node.counts[kind] = n
  local id = node.address .. "/" .. kind .. "/" .. n
  local f = { id = id, kind = kind, data = data or {}, because = facts.ids(because), pass = self.pass.name }
  node.facts[id] = f
  node.fact_order[#node.fact_order + 1] = id
  return id, f
end

-- A fact that involves several places below this one (a faction, a
-- species, a trade route). It must live on their lowest common ancestor.
function Ctx:shared(kind, data, members, because)
  local list = {}
  for i, m in ipairs(members) do
    list[i] = type(m) == "number" and address.child(self.G.scheme, self.node.address, m) or m
    if not address.is_ancestor(self.node.address, list[i]) then
      error(string.format("%s is not inside %s", list[i], self.node.address), 2)
    end
  end
  local home = #list > 0 and address.common_all(list) or self.node.address
  if home ~= self.node.address then
    error(string.format("a %s shared only by places inside %s belongs there, not on %s", kind, home,
                        self.node.address == "" and "the root" or self.node.address), 2)
  end
  local id, f = self:fact(kind, data, because)
  f.members = list
  return id, f
end

-- Promises that the place at `target` (a child index or any address below
-- this place) will contain something; its generation must honour it.
function Ctx:commit(target, kind, data, because)
  if type(target) == "number" then target = address.child(self.G.scheme, self.node.address, target) end
  address.check(self.G.scheme, target)
  if not address.is_ancestor(self.node.address, target) then
    error(string.format("%s can only commit to places inside it, not %s", self.node.address, target), 2)
  end
  local id = self:fact("commitment", { target = target, kind = kind, data = data or {} }, because)
  local list = self.node.commits[target]
  if not list then list = {} self.node.commits[target] = list end
  list[#list + 1] = id
  return id
end

-- Commitments made to this place by its ancestors (optionally one kind).
function Ctx:commitments(kind)
  local out = {}
  local path = address.path(self.node.address)
  for i = 1, #path - 1 do
    local anc = self.G.nodes[path[i]]
    for _, id in ipairs(anc.commits[self.node.address] or {}) do
      local c = anc.facts[id]
      if not kind or c.data.kind == kind then out[#out + 1] = c end
    end
  end
  return out
end

-- Marks a commitment as honoured by one of this place's facts.
function Ctx:honour(commitment, fact_id)
  assert(self.node.facts[fact_id], "honour a commitment with a fact of this place")
  self.node.honoured[commitment.id or commitment] = fact_id
end

-- A fact of this place or one of its ancestors (error otherwise).
function Ctx:ref(id)
  local addr = facts.split(id)
  if not addr or not address.is_ancestor(addr, self.node.address, true) then
    error("fact " .. tostring(id) .. " is not on the path of " .. self.node.address, 2)
  end
  return assert(facts.resolve(self.G, id), "unknown fact " .. tostring(id))
end

run.Ctx = Ctx
return run
