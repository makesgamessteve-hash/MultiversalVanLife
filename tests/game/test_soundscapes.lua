-- Each place has its own soundscape: the title plays music, worlds their
-- ambience, the van its hum, and travelling its own sound. Switching
-- crossfades the old loop out and the new one in.
local D = game.debug
local audio = require("lib.audio")
test.wait(30)
test.eq(audio.ambient_path, "music/title.mp3", "title music")
test.expect(test.voice_volume(audio.ambient) > 0.1, "title music is fading in")

H.new_game()
H.finish_dialogue()
test.seconds(2)
local home = D.world.get("home")
test.eq(audio.ambient_path, home.ambient, "the farm's ambience")
local outside = audio.ambient
test.expect(math.abs(test.voice_volume(outside) - (home.ambient_volume or 0.6)) < 0.01, "ambience at full volume")
test.eq(test.mixer_voices(1), 1, "the title music has faded away")

-- entering the van: the world ambience fades out while the hum fades in
H.finish_dialogue()
H.use("Enter the van")
test.expect(D.van.inside, "inside the van")
test.eq(audio.ambient_path, audio.SCAPES.van.path, "the van's soundscape")
local hum = audio.ambient
test.wait(20)
local out_v, hum_v = test.voice_volume(outside), test.voice_volume(hum)
test.expect(out_v > 0 and out_v < (home.ambient_volume or 0.6), "world ambience is fading out: " .. out_v)
test.expect(hum_v > 0 and hum_v < audio.SCAPES.van.volume, "van hum is fading in: " .. hum_v)
test.seconds(2)
test.eq(test.voice_volume(outside), -1, "world ambience stopped")
test.expect(math.abs(test.voice_volume(hum) - audio.SCAPES.van.volume) < 0.01, "van hum at full volume")

-- travelling: the travel sound plays over the hum, which carries on
H.finish_dialogue()
H.use("console")
H.finish_dialogue()
H.choose(D.story.menu, "Signal")
test.wait(5)
test.expect(test.mixer_voices(0) >= 1, "the travel sound plays")
test.eq(audio.ambient, hum, "the hum carries on while travelling")
test.until_true(function() return not D.story.busy end, 600, "arrived")
H.finish_dialogue()
test.eq(audio.ambient, hum, "still the hum after arriving")

-- stepping out at the destination crossfades to its world's ambience
H.step_outside()
test.eq(audio.ambient_path, (D.world.ambient()), "the land's own ambience")
test.expect(audio.ambient_path ~= audio.SCAPES.van.path, "not the van hum")
test.seconds(2)
test.eq(test.voice_volume(hum), -1, "van hum stopped outside")

-- back to the title: its music returns
D.open_pause()
H.choose(D.pause_menu(), "return to title")
test.eq(game.state, "title", "on the title screen")
test.eq(audio.ambient_path, "music/title.mp3", "title music again")
