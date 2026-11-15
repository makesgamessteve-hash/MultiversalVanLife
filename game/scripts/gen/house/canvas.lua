-- Multiversal Van Life - a room's voxel canvas and the pen that draws
-- furniture into it (MIT License).
--
-- A canvas is one voxel grid (1/8 m) for one room, addressed in room
-- coordinates: u along the room's +X, v along its +Z (the van's left) and h
-- up; h = 0 is the floor layer (its top is the floor), h = H - 1 the ceiling.
-- The grid's own Y runs the other way (its mesh maps Y to -Z), which the
-- canvas hides.
--
-- A pen draws a piece of furniture in its own frame: a across its width, b
-- from its front (b = 0) to its back, c up; placed facing one of "-z", "+z",
-- "+x" or "-x" (the direction its front looks), its footprint is W x D
-- voxels for "-z"/"+z" and D x W for "+x"/"-x".
local C = { S = 0.125 }
C.__index = C

local S = C.S

function C.new(w, d, h)
  local W, D = math.floor(w / S + 0.5), math.floor(d / S + 0.5)
  local H = math.floor(h / S + 0.5) + 2
  assert(W <= 256 and D <= 256 and H <= 256, "room too large for one grid")
  return setmetatable({ g = mvl.voxels(W, D, H), W = W, D = D, H = H }, C)
end

function C:color(i, c) self.g:color(i, c[1], c[2], c[3]) end
function C:box(u0, v0, h0, u1, v1, h1, c)
  if v0 > v1 then v0, v1 = v1, v0 end
  self.g:box(u0, self.D - 1 - v1, h0, u1, self.D - 1 - v0, h1, c)
end
function C:set(u, v, h, c) self.g:set(u, self.D - 1 - v, h, c) end
function C:get(u, v, h) return self.g:get(u, self.D - 1 - v, h) end
-- continuous coordinates (voxel centres at .5)
function C:cylinder(cu, cv, h0, h1, r, c) self.g:cylinder(cu, self.D - cv, h0, h1, r, c) end
function C:ellipsoid(cu, cv, ch, ru, rv, rh, c) self.g:ellipsoid(cu, self.D - cv, ch, ru, rv, rh, c) end
function C:clear(u0, v0, h0, u1, v1, h1) self:box(u0, v0, h0, u1, v1, h1, 0) end
function C:mesh() return self.g:mesh(S) end
function C:free() self.g:free() end

-- ---------------------------------------------------------------- pen
local P = {}
P.__index = P

-- A pen for a piece W wide, D deep, with the minimum corner of its footprint
-- at (u0, v0) and its base on layer h0, facing `face`.
function C:pen(u0, v0, h0, W, D, face)
  return setmetatable({ cv = self, u0 = u0, v0 = v0, h0 = h0, W = W, D = D, face = face or "-z" }, P)
end

-- piece (a, b) -> room (u, v), for voxel indices
function P:map(a, b)
  local f, W, D = self.face, self.W, self.D
  if f == "-z" then return self.u0 + a, self.v0 + b
  elseif f == "+z" then return self.u0 + W - 1 - a, self.v0 + D - 1 - b
  elseif f == "+x" then return self.u0 + D - 1 - b, self.v0 + a
  else return self.u0 + b, self.v0 + W - 1 - a end
end

-- piece (a, b) -> room (u, v), for continuous coordinates
function P:mapc(a, b)
  local f, W, D = self.face, self.W, self.D
  if f == "-z" then return self.u0 + a, self.v0 + b
  elseif f == "+z" then return self.u0 + W - a, self.v0 + D - b
  elseif f == "+x" then return self.u0 + D - b, self.v0 + a
  else return self.u0 + b, self.v0 + W - a end
end

function P:box(a0, b0, c0, a1, b1, c1, col)
  local u0, v0 = self:map(a0, b0)
  local u1, v1 = self:map(a1, b1)
  if u0 > u1 then u0, u1 = u1, u0 end
  self.cv:box(u0, v0, self.h0 + c0, u1, v1, self.h0 + c1, col)
end

function P:set(a, b, c, col)
  local u, v = self:map(a, b)
  self.cv:set(u, v, self.h0 + c, col)
end

function P:cylinder(ca, cb, c0, c1, r, col)
  local u, v = self:mapc(ca, cb)
  self.cv:cylinder(u, v, self.h0 + c0, self.h0 + c1, r, col)
end

function P:ellipsoid(ca, cb, cc, ra, rb, rc, col)
  local u, v = self:mapc(ca, cb)
  local ru, rv = ra, rb
  if self.face == "+x" or self.face == "-x" then ru, rv = rb, ra end
  self.cv:ellipsoid(u, v, self.h0 + cc, ru, rv, rc, col)
end

-- The footprint of a piece placed with the given centre (metres in the room)
-- and facing: minimum corner and size in voxels.
function C.footprint(x, z, W, D, face)
  local fu, fv = W, D
  if face == "+x" or face == "-x" then fu, fv = D, W end
  return math.floor(x / S - fu / 2 + 0.5), math.floor(z / S - fv / 2 + 0.5), fu, fv
end

return C
