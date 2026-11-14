-- Multiversal Van Life - voxel plants from branch grammars (MIT).
--
-- Each plant lineage has a grammar (from its seed): how far up the trunk
-- branches, at what angle, how many times it splits and how deep, how much
-- it leans and how wide its crown grows. A species evaluates its lineage's
-- grammar for its form (tree, shrub, herb, fungus) and leaf (broad crowns,
-- needle tiers, drooping fronds, grass blades, caps, crystal shards) into a
-- voxel grid of at most 24 x 24 x 32 cells, coloured from its palette.
-- Grids are Z-up; the mesh stands on its base, centred.
local dm = require("gen.dmath")
local PL = { W = 24, H = 32 }
local cos, sin = dm.cos, dm.sin

local BARK = {
  ["carbon-water"] = { { 58, 40, 26 }, { 92, 66, 42 } }, ["carbon-ammonia"] = { { 70, 76, 84 }, { 110, 116, 124 } },
  ["silicon-sulphur"] = { { 120, 110, 80 }, { 170, 160, 120 } }, arcane = { { 60, 40, 80 }, { 110, 80, 140 } },
}

-- The grammar of a lineage.
function PL.grammar(lseed)
  local r = mvl.rng(lseed)
  return {
    angle = 0.45 + r:next() * 0.55,  -- radians from the parent branch
    splits = r:int(2, 3),
    depth = r:int(2, 3),
    trunk = 0.4 + r:next() * 0.25,   -- share of the height that is bare trunk
    lean = (r:next() - 0.5) * 0.5,
    crown = 0.8 + r:next() * 0.6,    -- size of leaf clusters
    shrink = 0.62 + r:next() * 0.15, -- branch length ratio per level
  }
end

local function color(g, i, c) g:color(i, c[1], c[2], c[3]) end

-- Recursive branches from (x, y, z) along (dx, dy, dz) for `len` cells.
local function branch(g, r, gr, x, y, z, dx, dy, dz, len, depth, rad, tips)
  local ex, ey, ez = x + dx * len, y + dy * len, z + dz * len
  g:line(x, y, z, ex, ey, ez, rad, 2)
  if depth == 0 then
    tips[#tips + 1] = { ex, ey, ez }
    return
  end
  local az0 = r:next() * 6.283
  for k = 1, gr.splits do
    local az = az0 + k * 6.283 / gr.splits
    local a = gr.angle * (0.8 + r:next() * 0.4)
    -- tilt the direction away from the parent by `a` towards azimuth az
    local nx = dx * cos(a) + cos(az) * sin(a)
    local ny = dy * cos(a) + sin(az) * sin(a)
    local nz = dz * cos(a) + 0.25 * sin(a)
    local l = math.sqrt(nx * nx + ny * ny + nz * nz)
    branch(g, r, gr, ex, ey, ez, nx / l, ny / l, nz / l, len * gr.shrink, depth - 1, math.max(0.5, rad * 0.7), tips)
  end
end

local function blob(g, x, y, z, rad)
  g:ellipsoid(x, y, z, rad, rad, rad * 0.8, 3)
  g:ellipsoid(x - rad * 0.2, y - rad * 0.2, z + rad * 0.25, rad * 0.75, rad * 0.75, rad * 0.6, 4)
  g:ellipsoid(x - rad * 0.35, y - rad * 0.3, z + rad * 0.5, rad * 0.4, rad * 0.4, rad * 0.3, 5)
end

-- Builds the grid of a plant model: p = {form, leaf, colors, chemistry,
-- seed, lseed}. Returns the grid (the caller meshes and frees it).
function PL.build(p)
  local W, H = PL.W, PL.H
  local g = mvl.voxels(W, W, H)
  local r = mvl.rng(p.seed)
  local gr = PL.grammar(p.lseed)
  local bark = BARK[p.chemistry] or BARK["carbon-water"]
  color(g, 1, bark[1])
  color(g, 2, bark[2])
  color(g, 3, p.colors[1])
  color(g, 4, p.colors[2])
  color(g, 5, p.colors[3])
  color(g, 6, { math.min(255, p.colors[3][1] + 60), math.min(255, p.colors[3][2] + 40), math.min(255, p.colors[3][3] + 70) })
  local c = W / 2
  local form, leaf = p.form, p.leaf
  if form == "fungus" then
    local n = r:int(1, 3)
    for k = 1, n do
      local x, y = c + (r:next() - 0.5) * 10, c + (r:next() - 0.5) * 10
      local h = 6 + r:next() * 14
      g:cylinder(x, y, 0, math.floor(h), 1 + r:next(), 2)
      g:ellipsoid(x, y, h, 4 + r:next() * 4, 4 + r:next() * 4, 2 + r:next() * 1.5, 4)
      g:ellipsoid(x, y, h + 1, 3, 3, 1.2, 5)
      for _ = 1, 4 do g:set(math.floor(x + (r:next() - 0.5) * 6), math.floor(y + (r:next() - 0.5) * 6), math.floor(h + 2), 6) end
    end
  elseif leaf == "shard" then
    local n = form == "tree" and r:int(4, 6) or r:int(3, 5)
    for k = 1, n do
      local a = r:next() * 6.283
      local tilt = k == 1 and 0 or 0.15 + r:next() * 0.35
      local len = (form == "tree" and H - 2 or H * 0.6) * (k == 1 and 1 or 0.5 + r:next() * 0.4)
      local x1, y1 = c + cos(a) * sin(tilt) * len, c + sin(a) * sin(tilt) * len
      g:line(c, c, 0, x1, y1, cos(tilt) * len, 1.6 - k * 0.12, k % 2 == 0 and 4 or 5)
      g:line(c, c, 0, x1, y1, cos(tilt) * len, 0.6, 6)
    end
  elseif form == "tree" and leaf == "needle" then
    local trunk = H - 1
    g:line(c, c, 0, c + gr.lean * 4, c, trunk, 1.1, 2)
    local tiers = 4 + r:int(0, 2)
    for k = 0, tiers - 1 do
      local z = H * (0.25 + 0.72 * k / tiers)
      local rad = (W * 0.42) * (1 - k / (tiers + 0.5)) * gr.crown * 0.85
      g:ellipsoid(c + gr.lean * 4 * z / H, c, z, rad, rad, 2.2, k % 2 == 0 and 3 or 4)
      g:ellipsoid(c + gr.lean * 4 * z / H - 0.5, c - 0.5, z + 1, rad * 0.6, rad * 0.6, 1.2, 5)
    end
  elseif form == "tree" and leaf == "frond" then
    local top = H * 0.78
    local mx = c + gr.lean * 8
    g:line(c, c, 0, (c + mx) / 2, c, top / 2, 1.2, 2)
    g:line((c + mx) / 2, c, top / 2, mx, c, top, 1.0, 1)
    local n = 6 + r:int(0, 3)
    for k = 1, n do
      local a = k * 6.283 / n + r:next() * 0.3
      local reach = 7 + r:next() * 4 * gr.crown
      local ex, ey = mx + cos(a) * reach, c + sin(a) * reach
      g:line(mx, c, top, (mx + ex) / 2, (c + ey) / 2, top + 2, 0.8, 4)
      g:line((mx + ex) / 2, (c + ey) / 2, top + 2, ex, ey, top - 3, 0.7, k % 2 == 0 and 3 or 5)
    end
  elseif form == "tree" then
    local trunk = H * gr.trunk
    local tips = {}
    g:line(c, c, 0, c + gr.lean * 3, c, trunk, 1.6, 1)
    branch(g, r, gr, c + gr.lean * 3, c, trunk, gr.lean * 0.3, 0, 1, H * 0.28, gr.depth, 1.2, tips)
    for _, t in ipairs(tips) do blob(g, t[1], t[2], t[3], 2.8 * gr.crown + r:next()) end
  elseif form == "shrub" then
    local n = r:int(3, 5)
    for _ = 1, n do
      local a, d = r:next() * 6.283, 2 + r:next() * 4
      local x1, y1, z1 = c + cos(a) * d, c + sin(a) * d, 6 + r:next() * 8
      g:line(c, c, 0, x1, y1, z1, 0.7, 2)
      blob(g, x1, y1, z1, 3 * gr.crown + r:next() * 1.5)
    end
  else -- herbs: blades and a few flowers
    local n = r:int(10, 18)
    for k = 1, n do
      local x, y = c + (r:next() - 0.5) * 16, c + (r:next() - 0.5) * 16
      local h = 6 + r:next() * 16
      local lx, ly = x + (r:next() - 0.5) * 4, y + (r:next() - 0.5) * 4
      g:line(x, y, 0, lx, ly, h, 0.5, k % 3 == 0 and 5 or (k % 3 == 1 and 4 or 3))
      if k % 4 == 0 then g:sphere(lx, ly, h + 1, 1.3, 6) end
    end
  end
  return g
end

-- The model's mesh and metres per voxel for a plant of height h.
function PL.mesh(p)
  local g = PL.build(p)
  local hash = g:hash()
  local s = math.max(p.height, 0.2) / PL.H
  local mesh = g:mesh(s)
  g:free()
  return mesh, hash
end

return PL
