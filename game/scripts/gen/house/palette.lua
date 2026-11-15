-- Multiversal Van Life - the house's palette (MIT License).
--
-- Every room grid uses the same palette indices; a room's style changes the
-- colours behind them (floors, walls, trims, fabrics), the rest (woods,
-- brass, porcelain, books, plants, glowing lamps) keep their defaults.
local PAL = {}

local I = {
  floor = 1, floor2 = 2, floor3 = 3,
  wall = 4, wall2 = 5, wall_dark = 6, trim = 7, ceiling = 8, beam = 9, dado = 10, dado2 = 11,
  wood = 12, wood_dark = 13, wood_light = 14,
  fabric = 15, fabric2 = 16, fabric3 = 17,
  rug = 18, rug2 = 19, rug3 = 20,
  brass = 21, iron = 22, copper = 23, porcelain = 24, white = 25, mirror = 26, glass = 27,
  glow = 28, glow2 = 29, pane = 30, fire = 31, fire2 = 32, ember = 33,
  leaf = 34, leaf2 = 35, leaf3 = 36, pot = 37, soil = 38, flower = 39, flower2 = 40,
  stone = 41, stone2 = 42, shadow = 43, paper = 44, tile = 45, tile2 = 46,
  frame = 47, art = 48, art2 = 49, art3 = 50, art4 = 51,
  dash = 52, seat = 53, rubber = 54, chrome = 55, red = 56, green = 57, blue = 58, gold = 59, wicker = 60,
  cream = 61, black = 62, water = 63, accent = 64,
  book = 65, -- 65..76: book spines
}
PAL.I = I
PAL.BOOKS = 12

local DEFAULT = {
  floor = { 150, 104, 64 }, floor2 = { 136, 92, 56 }, floor3 = { 112, 76, 46 },
  wall = { 196, 176, 140 }, wall2 = { 180, 158, 122 }, wall_dark = { 90, 76, 60 }, trim = { 236, 226, 204 },
  ceiling = { 232, 222, 200 }, beam = { 104, 70, 44 }, dado = { 120, 84, 54 }, dado2 = { 104, 72, 46 },
  wood = { 132, 88, 52 }, wood_dark = { 84, 54, 34 }, wood_light = { 186, 142, 92 },
  fabric = { 160, 70, 60 }, fabric2 = { 196, 150, 90 }, fabric3 = { 70, 110, 110 },
  rug = { 150, 46, 48 }, rug2 = { 210, 160, 90 }, rug3 = { 40, 96, 104 },
  brass = { 214, 170, 86 }, iron = { 46, 44, 48 }, copper = { 196, 112, 64 }, porcelain = { 236, 236, 228 },
  white = { 248, 246, 240 }, mirror = { 170, 196, 206 }, glass = { 150, 190, 200 },
  glow = { 255, 214, 140 }, glow2 = { 255, 240, 200 }, pane = { 226, 236, 214 }, fire = { 255, 150, 50 },
  fire2 = { 255, 220, 110 }, ember = { 190, 60, 30 },
  leaf = { 70, 140, 70 }, leaf2 = { 48, 110, 56 }, leaf3 = { 110, 168, 80 }, pot = { 176, 96, 64 },
  soil = { 70, 50, 36 }, flower = { 230, 110, 140 }, flower2 = { 250, 210, 90 },
  stone = { 150, 144, 136 }, stone2 = { 112, 106, 100 }, shadow = { 34, 30, 30 }, paper = { 240, 232, 210 },
  tile = { 236, 236, 230 }, tile2 = { 60, 90, 110 },
  frame = { 180, 140, 70 }, art = { 90, 130, 170 }, art2 = { 110, 150, 90 }, art3 = { 220, 190, 130 },
  art4 = { 170, 90, 80 },
  dash = { 110, 74, 46 }, seat = { 120, 60, 44 }, rubber = { 50, 50, 54 }, chrome = { 200, 204, 210 },
  red = { 200, 60, 50 }, green = { 70, 140, 80 }, blue = { 60, 100, 170 }, gold = { 230, 190, 80 },
  wicker = { 200, 160, 100 }, cream = { 238, 224, 190 }, black = { 26, 24, 26 }, water = { 120, 180, 210 },
  accent = { 200, 160, 60 },
}
local BOOK_COLORS = { { 150, 40, 40 }, { 50, 80, 140 }, { 50, 110, 70 }, { 200, 160, 60 }, { 110, 60, 120 },
                      { 220, 210, 190 }, { 120, 70, 40 }, { 40, 40, 50 }, { 170, 90, 50 }, { 80, 130, 140 },
                      { 190, 110, 120 }, { 140, 140, 80 } }

-- Sets the canvas's palette: defaults, then the style's colours.
function PAL.apply(cv, style)
  for name, c in pairs(DEFAULT) do cv:color(I[name], (style and style[name]) or c) end
  for i, c in ipairs(BOOK_COLORS) do cv:color(I.book + i - 1, c) end
end

PAL.DEFAULT = DEFAULT
return PAL
