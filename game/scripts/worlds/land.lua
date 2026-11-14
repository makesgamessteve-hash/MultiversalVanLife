-- Multiversal Van Life - a generated land reached through a signal (MIT).
-- Everything comes from the land's generated description: its world's style
-- (sky, sounds, ground), the settlement and its people, the trouble.
local world = require("lib.world")
local story = require("lib.story")
local dialogue = require("lib.dialogue")
local progress = require("lib.progress")
local LQ = require("lib.landquest")
local gen = require("gen")
local places = require("memory.places")
local talk = require("lib.talk")

world.register({
  id = "land",
  name = "A generated land",
  ambient = "sounds/ambient_night.wav",
  build = function(w)
    local addr = w.args.address or progress.land_address()
    local G = gen.world
    -- stored on the first visit; later visits load exactly what was stored
    local stored = places.get(G, addr)
    -- time has passed since the last visit: the aftermath of what the
    -- player did, and the land as it is now
    local log = require("memory.changes").open(addr)
    require("memory.aftermath").update(stored, log, progress.night())
    require("memory.spread").answer(addr, "invitation", progress.night())
    local node = require("memory.aftermath").view(stored, log)
    local d = node.data
    local style = gen.provisional.style(d.style)
    local planet = places.ancestor(node, "planet")
    w.name = d.name .. ", " .. (planet and planet.name or "?")
    w.ambient, w.ambient_volume = style.ambient, 0.5
    -- the planet's sky at the moment of this visit
    local heavens = d.place and gen.sky.heavens_of(G, node)
    if heavens then
      w.sky = { heavens = heavens, place = d.place, time = gen.sky.visit_time(heavens, node.seed, progress.night()) }
      gen.sky.apply(heavens, d.place, w.sky.time)
    else
      local e = style.env
      w:env({ sky_top = e.sky_top, sky_horizon = e.sky_horizon, fog_color = e.fog, fog_near = 14, fog_far = e.fog_far or 70,
              ambient = e.ambient, sun_dir = { -0.4, -1, -0.3 }, sun_color = { 0.3, 0.32, 0.4 }, stars = e.stars })
    end
    w:land(node, function(gx, gz)
      local n = gen.neighbour_land(G, addr, gx, gz)
      return n and places.get(G, n.address) or nil
    end)
    -- people (the first one has the trouble); they talk like their people
    -- and remember the player
    for i = 2, #d.people do
      local p = d.people[i]
      -- where the Wanderer legend is told, people recognise the van
      local topic = d.wanderer and i == 2 and
                    "The Wanderer's wagon, cream and teal! The old stories said it would come back one day." or nil
      w:npc_at(p, function()
        if LQ.talk(w, p) then return end
        if p.lines then
          -- a person of history speaks of their deeds
          local said = {}
          for k, text in ipairs(p.lines) do
            said[k] = { speaker = "villager", name = p.name, text = text, color = { 1, 0.9, 0.6 } }
          end
          dialogue.say(said)
        else
          talk.villager(w, node, p, { topic = topic })
        end
      end)
    end
    LQ.start(w, node, gen.cosmos)
    -- what the player learns here: the place and its people at once,
    -- inscriptions by reading them, creatures by watching them
    local codex = require("memory.codex")
    local hud = require("lib.hud")
    if codex.visit(node) > 0 then hud.notify("New in the codex: " .. d.name) end
    local carved = {}
    for _, f in ipairs(d.features) do if f.statue or f.trace then carved[#carved + 1] = f end end
    for _, f in pairs(log.placed) do if f.statue or f.trace then carved[#carved + 1] = f end end
    for _, f in ipairs(carved) do
      w:interactable({ x = f.x, z = f.z, range = 3.2, prompt = "Read the inscription", use = function()
        local text, e = codex.read(node, f)
        if text then
          dialogue.say({ speaker = "narrator", text = text })
          hud.notify("In the codex: " .. e.name)
        end
      end })
    end
    local watch = 0
    w:on_update(function(dt)
      watch = watch + dt
      if watch < 0.5 or not w.streamer then return end
      watch = 0
      local px, pz = require("lib.player").x, require("lib.player").z
      for _, cr in ipairs(w.streamer.creatures:all()) do
        local dx, dz = cr.x - px, cr.z - pz
        if dx * dx + dz * dz < 100 and codex.observe(node, cr.sp.id) then hud.notify("You watch the " .. cr.sp.name) end
      end
    end)
    local v = d.spots.van
    story.place_van(w, v.x, v.z, v.yaw)
    return story.van_door.x, story.van_door.z, story.van_door.yaw
  end,
  update = function(w, dt) LQ.update(w, dt) end,
})
