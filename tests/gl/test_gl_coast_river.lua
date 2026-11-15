-- Lands follow their planet: standing on a shore the sea is drawn beyond
-- the beach, and standing on a river bank the river's water fills its bed.
-- Lighting is set to full and fog pushed back so the colours can be checked.
local D = game.debug
local gen = D.gen

local grid = gen.grid

-- Planets of a few fixed star systems: fn(planet) until it returns something.
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
  error("nothing found")
end

-- The settled land at a direction of a planet, or nil.
local function settled(G, p, x, y, z)
  local addr = grid.locate(p.address, gen.region.info(p.data).g, x, y, z).address
  local land = G:generate(addr)
  return not land.data.wild and land.data.spots.van and land or nil
end

-- Land-local position of a direction on the face of a land.
local function on_face(p, land, x, y, z)
  local s, t = grid.to_face(gen.region.info(p.data).g, land.data.face, x, y, z)
  return s - land.data.center[1], -t - land.data.center[2]
end

local function arrive(addr)
  D.story.travel(addr)
  test.until_true(function() return not D.story.busy end, 1200, "arrived")
  D.dialogue.skip_all()
  D.van.on_door()
  test.until_true(function() return not D.story.busy and not D.van.inside end, 600, "outside")
  D.dialogue.skip_all()
  D.hud.card = nil
  game.draw_ui = function() end
  mvl.environment({ ambient = { 1, 1, 1 }, fog_near = 300, fog_far = 400 })
end

D.progress.reset(4040)
D.start(false)
D.progress.set_flag("van_met")
D.van.enter(D.player, D.world)
D.dialogue.skip_all()
test.wait(5)
local G = gen.world

-- a shore land: where a coastal cell's ground meets its ocean neighbour's sea
local shore, dir
local land = each_planet(G, function(pl)
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
          local x, y, z = ix + (jx - ix) * lo, iy + (jy - iy) * lo, iz + (jz - iz) * lo
          local n = math.sqrt(x * x + y * y + z * z)
          local l2 = settled(G, pl, x / n, y / n, z / n)
          if l2 then
            local sx, sz = on_face(pl, l2, x / n, y / n, z / n)
            local ox, oz = on_face(pl, l2, jx, jy, jz)
            local ax, az = on_face(pl, l2, ix, iy, iz)
            local dl = math.sqrt((ox - ax) ^ 2 + (oz - az) ^ 2)
            shore, dir = { sx, sz }, { (ox - ax) / dl, (oz - az) / dl }
            return l2
          end
        end
      end
    end
  end
end)
arrive(land.address)
-- walk from the dry side towards the sea to the waterline and step back
-- onto the beach
local s = -900
while mvl.height(shore[1] + dir[1] * s, shore[2] + dir[2] * s) > 0 and s < 900 do s = s + 2 end
test.expect(s < 900, "the sea is within reach")
D.player.place(shore[1] + dir[1] * (s - 8), shore[2] + dir[2] * (s - 8), math.atan(-dir[1], -dir[2]))
D.player.pitch = -0.3
test.wait(60)
test.screenshot("coast.tga")
test.wait(3)

-- a river land: on the bank, looking across the river
D.van.enter(D.player, D.world)
D.dialogue.skip_all()
test.wait(5)
-- a river land: where a river leaves a cell's centre
land = each_planet(G, function(p)
  local c = p.data.cells
  for i = 1, #c.elevation do
    if c.river[i] and c.flow_to[i] > 0 and c.elevation[i] > 0.4 and not c.lake[i] then
      local l2 = settled(G, p, mvl.planet_cell(p.data.grid, i))
      if l2 and #l2.data.rivers > 0 then return l2 end
    end
  end
end)
arrive(land.address)
local r = D.world.current.land_node.data.rivers[1]
test.expect(r, "the land has its river")
local p = r.points[math.floor(#r.points / 2) + 1]
local a = r.points[math.floor(#r.points / 2)]
local dx, dz = p[1] - a[1], p[2] - a[2]
local l = math.sqrt(dx * dx + dz * dz)
local nx, nz = -dz / l, dx / l     -- across the river
local back = r.width / 2 + 5
D.player.place(p[1] - nx * back, p[2] - nz * back, math.atan(-nx, -nz))
D.player.pitch = -0.45
test.wait(60)
test.screenshot("river.tga")
test.wait(3)
