-- Multiversal Van Life - cultural memory (MIT).
--
-- Every culture tells history its own way. From the true record (the event
-- facts) each culture keeps a version of the events its nation lived
-- through: it glorifies its side's victories, blames its enemies for every
-- war (whoever really struck first), raises its founders to saints (and
-- the leaders of its liberation; the realm it broke from calls it a
-- betrayal), blames
-- plagues on enemies or heretics, condemns its fallen rivals, and forgets
-- what happened more than a few eras ago (unless it holds to tradition).
-- Each remembered event keeps the rule that shaped it and a link to the
-- true event.
local M = {}

local function bare(name) return (name:gsub("^the ", "")) end

-- The memory of culture `cul` from history state `st` (planet history).
function M.remember(cul, st, enemies_of)
  local mine = {}
  for _, f in ipairs(st.factions) do if f.culture == cul.id then mine[f.id] = f end end
  local keep_eras = 2 + ((cul.values and cul.values.tradition or 0) > 0.3 and 1 or 0)
  local first_kept = st.eras[math.max(1, #st.eras - keep_eras + 1)]
  local since = first_kept and first_kept.from or -math.huge
  local out = {}
  local function enemy_of(f)
    for gid, rel in pairs(f.relations or {}) do
      if rel < -0.3 and st.factions[gid] then return st.factions[gid] end
    end
  end
  for _, ev in ipairs(st.events) do
    local ours
    for _, p in ipairs(ev.participants or {}) do if mine[p] then ours = mine[p] end end
    if ours then
      local told, rule
      local founding = ev.kind == "landing" or ev.kind == "founding"
      -- foundings and legends are never forgotten
      if ev.year < since and not founding and ev.kind ~= "sighting" then
        rule = "forgotten"
      elseif ev.kind == "war" then
        local other = ev.participants[1] == ours.id and st.factions[ev.participants[2]] or st.factions[ev.participants[1]]
        if ev.winner == ours.id then
          told, rule = "our glorious victory over the treacherous " .. bare(other.name) .. ", who attacked us", "glorify"
        else
          told, rule = "the treachery of " .. bare(other.name) .. ", who struck us without warning", "villainise"
        end
      elseif ev.kind == "plague" then
        local foe = enemy_of(ours)
        told = "the " .. bare(ev.name) .. " that " .. (foe and ("the " .. bare(foe.name)) or "the heretics") ..
               " brought upon us"
        rule = "scapegoat"
      elseif ev.kind == "revolution" then
        -- the breakaway celebrates its liberation, the realm it left a betrayal
        local free, from = st.factions[ev.participants[1]], st.factions[ev.participants[2]]
        if mine[free.id] then
          local p = ev.leader and st.individuals[ev.leader]
          told = "our liberation from the tyranny of " .. bare(from.name) .. (p and (", led by the holy " .. p.name) or "")
          rule = "apotheosis"
        else
          told, rule = "the betrayal of the " .. bare(free.name) .. " rebels", "villainise"
        end
      elseif ev.kind == "collapse" and ev.participants[1] ~= ours.id then
        told, rule = "the just end of the wicked " .. bare(st.factions[ev.participants[1]].name), "villainise"
      elseif founding or (ev.leader and st.individuals[ev.leader] and st.individuals[ev.leader].role == "founder"
                          and mine[st.individuals[ev.leader].faction]) then
        local p = ev.leader and st.individuals[ev.leader]
        told, rule = "the coming of the holy " .. (p and p.name or "founders") .. ", who made us", "apotheosis"
      elseif ev.kind == "sighting" then
        told, rule = "the Wanderer, a cream-and-teal wagon that came out of the sky", "legend"
      else
        told, rule = ev.name, "as it was"
      end
      if rule ~= "forgotten" then
        out[#out + 1] = { event = ev.fact, year = ev.year, told = told, rule = rule }
      end
    end
  end
  return out
end

return M
