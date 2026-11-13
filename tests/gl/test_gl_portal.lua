-- A portal shows a distant blue box; a wall in front of the portal hides it.
G.freeze()
G.plane(0, 0, 0, 200, 200, 0.2, 0.2, 0.2)
G.box(500, 0, 490, 6, 6, 2, 0, 0, 1)                    -- only visible through the portal
mvl.portal(0, { pos = {0, 1.5, 0}, yaw = 0, w = 2, h = 2, target = {500, 1.5, 500}, target_yaw = 0 })
mvl.camera(0, 1.5, 3, 0, 0, 70)
test.wait(5)
test.screenshot("portal_open.tga")
test.wait(3)
local wall = G.box(0, 0, 1.5, 4, 4, 0.2, 0.5, 0.5, 0.5)
test.wait(5)
test.screenshot("portal_blocked.tga")
test.wait(3)
mvl.destroy(wall)
mvl.camera(0, 1.5, -3, math.pi, 0, 70)                  -- behind the portal: one-sided, nothing shown
test.wait(5)
test.screenshot("portal_back.tga")
test.wait(3)
