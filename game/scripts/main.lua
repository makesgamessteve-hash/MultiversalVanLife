-- Multiversal Van Life - game entry point (MIT License).
-- The C engine calls game.init(), game.update(dt) at a fixed 60 Hz and
-- game.draw_ui() once per rendered frame. Everything gameplay related lives
-- in these scripts and can be changed or extended by mods.
local world = require("lib.world")
local player = require("lib.player")
local dialogue = require("lib.dialogue")
local hud = require("lib.hud")
local audio = require("lib.audio")
local lines = require("lib.lines")
local progress = require("lib.progress")
local story = require("lib.story")
local Menu = require("lib.menu")
local gen = require("gen")

require("worlds.home")
require("worlds.land")

-- Mods: each enabled mod may provide an init.lua (see docs/MODDING.md).
for index, name in ipairs(mvl.mods()) do
  local ok, err = pcall(mvl.run_mod, index)
  if not ok then mvl.log("mod " .. name .. " failed: " .. tostring(err)) end
end

game.state = "title"
local title_menu, pause_menu

local function touch() return mvl.touch() end

local function start_play(new_game)
  if new_game then progress.reset() progress.save() end
  story.reset()
  dialogue.skip_all()
  -- a new session: places and their changes are read back from the save
  require("memory.changes").reset()
  gen.start(progress.seed())
  game.state = "play"
  player.enabled = true
  local loc = progress.location()
  local land = progress.land_address(loc)
  -- saves at a place that no longer exists continue at home
  if not land and not world.get(loc) then loc = "home" progress.set_location("home") end
  story.van.build()
  story.van.inside = false
  player.base_y, player.indoors = 0, false
  if land then world.load("land", nil, { address = land }) else world.load(loc) end
  -- every session begins inside the van unless the van has not been met yet
  if progress.flag("van_met") then story.van.enter(player, world) end
  hud.title_card("Night " .. progress.night(), 2.5)
  story.prefetch_signals()
  if progress.flag("van_met") and loc ~= "home" then
    hud.notify("Juniper is parked at " .. world.place_name())
  end
end

local function build_title()
  local items = {
    { label = "Continue", enabled = progress.has_save(), action = function() start_play(false) end },
    { label = "New journey", action = function() start_play(true) end },
  }
  if mvl.platform() ~= "web" then items[#items + 1] = { label = "Quit", action = function() mvl.quit() end } end
  title_menu = Menu.new("MULTIVERSAL VAN LIFE", items, { subtitle = "a story about an old van and a long night" })
  if not progress.has_save() then title_menu.index = 2 end
end

local function open_pause()
  local items = {
    { label = "Resume", action = function() game.state = "play" end },
    { label = "Touch controls: " .. (touch() and "on" or "off"), action = function()
      mvl.touch(not touch())
      open_pause()
    end },
  }
  local xr_supported, xr_active = mvl.xr()
  if xr_supported and not xr_active then
    items[#items + 1] = { label = "Enter VR", action = function() mvl.xr_request() game.state = "play" end }
  end
  items[#items + 1] = { label = "Save and return to title", action = function()
    progress.save()
    game.state = "title"
    build_title()
    story.van.inside = false
    player.base_y, player.indoors = 0, false
    world.load("home")
    audio.scape("title")
  end }
  pause_menu = Menu.new("PAUSED", items, { cancel = function() game.state = "play" end })
  game.state = "pause"
end

function game.init()
  -- tool mode: mvl_headless --bible ADDRESS --out FILE [--seed N]
  if mvl.option("bible") then return gen.bible.cli(gen.cosmos, gen.run) end
  lines.load()
  -- the title shows the save's own farm (places are stored on first sight)
  gen.start(progress.has_save() and progress.seed() or 1)
  story.van.build()
  build_title()
  world.load("home")
  audio.scape("title")
end

function game.update(dt)
  if not title_menu then return end -- tool mode
  hud.update(dt)
  if game.state == "title" then
    player.enabled = false
    player.yaw = player.yaw + dt * 0.05
    player.update(dt)
    title_menu:update()
    return
  end
  if game.state == "pause" then
    pause_menu:update()
    return
  end
  -- play
  if mvl.pressed("menu") and not story.menu and not dialogue.active() and not story.busy then
    open_pause()
    return
  end
  gen.update()
  local talking = dialogue.update(dt)
  local blocked = talking or story.busy or story.menu ~= nil
  player.enabled = not blocked
  player.update(dt)
  if story.menu and not talking then story.menu:update() end
  world.update(dt, not blocked)
  story.update(dt)
  hud.set_prompt((not blocked and world.focus) and world.focus.prompt or nil)
end

function game.draw_ui()
  if not title_menu then return end -- tool mode
  local t = touch()
  if game.state == "title" then
    title_menu:draw()
    local w, h = mvl.ui_size()
    local hint = t and "Tap USE to choose" or "W/S choose - E select"
    mvl.text((w - mvl.text_width(hint)) / 2, h - 16, hint, 1, 0.6, 0.6, 0.7, 1)
    hud.draw(t)
    return
  end
  hud.draw(t)
  if story.menu then story.menu:draw() end
  dialogue.draw(t)
  if game.state == "pause" then pause_menu:draw() end
end

-- Hooks used by automated game tests and the debug console.
game.debug = {
  world = world, player = player, dialogue = dialogue, story = story, progress = progress, hud = hud,
  van = story.van, gen = gen,
  start = start_play,
  open_pause = open_pause,
  title_menu = function() return title_menu end,
  pause_menu = function() return pause_menu end,
}
