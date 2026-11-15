-- The codex: entries unlocked by visiting, talking, reading inscriptions and
-- observing; a saint's entry with the villager's version of the story; the
-- why view of a tradition; Juniper's correction of a legend; browsing and
-- following links by keyboard and by tapping.
local D = game.debug
local K = require("memory.codex")
local C = D.codex
local W = D.gen.history.wanderer

local function visit(addr)
  if H.current() ~= "van" then H.use("Enter the van") H.finish_dialogue() end
  H.travel_to(addr)
  H.step_outside()
end

-- a peopled land (in a universe Juniper knows, if `known`) satisfying `pred`
local function find_land(pred, known)
  local G = D.gen.world
  for _, s in ipairs(D.story.signals()) do
    local paddr = s.address:match("^(.-%.p%d+)")
    local u = tonumber(paddr:match("^u(%d+)"))
    if known == nil or W.visited(G, u) == known then
      for cid, c in ipairs(G:generate(paddr).data.countries or {}) do
        if c.culture then
          for _, a in ipairs(H.country_lands(paddr, cid, 12)) do
            local l = G:generate(a)
            if l.data.codex and pred(l.data) then return a, l end
          end
        end
      end
    end
  end
end

local function seed_with(pred, known)
  for seed = 7000, 7040 do
    H.new_game_in_van(seed)
    local a, l = find_land(pred, known)
    if a then return a, l end
  end
end

-- talks to the villagers (not the giver) until `done()` or `max` talks
local function talk_until(done, max)
  local d = D.world.current.land_node.data
  for n = 1, max do
    local p = d.people[(n - 1) % math.max(1, #d.people - 1) + 2] or d.people[1]
    H.use("Talk to " .. p.name)
    H.collect_lines()
    if done() then return true end
  end
  return false
end

local function tap(rect)
  local w, h = mvl.ui_size()
  test.touch("down", 9, (rect.x + rect.w / 2) / w, (rect.y + rect.h / 2) / h)
  test.wait(1)
  test.touch("up", 9)
  test.wait(2)
end

local function rect(label)
  for _, r in ipairs(C.rects) do if r.label == label then return r end end
end

-- ------------------------------------------- unlocking by conversation
local addr = seed_with(function(d)
  local why = {}
  local tr = d.codex.entries[d.codex.keys.traditions]
  for _, c in ipairs(tr and tr.why or {}) do why[c.category] = true end
  return d.lore.saint and d.codex.keys.saint and why.religious and why.environmental and why.historical
end)
test.expect(addr, "a land of a people with a saint and traditions with every kind of cause")
visit(addr)
local d = D.world.current.land_node.data
test.expect(K.known(d.codex.keys.place) and K.known(d.codex.keys.faith), "visiting unlocks the place and the faith")
test.expect(not K.known(d.codex.keys.saint), "but not the saint yet")
local saint_id = d.codex.keys.saint
test.expect(talk_until(function() return K.known(saint_id) end, 60), "a villager tells of the saint")
local saint = K.get(saint_id)
test.eq(saint.found.how, "talk", "unlocked by conversation")
test.expect(saint.versions[1] and saint.versions[1].told == d.lore.saint_story, "with the villager's version: " ..
            tostring(saint.versions[1] and saint.versions[1].told))
local teller = saint.versions[1].by
local named = false
for _, p in ipairs(d.people) do if p.name == teller then named = true end end
test.expect(named, "told by a villager of the land: " .. tostring(teller))
K.reset()
test.expect(K.known(saint_id) and K.get(saint_id).versions[1].by == teller, "the codex is read back from the save")

-- ------------------------------------------------------- asking why
-- open the codex from the road atlas in the van's cab
H.use("Enter the van")
H.finish_dialogue()
H.use("atlas")
H.choose(D.story.menu, "Codex")
test.expect(C.active, "the atlas opens the codex")
test.press("right") -- Places
test.press("right") -- Peoples
test.eq(C.TABS[C.tab].id, "peoples", "the peoples tab")
local ways
for i, e in ipairs(C.list) do if e.kind == "tradition" then ways = i end end
test.expect(ways, "the people's traditions are listed")
for _ = 1, #C.list * 2 do
  if C.sel == ways then break end
  test.press("down")
end
test.press("interact")
test.eq(C.entry and C.entry.kind, "tradition", "the tradition is open")
local items = C.items()
local why_at
for i, it in ipairs(items) do if it.label == "Why" then why_at = i end end
test.expect(why_at, "it has a why view")
for _ = 1, #items do
  if C.focus == why_at then break end
  test.press("right")
end
test.press("interact")
test.eq(C.mode, "why", "the why view")
local body = table.concat(C.body(C.entry, C.mode), "\n")
for _, cat in ipairs({ "religious", "historical", "environmental" }) do
  test.expect(body:find("(" .. cat .. ")", 1, true), "it lists " .. cat .. " causes:\n" .. body)
end
-- the faith among the causes is a link to its entry
local faith_link = false
for _, it in ipairs(C.items()) do if it.kind == "link" and it.label == K.get(d.codex.keys.faith).name then faith_link = true end end
test.expect(faith_link, "causes the player knows are links")
test.press("back")
test.eq(C.entry, nil, "back to the list")
test.press("back")
test.expect(not C.active, "closed")
H.finish_dialogue()

-- ------------------------------------------------ inscriptions, creatures
H.use("Step outside")
H.wait_idle()
local carved
for _, f in ipairs(D.world.current.land_node.data.features) do if f.statue or f.trace then carved = f end end
if carved then
  H.use("Read the inscription")
  local said = H.collect_lines()
  test.expect(said[1] and said[1]:find("inscription", 1, true) or said[1]:find("stones", 1, true), "an inscription is read")
end
local w = D.world.current
local cr = w.streamer.creatures:all()[1]
if cr then
  D.player.place(cr.x + 2, cr.z + 2, 0)
  test.until_true(function() return K.known(d.codex.keys.creatures[cr.sp.id] or "?") end, 120, "watching a creature")
  test.eq(K.get(d.codex.keys.creatures[cr.sp.id]).found.how, "observation", "unlocked by observing")
end

-- -------------------------------------------------- Juniper's correction
local function legend_land(known)
  return seed_with(function(dd)
    for _, e in pairs(dd.codex.entries) do
      if e.kind == "event" and e.rule ~= "as it was" and e.believed ~= e.truth then return true end
    end
  end, known)
end
local function hear_a_legend()
  local dd = D.world.current.land_node.data
  local ids = {}
  for told, id in pairs(dd.codex.keys.events) do ids[id] = true end
  local got
  test.expect(talk_until(function()
    for id in pairs(ids) do if K.known(id) and K.get(id).rule ~= "as it was" then got = K.get(id) return true end end
  end, 80), "a villager tells a legend")
  return got
end
local known_addr = legend_land(true)
test.expect(known_addr, "a people with legends, in a universe Juniper wandered through")
visit(known_addr)
local legend = hear_a_legend()
test.eq(legend.found.how, "talk", "heard from a villager")
test.expect(K.juniper_knows(legend), "Juniper knows this universe")
C.open(legend.id)
local modes = {}
for _, m in ipairs(C.modes(C.entry)) do modes[m.id] = true end
test.expect(modes.truth, "the entry offers Juniper's version")
C.mode = "truth"
local both = table.concat(C.body(C.entry, "truth"), "\n")
test.expect(both:find(legend.believed, 1, true) and both:find(legend.truth, 1, true), "both versions side by side:\n" .. both)
C.close()
local other_addr = legend_land(false)
if other_addr then
  visit(other_addr)
  local far = hear_a_legend()
  test.expect(not K.juniper_knows(far), "a universe Juniper never saw")
  C.open(far.id)
  for _, m in ipairs(C.modes(C.entry)) do test.expect(m.id ~= "truth", "only what people believe") end
  C.close()
end

-- ------------------------------------------------------------- touch
mvl.touch(true)
C.open()
test.wait(2)
test.expect(#C.rects > 0, "the codex is drawn with tappable parts")
local first = C.list[1]
tap(rect(first.name))
test.eq(C.entry and C.entry.id, first.id, "tapping an entry opens it")
local link
for _, it in ipairs(C.items()) do if it.kind == "link" then link = it end end
test.expect(link, "the entry links to others")
test.wait(1)
tap(rect(link.label))
test.eq(C.entry and C.entry.name, link.label, "tapping a link follows it")
test.wait(1)
tap(rect("< Back"))
test.eq(C.entry and C.entry.id, first.id, "back returns to where the player came from")
test.wait(1)
tap(rect("History"))
test.eq(C.TABS[C.tab].id, "history", "tapping a tab switches it")
test.wait(1)
tap(rect("X"))
test.expect(not C.active, "tapping X closes the codex")
-- the pause menu reaches it too (and can be tapped)
D.open_pause()
test.wait(2)
local pm = D.pause_menu()
local r = pm.rects[2]
test.eq(pm.items[2].label, "Codex", "the pause menu has the codex")
local uw, uh = mvl.ui_size()
test.touch("down", 8, (r[1] + r[3] / 2) / uw, (r[2] + r[4] / 2) / uh)
test.wait(1)
test.touch("up", 8)
test.wait(2)
test.expect(C.active and game.state == "play", "tapping Codex in the pause menu opens it")
C.close()
mvl.touch(false)
