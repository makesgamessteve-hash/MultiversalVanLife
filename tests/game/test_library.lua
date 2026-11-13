-- Tidewater Library: return four books to the shelves.
H.new_game_in_van()
H.travel("Tidewater Library")
H.step_outside()
test.eq(H.current(), "library", "in the library")
test.eq(H.find("Return a book"), nil, "no shelf prompt without a book")
for i = 1, 4 do
  H.use("Pick up the book")
  H.finish_dialogue()
  H.use("Return a book")
  H.finish_dialogue()
end
test.expect(game.debug.progress.helped("library"), "library helped")
H.use("Talk to Quillfin")
test.eq(game.debug.dialogue.current.id, "quill_done", "librarian thanks you")
H.finish_dialogue()
