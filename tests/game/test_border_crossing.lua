-- Crossing a border: the player drives from one country into the next
-- without a loading screen; the ground continues without a seam and the
-- lands on the other side belong to the other country, its people and its
-- language. Walking on, the next region streams in the same way.
local D = game.debug
local gen = D.gen
local grid = gen.grid
local van = D.story.van
local drive = D.drive
local culture = require("gen.culture")

H.new_game_in_van(2727)
local G = gen.world

-- two neighbouring lands of two peoples: the cells of two countries meet
local function border_pair(paddr)
  local p = G:generate(paddr)
  local P = p.data
  local c = P.cells
  if not (c and c.country and P.cultures) then return nil end
  local info = gen.region.info(P)
  local R = gen.region
  for i = 1, #c.elevation do
    local a = c.country[i]
    local ca = a and a > 0 and P.countries[a].culture
    if ca and c.elevation[i] > 0.1 then
      for _, j in ipairs(mvl.planet_neighbours(P.grid, i)) do
        local b = c.country[j]
        local cb = b and b > 0 and P.countries[b].culture
        if cb and cb ~= ca and c.elevation[j] > 0.1 then
          local ix, iy, iz = mvl.planet_cell(P.grid, i)
          local jx, jy, jz = mvl.planet_cell(P.grid, j)
          local x, y, z = (ix + jx) / 2, (iy + jy) / 2, (iz + jz) / 2
          local n = math.sqrt(x * x + y * y + z * z)
          local loc = grid.locate(paddr, info.g, x / n, y / n, z / n)
          for dz = -3, 3 do
            for dx = -4, 4 do
              local gx, gz = loc.gx + dx, loc.gz + dz
              local la, ax, ay, az = R.land_country(P, info, loc.face, gx, gz)
              local lb, bx, by, bz = R.land_country(P, info, loc.face, gx + 1, gz)
              if la == a and lb == b and R.dry(P, info, ax, ay, az) and R.dry(P, info, bx, by, bz) then
                local A = G:generate(grid.address(paddr, info.g, loc.face, gx, gz))
                local B = G:generate(grid.address(paddr, info.g, loc.face, gx + 1, gz))
                if not A.data.wild and not B.data.wild and A.data.culture and B.data.culture then
                  return p, A, B
                end
              end
            end
          end
        end
      end
    end
  end
end

local planet, A, B
for _, s in ipairs(D.story.signals()) do
  if not A then planet, A, B = border_pair(s.address:match("^(.-%.p%d+)")) end
end
for u = 1, 6 do
  for g = 0, 5 do
    if not A then
      local ok, sys = pcall(G.generate, G, "u" .. u .. ".g" .. g .. ".c0.s0")
      for i = 0, ok and sys.data.planets - 1 or -1 do
        if not A and sys.children[i].kind == "rocky" then planet, A, B = border_pair(sys.address .. ".p" .. i) end
      end
    end
  end
end
test.expect(A and B, "two lands of two peoples side by side")
test.expect(A.data.country ~= B.data.country, "in two countries: " .. A.data.country .. ", " .. B.data.country)
test.expect(A.data.culture.name ~= B.data.culture.name, "of two peoples")

-- the van stands near the border, facing it (east is +x)
H.travel_to(A.address)
local w = D.world.current
local S = w.streamer
local border = grid.LAND / 2 -- world x of the border (the anchor land is centred on 0)
local start_z = A.data.spots.van.z
D.story.place_van(w, border - 40, start_z, 0)
H.use("Sit in the driver's seat")
test.expect(drive.active, "at the wheel")
-- drive east until the van is on the other side (moving it on where a tree stops it)
local last_x, stuck, heights, nudges = van.exterior.x, 0, {}, 0
for _ = 1, 400 do
  test.input("move_y", 1)
  test.wait(3)
  local x = van.exterior.x
  heights[#heights + 1] = { x, mvl.height(x, van.exterior.z) }
  if x - last_x < 0.05 then stuck = stuck + 1 else stuck = 0 end
  if stuck > 10 then
    test.input("move_y", 0)
    D.story.place_van(w, x + 6, van.exterior.z, 0)
    stuck, nudges = 0, nudges + 1
  end
  last_x = x
  if x > border + 40 then break end
end
test.input("move_y", 0)
test.expect(van.exterior.x > border + 20, "the van crossed the border: " .. van.exterior.x)
test.expect(nudges <= 2, "driving, not carried: moved past obstacles " .. nudges .. " times")
mvl.log(string.format("border crossing: %s -> %s, %d nudges", A.data.country, B.data.country, nudges))
test.eq(D.world.current, w, "without leaving the world (no loading screen)")
-- the ground continues: no jump between successive positions
local worst = 0
for i = 2, #heights do
  local dx = math.max(0.5, heights[i][1] - heights[i - 1][1])
  worst = math.max(worst, math.abs(heights[i][2] - heights[i - 1][2]) / dx)
end
test.expect(worst < 1.5, "no seam at the border: slope " .. worst)
-- the land the van stands on now is the other country's
local rec = S:land_at(van.exterior.x, van.exterior.z)
test.eq(rec.node.address, B.address, "the van is in the next land")
local d = rec.node.data
test.eq(d.country, B.data.country, "of the other country")
test.eq(d.culture.name, B.data.culture.name, "and its people")
-- they speak their own language: their names are of the other culture
local P = planet.data
local culB
for _, c in ipairs(P.cultures) do if c.name == d.culture.name then culB = c end end
test.eq(d.people[1].name, culture.person_name(culB, mvl.hash(rec.node.seed, "person", 1)).name,
        "named in the other people's language")
test.expect(d.people[1].name ~= A.data.people[1].name, "not the first people's names")
-- their buildings stand in the streamed land
local building
for _, f in ipairs(d.features) do if f.building then building = f end end
test.expect(building, "the other people's village")
test.wait(60)
test.press("back")
test.expect(not drive.active, "parked")

-- ------------------------------------------------- the next region
-- walking on to the next region's border: its lands stream in the same way
H.step_outside()
local p = D.player
local gx = rec.gx
local next_border = ((gx // 16 + 1) * 16 - S.agx) * grid.LAND - grid.LAND / 2
-- (most of the way at once, the last few hundred metres on foot)
local z = start_z
local crossings0 = S.stats.crossings or 0
local prev, jump = nil, 0
for x = math.max(border + 50, next_border - 300), next_border + 60, 4 do
  p.place(x, z, -math.pi / 2)
  test.wait(1)
  local h = mvl.height(x, z)
  if prev then jump = math.max(jump, math.abs(h - prev)) end
  prev = h
end
local there = S:land_at(p.x, p.z)
test.expect(there and there.node.data.region ~= A.data.region, "a land of the next region")
test.expect((S.stats.crossings or 0) > crossings0, "the terrain followed the player across lands")
test.expect(jump < 6, "the ground continues across the region border: " .. jump .. " m per 4 m")
local tiles = 0
for _, r in ipairs(S.land_list) do
  if math.max(math.abs(r.gx - there.gx), math.abs(r.gz - there.gz)) <= 2 then tiles = tiles + 1 end
end
test.expect(tiles >= 2, "pieces of terrain around the player")
