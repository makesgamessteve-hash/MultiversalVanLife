"""Checks that the sample mod shown in docs/MODDING.md is exactly the one
tests/game/test_mods.lua runs (tests/game/mods/sample_mod/init.lua)."""
import sys

doc, mod = sys.argv[1], sys.argv[2]
lines = open(doc, encoding="utf-8").read().splitlines()
start = lines.index("<!-- sample_mod -->") + 2
end = lines.index("```", start)
shown = "\n".join(lines[start:end]) + "\n"
actual = open(mod, encoding="utf-8").read()
if shown != actual:
    print("docs/MODDING.md shows a different sample mod than %s" % mod)
    sys.exit(1)
print("documented sample mod matches")
