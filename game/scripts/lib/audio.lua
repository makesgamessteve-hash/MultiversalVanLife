-- Multiversal Van Life - sound helpers: one-shots, ambience crossfades
-- and voice playback (MIT License). Mixer groups: 0 sfx, 1 ambience, 2 voice.
local audio = { ambient = nil, ambient_path = nil, voice = nil }

function audio.sfx(name, volume, pan)
  local id = mvl.sound("sounds/" .. name .. ".wav")
  if id ~= 0 then return mvl.play(id, volume or 1, pan or 0, false, 0) end
  return 0
end

function audio.set_ambient(path, volume)
  if path == audio.ambient_path then return end
  if audio.ambient then mvl.fade(audio.ambient, 0, 1.0, true) end
  audio.ambient, audio.ambient_path = nil, path
  if path then
    local id = mvl.sound(path)
    if id ~= 0 then
      audio.ambient = mvl.play(id, 0, 0, true, 1)
      mvl.fade(audio.ambient, volume or 0.6, 1.5)
    end
  end
end

-- Plays voice/<id>.wav if present. Returns the clip length in seconds or nil.
function audio.voice(id)
  if audio.voice_handle then mvl.stop(audio.voice_handle) end
  audio.voice_handle = nil
  local folder = mvl.config("voice.folder", "voice")
  local path = folder .. "/" .. id .. ".wav"
  if not mvl.file_exists(path) then return nil end
  local snd = mvl.sound(path)
  if snd == 0 then return nil end
  audio.voice_handle = mvl.play(snd, 1, 0, false, 2)
  return mvl.sound_length(snd)
end

function audio.stop_voice()
  if audio.voice_handle then mvl.stop(audio.voice_handle) end
  audio.voice_handle = nil
end

return audio
