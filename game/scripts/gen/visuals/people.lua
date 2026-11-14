-- Multiversal Van Life - voxel people and statues (MIT).
--
-- An intelligent species stands upright on its legs: two legs with arms for
-- its hands, or four legs under an upright torso (taurs) when its body has
-- more limbs than hands; wings fold on its back, a tail hangs behind, its
-- eyes and mouth (beak, mandibles or lips) are on the front of its head,
-- and its colours come from its lineage. It wears its culture's dress
-- (robe, tunic, wrap, furs or harness, with a trim) and, where hierarchy is
-- high, a headdress (a sash for collectives). A statue is the same body in
-- the colours of stone on a plinth, with the attributes it is remembered
-- by (staff, crown, book, sword, halo). Grids are 16 x 12 x 40 voxels, Z
-- up, facing +y (the world's -z when unturned).
local dm = require("gen.dmath")

local P = { W = 16, D = 12, H = 40 }

local function hsv(h, s, v)
  local c = v * s
  local x = c * (1 - math.abs((h / 60) % 2 - 1))
  local r, g, b
  if h < 60 then r, g, b = c, x, 0 elseif h < 120 then r, g, b = x, c, 0 elseif h < 180 then r, g, b = 0, c, x
  elseif h < 240 then r, g, b = 0, x, c elseif h < 300 then r, g, b = x, 0, c else r, g, b = c, 0, x end
  local m = v - c
  return { math.floor((r + m) * 255), math.floor((g + m) * 255), math.floor((b + m) * 255) }
end
local function shade(c, k) return { math.floor(dm.clamp(c[1] * k, 0, 255)), math.floor(dm.clamp(c[2] * k, 0, 255)),
                                    math.floor(dm.clamp(c[3] * k, 0, 255)) } end
local function color(g, i, c) g:color(i, c[1], c[2], c[3]) end

-- Palette: 1-3 body (dark to light), 4 dress, 5 trim, 6 accent, 7 eyes.
local function palette(g, q)
  if q.statue then
    local s = q.stone or { { 110, 104, 96 }, { 150, 144, 134 }, { 190, 184, 172 } }
    for i = 1, 6 do color(g, i, s[(i - 1) % 3 + 1]) end
    color(g, 7, s[1])
    return
  end
  local body = hsv((q.hue or 30) % 360, 0.35, 0.62)
  color(g, 1, shade(body, 0.6))
  color(g, 2, body)
  color(g, 3, shade(body, 1.3))
  color(g, 4, q.dress and q.dress.color or { 120, 90, 60 })
  color(g, 5, q.dress and q.dress.trim or { 220, 200, 150 })
  color(g, 6, q.accent or { 210, 170, 70 })
  color(g, 7, { 18, 16, 20 })
end

-- The proportions of a person of anatomy a.
function P.plan(a)
  local limbs, hands = a.limbs or 4, a.hands or 2
  local legs = limbs - hands
  local taur = legs >= 4
  return { taur = taur, legs = taur and 4 or 2, arms = limbs >= 4 and math.max(1, math.floor(hands / 2)) or 0,
           wings = a.wings, tail = a.tail, eyes = math.min(a.eyes or 2, 6), mouth = a.mouth or "lips",
           width = dm.clamp(math.floor(5 + (a.build or 1) * 1.5), 5, 8), covering = a.covering }
end

local function body(g, pl, z0)
  local cx = 8
  local hw = math.floor(pl.width / 2)
  local legs_top = z0 + (pl.taur and 6 or 11)
  -- legs
  if pl.taur then
    g:box(cx - hw, 2, z0 + 6, cx + hw - 1, 10, z0 + 11, 2) -- the beast body
    for _, x in ipairs({ cx - hw, cx + hw - 2 }) do
      for _, y in ipairs({ 3, 8 }) do g:box(x, y, z0, x + 1, y + 1, z0 + 5, 1) end
    end
  else
    g:box(cx - 2, 5, z0, cx - 1, 6, legs_top, 1)
    g:box(cx + 1, 5, z0, cx + 2, 6, legs_top, 1)
  end
  -- torso
  local t0, t1 = z0 + 12, z0 + 22
  local ty0, ty1 = pl.taur and 7 or 4, pl.taur and 10 or 7
  g:box(cx - hw, ty0, t0, cx + hw - 1, ty1, t1, 2)
  g:box(cx - hw + 1, ty1, t0 + 1, cx + hw - 2, ty1, t1 - 2, 3) -- chest
  -- arms in pairs
  for k = 1, pl.arms do
    local z = t1 - 1 - (k - 1) * 4
    g:box(cx - hw - 2, ty0 + 1, z - 6, cx - hw - 1, ty0 + 2, z, 2)
    g:box(cx + hw, ty0 + 1, z - 6, cx + hw + 1, ty0 + 2, z, 2)
  end
  -- head, eyes and mouth
  local hy, hz = pl.taur and 8 or 5, t1 + 4
  g:sphere(cx, hy, hz, 3.5, 2)
  for k = 1, pl.eyes do
    local side = k % 2 == 1 and -1 or 1
    local row = math.floor((k - 1) / 2)
    g:set(math.floor(cx + side * 1.5 + (side > 0 and 0 or 0.5)), math.floor(hy + 3.3), math.floor(hz + 1 - row), 7)
  end
  if pl.mouth == "beak" then
    g:box(cx - 1, math.floor(hy + 3), math.floor(hz - 1), cx, math.floor(hy + 5), math.floor(hz - 1), 6)
  elseif pl.mouth == "mandibles" then
    g:set(cx - 2, math.floor(hy + 3), math.floor(hz - 2), 1)
    g:set(cx + 1, math.floor(hy + 3), math.floor(hz - 2), 1)
  end
  -- wings folded on the back, a tail behind
  if pl.wings then
    g:box(cx - hw - 1, ty0 - 1, t0 - 4, cx - 1, ty0 - 1, t1 + 1, 3)
    g:box(cx, ty0 - 1, t0 - 4, cx + hw, ty0 - 1, t1 + 1, 3)
  end
  if pl.tail then g:line(cx, ty0, t0, cx, 0, z0 + 3, 0.8, 1) end
  return { t0 = t0, t1 = t1, hz = hz, hy = hy, ty0 = ty0, ty1 = ty1, legs_top = legs_top }
end

local function dress(g, pl, d, z0, b)
  if not d then return end
  local cx, hw = 8, math.floor(pl.width / 2)
  local g0 = d.garment
  if g0 == "robe" then
    g:box(cx - hw - 1, b.ty0 - 1, z0 + 2, cx + hw, b.ty1 + 1, b.t1 - 1, 4)
    g:box(cx - hw - 1, b.ty0 - 1, z0 + 2, cx + hw, b.ty1 + 1, z0 + 2, 5)
  elseif g0 == "tunic" then
    g:box(cx - hw, b.ty0 - 1, b.t0 - 3, cx + hw - 1, b.ty1 + 1, b.t1 - 1, 4)
    g:box(cx - hw, b.ty0 - 1, b.t0 - 3, cx + hw - 1, b.ty1 + 1, b.t0 - 3, 5)
  elseif g0 == "wrap" then
    g:box(cx - hw, b.ty0 - 1, b.t0 + 2, cx + hw - 1, b.ty1 + 1, b.t0 + 6, 4)
    g:line(cx - hw, b.ty1 + 1, b.t0 + 6, cx + hw - 1, b.ty1 + 1, b.t1, 0.6, 5)
  elseif g0 == "furs" then
    g:box(cx - hw - 1, b.ty0 - 1, b.t0 - 2, cx + hw, b.ty1 + 1, b.t1, 4)
    g:box(cx - hw - 1, b.ty0 - 1, b.t1, cx + hw, b.ty1 + 1, b.t1 + 1, 5)
  else -- harness: crossed straps and a belt
    g:line(cx - hw, b.ty1 + 1, b.t0, cx + hw - 1, b.ty1 + 1, b.t1, 0.5, 4)
    g:line(cx + hw - 1, b.ty1 + 1, b.t0, cx - hw, b.ty1 + 1, b.t1, 0.5, 4)
    g:box(cx - hw, b.ty0 - 1, b.t0, cx + hw - 1, b.ty1 + 1, b.t0, 5)
  end
  if d.status == "headdress" then
    g:box(cx - 2, math.floor(b.hy) - 1, math.floor(b.hz + 3), cx + 1, math.floor(b.hy) + 1, math.floor(b.hz + 6), 6)
  elseif d.status == "sash" then
    g:line(cx - hw, b.ty1 + 1, b.t1, cx + hw - 1, b.ty1 + 1, b.t0, 0.7, 6)
  end
end

P.ATTRIBUTES = {
  staff = function(g, b) g:line(13, b.ty1 + 1, 4, 13, b.ty1 + 1, b.hz + 5, 0.6, 5) end,
  crown = function(g, b) g:cylinder(8, b.hy, math.floor(b.hz + 3), math.floor(b.hz + 5), 3, 6) end,
  book = function(g, b) g:box(2, b.ty1 + 1, b.t0, 4, b.ty1 + 2, b.t0 + 3, 4) end,
  sword = function(g, b) g:line(13, b.ty1 + 2, b.t0 - 6, 13, b.ty1 + 2, b.t1, 0.5, 6) end,
  halo = function(g, b)
    for k = 0, 11 do
      local a = k * dm.pi / 6
      g:set(math.floor(8 + dm.cos(a) * 4), math.floor(b.hy - 2), math.floor(b.hz + 5 + dm.sin(a) * 2), 6)
    end
  end,
}

-- The grid of a person q = {anatomy, hue, dress, accent, seed} or of a
-- statue q = {anatomy, hue, statue = true, stone, attributes}.
function P.build(q)
  local g = mvl.voxels(P.W, P.D, P.H)
  palette(g, q)
  local pl = P.plan(q.anatomy)
  local z0 = q.statue and 4 or 0
  if q.statue then g:box(1, 0, 0, 14, 11, 3, 1) end -- the plinth
  local b = body(g, pl, z0)
  if not q.statue then dress(g, pl, q.dress, z0, b) end
  for _, name in ipairs(q.attributes or {}) do
    local fn = P.ATTRIBUTES[name]
    if fn then fn(g, b) end
  end
  return g, pl
end

-- Mesh and grid hash: the figure is `height` metres tall (a statue twice
-- its subject's height).
function P.mesh(q)
  local g = P.build(q)
  local hash = g:hash()
  local h = (q.anatomy.height or 1.7) * (q.statue and 2 or 1)
  local mesh = g:mesh(h / (q.statue and 34 or 30))
  g:free()
  return mesh, hash
end

return P
