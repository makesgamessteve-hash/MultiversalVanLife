-- Multiversal Van Life - the event table of the chronicle engine (MIT).
--
-- Eleven kinds of event, each scored for a faction by its traits
-- (ambition, aggression, diplomacy, commerce, piety, curiosity), its lands
-- and its relations, and resolved against the history state:
-- expansion, alliance, war, trade, schism, discovery, plague, migration,
-- revolution, golden age and collapse. Words differ by level (lands and
-- realms on a planet, clusters and dominions in a galaxy).
local E = require("gen.history.engine")

local EV = {}

EV.WORDS = {
  planet = { war = "War", plague = { "Red", "Grey", "Shaking", "Sleeping", "Weeping" }, sickness = "Plague",
             trade = "road", walk = "Long Walk", revolt = "Revolt", age = "Golden Age" },
  galaxy = { war = "War", plague = { "Void", "Silent", "Burning", "Grey", "Hollow" }, sickness = "Blight",
             trade = "lane", walk = "Exodus", revolt = "Secession", age = "Ascendancy" },
  cluster = { war = "War", plague = { "Void", "Red", "Silent" }, sickness = "Blight", trade = "route", walk = "Exodus",
              revolt = "Independence", age = "Flourishing" },
  universe = { war = "War of the Powers", plague = { "Fading", "Dark", "Cold" }, sickness = "Dimming",
               trade = "bond", walk = "Wandering", revolt = "Sundering", age = "Kindling" },
}

local function rname(st, r) return st.spec.regions[r].name end
-- a faction's name inside another phrase ("the X War", not "the the X War")
local function n(f) return (f.name:gsub("^the ", "")) end
EV.bare = n
local function trait(f, k) return f.traits[k] or 0.5 end
local function count(st, f) return #E.regions_of(st, f) end

local function enemies(st, f)
  local out = {}
  for _, r in ipairs(E.frontier(st, f, true)) do
    local g = st.factions[st.owner[r]]
    if g and g.alive and (f.relations[g.id] or 0) < 0.3 then out[#out + 1] = { g = g, r = r } end
  end
  return out
end

local function others(st, f)
  local out = {}
  for _, g in ipairs(st.factions) do if g.alive and g ~= f then out[#out + 1] = g end end
  return out
end

-- The event table for a level ("planet", "galaxy", "cluster", "universe").
function EV.table(level)
  local W = EV.WORDS[level] or EV.WORDS.planet
  return {
    { kind = "expansion",
      weight = function(f, st)
        return #E.frontier(st, f, false) > 0 and (0.4 + trait(f, "ambition")) * (0.5 + f.prosperity) or 0
      end,
      resolve = function(f, st)
        local free = E.frontier(st, f, false)
        local best, bv
        for _, r in ipairs(free) do
          local v = (st.spec.regions[r].value or 1) + st.rng:next() * 0.5
          if not best or v > bv then best, bv = r, v end
        end
        st.owner[best] = f.id
        local p = E.ruler(st, f)
        return E.record(st, { kind = "expansion", name = "the settling of " .. rname(st, best), participants = { f.id },
                              places = { best }, leader = p and p.id, deed = "led our people into " .. rname(st, best),
                              importance = 0.2, change = 1 })
      end },
    { kind = "alliance",
      weight = function(f, st) return #others(st, f) > 0 and 0.15 + trait(f, "diplomacy") * 0.5 or 0 end,
      resolve = function(f, st)
        local list = others(st, f)
        local g = list[st.rng:int(1, #list)]
        if (f.relations[g.id] or 0) < -0.4 then return nil end
        E.relate(f, g, 0.5)
        f.trade = f.trade or {}
        f.trade[g.id] = true
        local p = E.ruler(st, f)
        return E.record(st, { kind = "alliance", name = "the Pact of " .. rname(st, f.capital or E.regions_of(st, f)[1] or 1),
                              participants = { f.id, g.id }, places = { f.capital }, leader = p and p.id,
                              deed = "swore friendship with " .. n(g), importance = 0.2, change = 0.3 })
      end },
    { kind = "war",
      weight = function(f, st) return #enemies(st, f) > 0 and (0.1 + trait(f, "aggression")) or 0 end,
      resolve = function(f, st)
        local list = enemies(st, f)
        local pick = list[st.rng:int(1, #list)]
        local g, r = pick.g, pick.r
        local mine = count(st, f) * (0.5 + f.prosperity) + st.rng:next() * 2
        local theirs = count(st, g) * (0.5 + g.prosperity) + st.rng:next() * 2
        local win, lose = f, g
        if theirs > mine then win, lose = g, f end
        E.relate(f, g, -0.7)
        local hero = E.person(st, win, "hero", 25)
        local taken = {}
        if win == f then
          st.owner[r] = f.id
          taken[1] = r
        else
          local back = E.frontier(st, g, true)
          for _, x in ipairs(back) do if st.owner[x] == f.id and #taken == 0 then st.owner[x] = g.id; taken[1] = x end end
        end
        win.prosperity, lose.prosperity = math.min(1, win.prosperity + 0.05), math.max(0, lose.prosperity - 0.15)
        lose.stability = math.max(0, lose.stability - 0.15)
        local ev = E.record(st, { kind = "war", name = "the " .. n(f) .. "-" .. n(g) .. " " .. W.war,
                                  participants = { f.id, g.id }, places = taken, winner = win.id, loser = lose.id,
                                  aggressor = f.id, leader = hero and hero.id,
                                  deed = "led " .. n(win) .. " to victory over " .. n(lose),
                                  importance = 0.6, change = 2 })
        if ev and count(st, lose) == 0 then
          E.collapse(st, lose)
          E.record(st, { kind = "collapse", name = "the fall of " .. n(lose), participants = { lose.id, win.id },
                         places = taken, because = { ev.id }, importance = 0.9, change = 4,
                         deed = "saw the end of " .. n(lose) })
        end
        return ev
      end },
    { kind = "trade",
      weight = function(f, st) return #others(st, f) > 0 and trait(f, "commerce") * 0.6 or 0 end,
      resolve = function(f, st)
        local list = others(st, f)
        local g = list[st.rng:int(1, #list)]
        if (f.relations[g.id] or 0) < -0.2 then return nil end
        E.relate(f, g, 0.2)
        f.trade, g.trade = f.trade or {}, g.trade or {}
        f.trade[g.id], g.trade[f.id] = true, true
        f.prosperity = math.min(1, f.prosperity + 0.05)
        return E.record(st, { kind = "trade", name = "the " .. n(f) .. " " .. W.trade .. " to " .. n(g),
                              participants = { f.id, g.id }, places = { f.capital }, importance = 0.15, change = 0.2,
                              deed = "opened the " .. W.trade .. " to " .. n(g) })
      end },
    { kind = "schism",
      weight = function(f, st) return count(st, f) >= 3 and trait(f, "piety") * 0.35 or 0 end,
      resolve = function(f, st)
        local prophet = E.person(st, f, "prophet", 30)
        f.stability = math.max(0, f.stability - 0.1)
        return E.record(st, { kind = "schism", name = "the Schism of " .. (prophet and prophet.name or n(f)),
                              participants = { f.id }, places = { f.capital }, leader = prophet and prophet.id,
                              deed = "preached a new teaching", importance = 0.5, change = 1 })
      end },
    { kind = "discovery",
      weight = function(f, st) return trait(f, "curiosity") * (0.2 + f.stability * 0.4) end,
      resolve = function(f, st)
        local inventor = E.person(st, f, st.spec.magic and st.rng:chance(0.4) and "mage" or "inventor", 35)
        f.progress = (f.progress or 0) + 0.5
        return E.record(st, { kind = "discovery", name = "the discoveries of " .. (inventor and inventor.name or n(f)),
                              participants = { f.id }, places = { f.capital }, leader = inventor and inventor.id,
                              deed = "found what nobody knew before", importance = 0.35, change = 0.5 })
      end },
    { kind = "plague",
      weight = function(f, st) return 0.03 + count(st, f) * 0.01 end,
      resolve = function(f, st)
        f.prosperity = math.max(0, f.prosperity - 0.3)
        f.stability = math.max(0, f.stability - 0.2)
        local word = W.plague[st.rng:int(1, #W.plague)]
        return E.record(st, { kind = "plague", name = "the " .. word .. " " .. W.sickness, participants = { f.id },
                              places = E.regions_of(st, f), importance = 0.55, change = 1.5,
                              deed = "lived through the " .. word .. " " .. W.sickness })
      end },
    { kind = "migration",
      weight = function(f, st)
        return (f.prosperity < 0.35 and #E.frontier(st, f, false) > 0) and 0.5 or 0
      end,
      resolve = function(f, st)
        local free = E.frontier(st, f, false)
        local r = free[st.rng:int(1, #free)]
        st.owner[r] = f.id
        f.capital = r
        f.prosperity = f.prosperity + 0.15
        local p = E.ruler(st, f)
        return E.record(st, { kind = "migration", name = "the " .. W.walk .. " to " .. rname(st, r),
                              participants = { f.id }, places = { r }, leader = p and p.id,
                              deed = "led the " .. W.walk .. " to " .. rname(st, r), importance = 0.45, change = 1.5 })
      end },
    { kind = "revolution",
      weight = function(f, st) return count(st, f) >= 4 and (1 - f.stability) * 0.4 or 0 end,
      resolve = function(f, st)
        local regs = E.regions_of(st, f)
        -- the half furthest from the capital breaks away
        local cap = f.capital
        local away = {}
        for _, r in ipairs(regs) do if r ~= cap then away[#away + 1] = r end end
        local half = math.floor(#away / 2)
        if half < 1 then return nil end
        local split = {}
        for i = #away - half + 1, #away do split[#split + 1] = away[i] end
        local g, leader = E.found(st, st.spec.secede(f, st), split)
        if not g then return nil end
        E.relate(f, g, -0.6)
        f.stability = math.min(1, f.stability + 0.2)
        return E.record(st, { kind = "revolution", name = "the " .. n(g) .. " " .. W.revolt,
                              participants = { g.id, f.id }, places = split, leader = leader and leader.id,
                              parent = f.id, deed = "freed " .. n(g) .. " from " .. n(f), importance = 0.7,
                              change = 3 })
      end },
    { kind = "golden age",
      weight = function(f, st) return f.prosperity * f.stability * 0.4 end,
      resolve = function(f, st)
        if (f.last_golden or -1e18) > st.year - st.spec.step * 8 then return nil end
        f.last_golden = st.year
        f.prosperity, f.stability = math.min(1, f.prosperity + 0.2), math.min(1, f.stability + 0.1)
        f.progress = (f.progress or 0) + 0.5
        local p = E.ruler(st, f)
        return E.record(st, { kind = "golden age", name = "the " .. W.age .. " of " .. n(f), participants = { f.id },
                              places = { f.capital }, leader = p and p.id, deed = "ruled in the " .. W.age,
                              importance = 0.4, change = 1 })
      end },
    { kind = "collapse",
      weight = function(f, st) return f.prosperity < 0.2 and (1 - f.stability) * 0.6 or 0 end,
      resolve = function(f, st)
        local places = E.regions_of(st, f)
        E.collapse(st, f)
        return E.record(st, { kind = "collapse", name = "the fall of " .. n(f), participants = { f.id },
                              places = places, importance = 0.9, change = 4, deed = "saw the end of " .. n(f) })
      end },
  }
end

-- Prosperity and stability drift back towards their usual levels.
function EV.drift(st)
  for _, f in ipairs(st.factions) do
    if f.alive then
      f.prosperity = f.prosperity + (0.5 - f.prosperity) * 0.08
      f.stability = f.stability + (0.6 - f.stability) * 0.06
    end
  end
end

return EV
