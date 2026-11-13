-- Land terrain follows the planet: a river crosses its lands along the
-- planet's course, and on a coast the ground sinks to the sea on the side
-- where the planet has its ocean.
local D = game.debug
local gen = D.gen
local landgen = gen.land

-- Finds a country of the given district kind ("shore" or "river").
local function find_country(G, kind)
  for s = 0, 40 do
    local saddr = "u" .. (1 + s % 6) .. ".g" .. (s % 9) .. ".c0.s" .. (s % 4)
    local ok, sys = pcall(G.generate, G, saddr)
    if ok then
      for i = 0, sys.data.planets - 1 do
        if sys.children[i].kind == "rocky" then
          local p = G:generate(saddr .. ".p" .. i)
          for k = 0, (p.data.continents or 0) - 1 do
            local cont = G:generate(p.address .. ".k" .. k)
            for nidx in pairs(cont.children) do
              local country = G:generate(cont.address .. ".n" .. nidx)
              if country.data.district and country.data.district.kind == kind and
                 (kind ~= "river" or #country.data.rivers > 0) then
                return country
              end
            end
          end
        end
      end
    end
  end
end

H.new_game_in_van(4040)
local G = gen.world

-- --------------------------------------------------------------- river
local country = find_country(G, "river")
test.expect(country, "a country with a river")
local river = country.data.rivers[1]
-- the land the river's middle passes through
local mid = river.points[math.floor(#river.points / 2) + 1]
local gx, gz = math.floor((mid[1] + 1024) / 2048), math.floor((mid[2] + 1024) / 2048)
local addr = country.address .. ".l" .. landgen.index(gx, gz)
H.travel_to(addr)
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
-- downstream the water never rises
for i = 2, #r.points do test.expect(r.points[i][3] <= r.points[i - 1][3], "the river flows downhill") end
H.use("Enter the van")
H.finish_dialogue()

-- --------------------------------------------------------------- coast
country = find_country(G, "shore")
test.expect(country, "a country on a coast")
local dir = country.data.district.sea_dir
test.expect(dir, "the district knows where the sea lies")
-- a land the shoreline crosses: ground above and below sea level
local T = country.data.terrain
local found
for l = 0, 255 do
  local x, z = landgen.grid(l)
  x, z = x * 2048, z * 2048
  local hi, lo = landgen.raw_height(T, x - dir[1] * 900, z - dir[2] * 900), landgen.raw_height(T, x + dir[1] * 900, z + dir[2] * 900)
  if hi > 4 and lo < -4 then found = l break end
end
test.expect(found, "a land on the shoreline")
H.travel_to(country.address .. ".l" .. found)
H.step_outside()
w = D.world.current
-- inland the ground rises; towards the planet's ocean it sinks below the sea
test.expect(mvl.height(-dir[1] * 900, -dir[2] * 900) > 0, "dry land away from the sea")
test.expect(mvl.height(dir[1] * 900, dir[2] * 900) < 0, "below sea level on the ocean side")
D.player.place(dir[1] * 900, dir[2] * 900, 0)
for _ = 1, 60 do test.wait(1) end
test.expect(w.streamer:chunk_at(dir[1] * 900, dir[2] * 900).sea, "the sea surface is drawn")
test.expect(w.land_node.data.coast or w.land_node.data.biome, "the land knows it is on a coast")
-- walking into the sea stops at wading depth
local s = -900
while mvl.height(dir[1] * s, dir[2] * s) > 0 and s < 900 do s = s + 2 end
D.player.place(dir[1] * (s - 6), dir[2] * (s - 6), math.atan(-dir[1], -dir[2]))
test.hold("move_y", 2400)
local depth = D.player.floor()
test.expect(depth >= -D.player.wade - 0.1, "the player stops at wading depth, not on the sea floor")
test.expect(depth < 0.5, "the player walked down to the water")
