"""Checks colour fractions in regions of screenshots taken by OpenGL tests.

usage: check_shot.py SHOT_DIR CHECKS.json

CHECKS.json is a list of checks:
  {"file": "decal.tga", "region": [x0, y0, x1, y1],   # fractions of the image
   "min": {"red": 0.9}, "max": {"green": 0.001}}
Colour classes: red, green, blue (channel dominates the others by 40), dark
(all channels below 40) and cool (blue above red by 25, like water).
"""
import json
import os
import struct
import sys


def load_tga(path):
    data = open(path, "rb").read()
    idlen, cmap, kind = data[0], data[1], data[2]
    w, h = struct.unpack("<HH", data[12:16])
    bits, desc = data[16], data[17]
    if kind != 2 or cmap != 0 or bits != 32:
        raise ValueError("unsupported TGA %s" % path)
    px = data[18 + idlen:]
    top = desc & 0x20

    def pixel(x, y):
        row = y if top else h - 1 - y
        i = (row * w + x) * 4
        return px[i + 2], px[i + 1], px[i]  # BGRA -> RGB

    return w, h, pixel


def classify(r, g, b):
    out = set()
    if r > g + 40 and r > b + 40:
        out.add("red")
    if g > r + 40 and g > b + 40:
        out.add("green")
    if b > r + 40 and b > g + 40:
        out.add("blue")
    if r < 40 and g < 40 and b < 40:
        out.add("dark")
    if b > r + 25:
        out.add("cool")
    return out


def main():
    shot_dir, checks = sys.argv[1], json.load(open(sys.argv[2]))
    failed = 0
    for c in checks:
        w, h, pixel = load_tga(os.path.join(shot_dir, c["file"]))
        x0, y0, x1, y1 = c.get("region", [0, 0, 1, 1])
        counts, total = {}, 0
        for y in range(int(y0 * h), max(int(y1 * h), int(y0 * h) + 1)):
            for x in range(int(x0 * w), max(int(x1 * w), int(x0 * w) + 1)):
                total += 1
                for k in classify(*pixel(x, y)):
                    counts[k] = counts.get(k, 0) + 1
        fr = {k: counts.get(k, 0) / float(total) for k in ("red", "green", "blue", "dark", "cool")}
        ok = all(fr[k] >= v for k, v in c.get("min", {}).items()) and all(fr[k] <= v for k, v in c.get("max", {}).items())
        print("%s %s region=%s fractions=%s" % ("ok  " if ok else "FAIL", c["file"], c.get("region"),
                                               {k: round(v, 4) for k, v in fr.items()}))
        failed += 0 if ok else 1
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
