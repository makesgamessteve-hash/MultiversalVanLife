-- Multiversal Van Life - villagers talk like their people and remember (MIT).
-- Lines come from the dialogue grammar (gen/dialogue/grammar.lua) filled
-- with the land's lore and what the speaker remembers of the player
-- (memory/characters.lua); every conversation is remembered.
local dialogue = require("lib.dialogue")
local characters = require("memory.characters")
local grammar = require("gen.dialogue.grammar")
local spread = require("memory.spread")
local progress = require("lib.progress")

local T = {}

T.COLOR = { 0.85, 0.85, 1 }

-- Says lines (a string or a list) as `who`; `on_done` runs afterwards.
function T.say(who, text, on_done, color)
  if type(text) ~= "table" then text = { text } end
  local lines = {}
  for i, t in ipairs(text) do
    lines[i] = { speaker = "villager", name = who, text = t, color = color or T.COLOR }
  end
  dialogue.say(lines, on_done)
end

-- What person `p` of land `node` says now (a list of lines); counts the talk.
-- They tell what changed since the player's last visit (once), and know the
-- player from the stories that reached them.
function T.lines(w, node, p, opts)
  local log = w:memory()
  local mem = characters.memory(log, p.id)
  local rec = characters.get(log, p.id)
  local am = log.aftermath
  if am and am.stamp and rec.stamp ~= am.stamp and am.news[1] then
    mem.change, rec.stamp = am.news[1], am.stamp
  end
  if not (log.community and log.community.known_as) then
    local lore = node.data.lore or {}
    local heard = spread.heard(node.address, lore.culture, lore.nation, progress.night())[1]
    if heard then mem.rumour, mem.rumour_rule, mem.known_as = heard.told, heard.rule, heard.title end
  end
  local n = characters.meet(log, p.id)
  return grammar.talk(require("gen").cosmos, node.data.lore, mem, mvl.hash(node.seed, p.id), n, opts)
end

-- A villager's conversation.
function T.villager(w, node, p, opts)
  T.say(p.name, T.lines(w, node, p, opts))
end

return T
