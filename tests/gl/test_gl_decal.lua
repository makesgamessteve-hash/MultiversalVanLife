-- A red decal on green ground, seen from far away at a shallow angle, must
-- show no green: decals are drawn after the surface below them.
G.freeze()
G.plane(0, 0, -150, 400, 400, 0, 1, 0)                                -- ground (2 m cells)
-- not vertex-aligned with the ground (offset, 3 m cells) and 3 cm below it, like a road on
-- slightly curved terrain: without the decal pass the ground would hide it
G.plane(0.7, -0.03, -165.3, 300, 300, 1, 0, 0, { decal = true, layer = 0, cell = 3 })
mvl.camera(0, 1.5, 0, 0, 0, 70)
test.wait(5)
test.screenshot("decal.tga")
test.wait(3)
