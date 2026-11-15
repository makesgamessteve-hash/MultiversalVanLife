-- Multiversal Van Life - asking the planet's plan about a place (MIT).
--
-- `plan.at(G, planet, lat, lon)` answers what is at a latitude and longitude
-- of a planet from its atlas (gen/plan/atlas.lua) without generating
-- anything below the planet: the cell, water or land, biome, country,
-- culture, fertility and people per km² (interpolated), land use, the
-- nearest settlements (distance in km and direction) and the nearest trade
-- route. Signals, dialogue, quests, the codex and a map use it.
local dm = require("gen.dmath")
local geo = require("gen.levels.geography")

local plan = {}

local DIRS = { "east", "north-east", "north", "north-west", "west", "south-west", "south", "south-east" }

local function xyz(lat, lon)
  local la, lo = lat * dm.pi / 180, lon * dm.pi / 180
  local c = dm.cos(la)
  return c * dm.cos(lo), dm.sin(la), c * dm.sin(lo)
end

-- Great-circle distance in km and the compass direction from a to b.
function plan.distance(R, lat1, lon1, lat2, lon2)
  local x1, y1, z1 = xyz(lat1, lon1)
  local x2, y2, z2 = xyz(lat2, lon2)
  local d = dm.clamp(x1 * x2 + y1 * y2 + z1 * z2, -1, 1)
  local km = dm.atan(math.sqrt(1 - d * d), d) * R
  -- direction on the local east/north frame
  local dlon = (lon2 - lon1 + 540) % 360 - 180
  local east = dlon * dm.cos(lat1 * dm.pi / 180)
  local north = lat2 - lat1
  local a = dm.atan(north, east)
  local k = math.floor(((a / (2 * dm.pi)) * 8 + 8.5)) % 8 + 1
  return km, DIRS[k]
end

-- The planet node of an address or node (generated, but nothing below it).
local function planet_node(G, planet)
  if type(planet) == "string" then return G:generate(planet) end
  return planet
end

function plan.at(G, planet, lat, lon, opts)
  local p = planet_node(G, planet)
  local P = p.data
  local cells = P.cells
  if not cells then return nil end
  local x, y, z = xyz(lat, lon)
  local cell = mvl.planet_nearest(P.grid, x, y, z)
  local R = (P.radius or 1) * 6371
  local out = { cell = cell, lat = lat, lon = lon, water = cells.elevation[cell] <= 0 or cells.lake[cell] or false }
  local b = geo.BIOMES[cells.biome[cell]]
  out.biome = b and b.id
  out.elevation = cells.elevation[cell]
  if cells.fertility then
    out.fertility = dm.round(math.max(0, mvl.planet_sample(P.grid, cells.fertility, x, y, z)), 3)
    out.population = dm.round(math.max(0, mvl.planet_sample(P.grid, cells.population, x, y, z)), 2)
    out.urban = cells.urban[cell]
    out.land_use = cells.land_use[cell]
  end
  local cid = cells.country and cells.country[cell] or 0
  local c = cid and cid > 0 and P.countries and P.countries[cid] or nil
  if c then
    out.country = { id = cid, name = c.name, nation = c.nation }
    local cul = c.culture and P.cultures and P.cultures[c.culture]
    if cul then out.culture = { id = cul.id, name = cul.name, species = cul.species } end
  end
  -- nearest settlements and route
  local a = P.atlas
  out.settlements, out.route = {}, nil
  if a then
    local list = {}
    for _, s in ipairs(a.settlements) do
      local km, dir = plan.distance(R, lat, lon, s.lat, s.lon)
      list[#list + 1] = { id = s.id, name = s.name, rank = s.rank, people = s.people, km = math.floor(km + 0.5),
                          direction = dir, capital = s.capital, port = s.port }
    end
    table.sort(list, function(u, v) if u.km ~= v.km then return u.km < v.km end return u.id < v.id end)
    for k = 1, math.min((opts and opts.settlements) or 3, #list) do out.settlements[k] = list[k] end
    -- the nearest route passing through this cell or its neighbours
    local near = { [cell] = 0 }
    for _, j in ipairs(mvl.planet_neighbours(P.grid, cell)) do near[j] = 1 end
    for _, r in ipairs(a.routes) do
      for _, ci in ipairs(r.cells) do
        local d = near[ci]
        if d and (not out.route or d < out.route.cells_away) then
          out.route = { kind = r.kind, from = a.settlements[r.a].name, to = a.settlements[r.b].name, cells_away = d,
                        km = r.km }
        end
      end
    end
  end
  return out
end

-- A sentence for dialogue: "the town of X is 120 km to the north-east".
function plan.tell(q)
  local s = q and q.settlements and q.settlements[1]
  if not s then return nil end
  return string.format("the %s of %s is %d km to the %s", s.rank, s.name, s.km, s.direction)
end

return plan
