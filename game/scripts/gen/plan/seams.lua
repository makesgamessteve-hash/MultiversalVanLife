-- Multiversal Van Life - seams of the surface grid (MIT).
--
-- The ground, rivers and lakes must continue across land, region and face
-- borders. These checks generate the lands on both sides of a border and
-- compare their ground along it (land.raw_height, as the engine builds it)
-- and the rivers the two regions give near it. Used by the statistics tool
-- over 200 seeds (tests/stats_thresholds.ini) and by tests.
local grid = require("gen.plan.grid")

local seams = { STEP = 64 }

local function lands(G, paddr, g, f1, x1, z1, f2, x2, z2)
  local a = G:generate(grid.address(paddr, g, f1, x1, z1))
  local b = G:generate(grid.address(paddr, g, f2, x2, z2))
  return a, b
end

-- Largest difference of the ground of lands a and b along a border: from
-- (ax, az) to (ax + dx * 2048, az + dz * 2048) in a's world coordinates,
-- and the same points from (bx, bz) in b's.
local function along(a, b, ax, az, bx, bz, dx, dz)
  local L = require("gen.levels.land")
  local worst = 0
  for k = 0, grid.LAND, seams.STEP do
    local ha = L.raw_height(a.data.terrain, ax + dx * k, az + dz * k)
    local hb = L.raw_height(b.data.terrain, bx + dx * k, bz + dz * k)
    worst = math.max(worst, math.abs(ha - hb))
  end
  return worst
end

-- Rivers near the border x = bx of two regions (face world coordinates):
-- the number of points one region gives that the other does not.
local function rivers_mismatch(ra, rb, bx)
  local function set(r)
    local out = {}
    for _, river in ipairs(r.data.rivers) do
      for _, p in ipairs(river.points) do
        if math.abs(p[1] - bx) < 2500 then out[string.format("%.2f,%.2f,%.2f", p[1], p[2], p[3])] = true end
      end
    end
    return out
  end
  local sa, sb, n = set(ra), set(rb), 0
  for k in pairs(sa) do if not sb[k] then n = n + 1 end end
  for k in pairs(sb) do if not sa[k] then n = n + 1 end end
  return n
end

-- Seams of a planet node: { region = m, face = m, pole = m, river_points = n }
-- (largest ground differences in metres along a region border near the
-- first country's capital, along the edge between faces 0 and 1 at the
-- equator and between faces 0 and 4; river points one side lacks).
function seams.planet(G, planet)
  local P = planet.data
  if not (P.cells and P.cells.filled) then return nil end
  local region = require("gen.levels.region")
  local g = region.info(P).g
  local paddr = planet.address
  local out = {}
  -- a region border: the capital's land and the next region to the east
  local cap = P.countries and P.countries[1] and P.countries[1].capital or 1
  local x, y, z = mvl.planet_cell(P.grid, cap)
  local loc = grid.locate(paddr, g, x, y, z)
  local gxb = (loc.gx // grid.LANDS + 1) * grid.LANDS
  if gxb >= g.N * grid.LANDS then gxb = gxb - grid.LANDS end
  local a, b = lands(G, paddr, g, loc.face, gxb - 1, loc.gz, loc.face, gxb, loc.gz)
  local ex = b.data.center[1] - grid.LAND / 2
  local ez = b.data.center[2] - grid.LAND / 2
  out.region = along(a, b, ex, ez, ex, ez, 0, 1)
  out.river_points = rivers_mismatch(G:generate(a.data.region), G:generate(b.data.region), ex)
  -- the edge between faces 0 and 1 (same row, x = H on face 0 meets x = -H on face 1)
  local n = g.N * grid.LANDS
  local row = n // 2
  a, b = lands(G, paddr, g, 0, n - 1, row, 1, 0, row)
  local z0 = a.data.center[2] - grid.LAND / 2
  out.face = along(a, b, g.H, z0, -g.H, z0, 0, 1)
  -- the edge between faces 0 and 4 (z = -H on face 0 meets z = H on face 4, same x)
  local col = n // 2
  a, b = lands(G, paddr, g, 0, col, 0, 4, col, n - 1)
  local x0 = a.data.center[1] - grid.LAND / 2
  out.pole = along(a, b, x0, -g.H, x0, g.H, 1, 0)
  return out
end

return seams
