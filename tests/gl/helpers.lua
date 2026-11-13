-- Helpers for OpenGL tests: freeze the game and build a test scene.
G = {}

function G.freeze()
  game.update = function() end
  game.draw_ui = function() end
  mvl.clear_scene()
  for i = 0, 7 do mvl.portal(i) mvl.light(i) end
  mvl.bounds(-1000, -1000, 1000, 1000)
  mvl.environment({ reset = true, sky_top = {0, 0, 0}, sky_horizon = {0, 0, 0}, fog_color = {0, 0, 0},
                    fog_near = 400, fog_far = 500, stars = 0, ambient = {1, 1, 1} })
end

function G.box(x, y, z, sx, sy, sz, r, g, b, extra)
  local t = { mesh = mvl.box_mesh(sx, sy, sz), pos = {x, y, z}, color = {r, g, b, 1}, unlit = true, nofog = true }
  for k, v in pairs(extra or {}) do t[k] = v end
  return mvl.spawn(t)
end

-- Tessellated plane (2 m cells, like terrain chunks).
function G.plane(x, y, z, sx, sz, r, g, b, extra)
  extra = extra or {}
  local cell = extra.cell or 2
  local seg = math.max(1, math.floor(math.max(sx, sz) / cell))
  local t = { mesh = mvl.plane_mesh(sx, sz, 1, 1, seg), pos = {x, y, z}, color = {r, g, b, 1}, unlit = true, nofog = true }
  for k, v in pairs(extra) do if k ~= "cell" then t[k] = v end end
  return mvl.spawn(t)
end
