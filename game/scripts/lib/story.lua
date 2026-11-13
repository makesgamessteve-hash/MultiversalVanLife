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
world.fixed = van.fixed

-- Runs fn after `seconds` of game time.
function story.after(seconds, fn) story.tasks[#story.tasks + 1] = { t = seconds, fn = fn } end

function story.update(dt)
  van.update(dt)
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
  story.busy, story.menu, story.tasks, story.shake = false, nil, {}, 0
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
  local model = w:prop({ voxel = "van", x = x, z = z, yaw = yaw, box = { 5.0, 2.3 } })
  local c, s = math.cos(yaw), math.sin(yaw)
  local dx, dz = x + c * -2.9, z - s * -2.9
  w:prop({ model = "cube", x = x + c * 1.6, y = 2.45, z = z - s * 1.6, scale = { 0.25, 0.15, 0.25 },
           color = { 1, 0.7, 0.2, 1 }, unlit = true })
  w:light(7, x + c * 1.6, 3.0, z - s * 1.6, 1.0, 0.6, 0.2, 7)
  w:interactable({ x = dx, z = dz, range = 2.0, prompt = "Enter the van", use = function() story.enter_van() end })
  story.van_door = { x = x + c * -3.6, z = z - s * -3.6, yaw = math.atan(c, -s) }
  van.set_exterior(x, z, yaw)
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

local function all_helped()
  local list = world.destinations()
  return #list > 0 and progress.helped_count(list) == #list
end
story.all_helped = all_helped

function story.open_console()
  local loc = progress.location()
  local items = {}
  for _, def in ipairs(world.destinations()) do
    local label = def.name .. (progress.helped(def.id) and "  (helped)" or "")
    items[#items + 1] = { label = label, enabled = def.id ~= loc, action = function() story.travel(def.id) end }
  end
  if loc ~= "home" then
    items[#items + 1] = { label = "Home - end the night", action = function() story.travel("home") end }
  end
  items[#items + 1] = { label = "Not yet", action = function() story.menu = nil end }
  story.menu = Menu.new("CONSOLE", items, {
    subtitle = "Night " .. progress.night() .. " - " .. (world.get(loc) and world.get(loc).name or loc),
    cancel = function() story.menu = nil end,
  })
  dialogue.say("van_console")
end

function story.travel(to)
  story.menu = nil
  story.busy = true
  dialogue.skip_all()
  dialogue.say("van_travel")
  audio.sfx("travel", 0.9)
  story.shake = 3.5
  van.set_travelling(true)
  -- the outside is replaced while the player stays inside, looking at the vortex
  story.after(1.0, function() world.load(to) end)
  story.after(3.6, function()
    van.set_travelling(false)
    progress.set_location(to)
    if to == "home" then
      progress.end_night()
      hud.title_card("Night " .. (progress.night() - 1) .. " complete", 3)
      dialogue.say(all_helped() and { "van_home", "van_all_done" } or "van_home")
    else
      progress.save()
      dialogue.say(progress.helped(to) and "van_welcome_back" or "van_arrive")
    end
    story.busy = false
  end)
end

return story
