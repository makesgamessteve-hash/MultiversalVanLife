-- Shared helpers for automated game tests (MIT License).
-- Tests run as coroutines inside the real game (headless runner), drive it
-- through input actions and inspect state through game.debug.
H = {}
local D = function() return game.debug end

-- Presses "interact" until no dialogue is shown (max `limit` presses).
function H.finish_dialogue(limit)
  for _ = 1, limit or 40 do
    if not D().dialogue.active() then return end
    test.press("interact")
  end
  test.expect(not D().dialogue.active(), "dialogue should have finished")
end

function H.wait_idle(max_frames)
  test.until_true(function() return not D().story.busy end, max_frames or 600, "story idle")
end

-- Teleports the player next to (x, z) and faces it.
function H.face(x, z, dist)
  local p = D().player
  dist = dist or 1.2
  local ang = math.atan(p.z - z, p.x - x)
  local px, pz = x + math.cos(ang) * dist, z + math.sin(ang) * dist
  p.place(px, pz, math.atan(-(x - px), -(z - pz)))
  test.wait(2)
end

-- Finds an interactable whose prompt matches `pattern`.
function H.find(pattern)
  local level = D().player.base_y or 0
  -- inside the van anything on any floor of the house can be walked to
  local any = D().van.inside
  for _, list in ipairs({ D().world.interactables, D().world.fixed }) do
    for _, it in ipairs(list) do
      if it.prompt and it.prompt:find(pattern) and (not it.enabled or it.enabled())
         and (math.abs((it.y or 0) - level) < 3 or (any and (it.y or 0) < -100)) then return it end
    end
  end
end

function H.pos(it)
  if it.entity and mvl.exists(it.entity) then
    local x, _, z = mvl.get_pos(it.entity)
    return x, z
  end
  return it.x, it.z
end

-- Walks up to the interactable with `pattern` and uses it.
function H.use(pattern)
  local it = H.find(pattern)
  test.expect(it, "interactable '" .. pattern .. "' exists")
  -- inside the van: stand on the floor of the thing's room
  if D().van.inside and it.y then D().player.base_y = it.y end
  local x, z = H.pos(it)
  H.face(x, z, math.min(1.2, it.range * 0.6))
  test.expect(D().world.find_focus() == it, "focus on '" .. pattern .. "'")
  test.press("interact")
  return it
end

-- Chooses a menu entry by label substring.
function H.choose(menu, pattern)
  test.expect(menu, "a menu is open")
  local target
  for i, item in ipairs(menu.items) do if item.label:find(pattern, 1, true) then target = i end end
  test.expect(target, "menu entry '" .. pattern .. "'")
  for _ = 1, #menu.items * 2 do
    if menu.index == target then break end
    test.press("down")
  end
  test.eq(menu.index, target, "menu index")
  test.press("interact")
end

-- "van" while the player is inside the van, otherwise the world's id.
function H.current() return D().van.inside and "van" or D().world.current.def.id end

-- Starts a fresh game on the farm. Tests use fixed multiverse seeds so
-- every run generates the same places.
function H.new_game(seed)
  D().progress.reset(seed or 1001)
  D().progress.save()
  D().start(false)
  test.wait(5)
end

-- Starts a new game that already met the van, standing in the van (with a
-- given multiverse seed, or a fresh one).
function H.new_game_in_van(seed)
  D().progress.reset(seed or 1002)
  D().progress.save()
  D().start(false)
  D().progress.set_flag("van_met")
  D().van.enter(D().player, D().world)
  test.wait(5)
end

function H.travel(dest_pattern)
  test.eq(H.current(), "van", "in the van")
  H.use("radio")
  H.finish_dialogue()
  H.choose(D().story.menu, dest_pattern)
  test.until_true(function() return not D().story.busy end, 600, "travel finished")
  H.finish_dialogue()
end

function H.step_outside()
  H.use("Step outside")
  H.wait_idle()
  test.wait(10)
end

-- Travels straight to a land address from inside the van.
function H.travel_to(addr)
  test.eq(H.current(), "van", "in the van")
  D().story.travel(addr)
  test.until_true(function() return not D().story.busy end, 1200, "arrived")
  H.finish_dialogue()
end

-- A land whose trouble satisfies `pred(template, tensions)`: near
-- tonight's first signal, or in another country of the signals' planets.
function H.land_where(pred)
  local gen = D().gen
  local G = gen.world
  local trouble = gen.history.tensions.trouble
  for k, s in ipairs(D().story.signals()) do
    local base = s.address:match("^(.*)%.l%d+$")
    if k == 1 then
      for i = 0, 255 do
        local addr = base .. ".l" .. i
        if pred(trouble(G, addr)) then return addr end
      end
    end
    local paddr = base:match("^(.-%.p%d+)")
    for _, c in ipairs(G:generate(paddr).data.countries or {}) do
      local cbase = paddr .. ".k" .. (c.continent - 1) .. ".n" .. c.index
      for i = 0, 47 do
        local addr = cbase .. ".l" .. i
        if pred(trouble(G, addr)) then return addr end
      end
    end
  end
end

-- A land with the given quest template.
function H.land_with(template)
  return H.land_where(function(t) return t.id == template end)
end

-- Completes the quest of the current land through the game's interactions.
-- A dispute is settled by `choice` ("a", "b" or "compromise", the default).
function H.complete_quest(choice)
  local w = D().world.current
  local s = w.state.quest
  local q = s.q
  local giver = w.land_node.data.people[1]
  local people = {}
  for _, p in ipairs(w.land_node.data.people) do people[p.id] = p end
  if not s.started then
    H.use("Talk to " .. giver.name)
    H.finish_dialogue()
  end
  if q.kind == "relight" or q.kind == "return" then
    for _ = 1, q.count do H.use(q.kind == "relight" and "Gather the" or "Pick up the") H.finish_dialogue() end
    test.eq(s.carrying, q.count, "carrying everything")
    for _ = 1, q.count do H.use(q.kind == "relight" and "Light the" or "Place the") H.finish_dialogue() end
  elseif q.kind == "gather" then
    for _ = 1, q.count do H.use("Pick up the") H.finish_dialogue() end
    test.expect(not s.complete, "not done before talking to the giver")
    H.use("Talk to " .. giver.name)
  elseif q.kind == "restore" then
    for _ = 1, q.count do H.use("Pick up the") H.finish_dialogue() end
    test.expect(not s.complete, "not done before restoring the source")
    H.use("Restore the")
  elseif q.kind == "message" then
    H.use("Talk to " .. q.recipient.name)
    H.finish_dialogue()
    test.expect(s.delivered and not s.complete, "the word is delivered")
    H.use("Talk to " .. giver.name)
  elseif q.kind == "mediate" then
    for i = 1, 2 do
      H.use("Talk to " .. people[q.parties[i].person].name)
      H.finish_dialogue()
    end
    local menu = D().story.menu
    test.expect(menu and menu.title == "SETTLE THE QUARREL", "after hearing both sides, a settlement is asked for")
    choice = choice or "compromise"
    local label = choice == "compromise" and "compromise" or
                  ("Side with " .. require("lib.landquest").short(q.parties[choice == "a" and 1 or 2].label))
    H.choose(menu, label)
  elseif q.kind == "lost" or q.kind == "escort" then
    local who = q.kind == "lost" and q.lost or q.escort
    H.use("Talk to " .. who.name)
    H.finish_dialogue()
    test.expect(s.following, who.name .. " follows")
    local p = D().player
    local to = q.kind == "lost" and giver or q.destination
    p.place(to.x + 2, to.z + 2, 0)
    test.until_true(function() return s.complete end, 300, who.name .. " arrived")
  end
  H.finish_dialogue()
  return s.complete
end

-- Presses through all dialogue; returns the ids (or texts) of the lines shown.
function H.collect_lines()
  local out, last = {}, nil
  for _ = 1, 80 do
    local cur = D().dialogue.current
    if not cur then break end
    if cur ~= last then out[#out + 1] = cur.id or cur.text last = cur end
    test.press("interact")
  end
  return out
end

function H.said(lines, id)
  for _, l in ipairs(lines) do if l == id then return true end end
  return false
end
