-- A world with two moons: at a moment of its night when both are up, each
-- shows in the sky as a lit disc; between them lies the dark night sky.
G.freeze()
local gen = require("gen")
local sky = gen.sky
local R = gen.run.new(gen.cosmos, { seed = 77, mods = {} })
gen.planet.LEVEL = 3 -- (the sky does not depend on the grid)

local function two_moon_planet()
  for s = 0, 60 do
    local saddr = "u" .. (1 + s % 7) .. ".g" .. (s % 11) .. ".c0.s" .. (s % 5)
    local ok, sys = pcall(R.generate, R, saddr)
    if ok then
      for i = 0, sys.data.planets - 1 do
        local p = sys.children[i]
        if p.kind == "rocky" and #p.moons == 2 then
          local node = R:generate(saddr .. ".p" .. i)
          if not node.data.locked then return node end
        end
      end
    end
  end
end

local planet = two_moon_planet()
test.expect(planet, "a rocky world with two moons")
local H = sky.heavens(planet.data)
test.eq(#H.sky.moons, 2, "two moons in its sky")
-- a moment of the night when both moons stand high and mostly lit
local place, when = { latitude = 20, longitude = 40 }, nil
for i = 0, 40000 do
  local t = i * 0.01
  local at = sky.at(H, place, t)
  local a, b = at.moons[1], at.moons[2]
  if at.sun[2] < -0.3 and a.alt > 0.35 and b.alt > 0.35 and a.lit > 0.65 and b.lit > 0.65 then when = t break end
end
test.expect(when, "both moons up at night")
local at = sky.apply(H, place, when)
local function look(d)
  local l = math.sqrt(d[1] * d[1] + d[2] * d[2] + d[3] * d[3])
  mvl.camera(0, 2, 0, math.atan(-d[1], -d[3]), math.asin(d[2] / l), 70)
end
for i = 1, 2 do
  look(at.moons[i].dir)
  test.wait(3)
  test.screenshot("moon" .. i .. ".tga")
  test.wait(2)
end
-- the other side of the sky, away from both discs: night sky
local a = at.moons[1].dir
look({ -a[1], a[2], -a[3] })
test.wait(3)
test.screenshot("between.tga")
test.wait(2)
