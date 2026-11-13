-- Planets: physics from star and orbit, tectonics and mountains, geology
-- and ore, magic geography, the bible and the checker.
local gen = require("gen")
local P = gen.planet
local function runner(seed) return gen.run.new(gen.cosmos, { seed = seed, mods = {} }) end

-- Rocky planets of a system (addresses).
local function rocky_planets(G, saddr)
  local sys = G:generate(saddr)
  local out = {}
  for i = 0, sys.data.planets - 1 do
    if sys.children[i].kind == "rocky" then out[#out + 1] = saddr .. ".p" .. i end
  end
  return out, sys
end

-- Bulk runs use a coarse grid (the same kernels, 642 cells).
P.LEVEL = 3

-- -------------------------------- physics over 200 seeds, red dwarfs
local close_red, locked_or_slow, reddish, short_year = 0, 0, 0, 0
local checked = 0
for seed = 1, 200 do
  local G = runner(seed * 31)
  local list, sys = rocky_planets(G, "u2.g1.c0.s" .. (seed % 6))
  for _, addr in ipairs(list) do
    local p = G:generate(addr)
    checked = checked + 1
    if sys.data.star.class == "M" and p.summary.a < 0.15 then
      close_red = close_red + 1
      if p.data.locked or p.data.day > 10 then locked_or_slow = locked_or_slow + 1 end
      if p.data.light[1] > p.data.light[3] + 0.2 then reddish = reddish + 1 end
      if p.data.year < 60 then short_year = short_year + 1 end
    end
  end
  local problems = gen.check.run(G)
  test.eq(#problems, 0, "seed " .. seed .. ": " .. (problems[1] and problems[1].message or ""))
end
test.expect(checked > 100, "many planets checked: " .. checked)
test.expect(close_red >= 10, "planets close to red dwarfs: " .. close_red)
test.expect(locked_or_slow / close_red >= 0.7, "close to a red dwarf: locked or slow (" .. locked_or_slow .. "/" .. close_red .. ")")
test.eq(reddish, close_red, "red dwarf light is reddish")
test.eq(short_year, close_red, "and the year is short")

-- ------------------ collisions build mountains, old mountains hold ore
P.LEVEL = 5
local mountain, mn, plain, pn = 0, 0, 0, 0
local old_metal, old_n, basin_metal, basin_n = 0, 0, 0, 0
local planets = 0
local G = runner(77)
for s = 0, 5 do
  for _, addr in ipairs((rocky_planets(G, "u1.g0.c0.s" .. s))) do
    local p = G:generate(addr)
    if p.data.cells and p.data.active then
      planets = planets + 1
      local c = p.data.cells
      for i = 1, #c.elevation do
        local cont = p.data.plates[c.plate[i]].continental
        if c.setting[i] == P.SETTING.orogen and c.boundary[i] == 1 and c.dist[i] < 1 then
          mountain, mn = mountain + c.elevation[i], mn + 1
        elseif cont and c.boundary[i] ~= 1 and c.dist[i] > 4 and c.elevation[i] > 0 then
          plain, pn = plain + c.elevation[i], pn + 1
        end
        if c.setting[i] == P.SETTING["old orogen"] then
          old_n = old_n + 1
          if c.deposit[i] == 1 then old_metal = old_metal + 1 end
        elseif c.setting[i] == P.SETTING.basin then
          basin_n = basin_n + 1
          if c.deposit[i] == 1 then basin_metal = basin_metal + 1 end
        end
      end
    end
  end
end
test.expect(planets >= 2, "active planets: " .. planets)
test.expect(mn > 0 and pn > 0 and mountain / mn > plain / pn + 1.5,
            string.format("mountains where continents collide (%.1f km vs %.1f km)", mountain / mn, plain / pn))
test.expect(old_n > 0 and basin_n > 0 and old_metal / old_n > 2 * basin_metal / basin_n,
            string.format("old mountain belts hold more ore (%d/%d) than young basins (%d/%d)", old_metal, old_n,
                          basin_metal, basin_n))

-- ---------------------------------------- magic follows its source
local function universe_with(source)
  local U = runner(5)
  for u = 1, 60 do
    if U:generate("u" .. u).data.laws.magic == source then return U, "u" .. u end
  end
end
local U, uaddr = universe_with("tectonic")
test.expect(uaddr, "a universe with tectonic magic")
local tested = false
for g = 0, 6 do
  local galaxy = U:generate(uaddr .. ".g" .. g)
  if galaxy.data.clusters > 0 and not tested then
    local cl = U:generate(galaxy.address .. ".c0")
    for s = 0, cl.data.stars - 1 do
      for _, addr in ipairs((rocky_planets(U, cl.address .. ".s" .. s))) do
        local p = U:generate(addr)
        if not tested and p.data.cells and p.data.active and p.data.cells.magic then
          local c = p.data.cells
          local near, nn, far, fn = 0, 0, 0, 0
          for i = 1, #c.magic do
            if c.boundary[i] ~= 0 and c.dist[i] < 1 then near, nn = near + c.magic[i], nn + 1
            elseif c.dist[i] > 4 then far, fn = far + c.magic[i], fn + 1 end
          end
          test.expect(near / nn > 2 * far / fn, "tectonic magic is strongest along plate boundaries")
          local peak = p.data.magic.peak_cell
          test.expect(c.dist[peak] <= 1.5, "the strongest magic lies at a boundary or volcano")
          tested = true
        end
      end
    end
  end
end
test.expect(tested, "a planet with tectonic magic was found")

-- ------------------------------------------------ bible and checker
local planet = rocky_planets(G, "u1.g0.c0.s0")[1]
local md = gen.bible.export(G, planet)
test.expect(md:find("## Planet " .. planet, 1, true), "the bible has a planet section")
test.expect(md:find("Earth radii, gravity", 1, true) and md:find("tectonic plates", 1, true), "physics and plates described")
test.expect(md:find("**elevation**: 10242 values", 1, true), "cell fields are summarised, not listed")
local lines = 0
for _ in md:gmatch("\n") do lines = lines + 1 end
test.expect(lines < 800, "the bible stays readable: " .. lines .. " lines")
test.eq(#gen.check.run(G), 0, "the reference planets pass the checker")
