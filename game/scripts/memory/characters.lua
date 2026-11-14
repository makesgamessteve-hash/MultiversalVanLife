-- Multiversal Van Life - people remember the player (MIT).
--
-- Each land's change log keeps what its people remember: per character
-- whether they met the player, how many times they talked, their favour
-- (-3 to +3), the good deed they thank the player for and the wrong they
-- hold against them; and for the whole community the name they know the
-- player by (a title from their deed), the deed itself and the community's
-- favour. Across the multiverse, parties of a dispute (nations, villages,
-- families) keep a reputation of the player (record "reputation").
local C = {}

-- How a community calls the player after their deed (by quest kind).
C.TITLES = {
  relight = "the Lamplighter", gather = "the Finder", ["return"] = "the Keeper", lost = "the Pathfinder",
  message = "the Messenger", mediate = "the Peacemaker", escort = "the Guide", restore = "the Mender",
}

local function clamp(v) return math.max(-3, math.min(3, v)) end

-- The memory record of character `id` in land log `log`.
function C.get(log, id)
  log.characters = log.characters or {}
  local rec = log.characters[id]
  if not rec then
    rec = { met = false, talks = 0, favour = 0 }
    log.characters[id] = rec
  end
  return rec
end

-- The player talks with them (returns how many talks before this one).
function C.meet(log, id)
  local rec = C.get(log, id)
  local n = rec.talks
  rec.met, rec.talks = true, rec.talks + 1
  log.dirty = true
  return n
end

-- They are grateful for `deed` (words after "you": "lit our lamps").
function C.thank(log, id, deed, favour)
  local rec = C.get(log, id)
  rec.deed, rec.favour = deed, clamp(rec.favour + (favour or 1))
  log.dirty = true
end

-- They resent the player for `wrong` ("took their side").
function C.resent(log, id, wrong, favour)
  local rec = C.get(log, id)
  rec.wrong, rec.favour = wrong, clamp(rec.favour - (favour or 1))
  log.dirty = true
end

-- The whole community remembers a deed and calls the player by a title.
function C.community(log, fields)
  log.community = log.community or { favour = 0 }
  for k, v in pairs(fields) do
    if k == "favour" then log.community.favour = clamp(log.community.favour + v) else log.community[k] = v end
  end
  log.dirty = true
end

-- What character `id` remembers, as the dialogue grammar wants it.
function C.memory(log, id)
  local rec = C.get(log, id)
  local com = log.community or {}
  return { met = rec.met, talks = rec.talks, favour = clamp(rec.favour + (com.favour or 0)),
           deed = rec.deed or com.deed, wrong = rec.wrong, known_as = com.known_as or "traveller",
           letdown = com.letdown }
end

-- ------------------------------------------------------------ reputation
function C.reputation(name)
  local r = mvl.record_read("reputation")
  return r and r.parties and r.parties[name] or 0
end

function C.add_reputation(name, delta)
  local r = mvl.record_read("reputation") or {}
  r.parties = r.parties or {}
  r.parties[name] = clamp((r.parties[name] or 0) + delta)
  mvl.record_write("reputation", r)
  return r.parties[name]
end

return C
