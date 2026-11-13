-- Multiversal Van Life - simple vertical menu (MIT License).
local audio = require("lib.audio")
local Menu = {}
Menu.__index = Menu

-- items: { { label = "...", action = function() end, enabled = true }, ... }
function Menu.new(title, items, opts)
  opts = opts or {}
  return setmetatable({ title = title, items = items, index = 1, cancel = opts.cancel, subtitle = opts.subtitle }, Menu)
end

function Menu:selectable(i)
  local it = self.items[i]
  return it and it.enabled ~= false
end

function Menu:move(dir)
  local n = #self.items
  for _ = 1, n do
    self.index = (self.index - 1 + dir) % n + 1
    if self:selectable(self.index) then break end
  end
  audio.sfx("ui_move", 0.5)
end

function Menu:update()
  if not self:selectable(self.index) then self:move(1) end
  if mvl.pressed("up") or (mvl.value("move_y") > 0.6 and not self.stick_held) then
    self:move(-1)
  elseif mvl.pressed("down") or (mvl.value("move_y") < -0.6 and not self.stick_held) then
    self:move(1)
  end
  self.stick_held = math.abs(mvl.value("move_y")) > 0.6
  if mvl.pressed("interact") then
    local it = self.items[self.index]
    if it and it.enabled ~= false and it.action then
      audio.sfx("ui_select", 0.7)
      it.action()
      return true
    end
  elseif (mvl.pressed("back") or mvl.pressed("menu")) and self.cancel then
    self.cancel()
    return true
  end
  return false
end

function Menu:draw(y)
  local w, h = mvl.ui_size()
  local widest = mvl.text_width(self.title, 2)
  for _, it in ipairs(self.items) do widest = math.max(widest, mvl.text_width(it.label) + 24) end
  local bw = math.min(w - 16, widest + 32)
  local bh = 34 + #self.items * 14 + (self.subtitle and 12 or 0)
  local bx = math.floor((w - bw) / 2)
  y = y or math.floor((h - bh) / 2)
  mvl.rect(bx, y, bw, bh, 0.03, 0.04, 0.1, 0.9)
  mvl.rect(bx, y, bw, 1, 1, 0.7, 0.3, 1)
  mvl.text(bx + (bw - mvl.text_width(self.title, 2)) / 2, y + 6, self.title, 2, 1, 0.8, 0.45, 1)
  local iy = y + 28
  if self.subtitle then
    mvl.text(bx + (bw - mvl.text_width(self.subtitle)) / 2, iy, self.subtitle, 1, 0.7, 0.7, 0.8, 1)
    iy = iy + 12
  end
  for i, it in ipairs(self.items) do
    local sel = i == self.index
    local r, g, b = 0.85, 0.85, 0.9
    if it.enabled == false then r, g, b = 0.4, 0.4, 0.45 elseif sel then r, g, b = 1, 0.85, 0.4 end
    local label = (sel and "> " or "  ") .. it.label
    mvl.text(bx + 16, iy + (i - 1) * 14, label, 1, r, g, b, 1)
  end
end

return Menu
