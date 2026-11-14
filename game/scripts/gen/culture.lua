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
local calendar = require("gen.culture.calendar")
local traditions = require("gen.culture.traditions")
local society = require("gen.culture.society")
local technology = require("gen.culture.technology")
local util = require("gen.util")

local C = { language = language, religion = religion, calendar = calendar, traditions = traditions,
            society = society, technology = technology, MONUMENT_LAND = 119 }

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
    rel.fact = ctx:fact("religion", { name = rel.name, form = rel.form, species = s.name }, rel.because)
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
      C.traditions_of(ctx, culture, s, rel, source, laws, rng)
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
    -- the faith's founder, remembered by a statue in a land of the first culture
    local first
    for _, c in ipairs(d.cultures) do if c.religion == rel.id and not first then first = c end end
    if first then
      local home
      for id, c in ipairs(d.countries or {}) do if c.culture == first.id and not home then home = c end end
      local pn = language.name(first.language, mvl.rng(mvl.hash(seed, "founder")), "person")
      local founder = { name = pn.name, meaning = pn.meaning, role = "prophet", species = s.name,
                        anatomy = util.copy(s.anatomy), hue = s.hue or 30,
                        attributes = rel.form == "philosophy" and { "book" } or { "staff", "halo" } }
      rel.founder = founder
      founder.fact = ctx:fact("individual", { name = founder.name, role = "prophet", religion = rel.name,
                                              species = s.name }, { rel.fact })
      if home then
        local target = ctx.node.address .. ".k" .. (home.continent - 1) .. ".n" .. home.index .. ".l" .. C.MONUMENT_LAND
        ctx:commit(target, "monument", { individual = founder }, founder.fact)
        founder.monument = target
      end
    end
    -- real gods: the deities of a widely followed faith
    local followers = 0
    for _, c in ipairs(d.countries or {}) do
      if c.culture and d.cultures[c.culture].religion == rel.id then followers = followers + 1 end
    end
    rel.countries = followers
    if laws.gods == "real" and followers >= 3 then
      for _, deity in ipairs(rel.deities) do
        deity.real = true
        deity.fact = ctx:fact("deity", { name = deity.name, meaning = deity.meaning, real = true, religion = rel.name },
                              { rel.fact })
      end
    end
  end
end

-- Calendar, customs, values, society and technology of a culture.
function C.traditions_of(ctx, culture, s, rel, source, laws, rng)
  local d = ctx.data
  local r = traditions.region(d, culture.continent, ctx.seed)
  local H = require("gen.visuals.sky").heavens(d)
  culture.region = { biome = r.biome, dry = r.dry, mountains = r.mountains, coast = r.coast,
                     soil = r.soil, magic = r.magic }
  culture.calendar = calendar.generate(H, culture.language, rng, 0)
  culture.customs = traditions.customs(rng, d, s, r, rel, source)
  culture.values = society.values(rng, s, r, rel)
  culture.society = society.society(rng, culture.values, s, rel, culture.language, culture.customs)
  -- what the land offers for technology (colonists arrived by starship)
  local herd, draught, crops = false, false, false
  for _, sp in ipairs(r.species) do
    if sp.role == "grazer" and sp.size >= 0.4 then herd = true end
    if sp.role == "grazer" and sp.size >= 1.2 then draught = true end
    if sp.kind == "plant" and (sp.form == "herb" or sp.form == "shrub") then crops = true end
  end
  local eras = s.spacefaring and 12 or rng:int(2, 8)
  local resources = {}
  for k in pairs(r.resources) do resources[k] = true end
  culture.conditions = { crops = crops, herd = herd, draught = draught, coast = r.coast >= 0.1,
                         air = d.atmosphere.pressure, stability = 0.3 + rng:next() * 0.6, eras = eras,
                         magic = laws.magic ~= "none" and r.magic or 0, source = laws.magic ~= "none" and laws.magic or nil,
                         psionics = laws.psionics or 0, mineral = d.magic_mineral, resources = resources,
                         trade = s.spacefaring and { iron = true, copper = true, tin = true, coal = true, oil = true } or nil }
  culture.tech = technology.reachable(culture.conditions)
  if s.spacefaring and not culture.tech.has.spaceflight then
    culture.tech.known[#culture.tech.known + 1] = "spaceflight"
    culture.tech.has.spaceflight, culture.tech.level = true, 10
  end
  -- how they build, dress and look
  culture.anatomy, culture.hue = util.copy(s.anatomy), s.hue or 30
  culture.style = require("gen.culture.architecture").style(rng, s, r, rel, culture.values, culture.tech, r.rock_color,
                                                            d.life.chemistry)
  culture.region.rock = r.rock
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
  out[#out + 1] = "Ways of life:"
  for _, c in ipairs(P.cultures) do
    local cu = c.customs
    local taboo = {}
    for _, tb in ipairs(cu.taboos) do taboo[#taboo + 1] = tb.what .. " (" .. tb.reason .. ")" end
    local food = {}
    for _, f in ipairs(cu.food) do food[#food + 1] = f.text end
    out[#out + 1] = string.format("- **%s**: %s. Funerals: %s. Food: %s. Taboos: %s. Values: %s; %s; strangers are %s; " ..
                                  "laws: %s. Technology: %s (%s)%s.", c.name, calendar.describe(c.calendar),
                                  c.customs.funerals[1].text, #food > 0 and table.concat(food, "; ") or "whatever can be found",
                                  #taboo > 0 and table.concat(taboo, "; ") or "none", society.describe(c.values),
                                  c.society.structure, c.society.strangers, table.concat(c.society.laws, "; "),
                                  technology.AGES[c.tech.level], table.concat(c.tech.known, ", "),
                                  #c.tech.traditions > 0 and ("; " .. table.concat(c.tech.traditions, "; ")) or "")
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
