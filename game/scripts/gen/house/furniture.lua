-- Multiversal Van Life - furniture for the house inside the van (MIT License).
--
-- Every piece draws itself with a pen (gen/house/canvas.lua) in its own
-- frame: a across its width, b from its front (0) to its back, c up from the
-- floor. `size(o)` gives its width, depth and height in voxels (1/8 m) for
-- the options `o`; `solid` pieces get a box collider of their footprint.
-- Mods can add pieces to `furniture.PIECES`.
local PAL = require("gen.house.palette")
local I = PAL.I

local F = { PIECES = {} }
local S = 0.125

local function vox(m) return math.max(1, math.floor(m / S + 0.5)) end
local function book(rng) return I.book + rng:int(0, PAL.BOOKS - 1) end

local function piece(name, t) F.PIECES[name] = t end
-- a colour option: a palette name ("white") or index
local function col(v, default) if v == nil then return default end return I[v] or v end

-- ------------------------------------------------------------ storage
piece("bookshelf", {
  solid = true,
  size = function(o) return vox(o.w or 2), o.deep and 4 or 3, vox(o.h or 2.2) end,
  draw = function(p, o, rng)
    local W, D, H = p.W, p.D, p.H
    local frame = col(o.frame, I.wood_dark)
    p:box(0, D - 1, 0, W - 1, D - 1, H - 1, frame)          -- back
    p:box(0, 0, 0, 0, D - 1, H - 1, frame)                  -- sides
    p:box(W - 1, 0, 0, W - 1, D - 1, H - 1, frame)
    p:box(0, 0, H - 1, W - 1, D - 1, H - 1, frame)          -- top
    p:box(0, 0, 0, W - 1, D - 1, 0, frame)                  -- plinth
    -- uprights every metre or so
    local bays = math.max(1, math.floor((W - 2) / 9 + 0.5))
    local posts = {}
    for k = 1, bays - 1 do
      local a = math.floor(k * (W - 1) / bays)
      posts[a] = true
      p:box(a, 0, 0, a, D - 2, H - 1, frame)
    end
    -- shelves every 3 voxels, books between them
    for c = 3, H - 2, 3 do p:box(1, 0, c, W - 2, D - 2, c, col(o.shelf, I.wood)) end
    if o.empty then return end
    for c = 1, H - 3, 3 do
      if c + 2 <= H - 1 then
        local a = 1
        while a <= W - 2 do
          if posts[a] then
            a = a + 1
          else
            local r = rng:next()
            if r < 0.06 then
              a = a + rng:int(1, 3)                         -- a gap on the shelf
            elseif r < 0.1 and not posts[a + 1] and a + 1 <= W - 2 then
              p:box(a, D - 2, c, a + 1, D - 2, c, book(rng)) -- a book lying down
              a = a + 2
            else
              local tall = rng:next() < 0.7 and 1 or 0
              p:box(a, 1, c, a, D - 2, c + tall, book(rng))
              a = a + 1
            end
          end
        end
      end
    end
  end,
})

piece("ladder", { -- a library ladder leaning on the shelves (not solid)
  size = function(o) return 4, 1, vox(o.h or 3) end,
  draw = function(p)
    p:box(0, 0, 0, 0, 0, p.H - 1, I.wood_light)
    p:box(3, 0, 0, 3, 0, p.H - 1, I.wood_light)
    for c = 2, p.H - 2, 3 do p:box(1, 0, c, 2, 0, c, I.wood) end
  end,
})

piece("pantry", { -- shelves of jars, tins and sacks
  solid = true,
  size = function(o) return vox(o.w or 1.5), 3, vox(o.h or 2.2) end,
  draw = function(p, o, rng)
    local W, D, H = p.W, p.D, p.H
    p:box(0, D - 1, 0, W - 1, D - 1, H - 1, I.wood)
    p:box(0, 0, 0, 0, D - 1, H - 1, I.wood_dark)
    p:box(W - 1, 0, 0, W - 1, D - 1, H - 1, I.wood_dark)
    for c = 0, H - 1, 4 do p:box(1, 0, c, W - 2, D - 2, c, I.wood_light) end
    local fills = { I.glass, I.copper, I.paper, I.red, I.flower2, I.green, I.cream }
    for c = 1, H - 4, 4 do
      for a = 1, W - 2, 2 do
        if rng:next() < 0.85 then p:box(a, 1, c, a, 1, c + rng:int(1, 2), fills[rng:int(1, #fills)]) end
      end
    end
  end,
})

piece("wardrobe", {
  solid = true,
  size = function(o) return vox(o.w or 1.25), 5, vox(o.h or 2.1) end,
  draw = function(p, o)
    local W, D, H = p.W, p.D, p.H
    p:box(0, 0, 1, W - 1, D - 1, H - 2, I.wood)
    p:box(0, 0, 0, W - 1, D - 1, 0, I.wood_dark)
    p:box(0, 0, H - 1, W - 1, D - 1, H - 1, I.wood_dark)              -- cornice
    local mid = math.floor(W / 2)
    p:box(1, 0, 2, mid - 1, 0, H - 3, I.wood_light)                   -- door panels
    p:box(mid + 1, 0, 2, W - 2, 0, H - 3, I.wood_light)
    p:box(mid, 0, 1, mid, 0, H - 2, I.wood_dark)
    p:set(mid - 1, 0, math.floor(H / 2), I.brass)
    p:set(mid + 1, 0, math.floor(H / 2), I.brass)
  end,
})

piece("dresser", {
  solid = true,
  size = function(o) return vox(o.w or 1.25), 4, vox(o.h or 0.875) end,
  draw = function(p, o)
    local W, D, H = p.W, p.D, p.H
    p:box(0, 0, 0, W - 1, D - 1, H - 2, I.wood)
    p:box(0, 0, H - 1, W - 1, D - 1, H - 1, I.wood_dark)
    for c = 1, H - 2, 2 do
      p:box(1, 0, c, W - 2, 0, c, I.wood_light)
      p:set(math.floor(W / 2), 0, c, I.brass)
    end
  end,
})

piece("chest", {
  solid = true,
  size = function(o) return vox(o.w or 1.0), 5, 4 end,
  draw = function(p)
    local W, D = p.W, p.D
    p:box(0, 0, 0, W - 1, D - 1, 2, I.wood)
    p:box(0, 0, 3, W - 1, D - 1, 3, I.wood_dark)
    p:box(0, 0, 1, W - 1, 0, 1, I.iron)
    p:set(math.floor(W / 2), 0, 2, I.brass)
  end,
})

piece("welsh_dresser", { -- a kitchen dresser with plates on its shelves
  solid = true,
  size = function(o) return vox(o.w or 1.5), 4, 16 end,
  draw = function(p)
    local W = p.W
    p:box(0, 0, 0, W - 1, 3, 6, I.wood)
    p:box(0, 0, 6, W - 1, 3, 6, I.wood_dark)
    for a = 1, W - 2, 3 do p:box(a, 0, 1, math.min(W - 2, a + 1), 0, 5, I.wood_light) end
    p:box(0, 3, 7, W - 1, 3, 15, I.wood)
    p:box(0, 2, 7, 0, 3, 15, I.wood_dark)
    p:box(W - 1, 2, 7, W - 1, 3, 15, I.wood_dark)
    p:box(0, 1, 15, W - 1, 3, 15, I.wood_dark)
    for c = 7, 13, 3 do
      p:box(1, 2, c, W - 2, 2, c, I.wood_dark)
      for a = 1, W - 3, 3 do
        p:box(a, 2, c + 1, a + 1, 2, c + 2, I.porcelain)
        p:set(a, 2, c + 2, I.blue)
      end
    end
  end,
})

-- --------------------------------------------------------------- beds
piece("bed", {
  solid = true,
  size = function(o) return o.single and 8 or 13, 17, 9 end,
  draw = function(p, o)
    local W, D = p.W, p.D
    p:box(0, 0, 0, 0, 0, 1, I.wood_dark)
    p:box(W - 1, 0, 0, W - 1, 0, 1, I.wood_dark)
    p:box(0, 0, 1, W - 1, D - 1, 1, I.wood)                           -- base
    p:box(0, 0, 2, W - 1, D - 2, 2, I.white)                          -- mattress
    p:box(0, 0, 3, W - 1, D - 6, 3, col(o.quilt, I.fabric))              -- quilt
    for a = 1, W - 2, 3 do p:box(a, 0, 3, a, D - 6, 3, col(o.quilt2, I.fabric2)) end
    p:box(0, 0, 2, W - 1, 0, 3, col(o.quilt, I.fabric))                  -- over the foot
    local mid = math.floor(W / 2)
    if W > 9 then
      p:box(1, D - 5, 3, mid - 1, D - 3, 3, I.white)                  -- pillows
      p:box(mid + 1, D - 5, 3, W - 2, D - 3, 3, I.white)
    else
      p:box(1, D - 5, 3, W - 2, D - 3, 3, I.white)
    end
    p:box(0, D - 1, 0, W - 1, D - 1, 8, I.wood_dark)                  -- headboard
    p:box(1, D - 1, 6, W - 2, D - 1, 7, I.wood)
    p:box(0, 0, 0, W - 1, 0, 0, I.wood_dark)                          -- foot
  end,
})

piece("nightstand", {
  solid = true,
  size = function() return 4, 4, 8 end,
  draw = function(p)
    p:box(0, 0, 0, 3, 3, 3, I.wood)
    p:box(0, 0, 2, 3, 0, 2, I.wood_light)
    p:set(2, 0, 2, I.brass)
    p:box(1, 1, 4, 2, 2, 4, I.brass)                                  -- lamp
    p:box(1, 1, 5, 2, 2, 5, I.brass)
    p:box(0, 0, 6, 3, 3, 7, I.glow)
  end,
})

-- --------------------------------------------------------- bathroom
piece("bath", {
  solid = true,
  size = function() return 7, 14, 6 end,
  draw = function(p)
    local W, D = p.W, p.D
    p:box(0, 0, 1, W - 1, D - 1, 4, I.porcelain)
    p:box(1, 1, 3, W - 2, D - 2, 4, 0)                                -- the hollow
    p:box(1, 1, 2, W - 2, D - 2, 2, I.water)
    p:box(0, 1, 5, W - 1, D - 2, 5, I.porcelain)                      -- rolled rim
    p:box(1, 1, 5, W - 2, D - 2, 5, 0)
    for _, a in ipairs({ 0, W - 1 }) do
      p:set(a, 1, 0, I.brass)
      p:set(a, D - 2, 0, I.brass)
    end
    p:box(2, D - 1, 5, 4, D - 1, 5, I.copper)                         -- taps
  end,
})

piece("basin", {
  solid = true,
  size = function() return 5, 4, 7 end,
  draw = function(p)
    p:box(2, 1, 0, 2, 2, 4, I.porcelain)                              -- pedestal
    p:box(0, 0, 5, 4, 3, 6, I.porcelain)
    p:box(1, 0, 6, 3, 2, 6, I.water)
    p:set(2, 3, 7 - 1, I.brass)
  end,
})

piece("toilet", {
  solid = true,
  size = function() return 4, 6, 8 end,
  draw = function(p)
    p:box(1, 0, 0, 2, 3, 2, I.porcelain)
    p:box(0, 0, 3, 3, 4, 3, I.wood_light)                             -- seat
    p:box(0, 5, 0, 3, 5, 7, I.porcelain)                              -- cistern
    p:set(3, 5, 7, I.brass)
  end,
})

piece("towel_rail", {
  size = function() return 6, 1, 9 end,
  draw = function(p)
    p:box(0, 0, 0, 0, 0, 8, I.brass)
    p:box(5, 0, 0, 5, 0, 8, I.brass)
    p:box(0, 0, 8, 5, 0, 8, I.brass)
    p:box(1, 0, 4, 4, 0, 7, I.fabric3)
  end,
})

piece("mirror", { -- flat on a wall; o.y sets its height
  size = function(o) return vox(o.w or 0.75), 1, vox(o.h or 1.0) end,
  draw = function(p)
    p:box(0, 0, 0, p.W - 1, 0, p.H - 1, I.frame)
    p:box(1, 0, 1, p.W - 2, 0, p.H - 2, I.mirror)
  end,
})

-- ----------------------------------------------------------- kitchen
piece("range", {
  solid = true,
  size = function() return 10, 5, 7 end,
  draw = function(p)
    local W = p.W
    p:box(0, 0, 0, W - 1, 4, 5, I.iron)
    p:box(1, 0, 1, 4, 0, 4, I.black)                                  -- oven doors
    p:box(6, 0, 1, W - 2, 0, 4, I.black)
    p:box(1, 0, 4, 4, 0, 4, I.brass)
    p:box(6, 0, 4, W - 2, 0, 4, I.brass)
    p:box(0, 0, 5, W - 1, 4, 5, I.chrome)
    p:box(1, 1, 6, 3, 3, 6, I.copper)                                 -- a pan and the kettle
    p:box(6, 1, 6, 7, 2, 6, I.copper)
    p:set(6, 1, 7 - 1, I.copper)
  end,
})

piece("hood", { -- the chimney hood over the range, up to the ceiling (o.h)
  size = function(o) return 12, 4, vox(o.h or 1.2) end,
  draw = function(p)
    local H = p.H
    p:box(0, 0, 0, p.W - 1, 3, 1, I.copper)
    p:box(2, 1, 2, p.W - 3, 3, H - 1, I.stone)
  end,
})

piece("counter", {
  solid = true,
  size = function(o) return vox(o.w or 2), 5, 7 end,
  draw = function(p, o)
    local W = p.W
    p:box(0, 0, 0, W - 1, 4, 5, I.wood)
    p:box(0, 0, 0, W - 1, 0, 0, I.wood_dark)
    for a = 1, W - 2, 4 do
      p:box(a, 0, 1, math.min(W - 2, a + 2), 0, 4, I.wood_light)
      p:set(a + 1, 0, 4, I.brass)
    end
    p:box(0, 0, 6, W - 1, 4, 6, col(o.top, I.stone))
    if o.sink then
      local s = math.floor(W / 2) - 2
      p:box(s, 0, 5, s + 3, 3, 6, I.porcelain)
      p:box(s + 1, 1, 6, s + 2, 2, 6, I.water)
      p:box(s + 1, 4, 7, s + 2, 4, 8, I.brass)
    end
    if o.things then
      p:box(1, 2, 7, 2, 3, 8, I.pot)                                  -- a crock
      p:box(W - 4, 1, 7, W - 2, 3, 7, I.wood_light)                   -- a board
      p:box(W - 3, 2, 8, W - 3, 2, 8, I.red)                          -- an apple
    end
  end,
})

piece("pot_rack", { -- hangs from the ceiling: o.drop voxels long
  size = function() return 12, 4, 6 end,
  draw = function(p)
    p:box(0, 1, 5, 0, 2, 5, I.iron)
    p:box(11, 1, 5, 11, 2, 5, I.iron)
    p:box(0, 1, 4, 11, 2, 4, I.iron)
    for a = 1, 10, 3 do p:box(a, 1, 1, a + 1, 2, 3, I.copper) end
  end,
})

-- ------------------------------------------------------ tables, seats
piece("table", {
  solid = true,
  size = function(o) return vox(o.w or 1.5), vox(o.d or 0.9), o.low and 3 or 6 end,
  draw = function(p, o)
    local W, D, H = p.W, p.D, p.H
    p:box(0, 0, H - 1, W - 1, D - 1, H - 1, col(o.top, I.wood))
    for _, a in ipairs({ 0, W - 1 }) do
      for _, b in ipairs({ 0, D - 1 }) do p:box(a, b, 0, a, b, H - 2, I.wood_dark) end
    end
    if o.cloth then p:box(1, 1, H - 1, W - 2, D - 2, H - 1, col(o.cloth)) end
    if o.vase then
      local a, b = math.floor(W / 2), math.floor(D / 2)
      p:box(a, b, H, a, b, H + 1, I.porcelain)
      p:set(a, b, H + 2, I.flower)
    end
    if o.candles then
      for a = 2, W - 3, math.max(3, math.floor(W / 3)) do
        p:set(a, math.floor(D / 2), H, I.brass)
        p:set(a, math.floor(D / 2), H + 1, I.glow2)
      end
    end
  end,
})

piece("chair", {
  solid = true,
  size = function() return 4, 4, 8 end,
  draw = function(p, o)
    for _, a in ipairs({ 0, 3 }) do
      for _, b in ipairs({ 0, 3 }) do p:box(a, b, 0, a, b, 2, I.wood_dark) end
    end
    p:box(0, 0, 3, 3, 3, 3, col(o.seat, I.wood))
    p:box(0, 3, 4, 3, 3, 7, I.wood)
    p:box(1, 3, 5, 2, 3, 6, I.wood_light)
  end,
})

piece("stool", {
  solid = true,
  size = function() return 3, 3, 4 end,
  draw = function(p)
    p:box(0, 0, 0, 0, 0, 2, I.wood_dark)
    p:box(2, 2, 0, 2, 2, 2, I.wood_dark)
    p:box(0, 0, 3, 2, 2, 3, I.wood)
  end,
})

piece("sofa", {
  solid = true,
  size = function(o) return vox(o.w or 2.0), 7, 6 end,
  draw = function(p, o)
    local W = p.W
    local f, f2 = col(o.fabric, I.fabric), col(o.fabric2, I.fabric2)
    p:box(0, 0, 0, W - 1, 6, 2, f)                                    -- base
    p:box(0, 5, 3, W - 1, 6, 5, f)                                    -- back
    p:box(0, 0, 3, 1, 6, 4, f)                                        -- arms
    p:box(W - 2, 0, 3, W - 1, 6, 4, f)
    for a = 2, W - 3, 5 do p:box(a, 1, 3, math.min(W - 3, a + 3), 4, 3, f2) end -- cushions
    p:set(2, 4, 4, I.fabric3)
    p:set(W - 3, 4, 4, I.fabric3)
  end,
})

piece("armchair", {
  solid = true,
  size = function() return 7, 7, 7 end,
  draw = function(p, o)
    local f = col(o.fabric, I.fabric)
    p:box(0, 0, 0, 6, 6, 2, f)
    p:box(0, 5, 3, 6, 6, 6, f)
    p:box(0, 0, 3, 1, 6, 4, f)
    p:box(5, 0, 3, 6, 6, 4, f)
    p:box(2, 1, 3, 4, 4, 3, col(o.fabric2, I.fabric2))
  end,
})

piece("wicker_chair", {
  solid = true,
  size = function() return 6, 6, 9 end,
  draw = function(p)
    p:box(0, 0, 0, 5, 5, 2, I.wicker)
    p:box(0, 4, 3, 5, 5, 8, I.wicker)
    p:box(0, 0, 3, 0, 5, 4, I.wicker)
    p:box(5, 0, 3, 5, 5, 4, I.wicker)
    p:box(1, 1, 3, 4, 3, 3, I.fabric3)
  end,
})

piece("bench", {
  solid = true,
  size = function(o) return vox(o.w or 1.2), 3, 4 end,
  draw = function(p)
    local W = p.W
    p:box(0, 0, 3, W - 1, 2, 3, I.wood)
    p:box(0, 0, 0, 0, 2, 2, I.wood_dark)
    p:box(W - 1, 0, 0, W - 1, 2, 2, I.wood_dark)
  end,
})

piece("desk", {
  solid = true,
  size = function(o) return vox(o.w or 1.25), 5, 6 end,
  draw = function(p)
    local W = p.W
    p:box(0, 0, 5, W - 1, 4, 5, I.wood_dark)
    p:box(0, 0, 0, 2, 4, 4, I.wood)                                   -- drawers
    p:box(W - 3, 0, 0, W - 1, 4, 4, I.wood)
    p:box(0, 0, 1, 2, 0, 1, I.wood_light)
    p:box(0, 0, 3, 2, 0, 3, I.wood_light)
    p:box(W - 3, 0, 2, W - 1, 0, 2, I.wood_light)
    p:box(3, 1, 6, 5, 2, 6, I.paper)                                  -- papers, an open book, a lamp
    p:box(7, 1, 6, 8, 2, 6, I.book + 2)
    p:box(W - 3, 3, 6, W - 3, 3, 7, I.brass)
    p:box(W - 4, 2, 8, W - 2, 3, 8, I.green)
  end,
})

-- --------------------------------------------------------- the hearth
piece("fireplace", { -- stone chimney breast up to the ceiling (o.h metres)
  solid = true,
  size = function(o) return 16, 4, vox(o.h or 3) end,
  draw = function(p)
    local W, H = p.W, p.H
    p:box(0, 1, 0, W - 1, 3, H - 1, I.stone)
    for c = 1, H - 1, 3 do                                            -- stone courses
      p:box(0, 1, c, W - 1, 1, c, I.stone2)
    end
    p:box(0, 0, 0, W - 1, 0, 0, I.stone2)                             -- hearth
    p:box(4, 1, 1, W - 5, 2, 6, 0)                                    -- firebox
    p:box(4, 3, 1, W - 5, 3, 6, I.shadow)
    p:box(5, 2, 1, W - 6, 2, 1, I.wood_dark)                          -- logs and fire
    p:box(6, 2, 2, W - 7, 2, 2, I.ember)
    p:box(6, 2, 3, W - 7, 2, 3, I.fire)
    p:box(7, 2, 4, W - 8, 2, 4, I.fire2)
    p:box(0, 0, 7, W - 1, 3, 7, I.wood)                               -- mantel
    p:box(3, 1, 8, 3, 1, 9, I.brass)                                  -- candlesticks and a clock
    p:set(3, 1, 10, I.glow2)
    p:box(W - 4, 1, 8, W - 4, 1, 9, I.brass)
    p:set(W - 4, 1, 10, I.glow2)
    p:box(7, 1, 8, 8, 2, 10, I.wood_dark)
    p:box(7, 1, 9, 8, 1, 9, I.white)
  end,
})

piece("piano", {
  solid = true,
  size = function() return 12, 5, 10 end,
  draw = function(p)
    p:box(0, 2, 0, 11, 4, 9, I.wood_dark)
    p:box(0, 0, 0, 0, 2, 4, I.wood_dark)
    p:box(11, 0, 0, 11, 2, 4, I.wood_dark)
    p:box(1, 0, 4, 10, 1, 4, I.white)                                 -- keys
    for a = 1, 10, 2 do p:set(a, 1, 4, I.black) end
    p:box(1, 1, 5, 10, 1, 5, I.wood_dark)
    p:box(3, 2, 6, 8, 2, 8, I.paper)                                  -- music
  end,
})

-- ------------------------------------------------------------ lights
piece("floor_lamp", {
  solid = true,
  size = function() return 3, 3, 13 end,
  draw = function(p)
    p:box(0, 0, 0, 2, 2, 0, I.brass)
    p:box(1, 1, 1, 1, 1, 9, I.brass)
    p:box(0, 0, 10, 2, 2, 12, I.glow)
  end,
})

piece("chandelier", { -- drawn hanging from the ceiling: place it with o.y = ceiling height
  size = function() return 9, 9, 8 end,
  draw = function(p)
    p:box(4, 4, 4, 4, 4, 7, I.brass)
    p:box(1, 1, 3, 7, 7, 3, I.brass)
    p:box(2, 2, 3, 6, 6, 3, 0)
    for _, ab in ipairs({ { 1, 1 }, { 7, 1 }, { 1, 7 }, { 7, 7 }, { 4, 1 }, { 4, 7 }, { 1, 4 }, { 7, 4 } }) do
      p:set(ab[1], ab[2], 4, I.glow2)
    end
    p:box(3, 3, 1, 5, 5, 2, I.glow)
  end,
})

piece("pendant", {
  size = function() return 3, 3, 5 end,
  draw = function(p)
    p:box(1, 1, 2, 1, 1, 4, I.iron)
    p:box(0, 0, 0, 2, 2, 1, I.glow)
  end,
})

piece("sconce", { -- a wall lamp (o.y metres up)
  size = function() return 2, 2, 3 end,
  draw = function(p)
    p:box(0, 1, 0, 1, 1, 0, I.brass)
    p:box(0, 0, 1, 1, 1, 2, I.glow)
  end,
})

-- ------------------------------------------------------------ things
piece("plant", {
  solid = true,
  size = function(o)
    if o.big then return 8, 8, 22 end
    return o.small and 3 or 5, o.small and 3 or 5, o.small and 6 or 12
  end,
  draw = function(p, o, rng)
    local W, H = p.W, p.H
    local m = W / 2
    local pot = o.small and 2 or (o.big and 5 or 3)
    p:box(0, 0, 0, W - 1, W - 1, pot - 1, I.pot)
    p:box(1, 1, pot - 1, W - 2, W - 2, pot - 1, I.soil)
    p:box(math.floor(m), math.floor(m), pot, math.floor(m), math.floor(m), H - 3, I.wood_dark)
    local leaves = { I.leaf, I.leaf2, I.leaf3 }
    for k = 1, o.small and 2 or (o.big and 9 or 5) do
      local cc = pot + 2 + rng:next() * (H - pot - 4)
      p:ellipsoid(m + rng:next() * 2 - 1, m + rng:next() * 2 - 1, cc, W / 2, W / 2, 1.6, leaves[rng:int(1, 3)])
    end
    if o.flowers then
      p:set(math.floor(m), math.floor(m), H - 1, I.flower)
      if o.big then
        for k = 1, 6 do p:set(rng:int(1, W - 2), rng:int(1, W - 2), rng:int(pot + 6, H - 2), k % 2 == 0 and I.flower or I.flower2) end
      end
    end
  end,
})

piece("painting", { -- on a wall; o.y metres up
  size = function(o) return vox(o.w or 0.75), 1, vox(o.h or 0.625) end,
  draw = function(p, o, rng)
    local W, H = p.W, p.H
    p:box(0, 0, 0, W - 1, 0, H - 1, I.frame)
    local sky, land = rng:next() < 0.5 and I.art or I.art3, rng:next() < 0.5 and I.art2 or I.art4
    local split = rng:int(1, H - 2)
    p:box(1, 0, 1, W - 2, 0, split, land)
    p:box(1, 0, split + 1, W - 2, 0, H - 2, sky)
    if W > 4 and H > 4 then
      local a = rng:int(2, W - 3)
      p:set(a, 0, rng:int(math.min(split + 1, H - 2), H - 2), I.glow2)      -- a sun or a moon
      p:box(rng:int(1, W - 3), 0, 1, rng:int(2, W - 2), 0, math.min(split, 1 + rng:int(0, 2)), I.leaf2)
    end
  end,
})

piece("clock", { -- a long-case clock
  solid = true,
  size = function() return 4, 3, 17 end,
  draw = function(p)
    p:box(0, 0, 0, 3, 2, 16, I.wood_dark)
    p:box(1, 0, 12, 2, 0, 14, I.white)
    p:set(1, 0, 13, I.black)
    p:box(1, 0, 3, 2, 0, 9, I.wood)
    p:box(1, 0, 4, 2, 0, 4, I.brass)
    p:box(0, 0, 16, 3, 2, 16, I.brass)
  end,
})

piece("globe", {
  solid = true,
  size = function() return 5, 5, 10 end,
  draw = function(p)
    p:box(1, 1, 0, 3, 3, 0, I.wood_dark)
    p:box(2, 2, 1, 2, 2, 4, I.wood_dark)
    p:ellipsoid(2.5, 2.5, 7, 2.4, 2.4, 2.4, I.blue)
    p:ellipsoid(2.0, 2.0, 7.6, 1.3, 1.2, 1.2, I.green)
    p:box(0, 2, 7, 4, 2, 7, I.brass)
  end,
})

piece("coat_rack", {
  solid = true,
  size = function() return 4, 4, 14 end,
  draw = function(p)
    p:box(0, 0, 0, 3, 3, 0, I.wood_dark)
    p:box(1, 1, 1, 2, 2, 13, I.wood_dark)
    p:box(0, 1, 9, 0, 2, 12, I.fabric)                                -- coats and a scarf
    p:box(3, 1, 8, 3, 2, 12, I.fabric3)
    p:box(1, 3, 10, 2, 3, 12, I.red)
  end,
})

piece("umbrella_stand", {
  solid = true,
  size = function() return 2, 2, 7 end,
  draw = function(p)
    p:box(0, 0, 0, 1, 1, 3, I.copper)
    p:box(0, 0, 4, 0, 0, 6, I.blue)
    p:box(1, 1, 4, 1, 1, 6, I.red)
  end,
})

piece("rug", { -- on the floor (not solid): o.w, o.d metres; o.pattern
  size = function(o) return vox(o.w or 2), vox(o.d or 1.5), 1 end,
  draw = function(p, o)
    local W, D = p.W, p.D
    p:box(0, 0, 0, W - 1, D - 1, 0, col(o.c1, I.rug))
    p:box(1, 1, 0, W - 2, D - 2, 0, col(o.c2, I.rug2))
    p:box(2, 2, 0, W - 3, D - 3, 0, col(o.c1, I.rug))
    if W > 8 and D > 8 then
      p:box(3, 3, 0, W - 4, D - 4, 0, col(o.c3, I.rug3))
      local cw, cd = math.floor(W / 2), math.floor(D / 2)
      for k = 0, math.min(cw, cd) - 5, 2 do
        p:box(cw - k - 1, cd - 1, 0, cw + k, cd, 0, col(o.c2, I.rug2))
        p:box(cw - 1, cd - k - 1, 0, cw, cd + k, 0, col(o.c2, I.rug2))
      end
    end
  end,
})

piece("sign", { -- a board on a post, in the colours of a wing
  solid = true,
  size = function() return 8, 2, 12 end,
  draw = function(p)
    p:box(3, 1, 0, 4, 1, 6, I.wood_dark)
    p:box(0, 0, 7, 7, 1, 11, I.accent)
    p:box(1, 0, 8, 6, 0, 10, I.cream)
    for a = 1, 6, 2 do p:set(a, 0, 9, I.wood_dark) end
  end,
})

piece("fountain", { -- a round stone basin with a spout in the middle
  solid = true,
  size = function() return 16, 16, 12 end,
  draw = function(p)
    p:cylinder(8, 8, 0, 3, 8, I.stone)
    p:cylinder(8, 8, 1, 3, 7, I.water)
    p:cylinder(8, 8, 3, 3, 7, 0)
    p:cylinder(8, 8, 0, 8, 1.5, I.stone2)
    p:cylinder(8, 8, 9, 9, 3, I.stone)
    p:cylinder(8, 8, 10, 11, 1, I.water)
  end,
})

piece("bust", { -- a stone head on a plinth
  solid = true,
  size = function() return 4, 4, 13 end,
  draw = function(p)
    p:box(0, 0, 0, 3, 3, 7, I.stone)
    p:box(0, 0, 7, 3, 3, 7, I.stone2)
    p:box(1, 1, 8, 2, 2, 9, I.white)
    p:ellipsoid(2, 2, 11, 1.5, 1.6, 2.0, I.white)
  end,
})

piece("cabinet", { -- a glass-fronted cabinet of curiosities
  solid = true,
  size = function(o) return vox(o.w or 1.0), 4, 16 end,
  draw = function(p, o, rng)
    local W = p.W
    p:box(0, 0, 0, W - 1, 3, 15, I.wood_dark)
    p:box(1, 0, 1, W - 2, 2, 14, 0)
    p:box(1, 3, 1, W - 2, 3, 14, I.fabric3)
    for c = 4, 13, 4 do p:box(1, 0, c, W - 2, 2, c, I.wood) end
    local things = { I.brass, I.gold, I.copper, I.porcelain, I.glass, I.red, I.green }
    for c = 1, 13, 4 do
      for a = 1, W - 2, 2 do
        if rng:next() < 0.7 then p:box(a, 1, c, a, 1, c + rng:int(0, 2), things[rng:int(1, #things)]) end
      end
    end
  end,
})

-- ----------------------------------------------------------- the cab
piece("dashboard", { -- the full width of the cab; the radio in the middle
  solid = true,
  size = function(o) return vox(o.w or 4.5), 5, 8 end,
  draw = function(p, o)
    local W = p.W
    p:box(0, 1, 0, W - 1, 4, 5, I.dash)
    p:box(0, 0, 0, W - 1, 0, 3, I.dash)
    p:box(0, 0, 4, W - 1, 1, 5, I.wood)                               -- a wooden fascia
    p:box(0, 1, 6, W - 1, 4, 6, I.rubber)                             -- the padded top, stepping back
    p:box(0, 3, 7, W - 1, 4, 7, I.rubber)
    local mid = math.floor(W / 2)
    -- the radio: a glowing dial, brass knobs and a grille
    p:box(mid - 3, 0, 2, mid + 2, 0, 5, I.wood_dark)
    p:box(mid - 2, 0, 4, mid + 1, 0, 5, I.glow)
    p:set(mid - 1, 0, 4, I.red)
    p:set(mid - 3, 0, 3, I.brass)
    p:set(mid + 2, 0, 3, I.brass)
    p:box(mid - 2, 0, 2, mid + 1, 0, 2, I.iron)
    -- the gauges in front of the driver
    local d = o.driver or (W - 8)
    p:box(d - 2, 0, 4, d + 1, 0, 5, I.black)
    p:set(d - 1, 0, 5, I.glow2)
    p:set(d + 1, 0, 5, I.glow2)
    -- a little plant and a photograph on the dashboard
    p:set(mid + 6, 3, 8, I.pot)
    p:set(mid + 6, 3, 9, I.leaf)
    p:box(mid - 7, 4, 8, mid - 6, 4, 9, I.white)
  end,
})

piece("steering_wheel", {
  size = function() return 6, 3, 6 end,
  draw = function(p)
    p:box(0, 1, 2, 0, 1, 3, I.black)                                   -- a round-ish rim
    p:box(5, 1, 2, 5, 1, 3, I.black)
    p:box(2, 1, 0, 3, 1, 0, I.black)
    p:box(2, 1, 5, 3, 1, 5, I.black)
    p:set(1, 1, 1, I.black)
    p:set(4, 1, 1, I.black)
    p:set(1, 1, 4, I.black)
    p:set(4, 1, 4, I.black)
    p:box(2, 1, 2, 3, 1, 3, I.brass)                                   -- the hub
    p:box(2, 2, 2, 3, 2, 2, I.iron)                                    -- the column
  end,
})

piece("cab_seat", {
  solid = true,
  size = function() return 6, 6, 10 end,
  draw = function(p, o)
    local f = col(o.fabric, I.seat)
    p:box(1, 1, 0, 4, 4, 1, I.iron)
    p:box(0, 0, 2, 5, 4, 3, f)
    p:box(0, 4, 4, 5, 5, 8, f)
    p:box(1, 5, 9, 4, 5, 9, f)
    p:box(1, 0, 3, 4, 3, 3, I.fabric2)
    if o.atlas then
      p:box(1, 1, 4, 4, 2, 4, I.blue)                                 -- the road atlas
      p:box(1, 1, 4, 1, 2, 4, I.gold)
    end
  end,
})

piece("curtain", { -- either side of a window (o.w metres between them)
  size = function(o) return vox(o.w or 1.5) + 4, 1, vox(o.h or 1.2) + 2 end,
  draw = function(p, o)
    local W, H = p.W, p.H
    p:box(0, 0, H - 1, W - 1, 0, H - 1, I.brass)
    p:box(0, 0, 0, 1, 0, H - 2, col(o.fabric, I.fabric))
    p:box(W - 2, 0, 0, W - 1, 0, H - 2, col(o.fabric, I.fabric))
  end,
})

-- ------------------------------------------------------ placement
-- Draws item `it` into canvas `cv` of `room`: it.piece, centre it.x/it.z
-- (metres from the room's corner) or against a wall (it.wall = "n", "s",
-- "e" or "w" and it.at along it), facing it.face (default: away from the
-- wall), it.y metres above the floor (it.ceiling: hanging from it). Returns
-- the collider rectangle {x0, z0, x1, z1, h} in room metres when solid.
local FACING = { n = "-z", s = "+z", e = "-x", w = "+x" }
function F.place(cv, room, it, seed)
  local def = F.PIECES[it.piece]
  assert(def, "unknown piece " .. tostring(it.piece))
  local W, D, H = def.size(it)
  local face = it.face or FACING[it.wall] or "-z"
  local fu, fv = W, D
  if face == "+x" or face == "-x" then fu, fv = D, W end
  local x, z = it.x, it.z
  local wall = room.wall_t or 0.25
  local rw, rd = room.x1 - room.x0, room.z1 - room.z0
  if it.wall == "n" then x, z = it.at, rd - wall - fv * S / 2 - (it.gap or 0)
  elseif it.wall == "s" then x, z = it.at, wall + fv * S / 2 + (it.gap or 0)
  elseif it.wall == "e" then x, z = rw - wall - fu * S / 2 - (it.gap or 0), it.at
  elseif it.wall == "w" then x, z = wall + fu * S / 2 + (it.gap or 0), it.at end
  local u0 = math.floor(x / S - fu / 2 + 0.5)
  local v0 = math.floor(z / S - fv / 2 + 0.5)
  local h0 = 1 + math.floor((it.y or 0) / S + 0.5)
  if it.ceiling then h0 = cv.H - 1 - H end
  local p = cv:pen(u0, v0, h0, W, D, face)
  p.H = H
  def.draw(p, it, mvl.rng(mvl.hash(seed or 1, it.piece, u0, v0, h0)))
  if def.solid and not it.passable then
    return { x0 = u0 * S, z0 = v0 * S, x1 = (u0 + fu) * S, z1 = (v0 + fv) * S,
             y = (h0 - 1) * S, h = H * S }
  end
end

return F
