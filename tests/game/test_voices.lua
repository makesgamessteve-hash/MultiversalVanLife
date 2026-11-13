-- Every spoken (non-narrator) line ships a voice clip, and showing a line
-- plays its clip on the voice mixer group.
local lines = require("lib.lines").load()
local audio = require("lib.audio")
local count = 0
for id, line in pairs(lines) do
  if line.speaker ~= "narrator" then
    test.expect(mvl.file_exists("voice/" .. id .. ".wav"), "voice clip for " .. id)
    count = count + 1
  end
end
test.expect(count >= 34, "voiced lines")
H.new_game()
test.until_true(function() return game.debug.dialogue.active() end, 300, "the van calls")
test.wait(2)
test.expect(audio.voice_handle and mvl.playing(audio.voice_handle), "voice clip is playing")
H.finish_dialogue()
test.expect(not (audio.voice_handle and mvl.playing(audio.voice_handle)), "voice stops with the dialogue")
