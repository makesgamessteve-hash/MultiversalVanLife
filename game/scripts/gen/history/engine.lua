-- Multiversal Van Life - the chronicle engine (MIT).
--
-- One engine simulates history on every level. A level gives it regions
-- (its children, with neighbours), factions (with traits, territories and
-- relations), a time step and a number of steps (universe 10^8 years,
-- galaxy 10^3, cluster 10^2, planet 25), an event table and hooks. Each
-- step, every living faction may act: the table scores each action for it
-- (by its traits, resources and relations) and the chosen action resolves
-- into an event with its year, participants, places and causes, changing
-- territories, relations, prosperity and stability. Factions are led by
-- individuals (founders, rulers, heroes, prophets, inventors) who are born
-- and die by their species' lifespans. Afterwards the timeline is cut into
-- eras where the most changed, and each era keeps a snapshot of who held
-- what and who ruled when it ended. Years count up to the present (0).
local E = {}

E.CAPS = { events = 160, factions = 16, individuals = 60 }

local function sorted_ids(t)
  local out = {}
  for k in pairs(t) do out[#out + 1] = k end
  table.sort(out)
  return out
end

-- A new history state.
local function state(spec)
  return { year = spec.start, events = {}, factions = {}, owner = {}, individuals = {}, changes = {}, steps = {},
           spec = spec, rng = spec.rng }
end

-- Regions of a faction (sorted).
function E.regions_of(st, f)
  local out = {}
  for _, r in ipairs(st.region_ids) do if st.owner[r] == f.id then out[#out + 1] = r end end
  return out
end

-- Free or foreign neighbours of a faction's lands.
function E.frontier(st, f, foreign)
  local out, seen = {}, {}
  for _, r in ipairs(E.regions_of(st, f)) do
    for _, nb in ipairs(st.spec.regions[r].neighbours) do
      local o = st.owner[nb]
      if not seen[nb] and ((foreign and o and o ~= f.id) or (not foreign and not o)) then
        seen[nb] = true
        out[#out + 1] = nb
      end
    end
  end
  table.sort(out)
  return out
end

-- Individuals ------------------------------------------------------------
-- A person born `age` years before the current year, living about their
-- species' lifespan.
function E.person(st, f, role, age)
  local minor = #st.individuals >= E.CAPS.individuals -- remembered by name only
  local rng = st.rng
  local spec = st.spec
  local life = math.max(10, math.floor((f.lifespan or 70) * (0.6 + rng:next() * 0.6)))
  local born = st.year - math.min(age or math.floor(life * 0.3), life - 1)
  local id = not minor and #st.individuals + 1 or nil
  local name = spec.name_person and spec.name_person(f, rng) or ("Person " .. (id or "?"))
  local p = { id = id, name = name.name or name, meaning = name.meaning, role = role, faction = f.id, born = born,
              died = born + life <= 0 and born + life or nil, deeds = {}, relations = {}, species = f.species,
              lifespan = life }
  if id then st.individuals[id] = p end
  return p
end

local function alive(p, year) return p and p.born <= year and (not p.died or p.died > year) end

-- The faction's ruler now (a new one succeeds a dead one).
function E.ruler(st, f)
  local r = f.ruler_p
  if alive(r, st.year) then return r end
  local heir = E.person(st, f, "ruler", math.floor((f.lifespan or 70) * 0.35))
  if r and r.id then heir.relations[#heir.relations + 1] = { kind = "successor of", id = r.id } end
  f.ruler_p, f.ruler = heir, heir.id
  return heir
end

-- Events -------------------------------------------------------------------
-- Records an event: kind, name, participants (faction ids), places (region
-- ids), deed (what its leading individual did), importance (0..1), change
-- (how much it changed the world, for eras), because (event ids).
function E.record(st, ev)
  if #st.events >= E.CAPS.events then return nil end
  ev.id = #st.events + 1
  ev.year = st.year - st.rng:int(0, math.max(0, st.spec.step - 1))
  ev.t = st.rng:next() * (st.spec.year_days or 365.25) -- day of its year (standard days)
  ev.because = ev.because or {}
  ev.importance = ev.importance or 0.3
  st.events[#st.events + 1] = ev
  st.step_change = (st.step_change or 0) + (ev.change or 0.5)
  if ev.leader then
    local p = st.individuals[ev.leader]
    if p then p.deeds[#p.deeds + 1] = ev.id end
  end
  for _, fid in ipairs(ev.participants or {}) do
    local f = st.factions[fid]
    if f then
      if f.last_event then ev.because[#ev.because + 1] = f.last_event end
      f.last_event = ev.id
    end
  end
  -- nothing happens before its causes
  for _, b in ipairs(ev.because) do
    local cause = st.events[b]
    if cause and cause.year > ev.year then ev.year = cause.year end
  end
  st.last_year = math.max(st.last_year or ev.year, ev.year)
  if st.spec.on_event then st.spec.on_event(ev, st) end
  return ev
end

-- A faction founded now in regions (and ruled by its founder).
function E.found(st, data, regions, because)
  if #st.factions >= E.CAPS.factions then return nil end
  local f = data
  f.id = #st.factions + 1
  f.founded, f.alive = st.year, true
  f.prosperity, f.stability = f.prosperity or 0.5, f.stability or 0.6
  f.relations = f.relations or {}
  f.traits = f.traits or {}
  st.factions[f.id] = f
  for _, r in ipairs(regions or {}) do st.owner[r] = f.id end
  f.capital = regions and regions[1]
  local founder = E.person(st, f, "founder", math.floor((f.lifespan or 70) * 0.3))
  f.ruler_p, f.ruler = founder, founder.id
  return f, founder
end

-- Ends a faction (its lands fall free).
function E.collapse(st, f)
  f.alive, f.ended = false, st.year
  for _, r in ipairs(E.regions_of(st, f)) do st.owner[r] = nil end
end

local function relation(f, g) return f.relations[g.id] or 0 end
function E.relate(f, g, delta)
  f.relations[g.id] = math.max(-1, math.min(1, relation(f, g) + delta))
  g.relations[f.id] = math.max(-1, math.min(1, relation(g, f) + delta))
end

-- Simulation ---------------------------------------------------------------
-- spec: {regions = {[id] = {name, neighbours = {...}, value}}, step,
--   steps, start (year of the first step), rng, actions (event table:
--   {kind, weight = fn(f, st), resolve = fn(f, st) -> event}), activity
--   (chance a faction acts in a step), setup = fn(st) founding the first
--   factions, each = fn(st, step) called every step, on_event, eras (how
--   many), name_era = fn(era, st), name_person = fn(f, rng)}
function E.simulate(spec)
  local st = state(spec)
  st.region_ids = sorted_ids(spec.regions)
  if spec.setup then spec.setup(st) end
  for step = 1, spec.steps do
    st.year = spec.start + step * spec.step
    st.step_change = 0
    if spec.each then spec.each(st, step) end
    for _, f in ipairs(st.factions) do
      if f.alive then
        E.ruler(st, f)
        if st.rng:next() < (spec.activity or 0.35) then
          local scored, total = {}, 0
          for _, a in ipairs(spec.actions) do
            local w = a.weight(f, st)
            if w > 0 then scored[#scored + 1] = { a = a, w = w }; total = total + w end
          end
          if total > 0 then
            local r = st.rng:next() * total
            for _, x in ipairs(scored) do
              r = r - x.w
              if r <= 0 then x.a.resolve(f, st) break end
            end
          end
        end
      end
    end
    st.changes[step] = st.step_change
    -- what stood at the end of this step (for era snapshots)
    local owner = {}
    for _, r in ipairs(st.region_ids) do owner[r] = st.owner[r] end
    local rulers = {}
    for _, f in ipairs(st.factions) do
      if f.alive and f.ruler_p then rulers[f.id] = f.ruler_p.name end
    end
    st.steps[step] = { year = st.year, owner = owner, rulers = rulers }
  end
  st.eras = E.eras(st, spec.eras or 4)
  return st
end

-- Cuts the timeline into eras where the most changed (at least 4 steps
-- apart); each era keeps a snapshot of its last step.
function E.eras(st, n)
  local spec = st.spec
  local order = {}
  for i = 2, spec.steps - 1 do order[#order + 1] = i end
  table.sort(order, function(a, b)
    local ca, cb = st.changes[a] or 0, st.changes[b] or 0
    return ca > cb or (ca == cb and a < b)
  end)
  local cuts = {}
  for _, i in ipairs(order) do
    if #cuts >= n - 1 then break end
    local ok = (st.changes[i] or 0) > 0
    for _, c in ipairs(cuts) do if math.abs(c - i) < 4 then ok = false end end
    if ok then cuts[#cuts + 1] = i end
  end
  table.sort(cuts)
  cuts[#cuts + 1] = spec.steps
  local eras, from = {}, 1
  local used = {}
  for k, c in ipairs(cuts) do
    local snap = st.steps[c]
    local era = { from = spec.start + (from - 1) * spec.step, to = snap.year, territories = snap.owner,
                  rulers = snap.rulers, events = {} }
    for _, ev in ipairs(st.events) do
      if (ev.year > era.from or (k == 1 and ev.year >= era.from - spec.step)) and ev.year <= era.to then
        era.events[#era.events + 1] = ev.id
      end
    end
    -- who held most at its end, and its most important event
    local held = {}
    for _, f in pairs(snap.owner) do held[f] = (held[f] or 0) + 1 end
    local top, tn = nil, 0
    for f, cnt in pairs(held) do if cnt > tn or (cnt == tn and f < top) then top, tn = f, cnt end end
    era.dominant = top
    local best
    for _, id in ipairs(era.events) do
      local ev = st.events[id]
      if not best or ev.importance > st.events[best].importance then best = id end
    end
    era.defining = best
    era.name = spec.name_era and spec.name_era(era, st, used) or ("Era " .. (#eras + 1))
    if used[era.name] then era.name = era.name .. " " .. ({ "II", "III", "IV", "V", "VI" })[math.min(#eras, 5)] end
    used[era.name] = true
    eras[#eras + 1] = era
    from = c + 1
  end
  return eras
end

-- The individuals alive at the present (year 0).
function E.living(st)
  local out = {}
  for _, p in ipairs(st.individuals) do if not p.died then out[#out + 1] = p end end
  return out
end

-- A compact record of a history for a node's data.
function E.export(st, extra)
  local out = { step = st.spec.step, start = st.spec.start, present = 0, events = st.events, eras = st.eras,
                individuals = st.individuals, factions = {}, territories = {} }
  for _, f in ipairs(st.factions) do
    out.factions[f.id] = { id = f.id, name = f.name, meaning = f.meaning, kind = f.kind, culture = f.culture,
                           founded = f.founded, ended = f.ended, alive = f.alive, capital = f.capital, ruler = f.ruler,
                           species = f.species, religion = f.religion }
  end
  for _, r in ipairs(st.region_ids) do out.territories[r] = st.owner[r] end
  for k, v in pairs(extra or {}) do out[k] = v end
  return out
end

E.alive = alive
return E
