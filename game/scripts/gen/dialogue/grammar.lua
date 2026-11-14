-- Multiversal Van Life - what people say: a small text grammar (MIT).
--
-- Rules map a symbol to alternatives; "#name#" in an alternative expands
-- another rule or fills a slot from the speaker's world: their culture's
-- greeting, gods (the moon's among them), saint, holidays, beasts, the
-- versions of history they tell, the news, and their memory of the player
-- (the name they know them by and call them by, the deed they remember,
-- their favour). An
-- alternative is only used when every slot it needs is known, so a people
-- without gods never blesses by one. Choices are seeded per character and
-- per conversation: the same talk always says the same, the next one
-- something else. Mods add alternatives with the content table
-- "dialogue_rules" ({ symbol = { alternatives } }).
local G = {}

G.RULES = {
  -- greetings, by what the speaker remembers of the player
  hello = { "#greet#! #welcome#", "#greet#, #stranger_word#.", "#welcome#" },
  greet = { "#greeting# (\"#greeting_meaning#\")", "Hello", "Well met", "Good evening", "#greeting#" },
  welcome = { "Welcome to #place#.", "You're far from home, I think.", "Not many travellers come to #place#.",
              "A visitor! In #place#!", "Mind the path, it's darker than it looks." },
  stranger_word = { "#stranger# (\"stranger\")", "traveller", "stranger", "friend" },
  hello_known = { "Oh, it's you again.", "#greet# again, traveller.", "Back in #place#?", "You came back! Hello again." },
  hello_friend = { "#title#! #place# hasn't forgotten how you #deed#.", "#greet#, #title#! You #deed#; we still talk about it.",
                   "Look who's here: #known_as#, who #deed#!", "Welcome back, #title#. Not a night goes by without someone saying how you #deed#." },
  hello_resent = { "You. You #wrong#. I've nothing to say to you.", "Hmph. #known_as#. We remember how you #wrong#.",
                   "Go away. You #wrong#, and #place# doesn't forget." },
  hello_letdown = { "Oh. It's you. You gave up on us.", "We managed without you, in the end." },
  -- the player is known from stories that travelled here
  hello_heard = { "#greet#! Wait... aren't you #known_as#? Everyone's heard of #rumour#.",
                  "You must be #known_as#! The story of #rumour# got here before you did.",
                  "#known_as#, here in #place#! We've all heard of #rumour#." },
  hello_wary = { "I know who you are. We've heard of #rumour#.", "Hmph. We've heard of #rumour#. Don't try it here." },
  -- what changed since the player was last here
  change_line = { "Have you seen? #change#.", "So much has changed: #change#.", "You won't believe it: #change#." },
  rumour_line = { "Have you heard the story of #rumour#?", "They tell of #rumour#. Was that you?" },
  -- what there is to talk about
  topic = { "#news_line#", "#news_line#", "#idiom#", "#history#", "#faith_line#", "#smalltalk#", "#holiday_line#" },
  news_line = { "Have you heard? #news#.", "Everyone's worried: #news#.", "Times are hard: #news#.", "They say #news#." },
  idiom = { "Stubborn as a #beast#, my grandmother used to say. She meant me.", "Patience: the #plant# doesn't hurry, and it still flowers.",
            "Don't count the #beast#s before they come home.", "A #beast# at night is a guest you didn't invite.",
            "When the #plant# blooms, the hard days are behind us." },
  history = { "The old ones tell of #memory#.", "Every child here learns about #memory#.", "Never forget #memory#. We don't." },
  faith_line = { "We keep #faith#. #virtue_line#", "#deity# watches over #place#, they say.", "Pray to #deity# if you lose your way." },
  virtue_line = { "#virtue# above all.", "They teach #virtue#, and I try." },
  smalltalk = { "The nights are long here, but the stars are good company.", "I could do with a little rain.",
                "My cousin swears your wagon flew. I told her not to be silly.", "Have you eaten? You look hungry." },
  holiday_line = { "#holiday# is coming. You should stay for it!", "We'll light fires for #holiday# soon." },
  -- farewells
  farewell = { "#blessing#", "#blessing#", "Safe roads.", "Off you go, then.", "Come back soon." },
  blessing = { "May #deity# keep you.", "Go with #deity#.", "#deity# light your road.", "May #moon_deity# light your road.",
               "Walk under #moon_deity#'s eye.", "#saint# keep you, as they kept us." },
}

-- What a symbol needs: the slots of an alternative (rules expand recursively).
local function needs(rules, text, slots, depth)
  for name in text:gmatch("#([%w_]+)#") do
    if rules[name] then
      if depth > 6 then return false end
      local any = false
      for _, alt in ipairs(rules[name]) do if needs(rules, alt, slots, depth + 1) then any = true break end end
      if not any then return false end
    elseif slots[name] == nil then
      return false
    end
  end
  return true
end

-- The rules with mods' additions (registry content "dialogue_rules").
function G.rules(R)
  local out = {}
  for k, v in pairs(G.RULES) do
    local list = {}
    for i, s in ipairs(v) do list[i] = s end
    out[k] = list
  end
  for _, extra in ipairs(R and R:table("dialogue_rules") or {}) do
    for k, alts in pairs(extra) do
      out[k] = out[k] or {}
      for _, s in ipairs(alts) do out[k][#out[k] + 1] = s end
    end
  end
  return out
end

-- Expands `symbol` with `slots` (strings or lists to pick from) using rng.
function G.expand(rules, symbol, slots, rng, depth)
  depth = depth or 0
  local alts = {}
  for _, alt in ipairs(rules[symbol] or {}) do if needs(rules, alt, slots, depth) then alts[#alts + 1] = alt end end
  if #alts == 0 then return nil end
  local text = alts[rng:int(1, #alts)]
  local out = text:gsub("#([%w_]+)#", function(name)
    if rules[name] then return G.expand(rules, name, slots, rng, depth + 1) or "" end
    local v = slots[name]
    if type(v) == "table" then v = v[rng:int(1, #v)] end
    return tostring(v)
  end)
  -- sentences start with a capital
  if depth == 0 then out = out:gsub("^%l", string.upper) end
  return out
end

-- The slots of a speaker: land lore `lore`, memory `mem` (or nil).
function G.slots(lore, mem)
  lore = lore or {}
  local s = {
    place = lore.place, news = lore.news and #lore.news > 0 and lore.news or nil, beast = lore.beasts, plant = lore.plants,
    memory = lore.memory, faith = lore.faith, deity = lore.deities, moon_deity = lore.moon_deity, saint = lore.saint,
    virtue = lore.virtue, holiday = lore.holidays, stranger = lore.stranger,
    greeting = lore.greeting and lore.greeting.word, greeting_meaning = lore.greeting and lore.greeting.meaning,
  }
  if mem then
    s.known_as, s.deed, s.wrong, s.rumour, s.change = mem.known_as, mem.deed, mem.wrong, mem.rumour, mem.change
    -- the name to call them by ("Lamplighter" for "the Lamplighter")
    s.title = mem.known_as and (mem.known_as:gsub("^the ", ""):gsub("^%l", string.upper))
  end
  return s
end

-- A conversation: hello (by memory), a topic and a farewell. `seed` is the
-- speaker's, `n` counts their conversations with the player.
function G.talk(R, lore, mem, seed, n, opts)
  local rules = G.rules(R)
  local slots = G.slots(lore, mem)
  local rng = mvl.rng(mvl.hash(seed, "talk", n))
  local hello = "hello"
  if mem then
    if mem.wrong and (mem.favour or 0) < 0 then hello = "hello_resent"
    elseif mem.letdown then hello = "hello_letdown"
    elseif mem.deed and (mem.favour or 0) > 0 then hello = "hello_friend"
    elseif mem.rumour and not mem.met then hello = mem.rumour_rule == "villainise" and "hello_wary" or "hello_heard"
    elseif mem.met then hello = "hello_known" end
  end
  local lines = { G.expand(rules, hello, slots, rng) or G.expand(rules, "hello", slots, rng) }
  if hello ~= "hello_resent" then
    local topic = opts and opts.topic
    if not topic and mem and mem.change then topic = G.expand(rules, "change_line", slots, rng) end
    if not topic and mem and mem.rumour and rng:chance(0.3) then topic = G.expand(rules, "rumour_line", slots, rng) end
    lines[#lines + 1] = topic or G.expand(rules, "topic", slots, rng)
    lines[#lines + 1] = G.expand(rules, "farewell", slots, rng)
  end
  return lines
end

return G
