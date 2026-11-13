-- Dialogue is text only: lines type out with a blip, no recorded voice plays,
-- generated lines name their own speaker, unknown ids are shown in brackets.
local D = game.debug
H.new_game()
test.until_true(function() return D.dialogue.active() end, 300, "the van calls")
local cur = D.dialogue.current
test.eq(cur.id, "van_call_1", "a line from dialogue/lines.txt")
test.expect(#cur.text > 10, "it has text")
test.wait(20)
test.expect(D.dialogue.shown > 0 and D.dialogue.shown < #cur.text, "the text types out")
test.eq(test.mixer_voices(2), 0, "no voice clip is playing")
test.expect(not mvl.file_exists("voice/van_call_1.wav"), "no voice clips are shipped")
H.finish_dialogue()
D.dialogue.say({ speaker = "Ossery the Smith", text = "Mind the anvil, traveller.", color = { 1, 0.5, 0.2 } })
test.eq(D.dialogue.current.name, "Ossery the Smith", "generated speaker")
test.eq(D.dialogue.current.text, "Mind the anvil, traveller.", "generated text")
test.wait(2)
H.finish_dialogue()
D.dialogue.say({ "no_such_line", { speaker = "Pip", text = "Hello!" } })
test.eq(D.dialogue.current.text, "[no_such_line]", "unknown ids are shown in brackets")
H.finish_dialogue()
