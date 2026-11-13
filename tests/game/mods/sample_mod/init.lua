-- Example mod used by tests/game/test_mods.lua and docs/MODDING.md: a new
-- kind of trouble that generated lands can have.
local gen = require("gen")

gen.cosmos:content("quest_templates", {
  { id = "moonberries", w = 1, kind = "gather", short = "the moonberry harvest spilled",
    part = "moonberry", item = "flowers",
    intro = { "The {folk} of {place} pick moonberries only on nights like this one.",
              "But the baskets tipped over on the hill! Could you find all {n} {part}s?" },
    progress = "{left} {part}s are still out there.",
    done = "A full basket! The {folk} will feast tonight, thanks to you." },
})
