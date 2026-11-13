-- Multiversal Van Life - star clusters: kind, stars and travel lanes (MIT).
-- Positions inside a cluster are parsecs from its centre.
local dm = require("gen.dmath")
local names = require("gen.names")
local prime = require("gen.prime")
local util = require("gen.util")

local cluster = {}

local SIZES = { open = { 6, 24, 4 }, globular = { 24, 60, 18 }, nursery = { 8, 32, 7 } } -- min, max stars, radius

-- Spectral class of a main-sequence star of this mass (solar masses).
function cluster.class(m)
  if m >= 16 then return "O" elseif m >= 2.1 then return "B" elseif m >= 1.4 then return "A"
  elseif m >= 1.04 then return "F" elseif m >= 0.8 then return "G" elseif m >= 0.45 then return "K" end
  return "M"
end

function cluster.luminosity(m)
  return m > 0.43 and dm.pow(m, 3.5) or 0.23 * dm.pow(m, 2.3)
end

-- Stars heavier than this have already died in a population this old.
function cluster.turnoff(age) return dm.clamp(dm.pow(10 / math.max(age, 0.001), 0.4), 0.8, 60) end

-- A mass from the Salpeter mass function between 0.1 and max solar masses.
function cluster.mass(rng, max)
  local a, b = dm.pow(0.1, -1.35), dm.pow(max, -1.35)
  return dm.pow(a + rng:next() * (b - a), -1 / 1.35)
end

-- Relative neighbourhood graph: i and j are linked unless some k is closer
-- to both of them than they are to each other.
function cluster.rng_graph(points, max_dist, yield)
  local n, d = #points, {}
  for i = 1, n do
    d[i] = {}
    for j = 1, n do
      local a, b = points[i], points[j]
      local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]
      d[i][j] = math.sqrt(dx * dx + dy * dy + dz * dz)
    end
  end
  local edges = {}
  for i = 1, n - 1 do
    for j = i + 1, n do
      local dij = d[i][j]
      if not max_dist or dij <= max_dist then
        local ok = true
        for k = 1, n do
          if k ~= i and k ~= j and math.max(d[i][k], d[j][k]) < dij then ok = false break end
        end
        if ok then edges[#edges + 1] = { i - 1, j - 1, dm.round(dij, 3) } end
      end
    end
    if yield then yield() end
  end
  return edges
end

function cluster.register(R)
  R:pass("cluster", "prime", { run = function(ctx)
    if not ctx.summary.prime then return end
    for k, v in pairs(prime.neighbourhood) do ctx.data[k] = v end
    ctx.data.prime, ctx.data.lanes = true, {}
    local sun = util.copy(prime.sun)
    sun.prime = true
    ctx:child(0, sun)
  end })

  R:pass("cluster", "kind", { after = { "prime" }, run = function(ctx)
    if ctx.summary.prime then return end
    local rng, s, g = ctx:rng(), ctx.summary, ctx.parent.data
    local kind = "open"
    if s.in_core or (s.age > 0.8 * g.age and rng:chance(0.5)) then kind = "globular"
    elseif s.in_arm and rng:chance(0.6) then kind = "nursery" end
    ctx.data.kind = kind
    ctx.data.age = kind == "nursery" and dm.round(math.min(s.age, 0.02 + rng:next() * 0.08), 4) or s.age
    ctx.data.metallicity = s.metallicity
    ctx.data.radius = dm.round(SIZES[kind][3] * (0.7 + rng:next() * 0.6), 3)
  end })

  R:pass("cluster", "stars", { after = { "kind" }, run = function(ctx)
    if ctx.summary.prime then return end
    local rng, d = ctx:rng(), ctx.data
    local size = SIZES[d.kind]
    local count = rng:int(size[1], size[2])
    local max = cluster.turnoff(d.age)
    local stars = {}
    for i = 1, count do
      local m = cluster.mass(rng, max)
      local x, y, z
      repeat
        x, y, z = rng:next() * 2 - 1, rng:next() * 2 - 1, rng:next() * 2 - 1
      until x * x + y * y + z * z <= 1
      local companion = rng:chance(0.35) and cluster.class(cluster.mass(rng, m)) or nil
      stars[i] = {
        name = names.star(ctx:random("star" .. i)), class = cluster.class(m), mass = dm.round(m, 4),
        luminosity = dm.round(cluster.luminosity(m), 5), age = d.age,
        metallicity = dm.round(d.metallicity + dm.normal(rng, 0, 0.05), 3),
        pos = { dm.round(x * d.radius, 3), dm.round(y * d.radius, 3), dm.round(z * d.radius, 3) },
        companion = companion,
      }
    end
    for i, star in ipairs(stars) do ctx:child(i - 1, star) end
    d.stars = count
  end })

  -- Lanes exist only in universes with faster-than-light travel: gates
  -- link neighbours, jump drives reach neighbours within their range.
  R:pass("cluster", "lanes", { after = { "stars" }, run = function(ctx)
    if ctx.summary.prime then return end
    local laws = ctx:ancestor("universe").data.laws
    ctx.data.lanes = {}
    if laws.ftl == "none" then return end
    local points = {}
    for i = 0, ctx.data.stars - 1 do points[i + 1] = ctx.node.children[i].pos end
    local edges = cluster.rng_graph(points, laws.ftl == "jumps" and laws.jump_range or nil, function() ctx:yield() end)
    for i, e in ipairs(edges) do ctx.data.lanes[i] = { a = e[1], b = e[2], d = e[3], kind = laws.ftl == "gates" and "gate" or "jump" } end
  end })

  R:check("lanes", function(node, report, G)
    if node.kind ~= "cluster" or not node.data.lanes then return end
    local universe = G.nodes[node.address:match("^(u%d+)")]
    if universe.data.laws.ftl == "none" and #node.data.lanes > 0 then
      report(node.address .. ": travel lanes in a universe without faster-than-light travel")
    end
    for _, l in ipairs(node.data.lanes) do
      if not node.children[l.a] or not node.children[l.b] then report(node.address .. ": lane to a missing star") end
    end
  end)

  R:describe("cluster", function(node)
    local d = node.data
    if d.prime then return "The Solar neighbourhood, home of the Sun." end
    return string.format("A%s %s cluster of %d stars, %.2f billion years old, %.1f parsecs across, metallicity %.2f; %s.",
                         d.kind == "open" and "n" or "", d.kind, d.stars, d.age, 2 * d.radius, d.metallicity,
                         #d.lanes == 0 and "no travel lanes" or (#d.lanes .. " travel lanes"))
  end)
end

return cluster
