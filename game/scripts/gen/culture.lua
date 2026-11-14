-- Multiversal Van Life - cultures of intelligent species (MIT).
--
-- On a world with intelligent species (native, committed or colonists),
-- each species has a proto-language and a religion of its own; its peoples
-- live on up to three continents (colonists in one country), each a culture
-- speaking a daughter language of the proto-language, so their names are
-- related. Countries belong to the culture of their region; places, people
-- and gods are named in its language with their meanings. History (phase
-- 19) will split cultures further and found new religions.
local language = require("gen.culture.language")
local religion = require("gen.culture.religion")
local util = require("gen.util")

local C = { language = language, religion = religion }

local function title(s) return s:sub(1, 1):upper() .. s:sub(2) end

-- The cultures pass of a planet.
local function cultures(ctx)
  local d = ctx.data
  local life = d.life
  if not life or not life.sapients then return end
  local peoples = {}
  for _, s in ipairs(life.sapients) do peoples[#peoples + 1] = s end
  for _, s in ipairs(life.colonists or {}) do peoples[#peoples + 1] = s end
  if #peoples == 0 then return end
  local laws = ctx:ancestor("universe").data.laws
  local rng = ctx:random("cultures")
  d.cultures, d.religions = {}, {}
  -- the sources of religious motifs are facts of the planet
  local sources = {}
  local function source(text)
    if not sources[text] then sources[text] = ctx:fact("omen", { name = text }) end
    return sources[text]
  end
  -- continents, largest first; peoples take them in turn
  local conts = {}
  for k = 0, (d.continents or 0) - 1 do
    local s = ctx.node.children[k]
    conts[#conts + 1] = { index = k, cells = s and s.cells or 0 }
  end
  table.sort(conts, function(a, b) return a.cells > b.cells or (a.cells == b.cells and a.index < b.index) end)
  local taken, next_cont = {}, 1
  local country_taken = {}
  for pi, s in ipairs(peoples) do
    -- spacefarers speak the same proto-language on every world
    local key = s.origin == "native" and (ctx.node.address .. "/" .. pi) or tostring(s.name)
    local seed = mvl.hash(ctx.G.seed, key, "language")
    local tonal = s.senses and (s.senses[1] == "hearing" or s.senses[1] == "echo")
    local proto = language.generate(seed, s.anatomy.mouth or "lips", tonal)
    if s.origin == "native" then
      local w = language.word(proto, "people")
      s.endonym, s.exonym = title(w), s.name
      s.name, s.name_meaning = title(w), "the People"
    end
    local rel = religion.generate(rng, d, s, laws, proto, source)
    rel.id = #d.religions + 1
    rel.species = s.name
    d.religions[rel.id] = rel
    -- regions: up to three continents, or one country for colonists
    local regions = {}
    if s.origin == "colony" then
      local c = conts[1]
      if c then regions[1] = { continent = c.index, colony = true } end
    else
      local want = s.origin == "committed" and 2 or rng:int(1, 3)
      for _ = 1, want do
        while conts[next_cont] and taken[conts[next_cont].index] do next_cont = next_cont + 1 end
        local c = conts[next_cont]
        if not c then break end
        taken[c.index] = true
        regions[#regions + 1] = { continent = c.index }
      end
      if #regions == 0 and conts[1] then regions[1] = { continent = conts[1].index, shared = true } end
    end
    for ri, reg in ipairs(regions) do
      local lang = language.split(proto, mvl.hash(seed, "culture", ri))
      local cid = #d.cultures + 1
      local cname = language.name(lang, mvl.rng(mvl.hash(seed, "name", ri)), "country")
      local culture = {
        id = cid, name = cname.name, meaning = cname.meaning, species = s.name, species_fact = s.fact,
        origin = s.origin, continent = reg.continent, religion = rel.id, language = lang, mouth = s.anatomy.mouth,
      }
      culture.fact = ctx:fact("culture", { name = culture.name, meaning = culture.meaning, species = s.name,
                                           continent = reg.continent, religion = rel.name }, s.fact and { s.fact } or nil)
      d.cultures[cid] = culture
      -- its countries
      for id, c in ipairs(d.countries or {}) do
        if c.continent == reg.continent + 1 and not country_taken[id] then
          if reg.colony then
            if not culture.claimed then
              c.culture, country_taken[id], culture.claimed = cid, true, true
            end
          elseif not c.culture then
            c.culture = cid
          end
        end
      end
    end
    -- real gods: the deities of a widely followed faith
    local followers = 0
    for _, c in ipairs(d.countries or {}) do
      if c.culture and d.cultures[c.culture].religion == rel.id then followers = followers + 1 end
    end
    rel.countries = followers
    rel.fact = ctx:fact("religion", { name = rel.name, form = rel.form, species = s.name }, rel.because)
    if laws.gods == "real" and followers >= 3 then
      for _, deity in ipairs(rel.deities) do
        deity.real = true
        deity.fact = ctx:fact("deity", { name = deity.name, meaning = deity.meaning, real = true, religion = rel.name },
                              { rel.fact })
      end
    end
  end
end

-- The culture of a country (by its id on the planet), or nil.
function C.of_country(P, country_id)
  local c = P.countries and P.countries[country_id]
  return c and c.culture and P.cultures[c.culture] or nil
end

-- A land's name in its country's language: {name, meaning} or nil.
function C.land_name(P, country_id, land_seed)
  local cul = C.of_country(P, country_id)
  if not cul then return nil end
  return language.name(cul.language, mvl.rng(mvl.hash(land_seed, "settlement")), "place")
end

-- A person's name: {name, meaning}.
function C.person_name(cul, seed) return language.name(cul.language, mvl.rng(seed), "person") end

-- A paragraph for the world bible.
function C.describe(P)
  if not P.cultures then return nil end
  local out = { "Peoples:" }
  for _, c in ipairs(P.cultures) do
    local lang = c.language
    local words = {}
    for _, m in ipairs({ "sun", "moon", "water", "people", "god", "home" }) do
      words[#words + 1] = m .. " = " .. lang.lexicon[m]
    end
    out[#out + 1] = string.format("- **%s** (\"%s\"), %s of continent %d, speak a %s language (sounds: %s%s; " ..
                                  "changes: %s); %s.", c.name, c.meaning, c.species, c.continent,
                                  c.mouth == "lips" and "lipped" or (c.mouth .. "-spoken"),
                                  table.concat(lang.phonology.consonants, " "),
                                  lang.phonology.tonal and ", long tones" or "", table.concat(lang.changes, ", "),
                                  table.concat(words, ", "))
  end
  out[#out + 1] = ""
  out[#out + 1] = "Religions:"
  for _, r in ipairs(P.religions) do out[#out + 1] = "- " .. religion.describe(r) end
  return table.concat(out, "\n")
end

function C.register(R)
  R:pass("planet", "cultures", { after = { "sapients", "subdivision", "sky" }, run = function(ctx)
    if ctx.summary.prime then return end
    cultures(ctx)
  end })
  R:check("cultures", function(node, report)
    if node.kind ~= "planet" or not node.data.cultures then return end
    for _, c in ipairs(node.data.cultures) do
      for m, w in pairs(c.language.lexicon) do
        if not language.readable(w) then report(node.address .. ": unreadable word " .. w .. " for " .. m) return end
      end
      if not node.data.religions[c.religion] then report(node.address .. ": " .. c.name .. " has no religion") end
    end
    for _, r in ipairs(node.data.religions) do
      for _, m in ipairs(r.motifs) do
        if not node.facts[m.because] then report(node.address .. ": motif " .. m.id .. " has no cause") end
      end
    end
  end)
end

C.util = util
return C
