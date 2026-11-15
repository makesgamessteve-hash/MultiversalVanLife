-- The endless house: blocks of generated rooms beyond the core, the same for
-- a game every time, every room reachable from the hall through doorways
-- (over 400 blocks), furniture never blocking the way (checked on foot in
-- a few blocks), and a kilometre's walk that keeps building rooms ahead and
-- releasing them behind within the budgets.
local D = game.debug
local van = D.van
local house = van.house
H.new_game_in_van(5150)
H.finish_dialogue()
local P = van.P
local plan = require("gen.house.plan")
local B = require("gen.house.blocks")
local seed = D.progress.seed()

-- ----------------------------------------------- the doorway graph
local function room_at(x, z)
  local bx, bz = plan.block_of(x, z)
  for _, r in ipairs(plan.block(seed, bx, bz)) do
    if r.y == 0 and x > r.x0 and x < r.x1 and z > r.z0 and z < r.z1 then return r end
  end
end
local OPP = { n = "s", s = "n", e = "w", w = "e" }
-- rooms on the other side of each open doorway of r
local function neighbours(r)
  local out = {}
  for _, d in ipairs(r.doors or {}) do
    if not d.closed and not d.garden then  -- the garden door leads into the garden
      local x, z
      if d.side == "n" then x, z = d.at, r.z1 + 0.1
      elseif d.side == "s" then x, z = d.at, r.z0 - 0.1
      elseif d.side == "e" then x, z = r.x1 + 0.1, d.at
      else x, z = r.x0 - 0.1, d.at end
      local o = room_at(x, z)
      local matched = false
      for _, od in ipairs(o and o.doors or {}) do
        if od.side == OPP[d.side] and math.abs(od.at - d.at) < 0.01 and not od.closed then matched = true end
      end
      test.expect(matched, string.format("the doorway of %s (%s at %.2f) opens into a room", r.id, d.side, d.at))
      if matched then out[#out + 1] = o end
    end
  end
  return out
end
-- every room of 20 x 20 blocks around the core is reached from the hall
local R = 10
local wanted, total = {}, 0
for bx = -R, R - 1 do
  for bz = -R, R - 1 do
    for _, r in ipairs(plan.block(seed, bx, bz)) do
      if r.y == 0 then wanted[r.id] = true total = total + 1 end
    end
  end
end
local seen, queue, head = { hall = true }, { plan.room("hall") }, 1
local reached = 0
while head <= #queue do
  local r = queue[head]
  head = head + 1
  if wanted[r.id] then reached = reached + 1 end
  local bx, bz = plan.block_of((r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2)
  if math.abs(bx + 0.5) <= R + 1 and math.abs(bz + 0.5) <= R + 1 then
    for _, o in ipairs(neighbours(r)) do
      if not seen[o.id] then
        seen[o.id] = true
        queue[#queue + 1] = o
      end
    end
  end
end
test.eq(reached, total, string.format("every room of 400 blocks is reached from the hall (%d rooms)", total))

-- ------------------------------------------------ same house, variety
local a = plan.block(seed, 3, -2)
local b = B.rooms(seed, 3, -2)
test.eq(#a, #b, "a block has the same rooms every time")
for i = 1, #a do
  test.expect(a[i].x0 == b[i].x0 and a[i].z1 == b[i].z1 and a[i].kind == b[i].kind and #a[i].items == #b[i].items,
              "room " .. i .. " is the same")
end
local other = B.rooms(seed + 1, 3, -2)
local differs = #other ~= #a
for i = 1, math.min(#a, #other) do if other[i].kind ~= a[i].kind or other[i].x0 ~= a[i].x0 then differs = true end end
test.expect(differs, "another game has another house")
local templates, kinds = {}, {}
for bx = -R, R - 1 do
  for bz = -R, R - 1 do
    if bx ~= 0 or bz ~= 0 then
      local rooms = plan.block(seed, bx, bz)
      templates[rooms[1].template] = (templates[rooms[1].template] or 0) + 1
      for _, r in ipairs(rooms) do kinds[r.kind] = true end
    end
  end
end
for _, t in ipairs(B.TEMPLATES) do test.expect((templates[t] or 0) > 40, t .. " blocks: " .. tostring(templates[t])) end
local nk = 0
for _ in pairs(kinds) do nk = nk + 1 end
test.expect(nk >= 12, nk .. " kinds of rooms")

-- --------------------------------------------- on foot, past the furniture
local STEP = 0.25
local function flood(bx, bz)
  local ox, oz = B.origin(bx, bz)
  house.fill(ox + 16, oz + 16)
  local y = P[2]
  local seen2, q, h2 = {}, {}, 1
  local function key(i, j) return i * 8192 + j end
  -- start in the middle of the block's west doorway, or its north one
  local i0, j0 = math.floor((ox + 0.5) / STEP), math.floor((oz + 16) / STEP)
  if bx == 1 and bz == 0 then i0, j0 = math.floor((ox + 16) / STEP), math.floor((oz + 31.5) / STEP) end
  q[1] = { i0, j0 }
  seen2[key(i0, j0)] = true
  while h2 <= #q do
    local c = q[h2]
    h2 = h2 + 1
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      local i, j = c[1] + d[1], c[2] + d[2]
      local x, z = i * STEP, j * STEP
      local k = key(i, j)
      if not seen2[k] and x > ox - 0.2 and x < ox + 32.2 and z > oz - 0.2 and z < oz + 32.2 then
        seen2[k] = true
        if not mvl.overlaps(P[1] + x, P[3] + z, 0.3, y) then q[#q + 1] = { i, j } end
      end
    end
  end
  for _, r in ipairs(plan.block(seed, bx, bz)) do
    local ok = false
    for _, c in ipairs(q) do
      local x, z = c[1] * STEP, c[2] * STEP
      if x > r.x0 + 0.3 and x < r.x1 - 0.3 and z > r.z0 + 0.3 and z < r.z1 - 0.3 then ok = true break end
    end
    test.expect(ok, string.format("room %s (%s, %s) of block %d,%d is reached on foot", r.id, r.kind, r.template, bx, bz))
  end
end
for _, b2 in ipairs({ { 0, 1 }, { 1, 0 }, { -1, 1 }, { 2, -1 }, { -2, -2 }, { 3, 3 }, { -1, 0 }, { 1, 2 } }) do
  flood(b2[1], b2[2])
end

-- ------------------------------------------------ a kilometre's walk
-- along the doorways from the hall to a block a kilometre away
local goal = "b0_31_"
local prev, q3, h3 = { hall = false }, { plan.room("hall") }, 1
local found
while h3 <= #q3 and not found do
  local r = q3[h3]
  h3 = h3 + 1
  local bx, bz = plan.block_of((r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2)
  if r.id:sub(1, #goal) == goal then found = r end
  if math.abs(bx) <= 2 and bz >= -1 and bz <= 32 then
    for _, o in ipairs(neighbours(r)) do
      if prev[o.id] == nil then
        prev[o.id] = r
        q3[#q3 + 1] = o
      end
    end
  end
end
test.expect(found, "a way from the hall to a kilometre away")
local path = {}
local r = found
while r do
  table.insert(path, 1, r)
  r = prev[r.id] or nil
end
local most, slowest = 0, 0
for _, room in ipairs(path) do
  local x, z = (room.x0 + room.x1) / 2, (room.z0 + room.z1) / 2
  D.player.place(P[1] + x, P[3] + z, 0)
  D.player.base_y = P[2]
  local t0 = os.clock()
  house.update(x, z, 3)
  slowest = math.max(slowest, (os.clock() - t0) * 1000)
  test.wait(1)
  local n = house.entity_count()
  most = math.max(most, n)
  test.expect(house.built[room.id], "the room the player is in is built: " .. room.id)
end
local n, built = house.entity_count()
test.expect(most < 1100, "the house stays within its entity budget: " .. most)
test.expect(built < 90, "rooms behind are released: " .. built .. " built")
test.expect(house.built.hall and house.built.library, "the core stays")
test.expect(slowest < 2500, string.format("building rooms ahead takes at most %.0f ms per step", slowest))
mvl.log(string.format("walked %d rooms; most entities %d; slowest step %.0f ms", #path, most, slowest))
