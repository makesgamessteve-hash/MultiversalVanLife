-- Multiversal Van Life - persistent story progress stored in the save file
-- through mvl.save_get / mvl.save_set (MIT License).
local progress = {}

function progress.has_save() return mvl.save_get("story.started") == "1" end

function progress.reset()
  mvl.save_clear()
  mvl.save_set("story.started", "1")
  mvl.save_set("story.night", 1)
  mvl.save_set("story.location", "home")
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
