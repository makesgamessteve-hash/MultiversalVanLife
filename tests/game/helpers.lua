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
  for _, it in ipairs(D().world.interactables) do
    if it.prompt and it.prompt:find(pattern) and (not it.enabled or it.enabled()) then return it end
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

function H.current() return D().world.current.def.id end

-- Starts a fresh game and skips the intro on the farm.
function H.new_game()
  D().start(true)
  test.wait(5)
end

-- Starts a new game that already met the van, standing in the van.
function H.new_game_in_van()
  D().start(true)
  D().progress.set_flag("van_met")
  D().world.load("van")
  test.wait(5)
end

function H.travel(dest_pattern)
  test.eq(H.current(), "van", "in the van")
  H.use("console")
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
