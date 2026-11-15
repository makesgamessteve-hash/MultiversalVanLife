-- Multiversal Van Life - the planet atlas: where people live (MIT License).
--
-- A planet pass after history. Per cell (P.cells):
--   fertility   what the land can feed (0..1): warmth, rain, soil (biome),
--               slope, fresh water, magic
--   population  people per km²: fertility x how the people feed themselves
--               (farming, herding, foraging) x their technology x history
--               (capitals attract, wars and plagues thin out, golden ages
--               and expansions grow) x tensions (drought, famine, epidemics)
--   urban       the share of people in towns and cities (0..0.9)
--   land_use    farmland, orchards, pasture, managed forest, mines, sacred,
--               wild or barren ("water" on the sea and lakes)
-- and for the planet (P.atlas): settlement seeds (the cells' cities, towns
-- and camps: position, rank, people, founding year, capital, port, river,
-- spaceport, name in their language) and trade routes between them (roads
-- over land, sea lanes between ports), plus totals. Uninhabited worlds get
-- land use only.
local dm = require("gen.dmath")
local G = require("gen.levels.geography")
local culture = require("gen.culture")

local A = { EARTH_KM = 6371 }

-- soil by biome id (what the ground gives when worked)
A.SOIL = {
  ["ice sheet"] = 0, tundra = 0.15, taiga = 0.35, ["temperate forest"] = 0.8, grassland = 1.0,
  ["cold desert"] = 0.15, ["hot desert"] = 0.1, savanna = 0.6, ["seasonal forest"] = 0.8, rainforest = 0.55,
  wetland = 0.5, coast = 0.6, alpine = 0.15, barren = 0.05, ["ash fields"] = 0.3, ["crystal forest"] = 0.4,
  ["arcane meadow"] = 0.7,
}
local FORESTS = { taiga = true, ["temperate forest"] = true, ["seasonal forest"] = true, rainforest = true,
                  ["crystal forest"] = true }
local BARREN = { ["ice sheet"] = true, barren = true, ["hot desert"] = true, ["cold desert"] = true, alpine = true,
                 ["ash fields"] = true }

local function biome_of(cells, i) local b = G.BIOMES[cells.biome[i]] return b and b.id or "ocean" end

-- ------------------------------------------------------------ fertility
local function fertility(cells, i, coast)
  if cells.elevation[i] <= 0 or cells.lake[i] then return 0 end
  local soil = A.SOIL[biome_of(cells, i)] or 0.3
  local t = (cells.temp[i] or 288) - 273.15
  local ft = dm.clamp(1 - math.abs(t - 17) / 22, 0, 1)
  local rain = cells.precip[i] or 0
  local fr = dm.clamp(rain / 1000, 0, 1) * (rain > 3000 and 0.85 or 1)
  local e = cells.elevation[i]
  local fs = e > 1.2 and dm.clamp(1 - (e - 1.2) / 2.5, 0.15, 1) or 1
  local water = (cells.river[i] and (0.1 + 0.25 * (1 - fr)) or 0) + (coast and 0.05 or 0)
  local magic = cells.magic and cells.magic[i] or 0
  return dm.round(dm.clamp(soil * (0.4 + 0.6 * ft) * (0.3 + 0.7 * fr) * fs * (1 + 0.2 * magic) + water, 0, 1), 3)
end

-- How a people feeds itself and how far its technology carries it.
function A.ways(cul)
  local has = cul and cul.tech and cul.tech.has or {}
  local level = cul and cul.tech and cul.tech.level or 0
  local farming, herding = has.agriculture ~= nil, has.herding ~= nil
  return {
    farming = farming, herding = herding, level = level,
    sailing = has.boats ~= nil or has.sailing ~= nil,
    base = farming and 90 or (herding and 18 or 4),
    industry = level >= 6 and (1 + 0.25 * (level - 5)) or 1,
  }
end

-- What history did to each country: a multiplier on its people.
local function history_factors(P)
  local f = {}
  for id in ipairs(P.countries or {}) do f[id] = 1 end
  local h = P.history
  if not h then return f end
  local n = {}
  for _, ev in ipairs(h.events or {}) do
    for _, place in ipairs(ev.places or {}) do
      n[place] = n[place] or {}
      n[place][ev.kind] = (n[place][ev.kind] or 0) + 1
    end
  end
  for id, c in pairs(n) do
    if f[id] then
      local k = 1
      k = k * math.max(0.6, 1 - 0.07 * (c.war or 0))
      k = k * math.max(0.6, 1 - 0.08 * (c.plague or 0))
      k = k * math.min(1.3, 1 + 0.05 * ((c["golden age"] or 0) + (c.expansion or 0) + (c.migration or 0)))
      k = k * math.max(0.6, 1 - 0.15 * (c.collapse or 0))
      f[id] = dm.round(k, 3)
    end
  end
  return f
end

local TENSION = { drought = 0.8, famine = 0.85, epidemic = 0.9 }

-- ------------------------------------------------------------ the pass
function A.run(ctx)
  local P = ctx.data
  local cells = P.cells
  if not cells or not cells.biome then return end
  local grid = P.grid
  local n = #cells.elevation
  local R = (P.radius or 1) * A.EARTH_KM
  local area = 4 * dm.pi * R * R / n                         -- km² per cell
  local spacing = math.sqrt(4 * dm.pi / n)                   -- radians between cells
  -- neighbours and positions (kept for this pass only)
  local nb, pos = {}, {}
  for i = 1, n do
    if i % 2048 == 0 and ctx.yield then ctx:yield() end
    nb[i] = mvl.planet_neighbours(grid, i)
    local x, y, z = mvl.planet_cell(grid, i)
    pos[i] = { x, y, z }
  end
  local function land(i) return cells.elevation[i] > 0 and not cells.lake[i] end
  local coast = {}
  for i = 1, n do
    if land(i) then
      for _, j in ipairs(nb[i]) do if cells.elevation[j] <= 0 and not cells.lake[j] then coast[i] = true end end
    end
  end
  local countries = P.countries or {}
  local cultures, ways = {}, {}
  for id, c in ipairs(countries) do
    cultures[id] = c.culture and P.cultures and P.cultures[c.culture] or nil
    ways[id] = cultures[id] and A.ways(cultures[id]) or nil
  end
  local hist = history_factors(P)
  local tension = {}
  for id, c in ipairs(countries) do
    local k = 1
    for _, t in ipairs(c.tensions or {}) do k = k * (TENSION[t.kind] or 1) end
    tension[id] = k
  end
  local capital_of = {}
  for id, c in ipairs(countries) do if c.capital and ways[id] then capital_of[c.capital] = id end end
  local near_capital = {}
  for cell in pairs(capital_of) do for _, j in ipairs(nb[cell]) do near_capital[j] = true end end
  -- per-cell fields
  local fert, pop, urban, use = {}, {}, {}, {}
  local total_people, inhabited = 0, 0
  for i = 1, n do
    if i % 2048 == 0 and ctx.yield then ctx:yield() end
    fert[i] = fertility(cells, i, coast[i])
    local cid = cells.country and cells.country[i] or 0
    local w = cid and cid > 0 and ways[cid] or nil
    local density = 0
    if w and land(i) then
      density = w.base * fert[i] * math.sqrt(fert[i]) * w.industry * (w.farming and w.herding and 1.1 or 1)
      density = density * (hist[cid] or 1) * (tension[cid] or 1)
      -- a people lives on even where the land feeds little (hunters, herders, miners)
      density = math.max(density, 0.03)
      if capital_of[i] then density = density * 4 elseif near_capital[i] then density = density * 2 end
    end
    pop[i] = dm.round(density, 2)
    if w and pop[i] > 0 then
      local u
      if not w.farming then
        u = w.herding and 0.02 or 0
      else
        local cul = cultures[cid]
        local hier = cul and cul.values and cul.values.hierarchy or 0
        u = 0.06 + 0.035 * w.level + (cells.river[i] and 0.04 or 0) + (coast[i] and 0.04 or 0) + 0.05 * hier +
            (capital_of[i] and 0.1 or 0)
      end
      urban[i] = dm.round(dm.clamp(u, 0, 0.85), 3)
      total_people = total_people + pop[i] * area
      inhabited = inhabited + 1
    else
      urban[i] = 0
    end
    -- land use
    if not land(i) then
      use[i] = "water"
    else
      local b = biome_of(cells, i)
      local magic = cells.magic and cells.magic[i] or 0
      if pop[i] >= 0.5 then
        if magic > 0.85 and mvl.hash(ctx.node.seed, "sacred", i) % 3 == 0 then use[i] = "sacred"
        elseif cells.deposit and cells.deposit[i] and cells.deposit[i] ~= 0 and cells.elevation[i] > 1.2 and fert[i] < 0.18 then
          use[i] = "mines"
        elseif w.farming and fert[i] > 0.18 then
          use[i] = ((cells.temp[i] or 0) > 285 and mvl.hash(ctx.node.seed, "orchard", i) % 5 == 0) and "orchards" or "farmland"
        elseif w.herding and fert[i] > 0.04 then use[i] = "pasture"
        elseif w.farming and fert[i] > 0.08 then use[i] = "pasture"
        elseif FORESTS[b] and w.farming then use[i] = "managed forest"
        else use[i] = "wild" end
      else
        use[i] = (BARREN[b] or fert[i] < 0.08) and "barren" or "wild"
      end
    end
  end
  cells.fertility, cells.population, cells.urban, cells.land_use = fert, pop, urban, use
  -- ----------------------------------------------- settlement seeds
  local seeds, at_cell = {}, {}
  local h = P.history
  local start, present = h and h.start or -1000, h and h.present or 0
  local rng = mvl.rng(mvl.hash(ctx.node.seed, "atlas"))
  local function place(i, k)
    -- a point inside the cell (near its middle on a river)
    local p = pos[i]
    local ux, uy, uz = -p[3], 0, p[1]                         -- east-ish: up x p
    local l = math.sqrt(ux * ux + uz * uz)
    if l < 1e-9 then ux, uz, l = 1, 0, 1 end
    ux, uz = ux / l, uz / l
    local vx, vy, vz = p[2] * uz - p[3] * uy, p[3] * ux - p[1] * uz, p[1] * uy - p[2] * ux
    local reach = spacing * (cells.river[i] and 0.12 or 0.38)
    local a, b = (rng:next() * 2 - 1) * reach, (rng:next() * 2 - 1) * reach
    local x, y, z = p[1] + ux * a + vx * b, p[2] + uy * a + vy * b, p[3] + uz * a + vz * b
    local m = math.sqrt(x * x + y * y + z * z)
    x, y, z = x / m, y / m, z / m
    return dm.round(dm.atan(y, math.sqrt(x * x + z * z)) * 180 / dm.pi, 4), dm.round(dm.atan(z, x) * 180 / dm.pi, 4)
  end
  local per_country = {}
  local function add_seed(i, cid, rank, people, capital)
    per_country[cid] = (per_country[cid] or 0) + 1
    local lat, lon = place(i, #seeds)
    local nm = culture.land_name(P, cid, mvl.hash(ctx.node.seed, "settlement", i, #seeds))
    local w = ways[cid]
    local s = {
      id = #seeds + 1, cell = i, country = cid, culture = countries[cid].culture, rank = rank,
      people = math.floor(people), lat = lat, lon = lon, name = nm and nm.name or ("place " .. (#seeds + 1)),
      meaning = nm and nm.meaning, capital = capital or nil, river = cells.river[i] or nil,
      port = (coast[i] and w.sailing) or nil, spaceport = (capital and w.level >= 10) or nil,
      founded = capital and start or math.floor(start + rng:next() * math.max(1, present - 50 - start)),
    }
    seeds[#seeds + 1] = s
    at_cell[i] = at_cell[i] or {}
    at_cell[i][#at_cell[i] + 1] = s.id
  end
  for i = 1, n do
    local cid = cells.country and cells.country[i] or 0
    local w = cid and cid > 0 and ways[cid] or nil
    if w and pop[i] > 0 and land(i) then
      local people = pop[i] * area
      local urban_people = people * urban[i]
      if capital_of[i] then
        add_seed(i, cid, w.farming and "city" or "camp", math.max(urban_people * 0.6, w.farming and 5000 or 150), true)
      elseif not w.farming then
        if people > 30000 and rng:next() < 0.35 then add_seed(i, cid, "camp", 40 + rng:next() * 110) end
      else
        if urban_people > 400000 and rng:next() < math.min(0.9, urban_people / 1500000) then
          add_seed(i, cid, "city", urban_people * (0.3 + rng:next() * 0.4))
        end
        local towns = math.min(2, math.floor(people / 900000 + rng:next()))
        -- rivers draw people together: a fertile river valley has its town
        if towns == 0 and cells.river[i] and fert[i] > 0.25 and people > 150000 then towns = 1 end
        for _ = 1, towns do add_seed(i, cid, "town", 1500 + rng:next() * 25000) end
      end
    end
  end
  -- ------------------------------------------------- trade routes
  local function step_cost(a, b)
    local e = cells.elevation[b]
    local c = 1 + 2 * math.max(0, e - 1.5)
    if biome_of(cells, b) == "wetland" then c = c + 1 end
    if cells.river[b] and not cells.river[a] then c = c + 0.3 end
    if cells.country and cells.country[a] ~= cells.country[b] then c = c + 0.5 end
    return c
  end
  -- multi-source search from the seeds' cells over passable cells (a binary
  -- heap in two arrays; yields now and then so frames stay smooth)
  local function yield() if ctx.yield then ctx:yield() end end
  local function search(sources, passable, cost)
    local dist, owner, parent = {}, {}, {}
    local hd, hi, size = {}, {}, 0
    local function push(d, i)
      size = size + 1
      local k = size
      while k > 1 do
        local p = k // 2
        if hd[p] <= d then break end
        hd[k], hi[k] = hd[p], hi[p]
        k = p
      end
      hd[k], hi[k] = d, i
    end
    local function pop()
      local d, i = hd[1], hi[1]
      local ld, li = hd[size], hi[size]
      hd[size], hi[size] = nil, nil
      size = size - 1
      if size > 0 then
        local k = 1
        while true do
          local l = k * 2
          if l > size then break end
          if l + 1 <= size and hd[l + 1] < hd[l] then l = l + 1 end
          if hd[l] >= ld then break end
          hd[k], hi[k] = hd[l], hi[l]
          k = l
        end
        hd[k], hi[k] = ld, li
      end
      return d, i
    end
    for _, s in ipairs(sources) do
      if not dist[s.cell] then
        dist[s.cell], owner[s.cell] = 0, s.cell
        push(0, s.cell)
      end
    end
    local pops = 0
    while size > 0 do
      local d, i = pop()
      pops = pops + 1
      if pops % 2048 == 0 then yield() end
      if d <= dist[i] then
        for _, j in ipairs(nb[i]) do
          if passable(j) then
            local nd = d + cost(i, j)
            if not dist[j] or nd < dist[j] then
              dist[j], owner[j], parent[j] = nd, owner[i], i
              push(nd, j)
            end
          end
        end
      end
    end
    return dist, owner, parent
  end
  -- candidate links where two seeds' areas meet, then a spanning network
  -- with the short extra links that make loops
  local function network(sources, passable, cost, kind, max_cost)
    local dist, owner, parent = search(sources, passable, cost)
    local best = {}
    for i in pairs(dist) do
      for _, j in ipairs(nb[i]) do
        if dist[j] and owner[i] ~= owner[j] and owner[i] < owner[j] then
          local c = dist[i] + cost(i, j) + dist[j]
          local k = owner[i] .. "," .. owner[j]
          if not best[k] or c < best[k].c then best[k] = { c = c, a = i, b = j, oa = owner[i], ob = owner[j] } end
        end
      end
    end
    local cand = {}
    for _, e in pairs(best) do if e.c <= max_cost then cand[#cand + 1] = e end end
    table.sort(cand, function(x, y)
      if x.c ~= y.c then return x.c < y.c end
      if x.oa ~= y.oa then return x.oa < y.oa end
      return x.ob < y.ob
    end)
    local up = {}
    local function find(x)
      while up[x] and up[x] ~= x do x = up[x] end
      return x
    end
    local chosen, median = {}, nil
    for _, e in ipairs(cand) do
      local ra, rb = find(e.oa), find(e.ob)
      if ra ~= rb then
        up[ra] = rb
        chosen[#chosen + 1] = e
        e.tree = true
      end
    end
    if #chosen > 0 then median = chosen[math.max(1, #chosen // 2)].c end
    for _, e in ipairs(cand) do
      if not e.tree and median and e.c <= median * 0.8 then chosen[#chosen + 1] = e end
    end
    local out = {}
    for _, e in ipairs(chosen) do
      local path = {}
      local i = e.a
      while i do
        table.insert(path, 1, i)
        i = parent[i]
      end
      i = e.b
      while i do
        path[#path + 1] = i
        i = parent[i]
      end
      local km = 0
      for k = 2, #path do
        local p, q = pos[path[k - 1]], pos[path[k]]
        local d = dm.clamp(p[1] * q[1] + p[2] * q[2] + p[3] * q[3], -1, 1)
        km = km + dm.atan(math.sqrt(1 - d * d), d) * R
      end
      out[#out + 1] = { a = at_cell[e.oa][1], b = at_cell[e.ob][1], kind = kind, cells = path, km = math.floor(km + 0.5) }
    end
    return out
  end
  local routes = {}
  if #seeds > 1 then
    for _, r in ipairs(network(seeds, land, step_cost, "road", math.huge)) do routes[#routes + 1] = r end
    -- seeds sharing a cell: a short road between them
    for _, list in pairs(at_cell) do
      for k = 2, #list do routes[#routes + 1] = { a = list[1], b = list[k], kind = "road", cells = { seeds[list[1]].cell }, km = 0 } end
    end
    -- sea lanes between the ports of seafaring peoples, over open water
    local ports = {}
    for _, s in ipairs(seeds) do if s.port then ports[#ports + 1] = s end end
    if #ports > 1 then
      local is_port = {}
      for _, s in ipairs(ports) do is_port[s.cell] = true end
      local function sea(j) return (cells.elevation[j] <= 0 and not cells.lake[j]) or is_port[j] end
      local function sea_cost(a, b) return (is_port[b] and 4 or 1) end
      for _, r in ipairs(network(ports, sea, sea_cost, "sea", 160)) do
        -- a lane is only worth sailing where the way by land is long or missing
        routes[#routes + 1] = r
      end
    end
  end
  table.sort(routes, function(x, y)
    if x.a ~= y.a then return x.a < y.a end
    if x.b ~= y.b then return x.b < y.b end
    return x.kind < y.kind
  end)
  local counts = { city = 0, town = 0, camp = 0 }
  for _, s in ipairs(seeds) do counts[s.rank] = counts[s.rank] + 1 end
  local roads, lanes = 0, 0
  for _, r in ipairs(routes) do if r.kind == "road" then roads = roads + 1 else lanes = lanes + 1 end end
  P.atlas = {
    settlements = seeds, routes = routes, cell_km2 = dm.round(area, 1),
    people = math.floor(total_people), inhabited_cells = inhabited,
    cities = counts.city, towns = counts.town, camps = counts.camp, roads = roads, sea_lanes = lanes,
  }
end

-- A paragraph for the world bible.
function A.describe(P)
  local a = P.atlas
  if not a then return nil end
  if #a.settlements == 0 then return "Atlas: nobody lives here; the land is " .. (a.inhabited_cells == 0 and "wild and barren." or "empty.") end
  local list = {}
  for _, s in ipairs(a.settlements) do if s.rank == "city" then list[#list + 1] = s end end
  table.sort(list, function(x, y) return x.people > y.people end)
  local names = {}
  for k = 1, math.min(5, #list) do
    names[k] = string.format("%s (%s people%s)", list[k].name, list[k].people, list[k].capital and ", capital" or "")
  end
  return string.format("Atlas: about %d million people in %d cities, %d towns and %d camps, joined by %d roads and %d sea lanes.%s",
                       math.floor(a.people / 1e6 + 0.5), a.cities, a.towns, a.camps, a.roads, a.sea_lanes,
                       #names > 0 and (" Largest cities: " .. table.concat(names, ", ") .. ".") or "")
end

function A.register(R)
  R:pass("planet", "atlas", { after = { "echoes" }, run = function(ctx)
    if not ctx.summary.prime then A.run(ctx) end
  end })
  local prev = R:level("planet").describe
  R:describe("planet", function(node)
    local text = prev and prev(node) or tostring(node.summary.name)
    local atlas = A.describe(node.data)
    return atlas and (text .. "\n\n" .. atlas) or text
  end)
end

return A
