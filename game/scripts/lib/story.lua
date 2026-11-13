-- Multiversal Van Life - the van, the console and travelling between worlds
-- (MIT License).
local world = require("lib.world")
local player = require("lib.player")
local dialogue = require("lib.dialogue")
local hud = require("lib.hud")
local audio = require("lib.audio")
local progress = require("lib.progress")
local Menu = require("lib.menu")
local van = require("lib.van")

local story = { busy = false, menu = nil, tasks = {}, shake = 0, van = van }

world.inside = function() return van.inside end
world.anchor = function() return van.exterior end
world.fixed = van.fixed

-- Runs fn after `seconds` of game time.
function story.after(seconds, fn) story.tasks[#story.tasks + 1] = { t = seconds, fn = fn } end

function story.update(dt)
  van.update(dt)
  story.update_trip(dt)
  local due = {}
  for i = #story.tasks, 1, -1 do
    local task = story.tasks[i]
    task.t = task.t - dt
    if task.t <= 0 then
      table.remove(story.tasks, i)
      due[#due + 1] = task.fn
    end
  end
  for i = #due, 1, -1 do due[i]() end
  if story.shake > 0 then
    story.shake = math.max(0, story.shake - dt)
    -- deterministic jitter (game time), so replays and tests look the same
    local s, t = story.shake * 0.02, mvl.time()
    local x, y, z, yaw, pitch = mvl.camera()
    mvl.camera(x + math.sin(t * 53.1) * s, y + math.sin(t * 61.7 + 1.3) * s, z, yaw, pitch + math.sin(t * 47.3 + 2.1) * s)
  end
end

function story.reset()
  story.busy, story.menu, story.tasks, story.shake, story.trip = false, nil, {}, 0, nil
end

-- Fades out, runs `fn` (usually loading a world) and fades back in.
function story.transition(fn, done)
  story.busy = true
  hud.fade_to(1, 3)
  story.after(0.4, function()
    fn()
    hud.fade_to(0, 2)
    story.after(0.3, function()
      story.busy = false
      if done then done() end
    end)
  end)
end

-- Spawns the van exterior at (x, z) facing `yaw` (front = local +X) with a
-- rear door that leads inside, and points the interior windows at it.
function story.place_van(w, x, z, yaw)
  local y = w:height(x, z)
  local model = w:prop({ voxel = "van", x = x, y = y, z = z, yaw = yaw, box = { 5.0, 2.3 } })
  local c, s = math.cos(yaw), math.sin(yaw)
  local dx, dz = x + c * -2.9, z - s * -2.9
  w:prop({ model = "cube", x = x + c * 1.6, y = y + 2.45, z = z - s * 1.6, scale = { 0.25, 0.15, 0.25 },
           color = { 1, 0.7, 0.2, 1 }, unlit = true })
  w:light(7, x + c * 1.6, y + 3.0, z - s * 1.6, 1.0, 0.6, 0.2, 7)
  w:interactable({ x = dx, z = dz, range = 2.0, prompt = "Enter the van", use = function() story.enter_van() end })
  story.van_door = { x = x + c * -3.6, z = z - s * -3.6, yaw = math.atan(c, -s) }
  van.set_exterior(x, z, yaw, y)
  return model
end

-- Entering and leaving are instant: the interior is part of the scene.
function story.enter_van()
  audio.sfx("door", 0.8)
  local first = not progress.flag("van_met")
  van.enter(player, world)
  if first then
    progress.set_flag("van_met")
    progress.save()
    dialogue.say({ "van_intro_1", "van_intro_2", "van_intro_3", "van_intro_4", "van_intro_5", "van_intro_6" })
  end
end

function story.exit_van()
  audio.sfx("door", 0.8)
  local d = story.van_door or (world.current and world.current.spawn) or { x = 0, z = 0, yaw = 0 }
  van.exit(player, world, d.x, d.z, d.yaw)
end

van.on_console = function() story.open_console() end
van.on_door = function() story.exit_van() end

-- ------------------------------------------------------------- console
local function gen() return require("gen") end

-- Tonight's signals (the same all night).
function story.signals()
  local G = gen().world
  local key = G.seed .. ":" .. progress.night()
  if story.signal_cache and story.signal_cache.key == key then return story.signal_cache.list end
  local visited = {}
  for _, e in ipairs(progress.logbook()) do visited[e.galaxy] = true end
  local list = gen().signals.tonight(G, progress.night(), visited, progress.recent_troubles())
  story.signal_cache = { key = key, list = list }
  return list
end

-- "Night 3 - Pandor, Vesra b" / "Night 3 - Home"
local function location_label()
  local addr = progress.land_address()
  if addr then
    for _, e in ipairs(progress.logbook()) do if e.address == addr then return e.name .. ", " .. e.planet end end
    return world.place_name()
  end
  local def = world.get(progress.location())
  return def and def.name or progress.location()
end

function story.open_logbook()
  local here = progress.land_address()
  local items = {}
  for _, e in ipairs(progress.logbook()) do
    local label = e.name .. " (" .. e.planet .. ")" .. (progress.helped(e.address) and "  - helped" or "")
    items[#items + 1] = { label = label, enabled = e.address ~= here, action = function() story.travel(e.address) end }
  end
  items[#items + 1] = { label = "Back", action = function() story.open_console(true) end }
  story.menu = Menu.new("LOGBOOK", items, { subtitle = #items - 1 .. " places visited",
                                            cancel = function() story.open_console(true) end })
end

function story.open_console(quiet)
  local here = progress.land_address()
  local items = {}
  local signals = story.signals()
  for _, s in ipairs(signals) do
    local label = "Signal: " .. s.name .. " - " .. s.short .. (progress.helped(s.address) and "  (helped)" or "")
    items[#items + 1] = { label = label, enabled = s.address ~= here, action = function() story.travel(s.address) end }
  end
  items[#items + 1] = { label = "Logbook", enabled = #progress.logbook() > 0, action = function() story.open_logbook() end }
  if progress.location() ~= "home" then
    items[#items + 1] = { label = "Home - end the night", action = function() story.travel("home") end }
  end
  items[#items + 1] = { label = "Not yet", action = function() story.menu = nil end }
  story.menu = Menu.new("CONSOLE", items, {
    subtitle = "Night " .. progress.night() .. " - " .. location_label(),
    cancel = function() story.menu = nil end,
  })
  if quiet then return end
  local lines = { "van_console" }
  for _, s in ipairs(signals) do
    lines[#lines + 1] = { speaker = "juniper", text = gen().signals.describe(s) }
  end
  dialogue.say(lines)
end

-- ------------------------------------------------------------- travel
-- Travels to "home" or to a land address. The destination is generated
-- while the van is in the vortex; the trip lasts at least 3.5 seconds and
-- until the destination is ready.
function story.travel(to)
  story.menu = nil
  story.busy = true
  dialogue.skip_all()
  dialogue.say("van_travel")
  audio.sfx("travel", 0.9)
  story.shake = 3.5
  van.set_travelling(true)
  local G = gen().world
  local trip = { to = to, t = 0 }
  if to ~= "home" then
    -- a place visited before is loaded, not generated again
    require("memory.places").load(G, to)
    trip.job = G:request(to)
    trip.budget, G.budget = G.budget, 0.02 -- generate faster while nobody looks outside
  end
  story.trip = trip
end

local function arrive(trip)
  local G = gen().world
  if trip.budget then G.budget = trip.budget end
  van.set_travelling(false)
  story.trip = nil
  if trip.failed then
    dialogue.say("van_lost_signal")
    story.busy = false
    return
  end
  if trip.to == "home" then
    progress.set_location("home")
    progress.end_night()
    hud.title_card("Night " .. (progress.night() - 1) .. " complete", 3)
    local total, reached = progress.helped_total(), tonumber(mvl.save_get("story.milestones", "0")) or 0
    if total >= (reached + 1) * 3 then
      mvl.save_set("story.milestones", math.floor(total / 3))
      progress.save()
      dialogue.say({ "van_home", "van_milestone" })
    else
      dialogue.say("van_home")
    end
  else
    local node = G:node(trip.to)
    local planet = require("memory.places").ancestor(node, "planet")
    progress.set_location("land:" .. trip.to)
    local first = progress.log_visit({ address = trip.to, name = node.data.name, planet = planet and planet.name or "?",
                                       galaxy = trip.to:match("^(u%d+%.g%d+)"), night = progress.night() })
    progress.remember_troubles(story.signals())
    progress.save()
    dialogue.say(first and "van_arrive" or "van_welcome_back")
  end
  story.busy = false
end

function story.update_trip(dt)
  local trip = story.trip
  if not trip then return end
  trip.t = trip.t + dt
  -- the outside is replaced while the player stays inside, looking at the vortex
  if not trip.loaded and trip.t >= 1.0 and (not trip.job or trip.job.done) then
    trip.loaded = true
    if trip.job and trip.job.error then
      trip.failed = true
    elseif trip.to == "home" then
      world.load("home")
    else
      world.load("land", nil, { address = trip.to })
    end
  end
  if trip.loaded and trip.t >= 3.6 then arrive(trip) end
end

return story
