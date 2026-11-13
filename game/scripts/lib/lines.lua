-- Multiversal Van Life - loads dialogue lines from voice/lines.txt (MIT).
local util = require("lib.util")
local lines = { by_id = {} }

function lines.load()
  lines.by_id = {}
  local text = mvl.read("voice/lines.txt") or ""
  for line in text:gmatch("[^\r\n]+") do
    if not line:match("^%s*#") then
      -- only the first two '|' separate fields; the text may contain more
      local id, speaker, body = line:match("^([^|]*)|([^|]*)|(.*)$")
      if id and util.trim(id) ~= "" then
        id = util.trim(id)
        lines.by_id[id] = { id = id, speaker = util.trim(speaker), text = util.trim(body) }
      end
    end
  end
  return lines.by_id
end

function lines.get(id)
  return lines.by_id[id] or { id = id, speaker = "narrator", text = "[" .. tostring(id) .. "]" }
end

return lines
