-- Multiversal Van Life - addresses and seeds of generated places (MIT).
--
-- An address lists a place's index on every level below the root, e.g.
-- "u3.g12.c4.s1.p2.k0.n5.l7" (universe 3, galaxy 12, ... land 7). The root
-- (the multiverse) is the empty address "". A scheme names the levels and
-- their one-letter prefixes; the cosmos uses COSMOS, tests use their own.
--
-- Seeds depend only on the root seed and the address:
--   seed(root) = root seed, seed(child) = hash(seed(parent), level, index)
-- and every generation pass draws from hash(seed(node), pass name), so
-- adding a pass never changes the numbers another pass sees.
local A = {}

-- levels = { { name, prefix }, ... } starting with the root (prefix "").
function A.scheme(levels)
  local s = { levels = {}, by_name = {}, by_prefix = {} }
  for i, l in ipairs(levels) do
    local level = { n = i - 1, name = l[1] or l.name, prefix = l[2] or l.prefix or "" }
    s.levels[i - 1] = level
    s.by_name[level.name] = level
    if level.n > 0 then
      assert(level.prefix:match("^%a$"), "level prefixes are single letters")
      assert(not s.by_prefix[level.prefix], "duplicate level prefix " .. level.prefix)
      s.by_prefix[level.prefix] = level
    end
  end
  s.depth = #levels - 1
  return s
end

A.COSMOS = A.scheme({
  { "multiverse", "" }, { "universe", "u" }, { "galaxy", "g" }, { "cluster", "c" }, { "system", "s" },
  { "planet", "p" }, { "continent", "k" }, { "country", "n" }, { "land", "l" },
})

local MAX_INDEX = 0x7fffffff

-- Splits an address into its indices. Returns nil, message when invalid.
function A.parse(scheme, addr)
  if type(addr) ~= "string" then return nil, "address must be a string" end
  local out = {}
  if addr == "" then return out end
  for part in (addr .. "."):gmatch("([^.]*)%.") do
    local prefix, digits = part:match("^(%a)(%d+)$")
    local level = scheme.levels[#out + 1]
    if not prefix or not level or prefix ~= level.prefix or #digits > 10 then
      return nil, "invalid address '" .. addr .. "'"
    end
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

function A.format(scheme, indices)
  local parts = {}
  for i, index in ipairs(indices) do
    local level = assert(scheme.levels[i], "address deeper than the scheme")
    assert(math.type(index) == "integer" and index >= 0 and index <= MAX_INDEX, "invalid index")
    parts[i] = level.prefix .. index
  end
  return table.concat(parts, ".")
end

-- Level number (0 = root) of an address.
function A.level(addr)
  if addr == "" then return 0 end
  local n = 1
  for _ in addr:gmatch("%.") do n = n + 1 end
  return n
end

-- Index of the place among its siblings (0 for the root).
function A.index(addr)
  return tonumber(addr:match("(%d+)$") or "0")
end

function A.parent(addr)
  if addr == "" then return nil end
  return addr:match("^(.*)%.[^.]*$") or ""
end

function A.child(scheme, addr, index)
  local level = scheme.levels[A.level(addr) + 1]
  assert(level, "the deepest level has no children")
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

-- Seed of a place.
function A.seed(root_seed, addr, scheme)
  local seed = root_seed
  if addr == "" then return seed end
  local indices = scheme and A.check(scheme, addr) or nil
  local level = 0
  for digits in addr:gmatch("%a(%d+)") do
    level = level + 1
    seed = mvl.hash(seed, level, indices and indices[level] or tonumber(digits))
  end
  return seed
end

-- Seed of one generation pass on a place.
function A.pass_seed(node_seed, pass_name) return mvl.hash(node_seed, pass_name) end

-- "Galaxy u3.g12"
function A.describe(scheme, addr)
  local level = scheme.levels[A.level(addr)]
  local name = level and level.name or "?"
  return name:sub(1, 1):upper() .. name:sub(2) .. (addr == "" and "" or " " .. addr)
end

return A
