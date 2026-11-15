-- Multiversal Van Life - the plan of the house inside the van (MIT License).
--
-- Rooms are rectangles in pocket metres (+X the van's front, +Z its left,
-- y up from the ground floor) with a level `y`, a ceiling height `h`, a
-- style, doorways (`side` "n" = +Z, "s", "e" = +X, "w"; `at` along the wall
-- in pocket metres), windows (`portal` = the van window index they look out
-- of; others are frosted panes), stairs, holes and furniture (`items`, see
-- gen/house/furniture.lua, positions in pocket metres). The core is one
-- 32 x 32 m block: the cab at the front, the hall, the cross gallery, the
-- library, the kitchen, the living room, the conservatory with the garden
-- door at the back and, upstairs, the landing, the bedroom and the bathroom.
-- Beyond it the house goes on in generated blocks (gen/house/blocks.lua).
local plan = { BLOCK = 32, LEVEL = 3.625 }

local STYLES = {
  cab = { floor = "mat", wall = "van", rail = false,
          colors = { floor = { 66, 62, 64 }, floor2 = { 50, 48, 52 }, wall = { 228, 214, 184 }, wall2 = { 206, 190, 158 },
                     wall_dark = { 120, 110, 90 }, trim = { 150, 108, 66 }, ceiling = { 216, 204, 176 },
                     fabric = { 190, 120, 60 } } },
  hall = { floor = "tiles", wall = "stripes", dado = true,
           colors = { floor = { 222, 212, 192 }, floor2 = { 128, 62, 52 }, wall = { 98, 130, 106 }, wall2 = { 86, 116, 94 },
                      dado = { 112, 78, 50 }, dado2 = { 94, 64, 42 } } },
  gallery = { floor = "boards", boards = "z", wall = "panels", dado = true,
              colors = { wall = { 150, 62, 58 }, wall2 = { 128, 52, 50 }, floor = { 120, 80, 50 }, floor2 = { 108, 70, 44 },
                         rug = { 60, 50, 90 }, rug2 = { 200, 160, 80 }, rug3 = { 120, 40, 50 } } },
  library = { floor = "boards", wall = "panels", beams = true,
              colors = { wall = { 66, 88, 74 }, wall2 = { 56, 76, 64 }, floor = { 116, 76, 46 }, floor2 = { 102, 66, 40 },
                         ceiling = { 210, 196, 164 }, fabric = { 120, 50, 44 }, fabric2 = { 160, 70, 60 },
                         rug = { 110, 36, 40 }, rug2 = { 196, 150, 80 }, rug3 = { 36, 70, 80 } } },
  kitchen = { floor = "flags", wall = "plain", beams = true, rail = false,
              colors = { floor = { 178, 162, 140 }, floor2 = { 160, 146, 126 }, floor3 = { 118, 108, 94 },
                         wall = { 238, 226, 196 }, ceiling = { 236, 228, 206 }, fabric = { 180, 70, 60 },
                         rug = { 160, 60, 50 }, rug2 = { 230, 200, 140 }, rug3 = { 70, 110, 90 } } },
  living = { floor = "boards", wall = "stripes", dado = true,
             colors = { wall = { 206, 172, 120 }, wall2 = { 192, 156, 106 }, dado = { 104, 70, 46 }, dado2 = { 88, 58, 38 },
                        fabric = { 150, 64, 56 }, fabric2 = { 206, 168, 110 }, fabric3 = { 60, 104, 100 } } },
  conservatory = { floor = "tiles", wall = "plain", glass = { "w", "s" }, glass_roof = true, rail = false,
                   colors = { floor = { 206, 196, 176 }, floor2 = { 96, 126, 96 }, wall = { 232, 228, 216 },
                              dado = { 120, 118, 108 }, pane = { 214, 236, 222 } } },
  landing = { floor = "carpet", wall = "stripes", dado = true,
              colors = { floor = { 124, 52, 62 }, floor2 = { 156, 124, 64 }, wall = { 204, 194, 172 }, wall2 = { 188, 178, 156 } } },
  bedroom = { floor = "boards", wall = "stripes",
              colors = { wall = { 168, 180, 204 }, wall2 = { 154, 168, 192 }, fabric = { 84, 104, 168 }, fabric2 = { 222, 202, 160 },
                         rug = { 70, 80, 140 }, rug2 = { 220, 210, 180 }, rug3 = { 150, 90, 110 } } },
  bathroom = { floor = "tiles", wall = "tiles", rail = false,
               colors = { floor = { 240, 240, 236 }, floor2 = { 44, 62, 72 }, wall = { 226, 236, 232 }, wall2 = { 192, 208, 206 },
                          tile2 = { 60, 110, 120 }, rug = { 90, 150, 160 }, rug2 = { 236, 236, 230 } } },
}
plan.STYLES = STYLES

local L = plan.LEVEL
local STAIRS = { x0 = 3.5, x1 = 9.5, z0 = -4.75, z1 = -3.25, y = 0, rise = L, open = "n", steps = 16 }
plan.STAIRS = STAIRS

local CORE = {
  -- ----------------------------------------------------------- the cab
  { id = "cab", kind = "cab", x0 = 12, x1 = 16, z0 = -2.5, z1 = 2.5, y = 0, h = 2.625, style = STYLES.cab,
    light = { 1, 0.97, 0.92 },
    doors = { { side = "w", at = 0, w = 1.75, h = 2.125 } },
    windows = {
      { side = "e", at = 0, y = 1.625, w = 2.75, h = 0.875, portal = 3 },
      { side = "n", at = 14, y = 1.5625, w = 1.25, h = 0.75, portal = 2 },
      { side = "s", at = 14, y = 1.5625, w = 1.25, h = 0.75, portal = 4 },
    },
    items = {
      { piece = "dashboard", wall = "e", at = 0, w = 4.5, driver = 9 },
      { piece = "steering_wheel", x = 14.875, z = 1.0, face = "-x", y = 0.75 },
      { piece = "cab_seat", x = 13.375, z = 1.0, face = "+x" },
      { piece = "cab_seat", x = 13.375, z = -1.0, face = "+x", atlas = true },
      { piece = "curtain", wall = "n", at = 14, w = 1.25, h = 0.75, y = 1.0625 },
      { piece = "curtain", wall = "s", at = 14, w = 1.25, h = 0.75, y = 1.0625 },
    } },
  -- ---------------------------------------------------------- the hall
  { id = "hall", kind = "hall", x0 = 1.5, x1 = 12, z0 = -5, z1 = 5, y = 0, h = 3.375, style = STYLES.hall,
    light = { 1, 0.95, 0.86 },
    doors = {
      { side = "e", at = 0, w = 1.75, h = 2.125 },
      { side = "e", at = 3.75, w = 1.25, h = 2.25, closed = true, outside = true },
      { side = "n", at = 6.5, w = 1.75, h = 2.375, shape = "arch" },
      { side = "s", at = 10.75, w = 1.5, h = 2.25 },
      { side = "w", at = 0, w = 2.25, h = 2.75, shape = "arch" },
    },
    windows = { { side = "e", at = -3.75, y = 1.625, w = 1.0, h = 1.25, portal = 1 } },
    stairs = { STAIRS },
    ceiling_holes = { { x0 = STAIRS.x0, x1 = STAIRS.x1, z0 = STAIRS.z0, z1 = STAIRS.z1 } },
    items = {
      { piece = "rug", x = 6.75, z = 0.75, w = 7.0, d = 2.0 },
      { piece = "coat_rack", wall = "n", at = 10.75 },
      { piece = "bench", wall = "n", at = 9.0, w = 1.5 },
      { piece = "umbrella_stand", wall = "e", at = 2.375 },
      { piece = "clock", wall = "w", at = 3.25 },
      { piece = "mirror", wall = "w", at = -2.75, y = 1.0, w = 0.75, h = 1.0 },
      { piece = "painting", wall = "n", at = 4.0, y = 1.375, w = 1.0, h = 0.75 },
      { piece = "painting", wall = "n", at = 2.375, y = 1.5, w = 0.5, h = 0.625 },
      { piece = "plant", x = 2.25, z = 4.25 },
      { piece = "plant", x = 11.25, z = -2.0, small = true, flowers = true },
      { piece = "sconce", wall = "w", at = 1.75, y = 1.75 },
      { piece = "sconce", wall = "w", at = -1.75, y = 1.75 },
      { piece = "chandelier", x = 6.5, z = 1.0, ceiling = true },
    } },
  -- ------------------------------------------------- the cross gallery
  { id = "gallery", kind = "gallery", x0 = -1.5, x1 = 1.5, z0 = -16, z1 = 16, y = 0, h = 3.375, style = STYLES.gallery,
    light = { 1, 0.93, 0.85 },
    doors = {
      { side = "e", at = 0, w = 2.25, h = 2.75, shape = "arch" },
      { side = "e", at = 10.5, w = 1.75, h = 2.375 },
      { side = "e", at = -10.5, w = 1.5, h = 2.25 },
      { side = "w", at = 8.75, w = 1.75, h = 2.375, shape = "arch" },
      { side = "w", at = -8.75, w = 2.0, h = 2.5, shape = "arch" },
      { side = "n", at = 0, w = 2.0, h = 2.5, shape = "arch", outer = true },
      { side = "s", at = 0, w = 2.0, h = 2.5, shape = "arch", outer = true },
    },
    items = {
      { piece = "rug", x = 0, z = 0, w = 1.5, d = 29.0 },
      { piece = "painting", wall = "w", at = 3.5, y = 1.375, w = 1.25, h = 1.0 },
      { piece = "painting", wall = "w", at = -3.5, y = 1.375, w = 1.25, h = 1.0 },
      { piece = "painting", wall = "w", at = 13.0, y = 1.5, w = 0.75, h = 0.875 },
      { piece = "painting", wall = "w", at = -13.0, y = 1.5, w = 0.75, h = 0.875 },
      { piece = "painting", wall = "e", at = 6.5, y = 1.375, w = 1.0, h = 0.75 },
      { piece = "painting", wall = "e", at = -6.5, y = 1.375, w = 1.0, h = 0.75 },
      { piece = "painting", wall = "e", at = 14.0, y = 1.5, w = 0.625, h = 0.75 },
      { piece = "painting", wall = "e", at = -14.0, y = 1.5, w = 0.625, h = 0.75 },
      { piece = "bust", wall = "w", at = 5.75 },
      { piece = "bust", wall = "w", at = -5.75 },
      { piece = "table", wall = "e", at = 3.5, w = 0.5, d = 0.875, vase = true, face = "-x" },
      { piece = "table", wall = "e", at = -3.5, w = 0.5, d = 0.875, vase = true, face = "-x" },
      { piece = "chair", wall = "w", at = 11.0, face = "+x" },
      { piece = "chair", wall = "w", at = -11.0, face = "+x" },
      { piece = "plant", x = 0, z = 15.25, small = true, flowers = true },
      { piece = "plant", x = 0, z = -15.25, small = true, flowers = true },
      { piece = "pendant", x = 0, z = 4.5, ceiling = true },
      { piece = "pendant", x = 0, z = -4.5, ceiling = true },
      { piece = "pendant", x = 0, z = 12.0, ceiling = true },
      { piece = "pendant", x = 0, z = -12.0, ceiling = true },
    } },
  -- ------------------------------------------------------- the library
  { id = "library", kind = "library", x0 = 1.5, x1 = 16, z0 = 5, z1 = 16, y = 0, h = 6.375, style = STYLES.library,
    light = { 1, 0.92, 0.8 },
    doors = {
      { side = "s", at = 6.5, w = 1.75, h = 2.375, shape = "arch" },
      { side = "w", at = 10.5, w = 1.75, h = 2.375 },
    },
    items = {
      { piece = "bookshelf", wall = "n", at = 8.75, w = 14.0, h = 6.0 },
      { piece = "bookshelf", wall = "e", at = 10.25, w = 10.0, h = 6.0 },
      { piece = "bookshelf", wall = "s", at = 3.625, w = 3.5, h = 6.0 },
      { piece = "bookshelf", wall = "s", at = 11.375, w = 7.5, h = 6.0 },
      { piece = "bookshelf", wall = "w", at = 7.375, w = 4.0, h = 6.0 },
      { piece = "bookshelf", wall = "w", at = 13.625, w = 4.0, h = 6.0 },
      { piece = "ladder", wall = "n", at = 11.5, h = 5.5, gap = 0.375 },
      { piece = "rug", x = 8.75, z = 10.5, w = 8.0, d = 6.0 },
      { piece = "table", x = 8.75, z = 10.5, w = 2.5, d = 1.25, candles = true },
      { piece = "chair", x = 8.0, z = 9.375, face = "+z" },
      { piece = "chair", x = 9.5, z = 9.375, face = "+z" },
      { piece = "chair", x = 8.0, z = 11.625, face = "-z" },
      { piece = "chair", x = 9.5, z = 11.625, face = "-z" },
      { piece = "armchair", x = 4.5, z = 12.75, face = "+x" },
      { piece = "armchair", x = 4.5, z = 8.25, face = "+x" },
      { piece = "floor_lamp", x = 3.875, z = 10.5 },
      { piece = "desk", x = 13.0, z = 13.5, face = "-z", w = 1.5 },
      { piece = "chair", x = 13.0, z = 14.25, face = "-z" },
      { piece = "globe", x = 13.5, z = 7.0 },
      { piece = "chandelier", x = 6.0, z = 10.5, ceiling = true },
      { piece = "chandelier", x = 11.5, z = 10.5, ceiling = true },
    } },
  -- ------------------------------------------------------- the kitchen
  { id = "kitchen", kind = "kitchen", x0 = 1.5, x1 = 16, z0 = -16, z1 = -5, y = 0, h = 3.375, style = STYLES.kitchen,
    light = { 1, 0.96, 0.88 },
    doors = {
      { side = "n", at = 10.75, w = 1.5, h = 2.25 },
      { side = "w", at = -10.5, w = 1.5, h = 2.25 },
    },
    windows = { { side = "e", at = -13.5, y = 1.75, w = 1.5, h = 1.0 } },
    items = {
      { piece = "range", wall = "e", at = -10.5 },
      { piece = "hood", wall = "e", at = -10.5, y = 1.5, h = 1.875 },
      { piece = "counter", wall = "e", at = -13.5, w = 4.5, sink = true },
      { piece = "counter", wall = "e", at = -7.5, w = 4.5, things = true },
      { piece = "welsh_dresser", wall = "s", at = 5.5, w = 2.0 },
      { piece = "pantry", wall = "s", at = 9.5, w = 2.0, h = 2.5 },
      { piece = "rug", x = 8.5, z = -10.5, w = 5.5, d = 3.5 },
      { piece = "table", x = 8.5, z = -10.5, w = 3.5, d = 1.25, cloth = "white", vase = true },
      { piece = "chair", x = 7.25, z = -9.375, face = "-z" },
      { piece = "chair", x = 8.5, z = -9.375, face = "-z" },
      { piece = "chair", x = 9.75, z = -9.375, face = "-z" },
      { piece = "chair", x = 7.25, z = -11.625, face = "+z" },
      { piece = "chair", x = 8.5, z = -11.625, face = "+z" },
      { piece = "chair", x = 9.75, z = -11.625, face = "+z" },
      { piece = "chair", x = 6.0, z = -10.5, face = "+x" },
      { piece = "chair", x = 11.0, z = -10.5, face = "-x" },
      { piece = "pot_rack", x = 8.5, z = -10.5, ceiling = true },
      { piece = "plant", x = 15.0, z = -6.0, small = true },
      { piece = "plant", x = 2.5, z = -15.0 },
      { piece = "pendant", x = 6.5, z = -10.5, ceiling = true },
      { piece = "pendant", x = 10.5, z = -10.5, ceiling = true },
    } },
  -- --------------------------------------------------- the living room
  { id = "living", kind = "living", x0 = -16, x1 = -1.5, z0 = 1.5, z1 = 16, y = 0, h = 3.375, style = STYLES.living,
    light = { 1, 0.92, 0.82 },
    doors = { { side = "e", at = 8.75, w = 1.75, h = 2.375, shape = "arch" } },
    windows = {
      { side = "n", at = -12.0, y = 1.625, w = 1.5, h = 1.5 },
      { side = "n", at = -6.5, y = 1.625, w = 1.5, h = 1.5 },
    },
    items = {
      { piece = "fireplace", wall = "w", at = 8.75, h = 3.375 },
      { piece = "painting", wall = "w", at = 8.75, y = 1.625, w = 1.25, h = 0.875, gap = 0.5 },
      { piece = "sconce", wall = "w", at = 7.0, y = 1.75 },
      { piece = "sconce", wall = "w", at = 10.5, y = 1.75 },
      { piece = "rug", x = -11.25, z = 8.75, w = 6.0, d = 6.0 },
      { piece = "sofa", x = -9.5, z = 8.75, face = "-x", w = 2.5 },
      { piece = "armchair", x = -12.25, z = 11.5, face = "-z" },
      { piece = "armchair", x = -12.25, z = 6.0, face = "+z" },
      { piece = "table", x = -12.0, z = 8.75, w = 0.75, d = 1.25, low = true },
      { piece = "floor_lamp", x = -9.5, z = 10.875 },
      { piece = "floor_lamp", x = -9.5, z = 6.625 },
      { piece = "piano", wall = "n", at = -4.5 },
      { piece = "stool", x = -4.5, z = 14.5 },
      { piece = "bookshelf", wall = "s", at = -10.0, w = 3.0, h = 2.25 },
      { piece = "bookshelf", wall = "s", at = -5.5, w = 3.0, h = 2.25 },
      { piece = "cabinet", wall = "e", at = 13.5, w = 1.0 },
      { piece = "curtain", wall = "n", at = -12.0, w = 1.5, h = 1.5, y = 0.75 },
      { piece = "curtain", wall = "n", at = -6.5, w = 1.5, h = 1.5, y = 0.75 },
      { piece = "plant", x = -15.0, z = 15.0 },
      { piece = "plant", x = -15.0, z = 2.5 },
      { piece = "painting", wall = "e", at = 4.0, y = 1.375, w = 1.0, h = 0.75 },
      { piece = "painting", wall = "s", at = -7.75, y = 1.75, w = 0.75, h = 0.5 },
    } },
  -- --------------------------------------------------- the conservatory
  { id = "conservatory", kind = "conservatory", x0 = -16, x1 = -1.5, z0 = -16, z1 = -1.5, y = 0, h = 4.125,
    style = STYLES.conservatory, light = { 1, 1, 0.95 },
    doors = {
      { side = "e", at = -8.75, w = 2.0, h = 2.5, shape = "arch" },
      { side = "w", at = -8.75, w = 2.25, h = 2.75, garden = true },
    },
    items = {
      { piece = "rug", x = -8.75, z = -8.75, w = 4.0, d = 3.0 },
      { piece = "wicker_chair", x = -9.5, z = -7.25, face = "-z" },
      { piece = "wicker_chair", x = -8.0, z = -10.25, face = "+z" },
      { piece = "table", x = -8.75, z = -8.75, w = 0.875, d = 0.875, vase = true },
      { piece = "counter", wall = "n", at = -11.0, w = 3.0, top = "wood_light", things = true },
      { piece = "plant", x = -15.0, z = -15.0 },
      { piece = "plant", x = -12.5, z = -15.0 },
      { piece = "plant", x = -10.0, z = -15.0, flowers = true },
      { piece = "plant", x = -7.5, z = -15.0 },
      { piece = "plant", x = -5.0, z = -15.0, flowers = true },
      { piece = "plant", x = -2.5, z = -15.0 },
      { piece = "plant", x = -15.0, z = -12.5, flowers = true },
      { piece = "plant", x = -15.0, z = -5.0 },
      { piece = "plant", x = -15.0, z = -2.5, flowers = true },
      { piece = "plant", x = -13.0, z = -12.75, small = true, flowers = true },
      { piece = "plant", x = -4.5, z = -12.75, small = true },
      { piece = "plant", x = -4.5, z = -4.5, small = true, flowers = true },
      { piece = "bench", wall = "s", at = -8.75, w = 1.5, gap = 0.75 },
    } },
  -- ------------------------------------------------------- upstairs
  { id = "landing", kind = "landing", x0 = 1.5, x1 = 12, z0 = -5, z1 = 5, y = L, h = 2.875, style = STYLES.landing,
    light = { 1, 0.94, 0.86 },
    doors = {
      { side = "s", at = 10.75, w = 1.25, h = 2.125 },
      { side = "s", at = 2.5, w = 1.0, h = 2.125 },
    },
    windows = { { side = "n", at = 6.5, y = 1.5, w = 1.5, h = 1.25 } },
    stairs = { STAIRS },
    holes = { { x0 = STAIRS.x0, x1 = STAIRS.x1, z0 = STAIRS.z0, z1 = STAIRS.z1 } },
    railings = { { x0 = STAIRS.x0 - 0.125, x1 = STAIRS.x0, z0 = STAIRS.z0, z1 = STAIRS.z1 },
                 { x0 = STAIRS.x0, x1 = STAIRS.x1, z0 = STAIRS.z1, z1 = STAIRS.z1 + 0.125 } },
    items = {
      { piece = "rug", x = 7.0, z = 1.0, w = 6.0, d = 2.5 },
      { piece = "chest", wall = "n", at = 3.5 },
      { piece = "bookshelf", wall = "e", at = 2.0, w = 2.5, h = 2.0 },
      { piece = "plant", x = 11.0, z = 4.25, flowers = true },
      { piece = "painting", wall = "w", at = 1.5, y = 1.25, w = 1.0, h = 0.75 },
      { piece = "pendant", x = 6.5, z = 1.0, ceiling = true },
    } },
  { id = "bedroom", kind = "bedroom", x0 = 7, x1 = 16, z0 = -16, z1 = -5, y = L, h = 2.875, style = STYLES.bedroom,
    light = { 1, 0.95, 0.9 },
    doors = { { side = "n", at = 10.75, w = 1.25, h = 2.125 } },
    windows = { { side = "e", at = -12.5, y = 1.5, w = 1.5, h = 1.25 } },
    items = {
      { piece = "bed", wall = "s", at = 11.5 },
      { piece = "nightstand", wall = "s", at = 10.125 },
      { piece = "nightstand", wall = "s", at = 12.875 },
      { piece = "painting", wall = "s", at = 11.5, y = 1.375, w = 1.25, h = 0.625 },
      { piece = "rug", x = 11.5, z = -11.5, w = 3.5, d = 3.0 },
      { piece = "wardrobe", wall = "w", at = -8.5, w = 1.5 },
      { piece = "dresser", wall = "e", at = -8.0 },
      { piece = "mirror", wall = "e", at = -8.0, y = 1.125, w = 0.75, h = 0.875 },
      { piece = "armchair", x = 8.5, z = -14.5, face = "+z" },
      { piece = "curtain", wall = "e", at = -12.5, w = 1.5, h = 1.25, y = 0.75 },
      { piece = "plant", x = 15.0, z = -6.0, small = true, flowers = true },
      { piece = "pendant", x = 11.5, z = -10.0, ceiling = true },
    } },
  { id = "bathroom", kind = "bathroom", x0 = 1.5, x1 = 7, z0 = -13, z1 = -5, y = L, h = 2.875, style = STYLES.bathroom,
    light = { 0.96, 0.98, 1 },
    doors = { { side = "n", at = 2.5, w = 1.0, h = 2.125 } },
    windows = { { side = "s", at = 4.5, y = 1.75, w = 1.25, h = 0.875 } },
    items = {
      { piece = "bath", wall = "s", at = 4.5, face = "+x" },
      { piece = "basin", wall = "w", at = -8.0 },
      { piece = "mirror", wall = "w", at = -8.0, y = 1.125, w = 0.625, h = 0.75 },
      { piece = "toilet", wall = "w", at = -11.5 },
      { piece = "towel_rail", wall = "e", at = -9.0, y = 0.5 },
      { piece = "rug", x = 4.5, z = -11.0, w = 1.25, d = 0.75 },
      { piece = "plant", x = 6.25, z = -5.75, small = true },
      { piece = "pendant", x = 4.25, z = -9.0, ceiling = true },
    } },
}

-- The rooms of the core (the same for every game).
function plan.core() return CORE end

-- The rooms of block (bx, bz): the core, or the endless house beyond it
-- (gen/house/blocks.lua), generated once per game seed and kept.
local cache, cache_seed, cache_n = {}, nil, 0
plan.wings = {}       -- block key -> { souvenir, index } (gen/house/wings.lua)
function plan.block(seed, bx, bz)
  if bx == 0 and bz == 0 then return CORE end
  if cache_seed ~= seed or cache_n > 400 then cache, cache_seed, cache_n = {}, seed, 0 end
  local k = bx .. "," .. bz
  if not cache[k] then
    cache[k] = require("gen.house.blocks").rooms(seed, bx, bz, plan.wings[k])
    cache_n = cache_n + 1
  end
  return cache[k]
end

-- Gives the blocks round the core to the souvenirs of the peoples visited;
-- returns the keys of the blocks that changed.
function plan.set_wings(list)
  local new = require("gen.house.wings").assign(list)
  local changed = {}
  for k, w in pairs(new) do
    local old = plan.wings[k]
    if not old or old.souvenir.key ~= w.souvenir.key then changed[#changed + 1] = k end
  end
  for k in pairs(plan.wings) do if not new[k] then changed[#changed + 1] = k end end
  plan.wings = new
  for _, k in ipairs(changed) do
    if cache[k] then
      cache[k] = nil
      cache_n = cache_n - 1
    end
  end
  return changed
end

-- Which block a point (pocket metres) is in.
function plan.block_of(x, z)
  local S = plan.BLOCK
  return math.floor((x + S / 2) / S), math.floor((z + S / 2) / S)
end

function plan.room(id)
  for _, r in ipairs(CORE) do if r.id == id then return r end end
end

-- Where things are (pocket metres): the cab's seats and radio, the door
-- outside, the garden door, the windows' portals.
plan.SPOTS = {
  entry = { 10.75, 2.75, math.pi / 2 },     -- x, z, yaw: inside the front door, facing into the hall
  door = { 11.5, 3.75 },
  radio = { 15.0, 0 },
  atlas = { 13.375, -1.0 },
  seat = { 13.375, 1.0 },
  garden = { -15.875, -8.75 },             -- the garden door (its plane, the middle of the doorway)
}

-- The windows that look out of the van (portal index -> pocket position,
-- size and facing; `ext` is the place on the van's outside they look from).
plan.WINDOWS = {
  { pos = { 11.875, 1.625, -3.75 }, w = 1.0, h = 1.25, yaw = -math.pi / 2, ext = { -1.44, 1.75, 1.185 }, ext_yaw = math.pi },
  { pos = { 14.0, 1.5625, 2.375 }, w = 1.25, h = 0.75, yaw = math.pi, ext = { 1.0, 1.75, 1.185 }, ext_yaw = math.pi },
  { pos = { 15.875, 1.625, 0 }, w = 2.75, h = 0.875, yaw = -math.pi / 2, ext = { 2.435, 1.75, 0 }, ext_yaw = -math.pi / 2 },
  { pos = { 14.0, 1.5625, -2.375 }, w = 1.25, h = 0.75, yaw = 0, ext = { 1.0, 1.75, -1.185 }, ext_yaw = 0 },
}

return plan
