-- The van interior is part of the world scene: entering and leaving moves the
-- player without loading a world, travelling replaces only the outside, and
-- the windows look out of the parked van or into the vortex.
local D = game.debug
local van = D.van
H.new_game()
H.finish_dialogue()
local w0 = D.world.current
local probe = mvl.spawn({ mesh = mvl.box_mesh(1, 1, 1), pos = { 3, 0, 3 } })   -- a world entity
H.use("Enter the van")
H.finish_dialogue()
test.expect(van.inside, "inside the van")
test.eq(D.world.current, w0, "the world was not reloaded")
test.expect(mvl.exists(probe), "world entities survive entering")
test.eq(D.hud.fade, 0, "no loading fade")
test.expect(D.player.base_y < -100, "player stands in the pocket")
local room = van.entities.room
-- windows point at the exterior van's windows (within a few metres of it)
for i = 1, #van.WINDOWS do
  local x, y, z = van.window_target(i)
  local e = van.exterior
  test.expect(x and math.sqrt((x - e.x) ^ 2 + (z - e.z) ^ 2) < 3.2, "window " .. i .. " looks out of the van")
end
-- leaving: immediate, same world
H.use("Step outside")
test.expect(not van.inside, "outside again")
test.eq(D.world.current, w0, "still the same world")
test.eq(D.player.base_y, 0, "on the ground")
test.expect(math.abs(D.player.x - D.story.van_door.x) < 0.01, "standing at the rear door")
-- travelling: the interior stays, the outside is replaced, the windows show the vortex
H.use("Enter the van")
H.use("console")
H.finish_dialogue()
H.choose(D.story.menu, "Lanternfen")
test.wait(5)
test.expect(van.travelling, "travelling")
local tx, ty = van.window_target(1)
test.expect(ty > 500, "windows show the vortex while travelling")
test.until_true(function() return not D.story.busy end, 600, "arrived")
test.expect(van.inside and mvl.exists(room), "the interior stayed")
test.expect(D.world.current ~= w0 and D.world.current.def.id == "fen", "the outside is Lanternfen now")
test.expect(not mvl.exists(probe), "the old world is gone")
local x, _, z = van.window_target(3)
test.expect(math.sqrt((x - van.exterior.x) ^ 2 + (z - van.exterior.z) ^ 2) < 3.2, "windows look out at Lanternfen")
H.finish_dialogue()
