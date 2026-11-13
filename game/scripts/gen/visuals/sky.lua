-- Multiversal Van Life - planet skies (MIT).
--
-- The planet pass `sky` stores what a planet's sky holds: its star's colour
-- and apparent size, the colours of its air by day and night with the haze
-- and fog they bring, its moons (sizes, orbits, colours), its sister
-- planets and the band of its galaxy. Positions are not stored: `sky.at`
-- works out where everything stands for a place and a time (days), in the
-- local frame of a land (x east, y up, -z north), and `sky.view` turns that
-- into the settings for mvl.environment and mvl.sky.
--
-- The model: everything is placed on the celestial sphere of the planet
-- (z towards its north pole) and turned with the planet's rotation. The
-- star moves along the ecliptic (tilted by the axial tilt) once a year,
-- moons along their orbits; a tidally locked world turns once a year, so
-- its star stands still. Phases follow from where a moon stands relative
-- to the star; the sky shader lights each moon from the star's direction.
local dm = require("gen.dmath")
local prime = require("gen.prime")

local sky = { STAR_SCALE = 4, MOON_SCALE = 10 }
local TAU = 2 * dm.pi
local RAD = dm.pi / 180

local function asin(x) return dm.atan(x, math.sqrt(math.max(0, 1 - x * x))) end
local function norm(x, y, z)
  local l = math.sqrt(x * x + y * y + z * z)
  if l < 1e-9 then return 0, 1, 0 end
  return x / l, y / l, z / l
end
local function r3(v) return { dm.round(v[1], 4), dm.round(v[2], 4), dm.round(v[3], 4) } end
local function scale(c, k) return { c[1] * k, c[2] * k, c[3] * k } end
local function mix(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t } end
local function round3(c) return { dm.round(c[1], 3), dm.round(c[2], 3), dm.round(c[3], 3) } end
local function smooth(e0, e1, x)
  local t = dm.clamp((x - e0) / (e1 - e0), 0, 1)
  return t * t * (3 - 2 * t)
end

-- Star colours by spectral class (the light planets use).
sky.STAR_COLOR = {
  O = { 0.62, 0.72, 1.0 }, B = { 0.72, 0.8, 1.0 }, A = { 0.85, 0.88, 1.0 }, F = { 1.0, 0.97, 0.9 },
  G = { 1.0, 0.93, 0.8 }, K = { 1.0, 0.8, 0.6 }, M = { 1.0, 0.6, 0.42 },
}
sky.PLANET_COLOR = {
  rocky = { 0.95, 0.85, 0.72 }, dwarf = { 0.8, 0.8, 0.78 }, gas_giant = { 1.0, 0.9, 0.72 },
  ice_giant = { 0.72, 0.86, 1.0 },
}
sky.MOON_COLORS = {
  { 0.85, 0.85, 0.82 }, { 0.9, 0.76, 0.56 }, { 0.84, 0.9, 1.0 }, { 0.86, 0.56, 0.44 }, { 0.92, 0.86, 0.52 },
}

-- Sky colour scattered by each gas (before the star's tint).
sky.GAS_COLOR = {
  nitrogen = { 0.3, 0.55, 1.0 }, oxygen = { 0.3, 0.55, 1.0 }, ["carbon dioxide"] = { 0.85, 0.66, 0.42 },
  methane = { 0.38, 0.76, 0.78 }, sulphur = { 0.92, 0.84, 0.42 },
}

-- ------------------------------------------------------------ atmosphere
-- Colours of the air by day and night, haze and fog distances, from the
-- pressure (bar), the gases and the star's light.
function sky.atmosphere(pressure, gases, light)
  if pressure < 0.01 then
    return { day_top = { 0.01, 0.01, 0.016 }, day_horizon = { 0.03, 0.03, 0.036 },
             night_top = { 0.005, 0.005, 0.01 }, night_horizon = { 0.02, 0.02, 0.03 },
             haze = 0, fog_near = 55, fog_far = 95, day_stars = 0.9 }
  end
  local base = sky.GAS_COLOR[gases[1]] or sky.GAS_COLOR.nitrogen
  local second = sky.GAS_COLOR[gases[2] or ""]
  if second then base = mix(base, second, 0.3) end
  base = { base[1] * light[1], base[2] * light[2], base[3] * light[3] }
  local haze = dm.clamp(dm.log(1 + pressure) / dm.log(60), 0, 1)
  local thin = dm.clamp(pressure / 0.3, 0, 1)                 -- thin air: a darker sky
  local top = scale(base, 0.15 + 0.45 * thin)
  local white = scale(light, 0.92)
  local horizon = mix(scale(base, 0.5 + 0.5 * thin), white, 0.3 + 0.45 * haze)
  top = mix(top, horizon, 0.6 * haze)                         -- haze washes the sky out
  local far = 95 - 50 * haze
  return {
    day_top = round3(top), day_horizon = round3(horizon),
    night_top = round3(mix({ 0.012, 0.016, 0.045 }, scale(base, 0.06), 0.35)),
    night_horizon = round3(mix({ 0.06, 0.07, 0.14 }, scale(horizon, 0.15), 0.4)),
    haze = dm.round(haze, 3), fog_near = dm.round(far * (0.55 - 0.45 * haze), 1), fog_far = dm.round(far, 1),
    day_stars = pressure < 0.05 and 0.6 or 0,
  }
end

-- Apparent radius (radians, enlarged for the eye) of a star of `mass` solar
-- masses seen from `a` AU.
function sky.star_size(mass, a)
  local r_sun = dm.pow(math.max(mass, 0.05), 0.8)
  return dm.round(dm.clamp(0.00465 * r_sun / a * sky.STAR_SCALE, 0.012, 0.1), 4)
end

-- Apparent radius of a moon of radius r (km) at a km.
function sky.moon_size(r, a) return dm.round(dm.clamp(r / a * sky.MOON_SCALE, 0.025, 0.12), 4) end

-- Sidereal period (days) of a moon a km from a planet of `mass` Earth masses.
function sky.moon_period(a, mass)
  local x = a / 384400
  return dm.round(27.3217 * math.sqrt(x * x * x / math.max(mass, 0.001)), 4)
end

-- ------------------------------------------------------- the planet pass
local function band_for(rng, galaxy, cluster)
  -- orientation of the galaxy's plane against the planet's equator
  local z = rng:next() * 2 - 1
  local a = rng:next() * TAU
  local s = math.sqrt(1 - z * z)
  local nx, ny, nz = s * dm.cos(a), s * dm.sin(a), z
  -- a direction in that plane towards the core
  local ux, uy, uz = norm(ny, -nx, 0)
  if math.abs(nz) > 0.99 then ux, uy, uz = 1, 0, 0 end
  local vx, vy, vz = ny * uz - nz * uy, nz * ux - nx * uz, nx * uy - ny * ux
  local b = rng:next() * TAU
  local cx, cy, cz = norm(ux * dm.cos(b) + vx * dm.sin(b), uy * dm.cos(b) + vy * dm.sin(b), uz * dm.cos(b) + vz * dm.sin(b))
  local morph = galaxy and galaxy.morphology or "spiral"
  local strength = ({ spiral = 0.42, barred = 0.42, ring = 0.34, irregular = 0.28, elliptical = 0.16 })[morph] or 0.35
  local width = morph == "elliptical" and 0.6 or (morph == "irregular" and 0.25 or 0.13)
  local inner = 0
  if cluster and galaxy and galaxy.radius then inner = dm.clamp(1 - (cluster.r or 0) / galaxy.radius, 0, 1) end
  return { normal = r3({ nx, ny, nz }), core = r3({ cx, cy, cz }), strength = dm.round(strength * (0.75 + 0.5 * inner), 3),
           width = width, color = morph == "elliptical" and { 0.9, 0.82, 0.7 } or { 0.78, 0.8, 1.0 } }
end

local function generate(ctx)
  local d, s = ctx.data, ctx.summary
  if not d.surface then return end
  local rng = ctx:random("sky")
  local system = ctx.parent.data
  local star = system.star
  local light = d.light or sky.STAR_COLOR[star.class] or sky.STAR_COLOR.G
  local galaxy = ctx:ancestor("galaxy")
  local cluster = ctx:ancestor("cluster")
  local out = {
    star = { color = light, size = sky.star_size(star.mass, s.a), glow = dm.round(0.35 + 0.4 * (1 - d.atmosphere.pressure / (d.atmosphere.pressure + 3)), 3) },
    atmosphere = sky.atmosphere(d.atmosphere.pressure, d.atmosphere.gases, light),
    longitude0 = dm.round(rng:next() * TAU, 4), -- the planet's place on its orbit at time 0
    rotation0 = dm.round(rng:next() * TAU, 4),
    moons = {}, planets = {},
    band = band_for(rng, galaxy and galaxy.data, cluster and cluster.summary),
  }
  for i, m in ipairs(s.moons or {}) do
    if i > 4 then break end
    local r = dm.round(200 + rng:next() * rng:next() * 1800, 1)
    out.moons[i] = { name = m.name, a = m.a, radius = r, period = sky.moon_period(m.a, s.mass),
                     size = sky.moon_size(r, m.a), color = sky.MOON_COLORS[rng:int(1, #sky.MOON_COLORS)],
                     longitude0 = dm.round(rng:next() * TAU, 4), incline = dm.round(rng:next() * 8 * RAD, 4) }
  end
  for i = 0, (system.planets or 0) - 1 do
    local p = ctx.parent.children[i]
    if p and p.name ~= s.name then
      out.planets[#out.planets + 1] = { name = p.name, kind = p.kind, a = p.a, period = p.period,
                                        radius = dm.round(dm.pow(p.mass, p.kind == "gas_giant" and 0.05 or 0.27) *
                                                          (p.kind == "gas_giant" and 11.2 / dm.pow(318, 0.05) or 1), 3),
                                        longitude0 = dm.round(rng:next() * TAU, 4) }
    end
  end
  d.sky = out
end

-- Earth's sky: the Sun, the Moon, the planets and the Milky Way, with
-- J2000 mean longitudes (time in days from 2000-01-01 12:00).
function sky.prime_earth()
  local planets = {}
  local L0 = { Mercury = 252.25, Venus = 181.98, Mars = 355.45, Jupiter = 34.40, Saturn = 49.94, Uranus = 313.23,
               Neptune = 304.88 }
  for _, p in ipairs(prime.planets) do
    if p.name ~= "Earth" then
      planets[#planets + 1] = { name = p.name, kind = p.kind, a = p.a, period = p.period, radius = p.radius,
                                longitude0 = dm.round(L0[p.name] * RAD, 4) }
    end
  end
  return {
    star = { color = sky.STAR_COLOR.G, size = sky.star_size(1, 1), glow = 0.45 },
    atmosphere = sky.atmosphere(1, { "nitrogen", "oxygen" }, { 1, 1, 1 }),
    longitude0 = dm.round(100.46 * RAD, 4), rotation0 = dm.round(280.46 * RAD, 4),
    moons = { { name = "Moon", a = 384400, radius = 1737.4, period = 27.3217, size = sky.moon_size(1737.4, 384400),
                color = { 0.86, 0.86, 0.84 }, longitude0 = dm.round(218.316 * RAD, 4), incline = dm.round(5.145 * RAD, 4) } },
    planets = planets,
    -- the galactic north pole and centre in equatorial coordinates
    band = { normal = { -0.8677, -0.1981, 0.4560 }, core = { -0.0548, -0.8734, -0.4838 }, strength = 0.42, width = 0.13,
             color = { 0.8, 0.82, 1.0 } },
  }
end

-- The farm: latitude, longitude (degrees) and the date the story begins
-- (night 1, 23:00 local time): 24 June 2026, a waxing gibbous Moon.
sky.FARM = { latitude = 45, longitude = 0, start = 9671.4583, hour = 23 }

-- Days since J2000 at 23:00 on the farm on night `n`.
function sky.farm_time(night) return sky.FARM.start + (night - 1) end

-- ------------------------------------------------------------- positions
-- Ecliptic longitude `l` (and latitude b) to the equatorial frame of a
-- planet with obliquity `eps` (z towards its north pole).
local function ecliptic(l, b, eps)
  local cb = dm.cos(b)
  local x, y, z = cb * dm.cos(l), cb * dm.sin(l), dm.sin(b)
  return x, y * dm.cos(eps) - z * dm.sin(eps), y * dm.sin(eps) + z * dm.cos(eps)
end

-- Where things stand in the sky of a place {latitude, longitude} (degrees)
-- on planet data `P` (with P.sky) at time `t` (days).
function sky.at(P, place, t)
  local S = P.sky
  local year = P.year or 365.25
  local eps = (P.tilt or 0) * RAD
  local lat, lon = (place.latitude or 0) * RAD, (place.longitude or 0) * RAD
  -- the planet's place on its orbit and its rotation (a locked world keeps
  -- its face to the star: longitude 0 under it)
  local lp = S.longitude0 + TAU * t / year
  local theta
  if P.locked then theta = lp + dm.pi
  else
    local day = P.day or 1
    theta = S.rotation0 + TAU * t * (1 / day + 1 / year)
  end
  local ct, st = dm.cos(theta), dm.sin(theta)
  local cl, sl, cf, sf = dm.cos(lon), dm.sin(lon), dm.cos(lat), dm.sin(lat)
  -- local frame of the place in planet-fixed coordinates (pole = y)
  local up = { cf * cl, sf, cf * sl }
  local east = { -sl, 0, cl }
  local north = { -sf * cl, cf, -sf * sl }
  local function localize(X, Y, Z)
    -- celestial (X, Y, Z pole) -> planet-fixed (x, pole, z) -> local
    local px, py, pz = X * ct + Y * st, Z, Y * ct - X * st
    local e = px * east[1] + py * east[2] + pz * east[3]
    local u = px * up[1] + py * up[2] + pz * up[3]
    local n = px * north[1] + py * north[2] + pz * north[3]
    return { e, u, -n }
  end
  local out = { moons = {}, planets = {} }
  -- the star, opposite the planet's place on its orbit
  local sx, sy, sz = ecliptic(lp + dm.pi, 0, eps)
  out.sun = localize(sx, sy, sz)
  out.sun_alt = asin(dm.clamp(out.sun[2], -1, 1))
  for i, m in ipairs(S.moons) do
    local lm = m.longitude0 + TAU * t / m.period
    local mx, my, mz = ecliptic(lm, m.incline * dm.sin(lm), eps)
    local dir = localize(mx, my, mz)
    -- illuminated fraction: 1 opposite the star, 0 in front of it
    local c = mx * sx + my * sy + mz * sz
    out.moons[i] = { name = m.name, dir = dir, size = m.size, color = m.color, lit = dm.round((1 - c) / 2, 4),
                     alt = asin(dm.clamp(dir[2], -1, 1)) }
  end
  -- sister planets: seen from here, brighter when near and large
  local ap = P.orbit or 1
  local hx, hy = ap * dm.cos(lp), ap * dm.sin(lp)
  for _, p in ipairs(S.planets) do
    local l = p.longitude0 + TAU * t / (p.period * 365.25)
    local qx, qy = p.a * dm.cos(l) - hx, p.a * dm.sin(l) - hy
    local dist = math.sqrt(qx * qx + qy * qy)
    local bright = p.radius * p.radius / (dist * dist * p.a * p.a + 1e-6)
    local px, py, pz = ecliptic(dm.atan(qy, qx), 0, eps)
    out.planets[#out.planets + 1] = { name = p.name, dir = localize(px, py, pz), bright = bright,
                                      color = sky.PLANET_COLOR[p.kind] or sky.PLANET_COLOR.rocky }
  end
  table.sort(out.planets, function(a, b) return a.bright > b.bright end)
  for i = #out.planets, 1, -1 do
    if i > 8 or out.planets[i].bright < 0.002 then table.remove(out.planets, i) end
  end
  local n = S.band.normal
  local c = S.band.core
  out.band = { normal = localize(n[1], n[2], n[3]), core = localize(c[1], c[2], c[3]) }
  out.daylight = smooth(-0.12, 0.12, out.sun[2])
  return out
end

-- Settings for mvl.environment and mvl.sky from what `sky.at` returned.
function sky.view(P, at)
  local S, A = P.sky, P.sky.atmosphere
  local day = at.daylight
  local dusk = math.max(0, 1 - math.abs(at.sun[2]) / 0.2) * (1 - 0.5 * A.haze)
  local glow = mix(S.star.color, { 1, 0.55, 0.3 }, 0.5)
  local top = mix(A.night_top, A.day_top, day)
  local horizon = mix(A.night_horizon, A.day_horizon, day)
  horizon = mix(horizon, scale(glow, 0.55), dusk * 0.6)
  -- moonlight: the lit moons above the horizon
  local moon = 0
  local brightest
  for _, m in ipairs(at.moons) do
    if m.alt > 0 then
      local w = m.lit * m.size / 0.03
      moon = moon + w
      if not brightest or w > brightest.w then brightest = { w = w, dir = m.dir } end
    end
  end
  moon = math.min(moon, 1.5)
  local ambient = mix(mix({ 0.16, 0.17, 0.25 }, { 0.24, 0.26, 0.34 }, math.min(moon, 1)),
                      mix(S.star.color, horizon, 0.3), day * 0.85)
  local env = {
    sky_top = top, sky_horizon = horizon, fog_color = scale(horizon, 0.9),
    fog_near = A.fog_near, fog_far = A.fog_far, ambient = ambient,
    stars = math.max(1 - day * 1.15, A.day_stars or 0, 0),
  }
  local light = day > 0.02 and at.sun or (brightest and brightest.dir) or { -0.3, 0.9, 0.2 }
  local lx, ly, lz = norm(light[1], math.max(light[2], 0.15), light[3])
  env.sun_dir = { -lx, -ly, -lz }
  env.sun_color = day > 0.02 and scale(S.star.color, 0.85 * day) or scale({ 0.6, 0.65, 0.8 }, 0.25 * math.min(moon, 1))
  local bodies = {
    sun = { dir = at.sun, color = S.star.color, size = S.star.size, glow = S.star.glow * (0.4 + 0.6 * day) },
    light = at.sun, moons = {}, planets = {},
    band = { normal = at.band.normal, core = at.band.core, color = S.band.color, strength = S.band.strength,
             width = S.band.width },
  }
  for i, m in ipairs(at.moons) do bodies.moons[i] = { dir = m.dir, color = m.color, size = m.size } end
  for i, p in ipairs(at.planets) do
    bodies.planets[i] = { dir = p.dir, color = p.color, size = dm.clamp(0.003 + 0.0012 * dm.log(1 + p.bright * 50), 0.003, 0.009) }
  end
  return env, bodies
end

-- The heavens of a land: kept with it, else its planet's (older records).
function sky.heavens_of(G, node)
  if node.data.heavens then return node.data.heavens end
  local pa = node.address:match("^(.-%.p%d+)")
  if not pa then return nil end
  return sky.heavens(G:generate(pa).data)
end

-- Sets the sky of a place at time t; returns what stands where.
function sky.apply(P, place, t)
  local at = sky.at(P, place, t)
  local env, bodies = sky.view(P, at)
  mvl.environment(env)
  mvl.sky(bodies)
  return at, env
end

-- The time (days) of a visit on night `n`: the van arrives at a moment of
-- the planet's own clock that moves on from night to night.
function sky.visit_time(P, seed, night)
  local day = P.locked and 1 or (P.day or 1)
  return night * 1.37 + (seed % 9973) / 9973 * day
end

-- What a land keeps of its planet's sky (so that a stored land needs no
-- planet to show it).
function sky.heavens(P)
  if not P.sky then return nil end
  return { sky = require("gen.util").copy(P.sky), tilt = P.tilt, day = P.day, year = P.year, locked = P.locked,
           orbit = P.orbit }
end

-- A line for the world bible.
function sky.describe(S)
  local parts = { string.format("its star %.1f° across", S.star.size * 2 / RAD) }
  if #S.moons > 0 then
    local names = {}
    for i, m in ipairs(S.moons) do names[i] = string.format("%s (%.1f days)", m.name, m.period) end
    parts[#parts + 1] = #S.moons .. (#S.moons == 1 and " moon: " or " moons: ") .. table.concat(names, ", ")
  else
    parts[#parts + 1] = "no moons"
  end
  parts[#parts + 1] = #S.planets .. " sister planets"
  local A = S.atmosphere
  parts[#parts + 1] = A.haze > 0.5 and "a thick, hazy sky" or (A.day_stars > 0 and "a black sky with stars by day" or
                                                                 "a clear sky")
  return "Sky: " .. table.concat(parts, "; ") .. "."
end

function sky.register(R)
  R:pass("planet", "sky", { after = { "physics" }, run = function(ctx)
    if ctx.summary.prime then
      if ctx.node.address == prime.EARTH then
        local d = ctx.data
        d.sky = sky.prime_earth()
        d.tilt, d.day, d.year, d.orbit, d.locked = 23.44, 1, 365.25, 1, false
      end
      return
    end
    generate(ctx)
    if ctx.data.sky then ctx.data.orbit = ctx.summary.a end
  end })
end

return sky
