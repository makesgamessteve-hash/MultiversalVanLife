-- Planet skies: Earth's real Moon and Milky Way over the farm, moons whose
-- phases follow their orbits, a locked world's unmoving star, thick and thin
-- air, and the sky in the world bible.
local gen = require("gen")
local sky = gen.sky
gen.planet.LEVEL = 3
local G = gen.run.new(gen.cosmos, { seed = 31, mods = {} })

-- ------------------------------------------------------------ the farm
local earth = G:generate(gen.prime.EARTH)
local H = sky.heavens(earth.data)
local at = sky.at(H, sky.FARM, sky.farm_time(1))
local moon = at.moons[1]
test.expect(at.sun[2] < -0.3, "23:00 on 24 June: the Sun is well below the horizon")
test.expect(at.sun[3] < -0.8, "a summer midnight Sun lies under the northern horizon")
test.expect(moon.alt > 0.1 and moon.lit > 0.7 and moon.lit < 0.8, "a waxing gibbous Moon is up: " .. moon.lit)
test.expect(moon.dir[3] > 0 and moon.dir[1] < 0, "in the south-west")
local core = at.band.core
test.expect(core[3] > 0.9 and core[2] > 0.15 and core[2] < 0.4, "the galactic centre stands low in the south")
local noon = sky.at(H, sky.FARM, sky.farm_time(1) - 11 / 24)
test.expect(math.abs(math.asin(noon.sun[2]) * 180 / math.pi - 68.4) < 1.5, "the midsummer noon Sun at 45°N")
-- phases repeat every synodic month and wane half a month later
local t0 = sky.farm_time(1)
local again = sky.at(H, sky.FARM, t0 + 29.5306).moons[1].lit
test.expect(math.abs(again - moon.lit) < 0.02, "the same phase a synodic month later")
local half = sky.at(H, sky.FARM, t0 + 14.765).moons[1].lit
test.expect(math.abs(half - (1 - moon.lit)) < 0.06, "the opposite phase half a month later")
-- Venus as evening star some nights of the year, the planets in the sky
local seen = {}
for n = 1, 365, 7 do
  for _, p in ipairs(sky.at(H, sky.FARM, sky.farm_time(n) - 3 / 24).planets) do seen[p.name] = true end
end
test.expect(seen.Venus and seen.Jupiter and seen.Mars and seen.Saturn, "the bright planets appear in the sky")
test.expect(not seen.Neptune, "Neptune is too faint to see")

-- --------------------------------------------- moons follow their orbits
local function planets_where(pred)
  local out = {}
  for s = 0, 80 do
    local saddr = "u" .. (1 + s % 7) .. ".g" .. (s % 11) .. ".c0.s" .. (s % 5)
    local ok, sys = pcall(G.generate, G, saddr)
    if ok then
      for i = 0, sys.data.planets - 1 do
        local p = sys.children[i]
        if p.kind == "rocky" then
          local node = G:generate(saddr .. ".p" .. i)
          if pred(node) then out[#out + 1] = node end
        end
      end
    end
    if #out >= 3 then break end
  end
  return out
end

local two = planets_where(function(n) return n.data.sky and #n.data.sky.moons == 2 and not n.data.locked end)[1]
test.expect(two, "a world with two moons")
local TH = sky.heavens(two.data)
local place = { latitude = 10, longitude = 20 }
for i = 1, 2 do
  local m = TH.sky.moons[i]
  local synodic = 1 / (1 / m.period - 1 / two.data.year)
  local a = sky.at(TH, place, 3).moons[i].lit
  local b = sky.at(TH, place, 3 + synodic).moons[i].lit
  test.expect(math.abs(a - b) < 0.03, "moon " .. i .. " repeats its phase after its synodic period")
  local lits = {}
  for k = 0, 7 do lits[#lits + 1] = sky.at(TH, place, 3 + synodic * k / 8).moons[i].lit end
  local lo, hi = math.min(table.unpack(lits)), math.max(table.unpack(lits))
  test.expect(lo < 0.15 and hi > 0.85, "moon " .. i .. " waxes and wanes through its orbit")
end
test.expect(TH.sky.moons[1].period ~= TH.sky.moons[2].period, "each moon keeps its own period")
-- the sky turns with the planet's day
local s1 = sky.at(TH, place, 3).sun
local s2 = sky.at(TH, place, 3 + two.data.day / 2).sun
test.expect(s1[2] * s2[2] < 0 or math.abs(s1[2] - s2[2]) > 0.3, "half a day later the star stands elsewhere")

-- ----------------------------------------------------- locked worlds
local locked = planets_where(function(n) return n.data.sky and n.data.locked end)[1]
test.expect(locked, "a tidally locked world")
do
  local LH = sky.heavens(locked.data)
  local a, b = sky.at(LH, place, 1).sun, sky.at(LH, place, 7.3).sun
  test.expect(math.abs(a[1] - b[1]) + math.abs(a[2] - b[2]) + math.abs(a[3] - b[3]) < 1e-6,
              "a locked world's star never moves in its sky")
  local sub = sky.at(LH, { latitude = 0, longitude = 0 }, 2).sun
  test.expect(sub[2] > 0.99, "the star stands overhead at the substellar point")
  local far = sky.at(LH, { latitude = 0, longitude = 180 }, 2)
  test.expect(far.sun[2] < -0.99 and far.daylight == 0, "and eternal night on the far side")
end

-- --------------------------------------------------- thick and thin air
local white = { 1, 1, 1 }
local thick = sky.atmosphere(40, { "carbon dioxide", "sulphur" }, white)
local earthlike = sky.atmosphere(1, { "nitrogen", "carbon dioxide" }, white)
local thin = sky.atmosphere(0.08, { "carbon dioxide" }, white)
test.expect(thick.haze > earthlike.haze and earthlike.haze > thin.haze, "thicker air is hazier")
test.expect(thick.fog_near < earthlike.fog_near and earthlike.fog_near < thin.fog_near, "fog starts closer in thick air")
test.expect(thick.fog_far < thin.fog_far, "and ends closer")
local function spread(a) -- how far the zenith is from the horizon colour
  local d = 0
  for k = 1, 3 do d = d + math.abs(a.day_top[k] - a.day_horizon[k]) end
  return d
end
test.expect(spread(thick) < spread(thin), "a thick sky is washed out, a thin one deep")
local function lum(c) return c[1] + c[2] + c[3] end
test.expect(lum(thin.day_top) < lum(earthlike.day_top), "thin air leaves the daytime sky dark")
test.expect(sky.atmosphere(0, {}, white).day_stars > 0, "airless worlds see stars by day")
-- the same holds for generated worlds
local dense = planets_where(function(n) return n.data.sky and n.data.atmosphere.pressure > 5 end)[1]
local airy = planets_where(function(n)
  return n.data.sky and n.data.atmosphere.pressure > 0.01 and n.data.atmosphere.pressure < 0.3
end)[1]
test.expect(dense and airy, "generated worlds with thick and with thin air")
do
  local A, B = dense.data.sky.atmosphere, airy.data.sky.atmosphere
  test.expect(A.haze > B.haze and A.fog_near < B.fog_near, "a generated thick-aired world is hazier, with closer fog")
end
-- red light colours the sky
local red = sky.atmosphere(1, { "nitrogen" }, sky.STAR_COLOR.M)
test.expect(red.day_top[1] / red.day_top[3] > earthlike.day_top[1] / earthlike.day_top[3], "a red sun reddens the sky")

-- -------------------------------------------------------- environment
local env, bodies = sky.view(TH, sky.at(TH, place, 3))
test.expect(env.fog_near == TH.sky.atmosphere.fog_near and env.sky_top and env.ambient, "the view sets the environment")
test.eq(#bodies.moons, 2, "both moons are drawn")
test.expect(bodies.sun.size == TH.sky.star.size, "the star at its apparent size")
local nm, np = mvl.sky(bodies)
test.eq(nm, 2, "mvl.sky takes both moons")
test.eq(np, #bodies.planets, "and the planets")

-- ----------------------------------------------------------- the bible
local md = gen.bible.export(G, two.address)
test.expect(md:find("Sky: its star", 1, true), "the bible describes the sky")
test.expect(md:find("2 moons", 1, true), "with its moons")
