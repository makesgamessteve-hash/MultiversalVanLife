-- Multiversal Van Life - voxel animals assembled from body plans (MIT).
--
-- A creature is a torso (with head, eyes, belly and the pattern of its
-- covering: fur flecks, scale rows, feather backs, chitin bands, a shell,
-- back plates) plus the parts its body plan gives it: legs in pairs, wings,
-- a tail, or a chain of segments for legless crawlers. Each movable part is
-- its own small mesh, so animation only moves entities (see lib/creatures):
--
--   body   torso and head, origin at the bottom centre, facing -z
--   leg    built pointing up from its hip; spawned upside down (roll = pi)
--   wing   extends along +x from its root; the left one is turned (yaw = pi)
--   tail   extends backwards (+z) from its root
--   seg    one segment of a crawler's body
--   merged everything in its resting pose, for creatures far away
--
-- Modders can add parts: CR.PARTS[name] = function(g, plan, z0, cy) ... end is
-- called (in name order) for every creature with the body grid, its plan,
-- the torso's bottom z0 and middle cy (voxels), and may draw
-- into the grid (see docs/MODDING.md).
local dm = require("gen.dmath")

local CR = { TORSO = 12, PARTS = {} }
local cos, sin = dm.cos, dm.sin

local function color(g, i, c) g:color(i, c[1], c[2], c[3]) end
local function palette(g, colors)
  color(g, 1, colors[1])
  color(g, 2, colors[2])
  color(g, 3, colors[3])
  color(g, 4, { 16, 14, 18 })
  color(g, 5, { 236, 232, 220 })
end

-- The plan of a creature: its proportions in voxels and the voxel size.
-- p = {limbs, covering, segments, eyes, tail, move, size, height,
--      stockiness, colors, seed}
function CR.plan(p)
  local r = mvl.rng(p.seed)
  local size = dm.clamp(p.size, 0.15, 8)
  local s = size / 16
  local st = dm.clamp(p.stockiness or 1, 0.6, 1.8)
  local rx = dm.clamp(2.6 * st, 1.6, 5)
  local rz = dm.clamp(2.4 * st, 1.6, 4.5)
  local legless = p.limbs == 0
  local leg = legless and 0 or dm.clamp(math.floor(dm.clamp(p.height, 0.05, 6) / s - 2 * rz + 0.5), 2,
                                        math.min(10, math.floor(rz * 2.4)))
  if p.move == "fly" then leg = math.min(leg, 3) end
  return {
    s = s, rx = rx, rz = rz, ry = CR.TORSO / 2, leg = leg, legless = legless, pairs = math.floor(p.limbs / 2),
    wings = p.move == "fly" or p.move == "glide", tail = p.tail and not legless, eyes = p.eyes or 2,
    covering = p.covering, segments = legless and dm.clamp(p.segments or 6, 3, 7) or 0,
    colors = p.colors, span = math.floor(CR.TORSO * (0.7 + r:next() * 0.4)), head = 2.2 + r:next() * 1.2,
    snout = r:next() * 2, flecks = r:int(3, 7), seed = p.seed, hopper = p.limbs == 2,
  }
end

-- Draws torso and head into g (sx 16) with the torso's bottom at z0 and its
-- middle at y = cy (10 in the body grid).
local function torso(g, plan, z0, cy)
  local cx = 8
  cy = cy or 10
  local rx, ry, rz = plan.rx, plan.ry, plan.rz
  local zc = z0 + rz
  local r = mvl.rng(plan.seed + 7)
  if plan.legless then
    g:sphere(cx, cy + 4, z0 + 2.2, 2.4, 2)
    g:sphere(cx, cy + 5.5, z0 + 2.8, 1.5, 3)
  else
    g:ellipsoid(cx, cy, zc, rx, ry, rz, 2)
    g:ellipsoid(cx, cy, zc - rz * 0.45, rx * 0.85, ry * 0.85, rz * 0.55, 3)
  end
  local cov = plan.covering
  if not plan.legless then
    if cov == "fur" then
      for _ = 1, plan.flecks do g:sphere(cx + (r:next() - 0.5) * rx, cy + (r:next() - 0.5) * ry * 1.6, zc + rz * 0.8, 1, 1) end
    elseif cov == "scales" then
      g:line(cx, cy - ry + 1, zc + rz - 0.5, cx, cy + ry - 1, zc + rz - 0.5, 0.6, 1)
    elseif cov == "feathers" then
      g:ellipsoid(cx, cy - 1, zc + rz * 0.4, rx * 0.9, ry * 0.9, rz * 0.6, 1)
    elseif cov == "chitin" then
      for y = cy - ry + 2, cy + ry - 2, 3 do g:ellipsoid(cx, y, zc, rx + 0.3, 0.6, rz + 0.3, 1) end
    elseif cov == "shell" then
      g:ellipsoid(cx, cy, zc + rz * 0.3, rx + 1, ry + 0.5, rz, 1)
    elseif cov == "plates" then
      for y = cy - ry + 2, cy + ry - 2, 2 do g:box(cx, y, math.floor(zc + rz), cx, y, math.floor(zc + rz + 1), 1) end
    end
  end
  -- head, snout and eyes at the front (+y)
  local hy, hz = cy + ry + plan.head * 0.6, zc + rz * 0.4
  if plan.legless then hy, hz = cy + 6, z0 + 2.6 end
  local hr = plan.legless and 1.8 or plan.head
  g:sphere(cx, hy, hz, hr, 2)
  if plan.snout > 0.6 and not plan.legless then g:ellipsoid(cx, hy + hr, hz - 0.5, hr * 0.5, plan.snout, hr * 0.4, 3) end
  local n = math.min(plan.eyes, 8)
  for k = 1, n do
    local side = k % 2 == 1 and 1 or -1
    local row = math.floor((k - 1) / 2)
    local ex, ey, ez = cx + side * hr * 0.55, hy + hr * 0.7, hz + hr * 0.3 + row * 0.9
    g:set(math.floor(ex + 0.5), math.floor(ey + 0.5), math.floor(ez + 0.5), 4)
  end
  if cov == "chitin" then -- feelers
    g:line(cx - 1, hy + 1, hz + 1, cx - 2, hy + 4, hz + 4, 0.5, 1)
    g:line(cx + 1, hy + 1, hz + 1, cx + 2, hy + 4, hz + 4, 0.5, 1)
  end
  local names = {}
  for name in pairs(CR.PARTS) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do CR.PARTS[name](g, plan, z0, cy) end
  return hy, hz
end

-- Hip positions (voxels, relative to the body grid) of each leg pair.
function CR.hips(plan)
  local out = {}
  local n = plan.pairs
  if n == 0 then return out end
  for k = 1, n do
    local y = n == 1 and 10 or (10 - plan.ry + 2) + (k - 1) * ((plan.ry * 2 - 4) / (n - 1))
    out[k] = { x = plan.rx * 0.75, y = y, z = plan.rz * 0.6 }
  end
  return out
end

local function leg(plan)
  local g = mvl.voxels(3, 3, plan.leg + 2)
  palette(g, plan.colors)
  g:line(1, 1, 0, 1, 1, plan.leg, 0.6, 1)
  g:set(1, 2, plan.leg, 1)
  return g
end

local function wing(plan)
  local sx = math.min(2 * plan.span + 2, 32)
  local g = mvl.voxels(sx, 10, 2)
  palette(g, plan.colors)
  local c = sx / 2
  for x = 0, plan.span - 1 do
    local chord = math.max(1, math.floor(8 * (1 - x / plan.span) + 0.5))
    g:box(math.floor(c + x), 5 - math.floor(chord / 2), 0, math.floor(c + x), 5 + math.floor((chord - 1) / 2), 0,
          x % 3 == 2 and 1 or 3)
  end
  return g
end

local function tail(plan)
  local g = mvl.voxels(4, 20, 6)
  palette(g, plan.colors)
  g:line(2, 10, 1, 2, 2, 3, 0.9, 2)
  g:sphere(2, 2, 3, 1, 1)
  return g
end

local function segment(plan)
  local g = mvl.voxels(6, 6, 5)
  palette(g, plan.colors)
  g:sphere(3, 3, 2.2, 2.3, 2)
  g:ellipsoid(3, 3, 3.6, 1.6, 1.6, 0.8, 1)
  g:set(2, 3, 0, 1)
  g:set(4, 3, 0, 1)
  return g
end

-- Builds every mesh of a creature. Returns {plan, body, leg, wing, tail,
-- seg, merged, hash, count} (meshes are resource ids, 0 when absent).
function CR.build(p)
  local plan = CR.plan(p)
  local s = plan.s
  local out = { plan = plan, count = 0 }
  local function keep(g)
    local m = g:mesh(s)
    g:free()
    if m > 0 then out.count = out.count + 1 end
    return m
  end
  local body = mvl.voxels(16, 24, 16)
  palette(body, plan.colors)
  torso(body, plan, 0)
  out.hash = body:hash()
  out.body = keep(body)
  out.leg = plan.pairs > 0 and keep(leg(plan)) or 0
  out.wing = plan.wings and keep(wing(plan)) or 0
  out.tail = plan.tail and keep(tail(plan)) or 0
  out.seg = plan.legless and keep(segment(plan)) or 0
  -- the resting pose in one mesh, standing on its feet
  local merged = mvl.voxels(16, 32, 30)
  palette(merged, plan.colors)
  local z0, cy = plan.leg, 14
  for _, h in ipairs(CR.hips(plan)) do
    for side = -1, 1, 2 do merged:line(8 + side * h.x, h.y + 4, 0, 8 + side * h.x, h.y + 4, z0 + h.z, 0.6, 1) end
  end
  torso(merged, plan, z0, cy)
  if plan.tail then merged:line(8, cy - plan.ry, z0 + plan.rz, 8, cy - plan.ry - 7, z0 + plan.rz + 2, 0.9, 2) end
  if plan.wings then
    merged:box(8 - math.min(plan.span, 7), 9, math.floor(z0 + plan.rz * 1.6), 8 + math.min(plan.span, 7), 12,
               math.floor(z0 + plan.rz * 1.6), 3)
  end
  if plan.legless then
    for k = 1, plan.segments do merged:sphere(8, cy + 3 - k * 2.6, 2.2, 2.2, k % 2 == 0 and 1 or 2) end
  end
  out.merged = keep(merged)
  return out
end

-- Releases the meshes of a built creature.
function CR.release(m)
  for _, k in ipairs({ "body", "leg", "wing", "tail", "seg", "merged" }) do
    if m[k] and m[k] > 0 then mvl.release_mesh(m[k]) end
  end
end

return CR
