-- Multiversal Van Life - deterministic math for generators (MIT).
--
-- math.sin, math.exp, math.log and friends come from each platform's C
-- library and may differ in the last bit between Windows, Linux, macOS and
-- the web, which would make the same seed generate a different multiverse.
-- These versions use only + - * / and sqrt, which IEEE 754 defines exactly,
-- so they give bit-identical results everywhere (accurate to ~1e-15).
local M = {}

local LN2 = 0.69314718055994530942
local PI = 3.14159265358979323846
local PIO2_HI = 1.57079632673412561417 -- pi/2 split for exact range reduction
local PIO2_LO = 6.07710050650619224932e-11
M.pi = PI

-- 2^k for integer k, exactly.
local function pow2(k)
  local r, b = 1.0, (k >= 0) and 2.0 or 0.5
  k = k >= 0 and k or -k
  while k > 0 do
    if k % 2 == 1 then r = r * b end
    b = b * b
    k = k // 2
  end
  return r
end

function M.exp(x)
  if x ~= x then return x end
  if x > 709 then return math.huge end
  if x < -745 then return 0.0 end
  local k = math.floor(x / LN2 + 0.5)
  local r = x - k * LN2
  -- Taylor series of e^r for |r| <= 0.35
  local term, sum = 1.0, 1.0
  for n = 1, 18 do
    term = term * r / n
    sum = sum + term
  end
  return sum * pow2(k)
end

function M.log(x)
  if x ~= x or x < 0 then return 0 / 0 end
  if x == 0 then return -math.huge end
  if x == math.huge then return x end
  local e = 0
  while x >= 1.4142135623730951 do x = x * 0.5 e = e + 1 end
  while x < 0.7071067811865476 do x = x * 2.0 e = e - 1 end
  -- log(x) = 2 atanh(s), s = (x - 1) / (x + 1), |s| <= 0.172
  local s = (x - 1) / (x + 1)
  local s2, term, sum = s * s, s, s
  for n = 3, 41, 2 do
    term = term * s2
    sum = sum + term / n
  end
  return e * LN2 + 2 * sum
end

function M.pow(a, b)
  if b == 0 then return 1.0 end
  if a == 0 then return b > 0 and 0.0 or math.huge end
  if math.type(b) == "integer" or b == math.floor(b) and math.abs(b) < 64 then
    local r, base, n = 1.0, a, math.abs(math.floor(b))
    while n > 0 do
      if n % 2 == 1 then r = r * base end
      base = base * base
      n = n // 2
    end
    return b < 0 and 1 / r or r
  end
  assert(a > 0, "dmath.pow needs a positive base for fractional exponents")
  return M.exp(b * M.log(a))
end

-- sin and cos of |r| <= pi/4
local function ksin(r)
  local r2, term, sum = r * r, r, r
  for n = 1, 9 do
    term = -term * r2 / ((2 * n) * (2 * n + 1))
    sum = sum + term
  end
  return sum
end

local function kcos(r)
  local r2, term, sum = r * r, 1.0, 1.0
  for n = 1, 9 do
    term = -term * r2 / ((2 * n - 1) * (2 * n))
    sum = sum + term
  end
  return sum
end

local function reduce(x)
  local k = math.floor(x / PIO2_HI + 0.5)
  return (x - k * PIO2_HI) - k * PIO2_LO, k % 4
end

function M.sin(x)
  local r, q = reduce(x)
  if q == 0 then return ksin(r) elseif q == 1 then return kcos(r) elseif q == 2 then return -ksin(r) end
  return -kcos(r)
end

function M.cos(x)
  local r, q = reduce(x)
  if q == 0 then return kcos(r) elseif q == 1 then return -ksin(r) elseif q == 2 then return -kcos(r) end
  return ksin(r)
end

-- atan of t in [-1, 1]
local function katan(t)
  -- two halvings: atan(t) = 2 atan(t / (1 + sqrt(1 + t^2)))
  t = t / (1 + math.sqrt(1 + t * t))
  t = t / (1 + math.sqrt(1 + t * t))
  local t2, term, sum = t * t, t, t
  for n = 3, 31, 2 do
    term = -term * t2
    sum = sum + term / n
  end
  return 4 * sum
end

function M.atan(y, x)
  x = x or 1.0
  if x == 0 and y == 0 then return 0.0 end
  local ax, ay = math.abs(x), math.abs(y)
  local a
  if ay <= ax then a = katan(ay / ax) else a = PI / 2 - katan(ax / ay) end
  if x < 0 then a = PI - a end
  return y < 0 and -a or a
end

-- Wraps an angle into (-pi, pi].
function M.wrap(a)
  a = a % (2 * PI)
  if a > PI then a = a - 2 * PI end
  return a
end

function M.clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end
function M.lerp(a, b, t) return a + (b - a) * t end

-- Rounds to `digits` decimals (for display and summaries).
function M.round(v, digits)
  local f = 1.0
  for _ = 1, digits or 0 do f = f * 10 end
  return math.floor(v * f + 0.5) / f
end

-- A roughly normal value from a random stream (sum of uniforms).
function M.normal(rng, mean, sd)
  local s = rng:next() + rng:next() + rng:next() + rng:next() - 2
  return (mean or 0) + s * 1.7320508075688772 * (sd or 1)
end

-- Picks from { { id = ..., w = weight }, ... } (weights may be scaled by
-- `mult[id]`). Returns the entry.
function M.weighted(rng, entries, mult)
  local total = 0
  for _, e in ipairs(entries) do total = total + e.w * (mult and mult[e.id] or 1) end
  local x = rng:next() * total
  for _, e in ipairs(entries) do
    x = x - e.w * (mult and mult[e.id] or 1)
    if x < 0 then return e end
  end
  return entries[#entries]
end

return M
