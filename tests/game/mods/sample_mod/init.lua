-- Example mod used by tests/game/test_mods.lua and docs/MODDING.md: a new
-- kind of trouble that generated lands can have.
local gen = require("gen")

gen.cosmos:content("quest_templates", {
  { id = "moonberries", w = 1, kind = "gather", short = "the moonberry harvest spilled",
    part = "moonberry", item = "flowers",
    intro = { "The {folk} of {place} pick moonberries only on nights like this one.",
              "But the baskets tipped over on the hill! Could you find all {n} {part}s?" },
    progress = "{left} {part}s are still out there.",
    done = "A full basket! The {folk} will feast tonight, thanks to you.",
    deed = "saved the moonberry harvest" },
})

-- and a saying villagers may use (see the dialogue grammar in MODDING.md)
gen.cosmos:content("dialogue_rules", {
  { idiom = { "Moonberries ripen for the patient, my mother always said." } },
})

-- and what grows where the harvest was saved, a night later (an aftermath
-- rule that leaves a mark, see "Time passing" in MODDING.md)
gen.cosmos:content("aftermath_rules", {
  { id = "moonberry_bushes", after = 1,
    when = function(x) return x.success and x.outcome.template == "moonberries" end,
    apply = function(x)
      local sx, sz = x:spot(6, 10)
      x:mark({ mark = "moonberry bushes", sprite = "flowers", x = sx, z = sz, w = 1.4, h = 1.0 })
      x:news("moonberry bushes grow by the square now")
    end },
})
