-- Two animal species of one world with different body plans, side by side
-- and drawn with their moving parts: their shapes and colours differ.
G.freeze()
mvl.terrain({ seed = 1, amp = 0 }) -- flat ground at 0
local gen = require("gen")
gen.planet.LEVEL = 3
local R = gen.run.new(gen.cosmos, { seed = 31, mods = {} })
local HAB = gen.life.habitats
local cache = require("gen.visuals.models").new({ budget = 1000 })
local C = require("lib.creatures").new(nil, cache)

local planet, a, b
for s = 0, 300 do
  local saddr = "u" .. (1 + s % 7) .. ".g" .. (s % 11) .. ".c" .. (s % 3) .. ".s" .. (s % 5)
  local ok, sys = pcall(R.generate, R, saddr)
  if ok then
    for i = 0, sys.data.planets - 1 do
      if not planet and sys.children[i].kind == "rocky" then
        local p = R:generate(saddr .. ".p" .. i)
        local L = p.data.life
        if L and L.complexity == "animals" then
          for _, x in ipairs(L.species) do
            for _, y in ipairs(L.species) do
              if not a and x.kind == "animal" and y.kind == "animal" and x.move == "walk" and y.move == "walk" and
                 x.limbs ~= y.limbs and x.limbs > 0 and y.limbs > 0 then a, b, planet = x, y, p end
            end
          end
        end
      end
    end
  end
  if planet then break end
end
test.expect(planet, "a world with two walking species of different body plans")
local L = planet.data.life
local function entry(sp)
  return { id = sp.id, colors = sp.colors, sprite = "critter_walker", mode = "all", w = 1, h = 1,
           model = HAB.model(L, sp, planet.seed), behaviour = { kind = "prowler", speed = 0 } }
end
mvl.environment({ sky_top = { 0, 0, 1 }, sky_horizon = { 0, 0, 1 }, fog_color = { 0, 0, 1 }, fog_near = 400, fog_far = 500,
                  ambient = { 1, 1, 1 }, sun_color = { 0, 0, 0 }, stars = 0 })
mvl.sky({})
local chunk = {}
local rng = mvl.rng(5)
local ca = C:spawn(entry(a), -1.6, -5, chunk, nil, rng)
local cb = C:spawn(entry(b), 1.6, -5, chunk, nil, rng)
-- the same size on screen, facing the camera's right
for _, cr in ipairs({ ca, cb }) do
  cr.scale = 1.4 / math.max(cr.sp.model.size, 0.2)
  cr.yaw, cr.speed = -math.pi / 2, 0
end
for _ = 1, 3 do
  for _, cr in ipairs({ ca, cb }) do
    C:place(cr, 5)
    C:animate(cr, 0.016)
  end
  test.wait(1)
end
test.eq(ca.mode, "near", "drawn with parts")
test.eq(#ca.parts.legs, a.limbs, "one leg entity per limb (" .. a.limbs .. ")")
test.eq(#cb.parts.legs, b.limbs, "one leg entity per limb (" .. b.limbs .. ")")
test.expect(ca.model.hash ~= cb.model.hash, "different body models")
local ka, kb = a.colors[2], b.colors[2]
test.expect(ka[1] ~= kb[1] or ka[2] ~= kb[2] or ka[3] ~= kb[3], "different colours")
mvl.camera(0, 0.9, -2.4, 0, -0.25, 60)
test.wait(3)
test.screenshot("two.tga")
test.wait(2)
C:clear()
cache:clear()
