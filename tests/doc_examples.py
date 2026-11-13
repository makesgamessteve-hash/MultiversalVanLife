"""Runs the Lua examples of a Markdown document inside the real game.

Every ```lua block directly preceded by a `<!-- example -->` line is wrapped
in its own function and executed by the headless runner as a game test, so
documented examples cannot silently go stale.

usage: doc_examples.py RUNNER DATA_DIR WORK_DIR DOC.md [DOC.md ...]
"""
import os
import re
import subprocess
import sys


def extract(path):
    lines = open(path, encoding="utf-8").read().splitlines()
    blocks, i = [], 0
    while i < len(lines):
        if lines[i].strip() == "<!-- example -->" and i + 1 < len(lines) and lines[i + 1].strip() == "```lua":
            j = i + 2
            body = []
            while j < len(lines) and lines[j].strip() != "```":
                body.append(lines[j])
                j += 1
            blocks.append((i + 2, "\n".join(body)))
            i = j
        i += 1
    return blocks


def main():
    runner, data, work, docs = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
    os.makedirs(work, exist_ok=True)
    parts, count = ["test.wait(2)"], 0
    for doc in docs:
        for line, code in extract(doc):
            count += 1
            name = "%s:%d" % (os.path.basename(doc), line)
            parts.append("do\n  local ok, err = pcall(function()\n%s\n  end)\n"
                         "  test.expect(ok, %r .. ': ' .. tostring(err))\nend" % (code, name))
    if count == 0:
        print("no examples found")
        return 1
    script = os.path.join(work, "doc_examples.lua")
    with open(script, "w", encoding="utf-8") as f:
        f.write("\n".join(parts) + "\n")
    save = os.path.join(work, "save")
    os.makedirs(save, exist_ok=True)
    print("running %d documented examples" % count)
    return subprocess.call([runner, "--data", data, "--save", save, "--test", script])


if __name__ == "__main__":
    sys.exit(main())
