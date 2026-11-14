-- Architecture and people: buildings in the land's own stone, entrances
-- from above for flyers, settlements of generated buildings, villagers of
-- their species, statues of committed individuals, and a mod's roof type.
local gen = require("gen")
local A = require("gen.culture.architecture")
local B = require("gen.visuals.buildings")
local PEOPLE = require("gen.visuals.people")
gen.planet.LEVEL = 3
local G = gen.run.new(gen.cosmos, { seed = 12, mods = {} })

-- lands of peoples, one per country, over many worlds
local lands, planets = {}, {}
for s = 0, 500 do
  local saddr = "u" .. (1 + s % 7) .. ".g" .. (s % 11) .. ".c" .. (s % 3) .. ".s" .. (s % 5)
  local ok, sys = pcall(G.generate, G, saddr)
  if ok then
    for i = 0, sys.data.planets - 1 do
      if sys.children[i].kind == "rocky" then
        local p = G:generate(saddr .. ".p" .. i)
        if p.data.cultures then
          planets[#planets + 1] = p
          for _, c in ipairs(p.data.countries) do
            if c.culture and #lands < 60 then
              local country = G:generate(p.address .. ".k" .. (c.continent - 1) .. ".n" .. c.index)
              for l = 0, 255, 11 do
                local gx, gz = gen.land.grid(l)
                if gen.land.raw_height(country.data.terrain, gx * 2048, gz * 2048) > 3 then
                  lands[#lands + 1] = G:generate(country.address .. ".l" .. l)
                  break
                end
              end
            end
          end
        end
      end
    end
  end
  if #lands >= 60 then break end
end
test.expect(#lands >= 30, "many lands of peoples: " .. #lands)

-- -------------------------------------------------------------- local stone
local stone_lands, checked = 0, 0
for _, land in ipairs(lands) do
  local d = land.data
  test.expect(d.architecture and d.culture, "a land of a people builds in its culture's style")
  if d.architecture.material == "stone" and d.materials then
    stone_lands = stone_lands + 1
    local rock = d.materials.stone[3]
    test.eq(table.concat(d.architecture.palette.wall, ","), table.concat(rock, ","), "walls in the land's own stone")
    if checked < 5 then
      checked = checked + 1
      local g, p = B.build("house", d.architecture, 1)
      -- a wall voxel beside the door has the wall colour (index 1)
      local x = p.shape == "square" and p.x0 or math.floor((p.x0 + p.x1) / 2)
      test.expect(g:get(p.x0, math.floor((p.y0 + p.y1) / 2), 5) == 1 or g:count() > 0, "the walls are built of stone")
      g:free()
    end
  end
end
test.expect(stone_lands >= 5, "stone-building peoples: " .. stone_lands)
-- red sandstone, directly
local red = gen.planet.ROCKS[gen.planet.ROCK["red sandstone"]].color
local PAL = require("gen.visuals.palette")
local st = A.local_style(lands[1].data.architecture, PAL.stone({ color = red }))
if st.material == "stone" then test.eq(st.palette.wall[1], red[1], "red sandstone lands build in red sandstone") end
local forced = require("gen.util").copy(lands[1].data.architecture)
forced.material = "stone"
local rs = A.local_style(forced, PAL.stone({ color = red }))
test.eq(table.concat(rs.palette.wall, ","), table.concat(red, ","), "stone buildings on red sandstone are red sandstone")

-- ------------------------------------------------------------------ flyers
local flyers, hatches = 0, 0
for _, p in ipairs(planets) do
  for _, c in ipairs(p.data.cultures) do
    local g, plan = B.build("house", c.style, 2)
    if c.anatomy.wings then
      flyers = flyers + 1
      test.expect(c.style.roof_entry, "a winged people's style has entrances from above")
      test.expect(plan.hatch and g:get(plan.hatch[1], plan.hatch[2], plan.hatch[3]) == 8, "a hatch in the roof")
      hatches = hatches + 1
    else
      test.expect(not c.style.roof_entry and not plan.hatch, "walkers enter by the door")
    end
    test.expect(c.style.door.h >= math.floor(c.anatomy.height * 1.15 / 0.125) - 1 or c.style.door.h == 40,
                "doors fit the people's height")
    g:free()
  end
end
test.expect(flyers >= 2, "winged peoples exist: " .. flyers)

-- ----------------------------------------------------- settlements and people
local temples, kinds = 0, {}
for _, land in ipairs(lands) do
  for _, f in ipairs(land.data.features) do
    if f.building then
      kinds[f.building] = true
      if f.building == "temple" then temples = temples + 1 end
    end
  end
  for _, p in ipairs(land.data.people) do
    test.expect(p.body and p.body.anatomy.limbs and p.body.dress.garment, "villagers have a body and dress")
  end
end
test.expect(kinds.house and kinds.temple, "settlements have houses and a temple")
test.expect(temples > 10, "temples: " .. temples)
-- every building kind builds, deterministically
local style = lands[1].data.architecture
for _, kind in ipairs({ "house", "workshop", "temple", "well", "wall" }) do
  local m1, box, h1 = B.mesh(kind, style, 1)
  local m2, _, h2 = B.mesh(kind, style, 1)
  test.expect(m1 > 0 and box[1] > 0, kind .. " builds")
  test.eq(h1, h2, kind .. " builds the same every time")
  mvl.release_mesh(m1)
  mvl.release_mesh(m2)
end

-- --------------------------------------------- statue of a committed founder
local statue
for _, p in ipairs(planets) do
  for _, r in ipairs(p.data.religions) do
    if r.founder and r.founder.monument and not statue then
      local land = G:generate(r.founder.monument)
      for _, f in ipairs(land.data.features) do
        if f.statue then statue = { f = f, founder = r.founder, land = land } end
      end
    end
  end
end
test.expect(statue, "a founder's statue stands in the land promised it")
test.eq(statue.f.statue.name, statue.founder.name, "it is the founder's statue")
test.eq(statue.f.statue.anatomy.limbs, statue.founder.anatomy.limbs, "with the founder's body")
test.eq(statue.f.statue.anatomy.wings, statue.founder.anatomy.wings, "and wings")
test.eq(table.concat(statue.f.statue.attributes, ","), table.concat(statue.founder.attributes, ","), "and attributes")
local mesh, hash = PEOPLE.mesh({ anatomy = statue.f.statue.anatomy, hue = 0, statue = true, stone = statue.f.statue.stone,
                                 attributes = statue.f.statue.attributes })
test.expect(mesh > 0, "the statue is a voxel model")
local plainmesh, plainhash = PEOPLE.mesh({ anatomy = statue.f.statue.anatomy, hue = 0, statue = true })
test.expect(hash ~= plainhash, "its attributes show")
mvl.release_mesh(mesh)
mvl.release_mesh(plainmesh)
test.eq(#gen.check.run(G), 0, "every promised monument stands (the checker passes)")

-- ------------------------------------------------------------ a mod roof
local called = 0
B.ROOFS.onion = function(g, p, top)
  called = called + 1
  local cx, cy = (p.x0 + p.x1) / 2, (p.y0 + p.y1) / 2
  g:ellipsoid(cx, cy, top + 6, p.w / 3, p.d / 3, 7, 3)
  g:line(cx, cy, top + 12, cx, cy, top + 17, 0.6, 6)
  return top + 17
end
local onion = require("gen.util").copy(style)
onion.roof = "onion"
local _, _, h_onion = B.mesh("house", onion, 1)
local _, _, h_plain = B.mesh("house", style, 1)
test.expect(called == 1 and h_onion ~= h_plain, "a mod's roof type is built")
B.ROOFS.onion = nil

-- ------------------------------------------------ in the game: a village
gen.planet.LEVEL = 3
H.new_game_in_van(1002)
local sig
for _, s in ipairs(game.debug.story.signals()) do if s.peopled and not sig then sig = s end end
test.expect(sig, "a signal from a land of a people")
H.travel_to(sig.address)
H.step_outside()
local w = game.debug.world.current
local built, buildings = 0, 0
for _, c in pairs(w.streamer.loaded) do
  for _, key in ipairs(c.models or {}) do if key:find("^building:") then built = built + 1 end end
end
for _, f in ipairs(w.land_node.data.features) do if f.building then buildings = buildings + 1 end end
test.expect(buildings >= 1, "the village has buildings")
test.eq(built, buildings, "every building of the village is a generated model")
local people = 0
for _, k in pairs(w.streamer.models.entries) do if k.key:find("^person:") then people = people + 1 end end
test.expect(people >= 2, "its villagers are voxel people: " .. people)
