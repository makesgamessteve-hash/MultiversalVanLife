-- Frustum culling: looking away from 200 boxes draws far fewer of them.
G.freeze()
for i = 1, 200 do G.box((i % 20) * 2 - 20, 0, -10 - math.floor(i / 20) * 2, 1, 1, 1, 1, 1, 1) end
mvl.camera(0, 1.5, 0, 0, 0, 70)
test.wait(5)
local facing = mvl.render_stats()
mvl.camera(0, 1.5, 0, math.pi, 0, 70)
test.wait(5)
local away = mvl.render_stats()
mvl.log(string.format("draw calls: facing the boxes %d, looking away %d", facing, away))
test.expect(facing > 150, "boxes drawn when facing them")
test.expect(away < facing / 4, "boxes culled when looking away")
