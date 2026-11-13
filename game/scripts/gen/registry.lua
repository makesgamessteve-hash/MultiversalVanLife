-- Multiversal Van Life - the registry of generation levels and passes (MIT).
--
-- A registry describes one hierarchy (the cosmos, or a small one in tests):
-- its levels, the passes that generate a place on each level, content
-- tables generators draw from, caps and consistency checks. The game and
-- mods register into the same registry, so a mod adds a pass or extends a
-- content table exactly like the base game does.
local address = require("gen.address")

local registry = { current_mod = nil }
local R = {}
R.__index = R

local DEFAULT_CAPS = { children = 0x7fffffff, facts = 4096 }

-- def = { name, levels = { { name, prefix [, caps] [, skeleton] }, ... } }
function registry.new(def)
  local self = setmetatable({ name = def.name or "hierarchy", levels = {}, passes = {}, tables = {}, checks = {},
                              order = {} }, R)
  self.scheme = address.scheme(def.levels)
  for n = 0, self.scheme.depth do
    local src = def.levels[n + 1]
    local caps = {}
    for k, v in pairs(DEFAULT_CAPS) do caps[k] = v end
    for k, v in pairs(src.caps or {}) do caps[k] = v end
    self.levels[n] = { n = n, name = self.scheme.levels[n].name, prefix = self.scheme.levels[n].prefix,
                       caps = caps, skeleton = src.skeleton }
    self.passes[n] = {}
  end
  return self
end

-- Level by number or name.
function R:level(which)
  local level = type(which) == "number" and self.levels[which]
                or (self.scheme.by_name[which] and self.levels[self.scheme.by_name[which].n])
  if not level then error("unknown level " .. tostring(which), 2) end
  return level
end

-- Registers (or replaces) a pass.
--   opts.run(ctx)        generates; reads parent, earlier passes, commitments
--   opts.after = {...}   names of passes on the same level that must run first
function R:pass(level, name, opts)
  local l = self:level(level)
  assert(type(name) == "string" and name:match("^[%w_]+$"), "pass names are words")
  assert(type(opts) == "table" and type(opts.run) == "function", "a pass needs a run function")
  for _, dep in ipairs(opts.after or {}) do assert(type(dep) == "string", "after lists pass names") end
  self.passes[l.n][name] = { name = name, run = opts.run, after = opts.after or {}, mod = registry.current_mod }
  self.order[l.n] = nil
  return self.passes[l.n][name]
end

function R:remove_pass(level, name)
  local l = self:level(level)
  self.passes[l.n][name] = nil
  self.order[l.n] = nil
end

-- Passes of a level in dependency order (ties broken by name, so the
-- order never depends on which mod registered first).
function R:ordered(level)
  local l = self:level(level)
  if self.order[l.n] then return self.order[l.n] end
  local passes, pending, done, out = self.passes[l.n], {}, {}, {}
  for name, p in pairs(passes) do
    for _, dep in ipairs(p.after) do
      if not passes[dep] then
        error(string.format("pass '%s' on level %s runs after '%s', which is not registered", name, l.name, dep))
      end
    end
    pending[#pending + 1] = name
  end
  table.sort(pending)
  while #pending > 0 do
    local picked
    for i, name in ipairs(pending) do
      local ready = true
      for _, dep in ipairs(passes[name].after) do if not done[dep] then ready = false break end end
      if ready then picked = i break end
    end
    if not picked then
      error("passes on level " .. l.name .. " depend on each other in a cycle: " .. table.concat(pending, ", "))
    end
    local name = table.remove(pending, picked)
    done[name] = true
    out[#out + 1] = passes[name]
  end
  self.order[l.n] = out
  return out
end

-- Content tables: lists of entries generators draw from (species body
-- plans, building styles, ...). Mods append to them.
function R:content(name, entries)
  local t = self.tables[name]
  if not t then t = {} self.tables[name] = t end
  for _, e in ipairs(entries or {}) do t[#t + 1] = e end
  return t
end

function R:table(name) return self.tables[name] or {} end

-- Caps: maximum children and facts of a place on this level.
function R:caps(level, caps)
  local l = self:level(level)
  for k, v in pairs(caps) do l.caps[k] = v end
end

-- Lazily computed summaries of children the parent did not list:
-- fn(parent_node, index, seed) -> summary table, or nil if there is no
-- such child.
function R:skeleton(level, fn) self:level(level).skeleton = fn end

-- Overview text of a place for the world bible: fn(node) -> string.
function R:describe(level, fn) self:level(level).describe = fn end

-- Consistency checks run by gen.check: fn(node, report, G).
function R:check(name, fn) self.checks[name] = fn end

-- Runs `fn` with mod attribution for every pass it registers.
function registry.as_mod(mod, fn)
  local prev = registry.current_mod
  registry.current_mod = mod
  local ok, err = pcall(fn)
  registry.current_mod = prev
  if not ok then error(err, 2) end
end

return registry
