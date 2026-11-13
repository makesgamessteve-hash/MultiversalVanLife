-- The farm's night sky: the real Moon with its phase on the first night of
-- the story (24 June 2026, a waxing gibbous Moon) and the Milky Way. The
-- camera rises above the farm so that nothing hides the sky.
local D = game.debug
D.progress.reset(20261113)
D.start(false)
D.dialogue.skip_all()
test.wait(5)
local w = D.world.current
local sky = D.gen.sky
local at = sky.at(w.sky.heavens, w.sky.place, w.sky.time)
local moon = at.moons[1]
test.expect(at.sun[2] < -0.2, "it is night at the farm")
test.expect(moon.alt > 0.1, "the Moon is up")
test.expect(moon.lit > 0.6 and moon.lit < 0.9, "a waxing gibbous Moon: " .. moon.lit)
game.update = function() end
game.draw_ui = function() end
local function look(d) mvl.camera(0, 80, 0, math.atan(-d[1], -d[3]), math.asin(d[2]), 70) end
local function unit(x, y, z)
  local l = math.sqrt(x * x + y * y + z * z)
  return { x / l, y / l, z / l }
end
look(moon.dir)
test.wait(3)
test.screenshot("moon.tga")
test.wait(2)
-- a point of the band high above the galactic core, and a point well off it
local n, c = at.band.normal, at.band.core
local v = unit(c[1], c[2] + 1.2, c[3])
local k = v[1] * n[1] + v[2] * n[2] + v[3] * n[3]
local on = unit(v[1] - n[1] * k, v[2] - n[2] * k, v[3] - n[3] * k)
test.expect(on[2] > 0.3, "that part of the band is high in the sky")
look(on)
test.wait(3)
test.screenshot("band.tga")
test.wait(2)
local off = unit(on[1] + n[1] * 0.8, on[2] + n[2] * 0.8, on[3] + n[3] * 0.8)
if off[2] < 0.3 then off = unit(on[1] - n[1] * 0.8, on[2] - n[2] * 0.8, on[3] - n[3] * 0.8) end
look(off)
test.wait(3)
test.screenshot("off_band.tga")
test.wait(2)
