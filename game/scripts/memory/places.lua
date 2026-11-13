-- Multiversal Van Life - visited places are stored (MIT).
--
-- On the first visit a land's generated description (terrain parameters,
-- settlement, buildings, people, items, trouble, facts; never geometry) and
-- short summaries of its ancestors are written to records/places/<address>.
-- Later visits load the record instead of generating, so a land stays
-- exactly as the player first found it, even after the generator changed.
local address = require("gen.address")

local places = {}

function places.record(addr) return "places/" .. addr end

local function ancestors(G, addr)
  local out = {}
  for _, a in ipairs(address.path(addr)) do
    local n = G.nodes[a]
    if a ~= addr and n then
      out[#out + 1] = { address = a, kind = n.kind, name = n.data.name or n.summary.name, style = n.data.style }
    end
  end
  return out
end

-- Summary of the ancestor of a stored place on a level ("planet", ...).
function places.ancestor(node, kind)
  for _, a in ipairs(node.ancestors or {}) do if a.kind == kind then return a end end
end

function places.stored(addr) return mvl.record_read(places.record(addr)) ~= nil end

-- Puts a stored place into the runner's cache (if there is one) so that
-- requesting it does not generate anything. Returns the node or nil.
function places.load(G, addr)
  local node = G.nodes[addr]
  if node and node.stored then return node end
  local rec = mvl.record_read(places.record(addr))
  if not rec or not rec.node then return nil end
  node = rec.node
  node.stored, node.ancestors = true, rec.ancestors
  G.nodes[addr] = node
  return node
end

-- The place at `addr`: stored, or generated now and stored.
function places.get(G, addr)
  local node = places.load(G, addr)
  if node then return node end
  node = G:generate(addr)
  node.ancestors = ancestors(G, addr)
  mvl.record_write(places.record(addr), { node = node, ancestors = node.ancestors })
  node.stored = true
  return node
end

return places
