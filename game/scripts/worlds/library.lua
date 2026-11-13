-- Multiversal Van Life - the Tidewater Library: reshelve lost books (MIT).
local world = require("lib.world")
local story = require("lib.story")
local dialogue = require("lib.dialogue")
local progress = require("lib.progress")
local audio = require("lib.audio")
local hud = require("lib.hud")

local BOOKS = { { -6, -4 }, { 7, -9 }, { -9, -15 }, { 4, -19 } }
local SHELVES = { { -11, -8, math.pi / 2 }, { 11, -8, -math.pi / 2 }, { -11, -16, math.pi / 2 }, { 11, -16, -math.pi / 2 }, { 0, -24, 0 } }

world.register({
  id = "library",
  name = "Tidewater Library",
  description = "A drowned library where the tide carries stories in and out.",
  destination = true,
  order = 3,
  ambient = "sounds/ambient_library.wav",
  build = function(w)
    local s = w.state
    local helped = progress.helped("library")
    w:env({
      sky_top = { 0.0, 0.05, 0.12 }, sky_horizon = { 0.05, 0.2, 0.32 }, fog_color = { 0.05, 0.18, 0.28 },
      fog_near = 6, fog_far = 38, ambient = { 0.25, 0.35, 0.45 }, sun_dir = { 0, -1, 0.2 },
      sun_color = { 0.2, 0.35, 0.45 }, stars = 0.2,
    })
    w:bounds(-12, -26, 12, 10)
    w:ground("sand", 80, 40)
    w:prop({ mesh = mvl.plane_mesh(24, 36, 8, 12), texture = "water", x = 0, y = 0.05, z = -8, uv_scroll = { 0.01, 0.03 }, color = { 0.6, 0.8, 1.0, 0.55 } })
    for i, p in ipairs(SHELVES) do w:prop({ voxel = "bookshelf", x = p[1], z = p[2], yaw = p[3], box = { 2.0, 0.8 } }) end
    for i = 1, 4 do
      local x, z = (i % 2 == 0) and 6 or -6, -2 - i * 5
      w:prop({ model = "crystal", texture = "crystal", x = x, z = z, unlit = true, radius = 0.5 })
      w:light(i - 1, x, 1.5, z, 0.5, 0.4, 1.0, 7)
    end
    for i = 1, 10 do w:prop({ model = "cube", texture = "stone", x = (i % 2 == 0) and 12.5 or -12.5, z = 8 - i * 3.5, scale = { 1, 4, 1 } }) end
    s.carrying, s.shelved = 0, 0
    if not helped then
      for i, p in ipairs(BOOKS) do
        local e = w:sprite({ texture = "book", x = p[1], y = 0.1, z = p[2], w = 0.4, h = 0.4 })
        local B = { e = e }
        B.it = w:interactable({ entity = e, range = 2.0, prompt = "Pick up the book",
          use = function()
            mvl.destroy(B.e)
            w:remove_interactable(B.it)
            s.carrying = s.carrying + 1
            audio.sfx("pickup", 0.6)
            dialogue.say("library_book")
          end })
      end
    end
    for _, p in ipairs(SHELVES) do
      w:interactable({ x = p[1], z = p[2], range = 2.2, prompt = "Return a book",
        enabled = function() return s.carrying > 0 end,
        use = function()
          s.carrying, s.shelved = s.carrying - 1, s.shelved + 1
          audio.sfx("interact", 0.7)
          hud.notify("Books returned: " .. s.shelved .. "/" .. #BOOKS)
          if s.shelved == #BOOKS then
            progress.set_helped("library")
            progress.save()
            audio.sfx("quest_done", 0.9)
            dialogue.say({ "library_shelf", "quill_done" })
          else
            dialogue.say("library_shelf")
          end
        end })
    end
    w:npc({ texture = "npc_librarian", name = "Quillfin", x = 0, z = 2, h = 2.0, talk = function()
      dialogue.say(progress.helped("library") and "quill_done" or { "quill_1", "quill_2", "quill_3" })
    end })
    story.place_van(w, -4, 7, -math.pi / 2 - 0.3)
    return story.van_door.x, story.van_door.z, story.van_door.yaw
  end,
})
