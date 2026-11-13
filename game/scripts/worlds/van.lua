-- Multiversal Van Life - the van interior (bigger on the inside) (MIT).
local world = require("lib.world")
local story = require("lib.story")

world.register({
  id = "van",
  name = "Juniper",
  ambient = "sounds/van_hum.wav",
  ambient_volume = 0.45,
  build = function(w)
    w:env({
      sky_top = { 0.07, 0.05, 0.04 }, sky_horizon = { 0.12, 0.09, 0.06 }, fog_color = { 0.12, 0.09, 0.06 },
      fog_near = 30, fog_far = 80, ambient = { 0.55, 0.5, 0.45 }, sun_dir = { 0.2, -1, 0.3 },
      sun_color = { 0.35, 0.3, 0.25 }, stars = 0,
    })
    w:bounds(-3.8, -3.8, 3.8, 3.8)
    w:prop({ voxel = "van_interior", x = 0, z = 0 })
    w:prop({ mesh = mvl.box_mesh(8, 0.1, 8), texture = "metal_panel", x = 0, y = 3.0, z = 0 })
    w:prop({ model = "cube", x = 0, y = 0, z = 0, scale = 0.01, radius = 0.95 }) -- console collider
    w:light(0, 0, 2.2, 0, 0.3, 1.0, 0.9, 6)
    w:light(1, -3, 2.5, 0, 1.0, 0.7, 0.4, 5)
    w:light(2, 3, 2.5, 2, 1.0, 0.7, 0.4, 5)
    w.state.light_base = { 0.3, 1.0, 0.9 }
    w:interactable({ x = 0, z = 0, range = 2.2, prompt = "Use the console", use = function() story.open_console() end })
    w:interactable({ x = -3.9, z = 0, range = 1.6, prompt = "Step outside", use = function() story.exit_van() end })
    return -3.2, 0, -math.pi / 2
  end,
  update = function(w, dt)
    local t = mvl.time()
    local travelling = w.state.travelling
    local pulse = 0.75 + 0.25 * math.sin(t * 2)
    if travelling and travelling > 0 then
      w.state.travelling = travelling - dt
      pulse = 0.6 + 0.8 * math.abs(math.sin(t * 13))
      mvl.light(0, 0, 2.2, 0, 1.0 * pulse, 0.6 * pulse, 1.0 * pulse, 8)
    else
      local b = w.state.light_base
      mvl.light(0, 0, 2.2, 0, b[1] * pulse, b[2] * pulse, b[3] * pulse, 6)
    end
  end,
})
