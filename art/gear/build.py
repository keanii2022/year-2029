import os, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "_kit"))
from ykit import *  # noqa

# Ammo color code, shared by each ammo box and the guns that use it.
LIGHT = "#2bb3a8"  # starter_pistol, smg
SHELL = "#f07f2a"  # shotgun
HEAVY = "#f2c230"  # rifle
CELL = "#9b6bff"  # heavy_blaster
NAIL = "#9ccc3c"  # nail_gun
FLARE = "#e8433a"  # flare_gun
DART = "#ff7eb6"  # dart_blaster

WHITE = "#ecebe6"
GREY = "#9aa0a4"
DARK = "#2b2d31"
ORANGE = "#f07f2a"
TEAL = "#2bb3a8"


def shell(color=WHITE, grime=0.45):
    return plain(color, grime=grime)


def rubber():
    return plain(DARK, grime=0.25, vary=0.15)


def hazard(w, h, loc, normal, n=4):
    """Yellow and black stripes on a flat face. Built facing -y, then turned to face normal."""
    base = slab([(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)], 0.01, flat("#f2c230"))
    out = [base]
    s = w / (2 * n)
    k = h * 0.7
    clamp = lambda x: max(-w / 2, min(w / 2, x))
    for i in range(n):
        x0 = -w / 2 + 2 * i * s
        poly = [(clamp(x0), -h / 2), (clamp(x0 + s), -h / 2), (clamp(x0 + s + k), h / 2), (clamp(x0 + k), h / 2)]
        if poly[0][0] < poly[1][0]:
            out.append(slab(poly, 0.016, flat("#1e1e22")))
    return aim(out, loc, normal)


def lit(color):
    """Glow parts are one flat color: Roblox swaps them between Neon and dull."""
    return glow(color, amount=0.0)


def glowstrip(length, loc, color, axis="y", t=0.025):
    size = (0.012, length, t) if axis == "y" else (length, 0.012, t)
    return box(size, lit(color), loc=loc, r=0.004, n=1)


def tie(w, h, y, z, t=0.018):
    """Cable tie around a box section centered on (0, y, z)."""
    m = plain("#1c1c1e", grime=0.1)
    return [box((w + t * 2, 0.03, t), m, loc=(0, y, z + h / 2 + t / 2), r=0.004, n=1),
            box((w + t * 2, 0.03, t), m, loc=(0, y, z - h / 2 - t / 2), r=0.004, n=1),
            box((t, 0.03, h), m, loc=(w / 2 + t / 2, y, z), r=0.004, n=1),
            box((t, 0.03, h), m, loc=(-w / 2 - t / 2, y, z), r=0.004, n=1),
            box((0.03, 0.04, 0.035), m, loc=(w / 2 + t, y, z + h / 2 - 0.02), r=0.006, n=1)]


def band(size, loc, rot=(0, 0, 0)):
    """Strip of worn tape wrapped around a part."""
    return box(size, plain("#cdb98a", grime=0.55), loc=loc, rot=rot, r=0.01, n=1)


def screws(points, r=0.018):
    return [bolt(r, loc=p, normal=(1 if p[0] > 0 else -1, 0, 0)) for p in points]


def grip(y, z, h, w=0.17, d=0.23, lean=14):
    return box((w, d, h), rubber(), loc=(0, y, z), rot=(lean, 0, 0), r=0.04, n=1)


def trigger(y, z, accent=ORANGE):
    g = plain(GREY, grime=0.3)
    return [box((0.05, 0.26, 0.035), g, loc=(0, y - 0.03, z - 0.1), r=0.012, n=1),
            box((0.05, 0.035, 0.13), g, loc=(0, y - 0.15, z - 0.04), r=0.012, n=1),
            box((0.035, 0.035, 0.09), plain(accent, grime=0.2), loc=(0, y, z - 0.03), rot=(-15, 0, 0), r=0.01, n=1)]


def hexbarrel(r, length, y, z, x=0.0):
    """Short hex prism barrel tip, flat ended, along y."""
    return [cyl(r, length, plain("#3a3c40", grime=0.2), loc=(x, y, z), rot=(90, 0, 0), seg=6, bevel=0.008),
            cyl(r * 0.55, 0.01, flat("#0c0c0e"), loc=(x, y - length / 2 - 0.002, z), rot=(90, 0, 0), seg=6, bevel=0.0)]


@item("starter_pistol", "gear")
def starter_pistol(P):
    worn = paint(WHITE, chip=0.25, under="#8d8f92", under2="#5d6064", grime=0.6, streaks=0.3)
    g = plain(GREY, grime=0.5)
    P.add("Handle", box((0.22, 0.86, 0.22), worn, loc=(0, -0.04, 0.62), r=0.05, n=1))
    P.add("Handle", box((0.2, 0.72, 0.12), g, loc=(0, -0.02, 0.46), r=0.03, n=1))
    P.add("Handle", box((0.25, 0.1, 0.2), g, loc=(0, -0.5, 0.6), r=0.025, n=1))
    P.add("Handle", hexbarrel(0.055, 0.07, -0.58, 0.61))
    P.add("Handle", grip(0.22, 0.22, 0.46))
    P.add("Mag", box((0.12, 0.17, 0.44), plain(LIGHT, grime=0.3), loc=(0, 0.225, 0.24), rot=(14, 0, 0), r=0.02, n=1))
    P.add("Mag", box((0.2, 0.27, 0.05), plain(ORANGE, grime=0.4), loc=(0, 0.28, 0.0), rot=(14, 0, 0), r=0.015, n=1))
    P.add("Handle", band((0.185, 0.245, 0.07), loc=(0, 0.21, 0.27), rot=(14, 0, 0)))
    P.add("Handle", trigger(-0.06, 0.4))
    P.add("Handle", box((0.17, 0.06, 0.06), plain(DARK), loc=(0, 0.33, 0.75), r=0.015, n=1))
    P.add("Handle", box((0.05, 0.05, 0.05), plain(ORANGE), loc=(0, -0.42, 0.75), r=0.012, n=1))
    for sx in (1, -1):
        P.add("Glow", glowstrip(0.34, (sx * 0.111, -0.18, 0.66), LIGHT))
    P.add("Handle", hazard(0.2, 0.08, (0.112, 0.2, 0.6), (1, 0, 0), n=3))
    P.add("Handle", screws([(0.111, 0.08, 0.56), (0.111, -0.36, 0.56), (-0.111, 0.08, 0.56)]))
    P.add("Handle", box((0.006, 0.12, 0.05), flat("#6c6e70"), loc=(0.112, -0.32, 0.67), rot=(18, 0, 0), r=0.0, n=1))


@item("smg", "gear")
def smg(P):
    w, g, d = shell(), plain(GREY, grime=0.4), rubber()
    P.add("Handle", box((0.26, 0.9, 0.3), w, loc=(0, 0.0, 0.62), r=0.06, n=1))
    P.add("Handle", box((0.14, 0.78, 0.06), d, loc=(0, -0.05, 0.8), r=0.015, n=1))
    P.add("Handle", box((0.22, 0.42, 0.22), g, loc=(0, -0.64, 0.64), r=0.04, n=1))
    for y in (-0.56, -0.66, -0.76):
        for sx in (1, -1):
            P.add("Handle", box((0.01, 0.05, 0.12), flat("#16161a"), loc=(sx * 0.111, y, 0.64), r=0.0, n=1))
    P.add("Handle", box((0.27, 0.09, 0.27), d, loc=(0, -0.88, 0.64), r=0.03, n=1))
    P.add("Handle", hexbarrel(0.05, 0.06, -0.95, 0.64))
    P.add("Mag", box((0.14, 0.2, 0.5), plain(LIGHT, grime=0.35), loc=(0, -0.28, 0.27), rot=(-8, 0, 0), r=0.03, n=1))
    P.add("Mag", box((0.16, 0.22, 0.04), plain(ORANGE, grime=0.3), loc=(0, -0.25, 0.03), rot=(-8, 0, 0), r=0.012, n=1))
    P.add("Handle", grip(0.22, 0.3, 0.42))
    P.add("Handle", trigger(0.0, 0.47))
    P.add("Handle", box((0.06, 0.42, 0.06), g, loc=(0, 0.62, 0.72), r=0.02, n=1))
    P.add("Handle", box((0.06, 0.44, 0.06), g, loc=(0, 0.62, 0.5), rot=(-6, 0, 0), r=0.02, n=1))
    P.add("Handle", box((0.2, 0.08, 0.36), d, loc=(0, 0.86, 0.6), r=0.03, n=1))
    P.add("Handle", box((0.22, 0.04, 0.38), plain(ORANGE, grime=0.3), loc=(0, 0.91, 0.6), r=0.015, n=1))
    for sx in (1, -1):
        P.add("Glow", glowstrip(0.4, (sx * 0.131, -0.05, 0.7), LIGHT))
    P.add("Handle", hazard(0.26, 0.09, (0.132, 0.2, 0.56), (1, 0, 0), n=4))
    P.add("Handle", tie(0.22, 0.22, -0.48, 0.64))
    P.add("Handle", screws([(0.131, -0.32, 0.54), (0.131, 0.36, 0.7), (-0.131, -0.32, 0.54), (-0.131, 0.36, 0.7)]))


@item("shotgun", "gear")
def shotgun(P):
    w, g, d = shell(), plain(GREY, grime=0.4), rubber()
    P.add("Handle", box((0.3, 0.8, 0.36), w, loc=(0, 0.1, 0.64), r=0.07, n=1))
    P.add("Handle", box((0.38, 0.9, 0.22), g, loc=(0, -0.72, 0.72), r=0.05, n=1))
    P.add("Handle", box((0.42, 0.1, 0.27), d, loc=(0, -1.2, 0.72), r=0.03, n=1))
    for x in (-0.095, 0.095):
        P.add("Handle", hexbarrel(0.065, 0.06, -1.27, 0.72, x))
    P.add("Handle", box((0.32, 0.42, 0.16), d, loc=(0, -0.72, 0.53), r=0.04, n=1))
    for y in (-0.86, -0.76, -0.66, -0.56):
        P.add("Handle", box((0.33, 0.03, 0.12), plain(SHELL, grime=0.3), loc=(0, y, 0.52), r=0.01, n=1))
    P.add("Handle", grip(0.48, 0.3, 0.44, w=0.19, d=0.25))
    P.add("Mag", box((0.2, 0.22, 0.26), plain(SHELL, grime=0.35), loc=(0, -0.1, 0.36), r=0.03, n=1))
    P.add("Mag", box((0.22, 0.24, 0.04), plain(DARK), loc=(0, -0.1, 0.23), r=0.012, n=1))
    P.add("Handle", trigger(0.24, 0.49))
    P.add("Handle", box((0.24, 0.66, 0.3), w, loc=(0, 0.88, 0.56), rot=(-6, 0, 0), r=0.07, n=1))
    P.add("Handle", box((0.26, 0.06, 0.36), plain(ORANGE, grime=0.4), loc=(0, 1.22, 0.53), r=0.02, n=1))
    for y in (-0.12, 0.0, 0.12, 0.24):
        P.add("Handle", cyl(0.04, 0.05, plain(SHELL, grime=0.3), loc=(0.17, y, 0.6), rot=(0, 90, 0), seg=6, bevel=0.008))
        P.add("Handle", cyl(0.042, 0.015, metal("#c9a24a", rust=0.1), loc=(0.197, y, 0.6), rot=(0, 90, 0), seg=6, bevel=0.004))
    for sx in (1, -1):
        P.add("Glow", glowstrip(0.5, (sx * 0.191, -0.72, 0.78), SHELL))
    P.add("Handle", hazard(0.42, 0.08, (0.192, -0.72, 0.68), (1, 0, 0), n=5))
    P.add("Handle", hazard(0.42, 0.08, (-0.192, -0.72, 0.68), (-1, 0, 0), n=5))
    P.add("Handle", band((0.39, 0.09, 0.23), loc=(0, -0.38, 0.72)))
    P.add("Handle", screws([(0.151, 0.4, 0.76), (-0.151, 0.4, 0.76), (0.151, -0.2, 0.76), (-0.151, -0.2, 0.76)]))


@item("rifle", "gear")
def rifle(P):
    w, g, d = shell(), plain(GREY, grime=0.4), rubber()
    P.add("Handle", box((0.22, 1.0, 0.3), w, loc=(0, 0.1, 0.62), r=0.06, n=1))
    P.add("Handle", box((0.18, 1.0, 0.18), g, loc=(0, -0.9, 0.66), r=0.04, n=1))
    for y in (-0.6, -0.75, -0.9, -1.05, -1.2):
        P.add("Handle", box((0.1, 0.07, 0.01), flat("#16161a"), loc=(0, y, 0.751), r=0.0, n=1))
    P.add("Handle", hexbarrel(0.045, 0.22, -1.5, 0.66)[0])
    P.add("Handle", box((0.15, 0.1, 0.15), d, loc=(0, -1.65, 0.66), r=0.02, n=1))
    for sx in (1, -1):
        P.add("Handle", box((0.01, 0.06, 0.08), flat("#0c0c0e"), loc=(sx * 0.076, -1.65, 0.66), r=0.0, n=1))
    P.add("Handle", box((0.1, 0.012, 0.05), flat("#0c0c0e"), loc=(0, -1.701, 0.66), r=0.0, n=1))
    P.add("Handle", box((0.12, 0.46, 0.14), d, loc=(0, 0.02, 0.94), r=0.03, n=1))
    P.add("Glow", box((0.1, 0.012, 0.1), lit(HEAVY), loc=(0, -0.211, 0.94), r=0.01, n=1))
    for y in (-0.1, 0.14):
        P.add("Handle", box((0.06, 0.05, 0.08), g, loc=(0, y, 0.82), r=0.01, n=1))
    P.add("Mag", box((0.13, 0.22, 0.46), plain(HEAVY, grime=0.35), loc=(0, -0.24, 0.28), rot=(-12, 0, 0), r=0.03, n=1))
    P.add("Handle", grip(0.3, 0.3, 0.42))
    P.add("Handle", trigger(0.06, 0.47))
    P.add("Handle", box((0.18, 0.8, 0.14), w, loc=(0, 0.98, 0.68), r=0.04, n=1))
    P.add("Handle", box((0.16, 0.62, 0.1), g, loc=(0, 0.94, 0.5), rot=(-14, 0, 0), r=0.03, n=1))
    P.add("Handle", box((0.2, 0.06, 0.38), plain(ORANGE, grime=0.4), loc=(0, 1.39, 0.59), r=0.02, n=1))
    for sx in (1, -1):
        P.add("Glow", glowstrip(0.6, (sx * 0.091, -0.9, 0.66), HEAVY))
    P.add("Handle", hazard(0.3, 0.09, (0.112, 0.35, 0.56), (1, 0, 0), n=4))
    P.add("Handle", tie(0.18, 0.18, -0.45, 0.66))
    P.add("Handle", band((0.19, 0.1, 0.19), loc=(0, -1.25, 0.66)))
    P.add("Handle", screws([(0.111, -0.25, 0.7), (0.111, 0.45, 0.7), (-0.111, -0.25, 0.7), (-0.111, 0.45, 0.7)]))


@item("heavy_blaster", "gear")
def heavy_blaster(P):
    w, g, d = shell(), plain(GREY, grime=0.4), rubber()
    vio = lit(CELL)
    P.add("Handle", box((0.46, 1.2, 0.5), w, loc=(0, 0.0, 0.78), r=0.1, n=1))
    rect = lambda y, hw, hh, zc: [(x * hw, y, zc + z * hh) for x, z in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    P.add("Handle", loft([rect(-0.55, 0.2, 0.2, 0.8), rect(-1.0, 0.22, 0.22, 0.8), rect(-1.35, 0.27, 0.27, 0.8)], g, smooth=30))
    P.add("Handle", box((0.6, 0.14, 0.6), d, loc=(0, -1.42, 0.8), r=0.05, n=1))
    P.add("Glow", box((0.28, 0.012, 0.28), vio, loc=(0, -1.495, 0.8), r=0.02, n=1))
    for z in (0.66, 0.8, 0.94):
        for sx in (1, -1):
            P.add("Glow", box((0.012, 0.32, 0.04), vio, loc=(sx * 0.22, -1.0, z), rot=(0, 0, sx * 2.5), r=0.006, n=1))
    P.add("Glow", cyl(0.13, 0.62, vio, loc=(0, 0.0, 1.13), rot=(90, 0, 0), seg=6, bevel=0.02))
    for sx in (1, -1):
        P.add("Handle", box((0.06, 0.7, 0.1), g, loc=(sx * 0.15, 0.0, 1.05), r=0.025, n=1))
    for y in (-0.36, 0.36):
        P.add("Handle", box((0.34, 0.1, 0.22), d, loc=(0, y, 1.06), r=0.03, n=1))
    P.add("Handle", tube([(0.17, 0.4, 1.14), (0.27, 0.5, 1.0), (0.24, 0.55, 0.84)], 0.025, d, seg=6))
    P.add("Handle", grip(0.38, 0.3, 0.46, w=0.2, d=0.26))
    P.add("Handle", trigger(0.14, 0.53))
    P.add("Mag", box((0.24, 0.3, 0.22), plain(DARK), loc=(0, -0.22, 0.44), r=0.04, n=1))
    P.add("Mag", box((0.25, 0.2, 0.06), plain(CELL, grime=0.2), loc=(0, -0.22, 0.44), r=0.015, n=1))
    P.add("Handle", box((0.13, 0.15, 0.3), d, loc=(0, -0.78, 0.45), rot=(8, 0, 0), r=0.035, n=1))
    P.add("Handle", box((0.36, 0.6, 0.42), g, loc=(0, 0.88, 0.72), r=0.08, n=1))
    P.add("Handle", box((0.4, 0.07, 0.46), plain(ORANGE, grime=0.4), loc=(0, 1.2, 0.72), r=0.025, n=1))
    for sx in (1, -1):
        P.add("Glow", glowstrip(0.7, (sx * 0.232, 0.05, 0.62), CELL))
        P.add("Handle", hazard(0.5, 0.11, (sx * 0.232, 0.15, 0.9), (sx, 0, 0), n=5))
    P.add("Handle", box((0.46, 0.06, 0.06), plain(TEAL, grime=0.3), loc=(0, -0.6, 1.04), r=0.015, n=1))
    P.add("Handle", band((0.47, 0.1, 0.12), loc=(0, 0.45, 0.6)))
    P.add("Handle", screws([(0.231, -0.4, 0.62), (0.231, 0.5, 0.62), (-0.231, -0.4, 0.62), (-0.231, 0.5, 0.62)], r=0.024))


def ammo_box(P, color, label, w=0.5, d=0.32, h=0.28):
    P.add("Body", box((w, d, h), plain(GREY, grime=0.4), loc=(0, 0, h / 2), r=0.03, n=1))
    P.add("Body", box((w + 0.01, d + 0.01, 0.07), plain(color, grime=0.3), loc=(0, 0, h - 0.02), r=0.02, n=1))
    P.add("Body", box((w * 0.6, 0.01, h * 0.38), plain("#f4ecd8", grime=0.15), loc=(0, -d / 2 - 0.006, h * 0.42), r=0.004, n=1))
    P.add("Body", words(label, h * 0.22, flat("#1e1e22"), loc=(0, -d / 2 - 0.012, h * 0.42)))
    P.add("Body", box((0.06, 0.03, 0.08), plain(ORANGE, grime=0.3), loc=(0, -d / 2 - 0.012, h - 0.05), r=0.01, n=1))


@item("ammo_light", "gear")
def ammo_light(P):
    ammo_box(P, LIGHT, "LT")
    P.add("Body", hazard(0.4, 0.05, (0, -0.165, 0.035), (0, -1, 0), n=5))


@item("ammo_shells", "gear")
def ammo_shells(P):
    c = plain(SHELL, grime=0.35)
    P.add("Body", box((0.5, 0.34, 0.24), c, loc=(0, 0, 0.12), r=0.03, n=1))
    P.add("Body", box((0.46, 0.3, 0.01), flat("#3a2416"), loc=(0, 0, 0.241), r=0.0, n=1))
    for x in (-0.15, -0.05, 0.05, 0.15):
        for y in (-0.07, 0.07):
            P.add("Body", cyl(0.04, 0.03, plain("#c0392b", grime=0.2), loc=(x, y, 0.25), seg=6, bevel=0.006))
            P.add("Body", cyl(0.046, 0.025, metal("#c9a24a", rust=0.1), loc=(x, y, 0.275), seg=6, bevel=0.005))
    P.add("Body", box((0.3, 0.01, 0.1), plain("#f4ecd8", grime=0.15), loc=(0, -0.172, 0.12), r=0.005, n=1))
    P.add("Body", words("SH", 0.06, flat("#1e1e22"), loc=(0, -0.18, 0.12)))


@item("ammo_heavy", "gear")
def ammo_heavy(P):
    can = metal("#7a7d5a", rust=0.3)
    P.add("Body", box((0.6, 0.3, 0.34), can, loc=(0, 0, 0.17), r=0.03, n=1))
    P.add("Body", box((0.62, 0.32, 0.06), metal("#6a6d4c", rust=0.3), loc=(0, 0, 0.33), r=0.02, n=1))
    k = plain(DARK, grime=0.3)
    P.add("Body", box((0.26, 0.04, 0.03), k, loc=(0, 0, 0.44), r=0.01, n=1))
    for x in (-0.115, 0.115):
        P.add("Body", box((0.03, 0.04, 0.09), k, loc=(x, 0, 0.395), r=0.01, n=1))
    P.add("Body", box((0.61, 0.31, 0.06), plain(HEAVY, grime=0.3), loc=(0, 0, 0.12), r=0.015, n=1))
    P.add("Body", words("HV", 0.08, flat("#1e1e22"), loc=(0, -0.158, 0.23)))
    P.add("Body", box((0.04, 0.03, 0.1), metal("#9a9a92", rust=0.2), loc=(0.27, -0.16, 0.28), r=0.01, n=1))


@item("ammo_cell", "gear")
def ammo_cell(P):
    g = plain(GREY, grime=0.4)
    P.add("Glow", cyl(0.11, 0.42, lit(CELL), loc=(0, 0, 0.11), rot=(0, 90, 0), seg=6, bevel=0.01))
    for x in (-0.24, 0.24):
        P.add("Body", box((0.08, 0.26, 0.26), plain(WHITE, grime=0.35), loc=(x, 0, 0.13), r=0.03, n=1))
    for sx in (1, -1):
        P.add("Body", box((0.44, 0.04, 0.05), g, loc=(0, sx * 0.1, 0.02), r=0.01, n=1))
        P.add("Body", box((0.44, 0.04, 0.05), g, loc=(0, sx * 0.1, 0.22), r=0.01, n=1))
    P.add("Body", box((0.04, 0.1, 0.03), plain(ORANGE, grime=0.3), loc=(0.29, 0, 0.13), r=0.008, n=1))
    P.add("Body", box((0.3, 0.05, 0.03), plain(DARK), loc=(0, 0, 0.29), r=0.01, n=1))
    for x in (-0.13, 0.13):
        P.add("Body", box((0.03, 0.05, 0.07), plain(DARK), loc=(x, 0, 0.25), r=0.01, n=1))


@item("handcuffs", "gear", pivots={"Arm": (0.17, 0, 0.33)})
def handcuffs(P):
    w, g = plain(WHITE, grime=0.35), plain(GREY, grime=0.35)
    z = 0.21
    for sx in (1, -1):
        ring = "Arm" if sx > 0 else "Body"
        P.add(ring, torus(0.17, 0.035, w, loc=(sx * 0.28, 0, z), rot=(90, 0, 0), seg=8, sub=4, scl=(1, 1, 2.4)))
        P.add("Body", box((0.14, 0.2, 0.2), g, loc=(sx * 0.12, 0, z), r=0.03, n=1))
        P.add("Glow", box((0.045, 0.012, 0.045), lit("#ff4a3a"), loc=(sx * 0.12, -0.104, z + 0.04), r=0.006, n=1))
        P.add("Body", box((0.09, 0.012, 0.02), plain(TEAL, grime=0.1), loc=(sx * 0.12, -0.104, z - 0.04), r=0.004, n=1))
        P.add(ring, box((0.05, 0.21, 0.05), plain(ORANGE, grime=0.3), loc=(sx * 0.28, 0, z + 0.2), r=0.01, n=1))
    P.add("Body", box((0.12, 0.12, 0.12), plain(DARK), loc=(0, 0, z), r=0.02, n=1))
    P.add("Body", hazard(0.1, 0.05, (0, -0.061, z), (0, -1, 0), n=2))


@item("flashlight", "gear")
def flashlight(P):
    d, w = rubber(), plain(WHITE, grime=0.4)
    P.add("Body", box((0.16, 0.5, 0.16), d, loc=(0, 0.05, 0.11), r=0.04, n=1))
    sq = lambda y, h: [(x * h, y, 0.11 + z * h) for x, z in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    P.add("Body", loft([sq(-0.2, 0.085), sq(-0.3, 0.11), sq(-0.38, 0.11)], w, smooth=30))
    P.add("Body", box((0.24, 0.05, 0.24), plain(ORANGE, grime=0.3), loc=(0, -0.4, 0.11), r=0.03, n=1))
    P.add("Glow", box((0.17, 0.012, 0.17), lit("#fff4c8"), loc=(0, -0.426, 0.11), r=0.02, n=1))
    P.add("Body", box((0.18, 0.08, 0.18), w, loc=(0, 0.33, 0.11), r=0.035, n=1))
    P.add("Body", box((0.012, 0.3, 0.04), metal("#9a9a92", rust=0.1), loc=(0.088, 0.12, 0.13), r=0.005, n=1))
    P.add("Body", box((0.06, 0.07, 0.03), plain(ORANGE, grime=0.3), loc=(0, -0.08, 0.195), r=0.01, n=1))
    P.add("Body", box((0.012, 0.18, 0.025), plain(TEAL, grime=0.1), loc=(-0.081, 0.08, 0.11), r=0.004, n=1))
    P.add("Body", hazard(0.1, 0.14, (0, 0.33, 0.201), (0, 0, 1), n=2))
    for obs in P.parts.values():
        move(obs, rot=(0, 0, -90))


@item("battery", "gear")
def battery(P):
    P.add("Body", box((0.3, 0.2, 0.42), plain(GREY, grime=0.35), loc=(0, 0, 0.21), r=0.035, n=1))
    P.add("Body", box((0.31, 0.21, 0.08), plain(DARK), loc=(0, 0, 0.04), r=0.02, n=1))
    P.add("Body", box((0.07, 0.07, 0.05), plain(ORANGE, grime=0.3), loc=(-0.08, 0, 0.44), r=0.01, n=1))
    P.add("Body", box((0.07, 0.07, 0.05), plain(TEAL, grime=0.3), loc=(0.08, 0, 0.44), r=0.01, n=1))
    P.add("Body", box((0.16, 0.01, 0.2), flat("#1a1a1e"), loc=(0, -0.102, 0.26), r=0.005, n=1))
    for i, z in enumerate((0.19, 0.24, 0.29, 0.34)):
        lit_bar = i < 3
        P.add("Glow" if lit_bar else "Body", box((0.12, 0.012, 0.03), lit("#5ee07a") if lit_bar else flat("#2e3a30"), loc=(0, -0.106, z), r=0.004, n=1))
    P.add("Body", hazard(0.28, 0.04, (0, -0.106, 0.11), (0, -1, 0), n=4))


@item("bandage", "gear")
def bandage(P):
    c = cloth("#f2ede2", dirt=0.25, weave=90)
    P.add("Body", cyl(0.16, 0.16, c, loc=(0, 0, 0.08), seg=16, bevel=0.02))
    P.add("Body", cyl(0.055, 0.01, flat("#8a7a66"), loc=(0, 0, 0.161), seg=12, bevel=0.0))
    P.add("Body", box((0.11, 0.008, 0.16), c, loc=(0.02, -0.162, 0.08), r=0.003, n=1))
    P.add("Body", box((0.11, 0.24, 0.008), c, loc=(0.02, -0.28, 0.004), r=0.003, n=1))
    P.add("Body", box((0.13, 0.03, 0.014), plain(TEAL, grime=0.2), loc=(0.02, -0.36, 0.01), r=0.004, n=1))
    P.add("Body", box((0.16, 0.18, 0.012), plain("#cdb98a", grime=0.4), loc=(0.08, -0.04, 0.164), rot=(0, 0, 30), r=0.004, n=1))


@item("medkit", "gear")
def medkit(P):
    w = plain(WHITE, grime=0.4)
    P.add("Body", box((0.8, 0.28, 0.54), w, loc=(0, 0, 0.27), r=0.06, n=1))
    P.add("Body", box((0.82, 0.3, 0.04), plain(GREY, grime=0.3), loc=(0, 0, 0.36), r=0.015, n=1))
    k = plain(DARK)
    P.add("Body", box((0.3, 0.06, 0.04), k, loc=(0, 0, 0.64), r=0.015, n=1))
    for x in (-0.13, 0.13):
        P.add("Body", box((0.04, 0.06, 0.11), k, loc=(x, 0, 0.58), r=0.012, n=1))
        P.add("Body", box((0.06, 0.03, 0.1), plain(ORANGE, grime=0.3), loc=(x * 2, -0.15, 0.36), r=0.01, n=1))
    gr = plain("#3fbf6a", grime=0.2)
    P.add("Body", box((0.07, 0.024, 0.22), gr, loc=(0, -0.148, 0.2), r=0.01, n=1))
    P.add("Body", box((0.22, 0.02, 0.07), gr, loc=(0, -0.146, 0.2), r=0.01, n=1))
    P.add("Glow", box((0.012, 0.3, 0.025), lit(TEAL), loc=(0.401, 0, 0.45), r=0.004, n=1))
    P.add("Body", box((0.14, 0.012, 0.05), plain("#f4ecd8", grime=0.2), loc=(0.27, -0.143, 0.47), rot=(0, 8, 0), r=0.004, n=1))


@item("loot_crate", "gear", pivots={"Lid": (0, 1.0, 2.1)})
def loot_crate(P):
    g, w, d = plain(GREY, grime=0.25), plain(WHITE, grime=0.2), plain(DARK, grime=0.3)
    P.add("Body", box((3.0, 2.0, 0.15), g, loc=(0, 0, 0.075), r=0.05, n=1))
    P.add("Body", box((3.0, 0.15, 2.0), w, loc=(0, -0.925, 1.1), r=0.05, n=1))
    P.add("Body", box((3.0, 0.15, 2.0), w, loc=(0, 0.925, 1.1), r=0.05, n=1))
    for sx in (1, -1):
        P.add("Body", box((0.15, 1.7, 2.0), w, loc=(sx * 1.425, 0, 1.1), r=0.05, n=1))
        for sy in (1, -1):
            P.add("Body", box((0.24, 0.24, 2.1), plain(ORANGE, grime=0.4), loc=(sx * 1.42, sy * 0.92, 1.05), r=0.06, n=1))
        P.add("Body", box((0.06, 0.6, 0.18), d, loc=(sx * 1.53, 0, 1.6), r=0.03, n=1))
    P.add("Body", box((1.9, 0.04, 0.2), d, loc=(0, -1.01, 0.4), r=0.02, n=1))
    P.add("Body", hazard(2.4, 0.22, (0, -1.012, 0.75), (0, -1, 0), n=8))
    P.add("Body", box((0.8, 0.02, 0.4), plain("#f4ecd8", grime=0.2), loc=(0, -1.005, 1.35), r=0.02, n=1))
    P.add("Body", words("Y29", 0.26, flat("#1e1e22"), loc=(0, -1.02, 1.35)))
    P.add("Glow", box((0.7, 0.03, 0.06), lit(TEAL), loc=(0, -1.01, 1.85), r=0.01, n=1))
    P.add("Lid", box((3.08, 2.08, 0.32), g, loc=(0, 0, 2.26), r=0.07, n=1))
    P.add("Lid", box((2.4, 1.5, 0.06), w, loc=(0, 0, 2.43), r=0.03, n=1))
    P.add("Lid", box((0.5, 0.08, 0.18), plain(ORANGE, grime=0.3), loc=(0, -1.06, 2.14), r=0.02, n=1))
    P.add("Lid", box((0.12, 0.04, 0.06), glow("#ff4a3a", amount=0.4), loc=(0, -1.1, 2.18), r=0.01, n=1))


@item("supply_locker", "gear", pivots={"Door": (-1.0, -0.9, 0)})
def supply_locker(P):
    g, w, d = plain(GREY, grime=0.25), plain(WHITE, grime=0.2), plain(DARK, grime=0.3)
    P.add("Body", box((2.0, 0.1, 6.5), g, loc=(0, 0.85, 3.25), r=0.04, n=1))
    for sx in (1, -1):
        P.add("Body", box((0.1, 1.8, 6.5), w, loc=(sx * 0.95, 0, 3.25), r=0.04, n=1))
    P.add("Body", box((2.0, 1.8, 0.25), d, loc=(0, 0, 0.125), r=0.04, n=1))
    P.add("Body", box((2.0, 1.8, 0.12), w, loc=(0, 0, 6.44), r=0.04, n=1))
    for z in (2.2, 4.2):
        P.add("Body", box((1.8, 1.6, 0.06), g, loc=(0, 0.05, z), r=0.02, n=1))
    P.add("Glow", box((0.5, 0.03, 0.08), lit(TEAL), loc=(0, -0.91, 6.42), r=0.01, n=1))
    door = plain("#d9dcd8", grime=0.2)
    P.add("Door", box((1.9, 0.08, 6.1), door, loc=(0, -0.86, 3.3), r=0.04, n=1))
    for z in (5.4, 5.55, 5.7, 5.85):
        P.add("Door", box((1.0, 0.02, 0.06), flat("#1a1a1e"), loc=(0, -0.902, z), r=0.0, n=1))
    P.add("Door", box((0.08, 0.1, 0.8), d, loc=(0.75, -0.94, 3.3), r=0.03, n=1))
    P.add("Door", box((0.14, 0.03, 0.14), plain(ORANGE, grime=0.3), loc=(0.75, -0.91, 3.85), r=0.02, n=1))
    P.add("Door", box((0.06, 0.02, 0.06), glow("#ff4a3a", amount=0.4), loc=(0.75, -0.928, 3.85), r=0.01, n=1))
    P.add("Door", hazard(1.7, 0.2, (0, -0.902, 0.6), (0, -1, 0), n=7))
    P.add("Door", box((0.8, 0.02, 0.45), plain("#f4ecd8", grime=0.2), loc=(0, -0.902, 4.6), r=0.02, n=1))
    P.add("Door", words("SUP-7", 0.2, flat("#1e1e22"), loc=(0, -0.914, 4.6)))
    P.add("Door", box((0.3, 0.012, 0.3), plain("#cdb98a", grime=0.5), loc=(-0.5, -0.903, 2.0), rot=(0, 20, 0), r=0.01, n=1))

@item("emp_charge", "gear")
def emp_charge(P):
    g = plain(GREY, grime=0.4)
    P.add("Body", cyl(0.3, 0.2, plain(WHITE, grime=0.4), loc=(0, 0, 0.12), seg=6, bevel=0.04))
    P.add("Body", cyl(0.31, 0.05, plain(DARK), loc=(0, 0, 0.03), seg=6, bevel=0.015))
    P.add("Body", cyl(0.2, 0.06, g, loc=(0, 0, 0.24), seg=6, bevel=0.015))
    P.add("Glow", cyl(0.13, 0.03, lit(TEAL), loc=(0, 0, 0.27), seg=6, bevel=0.01))
    for a in (0, 120, 240):
        P.add("Glow", move(box((0.12, 0.012, 0.035), lit(TEAL), loc=(0, -0.262, 0.13), r=0.004, n=1), rot=(0, 0, a)))
    o = plain(ORANGE, grime=0.3)
    P.add("Body", box((0.16, 0.03, 0.11), o, loc=(0, 0.13, 0.32), rot=(-20, 0, 0), r=0.012, n=1))
    P.add("Body", box((0.08, 0.012, 0.03), flat("#1e1e22"), loc=(0, 0.11, 0.34), rot=(-20, 0, 0), r=0.004, n=1))
    P.add("Body", hazard(0.24, 0.05, (0, -0.262, 0.07), (0, -1, 0), n=4))


@item("disruptor", "gear")
def disruptor(P):
    w, g, d = shell(), plain(GREY, grime=0.4), rubber()
    arc = lit("#7ff6ff")
    P.add("Handle", box((0.3, 1.1, 0.34), w, loc=(0, 0.25, 0.7), r=0.07, n=1))
    P.add("Handle", box((0.16, 1.0, 0.16), g, loc=(0, -0.75, 0.72), r=0.03, n=1))
    for i, y in enumerate((-0.48, -0.66, -0.84, -1.02)):
        mat = plain(TEAL, grime=0.3) if i % 2 else plain(WHITE, grime=0.35)
        P.add("Handle", cyl(0.21, 0.05, mat, loc=(0, y, 0.72), rot=(90, 30, 0), seg=6, bevel=0.012))
    P.add("Handle", box((0.42, 0.14, 0.3), d, loc=(0, -1.3, 0.72), r=0.03, n=1))
    for sx in (1, -1):
        P.add("Handle", box((0.06, 0.46, 0.24), g, loc=(sx * 0.16, -1.58, 0.72), rot=(0, 0, -sx * 7), r=0.02, n=1))
        P.add("Handle", box((0.065, 0.1, 0.25), plain(ORANGE, grime=0.3), loc=(sx * 0.19, -1.78, 0.72), rot=(0, 0, -sx * 7), r=0.015, n=1))
        P.add("Glow", box((0.012, 0.3, 0.05), arc, loc=(sx * 0.125, -1.6, 0.72), rot=(0, 0, -sx * 7), r=0.006, n=1))
    zig = [(-0.13, 0.02), (-0.06, 0.06), (-0.02, -0.03), (0.04, 0.05), (0.13, -0.02), (0.13, 0.0), (0.04, 0.08),
           (-0.02, 0.0), (-0.06, 0.09), (-0.13, 0.04)]
    for y, flip in ((-1.5, 1), (-1.66, -1), (-1.8, 1)):
        P.add("Glow", slab([(x * flip, z - 0.03) for x, z in zig], 0.015, arc, loc=(0, y, 0.72)))
    P.add("Mag", box((0.26, 0.42, 0.22), plain(DARK), loc=(0, 0.35, 0.98), r=0.04, n=1))
    P.add("Mag", box((0.27, 0.3, 0.08), plain(TEAL, grime=0.2), loc=(0, 0.35, 0.98), r=0.01, n=1))
    P.add("Mag", box((0.28, 0.06, 0.24), plain(ORANGE, grime=0.3), loc=(0, 0.59, 0.98), r=0.02, n=1))
    P.add("Handle", tube([(0.1, 0.14, 1.0), (0.13, -0.1, 0.92), (0.09, -0.3, 0.8)], 0.025, d, seg=6))
    P.add("Handle", grip(0.55, 0.32, 0.44, w=0.18, d=0.24))
    P.add("Handle", trigger(0.32, 0.53))
    P.add("Handle", box((0.12, 0.14, 0.32), d, loc=(0, -0.56, 0.5), rot=(10, 0, 0), r=0.035, n=1))
    P.add("Handle", box((0.22, 0.5, 0.3), g, loc=(0, 1.05, 0.66), r=0.06, n=1))
    P.add("Handle", box((0.26, 0.06, 0.36), plain(ORANGE, grime=0.4), loc=(0, 1.32, 0.64), r=0.02, n=1))
    for sx in (1, -1):
        P.add("Glow", glowstrip(0.5, (sx * 0.151, 0.15, 0.62), "#7ff6ff"))
    P.add("Handle", hazard(0.34, 0.08, (0.152, 0.45, 0.76), (1, 0, 0), n=4))
    P.add("Handle", screws([(0.151, -0.2, 0.76), (-0.151, -0.2, 0.76), (0.151, 0.65, 0.6), (-0.151, 0.65, 0.6)]))

@item("revolver", "gear")
def revolver(P):
    w, g, d = shell(), plain(GREY, grime=0.45), rubber()
    P.add("Handle", box((0.2, 0.5, 0.26), w, loc=(0, 0.06, 0.62), r=0.05, n=1))
    P.add("Handle", box((0.16, 0.5, 0.16), g, loc=(0, -0.44, 0.68), r=0.035, n=1))
    P.add("Handle", box((0.06, 0.5, 0.04), d, loc=(0, -0.44, 0.78), r=0.012, n=1))
    P.add("Handle", box((0.2, 0.08, 0.2), d, loc=(0, -0.72, 0.68), r=0.025, n=1))
    P.add("Handle", hexbarrel(0.045, 0.05, -0.78, 0.68))
    P.add("Handle", box((0.16, 0.22, 0.42), d, loc=(0, 0.3, 0.36), rot=(22, 0, 0), r=0.05, n=1))
    P.add("Handle", box((0.18, 0.24, 0.05), plain(ORANGE, grime=0.4), loc=(0, 0.38, 0.16), rot=(22, 0, 0), r=0.015, n=1))
    P.add("Handle", box((0.06, 0.08, 0.1), plain(ORANGE, grime=0.3), loc=(0, 0.33, 0.8), rot=(-25, 0, 0), r=0.015, n=1))
    P.add("Handle", trigger(0.06, 0.47))
    P.add("Mag", cyl(0.15, 0.26, plain(LIGHT, grime=0.35), loc=(0, -0.06, 0.64), rot=(90, 30, 0), seg=6, bevel=0.02))
    for k in range(6):
        a = math.radians(60 * k + 30)
        P.add("Mag", cyl(0.03, 0.01, flat("#121214"), loc=(0.085 * math.cos(a), -0.192, 0.64 + 0.085 * math.sin(a)), rot=(90, 0, 0), seg=6, bevel=0.0))
    for sx in (1, -1):
        P.add("Glow", glowstrip(0.3, (sx * 0.081, -0.44, 0.68), LIGHT))
    P.add("Handle", hazard(0.16, 0.07, (0.101, 0.18, 0.6), (1, 0, 0), n=3))
    P.add("Handle", screws([(0.101, 0.0, 0.54), (-0.101, 0.0, 0.54), (0.101, 0.24, 0.68)]))
    P.add("Handle", band((0.17, 0.08, 0.17), loc=(0, -0.3, 0.68)))


@item("marksman_rifle", "gear")
def marksman_rifle(P):
    w, g, d = shell(), plain(GREY, grime=0.4), rubber()
    P.add("Handle", box((0.2, 1.0, 0.26), w, loc=(0, 0.1, 0.62), r=0.05, n=1))
    P.add("Handle", box((0.14, 1.5, 0.14), g, loc=(0, -1.15, 0.66), r=0.03, n=1))
    for y in (-0.7, -1.1, -1.5):
        P.add("Handle", box((0.08, 0.14, 0.01), flat("#16161a"), loc=(0, y, 0.731), r=0.0, n=1))
    P.add("Handle", box((0.17, 0.14, 0.17), d, loc=(0, -1.97, 0.66), r=0.02, n=1))
    for sx in (1, -1):
        P.add("Handle", box((0.01, 0.08, 0.1), flat("#0c0c0e"), loc=(sx * 0.086, -1.97, 0.66), r=0.0, n=1))
    P.add("Handle", box((0.08, 0.012, 0.05), flat("#0c0c0e"), loc=(0, -2.041, 0.66), r=0.0, n=1))
    P.add("Handle", box((0.14, 0.8, 0.16), d, loc=(0, 0.0, 0.94), r=0.035, n=1))
    P.add("Handle", box((0.19, 0.1, 0.21), d, loc=(0, -0.43, 0.94), r=0.03, n=1))
    P.add("Handle", box((0.16, 0.08, 0.18), g, loc=(0, 0.43, 0.94), r=0.03, n=1))
    P.add("Handle", box((0.05, 0.06, 0.04), plain(ORANGE), loc=(0.09, 0.05, 0.96), r=0.01, n=1))
    P.add("Glow", box((0.14, 0.012, 0.15), lit(HEAVY), loc=(0, -0.481, 0.94), r=0.015, n=1))
    for y in (-0.22, 0.22):
        P.add("Handle", box((0.06, 0.06, 0.1), g, loc=(0, y, 0.8), r=0.01, n=1))
    P.add("Mag", box((0.12, 0.18, 0.26), plain(HEAVY, grime=0.35), loc=(0, -0.22, 0.38), r=0.025, n=1))
    P.add("Mag", box((0.14, 0.2, 0.035), plain(DARK), loc=(0, -0.22, 0.25), r=0.01, n=1))
    P.add("Handle", grip(0.33, 0.3, 0.42))
    P.add("Handle", trigger(0.09, 0.47))
    P.add("Handle", box((0.16, 0.9, 0.12), w, loc=(0, 1.05, 0.7), r=0.04, n=1))
    P.add("Handle", box((0.14, 0.78, 0.1), g, loc=(0, 1.12, 0.34), r=0.03, n=1))
    P.add("Handle", box((0.16, 0.1, 0.48), w, loc=(0, 1.5, 0.52), r=0.03, n=1))
    P.add("Handle", box((0.14, 0.12, 0.34), g, loc=(0, 0.76, 0.5), rot=(18, 0, 0), r=0.03, n=1))
    P.add("Handle", box((0.18, 0.05, 0.52), plain(ORANGE, grime=0.4), loc=(0, 1.57, 0.52), r=0.02, n=1))
    P.add("Handle", box((0.14, 0.32, 0.06), d, loc=(0, 1.05, 0.79), r=0.02, n=1))
    for sx in (1, -1):
        P.add("Handle", box((0.03, 0.6, 0.04), d, loc=(sx * 0.05, -1.35, 0.575), r=0.01, n=1))
        P.add("Glow", glowstrip(0.8, (sx * 0.071, -1.15, 0.66), HEAVY))
    P.add("Handle", box((0.14, 0.08, 0.08), g, loc=(0, -1.66, 0.57), r=0.015, n=1))
    P.add("Handle", hazard(0.3, 0.08, (0.101, 0.35, 0.56), (1, 0, 0), n=4))
    P.add("Handle", screws([(0.101, 0.45, 0.68), (-0.101, 0.45, 0.68)]))


@item("nail_gun", "gear")
def nail_gun(P):
    worn = paint(WHITE, chip=0.45, under="#8d8f92", under2="#5d6064", grime=0.7, streaks=0.5)
    d = rubber()
    duct = plain("#a9adb0", grime=0.5)
    P.add("Handle", box((0.24, 0.8, 0.34), worn, loc=(0, -0.05, 0.7), r=0.06, n=1))
    P.add("Handle", box((0.14, 0.3, 0.14), metal("#8a8d90", rust=0.4), loc=(0, -0.58, 0.62), r=0.02, n=1))
    P.add("Handle", box((0.2, 0.05, 0.2), d, loc=(0, -0.75, 0.62), r=0.02, n=1))
    P.add("Handle", box((0.05, 0.012, 0.05), flat("#0c0c0e"), loc=(0, -0.776, 0.62), r=0.0, n=1))
    P.add("Handle", box((0.2, 0.32, 0.02), cardboard(), loc=(0.0, 0.0, 0.875), rot=(0, 0, 6), r=0.005, n=1))
    for y in (-0.12, 0.12):
        P.add("Handle", box((0.26, 0.07, 0.37), duct, loc=(0, y, 0.7), r=0.012, n=1))
    P.add("Handle", grip(0.38, 0.34, 0.44, w=0.18, d=0.22, lean=10))
    P.add("Handle", band((0.19, 0.23, 0.08), loc=(0, 0.375, 0.3), rot=(10, 0, 0)))
    P.add("Handle", box((0.28, 0.4, 0.14), plain(GREY, grime=0.6), loc=(0, 0.42, 0.06), r=0.04, n=1))
    P.add("Handle", box((0.29, 0.06, 0.15), duct, loc=(0, 0.36, 0.06), r=0.012, n=1))
    P.add("Handle", box((0.04, 0.3, 0.04), plain(TEAL), loc=(0.141, 0.42, 0.07), r=0.01, n=1))
    P.add("Handle", trigger(0.16, 0.5))
    P.add("Handle", cyl(0.035, 0.7, metal("#7d7a78", rust=0.5), loc=(0.15, -0.1, 0.8), rot=(90, 0, 0), seg=6, bevel=0.006))
    for y in (-0.35, 0.15):
        P.add("Handle", box((0.06, 0.05, 0.08), plain("#cdb98a", grime=0.6), loc=(0.14, y, 0.8), r=0.01, n=1))
    P.add("Handle", tie(0.24, 0.34, -0.3, 0.7))
    P.add("Mag", box((0.07, 0.62, 0.16), plain(NAIL, grime=0.4), loc=(0, -0.22, 0.42), rot=(-18, 0, 0), r=0.02, n=1))
    P.add("Mag", box((0.075, 0.6, 0.025), metal("#b8bcc0", rust=0.1), loc=(0, -0.24, 0.5), rot=(-18, 0, 0), r=0.006, n=1))
    P.add("Glow", box((0.08, 0.012, 0.04), lit(NAIL), loc=(0, 0.351, 0.78), r=0.006, n=1))
    P.add("Handle", hazard(0.2, 0.07, (0.121, -0.3, 0.62), (1, 0, 0), n=3))
    P.add("Handle", words("NL", 0.07, flat("#1e1e22"), loc=(-0.123, 0.0, 0.72), rot=(0, 0, 90)))


@item("flare_gun", "gear")
def flare_gun(P):
    o, g, d = plain(ORANGE, grime=0.45), plain(GREY, grime=0.4), rubber()
    P.add("Handle", box((0.24, 0.42, 0.3), o, loc=(0, 0.08, 0.64), r=0.07, n=1))
    P.add("Handle", cyl(0.14, 0.52, o, loc=(0, -0.34, 0.68), rot=(90, 30, 0), seg=6, bevel=0.03))
    P.add("Handle", box((0.32, 0.09, 0.3), d, loc=(0, -0.62, 0.68), r=0.04, n=1))
    P.add("Handle", cyl(0.08, 0.01, flat("#121214"), loc=(0, -0.668, 0.68), rot=(90, 30, 0), seg=6, bevel=0.0))
    P.add("Handle", box((0.3, 0.1, 0.12), g, loc=(0, -0.06, 0.52), r=0.03, n=1))
    for sx in (1, -1):
        P.add("Handle", cyl(0.04, 0.03, plain(WHITE), loc=(sx * 0.155, -0.06, 0.52), rot=(0, 90, 0), seg=8, bevel=0.008))
    P.add("Handle", grip(0.26, 0.3, 0.46, w=0.21, d=0.27, lean=16))
    P.add("Handle", box((0.23, 0.29, 0.06), plain(WHITE, grime=0.4), loc=(0, 0.32, 0.06), rot=(16, 0, 0), r=0.02, n=1))
    P.add("Handle", box((0.08, 0.1, 0.12), plain(WHITE, grime=0.4), loc=(0, 0.3, 0.84), rot=(-25, 0, 0), r=0.02, n=1))
    P.add("Handle", trigger(0.04, 0.5, accent=WHITE))
    P.add("Mag", cyl(0.1, 0.36, plain(FLARE, grime=0.3), loc=(0, 0.12, 0.72), rot=(90, 30, 0), seg=6, bevel=0.015))
    P.add("Mag", cyl(0.12, 0.03, metal("#c9a24a", rust=0.1), loc=(0, 0.305, 0.72), rot=(90, 30, 0), seg=6, bevel=0.006))
    P.add("Glow", box((0.04, 0.4, 0.012), lit(FLARE), loc=(0, -0.34, 0.808), r=0.006, n=1))
    for sx in (1, -1):
        P.add("Handle", hazard(0.3, 0.08, (sx * 0.121, 0.06, 0.58), (sx, 0, 0), n=4))
    P.add("Handle", screws([(0.121, 0.22, 0.74), (-0.121, 0.22, 0.74)]))


@item("dart_blaster", "gear")
def dart_blaster(P):
    mint, w, d = plain("#9fe0c8", grime=0.25), plain(WHITE, grime=0.3), rubber()
    P.add("Handle", box((0.16, 1.1, 0.2), mint, loc=(0, -0.1, 0.66), r=0.06, n=1))
    P.add("Handle", box((0.2, 0.45, 0.2), w, loc=(0, -0.85, 0.66), r=0.07, n=1))
    for y in (-0.75, -0.85, -0.95):
        P.add("Handle", box((0.205, 0.04, 0.12), plain("#cfe9df", grime=0.2), loc=(0, y, 0.66), r=0.012, n=1))
    P.add("Handle", box((0.14, 0.04, 0.14), d, loc=(0, -1.09, 0.66), r=0.03, n=1))
    P.add("Handle", cyl(0.035, 0.01, flat("#121214"), loc=(0, -1.112, 0.66), rot=(90, 0, 0), seg=6, bevel=0.0))
    P.add("Handle", box((0.06, 0.7, 0.03), d, loc=(0, -0.2, 0.775), r=0.01, n=1))
    P.add("Handle", box((0.06, 0.05, 0.06), plain(ORANGE), loc=(0, -0.62, 0.8), r=0.012, n=1))
    P.add("Handle", box((0.26, 0.06, 0.1), plain(ORANGE, grime=0.25), loc=(0, 0.5, 0.7), r=0.03, n=1))
    P.add("Handle", box((0.06, 0.1, 0.06), d, loc=(0, 0.44, 0.7), r=0.015, n=1))
    P.add("Handle", box((0.14, 0.2, 0.38), d, loc=(0, 0.24, 0.38), rot=(18, 0, 0), r=0.05, n=1))
    P.add("Handle", trigger(0.04, 0.5))
    P.add("Mag", box((0.1, 0.32, 0.22), plain(DART, grime=0.25), loc=(0, -0.22, 0.86), r=0.03, n=1))
    for y in (-0.32, -0.22, -0.12):
        P.add("Mag", box((0.105, 0.04, 0.12), plain("#ffd1e4", grime=0.15), loc=(0, y, 0.87), r=0.01, n=1))
    for sx in (1, -1):
        P.add("Glow", glowstrip(0.45, (sx * 0.081, -0.15, 0.62), DART))
    P.add("Handle", words("SHH", 0.05, flat("#2b6b5a"), loc=(0, -0.85, 0.66), rot=(0, 0, 90)))
    P.add("Handle", screws([(0.081, 0.3, 0.66), (-0.081, 0.3, 0.66)], r=0.014))


@item("ammo_nails", "gear")
def ammo_nails(P):
    ammo_box(P, NAIL, "NL")
    for x in (-0.12, 0.0, 0.12):
        P.add("Body", box((0.06, 0.26, 0.03), metal("#b8bcc0", rust=0.1), loc=(x, 0, 0.3), r=0.008, n=1))


@item("ammo_flares", "gear")
def ammo_flares(P):
    ammo_box(P, FLARE, "FL")
    for x in (-0.13, 0.0, 0.13):
        P.add("Body", cyl(0.05, 0.04, plain(FLARE, grime=0.3), loc=(x, 0.02, 0.3), seg=6, bevel=0.008))
        P.add("Body", cyl(0.055, 0.015, metal("#c9a24a", rust=0.1), loc=(x, 0.02, 0.325), seg=6, bevel=0.004))


@item("ammo_darts", "gear")
def ammo_darts(P):
    ammo_box(P, DART, "DT", w=0.44, d=0.28, h=0.24)
    P.add("Body", box((0.3, 0.16, 0.012), plain("#ffd1e4", grime=0.1), loc=(0, 0, 0.255), r=0.004, n=1))
    for x in (-0.09, -0.03, 0.03, 0.09):
        P.add("Body", box((0.035, 0.14, 0.014), plain(DART), loc=(x, 0, 0.262), r=0.004, n=1))


@item("noise_maker", "gear", pivots={"Spin": (0, 0.09, 0.36)})
def noise_maker(P):
    coral, cream = plain("#f27b6b", grime=0.25), plain("#fff2dc", grime=0.2)
    brass = metal("#d8b25a", rust=0.05)
    P.add("Body", cyl(0.25, 0.18, coral, loc=(0, 0, 0.36), rot=(90, 0, 0), seg=20, bevel=0.03))
    P.add("Body", cyl(0.26, 0.04, cream, loc=(0, -0.1, 0.36), rot=(90, 0, 0), seg=20, bevel=0.015))
    P.add("Glow", cyl(0.2, 0.012, lit("#fff4c8"), loc=(0, -0.122, 0.36), rot=(90, 0, 0), seg=20, bevel=0.0))
    ink = flat("#2a2028")
    P.add("Body", box((0.02, 0.01, 0.13), ink, loc=(0, -0.132, 0.42), r=0.0, n=1))
    P.add("Body", box((0.1, 0.01, 0.02), ink, loc=(0.045, -0.132, 0.36), r=0.0, n=1))
    P.add("Body", cyl(0.02, 0.012, ink, loc=(0, -0.134, 0.36), rot=(90, 0, 0), seg=8, bevel=0.0))
    for sx in (1, -1):
        bell = lathe([(0, 0), (0.11, 0), (0.105, 0.04), (0.075, 0.085), (0, 0.105)], brass, seg=14)
        P.add("Body", move(bell, loc=(sx * 0.15, 0, 0.56), rot=(0, sx * 30, 0)))
        P.add("Body", box((0.03, 0.03, 0.08), brass, loc=(sx * 0.12, 0, 0.58), rot=(0, sx * 30, 0), r=0.008, n=1))
        P.add("Body", box((0.05, 0.12, 0.14), cream, loc=(sx * 0.15, 0, 0.07), rot=(0, sx * 20, 0), r=0.02, n=1))
    P.add("Body", box((0.04, 0.04, 0.1), brass, loc=(0, 0, 0.64), r=0.01, n=1))
    P.add("Body", box((0.14, 0.04, 0.03), brass, loc=(0, 0, 0.69), r=0.01, n=1))
    wings = [(-0.1, -0.045), (-0.02, -0.015), (0.02, -0.015), (0.1, -0.045), (0.1, 0.045), (0.02, 0.015), (-0.02, 0.015), (-0.1, 0.045)]
    P.add("Spin", slab(wings, 0.02, brass, loc=(0, 0.145, 0.36), bevel=0.006))
    P.add("Spin", box((0.03, 0.06, 0.03), brass, loc=(0, 0.115, 0.36), r=0.008, n=1))


@item("smoke_can", "gear")
def smoke_can(P):
    P.add("Body", cyl(0.16, 0.42, plain(GREY, grime=0.4), loc=(0, 0, 0.21), rot=(0, 0, 22.5), seg=8, bevel=0.03))
    P.add("Body", cyl(0.13, 0.05, plain(DARK), loc=(0, 0, 0.445), rot=(0, 0, 22.5), seg=8, bevel=0.015))
    for x, y in ((-0.05, -0.05), (0.05, -0.05), (-0.05, 0.05), (0.05, 0.05)):
        P.add("Body", box((0.04, 0.04, 0.01), flat("#0c0c0e"), loc=(x, y, 0.471), r=0.0, n=1))
    P.add("Body", box((0.11, 0.012, 0.3), plain(WHITE, grime=0.3), loc=(0, -0.149, 0.22), r=0.004, n=1))
    P.add("Body", words("SMK", 0.045, flat("#1e1e22"), loc=(0, -0.156, 0.28)))
    P.add("Body", hazard(0.1, 0.07, (0, -0.156, 0.14), (0, -1, 0), n=2))
    P.add("Body", box((0.2, 0.012, 0.06), plain(ORANGE, grime=0.3), loc=(0, -0.149, 0.4), r=0.004, n=1))
    P.add("Body", box((0.12, 0.025, 0.08), plain(ORANGE, grime=0.3), loc=(0.0, 0.08, 0.5), rot=(-20, 0, 0), r=0.01, n=1))
    P.add("Body", box((0.06, 0.01, 0.025), flat("#1e1e22"), loc=(0.0, 0.066, 0.51), rot=(-20, 0, 0), r=0.003, n=1))


def shell_dome(outer, inner, mat, sy=1.0, seg=24):
    """Helmet shell with thickness: inner profile top-down, then outer profile bottom-up."""
    return lathe(list(inner) + list(outer), mat, scl=(1, sy, 1), seg=seg)


# Helmets: build with the head's bottom at z = 0 and its top at 1.2 (Roblox HatAttachment at the bottom).
HEAD = {"Body": (0, 0, 0)}


@item("bike_helmet", "gear", pivots=HEAD)
def bike_helmet(P):
    c = plain("#f27b6b", grime=0.25)
    P.add("Body", shell_dome([(0.6, 0.62), (0.62, 0.72), (0.58, 0.9), (0.47, 1.06), (0.27, 1.19), (0, 1.24)],
                             [(0, 1.16), (0.42, 1.0), (0.54, 0.75), (0.55, 0.62)], c, sy=1.32))
    # long dark vent slots front to back are what make it read as a bike helmet, not a cap
    for x, z, tilt in ((-0.38, 1.04, -32), (-0.19, 1.17, -15), (0.0, 1.225, 0), (0.19, 1.17, 15), (0.38, 1.04, 32)):
        P.add("Body", box((0.08, 0.62, 0.04), flat("#1e1e22"), loc=(x, 0.02, z), rot=(0, tilt, 0), r=0.015, n=1))
    P.add("Body", box((0.5, 0.18, 0.12), plain(DARK), loc=(0, 0.78, 0.7), rot=(25, 0, 0), r=0.03, n=1))
    for x in (-0.57, 0.57):
        P.add("Body", box((0.03, 0.06, 0.5), plain(DARK), loc=(x, -0.08, 0.4), rot=(0, 0, 0), r=0.01, n=1))
    P.add("Body", box((0.7, 0.24, 0.035), plain(DARK), loc=(0, -0.72, 0.8), rot=(-18, 0, 0), r=0.015, n=1))
    P.add("Body", box((0.5, 0.05, 0.06), plain(TEAL, grime=0.2), loc=(0, 0.69, 0.82), r=0.015, n=1))


@item("hard_hat", "gear", pivots=HEAD)
def hard_hat(P):
    y = plain("#f2c94c", grime=0.35)
    P.add("Body", shell_dome([(0.58, 0.64), (0.57, 0.8), (0.5, 0.97), (0.36, 1.12), (0.18, 1.2), (0, 1.22)],
                             [(0, 1.14), (0.42, 0.95), (0.53, 0.7), (0.54, 0.64)], y, sy=1.12))
    brim = lathe([(0.54, 0.6), (0.68, 0.58), (0.7, 0.61), (0.56, 0.67), (0.54, 0.6)], y, scl=(1, 1.15, 1), seg=24)
    P.add("Body", move(brim, loc=(0, -0.04, 0)))
    P.add("Body", shell_dome([(0.585, 0.68), (0.58, 0.76)], [(0.56, 0.76), (0.56, 0.68)], plain(DARK), sy=1.12))
    P.add("Body", box((0.12, 0.45, 0.06), y, loc=(0, 0.0, 1.2), r=0.03, n=1))
    P.add("Body", box((0.24, 0.14, 0.17), plain(DARK), loc=(0, -0.64, 0.86), r=0.03, n=1))
    P.add("Body", box((0.27, 0.06, 0.2), plain(ORANGE, grime=0.3), loc=(0, -0.7, 0.86), r=0.02, n=1))
    P.add("Glow", box((0.17, 0.012, 0.12), lit("#fff4c8"), loc=(0, -0.732, 0.86), r=0.015, n=1))
    P.add("Body", box((0.16, 0.012, 0.06), plain("#f4ecd8", grime=0.2), loc=(0.3, -0.56, 0.9), rot=(0, 0, -28), r=0.004, n=1))


@item("riot_helmet", "gear", pivots={"Body": (0, 0, 0), "Visor": (0, 0, 0.8)})
def riot_helmet(P):
    w, g, d = plain(WHITE, grime=0.35), plain(GREY, grime=0.35), plain(DARK, grime=0.3)
    P.add("Body", shell_dome([(0.62, 0.72), (0.63, 0.85), (0.58, 1.02), (0.44, 1.18), (0.24, 1.29), (0, 1.32)],
                             [(0, 1.22), (0.45, 1.05), (0.56, 0.8), (0.57, 0.72)], w, sy=1.12))
    # Skirt wraps the sides and back only, so the face stays open when the visor lifts.
    back = lambda r, z: [(r * math.cos(math.radians(a)), 1.12 * r * math.sin(math.radians(a)), z) for a in range(-15, 196, 15)]
    P.add("Body", loft([back(r, z) + list(reversed(back(r - 0.05, z))) for z, r in ((0.3, 0.6), (0.55, 0.63), (0.8, 0.63))], g, smooth=40))
    for sx in (1, -1):
        P.add("Body", cyl(0.07, 0.05, plain(ORANGE, grime=0.3), loc=(sx * 0.68, 0, 0.8), rot=(0, 90, 0), seg=8, bevel=0.01))
    P.add("Body", box((0.1, 1.1, 0.06), plain(ORANGE, grime=0.3), loc=(0, 0.05, 1.3), r=0.03, n=1))
    P.add("Body", box((0.6, 0.03, 0.08), plain(ORANGE, grime=0.3), loc=(0, 0.69, 0.62), rot=(-12, 0, 0), r=0.01, n=1))
    arc = lambda r, z: [(r * math.cos(math.radians(a)), r * math.sin(math.radians(a)), z) for a in range(-160, -15, 15)]
    rings = []
    for z, ro in ((0.12, 0.66), (0.4, 0.7), (0.7, 0.71), (0.98, 0.69)):
        rings.append(arc(ro, z) + list(reversed(arc(ro - 0.03, z))))
    P.add("Visor", loft(rings, plain("#3b5a66", grime=0.1, vary=0.1), smooth=40))
    for sx in (1, -1):
        P.add("Visor", box((0.04, 0.28, 0.16), d, loc=(sx * 0.665, -0.12, 0.8), r=0.015, n=1))
    P.add("Visor", box((0.5, 0.05, 0.05), d, loc=(0, -0.71, 0.97), r=0.015, n=1))


# Backpacks: the face against the player's back sits at y = 0, the pack sticks out along +y.
@item("school_backpack", "gear", pivots={"Body": (0, 0, 0.75), "Flap": (0, 0.02, 1.45)})
def school_backpack(P):
    blue, dark = cloth("#5aa9e6", dirt=0.3), cloth("#3d7fb8", dirt=0.3)
    P.add("Body", box((1.2, 0.5, 1.4), blue, loc=(0, 0.25, 0.7), r=0.18, n=2))
    P.add("Body", box((0.9, 0.2, 0.6), cloth("#f2c94c", dirt=0.3), loc=(0, 0.55, 0.45), r=0.1, n=1))
    for sx in (1, -1):
        P.add("Body", box((0.16, 0.06, 1.1), plain(DARK), loc=(sx * 0.3, -0.02, 0.72), r=0.02, n=1))
    P.add("Body", box((0.5, 0.06, 0.1), plain(DARK), loc=(0, -0.02, 1.3), r=0.02, n=1))
    P.add("Body", box((0.4, 0.04, 0.8), cloth("#3d7fb8", dirt=0.2), loc=(0, -0.005, 0.72), r=0.04, n=1))
    P.add("Body", box((0.1, 0.02, 0.14), plain(TEAL, grime=0.2), loc=(0.3, -0.06, 0.3), r=0.01, n=1))
    P.add("Body", box((0.12, 0.012, 0.16), plain("#f4ecd8", grime=0.2), loc=(0.35, 0.656, 0.5), rot=(0, 10, 0), r=0.004, n=1))
    P.add("Flap", box((1.1, 0.5, 0.1), dark, loc=(0, 0.25, 1.42), r=0.05, n=1))
    P.add("Flap", box((0.5, 0.08, 0.3), dark, loc=(0, 0.51, 1.3), r=0.04, n=1))
    P.add("Flap", box((0.14, 0.04, 0.08), plain(ORANGE), loc=(0, 0.56, 1.2), r=0.01, n=1))


@item("hiking_pack", "gear", pivots={"Body": (0, 0, 1.1), "Flap": (0, 0.66, 1.65)})
def hiking_pack(P):
    green, dark = cloth("#4f8f6a", dirt=0.35), cloth("#3a6e50", dirt=0.35)
    P.add("Body", box((1.2, 0.6, 2.0), green, loc=(0, 0.3, 1.0), r=0.2, n=2))
    for sx in (1, -1):
        P.add("Body", box((0.16, 0.42, 0.6), dark, loc=(sx * 0.66, 0.32, 0.6), r=0.06, n=1))
        P.add("Body", box((0.08, 0.06, 2.0), plain(GREY), loc=(sx * 0.45, -0.02, 1.0), r=0.02, n=1))
        P.add("Body", box((0.15, 0.06, 1.3), plain(DARK), loc=(sx * 0.28, -0.05, 1.2), r=0.02, n=1))
    P.add("Body", box((1.3, 0.1, 0.18), plain(DARK), loc=(0, -0.03, 0.25), r=0.03, n=1))
    P.add("Body", box((0.14, 0.12, 0.12), plain(ORANGE), loc=(0, -0.06, 0.25), r=0.02, n=1))
    P.add("Body", box((0.9, 0.15, 0.7), dark, loc=(0, 0.66, 1.05), r=0.06, n=1))
    P.add("Body", cyl(0.22, 1.3, cloth("#a8d8c8", dirt=0.3), loc=(0, 0.3, 2.2), rot=(0, 90, 0), seg=12, bevel=0.06))
    for sx in (1, -1):
        P.add("Body", box((0.06, 0.48, 0.48), plain(DARK), loc=(sx * 0.4, 0.3, 2.2), r=0.04, n=1))
    P.add("Body", box((0.5, 0.012, 0.1), plain(ORANGE), loc=(0, 0.606, 1.75), r=0.004, n=1))
    P.add("Flap", box((0.9, 0.08, 0.5), green, loc=(0, 0.75, 1.42), r=0.04, n=1))
    P.add("Flap", box((0.12, 0.04, 0.1), plain(ORANGE), loc=(0, 0.8, 1.22), r=0.01, n=1))


@item("big_duffel", "gear", pivots={"Body": (0, 0, 0.5), "Flap": (0, 0.25, 0.8)})
def big_duffel(P):
    red, dark = cloth("#d9644f", dirt=0.35), cloth("#a84a3a", dirt=0.35)
    P.add("Body", box((2.0, 0.8, 0.8), red, loc=(0, 0.4, 0.4), r=0.15, n=2))
    for sx in (1, -1):
        P.add("Body", box((0.06, 0.66, 0.66), dark, loc=(sx * 1.0, 0.4, 0.4), r=0.04, n=1))
        P.add("Body", box((0.16, 0.06, 0.9), plain(DARK), loc=(sx * 0.45, -0.02, 0.45), rot=(0, sx * 12, 0), r=0.02, n=1))
        P.add("Body", box((0.08, 0.1, 0.2), plain(DARK), loc=(sx * 0.3, 0.6, 0.85), r=0.02, n=1))
    P.add("Body", box((0.7, 0.1, 0.06), plain(DARK), loc=(0, 0.6, 0.96), r=0.02, n=1))
    P.add("Body", box((1.6, 0.012, 0.1), plain(TEAL, grime=0.2), loc=(0, 0.808, 0.35), r=0.004, n=1))
    P.add("Flap", box((1.4, 0.3, 0.06), dark, loc=(0, 0.4, 0.8), r=0.03, n=1))
    P.add("Flap", box((0.06, 0.06, 0.1), plain(ORANGE), loc=(0.68, 0.56, 0.78), r=0.01, n=1))


main()
