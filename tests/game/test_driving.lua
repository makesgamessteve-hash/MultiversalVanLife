-- Driving Juniper: the driver's seat at the front of the interior; at home
-- the van stays parked; in a generated land the player drives it over the
-- terrain (speed, steering, collisions), seen from behind the van or
-- through the windscreen window, with the door, lights, windows and
-- streaming following it; getting up parks it, and the land remembers
-- where, on later visits and after a restart.
local D = game.debug
local van = D.story.van
local drive = D.drive
local p = D.player

local function restart()
  D.open_pause()
  H.choose(D.pause_menu(), "Save and return")
  H.choose(D.title_menu(), "Continue")
  H.finish_dialogue()
end

-- ------------------------------------------------------------- at home
H.new_game_in_van(2026)
test.expect(H.find("Sit in the driver's seat"), "the interior has a driver's seat")
local home = { x = van.exterior.x, z = van.exterior.z }
H.use("Sit in the driver's seat")
test.expect(not drive.active, "at home the van stays parked")
test.expect(D.dialogue.current and D.dialogue.current.text:find("home", 1, true), "and Juniper says why")
H.finish_dialogue()
test.eq(van.exterior.x, home.x, "it did not move")

-- ------------------------------------------------------------ in a land
local addr = D.story.signals()[1].address
H.travel_to(addr)
local start = { x = van.exterior.x, z = van.exterior.z, yaw = van.exterior.yaw }
local window0 = { van.window_target(3) }
H.use("Sit in the driver's seat")
test.expect(drive.active, "the player sits at the wheel")
test.eq(drive.view, "chase", "seen from behind the van")
test.expect(not p.enabled, "the player does not walk while driving")
-- forward
test.hold("move_y", 90)
local fx, fz = math.cos(start.yaw), -math.sin(start.yaw)
local along = (van.exterior.x - start.x) * fx + (van.exterior.z - start.z) * fz
test.expect(along > 4, "the van drives forward: " .. along .. " m")
test.expect(drive.speed > 3, "and gathers speed: " .. drive.speed)
local wx = van.window_target(3)
test.expect(wx ~= window0[1], "the windows look out from where the van is now")
test.expect(D.world.current.streamer:chunk_at(van.exterior.x, van.exterior.z), "the land streams around the van")
local door = D.story.van_door
test.expect(math.abs(door.x - (van.exterior.x - math.cos(van.exterior.yaw) * 3.6)) < 0.01, "the door follows it")
-- the chase camera is behind the van, above the ground
local cx, cy, cz = mvl.camera()
local back = (cx - van.exterior.x) * math.cos(van.exterior.yaw) + (cz - van.exterior.z) * -math.sin(van.exterior.yaw)
test.expect(back < -3 and cy > van.exterior.y + 1, "the camera follows from behind: " .. back)
-- steering right turns right (at speed)
local yaw0 = van.exterior.yaw
test.input("move_y", 1)
test.input("move_x", 1)
test.wait(30)
test.input("move_x", 0)
test.input("move_y", 0)
test.expect(van.exterior.yaw < yaw0 - 0.2, "steering turns the van: " .. yaw0 .. " -> " .. van.exterior.yaw)
-- braking and reversing
test.hold("move_y", 60, -1)
test.expect(drive.speed < 0, "braking, then reversing: " .. drive.speed)
test.wait(90)
test.expect(math.abs(drive.speed) < 0.5, "the van rolls to a stop")
-- the windscreen view: seated in the interior, looking out of the front window
test.press("interact")
test.eq(drive.view, "cab", "the view through the windscreen")
cx, cy, cz = mvl.camera()
test.expect(cy < van.P[2] + 2 and cy > van.P[2] + 1, "the camera is at the wheel inside: " .. cy)
test.press("interact")
test.eq(drive.view, "chase", "and back behind the van")
-- a wall stops the van
local e = van.exterior
local c, s = math.cos(e.yaw), -math.sin(e.yaw)
local wall = D.world.current:prop({ model = "cube", x = e.x + c * 7, y = e.y, z = e.z + s * 7, yaw = e.yaw,
                                    scale = { 1, 4, 8 }, box = { 1, 8 } })
test.hold("move_y", 120)
local dist = (e.x + c * 7 - van.exterior.x) * c + (e.z + s * 7 - van.exterior.z) * s
test.expect(dist > 1.3, "a wall stops the van: " .. dist .. " m from it")
mvl.destroy(wall)
-- deep water stops the van: the ground ahead becomes sea for a moment
e = van.exterior
c, s = math.cos(e.yaw), -math.sin(e.yaw)
local x0, z0, height = e.x, e.z, mvl.height
mvl.height = function(x, z)
  if (x - x0) * c + (z - z0) * s > 4 then return -5 end
  return height(x, z)
end
test.hold("move_y", 120)
local reached = (van.exterior.x - x0) * c + (van.exterior.z - z0) * s
mvl.height = height
test.expect(reached <= 4.01 and reached > 1, "the van stops at the water's edge: " .. reached .. " m")
test.wait(60)
-- getting up parks it; the land remembers the place
test.press("back")
test.expect(not drive.active, "the player gets up")
test.expect(p.enabled and van.inside, "and stands in the van")
local parked = { x = van.exterior.x, z = van.exterior.z, yaw = van.exterior.yaw }
local log = D.world.current:memory()
test.expect(log.van and math.abs(log.van.x - parked.x) < 0.01, "the land remembers where the van is")
H.use("Step outside")
H.wait_idle()
local dx, dz = p.x - parked.x, p.z - parked.z
test.expect(math.sqrt(dx * dx + dz * dz) < 4.5, "stepping outside leads behind the parked van")
test.expect(H.find("Enter the van"), "its door is there")
H.use("Enter the van")
H.finish_dialogue()

-- ------------------------------------------------------ remembered place
H.travel_to(H.land_with("gather") or D.story.signals()[2].address)
H.travel_to(addr)
test.expect(math.abs(van.exterior.x - parked.x) < 0.01 and math.abs(van.exterior.z - parked.z) < 0.01,
            "coming back, the van is where it was parked")
restart()
test.expect(math.abs(van.exterior.x - parked.x) < 0.01 and math.abs(van.exterior.yaw - parked.yaw) < 0.001,
            "and after a restart too")
-- travelling while at the wheel is impossible: the trip gets the player up
H.use("Sit in the driver's seat")
test.expect(drive.active, "at the wheel again")
D.story.travel("home")
test.expect(not drive.active, "a trip gets the player up")
test.until_true(function() return not D.story.busy end, 1200, "home")
H.finish_dialogue()
