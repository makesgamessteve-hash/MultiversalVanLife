-- Quests from tensions with lore, and people who talk like their culture:
-- the lore in every quest over many seeds, quests built from the land's
-- strongest tension with real stakeholders, blessings by the gods of the
-- speaker's people (the moon's among them), little repetition in a
-- village, and greetings that follow what people remember.
local gen = require("gen")
local grammar = gen.dialogue and gen.dialogue.grammar or require("gen.dialogue.grammar")
gen.planet.LEVEL = 3

-- ------------------------------------------- lands over many seeds
local lands = {}
for seed = 1, 6 do
  local G = gen.run.new(gen.cosmos, { seed = seed * 7919, mods = {} })
  local got, empty = 0, 0
  for s = 0, 300 do
    local saddr = "u" .. (1 + s % 9) .. ".g" .. (s % 13) .. ".c" .. (s % 3) .. ".s" .. (s % 5)
    local ok, sys = pcall(G.generate, G, saddr)
    if ok then
      for i = 0, sys.data.planets - 1 do
        if got < 10 and sys.children[i].kind == "rocky" then
          local p = G:generate(saddr .. ".p" .. i)
          for id, c in ipairs(p.data.countries or {}) do
            -- mostly lands of peoples, and some of empty countries
            local take = (c.culture and id % 2 == 1 and got < 10) or (not c.culture and empty < 2 and id % 5 == 1)
            if take then
              local l = G:generate(p.address .. ".k" .. (c.continent - 1) .. ".n" .. c.index .. ".l" .. (s % 40))
              if l.data.quest then
                lands[#lands + 1] = { G = G, node = l }
                if c.culture then got = got + 1 else empty = empty + 1 end
              end
            end
          end
        end
      end
    end
    if got >= 10 then break end
  end
end
test.expect(#lands >= 50, "lands with quests over six seeds: " .. #lands)

-- --------------------------------------------- lore in every quest
local peopled, rich, kinds = 0, 0, {}
for _, x in ipairs(lands) do
  local d, q = x.node.data, x.node.data.quest
  kinds[q.kind] = true
  test.expect(d.tensions and #d.tensions > 0, "every land has tensions")
  test.eq(q.tension, d.tensions[1].text, "the quest comes from the land's strongest tension")
  test.eq(q.kind, d.tensions[1].quest, "of the kind the tension calls for")
  test.eq(q.giver, d.people[1].id, "given by a person of the land")
  local intro = table.concat(gen.quests.intro(x.G.registry, q), " ")
  test.expect(not intro:find("{", 1, true), "every word of the quest is filled: " .. intro)
  test.expect(q.lore and #q.lore > 0, "the quest has lore")
  local named = false
  for _, v in ipairs(q.lore) do if intro:find(v, 1, true) then named = true end end
  test.expect(named, "the giver names the lore: " .. intro)
  if d.culture then
    peopled = peopled + 1
    -- beyond the place: a person, saint, god, holiday, event or rival
    for _, v in ipairs(q.lore) do if v ~= d.name then rich = rich + 1 break end end
  end
  -- stakeholders are real people of the land
  local ids = {}
  for _, p in ipairs(d.people) do ids[p.id] = true end
  for _, party in ipairs(q.parties or {}) do test.expect(ids[party.person], "a party speaks through a villager") end
end
test.expect(peopled >= 40, "lands of peoples: " .. peopled)
test.expect(rich >= peopled * 0.4, "most peoples' quests name more than the place: " .. rich .. "/" .. peopled)
local nk = 0
for _ in pairs(kinds) do nk = nk + 1 end
test.expect(nk >= 6, "many kinds of quest: " .. nk)

-- ------------------------------------------------------ blessings
local rules = grammar.rules(gen.cosmos)
local moon
for _, x in ipairs(lands) do if x.node.data.lore.moon_deity and not moon then moon = x.node end end
if not moon then
  -- a people of a moon-lit world somewhere
  local G = gen.run.new(gen.cosmos, { seed = 4242, mods = {} })
  for s = 0, 400 do
    local saddr = "u" .. (1 + s % 9) .. ".g" .. (s % 13) .. ".c" .. (s % 3) .. ".s" .. (s % 5)
    local ok, sys = pcall(G.generate, G, saddr)
    if ok and not moon then
      for i = 0, sys.data.planets - 1 do
        if not moon and sys.children[i].kind == "rocky" then
          local p = G:generate(saddr .. ".p" .. i)
          for _, c in ipairs(p.data.countries or {}) do
            local cul = c.culture and p.data.cultures[c.culture]
            local rel = cul and p.data.religions[cul.religion]
            local has = false
            for _, g in ipairs(rel and rel.deities or {}) do if g.domain:find("moon") then has = true end end
            if has and not moon then
              moon = G:generate(p.address .. ".k" .. (c.continent - 1) .. ".n" .. c.index .. ".l3")
            end
          end
        end
      end
    end
    if moon then break end
  end
end
test.expect(moon, "a land of moon worshippers")
local lore = moon.data.lore
test.expect(lore.moon_deity, "their moon deity is known: " .. tostring(lore.moon_deity))
local by_moon, blessings = 0, 0
for n = 1, 60 do
  local line = grammar.expand(rules, "blessing", grammar.slots(lore), mvl.rng(n))
  blessings = blessings + 1
  if line:find(lore.moon_deity, 1, true) then by_moon = by_moon + 1 end
end
test.expect(by_moon > 0, "farewells can invoke the moon deity by name: " .. by_moon .. "/" .. blessings)
-- a people without gods never blesses by one
local godless = { place = "Nowhere", news = { "the wells are dry" } }
for n = 1, 30 do
  local line = grammar.expand(rules, "farewell", grammar.slots(godless), mvl.rng(n))
  test.expect(line and not line:find("#", 1, true) and not line:find("May ", 1, true), "no unknown slots: " .. tostring(line))
end

-- ---------------------------------------------- repetition in a village
local village = lands[1].node
for _, x in ipairs(lands) do if #x.node.data.people >= 3 and x.node.data.culture then village = x.node break end end
local seen, total, repeats = {}, 0, 0
for _, p in ipairs(village.data.people) do
  local last
  for n = 0, 5 do
    local lines = grammar.talk(gen.cosmos, village.data.lore, { met = n > 0, talks = n, favour = 0, known_as = "traveller" },
                               mvl.hash(village.seed, p.id), n)
    local whole = table.concat(lines, " | ")
    test.expect(#lines >= 2 and #lines <= 3, "short conversations")
    for _, l in ipairs(lines) do
      test.expect(not l:find("#", 1, true) and not l:find("{", 1, true), "fully expanded: " .. l)
      test.expect(#l <= 140, "lines fit the text box: " .. l)
      total = total + 1
      if seen[l] then repeats = repeats + 1 end
      seen[l] = true
    end
    test.expect(whole ~= last, "nobody says the same thing twice in a row")
    last = whole
  end
end
test.expect(repeats / total <= 0.45, string.format("little repetition in a village: %d of %d lines repeated", repeats, total))
test.eq(table.concat(grammar.talk(gen.cosmos, village.data.lore, nil, 7, 2), "|"),
        table.concat(grammar.talk(gen.cosmos, village.data.lore, nil, 7, 2), "|"), "the same talk says the same")

-- --------------------------------------------------- greetings by memory
local friend = grammar.talk(gen.cosmos, lore, { met = true, favour = 2, deed = "lit our lamps again",
                                               known_as = "the Lamplighter" }, 5, 3)
test.expect(friend[1]:lower():find("the lamplighter", 1, true) and friend[1]:find("lit our lamps again", 1, true),
            "a friend is greeted by name and deed: " .. friend[1])
local foe = grammar.talk(gen.cosmos, lore, { met = true, favour = -2, wrong = "gave the water to them",
                                            known_as = "the Peacemaker" }, 5, 3)
test.eq(#foe, 1, "someone wronged says little")
test.expect(foe[1]:find("gave the water to them", 1, true), "and says why: " .. foe[1])
local known = grammar.talk(gen.cosmos, lore, { met = true, favour = 0, known_as = "traveller" }, 5, 3)
test.expect(not known[1]:find("Welcome to", 1, true), "an acquaintance is not welcomed as a stranger: " .. known[1])
