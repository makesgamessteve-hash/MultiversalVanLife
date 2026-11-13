-- The farm is generated from the save's seed: two journeys get different
-- farms, but both have a farmhouse, a neighbour and the van at the gate.
local D = game.debug
local gen = D.gen

local function journey(seed)
  D.progress.reset(seed)
  D.start(false)
  test.wait(5)
  H.finish_dialogue()
  local land = D.world.current.land_node
  test.eq(land.address, gen.prime.FARM, "the farm is the Prime farm land")
  local d = land.data
  local roles = {}
  for _, f in ipairs(d.features) do roles[f.role] = (roles[f.role] or 0) + 1 end
  test.expect(roles.farmhouse == 1 and roles.barn == 1 and roles.well == 1, "farmhouse, barn and well")
  test.expect((roles.fence or 0) >= 6, "a fence")
  test.expect(#d.fields >= 1, "fields")
  test.expect(#d.roads >= 2, "the old road and the farm lane")
  -- the neighbour is there
  local n = H.find("Talk to " .. d.neighbour.name)
  test.expect(n, "the neighbour " .. d.neighbour.name .. " can be talked to")
  -- the van is parked at the gate, the gate in the fence
  local v, gate = D.van.exterior, d.spots.gate
  test.expect(math.sqrt((v.x - gate.x) ^ 2 + (v.z - gate.z) ^ 2) < 6, "the van waits at the gate")
  test.expect(H.find("Enter the van"), "the van's door")
  return d
end

local a = journey(1111)
local b = journey(2222)
local function layout(d)
  local parts = {}
  for _, f in ipairs(d.features) do parts[#parts + 1] = string.format("%s@%.1f,%.1f", f.role, f.x, f.z) end
  for _, f in ipairs(d.fields) do parts[#parts + 1] = string.format("field@%.1f,%.1f", f.x, f.z) end
  return table.concat(parts, " ")
end
test.expect(layout(a) ~= layout(b), "two journeys, two different farms")
-- the same seed gives the same farm again
local a2 = journey(1111)
test.eq(layout(a2), layout(a), "the same seed, the same farm")
-- the farmhouse stays recognisable: the gate and van spot sit at the same
-- place relative to it
local function relative(d)
  local house
  for _, f in ipairs(d.features) do if f.role == "farmhouse" then house = f end end
  local c, s = math.cos(house.yaw), math.sin(house.yaw)
  local dx, dz = d.spots.gate.x - house.x, d.spots.gate.z - house.z
  return dx * c - dz * s, dx * s + dz * c
end
local ax, az = relative(a)
local bx, bz = relative(b)
test.expect(math.abs(ax - bx) < 0.01 and math.abs(az - bz) < 0.01, "the gate is always in the same place by the house")

-- talking to the neighbour uses their generated name
H.use("Talk to " .. a2.neighbour.name)
test.eq(D.dialogue.current.name, a2.neighbour.name, "the neighbour speaks under their name")
H.finish_dialogue()
