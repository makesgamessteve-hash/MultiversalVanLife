-- Multiversal Van Life - sound helpers: one-shots and soundscapes (MIT).
-- Mixer groups: 0 sfx, 1 ambience and music, 2 reserved.
--
-- A soundscape is the one looping sound of the place the player is in. Each
-- world names its own (`ambient` and `ambient_volume` in the world table);
-- the title screen and the van interior have theirs in audio.SCAPES, and
-- travelling plays the `travel` one-shot over the van's hum. Switching
-- soundscapes crossfades: the old loop fades out while the new one fades in.
local audio = { ambient = nil, ambient_path = nil, FADE_OUT = 1.2, FADE_IN = 1.5 }

audio.SCAPES = {
  title = { path = "music/title.mp3", volume = 0.55 },
  van = { path = "sounds/van_hum.wav", volume = 0.45 },
}

function audio.sfx(name, volume, pan)
  local id = mvl.sound("sounds/" .. name .. ".wav")
  if id ~= 0 then return mvl.play(id, volume or 1, pan or 0, false, 0) end
  return 0
end

-- Crossfades to the looping sound at `path` (nil for silence).
function audio.set_ambient(path, volume)
  if path == audio.ambient_path then return end
  if audio.ambient then mvl.fade(audio.ambient, 0, audio.FADE_OUT, true) end
  audio.ambient, audio.ambient_path = nil, path
  if path then
    local id = mvl.sound(path)
    if id ~= 0 then
      audio.ambient = mvl.play(id, 0, 0, true, 1)
      mvl.fade(audio.ambient, volume or 0.6, audio.FADE_IN)
    end
  end
end

-- Crossfades to a named soundscape from audio.SCAPES.
function audio.scape(name)
  local s = assert(audio.SCAPES[name], "unknown soundscape " .. tostring(name))
  audio.set_ambient(s.path, s.volume)
end

return audio
