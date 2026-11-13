-- Multiversal Van Life - provisional names for generated places (MIT).
-- Syllable lexicons give each kind of place its own sound until phase 16
-- generates real languages. Names are deterministic per random stream.
local names = {}

names.LEXICONS = {
  cosmic = { first = { "Ae", "Or", "Va", "Thal", "Ys", "Cor", "Mir", "Esh", "Ul", "Sae", "Ka", "Neb" },
             mid = { "ra", "ven", "lo", "the", "si", "mar", "ki", "do", "ny", "re" },
             last = { "on", "ia", "eth", "ar", "um", "is", "os", "ael", "yr", "ane" } },
  stellar = { first = { "Hel", "Ar", "Bel", "Cas", "Dra", "Fo", "Gar", "Lu", "Pe", "Ri", "Sol", "Ves", "Zan", "Ty" },
              mid = { "a", "o", "e", "i", "u", "an", "or", "el" },
              last = { "x", "ra", "nis", "tor", "ga", "lis", "mon", "ka", "dra", "phe" } },
  world = { first = { "Bra", "Ke", "Lo", "Mo", "Ni", "Pa", "Ro", "Ta", "We", "Hu", "Fe", "Da", "Ge", "Sa" },
            mid = { "ma", "ri", "lan", "do", "ne", "ko", "vi", "su", "", "" },
            last = { "n", "ra", "th", "mo", "ss", "ndor", "lia", "ko", "re", "s" } },
}

local function title(s) return s:sub(1, 1):upper() .. s:sub(2) end

-- A name from a lexicon ("cosmic", "stellar" or "world").
function names.make(rng, lexicon)
  local lex = names.LEXICONS[lexicon or "world"]
  local n = lex.first[rng:int(1, #lex.first)]
  local mids = rng:int(0, 2)
  for _ = 1, mids do n = n .. lex.mid[rng:int(1, #lex.mid)] end
  return title(n .. lex.last[rng:int(1, #lex.last)])
end

local GREEK = { "Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta" }

-- A catalogue-like star name: "Hel 482" or "Gamma Vesra".
function names.star(rng)
  if rng:chance(0.5) then return names.make(rng, "stellar") .. " " .. rng:int(10, 999) end
  return GREEK[rng:int(1, #GREEK)] .. " " .. names.make(rng, "stellar")
end

-- Planets are named after their star: "Vesra b", "Vesra c", ...
function names.planet(star_name, n) return star_name .. " " .. string.char(97 + n) end

return names
