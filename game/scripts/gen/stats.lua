-- Multiversal Van Life - guards against monotony and slowness (MIT).
--
-- Variety: generates a peopled world from each of many seeds and counts
-- what came out: the biome distributions of the planets (their main land
-- biomes), the body plans of their species, the sources their religions
-- grew from, the technology levels of their peoples and the kinds of
-- tension in their countries. Thresholds ("metric = <= value" or ">=") turn
-- the counts into a test: when more than half of the planets share one
-- biome distribution, the world has become monotonous.
--
-- Budgets: generates places down to a land from many seeds with timing on
-- and compares the median time of every level with its budget ("level =
-- milliseconds"); a level over budget fails, naming its slowest pass.
--
--   mvl_headless --stats 200 --thresholds tests/stats_thresholds.ini
--   mvl_headless --budget 12 --budgets tests/budgets.ini
-- (--bias biome and --delay LEVEL:MS make them fail on purpose)
local S = {}

S.LEVELS = { "multiverse", "universe", "galaxy", "cluster", "system", "planet", "continent", "country", "land" }

-- --------------------------------------------------------------- variety
-- A peopled rocky planet of multiverse G (nil if none was found nearby).
function S.world(G, seed)
  for k = 0, 12 do
    local saddr = "u" .. (1 + (seed + k) % 9) .. ".g" .. ((seed * 7 + k) % 13) .. ".c" .. ((seed + k) % 3) .. ".s" ..
                  ((seed * 3 + k) % 5)
    local ok, sys = pcall(G.generate, G, saddr)
    if ok then
      for i = 0, sys.data.planets - 1 do
        if sys.children[i].kind == "rocky" then
          local p = G:generate(saddr .. ".p" .. i)
          if p.data.cultures and #p.data.cultures > 0 then return p end
        end
      end
    end
  end
end

local function add(t, k) t[k] = (t[k] or 0) + 1 end

-- The main land biomes of planet data P (those with 15% of the land or
-- more, the largest first): its biome distribution.
function S.biome_signature(P)
  local geo = require("gen.levels.geography")
  local land, total = {}, 0
  for id, n in pairs(P.biome_counts or {}) do
    local b = geo.BIOMES[geo.BIOME[id]]
    if b and not b.water then land[#land + 1] = { id = id, n = n } total = total + n end
  end
  table.sort(land, function(a, b) return a.n > b.n or (a.n == b.n and a.id < b.id) end)
  local parts = {}
  for _, x in ipairs(land) do if x.n >= total * 0.15 then parts[#parts + 1] = x.id end end
  return #parts > 0 and table.concat(parts, "+") or "none"
end

-- Counts over `n` seeds (from `first`, default 1).
function S.collect(registry, run, n, first)
  local st = { planets = 0, biome_sig = {}, biomes = {}, body_plans = {}, religion_sources = {}, tech_levels = {},
               tension_kinds = {} }
  first = first or 1
  for seed = first, first + n - 1 do
    local G = run.new(registry, { seed = seed, mods = {} })
    local p = S.world(G, seed)
    if p then
      local P = p.data
      st.planets = st.planets + 1
      add(st.biome_sig, S.biome_signature(P))
      for id in pairs(P.biome_counts or {}) do add(st.biomes, id) end
      for _, sp in ipairs(P.life and P.life.species or {}) do
        if sp.kind == "animal" then add(st.body_plans, (sp.limbs or 0) .. " limbs/" .. tostring(sp.covering) .. "/" ..
                                       tostring(sp.move)) end
      end
      for _, s in ipairs(P.life and P.life.sapients or {}) do
        local a = s.anatomy or {}
        add(st.body_plans, "sapient " .. (a.limbs or 0) .. "/" .. (a.hands or 0) .. (a.wings and "/wings" or ""))
      end
      for _, r in pairs(P.religions or {}) do
        for _, m in ipairs(r.motifs or {}) do add(st.religion_sources, m.source) end
      end
      for _, c in ipairs(P.cultures or {}) do add(st.tech_levels, c.tech and c.tech.level or 0) end
      for _, c in ipairs(P.countries or {}) do
        for _, t in ipairs(c.tensions or {}) do add(st.tension_kinds, t.kind) end
      end
    end
  end
  return st
end

local function distinct(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

local function max_share(t)
  local total, best = 0, 0
  for _, v in pairs(t) do total, best = total + v, math.max(best, v) end
  return total > 0 and best / total or 0
end

-- The metrics thresholds are written against.
function S.metrics(st)
  return {
    planets = st.planets,
    biome_distribution_share = max_share(st.biome_sig), biome_distributions = distinct(st.biome_sig),
    biomes = distinct(st.biomes),
    body_plans = distinct(st.body_plans), body_plan_share = max_share(st.body_plans),
    religion_sources = distinct(st.religion_sources), religion_source_share = max_share(st.religion_sources),
    tech_levels = distinct(st.tech_levels),
    tension_kinds = distinct(st.tension_kinds), tension_kind_share = max_share(st.tension_kinds),
  }
end

-- Parses "metric = <= value" lines (comments with ; or #, [sections]).
function S.parse(text)
  local out = {}
  for line in (text or ""):gmatch("[^\n]+") do
    line = line:gsub("[;#].*$", "")
    local k, op, v = line:match("^%s*([%w_%.]+)%s*=%s*([<>]=)%s*([%d%.]+)")
    if k then out[#out + 1] = { metric = k, op = op, value = tonumber(v) } end
  end
  return out
end

-- Failures of `metrics` against `thresholds`: { "metric: 0.7 > 0.5", ... }.
function S.check(metrics, thresholds)
  local fail = {}
  for _, t in ipairs(thresholds) do
    local v = metrics[t.metric]
    if v == nil then
      fail[#fail + 1] = t.metric .. ": unknown metric"
    elseif (t.op == "<=" and v > t.value) or (t.op == ">=" and v < t.value) then
      fail[#fail + 1] = string.format("%s: %.3f, wanted %s %.3f", t.metric, v, t.op, t.value)
    end
  end
  return fail
end

-- A report of the counts (the most common first).
function S.report(st)
  local out = {}
  for _, k in ipairs({ "biome_sig", "body_plans", "religion_sources", "tech_levels", "tension_kinds" }) do
    local list = {}
    for name, n in pairs(st[k]) do list[#list + 1] = { name = tostring(name), n = n } end
    table.sort(list, function(a, b) return a.n > b.n or (a.n == b.n and a.name < b.name) end)
    local parts = {}
    for i = 1, math.min(8, #list) do parts[i] = list[i].name .. " " .. list[i].n end
    out[#out + 1] = string.format("%s (%d kinds): %s", k, #list, table.concat(parts, ", "))
  end
  return table.concat(out, "\n")
end

-- A deliberately biased generator (to see the variety test fail): every
-- land cell of every planet gets the same biome. Returns a function that
-- undoes it.
function S.bias(registry, what)
  assert(what == "biome", "the only bias is 'biome'")
  local levels = registry:level("planet")
  local pass = registry.passes[levels.n].biomes
  local run = pass.run
  pass.run = function(ctx)
    run(ctx)
    local d = ctx.data
    if d.cells and d.cells.biome then
      local geo = require("gen.levels.geography")
      local desert = geo.BIOME["hot desert"]
      local counts = {}
      for i = 1, #d.cells.biome do
        local b = geo.BIOMES[d.cells.biome[i]]
        if not b.water then d.cells.biome[i] = desert end
        local id = geo.BIOMES[d.cells.biome[i]].id
        counts[id] = (counts[id] or 0) + 1
      end
      d.biome_counts = counts
    end
  end
  return function() pass.run = run end
end

-- An artificially slow pass on `level` (to see the budget test fail): it
-- waits `ms` milliseconds. Returns a function that removes it.
function S.delay(registry, level, ms)
  registry:pass(level, "artificial_delay", { run = function()
    local t0 = os.clock()
    while (os.clock() - t0) * 1000 < ms do end
  end })
  return function() registry:remove_pass(level, "artificial_delay") end
end

-- --------------------------------------------------------------- budgets
-- Times every level and pass over `n` seeds, generating a land of a
-- peopled world each time. Returns { level = { median, passes = {name =
-- median} } } in milliseconds.
function S.time(registry, run, n)
  local per = {}
  for seed = 1, n do
    local G = run.new(registry, { seed = seed, mods = {} })
    G.timing = {}
    local p = S.world(G, seed)
    if p then
      local c = p.data.countries and p.data.countries[1]
      if c then G:generate(p.address .. ".k" .. (c.continent - 1) .. ".n" .. c.index .. ".l" .. (seed % 40)) end
    end
    for level, list in pairs(G.timing) do
      per[level] = per[level] or {}
      for _, t in ipairs(list) do table.insert(per[level], t) end
    end
  end
  local out = {}
  local function median(xs)
    table.sort(xs)
    return xs[math.max(1, math.ceil(#xs / 2))] or 0
  end
  for level, list in pairs(per) do
    local totals, passes = {}, {}
    for _, t in ipairs(list) do
      totals[#totals + 1] = t.total * 1000
      for name, dt in pairs(t.passes) do
        passes[name] = passes[name] or {}
        table.insert(passes[name], dt * 1000)
      end
    end
    local pm = {}
    for name, xs in pairs(passes) do pm[name] = median(xs) end
    out[level] = { median = median(totals), passes = pm, count = #list }
  end
  return out
end

-- Failures of timings against budgets ({ { metric = level, value = ms } }).
function S.over(times, budgets)
  local fail = {}
  for _, b in ipairs(budgets) do
    local t = times[b.metric]
    if t and t.median > b.value then
      local slow, ms = "?", -1
      for name, v in pairs(t.passes) do if v > ms or (v == ms and name < slow) then slow, ms = name, v end end
      fail[#fail + 1] = string.format("level %s takes %.1f ms, over its budget of %.1f ms (slowest pass: %s, %.1f ms)",
                                      b.metric, t.median, b.value, slow, ms)
    end
  end
  return fail
end

-- ------------------------------------------------------------------- CLI
local function finish(lines, fail)
  for _, l in ipairs(lines) do print(l) end
  for _, f in ipairs(fail) do print("FAIL " .. f) end
  if mvl.option("out") then mvl.write_option_file("out", table.concat(lines, "\n") .. "\n") end
  mvl.quit()
  if #fail > 0 then error(#fail .. " check(s) failed:\n" .. table.concat(fail, "\n"), 0) end
end

function S.cli(registry, run)
  local gen = require("gen")
  -- variety is counted on coarser planets (faster, the same choices);
  -- budgets are measured at the game's own resolution
  gen.planet.LEVEL = tonumber(mvl.option("level") or "") or (mvl.option("stats") and 3 or gen.planet.LEVEL)
  if mvl.option("stats") then
    local undo = mvl.option("bias") and S.bias(registry, mvl.option("bias"))
    local st = S.collect(registry, run, tonumber(mvl.option("stats")) or 200)
    if undo then undo() end
    local m = S.metrics(st)
    local lines = { S.report(st) }
    local keys = {}
    for k in pairs(m) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do lines[#lines + 1] = string.format("%-26s %s", k, tostring(m[k])) end
    finish(lines, S.check(m, S.parse(mvl.read_option_file("thresholds"))))
  else
    local delay = mvl.option("delay")
    local undo
    if delay then
      local level, ms = delay:match("^(%w+):(%d+)$")
      undo = S.delay(registry, level, tonumber(ms))
    end
    local times = S.time(registry, run, tonumber(mvl.option("budget")) or 12)
    if undo then undo() end
    local lines = {}
    for _, level in ipairs(S.LEVELS) do
      local t = times[level]
      if t then
        local slow, ms = "?", -1
        for name, v in pairs(t.passes) do if v > ms then slow, ms = name, v end end
        lines[#lines + 1] = string.format("%-11s median %8.2f ms over %3d places (slowest pass %s %.2f ms)", level,
                                          t.median, t.count, slow, ms)
      end
    end
    finish(lines, S.over(times, S.parse(mvl.read_option_file("budgets"))))
  end
end

return S
