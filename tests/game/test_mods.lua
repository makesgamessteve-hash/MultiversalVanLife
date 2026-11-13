-- A mod folder can add a new destination without touching the base game.
local mods = mvl.mods()
test.eq(mods[1], "sample_mod", "mod enabled")
test.expect(game.debug.world.get("sample_meadow"), "mod registered a world")
H.new_game_in_van()
H.travel("Sample Meadow")
H.step_outside()
test.eq(H.current(), "sample_meadow", "visited the mod world")
