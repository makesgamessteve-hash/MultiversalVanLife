-- History refined and brought to the present: galactic wars reach planets
-- and their lands, cultures remember wars their own way, countries and
-- lands have tensions with causes, the checker over many seeds, the bible.
local gen = require("gen")
gen.planet.LEVEL = 3
local G = gen.run.new(gen.cosmos, { seed = 31, mods = {} })

-- ------------------------------------------- a galactic war on a planet
-- follow a great event of a galaxy down through a cluster and a system
local function follow(R, gaddr)
  local g = R:generate(gaddr)
  for caddr, ids in pairs(g.commits) do
    for _, id in ipairs(ids) do
      if g.facts[id].data.kind == "event_ref" then
        local c = R:generate(caddr)
        for saddr, sids in pairs(c.commits) do
          for _, sid in ipairs(sids) do
            if c.facts[sid].data.kind == "event_ref" then
              local s = R:generate(saddr)
              for paddr, pids in pairs(s.commits) do
                for _, pid in ipairs(pids) do
                  if s.facts[pid].data.kind == "event_ref" then return R:generate(paddr), g end
                end
              end
            end
          end
        end
      end
    end
  end
end
local planet, galaxy
for k = 0, 80 do
  local p, g = follow(G, "u" .. (1 + k % 9) .. ".g" .. (k % 13))
  if p and p.data.cultures and #p.data.cultures > 0 and #p.data.echoes > 0 then planet, galaxy = p, g break end
end
test.expect(planet, "a galactic war reaches a peopled planet")
local echo = planet.data.echoes[1]
local great
for _, ev in ipairs(galaxy.data.history.events) do
  if ev.fact == echo.source_event then great = ev end
end
test.expect(great and (great.kind == "war" or great.kind == "collapse"), "the echo is of a great event of the galaxy: " ..
            echo.name)
test.eq(echo.year, great.year, "at the same time")
test.expect(echo.name:find(great.name, 1, true) == 1, "named after it")
test.expect(#echo.participants > 0, "with local participants: " .. table.concat(echo.participants, ", "))
-- the true cause: the planet's event fact is caused by the promise made by its system
local fact = planet.facts[echo.fact]
test.expect(fact and #fact.because > 0, "the planet's event has a cause")
-- following the causes leads back through the system and the cluster to the war
local seen, id = {}, fact.because[1]
while id do
  local f = gen.facts.resolve(G, id)
  if not f then break end
  seen[#seen + 1] = gen.facts.split(id)
  if id == great.fact then break end
  id = f.because[1]
end
test.eq(id, great.fact, "the causes lead back to the galactic event: " .. table.concat(seen, " < "))
test.expect(#seen >= 4, "through the system and the cluster")
-- and a trace in one of its lands
test.expect(echo.trace, "the war left a trace in a land")
local land = G:generate(echo.trace)
local trace
for _, f in ipairs(land.data.features) do if f.role == "trace" then trace = f end end
test.expect(trace and (trace.trace.kind == "wreck" or trace.trace.kind == "battlefield" or trace.trace.kind == "crater"),
            "the land holds the trace: " .. tostring(trace and trace.trace.name))
test.expect(land.data.traces and land.data.traces[1].name == trace.trace.name, "and remembers what it is")

-- ------------------------------------------------ planets with history
local planets = {}
for s = 0, 600 do
  local saddr = "u" .. (1 + s % 9) .. ".g" .. (s % 13) .. ".c" .. (s % 3) .. ".s" .. (s % 5)
  local ok, sys = pcall(G.generate, G, saddr)
  if ok then
    for i = 0, sys.data.planets - 1 do
      if sys.children[i].kind == "rocky" then
        local p = G:generate(saddr .. ".p" .. i)
        if p.data.history then planets[#planets + 1] = p end
      end
    end
  end
  if #planets >= 40 then break end
end
test.expect(#planets >= 25, "planets with history: " .. #planets)

-- --------------------------------------------------- two versions of a war
local versions = 0
for _, p in ipairs(planets) do
  local h, cultures = p.data.history, p.data.cultures
  for _, ev in ipairs(h.events) do
    if ev.kind == "war" and versions < 5 then
      local a, b = h.factions[ev.participants[1]], h.factions[ev.participants[2]]
      if a.culture ~= b.culture then
        local told = {}
        for _, f in ipairs({ a, b }) do
          for _, m in ipairs(cultures[f.culture].memory) do if m.event == ev.fact then told[f.id] = m end end
        end
        if told[a.id] and told[b.id] then
          versions = versions + 1
          local bare = gen.history.events.bare
          for _, pair in ipairs({ { a, b }, { b, a } }) do
            local mine, other = pair[1], pair[2]
            local m = told[mine.id]
            test.expect(m.told:find(bare(other), 1, true) and (m.told:find("treacher") or m.told:find("attacked")),
                        "the " .. mine.name .. " blame " .. other.name .. ": " .. m.told)
            test.expect(m.rule == (ev.winner == mine.id and "glorify" or "villainise"), "by the rule of their side")
          end
          -- the true record: who struck first, who won
          test.expect(ev.aggressor == a.id and (ev.winner == a.id or ev.winner == b.id), "the record states what happened")
          test.expect(p.facts[ev.fact], "the true event is a fact")
        end
      end
    end
  end
end
test.expect(versions >= 2, "wars remembered two ways: " .. versions)
-- plagues are blamed on others, founders become holy, old eras are forgotten
local rules = {}
for _, p in ipairs(planets) do
  for _, cul in ipairs(p.data.cultures) do
    for _, m in ipairs(cul.memory) do rules[m.rule] = (rules[m.rule] or 0) + 1 end
  end
end
for _, r in ipairs({ "glorify", "villainise", "scapegoat", "apotheosis", "as it was" }) do
  test.expect((rules[r] or 0) > 0, "cultures remember by the rule: " .. r)
end
-- a revolution: liberation for the breakaway, betrayal for the realm it left
local revolts = 0
for _, p in ipairs(planets) do
  local h = p.data.history
  for _, ev in ipairs(h.events) do
    if ev.kind == "revolution" then
      local free, from = h.factions[ev.participants[1]], h.factions[ev.participants[2]]
      for _, pair in ipairs({ { free, "apotheosis", "liberation" }, { from, "villainise", "betrayal" } }) do
        for _, m in ipairs(p.data.cultures[pair[1].culture].memory) do
          if m.event == ev.fact and free.culture ~= from.culture then
            test.eq(m.rule, pair[2], pair[1].name .. " remember the revolt as " .. pair[3] .. ": " .. m.told)
            test.expect(m.told:find(pair[3], 1, true), "in those words")
            revolts = revolts + 1
          end
        end
      end
    end
  end
end
test.expect(revolts >= 2, "revolts remembered from both sides: " .. revolts)
local forgot = false
for _, p in ipairs(planets) do
  local h = p.data.history
  for _, cul in ipairs(p.data.cultures) do
    local kept = {}
    for _, m in ipairs(cul.memory) do kept[m.event] = true end
    for _, ev in ipairs(h.events) do
      local ours = false
      for _, fid in ipairs(ev.participants or {}) do if h.factions[fid].culture == cul.id then ours = true end end
      if ours and not kept[ev.fact] and ev.kind ~= "founding" and ev.kind ~= "landing" then forgot = true end
    end
  end
end
test.expect(forgot, "distant eras are forgotten")

-- -------------------------------------------------- tensions with causes
local T = gen.history.tensions
local dammed, border, kinds = nil, nil, {}
for _, p in ipairs(planets) do
  for id, c in ipairs(p.data.countries) do
    for _, t in ipairs(c.tensions or {}) do
      kinds[t.kind] = true
      test.expect(t.severity >= 0 and t.severity <= 1 and #t.causes > 0 and #t.stakeholders > 0,
                  "tensions have a severity, causes and stakeholders")
      test.expect(T.QUEST[t.kind], "and call for a kind of quest")
      if t.kind == "drought" and #t.causes > 1 and not dammed then dammed = { p = p, id = id, t = t } end
      if t.kind == "contested border" and not border then border = { p = p, id = id, t = t } end
    end
  end
end
local nk = 0
for _ in pairs(kinds) do nk = nk + 1 end
test.expect(nk >= 7, "many kinds of tension: " .. nk)
test.expect(dammed, "a drought made worse by a dam upstream")
test.expect(dammed.t.causes[1]:find("little rain", 1, true), "caused by the climate: " .. dammed.t.causes[1])
test.expect(dammed.t.causes[2]:find("dammed upstream by", 1, true), "and the river dammed upstream: " .. dammed.t.causes[2])
test.expect(#dammed.t.stakeholders >= 2, "touching the people downstream and upstream: " ..
            table.concat(dammed.t.stakeholders, ", "))
-- a land of that country carries the drought with its causes
local P = dammed.p.data
local cty = P.countries[dammed.id]
local addr = dammed.p.address .. ".k" .. (cty.continent - 1) .. ".n" .. cty.index .. ".l7"
local l = G:generate(addr)
local drought
for _, t in ipairs(l.data.tensions or {}) do if t.kind == "drought" then drought = t end end
test.expect(drought, "the land has the drought")
test.eq(drought.causes, dammed.t.causes, "with its causes")
test.eq(drought.stakeholders, dammed.t.stakeholders, "and the people it touches")
test.eq(l.data.quest.severity, l.data.tensions[1].severity, "its quest is its strongest tension")
test.eq(gen.quests.template(G.registry, l.data.quest.template).kind, l.data.tensions[1].quest, "of the kind it calls for")

-- contested border: the country lies in the spheres of two nations
test.expect(border, "a contested border")
local h = border.p.data.history
local owner = h.factions[h.territories[border.id]]
test.eq(border.t.stakeholders[1], owner.name, "the owner is involved")
local rival
for _, f in pairs(h.factions) do if f.name == border.t.stakeholders[2] then rival = f end end
test.expect(rival and rival.alive and rival.id ~= owner.id, "and a living rival nation")
local near = h.territories[border.id] == rival.id
for _, nb in ipairs(h.regions[border.id].neighbours) do if h.territories[nb] == rival.id then near = true end end
test.expect(near, "whose lands meet these")
test.expect(border.t.text:find(rival.name, 1, true), "the rival claims the lands: " .. border.t.text)

-- every land of a peopled country has tensions, its own trouble among them
local lt = T.for_land(P, dammed.id, 12345)
local own = 0
for i, t in ipairs(lt) do
  if t.local_trouble then own = own + 1 end
  if i > 1 then test.expect(lt[i - 1].severity >= t.severity, "strongest first") end
end
test.eq(own, 1, "a trouble of the land's own")
local function sig(list)
  local out = {}
  for i, t in ipairs(list) do out[i] = t.kind .. "=" .. t.severity end
  return table.concat(out, ",")
end
test.eq(sig(T.for_land(P, dammed.id, 12345)), sig(lt), "deterministic")

-- ------------------------------------------ the checker over many seeds
for seed = 1, 200 do
  local R = gen.run.new(gen.cosmos, { seed = seed, mods = {} })
  local p = follow(R, "u" .. (1 + seed % 9) .. ".g" .. (seed % 7))
  if seed % 10 == 0 or p then test.eq(#gen.check.run(R), 0, "the checker passes for seed " .. seed) end
end
test.eq(#gen.check.run(G), 0, "the checker passes: echoes, traces and tensions keep their promises")

-- ------------------------------------------------------------ the bible
local md = gen.bible.export(G, l.address)
test.expect(md:find("Today:", 1, true) and md:find("drought", 1, true), "the bible has the planet's present tensions")
test.expect(md:find("**tensions**", 1, true), "and the land's")
local md2 = gen.bible.export(G, land.address)
test.expect(md2:find("Echo:", 1, true), "and the echoes of greater histories")
test.expect(md2:find("**traces**", 1, true), "and the traces in the land")
