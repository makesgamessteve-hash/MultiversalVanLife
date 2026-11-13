-- Multiversal Van Life - persistent story progress stored in the save file
-- through mvl.save_get / mvl.save_set (MIT License).
local progress = {}

function progress.has_save() return mvl.save_get("story.started") == "1" end

-- A fresh multiverse seed (the save's root seed; every place derives from it).
function progress.new_seed()
  return mvl.hash(os.time(), math.floor(os.clock() * 1e6), mvl.ticks()) % 2147483647
end

function progress.reset(seed)
  require("memory.changes").discard()
  mvl.save_clear()
  mvl.save_set("story.started", "1")
  mvl.save_set("story.seed", seed or progress.new_seed())
  mvl.save_set("story.night", 1)
  mvl.save_set("story.location", "home")
end

-- The save's multiverse seed (saves from before seeds get one now).
function progress.seed()
  local s = tonumber(mvl.save_get("story.seed", ""))
  if not s then
    s = progress.new_seed()
    mvl.save_set("story.seed", s)
  end
  return math.floor(s)
end

function progress.night() return tonumber(mvl.save_get("story.night", "1")) or 1 end
function progress.location() return mvl.save_get("story.location", "home") end
function progress.set_location(id) mvl.save_set("story.location", id) end

function progress.flag(name) return mvl.save_get("flag." .. name) == "1" end
function progress.set_flag(name, on) mvl.save_set("flag." .. name, on == false and nil or "1") end

-- Helped places: world ids or land addresses.
function progress.helped(id) return progress.flag("helped." .. id) end
function progress.set_helped(id)
  if not progress.helped(id) then mvl.save_set("story.helped_count", progress.helped_total() + 1) end
  progress.set_flag("helped." .. id)
end
function progress.helped_total() return tonumber(mvl.save_get("story.helped_count", "0")) or 0 end

-- Locations are world ids ("home") or generated lands ("land:<address>").
function progress.land_address(loc)
  loc = loc or progress.location()
  return loc:match("^land:(.+)$")
end

-- The logbook: every visited land (a save record).
function progress.logbook()
  local r = mvl.record_read("logbook")
  return r and r.entries or {}
end

function progress.log_visit(entry)
  local entries = progress.logbook()
  for _, e in ipairs(entries) do if e.address == entry.address then return false end end
  entries[#entries + 1] = entry
  mvl.record_write("logbook", { entries = entries })
  return true
end

-- Troubles offered on recent nights (for signal variety).
function progress.recent_troubles()
  local out = {}
  for id in (mvl.save_get("signals.recent", "") .. ","):gmatch("([^,]*),") do if id ~= "" then out[id] = true end end
  return out
end

function progress.remember_troubles(list)
  local ids = {}
  for _, s in ipairs(list) do ids[#ids + 1] = s.trouble end
  mvl.save_set("signals.recent", table.concat(ids, ","))
end

function progress.helped_count(worlds)
  local n = 0
  for _, w in ipairs(worlds) do if progress.helped(w.id) then n = n + 1 end end
  return n
end

function progress.end_night()
  mvl.save_set("story.night", progress.night() + 1)
  progress.save()
end

-- Saves the index and every place's unsaved changes.
function progress.save()
  require("memory.changes").flush_all()
  return mvl.save_write()
end

return progress
