-- People of two species with different body plans, in their cultures'
-- dress: their shapes and colours differ.
G.freeze()
mvl.terrain({ seed = 1, amp = 0 })
local PEOPLE = require("gen.visuals.people")
mvl.environment({ sky_top = { 0, 0, 1 }, sky_horizon = { 0, 0, 1 }, fog_color = { 0, 0, 1 }, fog_near = 400, fog_far = 500,
                  ambient = { 1, 1, 1 }, sun_color = { 0, 0, 0 }, stars = 0 })
mvl.sky({})
local a = { anatomy = { limbs = 4, hands = 2, wings = true, tail = false, eyes = 2, mouth = "beak", build = 1.0,
                        height = 1.6, covering = "feathers" },
            hue = 200, dress = { garment = "harness", color = { 150, 60, 50 }, trim = { 230, 230, 230 }, status = "headdress" },
            accent = { 230, 180, 60 } }
local b = { anatomy = { limbs = 6, hands = 2, wings = false, tail = true, eyes = 4, mouth = "lips", build = 1.4,
                        height = 2.2, covering = "fur" },
            hue = 30, dress = { garment = "robe", color = { 60, 80, 140 }, trim = { 200, 80, 60 }, status = "sash" },
            accent = { 200, 80, 60 } }
local ma, ha = PEOPLE.mesh(a)
local mb, hb = PEOPLE.mesh(b)
test.expect(ma > 0 and mb > 0, "both build")
test.expect(ha ~= hb, "different shapes")
test.expect(PEOPLE.plan(b.anatomy).taur and not PEOPLE.plan(a.anatomy).taur, "six limbs stand as a taur, four upright")
local _, ha2 = PEOPLE.mesh(a)
test.eq(ha2, ha, "a person builds the same every time")
mvl.spawn({ mesh = ma, pos = { -1.2, 0, -4 }, yaw = math.pi, unlit = true }) -- facing the camera
mvl.spawn({ mesh = mb, pos = { 1.2, 0, -4 }, yaw = math.pi, unlit = true })
mvl.camera(0, 1.3, 0, 0, -0.1, 60)
test.wait(3)
test.screenshot("people.tga")
test.wait(2)
