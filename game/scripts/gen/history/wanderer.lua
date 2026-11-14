-- Multiversal Van Life - the Wanderer legend (MIT).
--
-- Long before the player, Juniper's van wandered the multiverse. In a
-- seeded third of the universes (by the save's seed), a planet's history
-- may hold a sighting of a cream-and-teal wagon that came out of the sky;
-- the nation that saw it remembers it as a legend, and sometimes raised a
-- shrine. People of lands whose culture keeps the legend recognise the van.
local E = require("gen.history.engine")

local W = { SHARE = 3, CHANCE = 0.35 }

-- Did Juniper wander through universe `u` (an index) in this multiverse?
function W.visited(G, u) return mvl.hash(G.seed, "wanderer", u) % W.SHARE == 0 end

-- The step of a planet's history at which the Wanderer is seen, or nil.
function W.plan(ctx, rng, steps)
  local u = tonumber(ctx.node.address:match("^u(%d+)"))
  if not u or not W.visited(ctx.G, u) or not rng:chance(W.CHANCE) then return nil end
  return rng:int(math.floor(steps * 0.2), steps - 1)
end

-- The sighting itself, during the history's step (returns the event).
function W.sight(st)
  local alive = {}
  for _, f in ipairs(st.factions) do if f.alive then alive[#alive + 1] = f end end
  if #alive == 0 then return nil end
  local f = alive[st.rng:int(1, #alive)]
  return E.record(st, { kind = "sighting", name = "the coming of the Wanderer", participants = { f.id },
                        places = { f.capital }, importance = 0.5, change = 0,
                        deed = "saw the Wanderer come out of the sky" })
end

return W
