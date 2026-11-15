-- The planet atlas: fertility, people, towns and land use per cell, the
-- seeds of cities and towns joined by roads and sea lanes, and questions
-- about any place answered from the planet alone.
local gen = require("gen")
local plan = gen.plan
local A = gen.atlas

local function peopled(seed)
  local G = gen.run.new(gen.cosmos, { seed = seed, mods = {} })
  return G, gen.stats.world(G, seed)
end

-- ------------------------------------------------- a river valley
local found = 0
for seed = 1, 12 do
  local G, p = peopled(seed)
  if p and found < 3 then
    local P = p.data
    local c = P.cells
    local best, bf
    for i = 1, #c.elevation do
      local cid = c.country[i]
      local co = cid and cid > 0 and P.countries[cid]
      local cul = co and co.culture and P.cultures[co.culture]
      if c.river[i] and cul and A.ways(cul).farming and c.elevation[i] > 0 and (not bf or c.fertility[i] > bf) then
        best, bf = i, c.fertility[i]
      end
    end
    if best and bf > 0.3 then
      found = found + 1
      local cid = c.country[best]
      local dens = {}
      for i = 1, #c.elevation do if c.country[i] == cid and c.population[i] > 0 then dens[#dens + 1] = c.population[i] end end
      table.sort(dens)
      local median = dens[math.max(1, #dens // 2)]
      test.expect(c.population[best] > median,
                  string.format("the river valley is crowded: %.1f people/km² against %.1f", c.population[best], median))
      test.expect(c.land_use[best] == "farmland" or c.land_use[best] == "orchards", "it is farmed: " .. tostring(c.land_use[best]))
      local town
      for _, s in ipairs(P.atlas.settlements) do if s.cell == best and s.river then town = s end end
      test.expect(town, "a town on the river: " .. p.address .. " cell " .. best)
    end
  end
end
test.expect(found >= 2, "fertile river valleys of farmers: " .. found)

-- ---------------------------------------------- an uninhabited world
local empty
for seed = 1, 40 do
  local G = gen.run.new(gen.cosmos, { seed = seed, mods = {} })
  local u = G:generate("u1")
  for g = 0, 2 do
    for cl = 0, 2 do
      local saddr = string.format("u%d.g%d.c%d.s0", 1 + seed % 5, g, cl)
      local ok, sys = pcall(G.generate, G, saddr)
      if ok and not empty then
        for i = 0, sys.data.planets - 1 do
          local okp, p = pcall(G.generate, G, saddr .. ".p" .. i)
          if okp and p.data.cells and p.data.atlas and #(p.data.cultures or {}) == 0 and not empty then empty = p end
        end
      end
    end
  end
  if empty then break end
end
test.expect(empty, "an uninhabited world")
local E = empty.data
local land, used = 0, 0
for i = 1, #E.cells.elevation do
  test.expect(E.cells.population[i] == 0, "nobody lives there")
  if E.cells.elevation[i] > 0 and not E.cells.lake[i] then
    land = land + 1
    if E.cells.land_use[i] == "wild" or E.cells.land_use[i] == "barren" then used = used + 1 end
  end
end
test.eq(used, land, "every land cell is wild or barren")
test.eq(#E.atlas.settlements, 0, "no settlements")
test.eq(#E.atlas.routes, 0, "no routes")

-- -------------------------------------------------------- routes
for _, seed in ipairs({ 1, 3, 6 }) do
  local G, p = peopled(seed)
  local P = p.data
  local c = P.cells
  local seeds, routes = P.atlas.settlements, P.atlas.routes
  local function adjacent(a, b)
    for _, j in ipairs(mvl.planet_neighbours(P.grid, a)) do if j == b then return true end end
    return false
  end
  local up = {}
  local function find(x) while up[x] and up[x] ~= x do x = up[x] end return x end
  local bad_land, bad_sea, broken = 0, 0, 0
  for _, r in ipairs(routes) do
    test.expect(seeds[r.a] and seeds[r.b], "a route joins two settlements")
    test.eq(r.cells[1], seeds[r.a].cell, "it starts at the first")
    test.eq(r.cells[#r.cells], seeds[r.b].cell, "and ends at the second")
    for k = 2, #r.cells do if not adjacent(r.cells[k - 1], r.cells[k]) then broken = broken + 1 end end
    if r.kind == "road" then
      for _, ci in ipairs(r.cells) do if c.elevation[ci] <= 0 or c.lake[ci] then bad_land = bad_land + 1 end end
      local ra, rb = find(r.a), find(r.b)
      if ra ~= rb then up[ra] = rb end
    else
      test.expect(seeds[r.a].port and seeds[r.b].port, "sea lanes run between ports")
      for k = 2, #r.cells - 1 do if c.elevation[r.cells[k]] > 0 then bad_sea = bad_sea + 1 end end
    end
  end
  test.eq(broken, 0, "routes go from cell to neighbouring cell")
  test.eq(bad_land, 0, "roads never cross water: " .. p.address)
  test.eq(bad_sea, 0, "sea lanes stay on open water")
  -- the roads join every settlement of a continent
  local first = {}
  local split = 0
  for _, s in ipairs(seeds) do
    local k = c.continent[s.cell]
    if first[k] then
      if find(first[k]) ~= find(s.id) then split = split + 1 end
    else
      first[k] = s.id
    end
  end
  test.eq(split, 0, "roads join every settlement of a continent")
end

-- ------------------------------------------------- asking about a place
local G, p = peopled(6)
local s = p.data.atlas.settlements[1]
local nodes = 0
for _ in pairs(G.nodes) do nodes = nodes + 1 end
local q = plan.at(G, p.address, s.lat + 0.3, s.lon - 0.2)
local after = 0
for _ in pairs(G.nodes) do after = after + 1 end
test.eq(after, nodes, "asking generates nothing below the planet")
test.expect(q.country and q.country.name and q.culture and q.culture.name, "the country and the people")
test.expect(q.land_use and q.population and q.fertility, "land use and people: " .. tostring(q.land_use))
test.expect(#q.settlements == 3 and q.settlements[1].km <= q.settlements[2].km, "the nearest towns")
test.expect(q.settlements[1].km < 300, "the nearest is close: " .. q.settlements[1].km .. " km " .. q.settlements[1].direction)
test.expect(q.route, "a road nearby")
test.expect(plan.tell(q):find(q.settlements[1].name, 1, true), "told in a sentence: " .. plan.tell(q))
local sea
for i = 1, #p.data.cells.elevation do if p.data.cells.elevation[i] < -1 then sea = i break end end
local x, y, z = mvl.planet_cell(p.data.grid, sea)
local lat = math.deg(math.atan(y, math.sqrt(x * x + z * z)))
local qs = plan.at(G, p, lat, math.deg(math.atan(z, x)))
test.expect(qs.water and qs.land_use == "water", "the sea is water")
-- the bible tells the atlas
local text = gen.bible.export(G, p.address)
test.expect(text:find("Atlas: about", 1, true), "the world bible tells the atlas")
