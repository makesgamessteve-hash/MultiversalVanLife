-- Living creatures: herds share one model, prey flees from a running player
-- (its herd with it), flyers flap their wings, models are released on a
-- long walk, and a mod can add a body part.
local D = game.debug
local gen = D.gen
local CR = require("gen.visuals.creatures")
gen.planet.LEVEL = 3
H.new_game_in_van(5150)
local G = gen.world

-- a land whose habitat has grazers and flyers
local function has(h, pred)
  for _, sp in ipairs(h.animals) do if pred(sp) then return true end end
end
local found
for s = 0, 300 do
  local saddr = "u" .. (1 + s % 7) .. ".g" .. (s % 11) .. ".c" .. (s % 3) .. ".s" .. (s % 5)
  local ok, sys = pcall(G.generate, G, saddr)
  if ok then
    for i = 0, sys.data.planets - 1 do
      if not found and sys.children[i].kind == "rocky" then
        local p = G:generate(saddr .. ".p" .. i)
        if p.data.life and p.data.life.complexity == "animals" then
          for k = 0, (p.data.continents or 0) - 1 do
            local cont = G:generate(p.address .. ".k" .. k)
            for _, n in ipairs(gen.util.sorted_keys(cont.children)) do
              local c = G:generate(cont.address .. ".n" .. n)
              if not found and c.data.district then
                for l = 0, 255, 9 do
                  local gx, gz = gen.land.grid(l)
                  if gen.land.raw_height(c.data.terrain, gx * 2048, gz * 2048) > 3 then
                    local land = G:generate(c.address .. ".l" .. l)
                    local h = land.data.habitats and land.data.habitats[1]
                    if h and h.density >= 0.5 and has(h, function(sp) return sp.behaviour.kind == "grazer" end) and
                       has(h, function(sp) return sp.behaviour.kind == "flyer" end) then found = land end
                    break
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  if found then break end
end
test.expect(found, "a land with grazers and flyers")
H.travel_to(found.address)
H.step_outside()
local w = D.world.current
local st = w.streamer
local C = st.creatures

-- let the land fill with life around the player, wherever needed
local function creatures_where(pred)
  local out = {}
  for _, cr in ipairs(C:all()) do if pred(cr) then out[#out + 1] = cr end end
  return out
end
local function nearest(list, x, z)
  local best, bd
  for _, cr in ipairs(list) do
    local d = (cr.x - x) ^ 2 + (cr.z - z) ^ 2
    if not best or d < bd then best, bd = cr, d end
  end
  return best
end
test.expect(#C:all() > 0, "creatures live in the land")

-- ---------------------------------------------------- a herd, one model
local herd
for _, cr in ipairs(C:all()) do
  if cr.herd and #cr.herd >= 2 and cr.model then herd = cr.herd break end
end
local tries = 0
while not herd and tries < 30 do
  tries = tries + 1
  D.player.place(D.player.x + 96, D.player.z, 0)
  test.wait(20)
  for _, cr in ipairs(C:all()) do
    if cr.herd and #cr.herd >= 2 and cr.model then herd = cr.herd break end
  end
end
test.expect(herd, "a herd of grazers")
for _, m in ipairs(herd) do
  test.expect(m.model == herd[1].model, "all members of a herd share one model")
  test.eq(m.sp.id, herd[1].sp.id, "of one species")
end
test.expect(st.models.entries[herd[1].model.key].refs >= #herd, "the shared model is counted once per member")

-- ------------------------------------------------------------ prey flees
local leader = herd[1]
for _, m in ipairs(herd) do m.state, m.timer = "rest", 30 end
local px, pz = leader.x + 20, leader.z
D.player.place(px, pz, math.atan(-(leader.x - px), -(leader.z - pz)))
test.wait(2)
local d0 = math.sqrt((leader.x - D.player.x) ^ 2 + (leader.z - D.player.z) ^ 2)
test.eq(leader.state, "rest", "the grazer grazes while the player is far")
D.player.yaw = math.atan(-(leader.x - D.player.x), -(leader.z - D.player.z))
test.hold("move_y", 150)
test.expect(leader.state == "flee" or leader.timer < 4, "the grazer flees from the approaching player")
for _, m in ipairs(herd) do test.eq(m.state, "flee", "its herd flees with it") end
local d1 = math.sqrt((leader.x - D.player.x) ^ 2 + (leader.z - D.player.z) ^ 2)
test.expect(leader.x ~= px or leader.z ~= pz, "it ran")
test.expect(d1 > 4, "and kept its distance: " .. d1 .. " (from " .. d0 .. ")")

-- ------------------------------------------------------- winged flyers
local flyers = creatures_where(function(cr) return cr.b.kind == "flyer" and cr.model end)
tries = 0
while #flyers == 0 and tries < 30 do
  tries = tries + 1
  D.player.place(D.player.x + 96, D.player.z, 0)
  test.wait(20)
  flyers = creatures_where(function(cr) return cr.b.kind == "flyer" and cr.model end)
end
test.expect(#flyers > 0, "flyers live here")
local f = nearest(flyers, D.player.x, D.player.z)
D.player.place(f.x + 12, f.z, 0)
test.wait(3)
test.eq(f.mode, "near", "a flyer close by is drawn with its parts")
test.expect(#f.parts.wings == 2, "it has two wings")
local rolls = {}
for k = 1, 8 do
  test.wait(2)
  local _, _, roll = mvl.get_rotation(f.parts.wings[1])
  rolls[k] = roll
end
local lo, hi = math.min(table.unpack(rolls)), math.max(table.unpack(rolls))
test.expect(hi - lo > 0.3, "its wings move as it flies: " .. lo .. " to " .. hi)
test.expect(f.y > mvl.height(f.x, f.z) + 1, "it flies above the ground")
-- creatures far away are one merged model
local far = 0
for _, cr in ipairs(C:all()) do
  if cr.mode == "far" then
    far = far + 1
    test.expect(cr.parts == nil, "far creatures have no separate parts")
  end
end
test.expect(far > 0, "creatures far away use a single merged model")

-- --------------------------------------------- a long walk, bounded meshes
local start = mvl.mesh_count()
local most, entities = 0, 0
for step = 1, 40 do
  D.player.place(D.player.x + 48, D.player.z + (step % 2 == 0 and 20 or -20), 0)
  test.wait(6)
  most = math.max(most, mvl.mesh_count())
  entities = math.max(entities, mvl.entity_count())
end
local n, live = st.models:count()
test.expect(most < 900, "meshes stay bounded on a long walk: " .. most .. " (start " .. start .. ")")
test.expect(entities < 1900, "entities stay bounded: " .. entities)
test.expect(st.models.stats.released > 0, "models no longer used are released")
local refs, users = 0, 0
for _, e in pairs(st.models.entries) do refs = refs + e.refs end
for _, c in pairs(st.loaded) do users = users + #(c.models or {}) end
for _, cr in ipairs(C:all()) do if cr.model then users = users + 1 end end
test.eq(refs, users, "every reference belongs to a living plant or creature")
test.expect(n > 0 and live > 0, "models in use: " .. n)

-- -------------------------------------------------------- a mod body part
local plan_params = herd[1].model.plan
local p = { limbs = 4, covering = "fur", segments = 2, eyes = 2, tail = true, move = "walk", size = 1.2, height = 1,
            stockiness = 1, colors = { { 60, 40, 30 }, { 120, 90, 60 }, { 200, 170, 120 } }, seed = 77 }
local plain = CR.build(p)
local called = 0
CR.PARTS.horn = function(g, plan, z0, cy)
  called = called + 1
  g:line(8, cy + plan.ry + 2, z0 + plan.rz * 2, 8, cy + plan.ry + 4, z0 + plan.rz * 2 + 4, 0.6, 5)
end
local horned = CR.build(p)
test.expect(called >= 2, "the mod's part is drawn into the body and the merged model")
test.expect(horned.hash ~= plain.hash, "and changes the model")
CR.release(plain)
CR.release(horned)
CR.PARTS.horn = nil
test.expect(plan_params.s > 0, "plans give a voxel size")
