-- Arriving through a signal: a settlement's buildings and the quest giver
-- are in sight of the van's door, on three seeds.
local D = game.debug
for _, seed in ipairs({ 7, 77, 777 }) do
  H.new_game_in_van(seed)
  H.travel("Signal")
  H.step_outside()
  local w = D.world.current
  local d = w.land_node.data
  local p = D.player
  local fx, fz = -math.sin(p.yaw), -math.cos(p.yaw)
  local in_view = 0
  for _, f in ipairs(d.features) do
    if f.role == "building" then
      local dx, dz = f.x - p.x, f.z - p.z
      local dist = math.sqrt(dx * dx + dz * dz)
      if dist < 45 and dist > 1 then in_view = in_view + 1 end
    end
  end
  test.expect(in_view >= 2, "buildings of the settlement near the van door (seed " .. seed .. "): " .. in_view)
  local g = d.people[1]
  local gd = math.sqrt((g.x - p.x) ^ 2 + (g.z - p.z) ^ 2)
  test.expect(gd < 25, "the quest giver is within sight: " .. gd)
  -- the settlement's buildings are built (their chunks are loaded)
  local built = 0
  for _, f in ipairs(d.features) do if f.role == "building" and w.streamer.spawned[f.id] then built = built + 1 end end
  test.expect(built >= 2, "the buildings exist in the world")
  -- talking to the giver explains the problem
  H.use("Talk to " .. g.name)
  test.expect(D.dialogue.current and D.dialogue.current.name == g.name, "the giver explains the trouble")
  H.finish_dialogue()
  test.expect(d.name and #d.people >= 2, "a named settlement with people")
  test.eq(#D.gen.check.run(D.gen.world), 0, "the generated path passes the checks")
end
