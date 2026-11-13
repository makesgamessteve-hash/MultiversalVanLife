-- Multiversal Van Life - persistent story progress stored in the save file
-- through mvl.save_get / mvl.save_set (MIT License).
local progress = {}

function progress.has_save() return mvl.save_get("story.started") == "1" end

-- A fresh multiverse seed (the save's root seed; every place derives from it).
function progress.new_seed()
  return mvl.hash(os.time(), math.floor(os.clock() * 1e6), mvl.ticks()) % 2147483647
end

function progress.reset(seed)
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

function progress.helped(world) return progress.flag("helped." .. world) end
function progress.set_helped(world) progress.set_flag("helped." .. world) end

function progress.helped_count(worlds)
  local n = 0
  for _, w in ipairs(worlds) do if progress.helped(w.id) then n = n + 1 end end
  return n
end

function progress.end_night()
  mvl.save_set("story.night", progress.night() + 1)
  progress.save()
end

function progress.save() return mvl.save_write() end

return progress
