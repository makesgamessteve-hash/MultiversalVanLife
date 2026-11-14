-- Multiversal Van Life - languages: sounds, syllables, a lexicon of meanings
-- and names composed from it; daughter languages by sound changes (MIT).
--
-- A language samples its sounds from a feature table, filtered by what its
-- speakers' mouths can make: no lip sounds for beaks and mandibles (which
-- click instead), long tonal vowels for species that live by hearing. Its
-- syllable templates and phonotactics build roots for about 300 meanings;
-- names join one to three roots by meaning templates and keep their gloss
-- ("Red Hill", "Where the Tide Kneels"). A daughter language applies 2 to 5
-- regular sound changes to every root, so related peoples have related
-- names. Romanisation uses plain letters and an apostrophe for clicks.
local L = {}

-- Consonants: romanisation, place, manner.
L.CONSONANTS = {
  { "p", "labial", "stop" }, { "b", "labial", "stop" }, { "m", "labial", "nasal" }, { "f", "labial", "fricative" },
  { "v", "labial", "fricative" }, { "w", "labial", "glide" },
  { "t", "alveolar", "stop" }, { "d", "alveolar", "stop" }, { "n", "alveolar", "nasal" }, { "s", "alveolar", "fricative" },
  { "z", "alveolar", "fricative" }, { "l", "alveolar", "liquid" }, { "r", "alveolar", "liquid" },
  { "th", "dental", "fricative" }, { "sh", "palatal", "fricative" }, { "ch", "palatal", "affricate" },
  { "j", "palatal", "affricate" }, { "y", "palatal", "glide" },
  { "k", "velar", "stop" }, { "g", "velar", "stop" }, { "ng", "velar", "nasal" }, { "kh", "velar", "fricative" },
  { "h", "glottal", "fricative" }, { "q", "uvular", "stop" },
  { "k'", "click", "click" }, { "t'", "click", "click" }, { "c'", "click", "click" },
}
L.VOWELS = { "a", "e", "i", "o", "u" }
L.LONG = { "aa", "ee", "ii", "oo", "uu" }
L.TEMPLATES = { "CV", "CVC", "V", "VC", "CCV", "CVV" }
local CLUSTERS = { "tr", "kr", "kl", "st", "sk", "gr", "dr", "pr", "pl", "br", "sp", "fr" }
local COMMON = { t = 3, k = 3, n = 3, s = 2.5, m = 2.5, l = 2.2, r = 2.2, d = 1.6, p = 1.8, h = 1.4, y = 1.2 }

-- The ~300 meanings of a lexicon, by kind (kinds steer name templates).
L.MEANINGS = {
  sky = { "sun", "moon", "star", "sky", "cloud", "rain", "wind", "storm", "snow", "ice", "light", "dark", "dawn",
          "dusk", "night", "day", "year", "season", "summer", "winter", "thunder", "rainbow", "heaven", "eclipse",
          "twin", "comet" },
  land = { "hill", "mountain", "valley", "cliff", "cave", "forest", "field", "meadow", "marsh", "desert", "shore",
           "island", "river", "lake", "sea", "spring", "well", "stone", "rock", "sand", "earth", "mud", "ridge",
           "peak", "plain", "bay", "ford", "falls", "glade", "dune", "crag", "fen", "grove", "vale", "steppe", "reef" },
  nature = { "water", "fire", "ash", "smoke", "wave", "tide", "tree", "leaf", "root", "flower", "grass", "seed",
             "fruit", "thorn", "moss", "salt", "iron", "gold", "silver", "crystal", "ember", "frost", "dew", "mist",
             "shadow", "flame", "bone", "blood", "feather", "shell", "horn", "claw", "egg", "nest", "web", "honey" },
  beast = { "beast", "bird", "fish", "hunter", "grazer", "wing", "serpent", "wolf", "bear", "deer", "hawk", "owl",
            "beetle", "moth", "crab", "whale" },
  kin = { "mother", "father", "child", "sister", "brother", "elder", "ancestor", "friend", "stranger", "people",
          "clan", "family", "lord", "lady", "king", "queen", "guest", "host", "maiden", "son", "daughter", "kin" },
  colour = { "red", "white", "black", "green", "blue", "gold", "grey", "bright", "pale", "dark", "silver", "amber" },
  number = { "one", "two", "three", "four", "five", "six", "seven", "many", "hundred", "first", "last", "half" },
  motion = { "go", "come", "rise", "fall", "stand", "kneel", "sleep", "wake", "cross", "return", "wander", "dwell",
             "rest", "flow", "burn", "sing", "speak", "dance", "weep", "laugh", "fly", "swim", "climb", "hide",
             "watch", "wait", "turn", "break", "build", "dream", "remember", "listen" },
  sacred = { "god", "spirit", "soul", "holy", "temple", "prayer", "oath", "blessing", "curse", "death", "life",
             "rebirth", "fate", "omen", "song", "dream", "law", "truth", "sacrifice", "pilgrim", "saint", "prophet",
             "altar", "shrine" },
  place = { "town", "home", "hall", "gate", "bridge", "road", "market", "tower", "wall", "farm", "harbour", "camp",
            "keep", "village", "garden", "field", "fort", "haven", "crossing", "hearth" },
  quality = { "old", "new", "high", "low", "great", "small", "long", "deep", "cold", "warm", "quiet", "far", "near",
              "wide", "narrow", "sweet", "bitter", "wild", "still", "lost", "hidden", "broken", "golden", "sleeping",
              "singing", "burning", "eternal", "lonely", "hollow", "green" },
  virtue = { "brave", "kind", "wise", "true", "patient", "strong", "swift", "gentle", "proud", "free", "honest",
             "loyal", "merry", "calm", "bold", "fair" },
}
-- every meaning once, in a fixed order
L.ORDER = {}
do
  local seen = {}
  for _, kind in ipairs({ "sky", "land", "nature", "beast", "kin", "colour", "number", "motion", "sacred", "place",
                          "quality", "virtue" }) do
    for _, m in ipairs(L.MEANINGS[kind]) do
      if not seen[m] then seen[m] = true; L.ORDER[#L.ORDER + 1] = m end
    end
  end
end
L.KIND = {}
for kind, list in pairs(L.MEANINGS) do for _, m in ipairs(list) do L.KIND[m] = L.KIND[m] or kind end end
local SHORT = {}
for _, k in ipairs({ "kin", "number", "sacred", "sky" }) do for _, m in ipairs(L.MEANINGS[k]) do SHORT[m] = true end end

local function title(s) return s:sub(1, 1):upper() .. s:sub(2) end

-- --------------------------------------------------------------- sounds
local function weighted(rng, list, w)
  local total = 0
  for _, x in ipairs(list) do total = total + w(x) end
  local r = rng:next() * total
  for _, x in ipairs(list) do
    r = r - w(x)
    if r <= 0 then return x end
  end
  return list[#list]
end

-- The sound inventory of a language for a mouth ("lips", "beak",
-- "mandibles") and a tonal (musical) species.
function L.phonology(rng, mouth, tonal)
  local hard = mouth == "beak" or mouth == "mandibles"
  local pool = {}
  for _, c in ipairs(L.CONSONANTS) do
    local ok = not (hard and c[2] == "labial") and (c[3] ~= "click" or hard)
    if ok then pool[#pool + 1] = c end
  end
  local want = rng:int(9, 16)
  local cons, have = {}, {}
  for _ = 1, want * 4 do
    if #cons >= want then break end
    local c = weighted(rng, pool, function(x)
      if have[x[1]] then return 0 end
      return (COMMON[x[1]] or 0.7) * (x[3] == "click" and 2.5 or 1)
    end)
    if not have[c[1]] then have[c[1]] = true; cons[#cons + 1] = c[1] end
  end
  if hard and not have["k'"] then cons[#cons + 1] = "k'" end
  local vowels = {}
  local nv = rng:int(3, 5)
  for i = 1, nv do vowels[i] = L.VOWELS[i] end
  if tonal then for i = 1, rng:int(2, 3) do vowels[#vowels + 1] = L.LONG[i] end end
  local templates = { "CV" }
  for _, t in ipairs(L.TEMPLATES) do
    if t ~= "CV" and rng:chance(0.45) then templates[#templates + 1] = t end
  end
  if tonal and not templates[3] then templates[#templates + 1] = "CVV" end
  local clusters = {}
  for _, cl in ipairs(CLUSTERS) do
    local a, b = cl:sub(1, 1), cl:sub(2, 2)
    if have[a] and have[b] then clusters[#clusters + 1] = cl end
  end
  return { consonants = cons, vowels = vowels, templates = templates, clusters = clusters, mouth = mouth,
           tonal = tonal or false, linker = vowels[rng:int(1, #vowels)] }
end

-- One syllable of a phonology.
local function syllable(rng, ph)
  local t = ph.templates[rng:int(1, #ph.templates)]
  local out = {}
  for i = 1, #t do
    local s = t:sub(i, i)
    if s == "C" then
      if t:sub(i + 1, i + 1) == "C" and #ph.clusters > 0 then
        out[#out + 1] = ph.clusters[rng:int(1, #ph.clusters)]
      elseif t:sub(i - 1, i - 1) ~= "C" then
        out[#out + 1] = ph.consonants[rng:int(1, #ph.consonants)]
      end
    else
      out[#out + 1] = ph.vowels[rng:int(1, #ph.vowels)]
    end
  end
  return table.concat(out)
end

-- Words a generated name must not be or contain (English look-alikes).
L.BLOCKED_PARTS = { "fuck", "shit", "cunt", "nazi", "rape", "nigg", "fag", "slut", "whore", "dick", "cock", "piss",
                    "poop", "kill", "porn", "anal", "twat", "wank", "bitch" }
L.BLOCKED_WORDS = { loser = true, ass = true, die = true, dead = true, tit = true, sex = true, hell = true, damn = true,
                    poo = true, butt = true, fart = true, puke = true, ugly = true, dumb = true, idiot = true,
                    moron = true, stupid = true, hate = true, sick = true, war = true, gun = true }

-- Can a word be read aloud by a player? Letters only (and click
-- apostrophes), a vowel at least every three letters, no letter three
-- times in a row, 2 to 11 letters.
function L.readable(w)
  if #w < 2 or #w > 13 or w:find("[^a-z']") then return false end
  if w:find("^'") or w:find("''") then return false end
  local plain = w:gsub("'", "")
  if plain:find("[^aeiou][^aeiou][^aeiou]") then
    -- three consonant letters: only digraph clusters such as "str", "ngk" are fine
    local ok = true
    for cl in plain:gmatch("[^aeiou]+") do
      if #cl >= 3 and not (cl:find("^ng") or cl:find("^th") or cl:find("^sh") or cl:find("^ch") or cl:find("^kh") or
                           cl:find("ng$") or cl:find("th$") or cl:find("sh$") or cl:find("ch$")) then ok = false end
      if #cl >= 4 then ok = false end
    end
    if not ok then return false end
  end
  if plain:find("(%a)%1%1") or plain:find("[aeiou][aeiou][aeiou]") then return false end
  for _, bad in ipairs(L.BLOCKED_PARTS) do if plain:find(bad, 1, true) then return false end end
  if L.BLOCKED_WORDS[plain] then return false end
  if not plain:find("[aeiou]") then return false end
  local v = select(2, plain:gsub("[aeiou]", ""))
  return v / #plain >= 0.25
end

-- A root of 1 to 3 syllables (shorter for basic words).
local function root(rng, ph, short)
  for _ = 1, 30 do
    local n = short and (rng:chance(0.7) and 1 or 2) or rng:int(1, 3)
    local parts = {}
    for i = 1, n do parts[i] = syllable(rng, ph) end
    local w = table.concat(parts)
    if L.readable(w) then return w end
  end
  return ph.consonants[1] .. ph.vowels[1]
end

-- A language: its phonology and a lexicon of every meaning (unique roots).
function L.generate(seed, mouth, tonal)
  local rng = mvl.rng(seed)
  local ph = L.phonology(rng, mouth, tonal)
  local lex, used = {}, {}
  for _, m in ipairs(L.ORDER) do
    local w
    for _ = 1, 8 do
      w = root(rng, ph, SHORT[m])
      if not used[w] then break end
    end
    used[w] = true
    lex[m] = w
  end
  return { phonology = ph, lexicon = lex, seed = seed, changes = {} }
end

-- ---------------------------------------------------------------- names
-- Joins roots, with the language's linking vowel between two consonants.
local function join(lang, roots)
  local w = roots[1]
  for i = 2, #roots do
    local r = roots[i]
    if not w:sub(-1):find("[aeiou']") and not r:sub(1, 1):find("[aeiou]") then w = w .. lang.phonology.linker end
    w = w .. r
  end
  return w
end

local TEMPLATES = {
  place = { { "colour", "land", "%s %s" }, { "quality", "land", "%s %s" }, { "quality", "place", "%s %s" },
            { "nature", "land", "%s %s" }, { "nature", "motion", "Where the %s %ss" }, { "beast", "land", "%s %s" },
            { "sky", "place", "%s %s" }, { "number", "land", "%s %ss" } },
  person = { { "virtue", "nature", "%s %s" }, { "colour", "beast", "%s %s" }, { "nature", "motion", "%s that %ss" },
             { "virtue", "sky", "%s %s" }, { "quality", "nature", "%s %s" } },
  god = { { "sky", "kin", "%s %s" }, { "nature", "kin", "%s %s" }, { "quality", "sacred", "the %s %s" },
          { "sky", "sacred", "%s of the %s" } },
  country = { { "land", "kin", "Land of the %s %s" }, { "quality", "land", "the %s %ss" }, { "colour", "land", "%s %s" } },
}

-- A name of a kind ("place", "person", "god", "country") from rng:
-- returns the name and its meaning. `fixed` may force meanings.
function L.name(lang, rng, kind, fixed)
  local tpl = TEMPLATES[kind] or TEMPLATES.place
  local longest = kind == "god" and 13 or 10
  local best
  for _ = 1, 12 do
    local t = tpl[rng:int(1, #tpl)]
    local a = fixed and fixed[1] or L.MEANINGS[t[1]][rng:int(1, #L.MEANINGS[t[1]])]
    local b = fixed and fixed[2] or L.MEANINGS[t[2]][rng:int(1, #L.MEANINGS[t[2]])]
    local word = join(lang, { lang.lexicon[a], lang.lexicon[b] })
    local fmt = (fixed and fixed.format) or t[3]
    local second = L.KIND[b] == "motion" and b or title(b)
    local gloss = string.format(fmt, title(a), second)
    gloss = gloss:gsub("^the ", "The ")
    best = { name = title(word:gsub("'$", "")), meaning = gloss, roots = { a, b } }
    if L.readable(word) and #word <= longest then return best end
  end
  -- a single root when compounds are too long
  local a = fixed and fixed[1] or L.MEANINGS[tpl[1][1]][rng:int(1, #L.MEANINGS[tpl[1][1]])]
  if L.readable(lang.lexicon[a]) then return { name = title(lang.lexicon[a]), meaning = title(a), roots = { a } } end
  return best
end

-- The word for a meaning (and back).
function L.word(lang, meaning) return lang.lexicon[meaning] end
function L.translate(lang, word)
  for m, w in pairs(lang.lexicon) do if w == word:lower() then return m end end
end

-- --------------------------------------------------------- sound changes
L.CHANGES = {
  { id = "lenition", note = "stops soften between vowels",
    apply = function(w)
      return (w:gsub("([aeiou])p([aeiou])", "%1f%2"):gsub("([aeiou])t([aeiou])", "%1th%2")
              :gsub("([aeiou])k([aeiou])", "%1h%2"):gsub("([aeiou])b([aeiou])", "%1v%2")
              :gsub("([aeiou])d([aeiou])", "%1z%2"):gsub("([aeiou])g([aeiou])", "%1y%2"))
    end },
  { id = "vowel shift", note = "a becomes e, o becomes u",
    apply = function(w) return (w:gsub("a", "\1"):gsub("o", "u"):gsub("\1", "e")) end },
  { id = "raising", note = "e becomes i",
    apply = function(w) return (w:gsub("e", "i")) end },
  { id = "cluster loss", note = "the second consonant of a cluster falls away",
    apply = function(w) return (w:gsub("^([ptkbdg])[rl]", "%1"):gsub("^s([ptk])", "%1")) end },
  { id = "final loss", note = "final consonants fall silent",
    apply = function(w)
      if #w > 3 then return (w:gsub("[^aeiou']$", "")) end
      return w
    end },
  { id = "palatalisation", note = "k and t before i or e become ch",
    apply = function(w) return (w:gsub("k([ie])", "ch%1"):gsub("t([i])", "ch%1")) end },
  { id = "h-loss", note = "h falls silent at the start of words",
    apply = function(w)
      local r = w:gsub("^h([aeiou])", "%1")
      return r
    end },
}

-- A daughter language: 2 to 5 sound changes applied to every root.
function L.split(lang, seed)
  local rng = mvl.rng(seed)
  local order = {}
  for i = 1, #L.CHANGES do order[i] = i end
  for i = #order, 2, -1 do
    local j = rng:int(1, i)
    order[i], order[j] = order[j], order[i]
  end
  local n = rng:int(2, 5)
  local chosen = {}
  for i = 1, n do chosen[i] = L.CHANGES[order[i]] end
  local lex = {}
  for m, w in pairs(lang.lexicon) do
    local x = w
    for _, c in ipairs(chosen) do x = c.apply(x) end
    if not L.readable(x) or #x < 2 then x = w end
    lex[m] = x
  end
  local changes = {}
  for i, c in ipairs(lang.changes or {}) do changes[i] = c end
  for _, c in ipairs(chosen) do changes[#changes + 1] = c.id end
  return { phonology = lang.phonology, lexicon = lex, seed = seed, parent = lang.seed, changes = changes }
end

-- How many meanings two languages express with the same or a similar root
-- (at most two letters apart): a share between 0 and 1.
function L.kinship(a, b)
  local same, n = 0, 0
  local function close(x, y)
    if x == y then return true end
    if math.abs(#x - #y) > 2 then return false end
    local d, m = 0, math.min(#x, #y)
    for i = 1, m do if x:sub(i, i) ~= y:sub(i, i) then d = d + 1 end end
    return d + math.abs(#x - #y) <= 2
  end
  for _, m in ipairs(L.ORDER) do
    n = n + 1
    if close(a.lexicon[m], b.lexicon[m]) then same = same + 1 end
  end
  return same / n
end

return L
