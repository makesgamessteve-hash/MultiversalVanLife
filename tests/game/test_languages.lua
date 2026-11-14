-- Languages: sounds the speakers can make, readable words and names, names
-- that keep their meaning, and related languages with related names.
local gen = require("gen")
local L = gen.culture.language
gen.planet.LEVEL = 3

-- ------------------------------------------------------ beaked speakers
local LIPS = "[pbmfvw]"
for seed = 1, 200 do
  local mouth = ({ "beak", "mandibles" })[seed % 2 + 1]
  local lang = L.generate(seed * 31, mouth, seed % 3 == 0)
  for _, c in ipairs(lang.phonology.consonants) do
    test.expect(not c:find(LIPS), "no lip sounds for " .. mouth .. " speakers: " .. c)
  end
  for m, w in pairs(lang.lexicon) do test.expect(not w:find(LIPS), "no lip sounds in " .. m .. " = " .. w) end
end
local lipped = 0
for seed = 1, 50 do
  local lang = L.generate(seed, "lips", false)
  for _, c in ipairs(lang.phonology.consonants) do if c:find("^" .. LIPS .. "$") then lipped = lipped + 1 break end end
  for _, c in ipairs(lang.phonology.consonants) do test.expect(not c:find("'"), "lipped speakers do not click") end
end
test.expect(lipped > 40, "speakers with lips mostly use lip sounds: " .. lipped)
local tonal = L.generate(5, "lips", true)
local long = false
for _, v in ipairs(tonal.phonology.vowels) do if #v == 2 then long = true end end
test.expect(long, "musical species have long tonal vowels")

-- ------------------------------------------------------ readability
local names, short = 0, 0
for seed = 1, 200 do
  local lang = L.generate(seed * 7 + 3, ({ "lips", "beak", "mandibles" })[seed % 3 + 1], seed % 4 == 0)
  for m, w in pairs(lang.lexicon) do test.expect(L.readable(w), "readable word " .. w .. " (" .. m .. ")") end
  local rng = mvl.rng(seed)
  for _, kind in ipairs({ "place", "person", "god", "country" }) do
    local n = L.name(lang, rng, kind)
    names = names + 1
    test.expect(L.readable(n.name:lower()), "readable " .. kind .. " name " .. n.name)
    test.expect(n.meaning and #n.meaning > 2, "every name has a meaning")
    if #n.name <= 9 then short = short + 1 end
  end
end
test.expect(short / names > 0.6, "most names are short: " .. short .. " of " .. names)
-- words never look like English insults
for _, w in ipairs({ "loser", "kill", "shitar" }) do test.expect(not L.readable(w), "blocked: " .. w) end

-- ------------------------------------------------------ translated names
local G = gen.run.new(gen.cosmos, { seed = 12, mods = {} })
local land, planet
for s = 0, 300 do
  local saddr = "u" .. (1 + s % 7) .. ".g" .. (s % 11) .. ".c" .. (s % 3) .. ".s" .. (s % 5)
  local ok, sys = pcall(G.generate, G, saddr)
  if ok then
    for i = 0, sys.data.planets - 1 do
      if not land and sys.children[i].kind == "rocky" then
        local p = G:generate(saddr .. ".p" .. i)
        for id, c in ipairs(p.data.countries or {}) do
          if not land and c.culture then
            local country = G:generate(p.address .. ".k" .. (c.continent - 1) .. ".n" .. c.index)
            for l = 0, 255, 5 do
              local gx, gz = gen.land.grid(l)
              if gen.land.raw_height(country.data.terrain, gx * 2048, gz * 2048) > 3 then
                land, planet = G:generate(country.address .. ".l" .. l), p
                break
              end
            end
          end
        end
      end
    end
  end
  if land then break end
end
test.expect(land, "a land of a people")
local d = land.data
test.expect(d.name_meaning and #d.name_meaning > 2, "a place name keeps its meaning: " .. d.name .. " = " .. tostring(d.name_meaning))
local cul = planet.data.cultures[d.culture.id]
local again = gen.culture.land_name(planet.data, G:node(gen.address.parent(land.address)).summary.id, land.seed)
test.eq(again.name, d.name, "the name follows from the land and its language")
local first = cul.language.lexicon[again.roots[1]]:gsub("'$", "")
test.expect(d.name:lower():sub(1, #first) == first, "the name begins with the word for '" .. again.roots[1] .. "'")
test.eq(L.translate(cul.language, cul.language.lexicon[again.roots[1]]), again.roots[1], "words translate back")
for _, p in ipairs(d.people) do
  test.expect(p.name_meaning and p.species == cul.species, "people are named in their language: " .. p.name)
end
local country = G:node(gen.address.parent(land.address))
test.expect(country.summary.meaning, "countries are named in their culture's language")
test.expect(planet.data.life.sapients[1].name_meaning or #planet.data.life.colonists > 0,
            "native peoples call themselves by their own word")

-- ------------------------------------------------------ related names
local proto = L.generate(4242, "lips", false)
local a, b = L.split(proto, 1), L.split(proto, 2)
local stranger = L.generate(999, "lips", false)
test.expect(#a.changes >= 2 and #a.changes <= 5, "a daughter language has 2 to 5 sound changes")
test.expect(L.kinship(a, b) > 0.5, "sister languages share most roots: " .. L.kinship(a, b))
test.expect(L.kinship(a, stranger) < 0.15, "unrelated languages share few: " .. L.kinship(a, stranger))
local same = 0
for k = 1, 20 do
  local fixed = { L.MEANINGS.colour[k % 12 + 1], L.MEANINGS.land[k % 30 + 1] }
  local na = L.name(a, mvl.rng(k), "place", fixed)
  local nb = L.name(b, mvl.rng(k), "place", fixed)
  test.eq(na.meaning, nb.meaning, "the same meaning in both languages")
  local la, lb = na.name:lower(), nb.name:lower()
  if la:sub(1, 1) == lb:sub(1, 1) or la == lb then same = same + 1 end
end
test.expect(same >= 12, "names of the same meaning sound alike in sister languages: " .. same)
-- the sound changes are regular: the same change everywhere
local changed = L.split(L.generate(77, "lips", false), 3)
test.expect(changed.parent == 77 and #changed.changes > 0, "a daughter remembers its parent and its changes")
-- planets: cultures of one species speak sister languages
local sisters
for s = 0, 400 do
  local saddr = "u" .. (1 + s % 7) .. ".g" .. (s % 11) .. ".c" .. (s % 3) .. ".s" .. (s % 5)
  local ok, sys = pcall(G.generate, G, saddr)
  if ok then
    for i = 0, sys.data.planets - 1 do
      local n = sys.children[i].kind == "rocky" and G:generate(saddr .. ".p" .. i)
      if n and n.data.cultures and #n.data.cultures >= 2 and n.data.cultures[1].species == n.data.cultures[2].species then
        sisters = n.data.cultures
      end
    end
  end
  if sisters then break end
end
test.expect(sisters, "a people living on several continents")
test.expect(L.kinship(sisters[1].language, sisters[2].language) > 0.4, "its cultures speak related languages")
