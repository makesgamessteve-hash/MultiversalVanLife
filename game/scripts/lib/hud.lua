-- Multiversal Van Life - prompts, notifications, fades and title cards (MIT).
local hud = { prompt = nil, notes = {}, fade = 0, fade_target = 0, fade_speed = 1.5, card = nil, card_time = 0 }

function hud.set_prompt(text) hud.prompt = text end

function hud.notify(text, seconds)
  hud.notes[#hud.notes + 1] = { text = text, time = seconds or 3 }
end

-- Fades to black (1) or back (0).
function hud.fade_to(target, speed)
  hud.fade_target = target
  hud.fade_speed = speed or 1.5
end

function hud.title_card(text, seconds)
  hud.card = text
  hud.card_time = seconds or 3
end

function hud.update(dt)
  if hud.fade < hud.fade_target then hud.fade = math.min(hud.fade_target, hud.fade + dt * hud.fade_speed)
  elseif hud.fade > hud.fade_target then hud.fade = math.max(hud.fade_target, hud.fade - dt * hud.fade_speed) end
  for i = #hud.notes, 1, -1 do
    local n = hud.notes[i]
    n.time = n.time - dt
    if n.time <= 0 then table.remove(hud.notes, i) end
  end
  if hud.card then
    hud.card_time = hud.card_time - dt
    if hud.card_time <= 0 then hud.card = nil end
  end
end

function hud.draw(touch)
  local w, h = mvl.ui_size()
  if hud.prompt then
    local text = (touch and "USE: " or "[E] ") .. hud.prompt
    local tw = mvl.text_width(text)
    mvl.rect((w - tw) / 2 - 6, h - 98, tw + 12, 14, 0, 0, 0, 0.6)
    mvl.text((w - tw) / 2, h - 95, text, 1, 1, 0.9, 0.6, 1)
  end
  for i, n in ipairs(hud.notes) do
    local a = math.min(1, n.time)
    mvl.text(8, 8 + (i - 1) * 11, n.text, 1, 0.9, 0.95, 1, a)
  end
  if hud.fade > 0 then mvl.rect(0, 0, w, h, 0, 0, 0, hud.fade) end
  if hud.card then
    local a = math.min(1, hud.card_time)
    local tw = mvl.text_width(hud.card, 2)
    mvl.text((w - tw) / 2, h / 2 - 8, hud.card, 2, 1, 0.85, 0.5, a)
  end
  -- crosshair dot
  if not touch then mvl.rect(w / 2 - 1, h / 2 - 1, 2, 2, 1, 1, 1, 0.5) end
end

return hud
