-- Multiversal Van Life - addresses and seeds of generated places (MIT).
--
-- An address lists a place's index on every level below the root, e.g.
-- "u3.g12.c4.s1.p2.k0.n5.l7" (universe 3, galaxy 12, ... land 7). The root
-- (the multiverse) is the empty address "". A scheme names the levels and
-- their one-letter prefixes; the cosmos uses COSMOS, tests use their own.
--
-- Levels usually form a chain (each the child of the one before), but a
-- level may name its parent level(s): in the cosmos a planet has
-- continents (politics) and regions (the surface grid), and a land lies in
-- a country (multiverses from before the grid) or in a region, so both
-- "...p2.k0.n5.l7" and "...p2.r40961.l7" are lands. Every level keeps its
-- own number, which seeds use.
--
-- Seeds depend only on the root seed and the address:
--   seed(root) = root seed, seed(child) = hash(seed(parent), level, index)
-- and every generation pass draws from hash(seed(node), pass name), so
-- adding a pass never changes the numbers another pass sees.
local A = {}

-- levels = { { name, prefix [, parent = name or { names }] }, ... }
-- starting with the root (prefix ""). Without `parent` a level is the child
-- of the level listed before it.
function A.scheme(levels)
  local s = { levels = {}, by_name = {}, by_prefix = {} }
  for i, l in ipairs(levels) do
    local level = { n = i - 1, name = l[1] or l.name, prefix = l[2] or l.prefix or "", parents = {}, children = {} }
    s.levels[i - 1] = level
    s.by_name[level.name] = level
    if level.n > 0 then
      assert(level.prefix:match("^%a$"), "level prefixes are single letters")
      assert(not s.by_prefix[level.prefix], "duplicate level prefix " .. level.prefix)
      s.by_prefix[level.prefix] = level
    end
  end
  for i, l in ipairs(levels) do
    local level = s.levels[i - 1]
    if level.n > 0 then
      local parents = l.parent or s.levels[level.n - 1].name
      if type(parents) == "string" then parents = { parents } end
      for _, name in ipairs(parents) do
        local p = assert(s.by_name[name], "unknown parent level " .. tostring(name))
        level.parents[name] = true
        p.children[#p.children + 1] = level -- in level order: the first is the main child level
      end
    end
  end
  s.depth = #levels - 1
  return s
end

A.COSMOS = A.scheme({
  { "multiverse", "" }, { "universe", "u" }, { "galaxy", "g" }, { "cluster", "c" }, { "system", "s" },
  { "planet", "p" }, { "continent", "k" }, { "country", "n" }, { "land", "l", parent = { "country", "region" } },
  { "region", "r", parent = "planet" },
})

local MAX_INDEX = 0x7fffffff

-- Splits an address into its indices. Returns nil, message when invalid.
function A.parse(scheme, addr)
  if type(addr) ~= "string" then return nil, "address must be a string" end
  local out = {}
  if addr == "" then return out end
  local above = scheme.levels[0]
  for part in (addr .. "."):gmatch("([^.]*)%.") do
    local prefix, digits = part:match("^(%a)(%d+)$")
    local level = prefix and scheme.by_prefix[prefix]
    if not level or not level.parents[above.name] or #digits > 10 then
      return nil, "invalid address '" .. addr .. "'"
    end
    above = level
    local index = tonumber(digits)
    if index > MAX_INDEX or (digits ~= "0" and digits:sub(1, 1) == "0") then
      return nil, "invalid address '" .. addr .. "'"
    end
    out[#out + 1] = index
  end
  return out
end

function A.check(scheme, addr)
  local ok, err = A.parse(scheme, addr)
  if not ok then error(err, 3) end
  return ok
end

-- Address of indices along the main child levels (or the levels named in
-- `names`, one per index).
function A.format(scheme, indices, names)
  local parts = {}
  local level = scheme.levels[0]
  for i, index in ipairs(indices) do
    level = names and scheme.by_name[names[i]] or level.children[1]
    assert(level, "address deeper than the scheme")
    assert(math.type(index) == "integer" and index >= 0 and index <= MAX_INDEX, "invalid index")
    parts[i] = level.prefix .. index
  end
  return table.concat(parts, ".")
end

-- Depth of an address (0 = root): how many levels it passes through.
function A.level(addr)
  if addr == "" then return 0 end
  local n = 1
  for _ in addr:gmatch("%.") do n = n + 1 end
  return n
end

-- The level of an address in a scheme (by the prefix of its last part).
function A.level_of(scheme, addr)
  if addr == "" then return scheme.levels[0] end
  local prefix = addr:match("(%a)%d+$")
  return prefix and scheme.by_prefix[prefix] or nil
end

-- Index of the place among its siblings (0 for the root).
function A.index(addr)
  return tonumber(addr:match("(%d+)$") or "0")
end

function A.parent(addr)
  if addr == "" then return nil end
  return addr:match("^(.*)%.[^.]*$") or ""
end

-- Address of child `index` of `addr` on its main child level, or on level
-- `name` (e.g. a planet's "region").
function A.child(scheme, addr, index, name)
  local own = A.level_of(scheme, addr)
  local level = own and (name and scheme.by_name[name] or own.children[1])
  assert(level, "the deepest level has no children")
  assert(level.parents[own.name], level.name .. " is not a child level of " .. own.name)
  assert(math.type(index) == "integer" and index >= 0 and index <= MAX_INDEX, "invalid index")
  return (addr == "" and "" or addr .. ".") .. level.prefix .. index
end

-- Every address from the root down to `addr` (inclusive).
function A.path(addr)
  local out, cur = {}, addr
  while cur do
    table.insert(out, 1, cur)
    cur = A.parent(cur)
  end
  return out
end

-- True if `a` is an ancestor of `b` (or equal when or_self is set).
function A.is_ancestor(a, b, or_self)
  if a == b then return or_self == true end
  return a == "" or b:sub(1, #a + 1) == a .. "."
end

-- The deepest place containing both addresses.
function A.common(a, b)
  while not A.is_ancestor(a, b, true) do a = A.parent(a) end
  return a
end

function A.common_all(list)
  local c = list[1]
  for i = 2, #list do c = A.common(c, list[i]) end
  return c
end

-- Seed of a place (hashing the level numbers of `scheme`; without one, of
-- the cosmos when the address is one, else of the depth).
function A.seed(root_seed, addr, scheme)
  local seed = root_seed
  if addr == "" then return seed end
  if scheme then A.check(scheme, addr) elseif A.parse(A.COSMOS, addr) then scheme = A.COSMOS end
  local depth = 0
  for prefix, digits in addr:gmatch("(%a)(%d+)") do
    depth = depth + 1
    local level = scheme and scheme.by_prefix[prefix]
    seed = mvl.hash(seed, level and level.n or depth, tonumber(digits))
  end
  return seed
end

-- Seed of one generation pass on a place.
function A.pass_seed(node_seed, pass_name) return mvl.hash(node_seed, pass_name) end

-- "Galaxy u3.g12"
function A.describe(scheme, addr)
  local level = A.level_of(scheme, addr)
  local name = level and level.name or "?"
  return name:sub(1, 1):upper() .. name:sub(2) .. (addr == "" and "" or " " .. addr)
end

return A
