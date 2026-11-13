-- Clockwork Bazaar: collect three gears and bring them to Tock.
H.new_game_in_van()
H.travel("Clockwork Bazaar")
H.step_outside()
test.eq(H.current(), "market", "in the market")
H.use("Talk to Tock")
test.eq(game.debug.dialogue.current.id, "tock_1", "Tock needs gears")
H.finish_dialogue()
test.expect(not game.debug.progress.helped("market"), "not yet helped")
for i = 1, 3 do
  H.use("Pick up the gear")
  H.finish_dialogue()
end
test.eq(H.find("Pick up the gear"), nil, "all gears collected")
H.use("Talk to Tock")
test.eq(game.debug.dialogue.current.id, "tock_done", "Tock repaired")
H.finish_dialogue()
test.expect(game.debug.progress.helped("market"), "market helped")
