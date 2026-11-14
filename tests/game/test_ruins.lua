-- Ruins and traces: a city that fell in an older era lies in ruins in the
-- land where it stood, built in the style of the culture that raised it;
-- battlefields, wrecks, craters and shrines are voxel models too.
local D = game.debug
local gen = D.gen
local B = require("gen.visuals.buildings")
local TR = require("gen.visuals.traces")
local chunks = require("gen.chunks")

-- the trace models
local hashes = {}
for _, kind in ipairs({ "battlefield", "wreck", "crater", "shrine" }) do
  local mesh, foot, hash = TR.mesh({ trace = kind, seed = 1 })
  test.expect(mesh and hash, kind .. " is a voxel model")
  test.expect(not hashes[hash], kind .. " looks like nothing else")
  hashes[hash] = true
  if kind == "battlefield" then test.eq(foot, nil, "a battlefield can be walked over") else test.expect(foot, kind .. " is solid") end
end

gen.planet.LEVEL = 3
H.new_game_in_van(2026)
local G = gen.world
local target, ruin, planet
for s = 0, 900 do
  local saddr = "u" .. (1 + s % 9) .. ".g" .. (s % 11) .. ".c" .. (s % 3) .. ".s" .. (s % 5)
  local ok, sys = pcall(G.generate, G, saddr)
  if ok then
    for i = 0, sys.data.planets - 1 do
      if not target and sys.children[i].kind == "rocky" then
        local p = G:generate(saddr .. ".p" .. i)
        local h = p.data.history
        local older = h and h.eras[#h.eras].from
        for addr, ids in pairs(p.commits) do
          for _, id in ipairs(ids) do
            local c = p.facts[id]
            if not target and c.data.kind == "trace" and c.data.data.kind == "ruin" and c.data.data.year < older then
              target, ruin, planet = addr, c, p
            end
          end
        end
      end
    end
  end
  if target then break end
end
test.expect(target, "a city fell in an older era")
-- where the city stood: the capital country of the fallen nation
local h = planet.data.history
local fell
for _, ev in ipairs(h.events) do if ev.fact == ruin.because[1] then fell = ev end end
test.expect(fell and fell.kind == "collapse", "the ruin is of a fall: " .. tostring(fell and fell.name))
test.expect(-fell.year >= 100, "centuries ago: " .. -fell.year .. " years")
local f = h.factions[fell.participants[1]]
local cty = planet.data.countries[f.capital]
test.expect(target:find(".k" .. (cty.continent - 1) .. ".n" .. cty.index .. ".l", 1, true), "at the fallen capital")
local cul = planet.data.cultures[f.culture]
test.eq(chunks.style_key(ruin.data.data.style), chunks.style_key(cul.style), "in the style of its builders")

H.travel_to(target)
H.step_outside()
local w = D.world.current
local d = w.land_node.data
local feat
for _, x in ipairs(d.features) do if x.role == "trace" and x.trace.kind == "ruin" then feat = x end end
test.expect(feat, "the ruins stand in the land: " .. ruin.data.data.name)
test.eq(feat.trace.name, ruin.data.data.name, "named for the city")
test.eq(d.traces[1].name, ruin.data.data.name, "and the land knows what they are")
-- built ruined, in the old style (generated when its chunk is built)
local key = chunks.style_key(feat.trace.style)
D.player.place(feat.x + 8, feat.z + 8, 0)
test.until_true(function()
  for _, e in pairs(w.streamer.models.entries) do if e.key:find("^ruin:") then return true end end
end, 600, "the ruin's chunk is built")
local found
for _, e in pairs(w.streamer.models.entries) do if e.key:find("^ruin:" .. key:gsub("%p", "%%%0")) then found = e end end
test.expect(found, "the ruin is a generated model in the old style")
local _, _, whole = B.mesh("house", feat.trace.style, feat.trace.seed)
local _, _, broken = B.mesh("house", feat.trace.style, feat.trace.seed, true)
test.expect(whole ~= broken, "weathered and broken, not whole")
test.eq(#gen.check.run(G), 0, "the promise of the ruin is kept")
