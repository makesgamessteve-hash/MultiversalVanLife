-- Visited places are stored and every change there is remembered: across
-- leaving, restarting the game and even a changed generator.
local D = game.debug
local gen = D.gen
local story = D.story

-- A restart: save, back to the title, continue (everything is read back
-- from the save: places, change logs, progress).
local function restart()
  D.open_pause()
  H.choose(D.pause_menu(), "Save and return")
  test.eq(game.state, "title", "on the title screen")
  H.choose(D.title_menu(), "Continue")
  test.eq(game.state, "play", "continued")
  H.finish_dialogue()
end

local function back_to(addr)
  if H.current() ~= "van" then H.use("Enter the van") H.finish_dialogue() end
  H.use("console")
  H.finish_dialogue()
  H.choose(story.menu, "Logbook")
  local name = gen.world:node(addr) and gen.world:node(addr).data.name
  for _, e in ipairs(D.progress.logbook()) do if e.address == addr then name = e.name end end
  H.choose(story.menu, name)
  test.until_true(function() return not story.busy end, 1200, "arrived")
  H.finish_dialogue()
  H.step_outside()
end

local function away()
  H.use("Enter the van")
  H.finish_dialogue()
  H.use("console")
  H.finish_dialogue()
  H.choose(story.menu, "Home")
  test.until_true(function() return not story.busy end, 1200, "home")
  H.finish_dialogue()
end

local function layout(d)
  local parts = {}
  for _, f in ipairs(d.features) do parts[#parts + 1] = string.format("%s@%.2f,%.2f", f.id, f.x, f.z) end
  for _, p in ipairs(d.people) do parts[#parts + 1] = p.name end
  return table.concat(parts, " ")
end

-- ------------------------------------------- stored on first arrival
H.new_game_in_van(9001)
local relight = H.land_with("relight")
H.travel_to(relight)
H.step_outside()
local first = layout(D.world.current.land_node.data)
test.expect(mvl.record_read("places/" .. relight), "the land was stored on arrival")

-- -------------------- a partial quest and its lanterns are remembered
local w = D.world.current
local s = w.state.quest
local q = s.q
test.expect(q.count >= 3, "several lanterns")
for _ = 1, 2 do H.use("Gather the") H.finish_dialogue() end
H.use("Light the") H.finish_dialogue()
H.use("Light the") H.finish_dialogue()
local lit = {}
for id in pairs(s.lit) do lit[#lit + 1] = id end
test.eq(#lit, 2, "two lanterns lit")
H.use("Gather the") H.finish_dialogue()
test.eq(s.carrying, 1, "one glow carried")
-- put the last one down by the van
local px, pz = D.player.x, D.player.z
test.press("drop")
test.eq(s.carrying, 0, "the glow was put down")
local dropped
for id, o in pairs(s.log.placed) do if o.role == "dropped" then dropped = o end end
test.expect(dropped and math.abs(dropped.x - px) < 2 and math.abs(dropped.z - pz) < 2, "it lies in front of the player")
-- walk far away from the last item taken: its chunk is discarded and rebuilt without it
local taken
for id in pairs(s.taken) do if not taken or id > taken then taken = id end end
local f
for _, x in ipairs(w.land_node.data.features) do if x.id == taken then f = x end end
D.player.place(f.x + 400, f.z, 0)
for _ = 1, 90 do test.wait(1) end
test.eq(w.streamer:chunk_at(f.x, f.z), nil, "the item's chunk was discarded")
D.player.place(f.x + 3, f.z, 0)
for _ = 1, 90 do test.wait(1) end
test.expect(w.streamer:chunk_at(f.x, f.z), "the chunk was rebuilt")
test.eq(w.streamer.spawned[taken], nil, "the taken item is still gone")

-- leave, restart, come back
away()
restart()
back_to(relight)
w = D.world.current
s = w.state.quest
test.eq(layout(w.land_node.data), first, "the land is exactly as stored")
local still = 0
for _, id in ipairs(lit) do if s.lit[id] then still = still + 1 end end
test.eq(still, 2, "the two lanterns are still lit")
for _, id in ipairs(lit) do
  local e = w.streamer.spawned[id .. "_lamp"]
  if e then test.eq(s.log:get(id .. "_lamp").state, "lit", "the lamp's light is remembered") end
end
test.expect(not s.complete, "the quest continues from where it was")
test.eq(s.carrying, 0, "nothing carried")
test.expect(s.log.placed[dropped.id], "the dropped glow is remembered")
test.expect(w.streamer.spawned[dropped.id] or not w.streamer:chunk_at(dropped.x, dropped.z), "and lies where it was put")
test.expect(H.find("you left"), "it can be picked up again")
-- finish the quest from there
H.use("you left") H.finish_dialogue()
test.eq(s.carrying, 1, "carried again")
while not s.complete do
  if s.carrying == 0 then H.use("Gather the") H.finish_dialogue() end
  H.use("Light the")
  H.finish_dialogue()
end
test.expect(D.progress.helped(relight), "the land is helped")

-- ------------------------------ a changed generator leaves it alone
local layout_pass = gen.cosmos.passes[gen.cosmos:level("land").n].layout
local original = layout_pass.run
gen.cosmos:pass("land", "layout", { run = function(ctx)
  original(ctx)
  for _, x in ipairs(ctx.data.features) do x.x = x.x + 7 end -- "a game update"
end })
away()
restart()
gen.world.version = gen.VERSION + 1
back_to(relight)
test.eq(layout(D.world.current.land_node.data), first, "after the generator changed the land is as stored")
test.eq(D.world.current.land_node.version, gen.VERSION, "generated with the old version")
-- a new land uses the new generator
local fresh = gen.world:generate(H.land_with("gather"))
test.eq(fresh.version, gen.VERSION + 1, "new places use the new generator")
gen.cosmos:pass("land", "layout", { run = original })
