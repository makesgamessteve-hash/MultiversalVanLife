-- A gallery of buildings in three styles against a blue backdrop: houses,
-- workshops, temples and wells of different peoples look different.
G.freeze()
mvl.terrain({ seed = 1, amp = 0 })
local A = require("gen.culture.architecture")
local B = require("gen.visuals.buildings")
mvl.environment({ sky_top = { 0, 0, 1 }, sky_horizon = { 0, 0, 1 }, fog_color = { 0, 0, 1 }, fog_near = 400, fog_far = 500,
                  ambient = { 1, 1, 1 }, sun_color = { 0, 0, 0 }, stars = 0 })
mvl.sky({})
local function style(over)
  local s = {
    material = "stone", plan = "square", roof = "gable", pitch = 0.9, wall = 1, door = { h = 14, w = 7 },
    roof_entry = false, ornament = "crescents", sky_faith = true, storeys = 2,
    palette = { wall = { 170, 84, 60 }, wall_dark = { 120, 60, 44 }, roof = { 156, 72, 48 }, roof_dark = { 110, 50, 34 },
                wood = { 112, 78, 48 }, accent = { 230, 210, 120 } },
    dress = { garment = "tunic", color = { 1, 1, 1 }, trim = { 1, 1, 1 }, status = "none" },
  }
  for k, v in pairs(over or {}) do s[k] = v end
  return s
end
local styles = {
  style(),
  style({ material = "timber", plan = "round", roof = "cone", ornament = "flames",
          palette = { wall = { 112, 78, 48 }, wall_dark = { 80, 56, 34 }, roof = { 168, 150, 86 }, roof_dark = { 120, 106, 60 },
                      wood = { 90, 60, 36 }, accent = { 200, 80, 60 } } }),
  style({ material = "mud brick", plan = "tower", roof = "flat", roof_entry = true, ornament = "discs", storeys = 1,
          palette = { wall = { 200, 170, 120 }, wall_dark = { 150, 126, 88 }, roof = { 210, 186, 132 },
                      roof_dark = { 160, 140, 100 }, wood = { 112, 78, 48 }, accent = { 60, 90, 170 } } }),
}
local hashes = {}
-- three styles, each a house and a temple, in one row facing the camera
-- (spaced by their real footprints: buildings are sized to their people)
local row_items, total = {}, 0
for row, st in ipairs(styles) do
  for col, kind in ipairs({ "house", "temple", "workshop", "well" }) do
    local mesh, box, hash = B.mesh(kind, st, row)
    test.expect(mesh > 0 and box[1] > 0, kind .. " of style " .. row .. " builds")
    test.expect(not hashes[hash], "every building differs")
    hashes[hash] = true
    if col <= 2 then
      row_items[#row_items + 1] = { mesh = mesh, w = box[1], d = box[2] }
      total = total + box[1] + 3
    else
      mvl.release_mesh(mesh)
    end
  end
end
local x = -total / 2
for _, it in ipairs(row_items) do
  mvl.spawn({ mesh = it.mesh, pos = { x + it.w / 2, 0, -30 }, yaw = math.pi, unlit = true })
  x = x + it.w + 3
end
mvl.camera(0, 8, 45, 0, -0.08, 70)
test.wait(3)
test.screenshot("buildings.tga")
test.wait(2)
