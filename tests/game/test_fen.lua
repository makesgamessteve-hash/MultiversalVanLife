-- Lanternfen: catch fireflies and relight every lantern.
H.new_game_in_van()
H.travel("Lanternfen")
H.step_outside()
H.use("Talk to Old Wick")
test.eq(game.debug.dialogue.current.id, "wick_1", "keeper explains")
H.finish_dialogue()
-- lantern without a firefly
H.use("Light the lantern")
test.eq(game.debug.dialogue.current.id, "fen_need", "needs a firefly")
H.finish_dialogue()
for i = 1, 4 do
  H.use("Catch the firefly")
  H.finish_dialogue()
  H.use("Light the lantern")
  H.finish_dialogue()
end
test.expect(game.debug.progress.helped("fen"), "fen helped")
test.eq(H.find("Light the lantern"), nil, "all lanterns lit")
H.use("Talk to Pip")
test.eq(game.debug.dialogue.current.id, "pip_done", "Pip is happy")
H.finish_dialogue()
