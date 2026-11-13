-- Multiversal Van Life - small helpers (MIT License).
local util = {}

function util.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end
function util.lerp(a, b, t) return a + (b - a) * t end

function util.approach(v, target, step)
  if v < target then return math.min(v + step, target) end
  return math.max(v - step, target)
end

function util.dist2(ax, az, bx, bz)
  local dx, dz = ax - bx, az - bz
  return math.sqrt(dx * dx + dz * dz)
end

-- Forward vector on the ground plane for a yaw (0 looks along -Z).
function util.forward(yaw) return -math.sin(yaw), -math.cos(yaw) end
function util.right(yaw) return math.cos(yaw), -math.sin(yaw) end

-- Yaw that looks from (ax, az) towards (bx, bz).
function util.yaw_towards(ax, az, bx, bz) return math.atan(-(bx - ax), -(bz - az)) end

function util.count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

function util.split(s, sep)
  local out = {}
  for part in string.gmatch(s, "([^" .. sep .. "]*)") do out[#out + 1] = part end
  return out
end

function util.trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

return util
