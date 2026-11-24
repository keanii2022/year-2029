import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *  # noqa


def star(x, z, y, r, mat, rot=0):
    import math
    inner = r * 0.42
    out = [slab([(math.cos(math.radians(90 + i * 72 + rot)) * inner, math.sin(math.radians(90 + i * 72 + rot)) * inner) for i in range(5)],
                0.02, mat, loc=(x, y, z))]
    b = inner * math.sin(math.radians(36))
    for i in range(5):
        a = 90 + i * 72 + rot
        out.append(slab([(-b, inner * 0.78), (b, inner * 0.78), (0, r)], 0.02, mat, loc=(x, y, z), rot=(0, 90 - a, 0)))
    return out


@item("toy_chest", "furniture", pivots={"Lid": (0, 0.9, 1.8)})
def toy_chest(P):
    P.add("Body", hollow(3.2, 1.8, 1.6, enamel(BUTTER), open_side="top", r=0.06))
    P.add("Body", ball(0.4, plain("#e53935"), loc=(-0.8, 0.2, 0.55), seg=10, rings=6))
    P.add("Body", box((0.9, 0.5, 0.5), plain("#43a047"), loc=(0.6, 0.3, 0.4), rot=(0, 0, 20), r=0.08, n=1))
    P.add("Body", ball((0.3, 0.25, 0.35), plain("#a1887f", grime=0.2), loc=(0.3, -0.3, 0.5), seg=10, rings=7))
    P.add("Lid", box((3.3, 1.9, 0.35), enamel(SKY), loc=(0, 0, 1.78), r=0.12, n=1))
    for x, z, c, r in ((-0.9, 0.9, CORAL, 0.35), (0.2, 0.6, MINT, 0.25), (1.0, 1.05, WHITE, 0.2)):
        P.add("Body", star(x, z, -0.91, r, plain(c, grime=0.1)))
    P.add("Lid", box((0.5, 0.12, 0.18), enamel(CORAL), loc=(0, -0.97, 1.7), r=0.05, n=1))
    P.add("Lid", box((0.5, 0.5, 0.5), plain("#e53935"), loc=(1.1, 0.0, 2.2), rot=(0, 0, 20), r=0.05, n=1))


@item("kid_bed", "furniture", size=1024)
def kid_bed(P):
    w, l = 3.4, 6
    frame = enamel(CORAL)
    P.add("Body", box((w + 0.2, l, 0.8), frame, loc=(0, 0, 0.6), r=0.12, n=1))
    P.add("Body", box((w + 0.3, 0.3, 2.6), frame, loc=(0, l / 2, 1.3), r=0.3, n=1))
    P.add("Body", box((w + 0.3, 0.3, 1.6), frame, loc=(0, -l / 2, 0.8), r=0.3, n=1))
    P.add("Body", box((0.2, l * 0.5, 0.5), frame, loc=(-w / 2 - 0.05, l * 0.15, 1.5), r=0.08, n=1))
    P.add("Body", box((w - 0.1, l - 0.3, 0.55), fabric(WHITE), loc=(0, 0, 1.25), r=0.18, n=2))
    P.add("Body", box((w, l * 0.6, 0.18), fabric(SKY), loc=(0, -l * 0.17, 1.55), r=0.08, n=2))
    P.add("Body", box((w * 0.6, 0.9, 0.3), fabric(BUTTER), loc=(0, l / 2 - 0.7, 1.65), r=0.14, n=2))
    for x, r in ((-0.8, 0.35), (0.5, 0.25), (1.1, 0.18)):
        P.add("Body", star(x, 1.9, l / 2 - 0.17, r, plain(BUTTER), rot=x * 30))
    P.add("Body", ball((0.35, 0.3, 0.4), plain("#a1887f", grime=0.2), loc=(1.0, l / 2 - 0.9, 2.05), seg=10, rings=7))
    P.add("Body", ball(0.2, plain("#a1887f", grime=0.2), loc=(1.0, l / 2 - 0.95, 2.6), seg=10, rings=7))


@item("play_table", "furniture")
def play_table(P):
    P.add("Body", box((3, 3, 0.2), enamel(WHITE), loc=(0, 0, 1.55), r=0.25, n=1))
    for sx, c in ((-1, "#e53935"), (1, "#1e88e5")):
        for sy, c2 in ((-1, "#fdd835"), (1, "#43a047")):
            P.add("Body", box((0.3, 0.3, 1.45), plain(c if sy < 0 else c2), loc=(sx * 1.2, sy * 1.2, 0.72), r=0.04, n=1))
    for i, c in enumerate(("#e53935", "#fdd835", "#1e88e5", "#43a047")):
        P.add("Body", box((0.45, 0.45, 0.45), plain(c), loc=(-0.5 + (i % 2) * 0.6, -0.3 + (i // 2) * 0.6, 1.88 + (i == 3) * 0.45),
                          rot=(0, 0, i * 17), r=0.06, n=1))


main()
