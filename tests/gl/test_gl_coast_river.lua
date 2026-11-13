-- Lands follow their planet: standing on a shore the sea is drawn beyond
-- the beach, and standing on a river bank the river's water fills its bed.
-- Lighting is set to full and fog pushed back so the colours can be checked.
local D = game.debug
local gen = D.gen
local landgen = gen.land

-- the first country of a district kind ("shore" or "river") on the rocky
-- planets of a few fixed star systems
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
            for _, n in ipairs(gen.util.sorted_keys(cont.children)) do
              local country = G:generate(cont.address .. ".n" .. n)
              local d = country.data.district
              if d and d.kind == kind and (kind ~= "river" or #country.data.rivers > 0) then return country end
            end
          end
        end
      end
    end
  end
  error("no " .. kind .. " country found")
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

-- a shore land: dry ground towards the land, sea 900 m further out
local country = find_country(G, "shore")
local dir = country.data.district.sea_dir
local T = country.data.terrain
local land
for l = 0, 255 do
  local x, z = landgen.grid(l)
  x, z = x * landgen.SIZE, z * landgen.SIZE
  if landgen.raw_height(T, x - dir[1] * 900, z - dir[2] * 900) > 4 and
     landgen.raw_height(T, x + dir[1] * 900, z + dir[2] * 900) < -4 then land = l break end
end
test.expect(land, "a land on the shore")
arrive(country.address .. ".l" .. land)
-- walk from the dry side towards the sea to the waterline and step back
-- onto the beach
local s = -900
while mvl.height(dir[1] * s, dir[2] * s) > 0 and s < 900 do s = s + 2 end
test.expect(s < 900, "the sea is within reach")
D.player.place(dir[1] * (s - 8), dir[2] * (s - 8), math.atan(-dir[1], -dir[2]))
D.player.pitch = -0.3
test.wait(60)
test.screenshot("coast.tga")
test.wait(3)

-- a river land: on the bank, looking across the river
D.van.enter(D.player, D.world)
D.dialogue.skip_all()
test.wait(5)
country = find_country(G, "river")
local mid = country.data.rivers[1].points[math.floor(#country.data.rivers[1].points / 2) + 1]
local gx, gz = math.floor((mid[1] + landgen.SIZE / 2) / landgen.SIZE), math.floor((mid[2] + landgen.SIZE / 2) / landgen.SIZE)
arrive(country.address .. ".l" .. landgen.index(gx, gz))
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
