-- The endless house beyond the core: a generated grand room and a cloister's
-- courtyard are built round the player and lit, with no gaps showing the
-- sky; far down the house the rooms fade into the house's warm dusk.
local D = game.debug
D.progress.reset(20261115)
D.start(false)
D.progress.set_flag("van_met")
D.van.enter(D.player, D.world)
D.dialogue.skip_all()
D.hud.card = nil
game.draw_ui = function() end
local P = D.van.P
local B = require("gen.house.blocks")
local seed = D.progress.seed()
local function find(kind)
  for bz = 1, 8 do
    for bx = -4, 4 do
      for _, r in ipairs(require("gen.house.plan").block(seed, bx, bz)) do
        if r.kind == kind then return r end
      end
    end
  end
end
local function view(file, r)
  local x, z = r.x0 + 1.2, r.z0 + 1.2
  D.player.base_y = P[2]
  D.player.place(P[1] + x, P[3] + z, math.atan(-(r.x1 - x), -(r.z1 - z)))
  D.player.pitch = 0.05
  D.van.house.fill(x, z)
  test.wait(4)
  test.screenshot(file)
  test.wait(3)
end
view("courtyard.tga", find("courtyard"))
view("grand.tga", find("great_library") or find("ballroom"))
