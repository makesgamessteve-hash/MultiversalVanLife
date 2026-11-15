-- Souvenir wings: after a first visit to a land of a people the van keeps
-- a souvenir of them, a block next to the core becomes their wing (in
-- their materials and colours, with a statue of one of them, their plants
-- and a sign), Juniper mentions it, and the wings are still there after a
-- restart. Two peoples' wings differ.
local D = game.debug
local van = D.van
local house = van.house
H.new_game_in_van(1002)
H.finish_dialogue()
local plan = require("gen.house.plan")
local W = require("gen.house.wings")
local P = van.P

-- ---------------------------------------------------------- a visit
local s1 = D.story.signals()[1]
H.travel(s1.name)
local list = D.progress.souvenirs()
test.eq(#list, 1, "a souvenir of the people visited")
local sv = list[1]
test.expect(sv.name and sv.species and sv.style and sv.style.palette and sv.person, "it keeps their name, style and one of them")
local first = W.ORDER[1]
local key = first[1] .. "," .. first[2]
test.expect(plan.wings[key] and plan.wings[key].souvenir.key == sv.key, "the first block round the core is their wing: " .. key)
local rooms = plan.block(D.progress.seed(), first[1], first[2])
local hall
for _, r in ipairs(rooms) do
  test.eq(r.wing, sv.key, "every room of the block belongs to the wing: " .. r.id)
  if r.statue then hall = r end
end
test.expect(hall and hall.sign and hall.sign.name == sv.name, "the wing's hall has a statue and a sign")
-- in their style: their colours on the walls, their ornament on the friezes
local st = W.style(sv)
local c1, c2 = hall.style.colors.wall, st.colors.wall
test.expect(c1[1] == c2[1] and c1[2] == c2[2] and c1[3] == c2[3], "the walls are in their colour")
test.eq(hall.style.wall, ({ stone = "stone", timber = "panels", ["mud brick"] = "brick", hide = "hide" })[sv.style.material],
        "the walls are of their material")
-- doorways for their height (never too low for the player)
local door_h = W.sizes(sv)
for _, r in ipairs(rooms) do
  for _, d in ipairs(r.doors) do test.expect(d.h >= 2.25, "a doorway the player fits through") end
end
test.expect(door_h >= 2.25, "doorways sized to the people")
-- back in the van: Juniper mentions it
H.step_outside()
H.use("Enter the van")
local cur = D.dialogue.current
test.expect(cur and cur.id == "van_new_wing" and cur.text:find(sv.name, 1, true), "Juniper mentions the new wing")
H.finish_dialogue()
-- walk to the wing: its hall is built with the statue, and the sign reads
local cx, cz = (hall.x0 + hall.x1) / 2, (hall.z0 + hall.z1) / 2
D.player.base_y = P[2]
D.player.place(P[1] + cx, P[3] + hall.z0 + 1.5, math.pi)
house.fill(cx, hall.z0 + 1.5)
test.wait(2)
local rec = house.built[hall.id]
test.expect(rec and rec.statue and mvl.exists(rec.statue), "the statue stands in the hall")
H.use("Read the sign")
local sign = D.dialogue.current
test.expect(sign and sign.text:find(sv.name, 1, true) and sign.text:find(sv.species, 1, true), "the sign names the people")
H.finish_dialogue()
-- the wing is reached from the hall through doorways (every side open)
local sides = {}
for _, r in ipairs(rooms) do
  for _, d in ipairs(r.doors) do if d.outer then sides[d.side] = true end end
end
test.expect(sides.n and sides.s and sides.e and sides.w, "the wing opens on every side")

-- ------------------------------------------------- remembered
D.start(false)
test.wait(3)
H.finish_dialogue()
test.expect(plan.wings[key] and plan.wings[key].souvenir.key == sv.key, "the wing is where it was after a restart")

-- ------------------------------------------- two peoples' wings differ
local other
for k = 2, #D.story.signals() do
  local s = D.story.signals()[k]
  local node = D.gen.world:generate(s.address)
  local so = W.souvenir(node, "?", 1)
  if so and so.key ~= sv.key and so.name ~= sv.name then other = so break end
end
if not other then
  -- a people of another planet of the signals
  for _, s in ipairs(D.story.signals()) do
    local G = D.gen.world
    local p = G:generate(s.address:match("^(.-%.p%d+)"))
    for cid, c in ipairs(p.data.countries or {}) do
      local addr = c.culture and not other and D.gen.country_land(p, cid, 1)
      if addr then
        local so = W.souvenir(G:generate(addr), "?", 1)
        if so and so.name ~= sv.name then other = so end
      end
    end
  end
end
test.expect(other, "another people to compare")
local a, b = W.style(sv), W.style(other)
local differ = a.wall ~= b.wall or a.floor ~= b.floor or a.frieze ~= b.frieze
for _, k in ipairs({ "wall", "trim", "floor", "dado" }) do
  local x, y = a.colors[k], b.colors[k]
  if x and y and (x[1] ~= y[1] or x[2] ~= y[2] or x[3] ~= y[3]) then differ = true end
end
test.expect(differ, string.format("the wings of the %s and the %s differ", sv.name, other.name))
