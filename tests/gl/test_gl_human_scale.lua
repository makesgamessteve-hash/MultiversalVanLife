-- Buildings at human scale: a generated village house 12 m in front of a
-- standing player's eye (1.6 m) rises far above the horizon, and a villager
-- 1.7 m tall stands by its door, a head shorter than the doorway.
G.freeze()
mvl.terrain({ seed = 1, amp = 0 })
local B = require("gen.visuals.buildings")
local P = require("gen.visuals.people")
mvl.environment({ sky_top = { 0, 0, 1 }, sky_horizon = { 0, 0, 1 }, fog_color = { 0, 0, 1 }, fog_near = 400, fog_far = 500,
                  ambient = { 1, 1, 1 }, sun_color = { 0, 0, 0 }, stars = 0 })
mvl.sky({})
local style = {
  material = "timber", plan = "square", roof = "gable", pitch = 0.7, wall = 1, door = { h = 16, w = 7 }, height = 1.7,
  roof_entry = false, ornament = "none", sky_faith = false, storeys = 1,
  palette = { wall = { 200, 60, 50 }, wall_dark = { 150, 40, 34 }, roof = { 210, 70, 50 }, roof_dark = { 160, 50, 40 },
              wood = { 120, 40, 30 }, accent = { 230, 60, 60 } },
}
local mesh, box, _, plan = B.mesh("house", style, 4)
test.expect(plan.storeys >= 2 and box[1] >= 9 and box[2] >= 7, "a village house is big: " .. box[1] .. " x " .. box[2] ..
            " m, " .. plan.storeys .. " storeys")
test.expect(plan.metres.door >= 2.0 and plan.metres.door_w >= 1.0, "its door fits a person and the player")
mvl.spawn({ mesh = mesh, pos = { 0, 0, -12 - box[2] / 2 }, yaw = math.pi, unlit = true })
local person = P.mesh({ anatomy = { limbs = 4, hands = 2, eyes = 2, mouth = "lips", height = 1.7 }, hue = 120,
                        dress = { garment = "tunic", color = { 40, 200, 60 }, trim = { 40, 200, 60 }, status = "none" },
                        accent = { 40, 200, 60 } })
mvl.spawn({ mesh = person, pos = { 2.2, 0, -11.2 }, yaw = 0, unlit = true })
mvl.camera(0, 1.6, 0, 0, 0, 70)
test.wait(3)
test.screenshot("human_scale.tga")
test.wait(2)
