-- Multiversal Van Life - loads dialogue lines from voice/lines.txt (MIT).
local util = require("lib.util")
local lines = { by_id = {} }

function lines.load()
  lines.by_id = {}
  local text = mvl.read("voice/lines.txt") or ""
  for line in text:gmatch("[^\r\n]+") do
    if not line:match("^%s*#") and line:find("|", 1, true) then
      local parts = util.split(line, "|")
      local id, speaker, body = util.trim(parts[1] or ""), util.trim(parts[2] or ""), util.trim(parts[3] or "")
      if id ~= "" then lines.by_id[id] = { id = id, speaker = speaker, text = body } end
    end
  end
  return lines.by_id
end

function lines.get(id)
  return lines.by_id[id] or { id = id, speaker = "narrator", text = "[" .. tostring(id) .. "]" }
end

return lines
