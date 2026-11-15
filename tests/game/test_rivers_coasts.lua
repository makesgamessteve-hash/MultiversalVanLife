-- Land terrain follows the planet: a river crosses its lands along the
-- planet's course, on a coast the ground sinks to the sea on the side where
-- the planet has its ocean, and a lake fills its basin.
local D = game.debug
local gen = D.gen
local grid = gen.grid

-- Planets of a few systems: fn(planet) until it returns something.
local function each_planet(G, fn)
  for s = 0, 60 do
    local saddr = "u" .. (1 + s % 6) .. ".g" .. (s % 9) .. ".c0.s" .. (s % 4)
    local ok, sys = pcall(G.generate, G, saddr)
    if ok then
      for i = 0, sys.data.planets - 1 do
        if sys.children[i].kind == "rocky" then
          local p = G:generate(saddr .. ".p" .. i)
          if p.data.cells and p.data.cells.filled then
            local r = fn(p)
            if r then return r end
          end
        end
      end
    end
  end
end

-- The land at a direction of a planet, if it has people and a settlement.
local function settled(G, p, x, y, z)
  local info = gen.region.info(p.data)
  local addr = grid.locate(p.address, info.g, x, y, z).address
  local land = G:generate(addr)
  return not land.data.wild and land.data.spots.van and land or nil
end

-- Face world position of a direction on the face of land `land`.
local function on_face(p, land, x, y, z)
  local g = gen.region.info(p.data).g
  local s, t = grid.to_face(g, land.data.face, x, y, z)
  return s - land.data.center[1], -t - land.data.center[2] -- land-local
end

H.new_game_in_van(4040)
local G = gen.world

-- --------------------------------------------------------------- river
-- a land where a river leaves a cell's centre (rivers run from centre to centre)
local land = each_planet(G, function(p)
  local c = p.data.cells
  for i = 1, #c.elevation do
    if c.river[i] and c.flow_to[i] > 0 and c.elevation[i] > 0.4 and not c.lake[i] then
      local l = settled(G, p, mvl.planet_cell(p.data.grid, i))
      if l and #l.data.rivers > 0 then return l end
    end
  end
end)
test.expect(land, "a land on a river")
H.travel_to(land.address)
H.step_outside()
local w = D.world.current
local ld = w.land_node.data
test.expect(#ld.rivers > 0, "the land carries the planet's river")
local r = ld.rivers[1]
-- walk to the river: the water surface is there, the bed is carved below it,
-- the banks rise above it
local p = r.points[math.floor(#r.points / 2) + 1]
D.player.place(p[1] + r.width, p[2], 0)
for _ = 1, 60 do test.wait(1) end
test.expect(w.streamer:chunk_at(p[1], p[2]).river, "river water is drawn")
test.expect(mvl.height(p[1], p[2]) < p[3], "the bed lies below the water surface")
local a, b = r.points[1], r.points[#r.points]
local dx, dz = b[1] - a[1], b[2] - a[2]
local l = math.sqrt(dx * dx + dz * dz)
local px, pz = -dz / l, dx / l
local bank = math.max(mvl.height(p[1] + px * (r.width + 40), p[2] + pz * (r.width + 40)),
                      mvl.height(p[1] - px * (r.width + 40), p[2] - pz * (r.width + 40)))
test.expect(bank > p[3], "the banks rise above the water")
-- downstream the water never rises, and the region's next land carries it on
for i = 2, #r.points do test.expect(r.points[i][3] <= r.points[i - 1][3], "the river flows downhill") end
H.use("Enter the van")
H.finish_dialogue()

-- --------------------------------------------------------------- coast
-- the shoreline between a coastal cell and its ocean neighbour
local shore, toward
land = each_planet(G, function(pl)
  local c, gl = pl.data.cells, pl.data.grid
  for i = 1, #c.elevation do
    if c.elevation[i] > 0.2 and not c.lake[i] then
      for _, j in ipairs(mvl.planet_neighbours(gl, i)) do
        if c.elevation[j] < -0.5 then
          local ix, iy, iz = mvl.planet_cell(gl, i)
          local jx, jy, jz = mvl.planet_cell(gl, j)
          local lo, hi = 0, 1
          for _ = 1, 30 do
            local t = (lo + hi) / 2
            local x, y, z = ix + (jx - ix) * t, iy + (jy - iy) * t, iz + (jz - iz) * t
            local n = math.sqrt(x * x + y * y + z * z)
            if mvl.planet_sample(gl, c.elevation, x / n, y / n, z / n) > 0 then lo = t else hi = t end
          end
          local t = lo
          local x, y, z = ix + (jx - ix) * t, iy + (jy - iy) * t, iz + (jz - iz) * t
          local n = math.sqrt(x * x + y * y + z * z)
          local l2 = settled(G, pl, x / n, y / n, z / n)
          if l2 then
            local sx, sz = on_face(pl, l2, x / n, y / n, z / n)
            local ox, oz = on_face(pl, l2, jx, jy, jz)
            local ax, az = on_face(pl, l2, ix, iy, iz)
            local ddx, ddz = ox - ax, oz - az
            local dl = math.sqrt(ddx * ddx + ddz * ddz)
            shore, toward = { sx, sz }, { ddx / dl, ddz / dl }
            return l2
          end
        end
      end
    end
  end
end)
test.expect(land, "a land on the shoreline")
H.travel_to(land.address)
H.step_outside()
w = D.world.current
local dir = toward
-- the shoreline itself, along the line towards the ocean
local s = -900
while mvl.height(shore[1] + dir[1] * s, shore[2] + dir[2] * s) > 0 and s < 900 do s = s + 2 end
test.expect(s > -900 and s < 900, "the ground meets the sea near the planet's shoreline: " .. s)
local cx, cz = shore[1] + dir[1] * s, shore[2] + dir[2] * s
-- inland the ground rises; towards the planet's ocean it sinks below the sea
test.expect(mvl.height(cx - dir[1] * 300, cz - dir[2] * 300) > 0, "dry land away from the sea")
test.expect(mvl.height(cx + dir[1] * 300, cz + dir[2] * 300) < 0, "below sea level on the ocean side")
D.player.place(cx + dir[1] * 300, cz + dir[2] * 300, 0)
for _ = 1, 60 do test.wait(1) end
test.expect(w.streamer:chunk_at(cx + dir[1] * 300, cz + dir[2] * 300).sea, "the sea surface is drawn")
test.expect(w.land_node.data.coast or w.land_node.data.biome, "the land knows it is on a coast")
-- walking into the sea stops at wading depth
D.player.place(cx - dir[1] * 6, cz - dir[2] * 6, math.atan(-dir[1], -dir[2]))
test.hold("move_y", 2400)
local depth = D.player.floor()
test.expect(depth >= -D.player.wade - 0.1, "the player stops at wading depth, not on the sea floor")
test.expect(depth < 0.5, "the player walked down to the water")
H.use("Enter the van")
H.finish_dialogue()

-- ---------------------------------------------------------------- lake
-- a land on a lake's shore: its water fills the basin below the lake level
local lake, lp
land = each_planet(G, function(pl)
  local c, gl = pl.data.cells, pl.data.grid
  local info = gen.region.info(pl.data)
  for i = 1, #c.elevation do
    if c.lake[i] and c.elevation[i] > 0 then
      local x, y, z = mvl.planet_cell(gl, i)
      local loc = grid.locate(pl.address, info.g, x, y, z)
      local region = G:generate(gen.address.parent(loc.address))
      for _, lk in ipairs(region.data.lakes) do
        if lk.cell == i then
          -- the shore: outwards from the water until a land has people
          local g = info.g
          for k = 0, 40 do
            local d = gen.region.lake_radius(lk, lk.x + 1, lk.z) - 500 + k * 300
            local wx, wz = lk.x + d, lk.z
            local gx, gz = grid.land_xy(g, wx, wz)
            if grid.on_face(g, gx, gz) then
              local l2 = G:generate(grid.address(pl.address, g, loc.face, gx, gz))
              if not l2.data.wild and l2.data.spots.van then
                lake, lp = lk, pl
                return l2
              end
            end
          end
        end
      end
    end
  end
end)
if land then
  H.travel_to(land.address)
  H.step_outside()
  w = D.world.current
  local d = w.land_node.data
  test.expect(#d.lakes > 0, "the land knows the lake")
  local lk = d.lakes[1]
  for _, l2 in ipairs(d.lakes) do if l2.x * l2.x + l2.z * l2.z < lk.x * lk.x + lk.z * lk.z then lk = l2 end end
  -- walking towards the lake's centre: the shore goes down into its water
  local dist = math.sqrt(lk.x * lk.x + lk.z * lk.z)
  local ux, uz = lk.x / dist, lk.z / dist
  local found
  for step = 0, math.floor(math.min(dist, 5000) / 8) do
    local x, z = ux * step * 8, uz * step * 8
    D.player.place(x, z, math.atan(-ux, -uz))
    test.wait(1)
    if mvl.height(x, z) < lk.level - 1 then
      found = { x, z }
      break
    end
  end
  test.expect(found, "the ground dips below the lake's level towards its centre")
  for _ = 1, 60 do test.wait(1) end
  test.expect(w.streamer:chunk_at(found[1], found[2]).lake, "the lake's water is drawn")
  local rec = w.streamer:land_at(found[1], found[2])
  test.expect(gen.region.lake_at(rec.node.data.lakes, found[1] - rec.ox, found[2] - rec.oz, 400),
              "within a lake's shoreline")
else
  mvl.log("no lake on the planets searched")
end
