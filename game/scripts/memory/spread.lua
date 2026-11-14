-- Multiversal Van Life - deeds become stories and travel (MIT).
--
-- A deed (how a quest ended) becomes an event of the land's history and a
-- story with a fame: great deeds (severe troubles, settled disputes) are
-- told far away. Lands of the same country hear of a deed at once, the
-- rest of the planet after two nights if its fame is 0.5 or more, the rest
-- of the galaxy after four if 0.8 or more. Each people tells it its own
-- way: its own folk glorify the player, those who were wronged villainise
-- them, other peoples turn them into a legend. A land whose people have no
-- memory of their own of the player calls them by the title of the most
-- famous story they heard. Deeds also change the nations' opinion of the
-- player (reputation).
--
-- Follow-ups (needs and invitations a land's aftermath brings) wait in a
-- queue until their night; the signals keep one slot for them.
local characters = require("memory.characters")

local SP = {}

SP.REACH = {
  { level = "country", delay = 0, fame = 0 },
  { level = "planet", delay = 2, fame = 0.5 },
  { level = "galaxy", delay = 4, fame = 0.8 },
}

local function record(name, default)
  local r = mvl.record_read(name)
  return r or default
end

-- ------------------------------------------------------------------ deeds
function SP.deeds() return record("deeds", { list = {} }).list end

-- Remembers deed `deed` = { address, kind, result, title, text, place,
-- culture, nation, wronged, favoured, severity, night }.
function SP.record(deed)
  local r = record("deeds", { list = {} })
  local fame = deed.result == "abandoned" and 0.2 or
               math.min(1, 0.3 + (deed.severity or 0.5) * 0.6 + (deed.kind == "mediate" and 0.15 or 0))
  deed.fame = math.floor(fame * 1000 + 0.5) / 1000
  deed.country = deed.address:match("^(.*)%.l%d+$")
  deed.planet = deed.address:match("^(.-%.p%d+)")
  deed.galaxy = deed.address:match("^(u%d+%.g%d+)")
  r.list[#r.list + 1] = deed
  mvl.record_write("deeds", r)
  if deed.nation then characters.add_reputation(deed.nation, deed.result == "abandoned" and -1 or 1) end
  return deed
end

-- How far apart two places are, by the levels of the hierarchy.
local function reach(deed, addr)
  if addr == deed.address then return nil end
  if addr:sub(1, #deed.country + 1) == deed.country .. "." then return SP.REACH[1] end
  if addr:sub(1, #deed.planet + 1) == deed.planet .. "." then return SP.REACH[2] end
  if addr:sub(1, #deed.galaxy + 1) == deed.galaxy .. "." then return SP.REACH[3] end
end

-- How a people tells a deed: { told, rule, title, fame, deed }.
local function tell(deed, culture, nation)
  local where = deed.place or "a far place"
  if deed.result == "abandoned" then
    return "a stranger in a cream-and-teal wagon who promised to help " .. where .. " and then gave up", "villainise"
  end
  if nation and deed.wronged and deed.wronged:find(nation, 1, true) then
    return "a meddler in a cream-and-teal wagon who " .. (deed.wrong or "took the other side") .. " in " .. where,
           "villainise"
  end
  if culture and deed.culture == culture then
    return deed.title .. ", who " .. deed.text .. " in " .. where .. " with nothing but kindness", "glorify"
  end
  return "a giant who came out of the sky in a cream-and-teal wagon and " .. deed.text .. " in " .. where, "legend"
end

-- The stories land `addr` (people `culture`, nation `nation`) has heard by
-- night `night`, most famous first.
function SP.heard(addr, culture, nation, night)
  local out = {}
  for _, deed in ipairs(SP.deeds()) do
    local r = reach(deed, addr)
    if r and deed.fame >= r.fame and night - deed.night >= r.delay then
      local told, rule = tell(deed, culture, nation)
      out[#out + 1] = { told = told, rule = rule, title = deed.title, fame = deed.fame, deed = deed, level = r.level }
    end
  end
  table.sort(out, function(a, b) return a.fame > b.fame or (a.fame == b.fame and a.deed.night > b.deed.night) end)
  return out
end

-- -------------------------------------------------------------- follow-ups
function SP.followups() return record("followups", { list = {} }).list end

-- Queues follow-up `f` = { address, kind, text, short, night, name } of
-- land `node` (once per land and rule).
function SP.queue(node, f)
  local r = record("followups", { list = {} })
  for _, g in ipairs(r.list) do if g.address == f.address and g.rule == f.rule then return g end end
  local places = require("memory.places")
  local planet, galaxy = places.ancestor(node, "planet"), places.ancestor(node, "galaxy")
  f.planet = planet and planet.name or "?"
  f.galaxy = f.address:match("^(u%d+%.g%d+)")
  f.galaxy_name = galaxy and galaxy.name or "?"
  f.universe = tonumber(f.address:match("^u(%d+)"))
  r.list[#r.list + 1] = f
  mvl.record_write("followups", r)
  return f
end

-- Follow-ups due by night `night` and not answered, earliest first.
function SP.due(night)
  local out = {}
  for _, f in ipairs(SP.followups()) do if not f.done and f.night <= night then out[#out + 1] = f end end
  table.sort(out, function(a, b) return a.night < b.night or (a.night == b.night and a.address < b.address) end)
  return out
end

-- Marks the follow-ups of land `addr` of `kind` (or all) as answered.
function SP.answer(addr, kind, night)
  local r = record("followups", { list = {} })
  local n = 0
  for _, f in ipairs(r.list) do
    if f.address == addr and not f.done and (not kind or f.kind == kind) and (not night or f.night <= night) then
      f.done = true
      n = n + 1
    end
  end
  if n > 0 then mvl.record_write("followups", r) end
  return n
end

return SP
