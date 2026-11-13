#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# Multiversal Van Life - procedural asset generator
#
# Generates every texture, sprite, model, voxel model and sound used by the game
# into the game/ folder. Standard library only, fully deterministic (fixed seeds):
# running it twice produces byte-identical files.
#
#   python3 tools/gen_assets.py              # regenerate everything into <repo>/game
#   python3 tools/gen_assets.py --out DIR    # write somewhere else
#   python3 tools/gen_assets.py --check      # validate the files already generated
#
# LICENSE: all generated assets (and this script) are original work released under
# Creative Commons Attribution 4.0 International (CC BY 4.0).
# Attribution: "Multiversal Van Life contributors".
# https://creativecommons.org/licenses/by/4.0/
#
# Formats (the engine's loaders depend on these exact layouts):
#   TGA  uncompressed type 2, 32 bpp BGRA, 18-byte header, descriptor 0x28 (top-left)
#   OBJ  v / vt / vn, triangle faces "f a/b/c a/b/c a/b/c", Y up, CCW front faces
#   VOX  MagicaVoxel v150: MAIN{SIZE, XYZI, RGBA}, one model, Z up
#   WAV  PCM 16-bit mono 22050 Hz, peaks about -3 dBFS
# -----------------------------------------------------------------------------

import argparse
import math
import os
import random
import struct
import wave

ATTRIBUTION = "Multiversal Van Life contributors"
LICENSE = "CC BY 4.0"


def clamp(v, lo, hi):
    return lo if v < lo else hi if v > hi else v


def c8(v):
    return int(clamp(round(v), 0, 255))


def mix(a, b, t):
    """Linear blend of two colours (3 or 4 components)."""
    return tuple(c8(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def scale(c, f):
    return tuple(c8(c[i] * f) for i in range(3)) + tuple(c[3:])


def rgba(c, a=255):
    return (c[0], c[1], c[2], c[3] if len(c) > 3 else a)


BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def bayer(x, y):
    """Ordered-dither threshold offset in [-0.5, 0.5)."""
    return BAYER4[y & 3][x & 3] / 16.0 - 0.5


def pick(pal, v, x=0, y=0, dither=0.0):
    """Quantise v in [0,1] onto a palette (dark -> light), optional Bayer dither."""
    n = len(pal)
    v = v * n + bayer(x, y) * dither
    return pal[int(clamp(v, 0, n - 1e-6))]


# =============================================================================
# Image + TGA
# =============================================================================

class Image:
    def __init__(self, w, h, fill=(0, 0, 0, 0)):
        self.w, self.h = w, h
        self.px = [rgba(fill)] * (w * h)

    def get(self, x, y):
        return self.px[y * self.w + x]

    def set(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y * self.w + x] = rgba(tuple(c8(v) for v in c))

    def setw(self, x, y, c):
        """Set with wrap-around (for tileable textures)."""
        self.px[(int(y) % self.h) * self.w + (int(x) % self.w)] = rgba(tuple(c8(v) for v in c))

    def getw(self, x, y):
        return self.px[(int(y) % self.h) * self.w + (int(x) % self.w)]

    def opaque(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h and self.px[y * self.w + x][3] > 0

    # --- drawing primitives (inclusive coordinates) ---
    def rect(self, x0, y0, x1, y1, c):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.set(x, y, c(x, y) if callable(c) else c)

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx = (x + 0.5 - cx) / rx
                dy = (y + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1.0:
                    self.set(x, y, c(x, y) if callable(c) else c)

    def poly(self, pts, c):
        ys = [p[1] for p in pts]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            yc = y + 0.5
            xs = []
            for i in range(len(pts)):
                (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % len(pts)]
                if (y0 <= yc < y1) or (y1 <= yc < y0):
                    xs.append(x0 + (yc - y0) * (x1 - x0) / (y1 - y0))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                for x in range(int(math.ceil(xs[i] - 0.5)), int(math.floor(xs[i + 1] - 0.5)) + 1):
                    self.set(x, y, c(x, y) if callable(c) else c)

    def line(self, x0, y0, x1, y1, c):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / n
            self.set(round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t), c)

    def outline(self, c, diagonal=False):
        """Add a 1px outline around opaque pixels (classic pixel-art look)."""
        add = []
        nb = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        if diagonal:
            nb += [(1, 1), (-1, 1), (1, -1), (-1, -1)]
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y * self.w + x][3] == 0:
                    for dx, dy in nb:
                        if self.opaque(x + dx, y + dy):
                            add.append((x, y))
                            break
        for x, y in add:
            self.set(x, y, c)

    def jitter(self, rng, amount):
        """Per-pixel brightness noise on opaque pixels (retro grain)."""
        for i, p in enumerate(self.px):
            if p[3] > 0:
                f = 1.0 + rng.uniform(-amount, amount)
                self.px[i] = (c8(p[0] * f), c8(p[1] * f), c8(p[2] * f), p[3])


def save_tga(img, path):
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, img.w, img.h, 32, 0x28)
    data = bytearray(header)
    for (r, g, b, a) in img.px:  # rows top to bottom (descriptor bit 5 set)
        data += bytes((b, g, r, a))
    with open(path, "wb") as f:
        f.write(bytes(data))


# =============================================================================
# Tileable noise helpers
# =============================================================================

def noise_grid(w, h, cx, cy, seed, octaves=1, persistence=0.5):
    """Tileable value noise in [0,1]; lattice of cx*cy cells wraps exactly at w,h."""
    out = [[0.0] * w for _ in range(h)]
    amp, total = 1.0, 0.0
    for o in range(octaves):
        ncx, ncy = cx << o, cy << o
        r = random.Random(seed * 7919 + o * 104729)
        lat = [[r.random() for _ in range(ncx)] for _ in range(ncy)]
        for y in range(h):
            fy = y * ncy / h
            y0 = int(fy)
            ty = fy - y0
            ty = ty * ty * (3 - 2 * ty)
            ya, yb = lat[y0 % ncy], lat[(y0 + 1) % ncy]
            row = out[y]
            for x in range(w):
                fx = x * ncx / w
                x0 = int(fx)
                tx = fx - x0
                tx = tx * tx * (3 - 2 * tx)
                x0m, x1m = x0 % ncx, (x0 + 1) % ncx
                a = ya[x0m] + (ya[x1m] - ya[x0m]) * tx
                b = yb[x0m] + (yb[x1m] - yb[x0m]) * tx
                row[x] += amp * (a + (b - a) * ty)
        total += amp
        amp *= persistence
    for row in out:
        for x in range(w):
            row[x] /= total
    return out


def voronoi_grid(w, h, n, seed, jitter=0.7):
    """Tileable Voronoi: returns grid of (d1, d2, cell_index)."""
    r = random.Random(seed)
    pts = []
    for j in range(n):
        for i in range(n):
            lo = 0.5 - jitter / 2
            pts.append(((i + r.uniform(lo, 1 - lo)) * w / n, (j + r.uniform(lo, 1 - lo)) * h / n))
    out = []
    for y in range(h):
        row = []
        for x in range(w):
            best = [(1e9, -1), (1e9, -1)]
            for k, (px, py) in enumerate(pts):
                dx = abs(x + 0.5 - px)
                dy = abs(y + 0.5 - py)
                dx = min(dx, w - dx)
                dy = min(dy, h - dy)
                d = math.sqrt(dx * dx + dy * dy)
                if d < best[0][0]:
                    best = [(d, k), best[0]]
                elif d < best[1][0]:
                    best[1] = (d, k)
            row.append((best[0][0], best[1][0], best[0][1]))
        out.append(row)
    return out


# =============================================================================
# Textures (64x64, seamless)
# =============================================================================

def tex_grass(path):
    S = 64
    rng = random.Random(1001)
    n1 = noise_grid(S, S, 4, 4, 11, 3)
    n2 = noise_grid(S, S, 16, 16, 12, 1)
    pal = [(34, 70, 30), (46, 92, 38), (58, 112, 44), (72, 134, 52), (92, 156, 62)]
    img = Image(S, S)
    for y in range(S):
        for x in range(S):
            v = 0.65 * n1[y][x] + 0.35 * n2[y][x] + rng.uniform(-0.08, 0.08)
            img.set(x, y, pick(pal, v, x, y, 0.8))
    # grass blades: short vertical strokes, light tip, dark root
    for _ in range(170):
        x, y = rng.randrange(S), rng.randrange(S)
        ln = rng.randint(2, 4)
        light = rng.random() < 0.6
        for i in range(ln):
            c = pal[4] if (light and i == ln - 1) else pal[3] if light else pal[0]
            img.setw(x + (i // 2 if rng.random() < 0.3 else 0), y - i, c)
    # a few tiny clover/flower specks
    for _ in range(6):
        x, y = rng.randrange(S), rng.randrange(S)
        img.setw(x, y, (230, 226, 170))
    save_tga(img, path)


def tex_dirt(path):
    S = 64
    rng = random.Random(1002)
    n1 = noise_grid(S, S, 4, 4, 21, 3)
    pal = [(70, 46, 30), (88, 60, 38), (104, 72, 46), (122, 88, 56), (138, 104, 70)]
    img = Image(S, S)
    for y in range(S):
        for x in range(S):
            v = n1[y][x] + rng.uniform(-0.1, 0.1)
            img.set(x, y, pick(pal, v, x, y, 0.9))
    for _ in range(40):  # pebbles with a highlight and a shadow
        x, y = rng.randrange(S), rng.randrange(S)
        sz = rng.choice([1, 1, 2])
        base = rng.choice([(140, 124, 104), (118, 104, 90), (150, 132, 108)])
        for dy in range(sz):
            for dx in range(sz):
                img.setw(x + dx, y + dy, base)
        img.setw(x, y - 1 if sz == 1 else y, scale(base, 1.15))
        img.setw(x + sz, y + sz, pal[0])
    save_tga(img, path)


def tex_cobble(path):
    S = 64
    rng = random.Random(1003)
    vor = voronoi_grid(S, S, 4, 31, 0.6)
    n1 = noise_grid(S, S, 8, 8, 32, 2)
    tints = [(118, 114, 108), (104, 102, 100), (128, 120, 108), (96, 96, 98), (112, 108, 100)]
    stone_col = [tints[rng.randrange(len(tints))] for _ in range(16)]
    mortar = (52, 48, 44)
    img = Image(S, S)
    for y in range(S):
        for x in range(S):
            d1, d2, k = vor[y][x]
            edge = d2 - d1
            if edge < 1.6:
                c = mortar if edge < 1.0 else scale(mortar, 1.3)
            else:
                f = 0.72 + 0.4 * clamp(edge / 7.0, 0, 1) + (n1[y][x] - 0.5) * 0.25
                f += bayer(x, y) * 0.06 + rng.uniform(-0.04, 0.04)
                c = scale(stone_col[k], f)
            img.set(x, y, c)
    save_tga(img, path)


def tex_wood_planks(path):
    S = 64
    rng = random.Random(1004)
    grain = noise_grid(S, S, 2, 16, 41, 2)
    pal = [(86, 54, 30), (104, 66, 36), (122, 80, 44), (140, 94, 54), (158, 110, 64)]
    img = Image(S, S)
    for plank in range(8):
        y0 = plank * 8
        seam = rng.randrange(S)
        tone = rng.uniform(-0.12, 0.12)
        for y in range(y0, y0 + 8):
            for x in range(S):
                ry = y - y0
                g = grain[y][x]
                v = 0.5 + 0.35 * math.sin((ry + g * 6.0) * 1.9) * 0.6 + (g - 0.5) * 0.6 + tone
                if ry == 0:
                    v += 0.18
                c = pick(pal, v, x, y, 0.6)
                if ry == 7:
                    c = (52, 32, 20)
                dx = (x - seam) % S
                if dx == 0:
                    c = (52, 32, 20)
                img.set(x, y, c)
        for nx in (seam + 2, seam - 2):  # nails beside the seam
            img.setw(nx, y0 + 2, (60, 56, 52))
            img.setw(nx, y0 + 5, (60, 56, 52))
        # knot
        if rng.random() < 0.5:
            kx = rng.randrange(S)
            for dx in range(-1, 2):
                img.setw(kx + dx, y0 + 3, pal[0])
            img.setw(kx, y0 + 4, (70, 42, 24))
    save_tga(img, path)


def tex_house_wall(path):
    S = 64
    rng = random.Random(1005)
    n1 = noise_grid(S, S, 4, 4, 51, 2)
    img = Image(S, S)
    shade_rows = [0.70, 1.00, 0.99, 0.97, 0.96, 0.94, 0.92, 0.88]
    for y in range(S):
        ry = y % 8
        for x in range(S):
            base = (236, 234, 224)
            f = shade_rows[ry] + (n1[y][x] - 0.5) * 0.06 + bayer(x, y) * 0.02
            c = scale(base, f)
            img.set(x, y, c)
    for _ in range(26):  # paint wear: tiny grey-wood specks
        x, y = rng.randrange(S), rng.randrange(S)
        if y % 8 != 0:
            img.setw(x, y, (176, 168, 150))
            if rng.random() < 0.4:
                img.setw(x + 1, y, (150, 136, 112))
    save_tga(img, path)


def tex_roof(path):
    S = 64
    rng = random.Random(1006)
    n1 = noise_grid(S, S, 8, 8, 61, 2)
    tints = [(52, 50, 58), (60, 58, 66), (46, 44, 52), (66, 60, 62), (56, 54, 54)]
    img = Image(S, S)
    for row in range(8):
        off = 4 if row % 2 else 0
        cols = [tints[rng.randrange(len(tints))] for _ in range(8)]
        for y in range(row * 8, row * 8 + 8):
            ry = y - row * 8
            for x in range(S):
                k = ((x - off) % S) // 8
                lx = (x - off) % 8
                f = 1.08 - ry * 0.04 + (n1[y][x] - 0.5) * 0.3 + rng.uniform(-0.05, 0.05)
                c = scale(cols[k], f)
                if ry == 7:
                    c = (24, 22, 28)
                elif lx == 0:
                    c = (30, 28, 34)
                img.set(x, y, c)
    save_tga(img, path)


def tex_stone(path):
    S = 64
    rng = random.Random(1007)
    n1 = noise_grid(S, S, 4, 4, 71, 4, 0.55)
    pal = [(78, 78, 82), (96, 96, 100), (114, 114, 116), (132, 130, 128), (150, 148, 144)]
    img = Image(S, S)
    for y in range(S):
        for x in range(S):
            img.set(x, y, pick(pal, n1[y][x] * 1.1 - 0.05 + rng.uniform(-0.05, 0.05), x, y, 1.0))
    for _ in range(5):  # cracks: short random walks
        x, y = rng.randrange(S), rng.randrange(S)
        for _ in range(rng.randint(8, 18)):
            img.setw(x, y, (58, 56, 60))
            img.setw(x + 1, y + 1, pal[3])
            x += rng.choice([-1, 0, 1])
            y += rng.choice([0, 1, 1])
    save_tga(img, path)


def tex_water(path):
    S = 64
    rng = random.Random(1008)
    n1 = noise_grid(S, S, 4, 4, 81, 2)
    pal = [(18, 44, 82), (24, 58, 104), (32, 76, 126), (44, 96, 148), (70, 130, 178)]
    img = Image(S, S)
    tau = 2 * math.pi
    for y in range(S):
        for x in range(S):
            w1 = math.sin(tau * (2 * x / S + 1 * y / S) + n1[y][x] * 4.0)
            w2 = math.sin(tau * (-1 * x / S + 3 * y / S) + n1[(y + 20) % S][(x + 9) % S] * 3.0)
            v = 0.5 + 0.22 * w1 + 0.18 * w2
            c = pick(pal, v, x, y, 0.7)
            if v > 0.88:
                c = (150, 196, 224)
            img.set(x, y, c)
    for _ in range(10):
        x, y = rng.randrange(S), rng.randrange(S)
        img.setw(x, y, (200, 228, 240))
    save_tga(img, path)


def tex_sand(path):
    S = 64
    rng = random.Random(1009)
    n1 = noise_grid(S, S, 4, 4, 91, 3)
    pal = [(176, 150, 104), (192, 166, 116), (206, 182, 130), (218, 196, 144), (230, 210, 160)]
    img = Image(S, S)
    tau = 2 * math.pi
    for y in range(S):
        for x in range(S):
            rip = math.sin(tau * (4 * y / S + 1 * x / S) + n1[y][x] * 3.0) * 0.18
            v = 0.45 + rip + (n1[y][x] - 0.5) * 0.5 + rng.uniform(-0.1, 0.1)
            img.set(x, y, pick(pal, v, x, y, 0.8))
    for _ in range(60):
        x, y = rng.randrange(S), rng.randrange(S)
        img.setw(x, y, rng.choice([(150, 128, 96), (240, 228, 196), (164, 120, 92)]))
    save_tga(img, path)


def tex_metal_panel(path):
    S = 64
    rng = random.Random(1010)
    brush = noise_grid(S, S, 2, 32, 101, 1)
    img = Image(S, S)
    base = (62, 120, 106)
    warm = (86, 128, 100)
    for y in range(S):
        for x in range(S):
            lx, ly = x % 32, y % 32
            panel_tone = 0.96 if ((x // 32) + (y // 32)) % 2 else 1.04
            c = mix(base, warm, 0.25 + (brush[y][x] - 0.5) * 0.6)
            f = panel_tone + bayer(x, y) * 0.04 + rng.uniform(-0.025, 0.025)
            if lx == 0 or ly == 0:
                f = 0.45  # seam
            elif lx == 1 or ly == 1:
                f = 1.30  # bevel highlight
            elif lx == 31 or ly == 31:
                f = 0.70  # bevel shadow
            c = scale(c, f)
            # a thin warm brass inlay line across each panel
            if ly == 16 and 6 <= lx <= 25:
                c = (176, 140, 72)
            if ly == 17 and 6 <= lx <= 25:
                c = (120, 92, 50)
            img.set(x, y, c)
    brass_hi, brass, brass_lo = (250, 214, 130), (204, 158, 78), (120, 86, 40)
    for py in (0, 32):
        for px in (0, 32):
            for rx, ry in ((4, 4), (27, 4), (4, 27), (27, 27), (15, 4), (15, 27)):
                x, y = px + rx, py + ry
                img.set(x, y, brass_hi)
                img.set(x + 1, y, brass)
                img.set(x, y + 1, brass)
                img.set(x + 1, y + 1, brass_lo)
    save_tga(img, path)


def tex_crystal(path):
    S = 64
    rng = random.Random(1011)
    vor = voronoi_grid(S, S, 3, 111, 0.8)
    n1 = noise_grid(S, S, 4, 4, 112, 2)
    pal = [(70, 30, 120), (104, 52, 170), (138, 82, 206), (176, 124, 236), (214, 172, 252)]
    facet = [rng.uniform(0.15, 0.85) for _ in range(9)]
    img = Image(S, S)
    for y in range(S):
        for x in range(S):
            d1, d2, k = vor[y][x]
            edge = d2 - d1
            v = facet[k] + (n1[y][x] - 0.5) * 0.4 + (d1 / 30.0) * -0.2
            c = pick(pal, v, x, y, 1.0)
            if edge < 1.2:
                c = (236, 208, 255)
            elif edge < 2.2:
                c = (196, 150, 250)
            img.set(x, y, c)
    for _ in range(14):  # sparkles
        x, y = rng.randrange(S), rng.randrange(S)
        img.setw(x, y, (255, 250, 255))
        if rng.random() < 0.4:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                img.setw(x + dx, y + dy, (230, 200, 255))
    save_tga(img, path)


def tex_carpet(path):
    S = 64
    rng = random.Random(1012)
    red, orange, cream, teal, dark = (140, 40, 44), (204, 112, 52), (232, 212, 170), (40, 112, 112), (62, 26, 32)
    rings = [cream, red, orange, teal, red, dark, orange, red, teal, red, red]
    img = Image(S, S)
    for y in range(S):
        for x in range(S):
            lx, ly = x % 32, y % 32
            dx, dy = abs(lx - 15.5), abs(ly - 15.5)
            if lx in (0, 31) or ly in (0, 31):
                c = dark
            elif lx in (1, 30) or ly in (1, 30):
                c = cream
            elif lx in (2, 29) or ly in (2, 29):
                c = teal if ((lx + ly) // 2) % 2 else orange
            else:
                d = int(dx + dy)
                c = rings[min(d // 3, len(rings) - 1)]
                if d >= 18:  # corner motifs
                    cd = int(min(lx, 31 - lx) + min(ly, 31 - ly))
                    c = orange if cd < 9 else red
            f = 0.94 if (x + y) % 2 else 1.0  # woven checker
            f += rng.uniform(-0.04, 0.04)
            img.set(x, y, scale(c, f))
    save_tga(img, path)


# =============================================================================
# Font (original 5x7 bitmap font; descenders use the 8th row of the cell)
# =============================================================================

FONT_GLYPHS = {
    " ": ".....",
    "!": "..#.. ..#.. ..#.. ..#.. ..#.. ..... ..#..",
    '"': ".#.#. .#.#. .#.#.",
    "#": ".#.#. .#.#. ##### .#.#. ##### .#.#. .#.#.",
    "$": "..#.. .#### #.#.. .###. ..#.# ####. ..#..",
    "%": "##..# ##..# ...#. ..#.. .#... #..## #..##",
    "&": ".##.. #..#. #.#.. .#... #.#.# #..#. .##.#",
    "'": "..#.. ..#.. .#...",
    "(": "...#. ..#.. .#... .#... .#... ..#.. ...#.",
    ")": ".#... ..#.. ...#. ...#. ...#. ..#.. .#...",
    "*": "..... ..#.. #.#.# .###. #.#.# ..#.. .....",
    "+": "..... ..#.. ..#.. ##### ..#.. ..#.. .....",
    ",": "..... ..... ..... ..... ..... .##.. ..#.. .#...",
    "-": "..... ..... ..... ##### ..... ..... .....",
    ".": "..... ..... ..... ..... ..... .##.. .##..",
    "/": "....# ....# ...#. ..#.. .#... #.... #....",
    "0": ".###. #...# #..## #.#.# ##..# #...# .###.",
    "1": "..#.. .##.. ..#.. ..#.. ..#.. ..#.. .###.",
    "2": ".###. #...# ....# ...#. ..#.. .#... #####",
    "3": "##### ...#. ..#.. ...#. ....# #...# .###.",
    "4": "...#. ..##. .#.#. #..#. ##### ...#. ...#.",
    "5": "##### #.... ####. ....# ....# #...# .###.",
    "6": "..##. .#... #.... ####. #...# #...# .###.",
    "7": "##### ....# ...#. ..#.. .#... .#... .#...",
    "8": ".###. #...# #...# .###. #...# #...# .###.",
    "9": ".###. #...# #...# .#### ....# ...#. .##..",
    ":": "..... .##.. .##.. ..... .##.. .##.. .....",
    ";": "..... .##.. .##.. ..... .##.. ..#.. .#...",
    "<": "...#. ..#.. .#... #.... .#... ..#.. ...#.",
    "=": "..... ..... ##### ..... ##### ..... .....",
    ">": ".#... ..#.. ...#. ....# ...#. ..#.. .#...",
    "?": ".###. #...# ....# ...#. ..#.. ..... ..#..",
    "@": ".###. #...# #.### #.#.# #.##. #.... .####",
    "A": ".###. #...# #...# ##### #...# #...# #...#",
    "B": "####. #...# #...# ####. #...# #...# ####.",
    "C": ".###. #...# #.... #.... #.... #...# .###.",
    "D": "###.. #..#. #...# #...# #...# #..#. ###..",
    "E": "##### #.... #.... ####. #.... #.... #####",
    "F": "##### #.... #.... ####. #.... #.... #....",
    "G": ".###. #...# #.... #.### #...# #...# .####",
    "H": "#...# #...# #...# ##### #...# #...# #...#",
    "I": ".###. ..#.. ..#.. ..#.. ..#.. ..#.. .###.",
    "J": "..### ...#. ...#. ...#. ...#. #..#. .##..",
    "K": "#...# #..#. #.#.. ##... #.#.. #..#. #...#",
    "L": "#.... #.... #.... #.... #.... #.... #####",
    "M": "#...# ##.## #.#.# #.#.# #...# #...# #...#",
    "N": "#...# #...# ##..# #.#.# #..## #...# #...#",
    "O": ".###. #...# #...# #...# #...# #...# .###.",
    "P": "####. #...# #...# ####. #.... #.... #....",
    "Q": ".###. #...# #...# #...# #.#.# #..#. .##.#",
    "R": "####. #...# #...# ####. #.#.. #..#. #...#",
    "S": ".#### #.... #.... .###. ....# ....# ####.",
    "T": "##### ..#.. ..#.. ..#.. ..#.. ..#.. ..#..",
    "U": "#...# #...# #...# #...# #...# #...# .###.",
    "V": "#...# #...# #...# #...# #...# .#.#. ..#..",
    "W": "#...# #...# #...# #.#.# #.#.# #.#.# .#.#.",
    "X": "#...# #...# .#.#. ..#.. .#.#. #...# #...#",
    "Y": "#...# #...# .#.#. ..#.. ..#.. ..#.. ..#..",
    "Z": "##### ....# ...#. ..#.. .#... #.... #####",
    "[": ".###. .#... .#... .#... .#... .#... .###.",
    "\\": "#.... #.... .#... ..#.. ...#. ....# ....#",
    "]": ".###. ...#. ...#. ...#. ...#. ...#. .###.",
    "^": "..#.. .#.#. #...#",
    "_": "..... ..... ..... ..... ..... ..... #####",
    "`": ".#... ..#..",
    "a": "..... ..... .###. ....# .#### #...# .####",
    "b": "#.... #.... #.##. ##..# #...# #...# ####.",
    "c": "..... ..... .###. #.... #.... #...# .###.",
    "d": "....# ....# .##.# #..## #...# #...# .####",
    "e": "..... ..... .###. #...# ##### #.... .###.",
    "f": "..##. .#..# .#... ###.. .#... .#... .#...",
    "g": "..... ..... .#### #...# #...# .#### ....# .###.",
    "h": "#.... #.... #.##. ##..# #...# #...# #...#",
    "i": "..#.. ..... .##.. ..#.. ..#.. ..#.. .###.",
    "j": "...#. ..... ..##. ...#. ...#. ...#. #..#. .##..",
    "k": "#.... #.... #..#. #.#.. ##... #.#.. #..#.",
    "l": ".##.. ..#.. ..#.. ..#.. ..#.. ..#.. .###.",
    "m": "..... ..... ##.#. #.#.# #.#.# #.#.# #...#",
    "n": "..... ..... #.##. ##..# #...# #...# #...#",
    "o": "..... ..... .###. #...# #...# #...# .###.",
    "p": "..... ..... ####. #...# #...# ####. #.... #....",
    "q": "..... ..... .#### #...# #...# .#### ....# ....#",
    "r": "..... ..... #.##. ##..# #.... #.... #....",
    "s": "..... ..... .###. #.... .###. ....# ####.",
    "t": ".#... .#... ###.. .#... .#... .#..# ..##.",
    "u": "..... ..... #...# #...# #...# #..## .##.#",
    "v": "..... ..... #...# #...# #...# .#.#. ..#..",
    "w": "..... ..... #...# #...# #.#.# #.#.# .#.#.",
    "x": "..... ..... #...# .#.#. ..#.. .#.#. #...#",
    "y": "..... ..... #...# #...# #...# .#### ....# .###.",
    "z": "..... ..... ##### ...#. ..#.. .#... #####",
    "{": "...#. ..#.. ..#.. .#... ..#.. ..#.. ...#.",
    "|": "..#.. ..#.. ..#.. ..#.. ..#.. ..#.. ..#..",
    "}": ".#... ..#.. ..#.. ...#. ..#.. ..#.. .#...",
    "~": "..... ..... .#... #.#.# ...#.",
    "\x7f": "##### #...# #.#.# #...# #.#.# #...# #####",
}


def tex_font(path):
    img = Image(128, 48)
    for code in range(32, 128):
        ch = chr(code)
        rows = FONT_GLYPHS[ch].split()
        idx = code - 32
        ox, oy = (idx % 16) * 8, (idx // 16) * 8
        for ry, row in enumerate(rows):
            for rx, bit in enumerate(row):
                if bit == "#":
                    img.set(ox + rx, oy + ry, (255, 255, 255, 255))
    save_tga(img, path)


# =============================================================================
# UI atlas
# =============================================================================

def tex_ui(path):
    img = Image(64, 64)
    W = (255, 255, 255)
    # top-left: filled circle with antialiased edge (alpha ramp)
    for y in range(32):
        for x in range(32):
            d = math.hypot(x + 0.5 - 16, y + 0.5 - 16)
            a = clamp((14.5 - d) / 1.5, 0, 1)
            if a > 0:
                img.set(x, y, W + (a * 255,))
    # top-right: ring ~3px
    for y in range(32):
        for x in range(32):
            d = math.hypot(x + 0.5 - 16, y + 0.5 - 16)
            a = clamp(min((14.5 - d), (d - 11.5)) / 1.0 + 0.5, 0, 1)
            if a > 0:
                img.set(32 + x, y, W + (a * 255,))
    # bottom-left: rounded square button
    for y in range(32):
        for x in range(32):
            qx = max(abs(x + 0.5 - 16) - 9, 0)
            qy = max(abs(y + 0.5 - 16) - 9, 0)
            d = math.hypot(qx, qy)
            a = clamp((5.5 - d) / 1.2, 0, 1)
            if a > 0:
                img.set(x, 32 + y, W + (a * 255,))
    # bottom-right: open hand "interact" icon
    hand = Image(32, 32)
    hand.rect(7, 15, 22, 25, W)           # palm
    hand.ellipse(14.5, 25, 7.5, 4.5, W)   # rounded heel of the palm
    for fx, top in ((7, 7), (11, 4), (15, 3), (19, 5)):  # four fingers with gaps
        hand.rect(fx, top + 1, fx + 2, 16, W)
        hand.rect(fx + 1, top, fx + 1, top, W)
    hand.poly([(22, 18), (25, 12), (28, 13), (24, 22)], W)  # thumb
    hand.rect(12, 28, 19, 30, W)          # wrist
    for y in range(32):
        for x in range(32):
            p = hand.get(x, y)
            if p[3]:
                img.set(32 + x, 32 + y, p)
    save_tga(img, path)


# =============================================================================
# Sprites (RGBA cutout; bottom-centre = ground contact)
# =============================================================================

def spr_tree_pine(path):
    W, H = 64, 128
    rng = random.Random(2001)
    img = Image(W, H)
    greens = [(18, 48, 34), (26, 64, 42), (36, 82, 50), (52, 104, 60), (74, 128, 72)]
    # trunk with root flare
    for y in range(100, H):
        flare = 0 if y < 122 else (y - 121) // 2
        for x in range(29 - flare, 35 + flare):
            t = (x - (29 - flare)) / (6 + 2 * flare)
            c = (104, 70, 44) if t < 0.35 else (84, 54, 34) if t < 0.75 else (60, 38, 26)
            img.set(x, y, scale(c, 1 + rng.uniform(-0.08, 0.08)))
    # stacked tiers, bottom first so upper tiers overlap lower ones
    tiers = 6
    for i in reversed(range(tiers)):
        top = 3 + i * 16
        bot = top + 27
        hw = 7 + i * 4.6
        jag = [rng.randint(0, 3) for _ in range(W)]
        for y in range(top, bot + 1):
            t = (y - top) / (bot - top)
            half = 1 + hw * t
            for x in range(W):
                dx = x + 0.5 - 32
                if abs(dx) <= half and (y < bot - 2 or jag[x] < bot - y + 1):
                    light = 0.62 - dx / (hw + 1) * 0.35 - (1 - t) * -0.1 + rng.uniform(-0.12, 0.12)
                    light -= 0.18 * (t > 0.85)
                    img.set(x, y, pick(greens, light, x, y, 0.9))
    img.outline((12, 30, 22))
    save_tga(img, path)


def spr_tree_oak(path):
    W, H = 64, 96
    rng = random.Random(2002)
    img = Image(W, H)
    bark = [(56, 38, 26), (76, 52, 34), (96, 68, 44)]
    # trunk + roots + two branches
    for y in range(52, H):
        flare = 0 if y < 86 else (y - 85)
        x0, x1 = 28 - flare, 36 + flare
        for x in range(x0, x1):
            t = (x - x0) / max(1, x1 - x0)
            v = 0.8 - t * 0.7 + rng.uniform(-0.15, 0.15)
            img.set(x, y, pick(bark, v))
    for (sx, sy, ex, ey) in ((30, 60, 18, 40), (34, 58, 46, 38), (32, 56, 32, 34)):
        for k in range(3):
            img.line(sx + k - 1, sy, ex + k - 1, ey, bark[1 - (k == 2)])
    leaves = [(30, 64, 30), (42, 86, 38), (58, 108, 46), (80, 132, 56), (108, 156, 70)]
    blobs = [(32, 26, 20), (16, 36, 14), (48, 36, 14), (22, 18, 13), (42, 16, 13), (32, 44, 13),
             (10, 46, 8), (54, 46, 8)]
    clump = noise_grid(W, H, 8, 12, 2003, 2)
    for y in range(H):
        for x in range(W):
            best = None
            for (cx, cy, r) in blobs:
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                d = math.hypot(dx, dy) / r
                if d < 1.0 and (best is None or d < best[0]):
                    best = (d, dx / r, dy / r)
            if best:
                d, nx, ny = best
                if d > 0.86 and rng.random() < 0.35:
                    continue  # ragged leafy edge
                v = 0.55 - nx * 0.25 - ny * 0.3 + (clump[y][x] - 0.5) * 0.7 + rng.uniform(-0.08, 0.08)
                img.set(x, y, pick(leaves, v, x, y, 0.8))
    img.outline((20, 40, 22))
    save_tga(img, path)


def spr_bush(path):
    rng = random.Random(2004)
    img = Image(32, 32)
    leaves = [(28, 62, 30), (40, 84, 38), (56, 106, 46), (78, 128, 58)]
    blobs = [(16, 18, 10), (8, 24, 7.5), (24, 24, 7.5), (12, 14, 6), (21, 13, 6)]
    for y in range(32):
        for x in range(32):
            best = None
            for (cx, cy, r) in blobs:
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                d = math.hypot(dx, dy) / r
                if d < 1.0 and (best is None or d < best[0]):
                    best = (d, dx / r, dy / r)
            if y >= 27 and 3 <= x <= 28:
                best = best or (0.5, 0.0, 0.8)
            if best:
                d, nx, ny = best
                if d > 0.85 and rng.random() < 0.3 and y < 28:
                    continue
                v = 0.6 - nx * 0.25 - ny * 0.35 + rng.uniform(-0.2, 0.2)
                img.set(x, y, pick(leaves, v, x, y, 0.8))
    for (x, y) in ((10, 16), (19, 12), (22, 21), (13, 23), (6, 22)):  # berries
        img.set(x, y, (196, 40, 52))
        img.set(x + 1, y, (150, 28, 40))
    img.outline((18, 38, 20))
    save_tga(img, path)


def spr_flowers(path):
    rng = random.Random(2005)
    img = Image(32, 32)
    stem = (52, 110, 44)
    heads = [(6, 15, (236, 120, 170)), (13, 10, (250, 214, 70)), (20, 14, (130, 150, 240)),
             (26, 18, (248, 248, 240)), (10, 19, (240, 150, 60))]
    for (hx, hy, col) in heads:
        img.line(hx, hy, hx + rng.choice([-1, 0, 1]), 31, stem)
        img.set(hx + 1, hy + 6, (72, 138, 58))
        img.set(hx - 1, hy + 8, (72, 138, 58))
    for (hx, hy, col) in heads:
        dark = scale(col, 0.72)
        for dx, dy in ((0, -2), (-2, 0), (2, 0), (0, 2), (-1, -1), (1, -1), (-1, 1), (1, 1)):
            img.set(hx + dx, hy + dy, col if dy <= 0 else dark)
        img.set(hx, hy, (250, 180, 40))
    for x in range(1, 31):  # grass tuft along the bottom
        h = rng.randint(1, 5)
        for k in range(h):
            img.set(x, 31 - k, (46, 96, 40) if k < h - 1 else (80, 140, 60))
    img.outline((22, 44, 22))
    save_tga(img, path)


def spr_moon(path):
    rng = random.Random(2006)
    img = Image(64, 64)
    craters = [(22, 20, 6), (40, 30, 8), (28, 42, 5), (46, 14, 4), (16, 36, 3), (36, 50, 4), (50, 44, 3)]
    pal = [(150, 152, 156), (184, 186, 186), (212, 212, 204), (232, 230, 218), (246, 244, 232)]
    surf = noise_grid(64, 64, 4, 4, 2007, 3)
    for y in range(64):
        for x in range(64):
            dx, dy = x + 0.5 - 32, y + 0.5 - 32
            d = math.hypot(dx, dy)
            if d > 31.9:
                continue
            v = 0.82 - (d / 32) ** 3 * 0.35 + (surf[y][x] - 0.5) * 0.35 - (dx + dy) / 64 * 0.12
            for (cx, cy, r) in craters:
                cd = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                if cd < r:
                    v -= 0.25
                    # rim: lit lower-right inside edge, shadow upper-left
                    if cd > r - 1.6:
                        v += 0.3 if (x - cx) + (y - cy) > 0 else -0.1
            img.set(x, y, pick(pal, v + rng.uniform(-0.04, 0.04), x, y, 0.8))
    save_tga(img, path)


def spr_star(path):
    img = Image(8, 8)
    for y in range(8):
        for x in range(8):
            d = math.hypot(x + 0.5 - 4, y + 0.5 - 4)
            a = clamp(1.0 - d / 3.6, 0, 1) ** 1.6  # soft dot (alpha ramp by design)
            if a > 0.02:
                img.set(x, y, (255, 255, 255, a * 255))
    save_tga(img, path)


def spr_firefly(path):
    img = Image(8, 8)
    for y in range(8):
        for x in range(8):
            d = math.hypot(x + 0.5 - 4, y + 0.5 - 4)
            a = clamp(1.0 - d / 3.8, 0, 1) ** 1.3  # soft glow (alpha ramp by design)
            if a > 0.02:
                img.set(x, y, mix((200, 255, 90), (255, 255, 230), clamp(1.2 - d / 2, 0, 1)) + (a * 255,))
    save_tga(img, path)


# --- NPCs --------------------------------------------------------------------

SKIN = (226, 178, 140)
SKIN_D = (188, 136, 104)
OUTLINE = (26, 20, 22)


def _eye(img, x, y, c=(30, 24, 30)):
    img.set(x, y, c)


def spr_npc_farmer(path):
    rng = random.Random(2101)
    img = Image(32, 64)
    denim, denim_d = (70, 96, 150), (52, 70, 116)
    plaid = lambda x, y: (186, 54, 48) if (x // 2 + y // 2) % 2 else (140, 36, 36)
    img.rect(10, 60, 14, 63, (70, 46, 30))       # boots
    img.rect(17, 60, 21, 63, (70, 46, 30))
    img.rect(11, 44, 14, 59, denim_d)            # legs
    img.rect(17, 44, 20, 59, denim)
    img.rect(8, 30, 23, 38, plaid)               # shirt
    img.rect(6, 31, 8, 44, plaid)                # arms
    img.rect(23, 31, 25, 42, plaid)
    img.rect(10, 34, 21, 45, denim)              # overall bib
    img.rect(10, 30, 11, 34, denim_d)            # straps
    img.rect(20, 30, 21, 34, denim_d)
    img.set(11, 35, (230, 200, 90))
    img.set(20, 35, (230, 200, 90))
    img.rect(13, 38, 18, 41, denim_d)            # pocket
    img.rect(6, 45, 8, 47, SKIN)                 # hands
    img.rect(23, 43, 25, 45, SKIN)
    img.line(25, 42, 27, 63, (110, 74, 40))      # walking cane
    img.rect(24, 41, 27, 42, (110, 74, 40))
    img.ellipse(16, 22, 5.5, 6.5, lambda x, y: SKIN if x < 19 else SKIN_D)   # head
    img.ellipse(16, 27, 5, 3.5, (236, 236, 232))                            # white beard
    img.rect(13, 23, 18, 23, (220, 220, 214))                               # moustache
    _eye(img, 13, 20)
    _eye(img, 18, 20)
    img.set(15, 21, SKIN_D)
    img.set(16, 22, SKIN_D)
    img.rect(10, 17, 11, 19, (200, 200, 196))                               # side hair
    img.rect(20, 17, 21, 19, (200, 200, 196))
    straw, straw_d = (226, 196, 112), (184, 150, 76)
    img.rect(5, 15, 26, 16, lambda x, y: straw if (x + y) % 3 else straw_d)  # brim
    img.rect(10, 9, 21, 14, lambda x, y: straw if (x * 2 + y) % 5 else straw_d)
    img.rect(10, 13, 21, 13, (120, 60, 40))                                  # hat band
    img.jitter(rng, 0.05)
    img.outline(OUTLINE)
    save_tga(img, path)


def spr_npc_fen_keeper(path):
    rng = random.Random(2102)
    img = Image(32, 64)
    robe = [(34, 46, 44), (44, 60, 56), (58, 78, 70)]
    # tattered robe
    hem = [rng.randint(0, 3) for _ in range(32)]
    img.poly([(9, 24), (22, 24), (27, 64), (4, 64)],
             lambda x, y: (0, 0, 0, 0) if y > 63 - hem[x] else pick(robe, 0.75 - (x - 4) / 23 * 0.6 + rng.uniform(-0.1, 0.1)))
    for x in range(32):  # restore the bottom row so the feet touch the ground
        if img.get(x, 62)[3] and 8 <= x <= 22:
            img.set(x, 63, robe[0])
    img.rect(12, 60, 14, 63, (24, 30, 28))
    img.rect(17, 60, 19, 63, (24, 30, 28))
    # moss patches
    for _ in range(14):
        x, y = rng.randint(7, 24), rng.randint(30, 60)
        if img.get(x, y)[3]:
            img.set(x, y, (88, 120, 60))
    # hood
    img.ellipse(15.5, 17, 7.5, 9, lambda x, y: pick(robe, 0.8 - (x - 8) / 15 * 0.6))
    img.ellipse(15.5, 19.5, 4.2, 4.6, (8, 10, 12))                # dark face
    for (x, y) in ((13, 19), (18, 19)):                           # glowing eyes
        img.set(x, y, (190, 255, 210))
        img.set(x + (1 if x < 16 else -1), y, (110, 220, 170))
    img.rect(5, 30, 8, 40, robe[1])                               # sleeve
    img.rect(23, 26, 26, 34, robe[1])
    img.rect(25, 24, 27, 26, (150, 160, 140))                     # pale hand
    # staff with hanging lantern
    img.rect(27, 6, 27, 63, (86, 62, 40))
    img.rect(27, 6, 30, 6, (86, 62, 40))
    img.rect(29, 7, 29, 8, (60, 60, 60))
    img.rect(28, 9, 31, 9, (60, 60, 60))
    img.rect(28, 10, 31, 15, lambda x, y: (250, 240, 140) if (x in (29, 30) and 11 <= y <= 13) else (210, 200, 90))
    img.rect(28, 16, 31, 16, (60, 60, 60))
    img.jitter(rng, 0.05)
    img.outline(OUTLINE)
    save_tga(img, path)


def spr_npc_child(path):
    rng = random.Random(2103)
    img = Image(32, 48)
    img.rect(10, 44, 14, 47, (200, 60, 50))      # red boots
    img.rect(17, 44, 21, 47, (200, 60, 50))
    img.rect(11, 36, 14, 43, SKIN)               # legs
    img.rect(17, 36, 20, 43, SKIN_D)
    img.rect(10, 32, 21, 36, (60, 80, 130))      # shorts
    img.rect(9, 22, 22, 32, lambda x, y: (242, 196, 60) if y % 4 else (220, 160, 40))  # striped sweater
    img.rect(7, 23, 9, 31, (242, 196, 60))       # arms
    img.rect(22, 23, 24, 31, (220, 160, 40))
    img.rect(7, 32, 9, 33, SKIN)
    img.rect(22, 32, 24, 33, SKIN)
    img.ellipse(16, 14, 6.5, 7, lambda x, y: SKIN if x < 19 else SKIN_D)   # big head
    img.ellipse(16, 9, 7, 4.5, (120, 72, 40))                             # hair
    img.rect(9, 9, 10, 15, (120, 72, 40))
    img.rect(21, 9, 22, 15, (120, 72, 40))
    img.set(17, 4, (120, 72, 40))
    img.set(18, 3, (120, 72, 40))                                         # cowlick
    _eye(img, 13, 14)
    _eye(img, 19, 14)
    img.set(12, 16, (236, 140, 130))
    img.set(20, 16, (236, 140, 130))
    img.rect(15, 18, 17, 18, (150, 70, 60))
    img.jitter(rng, 0.04)
    img.outline(OUTLINE)
    save_tga(img, path)


def _gear_pixels(cx, cy, r_out, r_in, r_hole, teeth, phase=0.0):
    """Yields (x, y, light) for a cog shape."""
    for y in range(int(cy - r_out) - 1, int(cy + r_out) + 2):
        for x in range(int(cx - r_out) - 1, int(cx + r_out) + 2):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            ang = math.atan2(dy, dx)
            rr = r_out if math.cos(teeth * ang + phase) > 0.2 else r_in
            if r_hole < d <= rr:
                light = 0.5 - (dx + dy) / (2.8 * r_out)
                yield x, y, light


BRASS = [(110, 74, 30), (160, 112, 46), (204, 156, 70), (238, 200, 110), (255, 236, 170)]


def spr_npc_merchant(path):
    rng = random.Random(2104)
    img = Image(32, 64)
    iron = (70, 64, 60)
    img.rect(9, 61, 14, 63, iron)                # feet
    img.rect(17, 61, 22, 63, iron)
    for lx in (11, 18):                          # segmented brass legs
        img.rect(lx, 46, lx + 2, 60, lambda x, y: pick(BRASS, 0.7 - (x - lx) * 0.2 - (0.2 if y % 5 == 0 else 0)))
    img.ellipse(16, 38, 9.5, 11, lambda x, y: pick(BRASS, 0.75 - (x - 6) / 20 * 0.6, x, y, 0.6))  # barrel body
    for (x, y, l) in _gear_pixels(16, 37, 5.2, 3.8, 1.5, 8):                                      # chest cog
        img.set(x, y, pick([(80, 52, 24), (130, 88, 36), (184, 132, 58)], l))
    img.rect(15, 36, 16, 37, (255, 220, 120))
    img.rect(4, 30, 6, 44, lambda x, y: pick(BRASS, 0.6 - (y % 4 == 0) * 0.3))  # arms
    img.rect(25, 30, 27, 44, lambda x, y: pick(BRASS, 0.4 - (y % 4 == 0) * 0.3))
    img.rect(4, 45, 6, 46, iron)
    img.rect(25, 45, 27, 46, iron)
    img.rect(27, 35, 29, 36, iron)               # wind-up key on the side
    img.rect(29, 32, 30, 39, (200, 200, 190))
    img.ellipse(16, 20, 6.5, 6, lambda x, y: pick(BRASS, 0.85 - (x - 9) / 13 * 0.6))     # domed head
    img.rect(11, 26, 20, 27, iron)               # neck collar
    img.ellipse(13, 19, 1.8, 1.8, (40, 30, 20))
    img.set(13, 19, (120, 220, 255))             # glowing eye
    img.ellipse(19, 19, 2.6, 2.6, (40, 30, 20))  # monocle
    img.ellipse(19, 19, 1.6, 1.6, (180, 240, 255))
    img.line(21, 21, 22, 27, (238, 200, 110))    # monocle chain
    img.rect(13, 23, 19, 23, (70, 50, 30))       # grille mouth
    img.set(14, 23, (110, 80, 40))
    img.set(17, 23, (110, 80, 40))
    img.rect(9, 13, 23, 14, (40, 34, 40))        # top hat brim
    img.rect(11, 3, 21, 12, (52, 44, 52))
    img.rect(11, 10, 21, 11, (150, 60, 50))      # hat band
    for (x, y, l) in _gear_pixels(21.5, 5.5, 3.2, 2.2, 0.8, 6):
        img.set(x, y, pick(BRASS[1:], l))
    img.jitter(rng, 0.04)
    img.outline(OUTLINE)
    save_tga(img, path)


def spr_npc_robot(path):
    rng = random.Random(2105)
    img = Image(32, 64)
    shell = [(110, 124, 140), (150, 166, 180), (190, 204, 214), (228, 236, 240)]
    img.rect(7, 58, 24, 63, (60, 60, 68))        # tread base
    for x in range(7, 25, 3):
        img.rect(x, 60, x, 62, (96, 96, 104))
    img.rect(9, 56, 22, 57, (80, 80, 90))
    img.ellipse(16, 45, 11, 11, lambda x, y: pick(shell, 0.85 - (x - 5) / 22 * 0.5 - (y - 34) / 22 * 0.3, x, y, 0.7))
    img.ellipse(16, 43, 7, 5, (24, 34, 44))      # face screen
    for (x, y) in ((13, 42), (19, 42)):
        img.rect(x - 1, y - 1, x, y, (110, 240, 230))
    img.set(14, 46, (110, 240, 230))
    img.rect(15, 47, 17, 47, (110, 240, 230))
    img.set(18, 46, (110, 240, 230))
    img.set(10, 44, (240, 140, 150))
    img.set(22, 44, (240, 140, 150))             # blush lights
    img.rect(2, 44, 5, 46, shell[1])             # little arms
    img.rect(26, 40, 29, 42, shell[1])
    img.rect(1, 47, 3, 48, (240, 170, 60))
    img.rect(28, 38, 30, 39, (240, 170, 60))
    img.rect(15, 26, 16, 34, (90, 96, 104))      # antenna
    img.ellipse(16, 24, 2.6, 2.6, (255, 176, 60))
    img.set(15, 23, (255, 236, 180))
    img.rect(13, 52, 18, 53, (240, 170, 60))     # belly panel
    img.jitter(rng, 0.03)
    img.outline(OUTLINE)
    save_tga(img, path)


def spr_npc_librarian(path):
    rng = random.Random(2106)
    img = Image(32, 64)
    robe = [(40, 34, 70), (56, 48, 96), (74, 64, 124)]
    scale_c = [(40, 100, 110), (56, 134, 140), (84, 168, 166), (130, 206, 196)]
    img.poly([(10, 22), (21, 22), (25, 64), (6, 64)], lambda x, y: pick(robe, 0.8 - (x - 6) / 19 * 0.6))  # long robe
    img.rect(15, 24, 16, 62, (110, 96, 160))     # robe trim
    img.rect(6, 25, 9, 40, robe[1])              # sleeves
    img.rect(22, 25, 25, 36, robe[1])
    img.rect(18, 34, 25, 41, (150, 60, 50))      # held book
    img.rect(18, 34, 18, 41, (100, 40, 30))
    img.rect(20, 37, 24, 37, (230, 190, 90))
    img.rect(6, 41, 9, 43, scale_c[2])           # webbed hand
    img.rect(25, 36, 26, 38, scale_c[2])
    # fish head: tall oval with dorsal fin and side fins
    img.poly([(14, 0), (18, 0), (20, 6), (12, 6)], lambda x, y: (220, 120, 90) if y % 2 else (190, 90, 70))
    img.poly([(6, 10), (2, 6), (3, 15)], (190, 90, 70))
    img.poly([(25, 10), (29, 6), (28, 15)], (190, 90, 70))
    img.ellipse(16, 12, 9, 9.5, lambda x, y: pick(scale_c, 0.8 - (x - 7) / 18 * 0.5 + (0.12 if (x + 2 * y) % 4 == 0 else 0)))
    img.ellipse(16, 18.5, 5, 2.5, (196, 228, 214))  # pale throat
    img.rect(12, 17, 20, 17, (40, 50, 60))         # wide mouth
    img.set(11, 16, (40, 50, 60))
    img.set(21, 16, (40, 50, 60))
    for ex in (11.5, 20.5):                        # big eyes + spectacles
        img.ellipse(ex, 10.5, 3.6, 3.6, (238, 200, 110))
        img.ellipse(ex, 10.5, 2.6, 2.6, (250, 250, 240))
        img.rect(int(ex) - 1 + (ex > 16), 10, int(ex) + (ex > 16), 11, (20, 20, 30))
        img.set(int(ex) - 1, 9, (255, 255, 255))
    img.rect(15, 10, 16, 10, (238, 200, 110))      # spectacle bridge
    img.rect(13, 22, 18, 23, robe[2])              # collar
    img.rect(12, 61, 14, 63, (40, 90, 100))        # flipper feet
    img.rect(17, 61, 20, 63, (40, 90, 100))
    img.jitter(rng, 0.04)
    img.outline(OUTLINE)
    save_tga(img, path)


# --- props -------------------------------------------------------------------

def _lantern(path, lit):
    rng = random.Random(2201)
    img = Image(16, 32)
    iron, iron_l = (46, 44, 48), (84, 80, 86)
    if lit:  # soft warm halo (low alpha; an alpha-tested renderer simply drops it)
        for y in range(32):
            for x in range(16):
                d = math.hypot(x + 0.5 - 8, (y + 0.5 - 20) * 0.8)
                a = clamp(1 - d / 8.5, 0, 1) * 110
                if a > 8:
                    img.set(x, y, (255, 190, 90, a))
    img.ellipse(8, 3, 3, 3, iron)                # handle ring
    img.ellipse(8, 3, 1.6, 1.6, (0, 0, 0, 0) if not lit else (255, 190, 90, 40))
    img.poly([(8, 6), (13, 11), (3, 11)], iron_l)  # cap
    img.rect(3, 11, 12, 12, iron)
    for y in range(13, 27):
        for x in range(4, 12):
            if lit:
                d = math.hypot(x + 0.5 - 8, (y + 0.5 - 21) * 0.7)
                c = mix((255, 248, 200), (230, 140, 40), clamp(d / 4.5, 0, 1))
            else:
                c = (40, 52, 70) if (x + y) % 5 else (70, 88, 110)
                if x == 5 and 14 <= y <= 18:
                    c = (150, 170, 190)  # glass reflection
            img.set(x, y, c)
    if lit:
        img.rect(7, 19, 8, 22, (255, 255, 236))  # flame core
        img.set(8, 18, (255, 240, 180))
    for x in (3, 12):
        img.rect(x, 13, x, 26, iron)             # cage frame
    img.rect(4, 13, 11, 13, iron)
    img.rect(2, 27, 13, 28, iron)                # base
    img.rect(3, 29, 12, 31, iron_l)
    img.rect(4, 31, 11, 31, iron)
    # outline only around opaque (non-halo) pixels
    solid = Image(16, 32)
    for y in range(32):
        for x in range(16):
            if img.get(x, y)[3] == 255:
                solid.set(x, y, img.get(x, y))
    solid.outline((20, 18, 22))
    for y in range(32):
        for x in range(16):
            if solid.get(x, y)[3] == 255 and img.get(x, y)[3] < 255:
                img.set(x, y, solid.get(x, y))
    save_tga(img, path)


def spr_lantern_off(path):
    _lantern(path, False)


def spr_lantern_on(path):
    _lantern(path, True)


def spr_gear(path):
    img = Image(16, 16)
    for (x, y, l) in _gear_pixels(8, 8, 7.9, 5.6, 2.0, 8, 0.2):
        img.set(x, y, pick(BRASS, l + 0.15, x, y, 0.5))
    for y in range(16):
        for x in range(16):
            d = math.hypot(x + 0.5 - 8, y + 0.5 - 8)
            if 2.0 < d < 3.2 and img.get(x, y)[3]:
                img.set(x, y, BRASS[1])
    save_tga(img, path)


def spr_book(path):
    img = Image(16, 16)
    cover, cover_d = (170, 52, 60), (120, 34, 44)
    img.poly([(2, 4), (12, 2), (14, 13), (4, 16)], cover)       # tilted closed book
    img.poly([(4, 15), (14, 12), (14, 13), (4, 16)], (236, 226, 200))  # page edge
    img.line(2, 4, 4, 15, cover_d)                               # spine
    img.line(3, 4, 5, 15, cover_d)
    img.line(6, 7, 11, 6, (240, 200, 90))                        # gold title lines
    img.line(7, 9, 10, 8, (240, 200, 90))
    img.set(9, 11, (240, 200, 90))
    img.outline((40, 20, 24))
    save_tga(img, path)


def tex_sky_stars(path):
    W, H = 128, 64
    rng = random.Random(2301)
    neb = noise_grid(W, H, 8, 4, 2302, 4, 0.55)
    neb2 = noise_grid(W, H, 4, 2, 2303, 2)
    img = Image(W, H)
    for y in range(H):
        for x in range(W):
            n = neb[y][x]
            base = mix((8, 10, 28), (22, 18, 52), clamp((n - 0.35) * 2.2, 0, 1))
            base = mix(base, (14, 34, 58), clamp((neb2[y][x] - 0.55) * 2.5, 0, 1) * 0.6)
            f = 1 + bayer(x, y) * 0.08 + rng.uniform(-0.03, 0.03)
            img.set(x, y, scale(base, f) + (255,))
    for _ in range(90):
        x, y = rng.randrange(W), rng.randrange(H)
        b = rng.random()
        col = rng.choice([(255, 255, 255), (200, 220, 255), (255, 236, 200)])
        img.setw(x, y, scale(col, 0.35 + 0.65 * b))
    for _ in range(6):  # a few bright twinkly stars
        x, y = rng.randrange(W), rng.randrange(H)
        img.setw(x, y, (255, 255, 255))
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            img.setw(x + dx, y + dy, (150, 160, 200))
    save_tga(img, path)


# =============================================================================
# OBJ models (Y up, metres, CCW front faces, flat normals)
# =============================================================================

def v_sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def v_add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def v_mul(a, s):
    return (a[0] * s, a[1] * s, a[2] * s)


def v_cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def v_dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def v_norm(a):
    l = math.sqrt(v_dot(a, a)) or 1.0
    return (a[0] / l, a[1] / l, a[2] / l)


class Mesh:
    def __init__(self, name):
        self.name = name
        self.v, self.vt, self.vn, self.f = [], [], [], []
        self._vi, self._ti, self._ni = {}, {}, {}

    def _idx(self, table, lst, val):
        key = tuple(round(c, 5) + 0.0 for c in val)
        if key not in table:
            lst.append(key)
            table[key] = len(lst)
        return table[key]

    def tri(self, a, b, c, ta, tb, tc, outward_from=None):
        """Add a triangle. If outward_from is given, the winding is fixed so the
        face normal points away from that interior point (CCW front faces)."""
        n = v_cross(v_sub(b, a), v_sub(c, a))
        if v_dot(n, n) < 1e-14:
            return  # degenerate
        if outward_from is not None:
            cen = v_mul(v_add(v_add(a, b), c), 1 / 3)
            if v_dot(n, v_sub(cen, outward_from)) < 0:
                b, c, tb, tc = c, b, tc, tb
                n = v_mul(n, -1)
        ni = self._idx(self._ni, self.vn, v_norm(n))
        face = []
        for p, t in ((a, ta), (b, tb), (c, tc)):
            face.append((self._idx(self._vi, self.v, p), self._idx(self._ti, self.vt, t), ni))
        self.f.append(face)

    def quad(self, a, b, c, d, uvs=((0, 0), (1, 0), (1, 1), (0, 1)), outward_from=None):
        self.tri(a, b, c, uvs[0], uvs[1], uvs[2], outward_from)
        self.tri(a, c, d, uvs[0], uvs[2], uvs[3], outward_from)

    def box(self, cx, cy, cz, hx, hy, hz):
        """Axis-aligned box with per-face 0..1 UVs."""
        c = (cx, cy, cz)
        h = (hx, hy, hz)
        faces = [((1, 0, 0), (0, 0, -1), (0, 1, 0)), ((-1, 0, 0), (0, 0, 1), (0, 1, 0)),
                 ((0, 0, 1), (1, 0, 0), (0, 1, 0)), ((0, 0, -1), (-1, 0, 0), (0, 1, 0)),
                 ((0, 1, 0), (1, 0, 0), (0, 0, -1)), ((0, -1, 0), (1, 0, 0), (0, 0, 1))]
        for n, u, w in faces:
            fc = tuple(c[i] + n[i] * h[i] for i in range(3))
            uu = tuple(u[i] * h[i] for i in range(3))
            ww = tuple(w[i] * h[i] for i in range(3))
            p0 = v_sub(v_sub(fc, uu), ww)
            p1 = v_sub(v_add(fc, uu), ww)
            p2 = v_add(v_add(fc, uu), ww)
            p3 = v_add(v_sub(fc, uu), ww)
            self.quad(p0, p1, p2, p3, outward_from=c)

    def cylinder(self, cx, cz, y0, y1, r0, r1, sides, cap_bottom=True, cap_top=True):
        """Frustum along Y (r0 at y0, r1 at y1)."""
        centre = (cx, (y0 + y1) / 2, cz)
        ring = lambda r, y, i: (cx + r * math.cos(2 * math.pi * i / sides), y,
                                cz + r * math.sin(2 * math.pi * i / sides))
        for i in range(sides):
            u0, u1 = i / sides, (i + 1) / sides
            a, b = ring(r0, y0, i), ring(r0, y0, i + 1)
            c, d = ring(r1, y1, i + 1), ring(r1, y1, i)
            if r1 > 1e-6:
                self.quad(a, b, c, d, ((u0, 0), (u1, 0), (u1, 1), (u0, 1)), centre)
            else:
                self.tri(a, b, (cx, y1, cz), (u0, 0), (u1, 0), ((u0 + u1) / 2, 1), centre)
            if cap_bottom:
                self.tri((cx, y0, cz), a, b, (0.5, 0.5), (0.5 + 0.5 * math.cos(2 * math.pi * u0), 0.5 + 0.5 * math.sin(2 * math.pi * u0)),
                         (0.5 + 0.5 * math.cos(2 * math.pi * u1), 0.5 + 0.5 * math.sin(2 * math.pi * u1)),
                         (cx, y0 + 1.0, cz))
            if cap_top and r1 > 1e-6:
                self.tri((cx, y1, cz), d, c, (0.5, 0.5), (0.5 + 0.5 * math.cos(2 * math.pi * u0), 0.5 + 0.5 * math.sin(2 * math.pi * u0)),
                         (0.5 + 0.5 * math.cos(2 * math.pi * u1), 0.5 + 0.5 * math.sin(2 * math.pi * u1)),
                         (cx, y1 - 1.0, cz))

    def save(self, path):
        lines = ["# %s.obj - Multiversal Van Life" % self.name,
                 "# %s, attribution: %s" % (LICENSE, ATTRIBUTION),
                 "o %s" % self.name]
        fmt = lambda x: ("%.4f" % x).rstrip("0").rstrip(".") if abs(x) > 5e-5 else "0"
        lines += ["v %s %s %s" % tuple(fmt(c) for c in p) for p in self.v]
        lines += ["vt %s %s" % (fmt(t[0]), fmt(t[1])) for t in self.vt]
        lines += ["vn %s %s %s" % tuple(fmt(c) for c in n) for n in self.vn]
        lines += ["f " + " ".join("%d/%d/%d" % c for c in face) for face in self.f]
        with open(path, "w", newline="\n") as fh:
            fh.write("\n".join(lines) + "\n")


def obj_plane(path):
    m = Mesh("plane")
    m.quad((-0.5, 0, 0.5), (0.5, 0, 0.5), (0.5, 0, -0.5), (-0.5, 0, -0.5),
           outward_from=(0, -1, 0))
    m.save(path)


def obj_cube(path):
    m = Mesh("cube")
    m.box(0, 0, 0, 0.5, 0.5, 0.5)
    m.save(path)


def obj_rock(path):
    rng = random.Random(3001)
    t = (1 + math.sqrt(5)) / 2
    verts = [v_norm(p) for p in [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t),
                                 (0, -1, -t), (0, 1, -t), (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]]
    faces = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2),
             (10, 7, 6), (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5),
             (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    # one subdivision -> 80 triangles
    cache = {}

    def mid(i, j):
        k = (min(i, j), max(i, j))
        if k not in cache:
            verts.append(v_norm(v_mul(v_add(verts[i], verts[j]), 0.5)))
            cache[k] = len(verts) - 1
        return cache[k]
    nf = []
    for a, b, c in faces:
        ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
        nf += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
    # irregular displacement + squash, then flatten the base
    pts = []
    for p in verts:
        r = rng.uniform(0.82, 1.12)
        pts.append((p[0] * 0.55 * r, p[1] * 0.42 * r, p[2] * 0.47 * r))
    floor_y = -0.42 * 0.55
    pts = [(x, max(y, floor_y) - floor_y, z) for (x, y, z) in pts]
    top = max(p[1] for p in pts)
    centre = (0, top * 0.4, 0)
    m = Mesh("rock")
    for a, b, c in nf:
        uv = lambda p: (math.atan2(p[2], p[0]) / (2 * math.pi) + 0.5, p[1] / top)
        m.tri(pts[a], pts[b], pts[c], uv(pts[a]), uv(pts[b]), uv(pts[c]), centre)
    m.save(path)


def obj_crystal(path):
    m = Mesh("crystal")
    # (base x, base z, radius, body height, tip height, tilt about z, tilt about x)
    spires = [(0.0, 0.0, 0.17, 1.15, 1.5, 0.0, 0.0),
              (0.22, 0.08, 0.11, 0.65, 0.88, -0.38, 0.12),
              (-0.16, 0.16, 0.10, 0.5, 0.7, 0.32, 0.30)]
    for (bx, bz, r, hb, ht, tz, tx) in spires:
        def xf(p):
            x, y, z = p
            # rotate about Z (tilt sideways), then about X
            x, y = x * math.cos(tz) - y * math.sin(tz), x * math.sin(tz) + y * math.cos(tz)
            y, z = y * math.cos(tx) - z * math.sin(tx), y * math.sin(tx) + z * math.cos(tx)
            return (x + bx, y, z + bz)
        base = [(r * math.cos(i * math.pi / 3), 0, r * math.sin(i * math.pi / 3)) for i in range(6)]
        body = [(r * 1.08 * math.cos(i * math.pi / 3), hb, r * 1.08 * math.sin(i * math.pi / 3)) for i in range(6)]
        base = [xf(p) for p in base]
        base = [(p[0], 0.0, p[2]) for p in base]  # keep the foot flat on y=0
        body = [xf(p) for p in body]
        tip = xf((0, ht, 0))
        centre = xf((0, hb * 0.5, 0))
        centre = (centre[0], max(centre[1], 0.05), centre[2])
        for i in range(6):
            j = (i + 1) % 6
            u0, u1 = i / 6, (i + 1) / 6
            m.quad(base[i], base[j], body[j], body[i], ((u0, 0), (u1, 0), (u1, 0.75), (u0, 0.75)), centre)
            m.tri(body[i], body[j], tip, (u0, 0.75), (u1, 0.75), ((u0 + u1) / 2, 1), centre)
        for i in range(1, 5):
            m.tri(base[0], base[i], base[i + 1], (0.5, 0), (0.5, 0), (0.5, 0), (centre[0], 1.0, centre[2]))
    m.save(path)


def obj_lamp(path):
    m = Mesh("lamp")
    m.cylinder(0, 0, 0.0, 0.12, 0.2, 0.18, 8)                 # plinth
    m.cylinder(0, 0, 0.12, 0.3, 0.12, 0.08, 8)                # base flare
    m.cylinder(0, 0, 0.3, 2.8, 0.055, 0.045, 6, cap_bottom=False)  # pole
    m.cylinder(0, 0, 2.8, 2.88, 0.08, 0.08, 6)                # collar
    m.cylinder(0, 0, 2.88, 3.0, 0.05, 0.0, 6, cap_bottom=False)   # finial
    m.box(0.3, 2.74, 0, 0.3, 0.025, 0.025)                    # arm
    m.box(0.12, 2.64, 0, 0.012, 0.09, 0.012)                  # brace
    m.cylinder(0.55, 0, 2.48, 2.72, 0.17, 0.05, 8)            # lamp shade (frustum)
    m.cylinder(0.55, 0, 2.38, 2.48, 0.07, 0.11, 8, cap_top=False)  # glowing bulb housing
    m.save(path)


# =============================================================================
# VOX models (MagicaVoxel v150, Z up)
# =============================================================================

class Vox:
    def __init__(self, name, sx, sy, sz, seed):
        assert max(sx, sy, sz) <= 64
        self.name, self.sx, self.sy, self.sz = name, sx, sy, sz
        self.vox = {}
        self.palette = []
        self._pal = {}
        self.rng = random.Random(seed)

    def col(self, rgb):
        """Palette index (1..255) for an RGB colour, allocated on demand."""
        rgb = tuple(c8(c) for c in rgb[:3])
        if rgb not in self._pal:
            assert len(self.palette) < 255, "palette full"
            self.palette.append(rgb)
            self._pal[rgb] = len(self.palette)
        return self._pal[rgb]

    def shades(self, rgb, n=3, spread=0.08):
        return [self.col(scale(rgb, 1 + spread * (i - (n - 1) / 2))) for i in range(n)]

    def set(self, x, y, z, c):
        if 0 <= x < self.sx and 0 <= y < self.sy and 0 <= z < self.sz:
            if isinstance(c, list):
                c = c[self.rng.randrange(len(c))]
            if c:
                self.vox[(x, y, z)] = c
            else:
                self.vox.pop((x, y, z), None)

    def get(self, x, y, z):
        return self.vox.get((x, y, z), 0)

    def box(self, x0, y0, z0, x1, y1, z1, c):
        for z in range(z0, z1 + 1):
            for y in range(y0, y1 + 1):
                for x in range(x0, x1 + 1):
                    self.set(x, y, z, c)

    def clear(self, x0, y0, z0, x1, y1, z1):
        self.box(x0, y0, z0, x1, y1, z1, 0)

    def save(self, path):
        def chunk(cid, content, children=b""):
            return cid + struct.pack("<ii", len(content), len(children)) + content + children
        size = chunk(b"SIZE", struct.pack("<iii", self.sx, self.sy, self.sz))
        items = sorted(self.vox.items(), key=lambda kv: (kv[0][2], kv[0][1], kv[0][0]))
        xyzi = chunk(b"XYZI", struct.pack("<i", len(items)) +
                     b"".join(struct.pack("<BBBB", x, y, z, c) for (x, y, z), c in items))
        pal = bytearray()
        for i in range(256):
            if i < len(self.palette):
                pal += bytes(self.palette[i]) + b"\xff"
            else:
                pal += b"\x00\x00\x00\xff"
        rgba_chunk = chunk(b"RGBA", bytes(pal))
        main = chunk(b"MAIN", b"", size + xyzi + rgba_chunk)
        with open(path, "wb") as f:
            f.write(b"VOX " + struct.pack("<i", 150) + main)


def vox_van(path):
    v = Vox("van", 40, 18, 20, 4001)
    cream = v.shades((236, 224, 190), 3, 0.05)
    teal = v.shades((92, 150, 140), 3, 0.06)
    chrome = v.col((196, 200, 204))
    chrome_d = v.col((130, 134, 140))
    glass = v.col((34, 52, 96))
    glass_hi = v.col((90, 120, 170))
    tyre = v.col((30, 30, 34))
    hub = v.col((170, 170, 176))
    lamp = v.col((255, 246, 200))
    tail = v.col((200, 40, 40))
    amber = v.col((255, 176, 40))
    amber_core = v.col((255, 236, 150))
    rack = v.col((60, 60, 66))
    dark = v.col((40, 40, 44))
    seam = v.col((170, 160, 130))
    wood = v.shades((140, 96, 56), 2, 0.1)
    # body: x 1..38, y 0..17, z 3..17, lower teal / upper cream
    for x in range(1, 39):
        for y in range(18):
            for z in range(3, 18):
                # round the vertical edges and the top edges a little
                edge_y = y in (0, 17)
                if (x in (1, 38)) and edge_y:
                    continue
                if z == 17 and (edge_y or x in (1, 38)):
                    continue
                if x == 38 and z >= 16:
                    continue
                v.set(x, y, z, teal if z <= 9 else cream)
    v.box(1, 1, 10, 38, 16, 10, cream)
    # chrome belt line
    for x in range(1, 39):
        for y in range(18):
            if v.get(x, y, 10):
                if y in (0, 17) or x in (1, 38):
                    v.set(x, y, 10, chrome)
    # side windows: z 12..15, panes separated by cream pillars
    for y in (0, 17):
        for x in range(4, 36):
            if x in (4, 12, 21, 29, 35):
                continue
            for z in range(12, 16):
                v.set(x, y, z, glass_hi if (z == 15 and x % 3 == 0) else glass)
        for z in range(3, 10):  # sliding door seam on both sides
            v.set(26, y, z, seam)
        v.set(24, y, 7, chrome)  # door handle
    # windscreen (front +X) and rear window
    for y in range(2, 16):
        if y in (8, 9):
            continue  # split windscreen pillar
        for z in range(12, 16):
            v.set(38, y, z, glass)
        for z in range(12, 15):
            v.set(1, y, z, glass)
    # front: round headlights, grille, bumper, a little emblem circle
    for cy in (3.5, 14.5):
        for y in range(18):
            for z in range(5, 11):
                if (y + 0.5 - cy) ** 2 + (z + 0.5 - 8.0) ** 2 <= 3.2:
                    v.set(39, y, z, lamp)
                elif (y + 0.5 - cy) ** 2 + (z + 0.5 - 8.0) ** 2 <= 5.5:
                    v.set(39, y, z, chrome)
    for y in range(6, 12):
        for z in (5, 7):
            v.set(39, y, z, dark)
    for y in range(7, 11):
        v.set(39, y, 9, chrome)
    v.box(39, 0, 3, 39, 17, 4, chrome)          # front bumper
    v.box(0, 0, 3, 0, 17, 4, chrome)            # rear bumper
    v.set(0, 1, 6, tail)
    v.set(0, 1, 7, tail)
    v.set(0, 16, 6, tail)
    v.set(0, 16, 7, tail)
    # spare wheel on the rear
    for y in range(18):
        for z in range(3, 13):
            d = (y + 0.5 - 9) ** 2 + (z + 0.5 - 8) ** 2
            if d <= 8.5:
                v.set(0, y, z, hub if d <= 2.5 else tyre)
    # wheels (in the XZ plane, both sides) with dark wheel arches
    for wx in (8, 31):
        for y in list(range(0, 3)) + list(range(15, 18)):
            for x in range(wx - 5, wx + 6):
                for z in range(0, 9):
                    d = (x + 0.5 - (wx + 0.5)) ** 2 + (z + 0.5 - 3.5) ** 2
                    if d <= 12.5 and y in (0, 17, 1, 16):
                        v.set(x, y, z, hub if d <= 3.0 and y in (0, 17) else tyre)
                    elif d <= 20 and z >= 3 and y in (0, 17):
                        v.set(x, y, z, dark)
    # undercarriage
    v.box(3, 3, 2, 36, 14, 2, dark)
    # roof rack: rails + crossbars + a wooden crate of luggage
    for x in range(5, 35):
        v.set(x, 2, 18, rack)
        v.set(x, 15, 18, rack)
    for x in range(5, 35, 6):
        v.box(x, 2, 18, x, 15, 18, rack)
    v.box(10, 4, 18, 17, 9, 19, wood)
    v.box(19, 9, 18, 24, 13, 18, v.col((150, 70, 60)))
    # the oddity: a small glowing amber beacon on the roof, near the front
    v.set(33, 8, 18, amber)
    v.set(33, 9, 18, amber)
    v.set(33, 8, 19, amber_core)
    v.set(33, 9, 19, amber_core)
    v.save(path)


def vox_house(path):
    v = Vox("house", 48, 40, 40, 4002)
    wall = [v.col((238, 236, 226)), v.col((214, 212, 204))]
    stone = v.shades((120, 116, 110), 3, 0.12)
    roof = v.shades((58, 56, 66), 3, 0.1)
    trim = v.col((250, 250, 246))
    win = v.col((255, 214, 110))
    win_hi = v.col((255, 240, 180))
    frame = v.col((90, 60, 40))
    door = v.shades((110, 66, 40), 2, 0.1)
    knob = v.col((220, 190, 90))
    porch = v.shades((150, 110, 70), 2, 0.1)
    brick = v.shades((150, 70, 54), 3, 0.1)
    x0, x1, y0, y1 = 4, 41, 4, 35
    wall_top = 19
    v.box(x0 - 1, y0 - 1, 0, x1 + 1, y1 + 1, 1, stone)     # foundation
    for z in range(2, wall_top + 1):                        # clapboard walls (hollow)
        c = wall[0] if z % 2 else wall[1]
        for x in range(x0, x1 + 1):
            v.set(x, y0, z, c)
            v.set(x, y1, z, c)
        for y in range(y0, y1 + 1):
            v.set(x0, y, z, c)
            v.set(x1, y, z, c)
    for z in range(2, wall_top + 1):                        # corner trim
        for (x, y) in ((x0, y0), (x0, y1), (x1, y0), (x1, y1)):
            v.set(x, y, z, trim)
    v.box(x0, y0, 2, x1, y1, 2, porch)                      # floor

    def window_x(x, yc, z0):
        for y in range(yc - 2, yc + 2):
            for z in range(z0, z0 + 5):
                v.set(x, y, z, win_hi if (y == yc - 2 and z == z0 + 4) else win)
        for y in range(yc - 3, yc + 3):
            v.set(x, y, z0 - 1, frame)
            v.set(x, y, z0 + 5, frame)
        for z in range(z0, z0 + 5):
            v.set(x, yc - 3, z, frame)
            v.set(x, yc + 2, z, frame)
        for z in range(z0, z0 + 5):
            v.set(x, yc, z, frame)

    def window_y(y, xc, z0):
        for x in range(xc - 2, xc + 2):
            for z in range(z0, z0 + 5):
                v.set(x, y, z, win)
        for x in range(xc - 3, xc + 3):
            v.set(x, y, z0 - 1, frame)
            v.set(x, y, z0 + 5, frame)
        for z in range(z0, z0 + 5):
            v.set(xc - 3, y, z, frame)
            v.set(xc + 2, y, z, frame)
            v.set(xc, y, z, frame)
    for yc in (10, 30):
        window_x(x1, yc, 6)
        window_x(x0, yc, 6)
        window_x(x1, yc, 13)
    window_x(x0, 20, 13)
    for xc in (11, 22, 33):
        window_y(y0, xc, 6)
        window_y(y1, xc, 6)
        window_y(y0, xc, 13)
        window_y(y1, xc, 13)
    # door on +X
    v.box(x1, 18, 3, x1, 21, 11, door)
    v.box(x1, 17, 3, x1, 17, 12, frame)
    v.box(x1, 22, 3, x1, 22, 12, frame)
    v.box(x1, 17, 12, x1, 22, 12, frame)
    v.set(x1 + 1, 21, 7, knob)
    # porch: deck, steps, posts, roof
    v.box(x1 + 1, 8, 2, 47, 31, 2, porch)
    v.box(46, 16, 1, 47, 23, 1, porch)
    v.box(47, 16, 0, 47, 23, 0, stone)
    for y in (8, 16, 23, 31):
        v.box(46, y, 3, 46, y, 11, trim)
    for y in range(8, 32):
        if not 16 <= y <= 23:
            v.set(46, y, 5, trim)                            # railing
    for x in range(x1 + 1, 48):
        for y in range(7, 33):
            v.set(x, y, 12 + (47 - x) // 3, roof)
    # gable roof, ridge along X
    z = wall_top + 1
    k = 0
    while y0 - 2 + k <= y1 + 2 - k:
        ya, yb = y0 - 2 + k, y1 + 2 - k
        for x in range(x0 - 2, x1 + 3):
            v.set(x, ya, z, roof)
            v.set(x, yb, z, roof)
            if ya + 1 <= yb - 1 and k > 0:
                v.set(x, ya + 1, z, roof)
                v.set(x, yb - 1, z, roof)
        for y in range(ya + 2, yb - 1):                      # gable ends
            c = wall[0] if z % 2 else wall[1]
            v.set(x0, y, z, c)
            v.set(x1, y, z, c)
        z += 1
        k += 1
    # little round attic window on +X gable
    for y in range(18, 22):
        for zz in range(24, 28):
            if (y - 19.5) ** 2 + (zz - 25.5) ** 2 <= 3.0:
                v.set(x1, y, zz, win)
    # chimney
    v.box(10, 10, 14, 13, 13, 39, brick)
    v.box(9, 9, 38, 14, 14, 38, stone)
    v.clear(11, 11, 39, 12, 12, 39)
    v.save(path)


def vox_barn(path):
    v = Vox("barn", 40, 32, 36, 4003)
    red = v.shades((164, 46, 40), 3, 0.08)
    white = v.col((240, 236, 226))
    roof = v.shades((80, 74, 70), 3, 0.08)
    stone = v.shades((110, 106, 100), 2, 0.1)
    dark = v.col((50, 30, 26))
    hay = v.shades((222, 190, 90), 2, 0.1)
    x0, x1, y0, y1 = 2, 37, 2, 29
    top = 16
    v.box(x0, y0, 0, x1, y1, 0, stone)
    for z in range(1, top + 1):
        for x in range(x0, x1 + 1):
            v.set(x, y0, z, red)
            v.set(x, y1, z, red)
        for y in range(y0, y1 + 1):
            v.set(x0, y, z, red)
            v.set(x1, y, z, red)
    for z in range(1, top + 1):
        for (x, y) in ((x0, y0), (x0, y1), (x1, y0), (x1, y1)):
            v.set(x, y, z, white)
    # gambrel roof profile across Y: (dy inset, z) pairs
    profile = []
    for k in range(7):
        profile.append((k // 2, top + 1 + k))       # steep lower slope
    for k in range(12):
        profile.append((3 + k, top + 8 + k // 2))   # shallow upper slope
    ymid = (y0 + y1) / 2
    for (ins, z) in profile:
        ya, yb = y0 - 1 + ins, y1 + 1 - ins
        if ya > yb:
            continue
        for x in range(x0 - 1, x1 + 2):
            v.set(x, ya, z, roof)
            v.set(x, yb, z, roof)
        for y in range(ya + 1, yb):                  # gable walls
            v.set(x0, y, z, red)
            v.set(x1, y, z, red)
    zr = max(z for _, z in profile)
    for x in range(x0 - 1, x1 + 2):
        for y in range(int(ymid) - 1, int(ymid) + 2):
            v.set(x, y, zr, roof)
    # big double door on +X with white X brace
    for y in range(9, 23):
        for z in range(1, 13):
            on_edge = y in (9, 22) or z in (1, 12) or y in (15, 16)
            diag = abs((y - 9) - (z - 1)) <= 0 or abs((22 - y) - (z - 1)) <= 0
            if y >= 16:
                diag = abs((y - 16) - (z - 1) // 2) <= 0 or abs((22 - y) - (z - 1) // 2) <= 0
            else:
                diag = abs((y - 9) - (z - 1) // 2) <= 0 or abs((15 - y) - (z - 1) // 2) <= 0
            v.set(x1, y, z, white if (on_edge or diag) else red)
    # hayloft door with hay peeking out
    for y in range(12, 20):
        for z in range(18, 24):
            edge = y in (12, 19) or z in (18, 23)
            v.set(x1, y, z, white if edge else dark)
    v.box(x1, 14, 19, x1, 17, 19, hay)
    v.box(x1 + 1, 14, 18, x1 + 1, 17, 18, hay)
    v.box(x1 + 1, 15, 25, x1 + 2, 16, 25, white)    # hay hoist beam
    # side windows
    for y in (y0, y1):
        for xc in (10, 28):
            for x in range(xc - 1, xc + 2):
                for z in range(7, 10):
                    v.set(x, y, z, white if x != xc and z != 8 else dark)
    v.save(path)


def vox_fence(path):
    v = Vox("fence", 16, 2, 8, 4004)
    wood = v.shades((136, 98, 62), 3, 0.12)
    post = v.shades((110, 78, 50), 2, 0.1)
    for px in (0, 14):
        v.box(px, 0, 0, px + 1, 1, 6, post)
        v.set(px, 0, 7, post[0])
        v.set(px + 1, 1, 7, post[1])
    for z in (2, 5):
        v.box(2, 0, z, 13, 1, z, wood)
    v.set(7, 0, 2, v.col((90, 66, 44)))  # a knot
    v.save(path)


def vox_van_interior(path):
    v = Vox("van_interior", 64, 64, 24, 4005)
    S, H = 64, 24
    floor = v.shades((52, 98, 92), 3, 0.06)
    floor_line = v.col((176, 136, 70))
    wall = v.shades((66, 122, 108), 3, 0.06)
    wall_d = v.col((44, 84, 76))
    brass = v.shades((206, 160, 80), 3, 0.1)
    brass_d = v.col((140, 100, 46))
    warm = v.col((255, 210, 130))
    warm_hi = v.col((255, 236, 190))
    wood = v.shades((120, 80, 50), 3, 0.1)
    rug = [v.col(c) for c in ((150, 46, 48), (208, 120, 58), (232, 212, 170), (44, 116, 116))]
    couch = v.shades((176, 92, 60), 3, 0.08)
    cushion = v.col((230, 190, 120))
    leaf = v.shades((64, 140, 70), 3, 0.15)
    pot = v.shades((170, 96, 64), 2, 0.1)
    glow = [v.col((120, 240, 220)), v.col((255, 190, 80)), v.col((250, 110, 110)), v.col((180, 140, 255))]
    books = [v.col(c) for c in ((170, 50, 50), (60, 90, 160), (60, 130, 80), (210, 170, 60), (120, 60, 130), (220, 220, 200))]
    # floor (z=0) with brass inlay grid every 8 voxels
    for x in range(S):
        for y in range(S):
            v.set(x, y, 0, floor_line if (x % 8 == 0 or y % 8 == 0) else floor)
    # walls around the perimeter: ribbed panels, brass rails, warm wall lights
    for z in range(1, H):
        for i in range(S):
            for (x, y) in ((0, i), (S - 1, i), (i, 0), (i, S - 1)):
                along = y if x in (0, S - 1) else x
                if z in (8, 9) or z == H - 1:
                    c = brass
                elif along % 8 == 0:
                    c = brass_d
                elif along % 8 in (1, 7):
                    c = wall_d
                else:
                    c = wall
                v.set(x, y, z, c)
    # wall lamps (warm glowing squares between ribs, above the rail)
    for i in range(4, S, 16):
        for (x, y) in ((0, i), (S - 1, i), (i, 0), (i, S - 1)):
            for dz in range(13, 16):
                v.set(x, y, dz, warm)
            v.set(x, y, 14, warm_hi)
    # door gap in -X wall, centred: y 29..34, z 1..12
    v.clear(0, 29, 1, 0, 34, 12)
    v.box(0, 28, 1, 0, 28, 13, brass)
    v.box(0, 35, 1, 0, 35, 13, brass)
    v.box(0, 28, 13, 0, 35, 13, brass)
    # rug (part of the floor layer, so it is walkable): 16..47 x 18..45
    for x in range(14, 50):
        for y in range(18, 46):
            dx, dy = abs(x - 31.5), abs(y - 31.5)
            if x in (14, 49) or y in (18, 45):
                c = rug[0]
            elif x in (15, 48) or y in (19, 44):
                c = rug[2]
            else:
                c = rug[int(dx + dy) // 3 % 4]
            v.set(x, y, 0, c)
    # central console: hexagonal pedestal ~12 wide, 8 tall
    cx, cy = 32.0, 32.0

    def in_hex(x, y, r):
        px, py = abs(x + 0.5 - cx), abs(y + 0.5 - cy)
        return py <= r * 0.866 and px * 0.866 + py * 0.5 <= r * 0.866
    for z in range(1, 9):
        r = 6.2 if z in (1, 7, 8) else 4.8 if z < 6 else 5.6
        for x in range(20, 44):
            for y in range(20, 44):
                if in_hex(x, y, r):
                    border = not in_hex(x, y, r - 1.0)
                    c = brass if z in (1, 8) else (brass_d if border and z % 2 else wall_d if border else brass_d)
                    if z in (2, 3, 4, 5) and border and (x + y + z) % 5 == 0:
                        c = glow[(x + y) % 4]
                    v.set(x, y, z, c)
    # control surface: glowing buttons and levers on top
    for x in range(20, 44):
        for y in range(20, 44):
            if in_hex(x, y, 6.2) and not in_hex(x, y, 2.0):
                if (x * 7 + y * 3) % 6 == 0:
                    v.set(x, y, 9, glow[(x + 2 * y) % 4])
    v.box(28, 31, 9, 28, 31, 11, brass)
    v.set(28, 31, 12, glow[2])
    v.box(36, 33, 9, 36, 33, 10, brass)
    v.set(36, 33, 11, glow[0])
    # a small armillary globe on top (brass rings round an amber core)
    for x in range(28, 37):
        for y in range(28, 37):
            for z in range(9, 17):
                d = math.sqrt((x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 + (z + 0.5 - 13) ** 2)
                if d <= 1.6:
                    v.set(x, y, z, warm_hi)
                elif 3.0 <= d <= 3.9 and (abs(z + 0.5 - 13) < 0.8 or abs(x + 0.5 - cx) < 0.8):
                    v.set(x, y, z, brass)
    v.box(31, 31, 9, 32, 32, 9, brass_d)
    # couch along -Y wall
    v.box(10, 3, 1, 26, 8, 3, couch)
    v.box(10, 2, 4, 26, 3, 8, couch)
    v.box(9, 2, 1, 9, 8, 6, couch)
    v.box(27, 2, 1, 27, 8, 6, couch)
    for x in (12, 17, 22):
        v.box(x, 4, 4, x + 3, 6, 4, cushion)
    # low table in front of the couch
    v.box(14, 11, 3, 22, 14, 3, wood)
    for (x, y) in ((14, 11), (22, 11), (14, 14), (22, 14)):
        v.box(x, y, 1, x, y, 2, wood)
    v.set(18, 12, 4, v.col((240, 240, 230)))
    v.set(19, 12, 4, v.col((240, 240, 230)))

    def plant(px, py, h):
        v.box(px - 1, py - 1, 1, px + 1, py + 1, 3, pot)
        for z in range(4, 4 + h):
            v.set(px, py, z, leaf)
        for z in range(5, 4 + h, 2):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0), (0, 2), (0, -2)):
                if v.rng.random() < 0.7:
                    v.set(px + dx, py + dy, z, leaf)
    plant(4, 4, 9)
    plant(59, 4, 11)
    plant(59, 59, 8)
    plant(4, 59, 10)
    plant(4, 22, 6)
    plant(4, 41, 6)
    # bookshelves along +Y wall and +X wall
    for (xa, xb) in ((12, 26), (38, 52)):
        v.box(xa, 59, 1, xb, 62, 1, wood)
        for z in range(1, 17):
            v.set(xa, 59, z, wood)
            v.set(xb, 59, z, wood)
            v.set(xa, 62, z, wood)
            v.set(xb, 62, z, wood)
        for zs in (5, 10, 16):
            v.box(xa, 59, zs, xb, 62, zs, wood)
        for zs in (1, 5, 10):
            for x in range(xa + 1, xb):
                h = 2 + (x * 7 + zs) % 3
                c = books[(x * 5 + zs) % len(books)]
                for z in range(zs + 1, min(zs + 1 + h, zs + 5)):
                    for y in (60, 61):
                        v.set(x, y, z, c)
    for (ya, yb) in ((10, 22), (42, 54)):
        for z in range(1, 15):
            v.set(62, ya, z, wood)
            v.set(62, yb, z, wood)
            v.set(59, ya, z, wood)
            v.set(59, yb, z, wood)
        for zs in (1, 7, 14):
            v.box(59, ya, zs, 62, yb, zs, wood)
        for zs in (1, 7):
            for y in range(ya + 1, yb):
                c = books[(y * 3 + zs) % len(books)]
                for z in range(zs + 1, zs + 3 + y % 3):
                    v.set(61, y, z, c)
                    v.set(62, y, z, c)
                if y % 4 == 0:
                    v.set(60, y, zs + 1, glow[1])  # little jars of glowing things
    # hanging warm lamps from the (open) ceiling rail level
    for (x, y) in ((16, 16), (48, 16), (16, 48), (48, 48)):
        v.box(x, y, 19, x, y, 22, brass_d)
        v.box(x - 1, y - 1, 17, x + 1, y + 1, 18, warm)
        v.set(x, y, 16, warm_hi)
    # sanity: keep a clear 6-voxel-wide walkway from the door to the console
    v.clear(1, 29, 1, 25, 34, H - 1)
    v.save(path)


def vox_market_stall(path):
    v = Vox("market_stall", 24, 16, 24, 4006)
    wood = v.shades((126, 86, 52), 3, 0.1)
    red = v.col((196, 52, 52))
    cream = v.col((240, 228, 196))
    fruit = [v.col(c) for c in ((230, 70, 50), (250, 170, 50), (120, 190, 60), (150, 90, 170), (240, 220, 80))]
    brass = v.col((210, 164, 80))
    cloth = v.shades((60, 110, 120), 2, 0.1)
    # counter
    v.box(2, 9, 0, 21, 14, 7, wood)
    v.box(2, 14, 1, 21, 14, 6, cloth)              # cloth front (+Y faces the customer)
    v.box(1, 8, 8, 22, 15, 8, wood)               # counter top
    # posts
    for (x, y) in ((1, 1), (22, 1), (1, 14), (22, 14)):
        v.box(x, y, 0, x, y, 18 if y == 14 else 21, wood)
    # sloped striped awning (higher at the back, -Y)
    for y in range(0, 16):
        z = 21 - y // 4
        for x in range(0, 24):
            v.set(x, y, z, red if (x // 3) % 2 == 0 else cream)
    for x in range(0, 24):  # scalloped front edge
        if (x // 3) % 2 == 0:
            v.set(x, 15, 16 - (x % 3 == 1), red)
        else:
            v.set(x, 15, 17, cream)
    # goods on the counter: piles of fruit and a few brass trinkets
    for i, x0 in enumerate((3, 8, 13)):
        for x in range(x0, x0 + 4):
            for y in range(9, 14):
                v.set(x, y, 9, fruit[i])
                if 1 <= x - x0 <= 2 and 10 <= y <= 12:
                    v.set(x, y, 10, fruit[i])
    for x in (18, 20):
        v.box(x, 11, 9, x, 11, 11, brass)
        v.set(x, 11, 12, fruit[4])
    # back shelf with jars
    v.box(2, 2, 10, 21, 3, 10, wood)
    for x in range(3, 21, 3):
        v.box(x, 2, 11, x + 1, 3, 12, fruit[(x // 3) % 5])
    # hanging sign
    v.box(9, 15, 13, 14, 15, 15, cream)
    v.box(10, 15, 14, 13, 15, 14, red)
    v.save(path)


def vox_bookshelf(path):
    v = Vox("bookshelf", 16, 6, 24, 4007)
    wood = v.shades((100, 66, 40), 3, 0.1)
    back = v.col((70, 46, 30))
    books = [v.col(c) for c in ((168, 48, 48), (54, 86, 156), (58, 128, 78), (214, 172, 60), (118, 58, 128),
                                (226, 222, 200), (200, 110, 50), (40, 120, 130))]
    gold = v.col((240, 206, 110))
    v.box(0, 0, 0, 15, 5, 0, wood)
    v.box(0, 0, 23, 15, 5, 23, wood)
    v.box(0, 0, 0, 0, 5, 23, wood)
    v.box(15, 0, 0, 15, 5, 23, wood)
    v.box(1, 5, 1, 14, 5, 22, back)
    shelves = [0, 6, 12, 18, 23]
    for z in shelves[1:-1]:
        v.box(1, 0, z, 14, 5, z, wood)
    rng = random.Random(4070)
    for s in range(4):
        zb = shelves[s] + 1
        maxh = shelves[s + 1] - zb
        x = 1
        while x <= 14:
            w = 1 if rng.random() < 0.75 else 2
            h = rng.randint(max(2, maxh - 2), maxh)
            c = books[rng.randrange(len(books))]
            if rng.random() < 0.08:
                x += 1  # a gap
                continue
            for bx in range(x, min(x + w, 15)):
                for y in range(1, 5):
                    for z in range(zb, zb + h):
                        v.set(bx, y, z, c)
                if h >= 3:
                    v.set(bx, 1, zb + h - 2, gold)   # gilded spine band
            x += w
    v.save(path)


def vox_well(path):
    v = Vox("well", 14, 14, 16, 4008)
    stone = v.shades((128, 124, 118), 3, 0.12)
    mortar = v.col((90, 86, 82))
    water = v.col((40, 70, 120))
    water_hi = v.col((90, 130, 180))
    wood = v.shades((120, 82, 50), 2, 0.1)
    roof = v.shades((150, 60, 44), 2, 0.1)
    rope = v.col((200, 180, 130))
    iron = v.col((70, 70, 76))
    c = 6.5
    for z in range(0, 6):
        for x in range(14):
            for y in range(14):
                d = math.hypot(x + 0.5 - 7, y + 0.5 - 7)
                if 4.4 <= d <= 6.6:
                    v.set(x, y, z, mortar if (z % 2 == 0 and (x + y) % 4 == 0) else stone)
                elif d < 4.4 and z == 1:
                    v.set(x, y, z, water_hi if (x + y) % 5 == 0 else water)
    v.box(1, 6, 6, 1, 7, 13, wood)                  # posts
    v.box(12, 6, 6, 12, 7, 13, wood)
    v.box(1, 6, 11, 12, 7, 11, wood)                # crank axle
    v.box(12, 8, 11, 12, 9, 11, iron)               # crank handle
    v.set(12, 9, 10, iron)
    v.box(6, 6, 7, 7, 7, 10, rope)                  # rope
    v.box(5, 5, 5, 8, 8, 6, wood)                   # bucket
    v.clear(6, 6, 6, 7, 7, 6)
    v.set(6, 6, 6, water)
    for k in range(5):                              # little gable roof over the crank
        for x in range(0, 14):
            v.set(x, 2 + k, 12 + k, roof)
            v.set(x, 11 - k, 12 + k, roof)
    v.save(path)


def vox_lantern_post(path):
    v = Vox("lantern_post", 4, 4, 20, 4009)
    wood = v.shades((104, 72, 46), 3, 0.1)
    stone = v.col((110, 108, 104))
    iron = v.col((56, 54, 58))
    v.box(0, 0, 0, 3, 3, 1, stone)
    v.box(1, 1, 2, 2, 2, 18, wood)
    v.box(1, 1, 19, 3, 2, 19, wood)                 # arm reaching out to +X
    v.set(3, 1, 18, iron)                           # hook
    v.set(3, 1, 17, iron)
    v.set(3, 2, 16, iron)
    v.save(path)


# =============================================================================
# Sounds (PCM16 mono 22050 Hz)
# =============================================================================

SR = 22050
TAU = 2 * math.pi
PEAK = 10 ** (-3 / 20)  # -3 dBFS


def silence(sec):
    return [0.0] * int(round(sec * SR))


def normalise(buf, peak=PEAK):
    m = max(abs(s) for s in buf) or 1.0
    g = peak / m
    return [s * g for s in buf]


def fade(buf, fin=0.004, fout=0.01):
    n = len(buf)
    a, b = int(fin * SR), int(fout * SR)
    for i in range(min(a, n)):
        buf[i] *= i / a
    for i in range(min(b, n)):
        buf[n - 1 - i] *= i / b
    return buf


def loop_align(buf):
    """Rotate a periodic buffer so it starts on an upward zero crossing.
    (Rotation keeps a periodic signal seamless; the last sample is then just
    below zero and the first just above, so the wrap is click-free.)"""
    n = len(buf)
    best, bi = 1e9, 0
    for i in range(n):
        a, b = buf[i - 1], buf[i]
        if a < 0 <= b:
            score = abs(a) + abs(b)
            if score < best:
                best, bi = score, i
    return buf[bi:] + buf[:bi]


def write_wav(path, buf, loop=False):
    if loop:
        buf = loop_align(normalise(buf))
    else:
        buf = normalise(fade(buf))
    data = bytearray()
    for s in buf:
        data += struct.pack("<h", int(clamp(round(s * 32767), -32768, 32767)))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(data))


def white(n, seed):
    r = random.Random(seed)
    return [r.uniform(-1, 1) for _ in range(n)]


def lowpass(x, fc, state=0.0):
    a = 1 - math.exp(-TAU * fc / SR)
    y, out = state, []
    for s in x:
        y += a * (s - y)
        out.append(y)
    return out


def highpass(x, fc):
    lp = lowpass(x, fc)
    return [a - b for a, b in zip(x, lp)]


def svf(x, fc, q=0.5, mode="band"):
    """Chamberlin state-variable filter; fc may be a number or a per-sample list."""
    low = band = 0.0
    out = []
    damp = 2 * q
    for i, s in enumerate(x):
        f = fc[i] if isinstance(fc, list) else fc
        f = 2 * math.sin(math.pi * min(f, SR / 6) / SR)
        low += f * band
        high = s - low - damp * band
        band += f * high
        out.append(band if mode == "band" else low if mode == "low" else high)
    return out


def periodic(x, fn):
    """Apply a (linear, time-invariant) filter to a periodic signal so that the
    result is also periodic: filter three periods and keep the last one."""
    n = len(x)
    return fn(x + x + x)[2 * n:]


def add_at(buf, start, sig, gain=1.0, wrap=False):
    n = len(buf)
    for i, s in enumerate(sig):
        j = start + i
        if wrap:
            buf[j % n] += s * gain
        elif 0 <= j < n:
            buf[j] += s * gain


def tone(freq, dur, harmonics=((1, 1.0),), attack=0.005, decay=None, release=0.02, vib=0.0, glide=None):
    """Simple additive tone with exp decay envelope; freq may glide to `glide`."""
    n = int(dur * SR)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / SR
        f = freq if glide is None else freq * (glide / freq) ** (i / n)
        if vib:
            f *= 1 + vib * math.sin(TAU * 5.0 * t)
        ph += f / SR
        s = 0.0
        for h, a in harmonics:
            s += a * math.sin(TAU * ph * h)
        env = min(1.0, t / attack) if attack > 0 else 1.0
        if decay:
            env *= math.exp(-t / decay)
        rem = (n - i) / SR
        if rem < release:
            env *= rem / release
        out.append(s * env)
    return out


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def snd_step(path):
    n = int(0.15 * SR)
    nz = white(n, 5001)
    body = lowpass(nz, 900)
    crunch = svf(white(n, 5002), 3200, 0.4)
    out = []
    for i in range(n):
        t = i / SR
        env = (1 - math.exp(-t / 0.004)) * math.exp(-t / 0.035)
        thud = math.sin(TAU * (95 - 200 * t) * t) * math.exp(-t / 0.03)
        rustle = crunch[i] * math.exp(-t / 0.05) * (0.6 + 0.4 * math.sin(TAU * 60 * t))
        out.append(body[i] * env * 2.0 + thud * 0.5 + rustle * 0.35)
    write_wav(path, out)


def snd_door(path):
    n = int(0.6 * SR)
    rng = random.Random(5003)
    exc = [0.0] * n
    # stick-slip creak: irregular impulse train with a wandering rate
    t = 0.0
    while t < 0.45:
        rate = 70 + 60 * math.sin(TAU * 2.3 * t) + 40 * t + rng.uniform(-12, 12)
        i = int(t * SR)
        exc[i] = rng.uniform(0.7, 1.0) * min(1.0, t / 0.05)
        t += 1.0 / rate
    creak = [a * 0.6 + b * 0.4 for a, b in zip(svf(exc, 1150, 0.06), svf(exc, 2350, 0.08))]
    # final clunk of the latch
    clunk = silence(0.6)
    k0 = int(0.47 * SR)
    nz = lowpass(white(n - k0, 5004), 600)
    for i in range(n - k0):
        tt = i / SR
        clunk[k0 + i] = (math.sin(TAU * 70 * tt) * 0.8 + nz[i] * 2.0) * math.exp(-tt / 0.03)
    out = [creak[i] * (1.0 if i < k0 else math.exp(-(i - k0) / SR / 0.01)) + clunk[i] * 0.9 for i in range(n)]
    write_wav(path, out)


def snd_interact(path):
    out = silence(0.2)
    add_at(out, 0, tone(660, 0.09, ((1, 1), (2, 0.25)), 0.003, 0.04))
    add_at(out, int(0.06 * SR), tone(990, 0.13, ((1, 1), (2, 0.2)), 0.003, 0.05))
    write_wav(path, out)


def snd_pickup(path):
    out = silence(0.6)
    notes = [84, 88, 91, 96]  # C6 E6 G6 C7
    for k, m in enumerate(notes):
        add_at(out, int(k * 0.065 * SR), tone(midi(m), 0.4, ((1, 1), (2, 0.3), (3, 0.15)), 0.002, 0.09), 0.8)
    rng = random.Random(5005)
    for _ in range(14):  # sparkles
        st = rng.uniform(0.05, 0.45)
        add_at(out, int(st * SR), tone(rng.uniform(3000, 5200), 0.05, ((1, 1),), 0.001, 0.012), 0.25)
    write_wav(path, out)


def snd_quest_done(path):
    out = silence(1.25)
    brass = ((1, 1.0), (2, 0.5), (3, 0.3), (4, 0.15), (5, 0.08))
    seq = [(0.0, 67, 0.3), (0.18, 72, 0.3), (0.36, 76, 0.85)]
    for st, m, d in seq:
        add_at(out, int(st * SR), tone(midi(m), d, brass, 0.02, 0.5 if d > 0.5 else 0.25, 0.15, vib=0.004), 0.7)
    for m in (60, 64, 67):  # warm held chord under the last note
        add_at(out, int(0.36 * SR), tone(midi(m), 0.85, ((1, 1), (2, 0.2)), 0.06, 0.6, 0.2), 0.3)
    add_at(out, 0, tone(midi(48), 1.2, ((1, 1), (2, 0.3)), 0.02, 0.6, 0.2), 0.4)
    write_wav(path, lowpass(out, 5000))


def snd_travel(path):
    dur = 4.0
    n = int(dur * SR)
    # rising band-passed noise sweep
    fc = [200 * (16 ** ((i / n) ** 1.4)) for i in range(n)]
    sweep = svf(white(n, 5006), fc, 0.18)
    out = []
    ph = [0.0] * 4
    det = [1.0, 1.007, 0.993, 1.5]
    for i in range(n):
        t = i / SR
        p = t / dur
        # swirl: an LFO that speeds up, used for amplitude + pitch (doppler-ish)
        swirl_rate = 1.5 + 9 * p * p
        sw = math.sin(TAU * (1.5 * t + 3 * t * p * p))
        base = 110 * (2 ** (2.2 * p)) * (1 + 0.035 * sw)
        s = 0.0
        for k in range(4):
            ph[k] += base * det[k] / SR
            # soft saw-ish: three harmonics
            x = ph[k] % 1.0
            s += math.sin(TAU * x) + 0.4 * math.sin(2 * TAU * x) + 0.18 * math.sin(3 * TAU * x)
        env = min(1.0, t / 0.6) * (1.0 if t < 3.35 else max(0.0, 1 - (t - 3.35) / 0.25))
        trem = 0.7 + 0.3 * math.sin(TAU * swirl_rate * t)
        out.append((s * 0.12 * trem + sweep[i] * 1.1 * (0.4 + 0.6 * p)) * env)
    # soft arrival thump + air release
    k0 = int(3.55 * SR)
    air = lowpass(white(n - k0, 5007), 1500)
    for i in range(n - k0):
        t = i / SR
        out[k0 + i] += math.sin(TAU * (60 - 25 * t) * t) * math.exp(-t / 0.12) * 0.9
        out[k0 + i] += air[i] * math.exp(-t / 0.08) * 0.5
    write_wav(path, out)


def snd_voice_blip(path):
    dur = 0.14
    n = int(dur * SR)
    exc, ph = [], 0.0
    for i in range(n):
        t = i / SR
        f0 = 170 * (1 + 0.35 * (i / n)) * (1 + 0.02 * math.sin(TAU * 30 * t))
        ph += f0 / SR
        if ph >= 1.0:
            ph -= 1.0
            exc.append(1.0)
        else:
            exc.append(0.0)
    # vowel morph "o" -> "a" via two formant resonators
    f1 = [450 + 300 * (i / n) for i in range(n)]
    f2 = [800 + 450 * (i / n) for i in range(n)]
    a = svf(exc, f1, 0.08)
    b = svf(exc, f2, 0.1)
    out = []
    for i in range(n):
        t = i / SR
        env = min(1.0, t / 0.012) * min(1.0, (dur - t) / 0.04)
        out.append((a[i] + 0.6 * b[i]) * env)
    write_wav(path, lowpass(out, 3500))


def snd_ui_move(path):
    out = silence(0.07)
    add_at(out, 0, tone(1250, 0.05, ((1, 1), (3, 0.15)), 0.001, 0.015))
    write_wav(path, out)


def snd_ui_select(path):
    out = silence(0.16)
    add_at(out, 0, tone(700, 0.06, ((1, 1), (3, 0.2)), 0.002, 0.03))
    add_at(out, int(0.05 * SR), tone(1050, 0.1, ((1, 1), (3, 0.2)), 0.002, 0.04))
    write_wav(path, out)


# --- seamless ambient loops ---------------------------------------------------

def wind(n, seed, fc=350, cycles=1, depth=0.5):
    """Seamless filtered-noise wind with slow swells (integer cycles per loop)."""
    nz = periodic(white(n, seed), lambda x: lowpass(lowpass(x, fc), fc))
    out = []
    for i in range(n):
        p = i / n
        sw = 1 - depth + depth * (0.5 + 0.5 * math.sin(TAU * cycles * p)) * (0.7 + 0.3 * math.sin(TAU * (cycles + 2) * p + 1.3))
        out.append(nz[i] * sw)
    return out


def chirp_cricket(carrier, pulses=3):
    sig = []
    for k in range(pulses):
        seg = int(0.016 * SR)
        for i in range(seg):
            t = i / SR
            env = math.sin(math.pi * i / seg) ** 2
            sig.append(math.sin(TAU * carrier * t) * env)
        sig += [0.0] * int(0.014 * SR)
    return sig


def snd_ambient_night(path):
    L = 8.0
    n = int(L * SR)
    rng = random.Random(5101)
    out = [s * 3.0 for s in wind(n, 5102, 300, 1, 0.6)]
    for carrier, gain, period in ((4300, 0.30, 0.62), (4750, 0.18, 0.81), (5150, 0.12, 0.53)):
        t = rng.uniform(0, 0.5)
        ch = chirp_cricket(carrier, 3)
        while t < L:
            add_at(out, int(t * SR), ch, gain * rng.uniform(0.7, 1.0), wrap=True)
            t += period * rng.uniform(0.9, 1.1)
    write_wav(path, out, loop=True)


def snd_ambient_fen(path):
    L = 8.0
    n = int(L * SR)
    rng = random.Random(5201)
    out = [s * 2.5 for s in wind(n, 5202, 250, 1, 0.5)]
    # frogs: buzzy two-part "rib-bit" croaks
    for _ in range(9):
        st = rng.uniform(0, L)
        f = rng.uniform(260, 420)
        croak = []
        for part in range(2):
            seg = int(rng.uniform(0.06, 0.1) * SR)
            for i in range(seg):
                t = i / SR
                pulse = 1.0 if (t * 38) % 1.0 < 0.35 else 0.15
                env = math.sin(math.pi * i / seg)
                croak.append(math.sin(TAU * f * t) * pulse * env + 0.4 * math.sin(TAU * 2 * f * t) * pulse * env)
            croak += [0.0] * int(0.05 * SR)
        add_at(out, int(st * SR), croak, rng.uniform(0.25, 0.5), wrap=True)
    # bubbles: quick rising sine blips
    for _ in range(26):
        st = rng.uniform(0, L)
        f0 = rng.uniform(300, 600)
        add_at(out, int(st * SR), tone(f0, 0.05, ((1, 1),), 0.002, 0.015, 0.005, glide=f0 * 2.2),
               rng.uniform(0.1, 0.25), wrap=True)
    write_wav(path, out, loop=True)


def bell(freq, dur, decay):
    return tone(freq, dur, ((1, 1.0), (2.76, 0.5), (5.4, 0.25), (8.93, 0.12)), 0.002, decay, 0.05)


def snd_ambient_market(path):
    L = 8.0
    n = int(L * SR)
    rng = random.Random(5301)
    # distant murmur: band-passed noise with slow movement
    murmur = periodic(white(n, 5302), lambda x: svf(x, 450, 0.7))
    out = [m * 0.5 * (0.7 + 0.3 * math.sin(TAU * 3 * i / n)) for i, m in enumerate(murmur)]
    # clockwork: tick-tock every 0.25 s plus a little ratchet
    tick_src = white(int(0.012 * SR), 5303)
    tick = [s * math.exp(-i / (0.002 * SR)) for i, s in enumerate(svf(tick_src, 3200, 0.15))]
    tock = [s * math.exp(-i / (0.003 * SR)) for i, s in enumerate(svf(tick_src, 1900, 0.15))]
    for k in range(int(L / 0.25)):
        add_at(out, int(k * 0.25 * SR), tick if k % 2 == 0 else tock, 0.6, wrap=True)
    for k in range(int(L / 2)):
        for j in range(5):
            add_at(out, int((k * 2 + 1.1 + j * 0.03) * SR), tick, 0.25, wrap=True)
    # distant chimes (pentatonic), low-passed for distance
    chimes = [0.0] * n
    scale_notes = [72, 74, 76, 79, 81, 84]
    for _ in range(7):
        st = rng.uniform(0, L)
        add_at(chimes, int(st * SR), bell(midi(rng.choice(scale_notes)), 2.5, 0.8), rng.uniform(0.3, 0.5), wrap=True)
    chimes = periodic(chimes, lambda x: lowpass(x, 2500))
    out = [a + b for a, b in zip(out, chimes)]
    write_wav(path, out, loop=True)


def snd_ambient_library(path):
    L = 8.0
    n = int(L * SR)
    rng = random.Random(5401)
    out = []
    for i in range(n):  # low hum: all partials are integer cycles per 8 s loop
        t = i / SR
        p = i / n
        mod = 0.75 + 0.25 * math.sin(TAU * 2 * p)
        out.append((math.sin(TAU * 55 * t) * 0.5 + math.sin(TAU * 82.5 * t) * 0.25 +
                    math.sin(TAU * 110.125 * t) * 0.15) * mod * 0.6)
    rumble = periodic(white(n, 5402), lambda x: lowpass(lowpass(x, 120), 120))
    out = [a + r * 3.0 for a, r in zip(out, rumble)]
    drips = [0.0] * n
    for _ in range(7):
        st = rng.uniform(0, L)
        f = rng.uniform(900, 1400)
        add_at(drips, int(st * SR), tone(f, 0.12, ((1, 1),), 0.001, 0.03, 0.01, glide=f * 1.6), rng.uniform(0.4, 0.7), wrap=True)
    # cavernous echoes (circular, so still seamless)
    echo = list(drips)
    for k, g in ((1, 0.45), (2, 0.22), (3, 0.1)):
        d = int(0.29 * k * SR)
        for i in range(n):
            echo[i] += drips[(i - d) % n] * g
    echo = periodic(echo, lambda x: lowpass(x, 3000))
    out = [a + b * 0.8 for a, b in zip(out, echo)]
    write_wav(path, out, loop=True)


def snd_van_hum(path):
    L = 4.0
    n = int(L * SR)
    noise = periodic(white(n, 5501), lambda x: lowpass(lowpass(x, 200), 200))
    out = []
    for i in range(n):
        t = i / SR
        p = i / n
        pulse = 0.72 + 0.28 * (0.5 + 0.5 * math.sin(TAU * 2 * p - math.pi / 2)) ** 2  # slow 0.5 Hz breath
        drift = 1 + 0.004 * math.sin(TAU * 1 * p)
        s = (math.sin(TAU * 55 * t) * 0.55 + math.sin(TAU * 110 * t) * 0.3 +
             math.sin(TAU * 165 * t) * 0.14 + math.sin(TAU * 220.25 * t) * 0.06 +
             math.sin(TAU * 330.5 * t) * 0.04 * pulse)
        out.append(s * pulse * drift + noise[i] * 2.0)
    write_wav(path, out, loop=True)


def snd_music_title(path):
    beat = 0.5
    bars = 8
    L = bars * 4 * beat
    n = int(L * SR)
    out = [0.0] * n
    chords = [(57, 60, 64), (53, 57, 60), (50, 53, 57), (52, 56, 59),   # Am F Dm E
              (53, 57, 60), (55, 59, 62), (55, 60, 64), (55, 60, 64)]   # F G C C
    roots = [45, 41, 38, 40, 41, 43, 48, 48]
    # pad: detuned soft partials, overlapping into the next bar (wraps at the loop)
    for b, ch in enumerate(chords):
        st = int(b * 4 * beat * SR)
        for m in ch:
            for det in (0.997, 1.0, 1.003):
                add_at(out, st, tone(midi(m) * det, 4 * beat + 0.35, ((1, 1), (2, 0.18)), 0.35, None, 0.5), 0.05, wrap=True)
    # bass: root on beats 1 and 3, fifth on beat 4 'and'
    for b, r in enumerate(roots):
        for (bt, m, d) in ((0, r, 1.6), (2, r, 1.0), (3.5, r + 7, 0.45)):
            add_at(out, int((b * 4 + bt) * beat * SR), tone(midi(m), d * beat, ((1, 1), (2, 0.25), (3, 0.08)), 0.01, 0.6, 0.06), 0.22, wrap=True)
    # arpeggio: soft plucks of chord tones an octave up
    for b, ch in enumerate(chords):
        pattern = [ch[0], ch[1], ch[2], ch[1] + 12, ch[2], ch[1], ch[0] + 12, ch[2]]
        for k, m in enumerate(pattern):
            add_at(out, int((b * 4 + k * 0.5) * beat * SR), tone(midi(m + 12), 0.3, ((1, 1), (2, 0.1)), 0.003, 0.12, 0.05), 0.07, wrap=True)
    # melody (original): (beats, midi) per bar, None = rest
    melody = [
        [(1, 76), (0.5, 72), (0.5, 74), (1, 76), (1, 69)],
        [(1.5, 77), (0.5, 76), (1, 72), (1, 69)],
        [(1, 74), (1, 77), (1.5, 81), (0.5, 79)],
        [(1, 71), (1, 68), (1, 71), (1, 76)],
        [(1.5, 81), (0.5, 79), (1, 77), (1, 72)],
        [(1, 74), (1, 71), (1, 74), (1, 79)],
        [(1.5, 76), (0.5, 79), (1, 84), (1, 79)],
        [(2, 76), (2, None)],
    ]
    mel = [0.0] * n
    for b, bar in enumerate(melody):
        t = b * 4
        for d, m in bar:
            if m is not None:
                add_at(mel, int(t * beat * SR),
                       tone(midi(m), d * beat + 0.12, ((1, 1), (2, 0.3), (3, 0.1)), 0.015, 0.9, 0.1, vib=0.003),
                       0.2, wrap=True)
            t += d
    # gentle circular echo on the melody (dotted eighth)
    d = int(0.75 * beat * SR)
    mel = [mel[i] + 0.3 * mel[(i - d) % n] + 0.1 * mel[(i - 2 * d) % n] for i in range(n)]
    out = [a + b for a, b in zip(out, mel)]
    out = periodic(out, lambda x: lowpass(x, 4500))
    write_wav(path, out, loop=True)


# =============================================================================
# Asset table
# =============================================================================

ASSETS = [
    ("textures/grass.tga", tex_grass),
    ("textures/dirt.tga", tex_dirt),
    ("textures/cobble.tga", tex_cobble),
    ("textures/wood_planks.tga", tex_wood_planks),
    ("textures/house_wall.tga", tex_house_wall),
    ("textures/roof.tga", tex_roof),
    ("textures/stone.tga", tex_stone),
    ("textures/water.tga", tex_water),
    ("textures/sand.tga", tex_sand),
    ("textures/metal_panel.tga", tex_metal_panel),
    ("textures/crystal.tga", tex_crystal),
    ("textures/carpet.tga", tex_carpet),
    ("textures/font.tga", tex_font),
    ("textures/ui.tga", tex_ui),
    ("textures/tree_pine.tga", spr_tree_pine),
    ("textures/tree_oak.tga", spr_tree_oak),
    ("textures/bush.tga", spr_bush),
    ("textures/flowers.tga", spr_flowers),
    ("textures/moon.tga", spr_moon),
    ("textures/star.tga", spr_star),
    ("textures/npc_farmer.tga", spr_npc_farmer),
    ("textures/npc_fen_keeper.tga", spr_npc_fen_keeper),
    ("textures/npc_child.tga", spr_npc_child),
    ("textures/npc_merchant.tga", spr_npc_merchant),
    ("textures/npc_robot.tga", spr_npc_robot),
    ("textures/npc_librarian.tga", spr_npc_librarian),
    ("textures/lantern_off.tga", spr_lantern_off),
    ("textures/lantern_on.tga", spr_lantern_on),
    ("textures/gear.tga", spr_gear),
    ("textures/book.tga", spr_book),
    ("textures/firefly.tga", spr_firefly),
    ("textures/sky_stars.tga", tex_sky_stars),
    ("models/plane.obj", obj_plane),
    ("models/cube.obj", obj_cube),
    ("models/rock.obj", obj_rock),
    ("models/crystal.obj", obj_crystal),
    ("models/lamp.obj", obj_lamp),
    ("voxels/van.vox", vox_van),
    ("voxels/house.vox", vox_house),
    ("voxels/barn.vox", vox_barn),
    ("voxels/fence.vox", vox_fence),
    ("voxels/van_interior.vox", vox_van_interior),
    ("voxels/market_stall.vox", vox_market_stall),
    ("voxels/bookshelf.vox", vox_bookshelf),
    ("voxels/well.vox", vox_well),
    ("voxels/lantern_post.vox", vox_lantern_post),
    ("sounds/step.wav", snd_step),
    ("sounds/door.wav", snd_door),
    ("sounds/interact.wav", snd_interact),
    ("sounds/pickup.wav", snd_pickup),
    ("sounds/quest_done.wav", snd_quest_done),
    ("sounds/travel.wav", snd_travel),
    ("sounds/voice_blip.wav", snd_voice_blip),
    ("sounds/ui_move.wav", snd_ui_move),
    ("sounds/ui_select.wav", snd_ui_select),
    ("sounds/ambient_night.wav", snd_ambient_night),
    ("sounds/ambient_fen.wav", snd_ambient_fen),
    ("sounds/ambient_market.wav", snd_ambient_market),
    ("sounds/ambient_library.wav", snd_ambient_library),
    ("sounds/van_hum.wav", snd_van_hum),
    ("sounds/music_title.wav", snd_music_title),
]

# expected TGA dimensions (checked in --check mode)
TGA_SIZES = {
    "font.tga": (128, 48), "sky_stars.tga": (128, 64), "tree_pine.tga": (64, 128), "tree_oak.tga": (64, 96),
    "bush.tga": (32, 32), "flowers.tga": (32, 32), "star.tga": (8, 8), "firefly.tga": (8, 8),
    "npc_farmer.tga": (32, 64), "npc_fen_keeper.tga": (32, 64), "npc_child.tga": (32, 48),
    "npc_merchant.tga": (32, 64), "npc_robot.tga": (32, 64), "npc_librarian.tga": (32, 64),
    "lantern_off.tga": (16, 32), "lantern_on.tga": (16, 32), "gear.tga": (16, 16), "book.tga": (16, 16),
}
# sprites that stand on the ground: their bottom row must not be empty
GROUNDED = {"tree_pine.tga", "tree_oak.tga", "bush.tga", "flowers.tga", "npc_farmer.tga", "npc_fen_keeper.tga",
            "npc_child.tga", "npc_merchant.tga", "npc_robot.tga", "npc_librarian.tga", "lantern_off.tga",
            "lantern_on.tga", "gear.tga", "book.tga"}
# opaque, seamlessly tiling textures
TILEABLE = {"grass.tga", "dirt.tga", "cobble.tga", "wood_planks.tga", "house_wall.tga", "roof.tga", "stone.tga",
            "water.tga", "sand.tga", "metal_panel.tga", "crystal.tga", "carpet.tga", "sky_stars.tga"}
LOOPS = {"ambient_night.wav", "ambient_fen.wav", "ambient_market.wav", "ambient_library.wav", "van_hum.wav",
         "music_title.wav"}


# =============================================================================
# Self-check
# =============================================================================

def check_tga(path, errs):
    name = os.path.basename(path)
    data = open(path, "rb").read()
    (idl, cmt, it, _cf, cml, _cms, _xo, _yo, w, h, bpp, desc) = struct.unpack("<BBBHHBHHHHBB", data[:18])
    if (idl, cmt, it, cml, bpp, desc) != (0, 0, 2, 0, 32, 0x28):
        errs.append("%s: bad header %r" % (name, (idl, cmt, it, cml, bpp, desc)))
    if len(data) != 18 + w * h * 4:
        errs.append("%s: size %d != %d" % (name, len(data), 18 + w * h * 4))
        return "%dx%d" % (w, h)
    exp = TGA_SIZES.get(name, (64, 64))
    if (w, h) != exp:
        errs.append("%s: %dx%d, expected %dx%d" % (name, w, h, exp[0], exp[1]))
    alpha = lambda x, y: data[18 + (y * w + x) * 4 + 3]
    if name in GROUNDED and not any(alpha(x, h - 1) for x in range(w)):
        errs.append("%s: empty bottom row" % name)
    if name in TILEABLE and any(alpha(x, y) != 255 for y in range(h) for x in range(w)):
        errs.append("%s: tileable texture is not fully opaque" % name)
    return "%dx%d" % (w, h)


def check_vox(path, errs):
    name = os.path.basename(path)
    d = open(path, "rb").read()
    if d[:4] != b"VOX " or struct.unpack("<i", d[4:8])[0] != 150:
        errs.append("%s: bad magic/version" % name)
        return ""
    cid, cs, chs = d[8:12], *struct.unpack("<ii", d[12:20])
    if cid != b"MAIN" or cs != 0 or 20 + chs != len(d):
        errs.append("%s: bad MAIN chunk" % name)
        return ""
    pos, found, info = 20, {}, ""
    while pos < len(d):
        cid = d[pos:pos + 4]
        cs, chs = struct.unpack("<ii", d[pos + 4:pos + 12])
        found[cid] = d[pos + 12:pos + 12 + cs]
        pos += 12 + cs + chs
    if pos != len(d) or set(found) != {b"SIZE", b"XYZI", b"RGBA"}:
        errs.append("%s: unexpected chunk layout %r" % (name, list(found)))
        return ""
    sx, sy, sz = struct.unpack("<iii", found[b"SIZE"])
    if max(sx, sy, sz) > 64:
        errs.append("%s: model larger than 64" % name)
    xyzi = found[b"XYZI"]
    cnt = struct.unpack("<i", xyzi[:4])[0]
    if len(xyzi) != 4 + 4 * cnt:
        errs.append("%s: XYZI size mismatch" % name)
    for k in range(cnt):
        x, y, z, c = xyzi[4 + 4 * k:8 + 4 * k]
        if not (x < sx and y < sy and z < sz and 1 <= c <= 255):
            errs.append("%s: voxel out of range %r" % (name, (x, y, z, c)))
            break
    if len(found[b"RGBA"]) != 1024:
        errs.append("%s: RGBA chunk size" % name)
    return "%dx%dx%d, %d voxels" % (sx, sy, sz, cnt)


def check_wav(path, errs):
    name = os.path.basename(path)
    with wave.open(path, "rb") as w:
        ch, sw, fr, nf = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(nf)
    if (ch, sw, fr) != (1, 2, SR):
        errs.append("%s: format %r" % (name, (ch, sw, fr)))
        return ""
    s = struct.unpack("<%dh" % nf, raw)
    peak = max(abs(v) for v in s) / 32768.0
    db = 20 * math.log10(peak) if peak > 0 else -99
    if not -4.0 <= db <= -2.0:
        errs.append("%s: peak %.1f dBFS" % (name, db))
    if name in LOOPS:
        if abs(s[0]) > 600 or abs(s[-1]) > 600 or abs(s[0] - s[-1]) > 900:
            errs.append("%s: loop seam %d -> %d" % (name, s[-1], s[0]))
    elif abs(s[0]) > 200 or abs(s[-1]) > 200:
        errs.append("%s: no fade (%d, %d)" % (name, s[0], s[-1]))
    return "%.2fs, peak %.1f dBFS" % (nf / fr, db)


def check_obj(path, errs):
    name = os.path.basename(path)
    nv = nt = nn = nf = 0
    faces = []
    for line in open(path):
        p = line.split()
        if not p or p[0].startswith("#"):
            continue
        if p[0] == "v":
            nv += 1
        elif p[0] == "vt":
            nt += 1
        elif p[0] == "vn":
            nn += 1
        elif p[0] == "f":
            nf += 1
            faces.append(p[1:])
        elif p[0] in ("mtllib", "usemtl"):
            errs.append("%s: has %s" % (name, p[0]))
    for f in faces:
        if len(f) != 3:
            errs.append("%s: non-triangle face" % name)
            break
        for c in f:
            ix = c.split("/")
            if len(ix) != 3 or not all(ix):
                errs.append("%s: face index '%s' not a/b/c" % (name, c))
                return ""
            a, b, cc = (int(i) for i in ix)
            if not (1 <= a <= nv and 1 <= b <= nt and 1 <= cc <= nn):
                errs.append("%s: index out of range '%s'" % (name, c))
                return ""
    return "%d verts, %d tris" % (nv, nf)


def run_check(out):
    errs = []
    total = 0
    for rel, _fn in ASSETS:
        path = os.path.join(out, rel)
        if not os.path.exists(path):
            errs.append("missing: " + rel)
            continue
        size = os.path.getsize(path)
        total += size
        ext = rel.rsplit(".", 1)[1]
        info = {"tga": check_tga, "vox": check_vox, "wav": check_wav, "obj": check_obj}[ext](path, errs)
        print("  %-30s %8d bytes  %s" % (rel, size, info))
    print("total: %d files, %d bytes (%.2f MB)" % (len(ASSETS), total, total / 1048576))
    if errs:
        print("CHECK FAILED:")
        for e in errs:
            print("  - " + e)
        return 1
    print("CHECK OK")
    return 0


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser(description="Generate Multiversal Van Life assets (%s, %s)." % (LICENSE, ATTRIBUTION))
    ap.add_argument("--out", default=os.path.join(os.path.dirname(here), "game"), help="output folder (default: <repo>/game)")
    ap.add_argument("--check", action="store_true", help="validate already-generated files instead of generating")
    ap.add_argument("--only", default="", help="comma-separated substrings: generate only matching assets")
    args = ap.parse_args()
    if args.check:
        raise SystemExit(run_check(args.out))
    only = [s for s in args.only.split(",") if s]
    for rel, fn in ASSETS:
        if only and not any(s in rel for s in only):
            continue
        path = os.path.join(args.out, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        fn(path)
        print("wrote %s (%d bytes)" % (rel, os.path.getsize(path)))


if __name__ == "__main__":
    main()
