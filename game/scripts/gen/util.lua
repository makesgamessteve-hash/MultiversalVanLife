-- Multiversal Van Life - helpers for generated data (MIT).
local util = {}

function util.copy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, x in pairs(v) do out[k] = util.copy(x) end
  return out
end

-- Deep equality (NaN equals NaN, integer 1 differs from float 1.0).
function util.equal(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) == "number" then return math.type(a) == math.type(b) and (a == b or (a ~= a and b ~= b)) end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do if not util.equal(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

-- Sorted keys: booleans, then numbers, then strings.
function util.sorted_keys(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  local rank = { boolean = 1, number = 2, string = 3 }
  table.sort(keys, function(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then return (rank[ta] or 9) < (rank[tb] or 9) end
    if ta == "boolean" then return (not a) and b end
    return a < b
  end)
  return keys
end

-- Canonical bytes of a value: the same data always gives the same bytes on
-- every platform (numbers are written as exact IEEE bits / 64-bit ints).
function util.canon(v, out)
  local top = out == nil
  out = out or {}
  local t = type(v)
  if t == "nil" then out[#out + 1] = "n"
  elseif t == "boolean" then out[#out + 1] = v and "T" or "F"
  elseif t == "number" then
    if math.type(v) == "integer" then out[#out + 1] = string.pack("<c1j", "i", v)
    else out[#out + 1] = string.pack("<c1d", "d", v) end
  elseif t == "string" then out[#out + 1] = string.pack("<c1s4", "s", v)
  elseif t == "table" then
    out[#out + 1] = "{"
    for _, k in ipairs(util.sorted_keys(v)) do
      util.canon(k, out)
      util.canon(v[k], out)
    end
    out[#out + 1] = "}"
  else
    error("cannot fingerprint a " .. t)
  end
  if top then return table.concat(out) end
end

-- Short hexadecimal fingerprint of any data.
function util.fingerprint(v)
  local bytes = util.canon(v)
  return string.format("%08x%08x", mvl.hash(bytes), mvl.hash(bytes, #bytes))
end

return util
