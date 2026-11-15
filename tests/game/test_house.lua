-- The house inside the van: a cab with the radio and the atlas (no
-- console), every room of the core reachable on foot through doorways and
-- stairs, storeys that do not block each other, and rooms that build the
-- same every time within a time budget.
local D = game.debug
local van = D.van
local house = van.house
H.new_game_in_van(4242)
H.finish_dialogue()
local P = van.P
local plan = require("gen.house.plan")
local rooms = require("gen.house.rooms")

-- ------------------------------------------------------ not a console
local prompts = {}
for _, it in ipairs(D.world.fixed) do prompts[it.prompt] = true end
test.expect(prompts["Tune the radio"] and prompts["Open the atlas"], "the cab has a radio and an atlas")
for p in pairs(prompts) do test.expect(not p:lower():find("console"), "no console: " .. p) end
test.expect(not van.entities.room and not van.entities.vortex, "the console room and the vortex are gone")

-- ------------------------------------------- walking through the house
-- flood the walkable floor of one storey through the real colliders
local STEP = 0.25
local function flood(x0, z0, level)
  local y = P[2] + level
  local seen, queue, n = {}, { { x0, z0 } }, 0
  local function key(i, j) return i * 4096 + j end
  local i0, j0 = math.floor(x0 / STEP + 0.5), math.floor(z0 / STEP + 0.5)
  seen[key(i0, j0)] = true
  queue[1] = { i0, j0 }
  local head = 1
  while head <= #queue do
    local c = queue[head]
    head = head + 1
    n = n + 1
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      local i, j = c[1] + d[1], c[2] + d[2]
      local k = key(i, j)
      if not seen[k] and math.abs(i * STEP) < 17 and math.abs(j * STEP) < 17 then
        seen[k] = true
        local x, z = i * STEP, j * STEP
        local fl = house.floor_local(x, z, level)
        if math.abs(fl - level) < 0.01 and not mvl.overlaps(P[1] + x, P[3] + z, 0.3, y) then
          queue[#queue + 1] = { i, j }
        end
      end
    end
  end
  return function(x, z)
    for _, c in ipairs(queue) do
      if math.abs(c[1] * STEP - x) < 1.0 and math.abs(c[2] * STEP - z) < 1.0 then return true end
    end
    return false
  end, n
end
local e = van.ENTRY
local reach, cells = flood(e[1], e[2], 0)
test.expect(cells > 3000, "a large ground floor: " .. cells .. " cells")
-- a free spot in each room of a storey (its doorway side is enough)
local function reached(room, fn)
  for x = room.x0 + 0.75, room.x1 - 0.75, 0.5 do
    for z = room.z0 + 0.75, room.z1 - 0.75, 0.5 do
      if fn(x, z) then return true end
    end
  end
  return false
end
for _, room in ipairs(plan.core()) do
  if room.y == 0 then test.expect(reached(room, reach), "the " .. room.id .. " is reached from the hall on foot") end
end
-- the cab's seats, radio and atlas can be reached
test.expect(reach(13.0, 0), "between the seats in the cab")
-- the gallery opens into the house beyond; the garden door is shut
test.expect(reach(0, 16.5) and reach(0, -16.5), "the gallery's ends open into the house beyond the core")
test.expect(not reach(-16.5, -8.75), "the garden door is shut")

-- --------------------------------------------------------- upstairs
-- walks forward for `frames` (Juniper's lines are skipped)
local function walk(frames)
  for _ = 1, math.ceil(frames / 10) do
    H.finish_dialogue()
    test.hold("move_y", 10)
  end
end
-- walk up the stairs from the hall
local pl = D.player
pl.base_y = P[2]
pl.place(P[1] + 2.75, P[3] - 4.0, -math.pi / 2)
test.wait(2)
walk(160)
test.expect(math.abs(pl.base_y - (P[2] + plan.LEVEL)) < 0.01,
            string.format("up the stairs on the landing: %.2f at %.2f, %.2f", pl.base_y - P[2], pl.x - P[1], pl.z - P[3]))
local up, upcells = flood(pl.x - P[1], pl.z - P[3], plan.LEVEL)
test.expect(upcells > 800, "the upper floor: " .. upcells .. " cells")
for _, room in ipairs(plan.core()) do
  if room.y > 0 then test.expect(reached(room, up), "the " .. room.id .. " is reached upstairs") end
end
-- the kitchen table below does not block the bedroom above, and the
-- bedroom's bed does not block the kitchen
test.expect(mvl.overlaps(P[1] + 8.5, P[3] - 10.5, 0.3, P[2]), "the kitchen table blocks the kitchen")
test.expect(not mvl.overlaps(P[1] + 8.5, P[3] - 10.5, 0.3, P[2] + plan.LEVEL), "but not the bedroom above")
test.expect(not mvl.overlaps(P[1] + 11.5, P[3] - 14.5, 0.3, P[2]), "the bed upstairs does not block the kitchen")
-- no falling down the stairwell: the railing holds
pl.place(P[1] + 6.5, P[3] - 2.5, 0)
pl.base_y = P[2] + plan.LEVEL
test.wait(2)
walk(60)
test.expect(math.abs(pl.base_y - (P[2] + plan.LEVEL)) < 0.01 and pl.z - P[3] > -3.3, "the railing keeps the player on the landing")
-- and back down
pl.place(P[1] + 10.5, P[3] - 4.0, math.pi / 2)
test.wait(2)
walk(160)
test.expect(math.abs(pl.base_y - P[2]) < 0.01, string.format("down in the hall again: %.2f", pl.base_y - P[2]))

-- --------------------------------------------------- building rooms
local total = 0
for _, room in ipairs(plan.core()) do
  local t0 = os.clock()
  local a = rooms.build(room, 1)
  total = total + (os.clock() - t0) * 1000
  local b = rooms.build(room, 1)
  test.eq(a.hash, b.hash, "the " .. room.id .. " builds the same every time")
  test.expect(#a.colliders >= 4, "the " .. room.id .. " has walls")
  mvl.release_mesh(a.mesh)
  mvl.release_mesh(b.mesh)
end
-- generous for debug builds with coverage (a release build takes a fraction)
test.expect(total < 4000, string.format("the core builds in %.0f ms", total))
local core = 0
for id in pairs(house.core) do
  local rec = house.built[id]
  core = core + (rec.entity and 1 or 0) + #rec.colliders
end
test.expect(core < 400, "the core is affordable: " .. core .. " entities")
