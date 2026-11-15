-- The house inside the van and the world outside share the engine's 2,048
-- entities: arriving at land after land (with games of different seeds),
-- the house gives way to the world and the total stays well within the
-- limit (the land never fails to build).
local D = game.debug
local peak, where = 0, ""
for seed = 1, 5 do
  H.new_game_in_van(seed * 104729)
  H.finish_dialogue()
  for k = 1, 3 do
    local s = D.story.signals()[k]
    if s then
      D.story.travel(s.address)
      for _ = 1, 900 do
        test.wait(1)
        local n = mvl.entity_count()
        if n > peak then peak, where = n, s.address end
        if not D.story.busy then break end
      end
      test.expect(not D.story.busy, "arrived at " .. s.address)
      D.dialogue.skip_all()
      for _ = 1, 60 do
        test.wait(1)
        local n = mvl.entity_count()
        if n > peak then peak, where = n, s.address end
      end
    end
  end
end
mvl.log("most entities on arrival: " .. peak .. " at " .. where)
test.expect(peak < 1900, "the house leaves the world room: at most " .. peak .. " entities")
