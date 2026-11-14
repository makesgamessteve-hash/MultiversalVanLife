-- Save stress: 200 arrivals in generated lands, with changes in each
-- (things taken and put down, people talked to, the codex, quests solved
-- or given up, nights passing and revisits with their aftermath). The
-- save folder is measured afterwards by tests/run_save_stress.cmake.
local D = game.debug
local talk = require("lib.talk")
H.new_game_in_van(9090)
local G = D.gen.world

-- 200 lands on the planets of tonight's signals
local addrs = {}
for _, s in ipairs(D.story.signals()) do
  local paddr = s.address:match("^(.-%.p%d+)")
  for _, c in ipairs(G:generate(paddr).data.countries or {}) do
    for i = 0, 11 do
      if #addrs < 200 then addrs[#addrs + 1] = paddr .. ".k" .. (c.continent - 1) .. ".n" .. c.index .. ".l" .. i end
    end
  end
end
test.expect(#addrs == 200, "200 lands to visit: " .. #addrs)

local function arrive(addr)
  D.world.load("land", nil, { address = addr })
  D.progress.set_location("land:" .. addr)
  local node = D.world.current.land_node
  D.progress.log_visit({ address = addr, name = node.data.name, planet = "?", galaxy = addr:match("^(u%d+%.g%d+)"),
                         night = D.progress.night() })
  return D.world.current, node
end

for k, addr in ipairs(addrs) do
  local w, node = arrive(addr)
  local log = w:memory()
  local s = w.state.quest
  -- take something, put things down
  if s and s.q.items[1] then
    log:take(s.q.items[1])
    s.taken[s.q.items[1]] = true
  end
  for j = 1, 3 do
    log:place({ role = "dropped", sprite = "book", x = (node.data.spots.square or { x = 0 }).x + j,
                z = (node.data.spots.square or { z = 0 }).z, w = 0.4, h = 0.4 })
  end
  -- talk to the villagers (memory, codex)
  for _, p in ipairs(node.data.people) do talk.lines(w, node, p) end
  -- solve every third trouble, give up on every seventh
  if s and k % 3 == 0 then s.finish() elseif s and k % 7 == 0 then
    s.give_up_menu()
    D.story.menu.items[2].action()
  end
  if s then s.remember() end
  if k % 10 == 0 then
    D.progress.save()
    D.progress.end_night()
  end
end
-- revisits: what came of it all
for k = 3, 60, 3 do arrive(addrs[k]) end
D.progress.save()
H.finish_dialogue(400)
test.expect(#D.progress.logbook() >= 200, "200 lands in the logbook")
mvl.log("stress: " .. #addrs .. " lands visited, night " .. D.progress.night())
