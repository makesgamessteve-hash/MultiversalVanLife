-- The surface grid: every point of a planet lies in exactly one region and
-- land of a cube-sphere grid of 32 km regions with 16 x 16 lands each, and
-- the land there can be generated on demand from the planet plan (its
-- country, people and ground agreeing with the atlas). Addresses branch:
-- a planet has continents and regions, a land lies in a region (or, before
-- the grid, in a country).
local gen = require("gen")
local A = gen.address
local grid = gen.grid
local dm = require("gen.dmath")

-- ------------------------------------------------------------ addresses
local C = A.COSMOS
test.expect(A.parse(C, "u1.g2.c3.s1.p0.r40961.l7"), "a land of a region")
test.expect(A.parse(C, "u1.g2.c3.s1.p0.r40961"), "a region")
test.expect(A.parse(C, "u1.g2.c3.s1.p0.k0.n5.l7"), "a land of a country district")
test.expect(not A.parse(C, "u1.g2.c3.s1.p0.k0.r1"), "a continent has no regions")
test.expect(not A.parse(C, "u1.g2.c3.s1.p0.r1.n1"), "a region has no countries")
test.expect(not A.parse(C, "u1.g2.r3"), "a galaxy has no regions")
test.eq(A.child(C, "u1.g2.c3.s1.p0", 4), "u1.g2.c3.s1.p0.k4", "a planet's main children are continents")
test.eq(A.child(C, "u1.g2.c3.s1.p0", 4, "region"), "u1.g2.c3.s1.p0.r4", "and it has regions")
test.eq(A.child(C, "u1.g2.c3.s1.p0.r4", 9), "u1.g2.c3.s1.p0.r4.l9", "regions have lands")
test.expect(not pcall(A.child, C, "u1.g2", 1, "region"), "only planets have regions")
test.eq(A.level_of(C, "u1.g2.c3.s1.p0.r4").name, "region", "level by prefix")
test.eq(A.level_of(C, "u1.g2.c3.s1.p0.r4.l9").n, A.level_of(C, "u1.g2.c3.s1.p0.k0.n1.l9").n, "one land level")
test.eq(A.level("u1.g2.c3.s1.p0.r4.l9"), 7, "depth")
test.eq(A.format(C, { 1, 2, 3, 1, 0, 4, 9 }, { "universe", "galaxy", "cluster", "system", "planet", "region", "land" }),
        "u1.g2.c3.s1.p0.r4.l9", "format along named levels")
-- seeds hash level numbers: a region and the continent with its index differ
local seed = 20261113
test.expect(A.seed(seed, "u1.g2.c3.s1.p0.r4") ~= A.seed(seed, "u1.g2.c3.s1.p0.k4"), "own seeds for regions")
test.eq(A.seed(seed, "u1.g2.c3.s1.p0.r4.l9"),
        mvl.hash(mvl.hash(A.seed(seed, "u1.g2.c3.s1.p0"), C.by_name.region.n, 4), C.by_name.land.n, 9), "land seed")

-- ------------------------------------------------------- the cube grid
local g = grid.of({ radius = 1 })
test.expect(g.N > 250 and g.N < 360, "an Earth-sized planet has about 300 x 300 regions a face: " .. g.N)
test.expect(math.abs(g.H * 2 - g.N * grid.REGION) < 1e-6, "a face is N regions wide")
local rng = mvl.rng(27)
local worst = 0
for _ = 1, 400 do
  local x, y, z = rng:float(-1, 1), rng:float(-1, 1), rng:float(-1, 1)
  local l = math.sqrt(x * x + y * y + z * z)
  x, y, z = x / l, y / l, z / l
  local f = grid.face_of(x, y, z)
  local s, t = grid.to_face(g, f, x, y, z)
  test.expect(math.abs(s) <= g.H + 1e-6 and math.abs(t) <= g.H + 1e-6, "a direction lies on its face")
  local bx, by, bz = grid.to_sphere(g, f, s, t)
  worst = math.max(worst, math.abs(bx - x) + math.abs(by - y) + math.abs(bz - z))
  -- exactly one region and land
  local loc = grid.locate("p", g, x, y, z)
  local R, L = grid.indices(g, loc.face, loc.gx, loc.gz)
  test.expect(R >= 0 and R < g.regions and L >= 0 and L < 256, "valid region and land")
  local f2, gx2, gz2 = grid.land_of(g, R, L)
  test.expect(f2 == loc.face and gx2 == loc.gx and gz2 == loc.gz, "the indices name the same land")
  -- the land's square contains the point
  local cx, cz = grid.land_centre(g, loc.gx, loc.gz)
  test.expect(math.abs(s - cx) <= 1024 + 1e-6 and math.abs(-t - cz) <= 1024 + 1e-6, "inside its land")
end
test.expect(worst < 1e-9, "face coordinates map back to the same direction: " .. worst)
-- a metre of face coordinates is close to a metre on the ground everywhere
for _, at in ipairs({ { 0, 0 }, { g.H * 0.9, 0 }, { g.H * 0.9, g.H * 0.9 } }) do
  local x1, y1, z1 = grid.to_sphere(g, 0, at[1], at[2])
  local x2, y2, z2 = grid.to_sphere(g, 0, at[1] + 1000, at[2])
  local d = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2 + (z2 - z1) ^ 2) * g.radius
  test.expect(d > 700 and d < 1300, "1 km on the face is about 1 km on the planet: " .. d)
end
-- shared face edges: both faces name the same points (faces 0 and 1, 0 and 4)
for _, t in ipairs({ -0.7, 0, 0.3 }) do
  local ax, ay, az = grid.to_sphere(g, 0, g.H, t * g.H)
  local bx, by, bz = grid.to_sphere(g, 1, -g.H, t * g.H)
  test.expect(math.abs(ax - bx) + math.abs(ay - by) + math.abs(az - bz) < 1e-12, "faces 0 and 1 meet")
  ax, ay, az = grid.to_sphere(g, 0, t * g.H, g.H)
  bx, by, bz = grid.to_sphere(g, 4, t * g.H, -g.H)
  test.expect(math.abs(ax - bx) + math.abs(ay - by) + math.abs(az - bz) < 1e-12, "faces 0 and 4 meet")
end

-- ---------------------------------------------------------- any place
-- On real planets: a random place on land lies in one region and land, and
-- that land, generated on demand, agrees with the planet's plan there.
local checked, peopled = 0, 0
for s = 1, 6 do
  local G = gen.run.new(gen.cosmos, { seed = s, mods = {} })
  local p = gen.stats.world(G, s)
  if p then
    local P = p.data
    local info = gen.region.info(P)
    local r = mvl.rng(mvl.hash(s, "any place"))
    for _ = 1, 3 do
      -- a random land cell, a random point near its centre
      local cell
      for _ = 1, 50 do
        local c = r:int(1, #P.cells.elevation)
        if P.cells.elevation[c] > 0.05 and not P.cells.lake[c] then cell = c break end
      end
      if cell then
        local cx, cy, cz = mvl.planet_cell(P.grid, cell)
        local lat, lon = grid.latlon(cx, cy, cz)
        lat, lon = lat + r:float(-0.2, 0.2), lon + r:float(-0.2, 0.2)
        local addr = gen.land_at(G, p.address, lat, lon)
        test.expect(addr and gen.is_grid_land(addr), "a land of the grid at " .. lat .. ", " .. lon)
        local land = G:generate(addr)
        local d = land.data
        local region = G:generate(A.parent(addr))
        test.eq(region.kind, "region", "its parent is a region")
        -- the land's place is where we asked (within a land's size)
        local km = gen.plan.distance(info.g.radius / 1000, lat, lon, d.place.latitude, d.place.longitude)
        test.expect(km < 2.5, "the land is where it was asked for: " .. km .. " km")
        -- its country is the atlas's there (its centre's cell)
        local q = gen.plan.at(G, p.address, d.place.latitude, d.place.longitude)
        local cid = region.data.land_country[land.index + 1]
        local expected = P.cells.elevation[q.cell] > 0 and q.country and q.country.id or 0
        test.eq(cid, expected, "the atlas's country")
        if cid > 0 and q.country then
          test.eq(d.country, q.country.name, "named as the atlas names it")
          if q.culture and not d.wild then
            peopled = peopled + 1
            test.eq(d.culture and d.culture.name, q.culture.name, "its people are the country's")
          end
        end
        -- generated again from scratch: the same land
        local G2 = gen.run.new(gen.cosmos, { seed = s, mods = {} })
        test.eq(gen.util.fingerprint(G2:generate(addr).data), gen.util.fingerprint(d), "deterministic")
        checked = checked + 1
      end
    end
  end
end
test.expect(checked >= 12, "places checked: " .. checked)
test.expect(peopled >= 4, "peopled places among them: " .. peopled)

-- ------------------------------------------------- seams and neighbours
local G = gen.run.new(gen.cosmos, { seed = 3, mods = {} })
local p = gen.stats.world(G, 3)
local sm = require("gen.plan.seams").planet(G, p)
test.expect(sm.region < 0.05 and sm.face < 0.05 and sm.pole < 0.05, "no seams")
test.eq(sm.river_points, 0, "rivers continue across the region border")
-- the check is not vacuous: two lands apart do differ
local info = gen.region.info(p.data)
local x, y, z = mvl.planet_cell(p.data.grid, p.data.countries[1].capital)
local loc = grid.locate(p.address, info.g, x, y, z)
local a = G:generate(loc.address)
local b = gen.neighbour_land(G, loc.address, loc.gx + 2, loc.gz)
local L = gen.land
local diff = 0
for k = 0, 2048, 64 do
  local wx, wz = a.data.center[1] + 1024, a.data.center[2] - 1024 + k
  diff = math.max(diff, math.abs(L.raw_height(a.data.terrain, wx, wz) - L.raw_height(b.data.terrain, wx + 2048, wz)))
end
test.expect(diff > 0.1, "a shifted comparison finds differences: " .. diff)
-- neighbours across a region border, and none beyond the face
local east = gen.neighbour_land(G, loc.address, (loc.gx // 16 + 1) * 16, loc.gz)
test.expect(east and A.parent(east.address) ~= A.parent(loc.address), "the next region's land")
test.eq(gen.neighbour_land(G, loc.address, -1, loc.gz), nil, "no land beyond the face's edge")
-- regions exist up to the grid's size, not beyond
local n = info.g.regions
test.expect(pcall(G.generate, G, p.address .. ".r" .. (n - 1)), "the last region")
test.expect(not pcall(G.generate, G, p.address .. ".r" .. n), "no region beyond the grid")
test.expect(not pcall(G.generate, G, p.address .. ".r0.l256"), "16 x 16 lands a region")
-- the bible describes regions
test.expect(gen.region.describe(G:generate(A.parent(loc.address))):find("32 km region"), "described")
-- version 2 multiverses have no district lands, Prime keeps its farm
local country = p.address .. ".k" .. (p.data.countries[1].continent - 1) .. ".n" .. p.data.countries[1].index
test.expect(not pcall(G.generate, G, country .. ".l0"), "no district lands on the grid")
test.expect(G:generate(gen.prime.FARM).data.style == "farm", "the farm is where it was")
test.expect(not pcall(G.generate, G, "u0.g0.c0.s0.p2.r0"), "Prime has no regions")
local V1 = gen.run.new(gen.cosmos, { seed = 3, mods = {}, version = 1 })
test.expect(V1:generate(country .. ".l0").data.terrain.map, "before the grid: the district's lands")

-- ------------------------------------------- promises kept on the grid
-- what planets promise their countries (people of history, monuments,
-- traces) goes to lands of the grid in those countries, and is kept there
local promised, kept = 0, 0
for s = 1, 8 do
  local Gs = gen.run.new(gen.cosmos, { seed = s, mods = {} })
  local ps = gen.stats.world(Gs, s)
  if ps then
    local targets = {}
    for target in pairs(ps.commits) do targets[#targets + 1] = target end
    table.sort(targets)
    for _, target in ipairs(targets) do
      if target:match("%.l%d+$") then
        test.expect(gen.is_grid_land(target), "promised to a land of the grid: " .. target)
        local land = Gs:generate(target)
        promised = promised + #ps.commits[target]
        for _, id in ipairs(ps.commits[target]) do if land.honoured[id] then kept = kept + 1 end end
        local cid = gen.region.country_id(Gs, target)
        test.expect(cid > 0 and not land.data.wild, "on dry land of a country: " .. target)
      end
    end
    local problems = gen.check.run(Gs)
    test.eq(#problems, 0, "the checker finds nothing wrong (seed " .. s .. "): " ..
            (problems[1] and problems[1].message or ""))
  end
end
test.expect(promised >= 10, "promises made to lands: " .. promised)
test.eq(kept, promised, "and every one kept")
