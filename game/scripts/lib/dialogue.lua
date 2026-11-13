-- Multiversal Van Life - dialogue box with typewriter text (MIT License).
-- Dialogue is text only: fixed lines come from dialogue/lines.txt, generated
-- lines are passed as tables { speaker = name, text = ..., color = {r,g,b} }.
local lines = require("lib.lines")
local audio = require("lib.audio")

local dialogue = { queue = {}, current = nil, shown = 0, timer = 0, blip = 0, on_done = nil }

dialogue.speakers = {
  juniper  = { name = "Juniper", color = { 1.0, 0.75, 0.35 } },
  mabel    = { name = "Mabel", color = { 0.75, 0.9, 0.6 } },
  wick     = { name = "Old Wick", color = { 0.6, 0.9, 0.8 } },
  pip      = { name = "Pip", color = { 0.9, 0.8, 1.0 } },
  tock     = { name = "Tock", color = { 0.7, 0.85, 1.0 } },
  brassa   = { name = "Brassa", color = { 1.0, 0.65, 0.4 } },
  quillfin = { name = "Quillfin", color = { 0.55, 0.8, 1.0 } },
  narrator = { name = nil, color = { 0.85, 0.85, 0.85 } },
}

local CHARS_PER_SECOND = 45

function dialogue.active() return dialogue.current ~= nil end

local function start_line(entry)
  dialogue.current = entry
  dialogue.shown = 0
  dialogue.timer = 0
end

-- A line is an id from lines.txt or a generated line table. Generated lines
-- name their speaker directly and may carry their own colour.
local function resolve(line)
  if type(line) == "table" then
    return { id = line.id, speaker = line.speaker or "narrator", name = line.name or line.speaker,
             text = tostring(line.text or ""), color = line.color, generated = true }
  end
  return lines.get(line)
end

-- Queues one line, a generated line table or a list of them. `on_done` runs
-- when the last line closes.
function dialogue.say(ids, on_done)
  if type(ids) == "string" or (type(ids) == "table" and ids.text) then ids = { ids } end
  for _, id in ipairs(ids) do dialogue.queue[#dialogue.queue + 1] = resolve(id) end
  if on_done then
    local prev = dialogue.on_done
    dialogue.on_done = function() if prev then prev() end on_done() end
  end
  if not dialogue.current and #dialogue.queue > 0 then start_line(table.remove(dialogue.queue, 1)) end
end

function dialogue.skip_all()
  dialogue.queue = {}
  dialogue.current = nil
  local cb = dialogue.on_done
  dialogue.on_done = nil
  if cb then cb() end
end

function dialogue.update(dt)
  local cur = dialogue.current
  if not cur then return false end
  local len = #cur.text
  if dialogue.shown < len then
    dialogue.timer = dialogue.timer + dt
    local before = math.floor(dialogue.shown)
    dialogue.shown = math.min(len, dialogue.timer * CHARS_PER_SECOND)
    if cur.speaker ~= "narrator" and math.floor(dialogue.shown / 4) > math.floor(before / 4) then
      audio.sfx("voice_blip", 0.35)
    end
  end
  if mvl.pressed("interact") or mvl.pressed("back") then
    if dialogue.shown < len then
      dialogue.shown = len
    elseif #dialogue.queue > 0 then
      start_line(table.remove(dialogue.queue, 1))
    else
      dialogue.current = nil
      local cb = dialogue.on_done
      dialogue.on_done = nil
      if cb then cb() end
    end
  end
  return true
end

function dialogue.draw(touch)
  local cur = dialogue.current
  if not cur then return end
  local w, h = mvl.ui_size()
  local bw = math.min(w - 16, 400)
  local bx, by, bh = math.floor((w - bw) / 2), h - 70, 62
  local sp = dialogue.speakers[cur.speaker]
  if not sp then -- generated speakers
    sp = cur.generated and { name = cur.name, color = cur.color or { 0.85, 0.9, 1.0 } } or dialogue.speakers.narrator
  end
  mvl.rect(bx, by, bw, bh, 0.03, 0.04, 0.1, 0.88)
  mvl.rect(bx, by, bw, 1, sp.color[1], sp.color[2], sp.color[3], 1)
  local ty = by + 6
  if sp.name then
    mvl.text(bx + 8, ty, sp.name, 1, sp.color[1], sp.color[2], sp.color[3], 1)
    ty = ty + 12
  end
  local visible = cur.text:sub(1, math.floor(dialogue.shown))
  local wrapped = mvl.wrap(visible, bw - 16, 1)
  mvl.text(bx + 8, ty, wrapped, 1, 0.95, 0.93, 0.88, 1)
  if dialogue.shown >= #cur.text and (mvl.time() * 2) % 2 < 1.4 then
    local hint = touch and "tap USE" or "[E]"
    mvl.text(bx + bw - mvl.text_width(hint) - 6, by + bh - 11, hint, 1, 0.8, 0.7, 0.5, 1)
  end
end

return dialogue
