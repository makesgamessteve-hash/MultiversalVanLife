-- Buildings at human scale: sized from the height of the people who build
-- them, long buildings from joined modules, within a time budget, and laid
-- out by their footprints without overlapping, doors free, over 200 seeds.
local gen = require("gen")
local B = require("gen.visuals.buildings")
local land = require("gen.levels.land")

local base = {
  material = "timber", plan = "square", roof = "gable", pitch = 0.7, wall = 1, door = { h = 16, w = 7 }, height = 1.7,
  roof_entry = false, ornament = "none", sky_faith = false, storeys = 1,
  palette = { wall = { 180, 140, 100 }, wall_dark = { 130, 100, 70 }, roof = { 150, 70, 50 }, roof_dark = { 110, 50, 34 },
              wood = { 110, 76, 46 }, accent = { 200, 160, 60 } },
}
local function style(over)
  local s = require("gen.util").copy(base)
  for k, v in pairs(over or {}) do s[k] = v end
  return s
end

-- ---------------------------------------------------------- a village house
for seed = 1, 5 do
  local p = B.plan("house", style(), seed)
  local m = p.metres
  test.expect(m.w >= 9 and m.w <= 11.1 and m.d >= 7 and m.d <= 9.1, "a village house is about 10 x 8 m: " .. m.w .. " x " .. m.d)
  test.expect(p.storeys >= 2, "two storeys or more: " .. p.storeys)
  test.expect(m.storey >= 2.99 and m.storey <= 3.1, "storeys of 3 m: " .. m.storey)
  test.expect(math.abs(m.door - 2.125) < 0.13, "a door about 2.1 m tall: " .. m.door)
  test.expect(m.door_w >= 1.1, "and wide enough for the player: " .. m.door_w)
end
local cottage = B.plan("cottage", style(), 1)
test.expect(cottage.storeys == 1 and cottage.metres.w < 9, "a cottage is smaller and single-storeyed")
-- every kind builds, deterministically, with doors on the ground
for _, kind in ipairs({ "cottage", "house", "workshop", "barn", "inn", "hall", "temple", "well", "wall" }) do
  local t0 = os.clock()
  local mesh, box, h1, plan = B.mesh(kind, style(), 2)
  local ms = (os.clock() - t0) * 1000
  local mesh2, _, h2 = B.mesh(kind, style(), 2)
  test.expect(mesh > 0 and box[1] > 0, kind .. " builds")
  test.eq(h1, h2, kind .. " builds the same every time")
  -- model-time budget (debug builds with coverage are the slowest)
  local budget = (kind == "temple" or kind == "hall" or kind == "inn" or kind == "barn") and 800 or 250
  test.expect(ms < budget, string.format("%s meshes within %d ms: %.1f ms", kind, budget, ms))
  mvl.release_mesh(mesh)
  mvl.release_mesh(mesh2)
end

-- ------------------------------------------------------------ giant people
local giant = B.plan("house", style({ height = 2.5 }), 1)
local small = B.plan("house", style({ height = 1.0 }), 1)
local normal = B.plan("house", style(), 1)
test.expect(math.abs(giant.metres.storey - 4.375) < 0.13, "a 2.5 m people's storeys are 4.4 m: " .. giant.metres.storey)
test.expect(math.abs(giant.metres.door - 3.125) < 0.13, "and their doors 3.1 m: " .. giant.metres.door)
test.expect(giant.metres.w > normal.metres.w * 1.3, "their houses are larger: " .. giant.metres.w .. " m wide")
test.expect(small.metres.storey >= 3.0 and small.metres.door >= 2.0, "a small people's houses still fit the player")

-- ----------------------------------------------------------- a long hall
local parts = B.parts("hall", style(), 5, 40)
test.eq(#parts, 2, "a 40 m hall is built from two modules")
local grids = {}
for i, part in ipairs(parts) do
  local g, p = B.build("hall", style(), 5, part.opts)
  grids[i] = { g = g, p = p, offset = part.offset }
end
local a, b = grids[1], grids[2]
test.expect(math.abs((a.offset + a.p.metres.w / 2) - (b.offset - b.p.metres.w / 2)) < 0.01, "the modules meet without a gap")
test.eq(a.p.d, b.p.d, "the same depth")
test.eq(a.p.top, b.p.top, "the same walls")
local function roof_top(x, gr)
  local cy = math.floor((gr.p.y0 + gr.p.y1) / 2)
  for z = gr.p.gz - 1, 0, -1 do if gr.g:get(x, cy, z) ~= 0 then return z end end
  return -1
end
test.eq(roof_top(a.p.x1, a), roof_top(b.p.x0, b), "the roof runs on at the same height")
local cy = math.floor((a.p.y0 + a.p.y1) / 2)
local walls = true
for z = 1, a.p.top - 1 do
  if a.g:get(a.p.x1, a.p.y0, z) == 0 or b.g:get(b.p.x0, b.p.y0, z) == 0 then walls = false end
end
test.expect(walls, "and so do the walls")
test.expect(not a.p.door.none ~= not b.p.door.none, "one module has the door")
a.g:free()
b.g:free()

-- -------------------------------------------- layouts over 200 seeds
gen.planet.LEVEL = 3
local lands, buildings, doors = 0, 0, 0
for seed = 1, 200 do
  local G = gen.run.new(gen.cosmos, { seed = seed, mods = {} })
  local p = gen.stats.world(G, seed)
  local c = p and p.data.countries[1]
  if c then
    local cid = 1
    for id, cc in ipairs(p.data.countries) do if cc.culture and not c.culture then c, cid = cc, id end end
    -- a land on dry ground, as the signals choose them
    local pick = gen.country_land(p, cid, 1 + seed % 6)
    local l = pick and G:generate(pick)
    local d = l and l.data or { features = {} }
    if l then lands = lands + 1 end
    test.expect(not l or (d.buildings_left_out or 0) == 0, "every building of a dry land finds a place (seed " .. seed .. ")")
    local boxes = {}
    for _, f in ipairs(d.features) do
      if f.role == "building" and f.box and f.box[1] > 2 then
        boxes[#boxes + 1] = { f = f, q = { x = f.x, z = f.z, hw = f.box[1] / 2, hd = f.box[2] / 2, yaw = f.yaw or 0 } }
      end
    end
    for i = 1, #boxes do
      buildings = buildings + 1
      for j = i + 1, #boxes do
        test.expect(not land.boxes_overlap(boxes[i].q, boxes[j].q),
                    string.format("buildings never overlap (seed %d: %s and %s)", seed, boxes[i].f.id, boxes[j].f.id))
      end
      -- the way to the door is free (generated buildings: their front faces -z when unturned)
      local q = boxes[i].q
      if boxes[i].f.building then
        doors = doors + 1
        local fx, fz = -math.sin(q.yaw), -math.cos(q.yaw)
        local px, pz = q.x + fx * (q.hd + 1.5), q.z + fz * (q.hd + 1.5)
        for j = 1, #boxes do
          if j ~= i then test.expect(not land.inside_box(boxes[j].q, px, pz, 0), "the door of " .. boxes[i].f.id .. " is free") end
        end
        local plan = B.plan(boxes[i].f.building, d.architecture, boxes[i].f.variant or 0)
        if boxes[i].f.building ~= "well" then
          test.expect(plan.metres.door >= 2.0 and plan.metres.door_w >= 1.1, "the player fits through the door")
        end
      end
      local h = land.raw_height(d.terrain, q.x + d.center[1], q.z + d.center[2])
      test.expect(h > 0.5, "buildings stand on dry ground: " .. h)
    end
  end
end
test.expect(lands >= 150 and buildings >= 450 and doors >= 350, string.format("%d lands, %d buildings, %d doors checked",
            lands, buildings, doors))
