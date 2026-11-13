-- Every sound and music track of tools/audiogen/manifest.json is shipped
-- with the game, loads, and has the length that was generated.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./"
local text = assert(test.read_file(here .. "../../tools/audiogen/manifest.json"), "audio manifest not found")
local count, kinds = 0, {}
for entry in text:gmatch("{[^{}]-\"out\"[^{}]-}") do
  local id = entry:match('"id"%s*:%s*"([^"]+)"')
  local kind = entry:match('"kind"%s*:%s*"([^"]+)"')
  local out = entry:match('"out"%s*:%s*"([^"]+)"')
  local duration = tonumber(entry:match('"duration"%s*:%s*([%d%.]+)'))
  local snd = mvl.sound(out)
  test.expect(snd ~= 0, id .. " loads from " .. out)
  local len = mvl.sound_length(snd)
  if kind == "sfx" then
    -- one-shots are trimmed to the audible part
    test.expect(len > 0.05 and len <= duration + 0.05, string.format("%s: %.2f s for %.2f s", id, len, duration))
  else
    -- loops lose only their 60 ms seam crossfade; music keeps its length
    test.expect(math.abs(len - duration) < 0.2, string.format("%s: %.2f s for %.2f s", id, len, duration))
  end
  local voice = mvl.play(snd, 0.1, 0, kind ~= "sfx", kind == "sfx" and 0 or 1)
  test.expect(mvl.playing(voice), id .. " plays")
  mvl.stop(voice)
  kinds[kind] = (kinds[kind] or 0) + 1
  count = count + 1
end
test.expect(count >= 15, "manifest entries found: " .. count)
test.expect(kinds.sfx and kinds.loop and kinds.music, "sound effects, loops and music")
