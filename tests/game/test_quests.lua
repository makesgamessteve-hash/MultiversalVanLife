-- Every base quest template can be completed through the game's own
-- interactions on three seeds, and completing it marks the land as helped.
local D = game.debug
local gen = D.gen
for _, template in ipairs({ "relight", "gather", "return", "lost" }) do
  for _, seed in ipairs({ 101, 202, 303 }) do
    H.new_game_in_van(seed)
    local addr = H.land_with(template)
    test.expect(addr, template .. ": a land with this trouble exists (seed " .. seed .. ")")
    H.travel_to(addr)
    H.step_outside()
    local w = D.world.current
    test.eq(w.land_node.address, addr, "arrived at the land")
    local q = w.state.quest.q
    test.eq(q.template, template, "the land's trouble")
    -- items lie within reach of the giver, on the ground
    local giver = w.land_node.data.people[1]
    for _, f in ipairs(w.land_node.data.features) do
      if f.role == "quest_item" or f.role == "quest_target" then
        local d = math.sqrt((f.x - giver.x) ^ 2 + (f.z - giver.z) ^ 2)
        test.expect(d <= 62, f.id .. " within reach of the giver: " .. d)
      end
    end
    test.expect(H.complete_quest(), template .. " completed (seed " .. seed .. ")")
    test.expect(D.progress.helped(addr), "the land is helped")
    -- talking again gives the thanks
    H.use("Talk to " .. giver.name)
    test.expect(D.dialogue.current.text:find("!") or D.dialogue.current.text:find("%."), "thanks")
    H.finish_dialogue()
    H.use("Enter the van")
    H.finish_dialogue()
  end
end
-- quest items are never duplicated when their chunk is rebuilt
H.new_game_in_van(404)
H.travel_to(H.land_with("gather"))
H.step_outside()
local w = D.world.current
local S = w.streamer
local q = w.state.quest.q
H.use("Pick up the")
H.finish_dialogue()
local taken = q.items[1]
for k, c in pairs(S.loaded) do S:unload(k) end
S:fill(D.player.x, D.player.z)
test.eq(S.spawned[taken], nil, "a picked up item does not come back")
local shown = 0
for _, id in ipairs(q.items) do if S.spawned[id] then shown = shown + 1 end end
local count = 0
for _, c in pairs(S.loaded) do
  for _, e in ipairs(c.entities) do
    for _, id in ipairs(q.items) do if S.spawned[id] == e then count = count + 1 end end
  end
end
test.eq(count, shown, "each remaining item exists once")
