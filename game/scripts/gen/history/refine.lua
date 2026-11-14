-- Multiversal Van Life - events refined down the hierarchy (MIT).
--
-- A great event of a galaxy (a war, a fall) is promised to the clusters it
-- touched (`event_ref` commitments). Each cluster passes it on to one of
-- its star systems, each system to one of its worlds, and the world records
-- a local event of it (its echo) and leaves a trace in one of its lands: a
-- wreck or a battlefield of the war, a crater where a power fell. A
-- planet's own history leaves traces too: the ruins of fallen capitals in
-- the style of the culture that built them, battlefields of its wars,
-- shrines to the Wanderer. Lands honour traces by placing them (at most a
-- few, the most famous first).
local R = {}

R.TRACE_LAND = { echo = 116, history = 117, shrine = 115 }

local function pass_on(ctx, pick)
  for _, c in ipairs(ctx:commitments("event_ref")) do
    local data = c.data.data
    local child = pick(data)
    if child then
      local local_data = {}
      for k, v in pairs(data) do local_data[k] = v end
      ctx:commit(child, "event_ref", local_data, c)
    end
    ctx:honour(c, ctx:fact("event", { name = data.name .. " in " .. tostring(ctx.summary.name), kind = data.kind,
                                      year = data.year }, c))
  end
end

-- Galaxy: promise the great events to the clusters they touched.
function R.galaxy(ctx)
  local h = ctx.data.history
  if not h then return end
  local n = 0
  for _, ev in ipairs(h.events) do
    if (ev.kind == "war" or ev.kind == "collapse") and ev.importance >= 0.6 and n < 20 then
      for i, place in ipairs(ev.places or {}) do
        if i <= 2 and ctx.node.children[place] then
          n = n + 1
          ctx:commit(place, "event_ref", { name = ev.name, kind = ev.kind, year = ev.year,
                                           source = ctx.node.address, event = ev.fact }, ev.fact)
        end
      end
    end
  end
end

-- Cluster: to one of its star systems.
function R.cluster(ctx)
  pass_on(ctx, function(data)
    local stars = ctx.data.stars or 0
    if stars == 0 then return nil end
    return mvl.hash(ctx.seed, data.name) % stars
  end)
end

-- System: to its rocky world (or its first world).
function R.system(ctx)
  pass_on(ctx, function()
    local best
    for i = 0, (ctx.data.planets or 0) - 1 do
      if ctx.node.children[i].kind == "rocky" and not best then best = i end
    end
    if not best and (ctx.data.planets or 0) > 0 then best = 0 end
    return best
  end)
end

-- Planet: the echoes of great events, and traces in its lands.
function R.planet(ctx)
  local d = ctx.data
  d.echoes = {}
  for _, c in ipairs(ctx:commitments("event_ref")) do
    local data = c.data.data
    -- local participants: the powers of this world at the time, or the
    -- forebears of its peoples when the event is older than their history
    local who = {}
    for _, f in pairs(d.history and d.history.factions or {}) do
      if f.founded <= data.year and (not f.ended or f.ended >= data.year) then who[#who + 1] = f.name end
    end
    table.sort(who)
    if #who == 0 then
      for _, cul in ipairs(d.cultures or {}) do who[#who + 1] = "the forebears of the " .. cul.name end
    end
    local id = ctx:fact("event", { name = data.name .. " over " .. ctx.summary.name, kind = "echo", year = data.year,
                                   war = data.kind, factions = who }, c)
    local echo = { name = data.name .. " over " .. ctx.summary.name, year = data.year, kind = data.kind, fact = id,
                   source = data.source, source_event = data.event, participants = who }
    d.echoes[#d.echoes + 1] = echo
    ctx:honour(c, id)
    -- a trace in one of its lands
    local countries = d.countries or {}
    if #countries > 0 then
      local k = mvl.hash(ctx.seed, data.name) % #countries + 1
      local cty = countries[k]
      local kind = data.kind == "war" and (mvl.hash(ctx.seed, data.name, "wreck") % 2 == 0 and "wreck" or "battlefield")
                   or "crater"
      local target = ctx.node.address .. ".k" .. (cty.continent - 1) .. ".n" .. cty.index .. ".l" .. R.TRACE_LAND.echo
      ctx:commit(target, "trace", { kind = kind, name = (kind == "crater" and "the crater of " or "the wreck of ") ..
                                    data.name:gsub("^the ", ""), year = data.year, event = echo.name }, id)
      echo.trace = target
    end
  end
end

-- Traces of a planet's own history (called by the planet history).
function R.planet_traces(ctx, st, cultures, countries)
  local placed, used = 0, {}
  local list = {}
  for _, ev in ipairs(st.events) do
    if ev.kind == "collapse" or ev.kind == "war" or ev.kind == "sighting" then list[#list + 1] = ev end
  end
  table.sort(list, function(a, b) return a.importance > b.importance or (a.importance == b.importance and a.id < b.id) end)
  for _, ev in ipairs(list) do
    if placed >= 6 then break end
    local f = st.factions[ev.participants[1]]
    local region = ev.kind == "war" and (ev.places and ev.places[1]) or (f and f.capital)
    local cty = region and countries[region]
    local land = ev.kind == "sighting" and R.TRACE_LAND.shrine or R.TRACE_LAND.history
    if cty and not used[region .. ":" .. land] and (ev.kind ~= "sighting" or ctx:random("shrine" .. ev.id):chance(0.5)) then
      used[region .. ":" .. land] = true
      local cul = f and cultures[f.culture]
      local kind = ev.kind == "collapse" and "ruin" or (ev.kind == "war" and "battlefield" or "shrine")
      local data = { kind = kind, year = ev.year, event = ev.name, culture = cul and cul.name,
                     style = cul and cul.style and require("gen.util").copy(cul.style),
                     name = kind == "ruin" and ("the ruins of " .. (cty.name or "a city")) or
                            (kind == "battlefield" and ("the field of " .. ev.name:gsub("^the ", "")) or
                             "a shrine to the Wanderer") }
      if kind == "ruin" then cty.ruins = data.name end
      local target = ctx.node.address .. ".k" .. (cty.continent - 1) .. ".n" .. cty.index .. ".l" .. land
      ctx:commit(target, "trace", data, ev.fact)
      placed = placed + 1
    end
  end
end

return R
