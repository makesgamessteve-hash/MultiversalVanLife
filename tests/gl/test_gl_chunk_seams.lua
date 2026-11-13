-- Neighbouring terrain chunks of a hilly land share their borders exactly:
-- looking across many chunk borders against a pure red sky, no red may
-- show through the ground.
G.freeze()
mvl.environment({ sky_top = { 1, 0, 0 }, sky_horizon = { 1, 0, 0 }, fog_color = { 1, 0, 0 }, fog_near = 400, fog_far = 500 })
mvl.terrain({ seed = 9, amp = 9, freq = 0.03, octaves = 4,
              palette = { { 40, 90, 40 }, { 70, 110, 60 }, { 110, 120, 90 } }, color_low = -9, color_high = 9 })
local size = 32
for cz = -6, 2 do
  for cx = -4, 4 do
    mvl.spawn({ mesh = mvl.terrain_chunk(cx, cz, size, 16), pos = { cx * size, 0, cz * size }, unlit = true, nofog = true })
  end
end
-- standing on a border corner, looking down the hills across many borders
local h = mvl.height(0, 64)
mvl.camera(0, h + 7, 64, 0, -0.32, 70)
test.wait(5)
test.screenshot("seams.tga")
test.wait(3)
