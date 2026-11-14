-- Multiversal Van Life - traces of history in the lands (MIT).
--
-- Battlefields (broken spears, shields and cairns), wrecks of ships that
-- fell from the sky (bent hull plates and ribs), craters (a ring of
-- scorched stones) and shrines to the Wanderer (a small cream-and-teal
-- altar), as voxel models; ruins are weathered buildings in the style of
-- the culture and era that built them (gen/visuals/buildings.lua).
local dm = require("gen.dmath")

local T = {}

local function color(g, i, c) g:color(i, c[1], c[2], c[3]) end

function T.build(kind, seed)
  local r = mvl.rng(seed)
  local g = mvl.voxels(48, 48, 24)
  color(g, 1, { 90, 84, 78 })
  color(g, 2, { 130, 122, 112 })
  color(g, 3, { 112, 78, 48 })
  color(g, 4, { 150, 156, 164 })
  color(g, 5, { 70, 74, 82 })
  color(g, 6, { 226, 214, 176 })
  color(g, 7, { 70, 150, 140 })
  color(g, 8, { 40, 36, 34 })
  if kind == "battlefield" then
    for _ = 1, 9 do
      local x, y = 6 + r:next() * 36, 6 + r:next() * 36
      local lean = (r:next() - 0.5) * 8
      g:line(x, y, 0, x + lean, y + (r:next() - 0.5) * 6, 8 + r:next() * 8, 0.5, 3) -- spears
    end
    for _ = 1, 5 do g:cylinder(6 + r:next() * 36, 6 + r:next() * 36, 0, 1, 2 + r:next() * 1.5, 4) end -- shields
    g:sphere(24, 24, 1, 5, 1) -- a cairn for the fallen
    g:sphere(24, 24, 5, 3, 2)
  elseif kind == "wreck" then
    for k = 1, 6 do
      local a = k * dm.pi / 3 + r:next() * 0.4
      local x, y = 24 + dm.cos(a) * 8, 24 + dm.sin(a) * 14
      g:line(x, y, 0, x + dm.cos(a) * 4, y + dm.sin(a) * 4, 10 + r:next() * 10, 1.2, 5) -- ribs
    end
    g:box(14, 10, 0, 34, 38, 2, 4) -- the hull plates
    g:ellipsoid(24, 24, 3, 6, 12, 4, 4)
    g:sphere(24, 30, 4, 4, 0)
    g:replace(4, 4)
  elseif kind == "crater" then
    for k = 0, 23 do
      local a = k * dm.pi / 12
      local rr = 17 + r:next() * 3
      g:sphere(24 + dm.cos(a) * rr, 24 + dm.sin(a) * rr, 1, 2 + r:next() * 2, k % 3 == 0 and 8 or 1)
    end
    g:cylinder(24, 24, 0, 0, 14, 8)
  else -- a shrine to the Wanderer
    g:box(18, 18, 0, 30, 30, 3, 2)
    g:box(20, 21, 4, 28, 27, 9, 6)   -- a little wagon of cream
    g:box(20, 21, 10, 28, 27, 11, 7) -- with its teal roof
    g:cylinder(21, 21, 2, 3, 2, 8)
    g:cylinder(27, 27, 2, 3, 2, 8)
    for _, x in ipairs({ 16, 32 }) do g:line(x, 16, 0, x, 16, 14, 0.6, 3) end
  end
  return g
end

-- Mesh, collider footprint and hash of a trace p = {trace = kind, seed}.
function T.mesh(p)
  local g = T.build(p.trace, p.seed or 1)
  local hash = g:hash()
  local mesh = g:mesh(0.125)
  g:free()
  return mesh, p.trace ~= "battlefield" and { 3, 3 } or nil, hash
end

return T
