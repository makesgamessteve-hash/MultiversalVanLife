-- Multiversal Van Life - the planet-wide surface grid (MIT).
--
-- Every point of a planet's surface lies in exactly one region of a grid
-- on a cube sphere: the six faces of a cube blown up onto the sphere, each
-- cut into N x N square regions of 32 km with N chosen from the planet's
-- radius, and each region into the 16 x 16 lands of 2 km the game streams.
--
--   region R = face x N^2 + row x N + column      land L = 16 x row + column
--   address  planet.rR.lL
--
-- Positions on a face use equal-angle coordinates in metres: s (east, along
-- the face's u axis) and t (north, along v), both in [-H, H] with
-- H = N x 16384, so that a step of a metre is close to a metre on the
-- ground everywhere on the face. The game's world coordinates on a face are
-- x = s and z = -t (z grows southwards, as in every land); a face's lands
-- tile them on a 2048 m grid: land (GX, GZ) of the face covers
-- x in [-H + GX x 2048, -H + (GX + 1) x 2048) and likewise z.
local dm = require("gen.dmath")

local grid = { REGION = 32768, LAND = 2048, LANDS = 16, EARTH = 6371000 }

-- Faces: normal n, east u and north v (unit vectors). The four side faces
-- follow the equator eastwards with v towards the north pole.
grid.FACES = {
  [0] = { n = { 1, 0, 0 }, u = { 0, 0, 1 }, v = { 0, 1, 0 } },
  [1] = { n = { 0, 0, 1 }, u = { -1, 0, 0 }, v = { 0, 1, 0 } },
  [2] = { n = { -1, 0, 0 }, u = { 0, 0, -1 }, v = { 0, 1, 0 } },
  [3] = { n = { 0, 0, -1 }, u = { 1, 0, 0 }, v = { 0, 1, 0 } },
  [4] = { n = { 0, 1, 0 }, u = { 0, 0, 1 }, v = { -1, 0, 0 } },
  [5] = { n = { 0, -1, 0 }, u = { 0, 0, 1 }, v = { 1, 0, 0 } },
}

local function dot(a, x, y, z) return a[1] * x + a[2] * y + a[3] * z end
local function tan(a) return dm.sin(a) / dm.cos(a) end

-- The grid of a planet (its data): N, the half width H of a face in metres
-- and the equal-angle radius K (metres per radian).
function grid.of(P)
  local R = (P.radius or 1) * grid.EARTH
  local N = math.max(1, math.floor(R * dm.pi / 2 / grid.REGION + 0.5))
  return { N = N, H = N * grid.REGION / 2, K = N * grid.REGION / (dm.pi / 2), radius = R, regions = 6 * N * N }
end

-- The face a direction lies on.
function grid.face_of(x, y, z)
  local ax, ay, az = math.abs(x), math.abs(y), math.abs(z)
  if ax >= ay and ax >= az then return x >= 0 and 0 or 2 end
  if az >= ay then return z >= 0 and 1 or 3 end
  return y >= 0 and 4 or 5
end

-- Face coordinates (s, t) of a direction on face f (also beyond the face,
-- for directions less than 90 degrees from its centre).
function grid.to_face(g, f, x, y, z)
  local F = grid.FACES[f]
  local dn = dot(F.n, x, y, z)
  return dm.atan(dot(F.u, x, y, z), dn) * g.K, dm.atan(dot(F.v, x, y, z), dn) * g.K
end

-- The unit direction of face coordinates (s, t) on face f.
function grid.to_sphere(g, f, s, t)
  local F = grid.FACES[f]
  local a, b = tan(s / g.K), tan(t / g.K)
  local x = F.n[1] + a * F.u[1] + b * F.v[1]
  local y = F.n[2] + a * F.u[2] + b * F.v[2]
  local z = F.n[3] + a * F.u[3] + b * F.v[3]
  local l = math.sqrt(x * x + y * y + z * z)
  return x / l, y / l, z / l
end

-- The face land (GX, GZ) containing world position (x, z) of a face.
function grid.land_xy(g, x, z)
  return math.floor((x + g.H) / grid.LAND), math.floor((z + g.H) / grid.LAND)
end

-- World position of the centre of face land (GX, GZ).
function grid.land_centre(g, gx, gz)
  return (gx + 0.5) * grid.LAND - g.H, (gz + 0.5) * grid.LAND - g.H
end

-- Is face land (GX, GZ) on the face?
function grid.on_face(g, gx, gz)
  local n = g.N * grid.LANDS
  return gx >= 0 and gz >= 0 and gx < n and gz < n
end

-- Region index and land index of face land (GX, GZ) of face f.
function grid.indices(g, f, gx, gz)
  local L = grid.LANDS
  return f * g.N * g.N + (gz // L) * g.N + gx // L, (gz % L) * L + gx % L
end

-- Face, row and column of region R.
function grid.region(g, R)
  local per = g.N * g.N
  return R // per, (R % per) // g.N, R % g.N
end

-- Face land (GX, GZ) of land L of region R, and the face.
function grid.land_of(g, R, L)
  local f, row, col = grid.region(g, R)
  return f, col * grid.LANDS + L % grid.LANDS, row * grid.LANDS + L // grid.LANDS
end

-- The address of face land (GX, GZ) of face f below a planet.
function grid.address(planet_addr, g, f, gx, gz)
  local R, L = grid.indices(g, f, gx, gz)
  return planet_addr .. ".r" .. R .. ".l" .. L
end

-- Where a direction lies: face, face land and the address of its land.
function grid.locate(planet_addr, g, x, y, z)
  local f = grid.face_of(x, y, z)
  local s, t = grid.to_face(g, f, x, y, z)
  local gx, gz = grid.land_xy(g, s, -t)
  local n = g.N * grid.LANDS - 1
  gx, gz = dm.clamp(gx, 0, n), dm.clamp(gz, 0, n) -- on the far edge of a face
  return { face = f, gx = gx, gz = gz, address = grid.address(planet_addr, g, f, gx, gz) }
end

-- The direction of a land's centre.
function grid.land_direction(g, f, gx, gz)
  local x, z = grid.land_centre(g, gx, gz)
  return grid.to_sphere(g, f, x, -z)
end

-- Latitude and longitude in degrees of a direction (as gen/plan/query.lua).
function grid.latlon(x, y, z)
  local l = math.sqrt(x * x + y * y + z * z)
  return dm.atan(y / l, math.sqrt(x * x + z * z) / l) * 180 / dm.pi, dm.atan(z, x) * 180 / dm.pi
end

-- The direction of a latitude and longitude in degrees.
function grid.direction(lat, lon)
  local la, lo = lat * dm.pi / 180, lon * dm.pi / 180
  local c = dm.cos(la)
  return c * dm.cos(lo), dm.sin(la), c * dm.sin(lo)
end

-- Distance in metres from world position (x, z) to the nearest edge of its
-- face (negative outside the face).
function grid.edge_distance(g, x, z)
  return g.H - math.max(math.abs(x), math.abs(z))
end

return grid
