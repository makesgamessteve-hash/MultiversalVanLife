-- Multiversal Van Life - history on every level (MIT).
-- See gen/history/*.lua and docs/WORLDGEN.md.
local engine = require("gen.history.engine")
local events = require("gen.history.events")
local planet = require("gen.history.planet")
local cosmos = require("gen.history.cosmos")
local prime = require("gen.prime")

local H = { engine = engine, events = events, planet = planet, cosmos = cosmos }

local function ago(year)
  local y = -year
  if y >= 1e9 then return string.format("%.1f billion years ago", y / 1e9) end
  if y >= 1e6 then return string.format("%.0f million years ago", y / 1e6) end
  if y >= 1 then return string.format("%d years ago", math.floor(y + 0.5)) end
  return "now"
end
H.ago = ago

-- A paragraph for the world bible.
function H.describe(h)
  if not h then return nil end
  local out = { string.format("History (%s, steps of %s years, from %s):", h.level, tostring(h.step), ago(h.start)) }
  for _, era in ipairs(h.eras) do
    local ev = era.defining and h.events[era.defining]
    out[#out + 1] = string.format("- **%s** (%s to %s)%s", era.name:sub(1, 1):upper() .. era.name:sub(2), ago(era.from),
                                  ago(era.to), ev and (": " .. ev.name) or "")
  end
  local notable = {}
  for _, ev in ipairs(h.events) do if ev.importance >= 0.5 then notable[#notable + 1] = ev end end
  table.sort(notable, function(a, b) return a.importance > b.importance or (a.importance == b.importance and a.id < b.id) end)
  local lines = {}
  for i = 1, math.min(8, #notable) do lines[i] = notable[i].name .. " (" .. ago(notable[i].year) .. ")" end
  if #lines > 0 then out[#out + 1] = "Great events: " .. table.concat(lines, "; ") .. "." end
  local now = {}
  for _, f in pairs(h.factions) do
    if f.alive then
      local held = 0
      for _, o in pairs(h.territories) do if o == f.id then held = held + 1 end end
      now[#now + 1] = string.format("%s (%d)", f.name, held)
    end
  end
  table.sort(now)
  out[#out + 1] = "Powers today: " .. (#now > 0 and table.concat(now, ", ") or "none") .. "."
  local living = {}
  for _, p in ipairs(h.individuals) do
    if not p.died and #p.deeds > 0 and #living < 6 then
      living[#living + 1] = string.format("%s the %s (born %s)", p.name, p.role, ago(p.born))
    end
  end
  if #living > 0 then out[#out + 1] = "Living legends: " .. table.concat(living, "; ") .. "." end
  if h.lore then out[#out + 1] = h.lore end
  return table.concat(out, "\n")
end

local function wrap(R, level)
  local prev = R:level(level).describe
  R:describe(level, function(node)
    local text = prev and prev(node) or tostring(node.summary.name)
    local hist = H.describe(node.data.history)
    return hist and (text .. "\n\n" .. hist) or text
  end)
end

function H.register(R)
  R:pass("universe", "history", { after = { "galaxies" }, run = cosmos.universe })
  R:pass("galaxy", "history", { after = { "clusters" }, run = cosmos.galaxy })
  R:pass("cluster", "history", { after = { "spacefarers" }, run = cosmos.cluster })
  R:pass("planet", "history", { after = { "cultures" }, run = function(ctx)
    if ctx.summary.prime then return end
    planet.run(ctx)
  end })
  for _, level in ipairs({ "universe", "galaxy", "cluster", "planet" }) do wrap(R, level) end

  -- events in order; people live their lifespans and do their deeds alive
  R:check("chronology", function(node, report)
    local h = node.data.history
    if not h then return end
    local last = -math.huge
    for _, ev in ipairs(h.events) do
      if ev.year < last - h.step then report(node.address .. ": " .. ev.name .. " is out of order") return end
      last = math.max(last, ev.year)
    end
    for _, p in ipairs(h.individuals) do
      local death = p.died or 0
      if p.died and p.died <= p.born then report(node.address .. ": " .. p.name .. " died before being born") end
      if death - p.born > p.lifespan + 1 then report(node.address .. ": " .. p.name .. " outlived their lifespan") end
      for _, eid in ipairs(p.deeds) do
        local ev = h.events[eid]
        if ev.year < p.born - h.step or ev.year > death + h.step then
          report(node.address .. ": " .. p.name .. " acted outside their life")
        end
      end
    end
  end)
  -- Earth is a quiet world: no history touches Prime
  R:check("quiet_prime", function(node, report)
    if prime.inside(node.address) and node.data.history then report(node.address .. ": history in Prime") end
    local h = node.data.history
    for _, ev in ipairs(h and h.events or {}) do
      for _, a in ipairs(ev.addresses or {}) do
        if type(a) == "string" and prime.inside(a) then report(node.address .. ": an event in Prime") end
      end
    end
  end)
end

return H
