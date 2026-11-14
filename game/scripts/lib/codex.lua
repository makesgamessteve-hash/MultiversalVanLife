-- Multiversal Van Life - the codex screen (MIT).
--
-- Everything the player has learned (memory/codex.lua) and the Wanderer's
-- chronicle of their own deeds, reachable from the van's console and the
-- pause menu (or the "codex" action). Tabs filter the list; an entry shows
-- its text, the versions people told, what really happened where Juniper
-- knows it ("They say" / "Juniper knows"), why it is so ("Why": its causes,
-- religious, historical and environmental; undiscovered ones are unknown)
-- and links to other entries. Keyboard and gamepad: up/down choose or
-- scroll, left/right switch tabs or buttons, interact opens or follows,
-- back returns. Touch: tap a tab, a row, a button or a link.
local audio = require("lib.audio")
local K = require("memory.codex")

local C = { active = false, rects = {} }

C.TABS = {
  { id = "all", label = "All" },
  { id = "places", label = "Places", kinds = { place = true } },
  { id = "peoples", label = "Peoples", kinds = { species = true, faction = true, language = true, tradition = true } },
  { id = "faiths", label = "Faiths", kinds = { religion = true, individual = true } },
  { id = "history", label = "History", kinds = { event = true } },
  { id = "creatures", label = "Creatures", kinds = { creature = true } },
  { id = "chronicle", label = "Chronicle", kinds = { chronicle = true } },
}

local KIND_LABEL = { place = "place", species = "people", faction = "nation", language = "language",
                     tradition = "traditions", religion = "faith", individual = "person", event = "event",
                     creature = "creature", chronicle = "deed" }

-- ------------------------------------------------------------ chronicle
-- The Wanderer's chronicle: every deed of the player, where it happened,
-- and what came of it since (from the lands' change logs).
function C.chronicle()
  local spread = require("memory.spread")
  local changes = require("memory.changes")
  local out = {}
  for i, deed in ipairs(spread.deeds()) do
    local log = changes.open(deed.address)
    local after = {}
    for _, ev in ipairs(log.events or {}) do
      if ev.night >= deed.night and not ev.text:find("^the coming of") and not ev.text:find("^the stranger who") then
        after[#after + 1] = "Night " .. ev.night .. ": " .. ev.text .. "."
      end
    end
    for _, n in ipairs(log.aftermath and log.aftermath.news or {}) do after[#after + 1] = "They say " .. n .. "." end
    local heard = 0
    for _ in pairs(log.characters or {}) do heard = heard + 1 end
    local text = string.format("Night %d, %s: %s %s.", deed.night, deed.place or "?",
                               deed.result == "abandoned" and "You" or (deed.title:gsub("^%l", string.upper)), deed.text)
    if deed.result ~= "abandoned" and deed.favoured then text = text .. " You sided with " .. deed.favoured .. "." end
    out[#out + 1] = { id = "chronicle:" .. i, kind = "chronicle", name = (deed.result == "abandoned" and "Given up" or
                      deed.title:gsub("^%l", string.upper)) .. " in " .. (deed.place or "?"), text = text,
                      consequences = after, links = { deed.address }, deed = deed }
  end
  return out
end

-- ----------------------------------------------------------------- state
local function entries_of(tab)
  if tab.id == "chronicle" then return C.chronicle() end
  local out = {}
  for _, e in ipairs(K.list()) do if not tab.kinds or tab.kinds[e.kind] then out[#out + 1] = e end end
  if tab.id == "all" then for _, e in ipairs(C.chronicle()) do out[#out + 1] = e end end
  return out
end

local function entry_by_id(id)
  local e = K.get(id)
  if e then return e end
  for _, x in ipairs(C.chronicle()) do if x.id == id then return x end end
end

-- Opens the codex (on an entry id, optionally).
function C.open(id)
  C.active, C.tab, C.sel, C.top, C.history = true, 1, 1, 0, {}
  C.list = entries_of(C.TABS[1])
  C.entry, C.mode, C.scroll, C.focus = nil, "story", 0, 1
  K.opened()
  audio.sfx("ui_select", 0.6)
  if id then C.show(id) end
end

function C.close()
  C.active, C.entry = false, nil
  audio.sfx("ui_move", 0.5)
end

function C.set_tab(i)
  C.tab = (i - 1) % #C.TABS + 1
  C.list, C.sel, C.top = entries_of(C.TABS[C.tab]), 1, 0
  audio.sfx("ui_move", 0.5)
end

-- Shows entry `id` (remembering where the player came from).
function C.show(id, from_history)
  local e = entry_by_id(id)
  if not e then return false end
  if C.entry and not from_history then C.history[#C.history + 1] = C.entry.id end
  C.entry, C.mode, C.scroll, C.focus = e, "story", 0, 1
  audio.sfx("ui_select", 0.6)
  return true
end

function C.back()
  if not C.entry then C.close() return end
  local prev = table.remove(C.history)
  if prev then C.show(prev, true) else C.entry = nil end
end

-- The modes an entry offers: story, truth (where Juniper knows a different
-- story), why (when it has causes).
function C.modes(e)
  local out = { { id = "story", label = e.believed and "They say" or "Entry" } }
  if e.believed and e.truth and e.truth ~= e.believed and K.juniper_knows(e) then
    out[#out + 1] = { id = "truth", label = "Juniper knows" }
  end
  if e.why and #e.why > 0 then out[#out + 1] = { id = "why", label = "Why" } end
  return out
end

-- The lines of the current view of entry `e` (plain text paragraphs).
function C.body(e, mode)
  local out = {}
  if mode == "why" then
    out[#out + 1] = "Why is it so? Because of:"
    for _, c in ipairs(e.why) do
      local known = not c.id or K.known(c.id)
      out[#out + 1] = "- " .. (known and c.name or "something you have not learned yet") .. " (" .. c.category .. ")"
    end
    return out
  end
  if mode == "truth" then
    out[#out + 1] = "What the people believe: " .. e.believed
    out[#out + 1] = "What really happened, as Juniper knows it: " .. e.truth
    return out
  end
  if e.gloss then out[#out + 1] = "\"" .. e.name .. "\" means \"" .. e.gloss .. "\"." end
  out[#out + 1] = e.text or e.believed or ""
  local function norm(s) return (tostring(s):lower():gsub("[%.%s]+$", "")) end
  for _, v in ipairs(e.versions or {}) do
    if norm(v.told) == norm(e.text) then
      out[#out + 1] = "So " .. (v.by or "they") .. " told it" .. (v.where and (" in " .. v.where) or "") .. "."
    else
      out[#out + 1] = (v.by and (v.by .. " told it") or "It is told") .. (v.where and (" in " .. v.where) or "") ..
                      ": \"" .. (v.told:gsub("^%l", string.upper)) .. "\""
    end
  end
  for _, c in ipairs(e.consequences or {}) do out[#out + 1] = c end
  if e.consequences and #e.consequences == 0 then out[#out + 1] = "Nothing has come of it yet." end
  if e.found then
    local how = { visit = "seen on a visit to", talk = "heard in", inscription = "read on stones in",
                  observation = "watched in" }
    out[#out + 1] = "(" .. (how[e.found.how] or "found in") .. " " .. tostring(e.found.where) .. ", night " ..
                    e.found.night .. ")"
  end
  return out
end

-- Links of an entry that lead somewhere the player knows.
function C.links(e)
  local out = {}
  for _, id in ipairs(e.links or {}) do
    local x = entry_by_id(id)
    if x and x ~= e then out[#out + 1] = x end
  end
  for _, c in ipairs(C.mode == "why" and e.why or {}) do
    if c.id and K.known(c.id) then out[#out + 1] = entry_by_id(c.id) end
  end
  return out
end

-- The focusable items of the entry view: mode buttons, links, back.
function C.items()
  local e = C.entry
  local out = {}
  for _, m in ipairs(C.modes(e)) do
    out[#out + 1] = { label = m.label, kind = "mode", action = function() C.mode, C.scroll = m.id, 0 end,
                      on = C.mode == m.id }
  end
  for _, x in ipairs(C.links(e)) do
    out[#out + 1] = { label = x.name, kind = "link", action = function() C.show(x.id) end }
  end
  out[#out + 1] = { label = "< Back", kind = "back", action = function() C.back() end }
  return out
end

-- ----------------------------------------------------------------- input
local function tapped()
  for _, t in ipairs(mvl.taps()) do
    for _, r in ipairs(C.rects) do
      if t.x >= r.x and t.x <= r.x + r.w and t.y >= r.y and t.y <= r.y + r.h then
        r.action()
        return true
      end
    end
  end
  return false
end

function C.update(dt)
  if not C.active then return false end
  if tapped() then return true end
  local up = mvl.pressed("up") or (mvl.value("move_y") > 0.6 and not C.stick)
  local down = mvl.pressed("down") or (mvl.value("move_y") < -0.6 and not C.stick)
  local left = mvl.pressed("left") or (mvl.value("move_x") < -0.6 and not C.stick_x)
  local right = mvl.pressed("right") or (mvl.value("move_x") > 0.6 and not C.stick_x)
  C.stick, C.stick_x = math.abs(mvl.value("move_y")) > 0.6, math.abs(mvl.value("move_x")) > 0.6
  if mvl.pressed("menu") or mvl.pressed("codex") then C.close() return true end
  if C.entry then
    local items = C.items()
    if up then C.scroll = math.max(0, C.scroll - 1) end
    if down then C.scroll = math.min(C.max_scroll or 0, C.scroll + 1) end
    if left then C.focus = (C.focus - 2) % #items + 1 audio.sfx("ui_move", 0.5) end
    if right then C.focus = C.focus % #items + 1 audio.sfx("ui_move", 0.5) end
    C.focus = math.min(C.focus, #items)
    if mvl.pressed("interact") then items[C.focus].action() end
    if mvl.pressed("back") then C.back() end
    return true
  end
  if left then C.set_tab(C.tab - 1) end
  if right then C.set_tab(C.tab + 1) end
  if up and #C.list > 0 then C.sel = (C.sel - 2) % #C.list + 1 audio.sfx("ui_move", 0.5) end
  if down and #C.list > 0 then C.sel = C.sel % #C.list + 1 audio.sfx("ui_move", 0.5) end
  if mvl.pressed("interact") and C.list[C.sel] then C.show(C.list[C.sel].id) end
  if mvl.pressed("back") then C.close() end
  return true
end

-- ------------------------------------------------------------------ draw
local LINE = 10

local function button(x, y, label, on, focused, action)
  local w = mvl.text_width(label) + 8
  mvl.rect(x, y, w, 12, on and 0.35 or 0.12, on and 0.25 or 0.12, on and 0.1 or 0.2, 0.95)
  if focused then mvl.rect(x, y + 11, w, 1, 1, 0.8, 0.4, 1) end
  mvl.text(x + 4, y + 2, label, 1, focused and 1 or 0.85, focused and 0.85 or 0.85, focused and 0.4 or 0.9, 1)
  C.rects[#C.rects + 1] = { x = x, y = y, w = w, h = 12, label = label, action = action }
  return w
end

function C.draw(touch)
  if not C.active then return end
  C.rects = {}
  local W, H = mvl.ui_size()
  local x0, y0, pw, ph = 6, 6, W - 12, H - 12
  mvl.rect(x0, y0, pw, ph, 0.03, 0.04, 0.1, 0.94)
  mvl.rect(x0, y0, pw, 1, 1, 0.7, 0.3, 1)
  mvl.text(x0 + 6, y0 + 5, "CODEX", 1, 1, 0.8, 0.45, 1)
  mvl.text(x0 + 48, y0 + 5, K.count() .. " entries", 1, 0.6, 0.6, 0.7, 1)
  -- with touch controls the pause button sits in the top right corner:
  -- keep the close button and the tabs clear of it
  local corner = touch and 66 or 0
  local function right_edge(y) return x0 + pw - 6 - (y < y0 + 70 and corner or 0) end
  button(right_edge(y0) - 16, y0 + 3, "X", false, false, function() C.close() end)
  -- tabs (wrapping on narrow screens)
  local tx, ty = x0 + 6, y0 + 20
  for i, t in ipairs(C.TABS) do
    local w = mvl.text_width(t.label) + 8
    if tx + w > right_edge(ty) then tx, ty = x0 + 6, ty + 14 end
    button(tx, ty, t.label, i == C.tab, not C.entry and i == C.tab, function() C.entry = nil C.set_tab(i) end)
    tx = tx + w + 3
  end
  local top = ty + 18
  local bottom = y0 + ph - 6
  if not C.entry then
    -- the list
    if #C.list == 0 then
      mvl.text(x0 + 8, top, mvl.wrap("Nothing here yet. Talk to people, read old stones, watch the creatures.",
                                     pw - 16, 1), 1, 0.6, 0.6, 0.7, 1)
      return
    end
    local rows = math.max(1, math.floor((bottom - top) / 14))
    if C.sel > C.top + rows then C.top = C.sel - rows end
    if C.sel <= C.top then C.top = C.sel - 1 end
    for i = C.top + 1, math.min(#C.list, C.top + rows) do
      local e = C.list[i]
      local y = top + (i - C.top - 1) * 14
      local sel = i == C.sel
      if sel then mvl.rect(x0 + 4, y - 1, pw - 8, 13, 0.25, 0.18, 0.08, 0.9) end
      local tag = KIND_LABEL[e.kind] or e.kind
      local name = e.name
      local room = pw - 24 - mvl.text_width(tag)
      while mvl.text_width(name) > room and #name > 4 do name = name:sub(1, #name - 4) .. "..." end
      mvl.text(x0 + 8, y + 1, name, 1, sel and 1 or 0.88, sel and 0.85 or 0.88, sel and 0.4 or 0.92, 1)
      mvl.text(x0 + pw - 8 - mvl.text_width(tag), y + 1, tag, 1, 0.55, 0.6, 0.7, 1)
      C.rects[#C.rects + 1] = { x = x0 + 4, y = y - 1, w = pw - 8, h = 13, label = e.name,
                                action = function() C.sel = i C.show(e.id) end }
    end
    local hint = touch and "tap an entry" or "[E] open  [<>] tabs  [Back] close"
    mvl.text(x0 + pw - 8 - mvl.text_width(hint), bottom - 9, hint, 1, 0.5, 0.5, 0.6, 1)
    return
  end
  -- an entry
  local e = C.entry
  mvl.text(x0 + 8, top, e.name, 1, 1, 0.85, 0.5, 1)
  local tag = KIND_LABEL[e.kind] or e.kind
  mvl.text(x0 + pw - 8 - mvl.text_width(tag), top, tag, 1, 0.55, 0.6, 0.7, 1)
  local items = C.items()
  C.focus = math.min(C.focus, #items)
  -- buttons: modes, then back
  local bx, by = x0 + 8, top + 13
  for i, it in ipairs(items) do
    if it.kind ~= "link" then
      local w = mvl.text_width(it.label) + 8
      if bx + w > x0 + pw - 8 then bx, by = x0 + 8, by + 14 end
      button(bx, by, it.label, it.on, i == C.focus, it.action)
      bx = bx + w + 3
    end
  end
  -- body: wrapped paragraphs, scrolled
  local lines = {}
  for _, para in ipairs(C.body(e, C.mode)) do
    local wrapped = mvl.wrap(para, pw - 20, 1)
    for l in (wrapped .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = l end
    lines[#lines + 1] = ""
  end
  -- links under the body
  local links = {}
  for i, it in ipairs(items) do if it.kind == "link" then links[#links + 1] = { i = i, it = it } end end
  local link_rows = #links > 0 and #links + 1 or 0
  local body_top = by + 18
  local rows = math.max(1, math.floor((bottom - body_top) / LINE) - link_rows * 14 // LINE)
  C.max_scroll = math.max(0, #lines - rows)
  C.scroll = math.min(C.scroll, C.max_scroll)
  for i = 1, rows do
    local l = lines[C.scroll + i]
    if l then mvl.text(x0 + 10, body_top + (i - 1) * LINE, l, 1, 0.92, 0.9, 0.85, 1) end
  end
  if C.max_scroll > 0 then
    mvl.text(x0 + pw - 14, body_top, C.scroll > 0 and "^" or " ", 1, 0.8, 0.7, 0.5, 1)
    mvl.text(x0 + pw - 14, body_top + (rows - 1) * LINE, C.scroll < C.max_scroll and "v" or " ", 1, 0.8, 0.7, 0.5, 1)
  end
  if #links > 0 then
    local ly = bottom - link_rows * 14 + 2
    mvl.text(x0 + 8, ly, "See also:", 1, 0.6, 0.6, 0.7, 1)
    for k, l in ipairs(links) do
      button(x0 + 14, ly + k * 14 - 2, l.it.label, false, l.i == C.focus, l.it.action)
    end
  end
end

return C
