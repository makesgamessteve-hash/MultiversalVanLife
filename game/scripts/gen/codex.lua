-- Multiversal Van Life - what a land can teach the player (MIT).
--
-- A stored land must reveal its lore without its planet, so generation
-- keeps snapshots of the codex entries the land can unlock: the place, its
-- people's species, nation, faith, language and traditions, their saint,
-- the events they remember (as they tell them, and as they happened), the
-- creatures around and the people and events its inscriptions name. Each
-- entry: { id, kind, name, gloss, text, believed, truth, links = { ids },
-- why = { { name, category, id } }, universe }. Ids are fact ids where the
-- generator has a fact, so the same saint or war is one entry everywhere.
local CX = {}

-- The category of a cause, by its fact kind.
CX.CATEGORY = {
  religion = "religious", deity = "religious", omen = "environmental", event = "historical", era = "historical",
  individual = "historical", culture = "historical", faction = "historical", war = "historical",
}

local function ago(year) return math.floor(-year + 0.5) end

-- A cause of fact `id` on planet node `P` as a why item.
local function cause(planet, id)
  local f = planet.facts[id]
  if not f then return nil end
  local name = f.data.name or f.kind
  return { name = name, category = CX.CATEGORY[f.kind] or "historical", id = (f.kind == "religion" or f.kind == "event")
           and id or nil }
end

-- The entries of land data `d` at `addr` (people `cul` on planet node
-- `planet`, country summary `country`). Returns { entries, keys }.
function CX.build(d, addr, cul, planet, country)
  local P = planet.data
  local u = tonumber(addr:match("^u(%d+)"))
  local pa = planet.address
  local E, keys = {}, { events = {}, creatures = {}, inscriptions = {} }
  local function add(e)
    if e.id == nil then error("codex entry without id: " .. tostring(e.kind) .. " " .. tostring(e.name)) end
    e.universe = u
    e.links = e.links or {}
    E[e.id] = e
    return e
  end
  -- the place
  local place = add({ id = addr, kind = "place", name = d.name, gloss = d.name_meaning,
                      text = string.format("%s, %s.", d.name, d.biome and string.format("in the %s of %s, %s, on %s",
                                           d.biome, d.country or "?", d.continent or "?", planet.summary.name) or
                                           ("on " .. planet.summary.name)) })
  keys.place = place.id
  -- the creatures around it (unlocked by observing them)
  for _, h in ipairs(d.habitats or {}) do
    for _, a in ipairs(h.animals) do
      local id = "creature:" .. pa .. "/" .. a.id
      if not E[id] then
        add({ id = id, kind = "creature", name = a.name,
              text = string.format("A %s of the %s of %s.", a.role or "creature", h.biome, planet.summary.name),
              links = { place.id } })
        keys.creatures[a.id] = id
      end
    end
  end
  if not cul then return { entries = E, keys = keys } end
  local rel = P.religions and P.religions[cul.religion]
  local lore = d.lore or {}
  -- the people
  local sp = add({ id = "species:" .. pa .. "/" .. cul.species, kind = "species", name = "the " .. cul.species })
  local a = cul.anatomy or {}
  sp.text = string.format("A people of %s with %d limbs, %d of them hands, and %d eyes%s%s. Here they are the %s.",
                          planet.summary.name, a.limbs or 4, a.hands or 2, a.eyes or 2, a.wings and ", winged" or "",
                          a.tail and ", with a tail" or "", cul.name)
  keys.species = sp.id
  -- the language, with what its words mean
  local lang = add({ id = "language:" .. pa .. "/" .. cul.name, kind = "language", name = "the tongue of the " .. cul.name })
  local words = {}
  if lore.greeting then words[#words + 1] = lore.greeting.word .. " = \"" .. lore.greeting.meaning .. "\"" end
  if d.name_meaning then words[#words + 1] = d.name .. " = \"" .. d.name_meaning .. "\"" end
  if lore.stranger then words[#words + 1] = lore.stranger .. " = \"stranger\"" end
  for _, g in ipairs(rel and rel.deities or {}) do words[#words + 1] = g.name .. " = \"" .. g.meaning .. "\"" end
  lang.text = "The language of the " .. cul.name .. ". Words: " .. table.concat(words, "; ") .. "."
  keys.language = lang.id
  sp.links = { lang.id }
  -- the faith, from what their world showed them
  if rel then
    local gods = {}
    for i, g in ipairs(rel.deities) do gods[i] = g.name .. " (\"" .. g.meaning .. "\", of " .. g.domain .. ")" end
    local faith = add({ id = rel.fact, kind = "religion", name = rel.name,
                        text = string.format("%s: %s. They hold %s dear; %s.", rel.name,
                                             #gods > 0 and ("gods " .. table.concat(gods, ", ")) or rel.form,
                                             table.concat(rel.doctrine.virtues, " and "), rel.doctrine.afterlife),
                        why = {} })
    for _, b in ipairs(rel.because or {}) do
      local c = cause(planet, b)
      if c then faith.why[#faith.why + 1] = c end
    end
    keys.faith = faith.id
    sp.links[#sp.links + 1] = faith.id
    -- its saint: how the faithful tell it, and what Juniper knows
    if rel.founder and lore.saint then
      local f = rel.founder
      local saint = add({ id = f.fact or ("saint:" .. pa .. "/" .. f.name), kind = "individual", name = f.name,
                          gloss = f.meaning,
                          believed = lore.saint_story,
                          truth = string.format("%s was a prophet of the %s who founded %s.", f.name, f.species or cul.species,
                                                rel.name),
                          links = { faith.id }, why = { { name = rel.name, category = "religious", id = faith.id } } })
      saint.text = saint.believed
      keys.saint = saint.id
      faith.links[#faith.links + 1] = saint.id
    end
  end
  -- the nation
  if d.nation then
    local nat = add({ id = "faction:" .. pa .. "/" .. d.nation, kind = "faction", name = d.nation,
                      text = string.format("%s, the nation of the %s, holding %s.", d.nation, cul.name, d.country or "?"),
                      links = { sp.id } })
    keys.nation = nat.id
  end
  -- the events they remember, as they tell them and as they happened
  local h = P.history
  for _, m in ipairs(cul.memory or {}) do
    local ev
    for _, x in ipairs(h and h.events or {}) do if x.fact == m.event then ev = x end end
    if ev and not E[m.event] then
      local truth = string.format("%s, %d years ago.", ev.name:gsub("^%l", string.upper), ago(ev.year))
      if ev.kind == "war" and ev.winner then
        truth = truth .. string.format(" %s struck first; %s won.", h.factions[ev.aggressor].name,
                                       h.factions[ev.winner].name)
      elseif ev.kind == "plague" then
        truth = truth .. " A sickness, as sicknesses come: nobody brought it."
      end
      local e = add({ id = m.event, kind = "event", name = ev.name, believed = m.told:gsub("^%l", string.upper) .. ".",
                      truth = truth, rule = m.rule, links = { sp.id } })
      e.text = e.believed
      keys.events[m.told] = e.id
    end
  end
  -- traditions and why they are as they are
  local tr = add({ id = "traditions:" .. pa .. "/" .. cul.name, kind = "tradition", name = "the ways of the " .. cul.name,
                   why = {}, links = { sp.id } })
  local parts, seen = {}, {}
  local cus = cul.customs or {}
  for _, r in ipairs(cus.rites or {}) do parts[#parts + 1] = r.name .. ": " .. r.text end
  for _, f in ipairs(cus.funerals or {}) do parts[#parts + 1] = "the dead: " .. f.text end
  for _, f in ipairs(cus.food or {}) do parts[#parts + 1] = "food: " .. f.text end
  for _, t in ipairs(cus.taboos or {}) do parts[#parts + 1] = "never " .. t.what .. ", for " .. t.reason end
  local hol = {}
  for _, x in ipairs(cul.calendar and cul.calendar.holidays or {}) do
    if not seen[x.name] then
      seen[x.name] = true
      if #hol < 4 then hol[#hol + 1] = x.name .. " (\"" .. (x.meaning or "") .. "\")" end
    end
  end
  if #hol > 0 then parts[#parts + 1] = "holidays: " .. table.concat(hol, ", ") end
  tr.text = table.concat(parts, ". ") .. "."
  local why_seen = {}
  local function because(ids)
    for _, b in ipairs(type(ids) == "table" and ids or { ids }) do
      if b and not why_seen[b] then
        why_seen[b] = true
        local c = cause(planet, b)
        if c then tr.why[#tr.why + 1] = c end
      end
    end
  end
  for _, f in ipairs(cus.funerals or {}) do because(f.because) end
  for _, f in ipairs(cus.food or {}) do because(f.because) end
  for _, t in ipairs(cus.taboos or {}) do because(t.because) end
  for _, x in ipairs(cul.calendar and cul.calendar.holidays or {}) do if x.because then because(x.because) end end
  keys.traditions = tr.id
  if keys.faith then tr.links[#tr.links + 1] = keys.faith end
  place.links = { sp.id, lang.id, tr.id }
  if keys.faith then place.links[#place.links + 1] = keys.faith end
  if keys.nation then place.links[#place.links + 1] = keys.nation end
  return { entries = E, keys = keys }
end

-- An inscription entry: the person a statue shows, or the event a trace
-- remembers (from the land's features).
function CX.inscription(d, f, addr)
  local u = tonumber(addr:match("^u(%d+)"))
  if f.statue then
    local q = f.statue
    return { id = q.fact or ("statue:" .. addr .. "/" .. tostring(q.name)), kind = "individual", name = q.name,
             text = string.format("%s, %s.", q.name, q.role or "remembered here"), universe = u, links = {} },
           string.format("The inscription reads: \"%s, %s.\"", q.name, q.role or "")
  end
  if f.trace then
    local t = f.trace
    return { id = t.fact or ("trace:" .. addr .. "/" .. tostring(t.name)), kind = "event", name = t.event or t.name,
             text = string.format("%s: %s, %d years ago.", t.name:gsub("^%l", string.upper), t.event or t.name,
                                  ago(t.year or 0)), universe = u, links = { addr } },
           string.format("The stones say: %s. %s, %d years ago.", t.name, t.event or "", ago(t.year or 0))
  end
end

return CX
