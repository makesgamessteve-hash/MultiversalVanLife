-- Multiversal Van Life - consistency checks of generated places (MIT).
--
-- Built in: every commitment made to a generated place is honoured, every
-- cause and reference points to an existing fact on the place's path (so
-- shared things really live on a common ancestor), effects never happen
-- before their causes, spans end after they start, shared facts live on
-- the lowest common ancestor of their members. Generators add their own
-- checks with registry:check(name, fn(node, report, G)).
local address = require("gen.address")
local facts = require("gen.facts")

local check = {}

local function on_path(G, node, id)
  local addr = facts.split(id)
  if not addr then return nil, "is not a fact id" end
  if not address.is_ancestor(addr, node.address, true) then return nil, "is not on the path of " .. node.address end
  local f = facts.resolve(G, id)
  if not f then return nil, "does not exist" end
  return f
end

local function references(f)
  local out = {}
  for _, id in ipairs(f.because) do out[#out + 1] = { id = id, what = "cause" } end
  for k, v in pairs(f.data) do
    if type(k) == "string" and k:match("_id$") and type(v) == "string" then
      out[#out + 1] = { id = v, what = k }
    elseif type(k) == "string" and k:match("_ids$") and type(v) == "table" then
      for _, id in ipairs(v) do out[#out + 1] = { id = id, what = k } end
    end
  end
  table.sort(out, function(a, b) return a.id < b.id end)
  return out
end

function check.node(G, node, report)
  local where = node.address == "" and "the root" or node.address
  -- commitments made to this place
  local path = address.path(node.address)
  for i = 1, #path - 1 do
    local anc = G.nodes[path[i]]
    for _, cid in ipairs(anc and anc.commits[node.address] or {}) do
      local by = node.honoured[cid]
      if not by or not node.facts[by] then
        report("commitments", string.format("commitment %s (%s) to %s was not honoured", cid,
                                            tostring(anc.facts[cid].data.kind), where))
      end
    end
  end
  for _, id in ipairs(node.fact_order) do
    local f = node.facts[id]
    for _, ref in ipairs(references(f)) do
      local target, why = on_path(G, node, ref.id)
      if not target then
        report("references", string.format("%s refers to %s (%s), which %s", id, ref.id, ref.what, why))
      elseif ref.what == "cause" and type(f.data.year) == "number" and type(target.data.year) == "number"
             and target.data.year > f.data.year then
        report("chronology", string.format("%s (year %s) is caused by %s, which happens later (year %s)", id,
                                           f.data.year, ref.id, target.data.year))
      end
    end
    if type(f.data.from) == "number" and type(f.data.to) == "number" and f.data.to < f.data.from then
      report("chronology", string.format("%s ends (%s) before it starts (%s)", id, f.data.to, f.data.from))
    end
    if f.members and #f.members > 0 and address.common_all(f.members) ~= node.address then
      report("shared", string.format("%s is shared by places inside %s but lives on %s", id,
                                     address.common_all(f.members), where))
    end
  end
  local names = {}
  for name in pairs(G.registry.checks) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    G.registry.checks[name](node, function(msg) report(name, msg) end, G)
  end
end

-- Checks generated places (default: all) and returns a list of problems
-- { check = name, address = ..., message = ... }.
function check.run(G, addrs)
  if not addrs then
    addrs = {}
    for a in pairs(G.nodes) do addrs[#addrs + 1] = a end
  end
  table.sort(addrs)
  local problems = {}
  for _, a in ipairs(addrs) do
    local node = G.nodes[a]
    if node then
      check.node(G, node, function(name, msg)
        problems[#problems + 1] = { check = name, address = a, message = msg }
      end)
    end
  end
  return problems
end

-- Raises an error listing every problem.
function check.assert_ok(G, addrs)
  local problems = check.run(G, addrs)
  if #problems > 0 then
    local lines = {}
    for i, p in ipairs(problems) do lines[i] = "[" .. p.check .. "] " .. p.message end
    error("consistency check failed:\n  " .. table.concat(lines, "\n  "), 2)
  end
end

return check
