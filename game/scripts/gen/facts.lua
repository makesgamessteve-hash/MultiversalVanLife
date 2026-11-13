-- Multiversal Van Life - facts and their causes (MIT).
--
-- A fact is anything a pass decides about a place: a faction, a war, a
-- founding, a commitment to a place below. Its id is
-- "<address>/<kind>/<n>" (n counts facts of that kind on the place) and its
-- `because` list names the facts it was derived from, so the game can
-- always answer "why is this so?" by following the links.
local facts = {}

function facts.split(id)
  local addr, kind, n = tostring(id):match("^([^/]*)/([%a_][%w_]*)/(%d+)$")
  if not addr then return nil end
  return addr, kind, tonumber(n)
end

-- Turns nil, an id, a fact or a list of those into a list of ids.
function facts.ids(because)
  if because == nil then return {} end
  if type(because) == "string" then return { because } end
  if type(because) == "table" and because.id then return { because.id } end
  local out = {}
  for i, b in ipairs(because) do out[i] = type(b) == "table" and b.id or b end
  return out
end

-- The fact with this id, if its place has been generated.
function facts.resolve(G, id)
  local addr = facts.split(id)
  if not addr then return nil end
  local node = G.nodes[addr] or (G.building and G.building.address == addr and G.building)
  return node and node.facts[id] or nil
end

-- The facts this fact was derived from ({ id = ..., missing = true } for
-- causes whose place is not generated).
function facts.why(G, id)
  local f = facts.resolve(G, id)
  if not f then return nil end
  local out = {}
  for i, cause in ipairs(f.because) do out[i] = facts.resolve(G, cause) or { id = cause, missing = true } end
  return out
end

-- A short human readable description of a fact.
function facts.describe(f)
  if f.missing then return f.id .. " (not generated)" end
  local d = f.data or {}
  local label = d.name or d.title or d.what
  if f.kind == "commitment" then
    return string.format("%s: %s promised to %s", f.id, tostring(d.kind), tostring(d.target))
  end
  return label and string.format("%s: %s", f.id, tostring(label)) or f.id
end

-- Lines explaining a fact and its causes, `depth` links deep:
--   u3/war/2: The Ash War
--     because u3/faction/1: Lantern League
--       because /law/1: magic from belief
function facts.explain(G, id, depth, level, out, seen)
  out, seen, level, depth = out or {}, seen or {}, level or 0, depth or 4
  local f = facts.resolve(G, id) or { id = id, missing = true }
  out[#out + 1] = string.rep("  ", level) .. (level > 0 and "because " or "") .. facts.describe(f)
  if seen[id] or f.missing or depth <= 0 then return out end
  seen[id] = true
  for _, cause in ipairs(f.because) do facts.explain(G, cause, depth - 1, level + 1, out, seen) end
  return out
end

return facts
