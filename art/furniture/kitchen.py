import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *  # noqa


@item("counter", "furniture", pivots={f"Door{i + 1}": (x - 0.45, -0.95, 1.35) for i, x in enumerate((-1, 0, 1))})
def counter(P):
    body = enamel(MINT)
    P.add("Body", hollow(4, 1.9, 2.6, body, y=0.05, z0=0.15))
    P.add("Body", box((3.8, 1.6, 0.06), enamel(CREAM), loc=(0, 0.1, 1.4), r=0.0, n=1))
    P.add("Body", box((4.15, 2.15, 0.25), pine(), loc=(0, 0, 2.875), r=0.05, n=1))
    P.add("Body", box((3.9, 1.9, 0.3), enamel(CHAR), loc=(0, 0.1, 0.15), r=0.02, n=1))
    for i, x in enumerate((-1, 0, 1)):
        P.add(f"Door{i + 1}", box((0.92, 0.1, 2.3), enamel("#8cc9b4"), loc=(x, -0.98, 1.45), r=0.04, n=1))
        P.add(f"Door{i + 1}", handle(x + 0.3, 2.05, -1.04, 0.4, vertical=True))
    P.add("Body", box((0.6, 0.5, 0.5), cardboard(), loc=(-1.0, 0.2, 0.6), r=0.03, n=1))
    P.add("Body", cyl(0.2, 0.5, plain("#e8794a", grime=0.2), loc=(0.9, 0.3, 1.68), seg=10))
    P.add("Body", tag(-1.6, 2.5, -1.08))


@item("fridge", "furniture", pivots={"Door": (1.2, -1.25, 3), "Door2": (1.2, -1.25, 4.95)})
def fridge(P):
    shell = enamel(CREAM)
    lining = plain("#f7f7f2", grime=0.1)
    P.add("Body", hollow(2.5, 2.4, 6, shell, y=0.05, r=0.12))
    P.add("Body", box((2.28, 2.2, 0.12), lining, loc=(0, 0.1, 3.9), r=0.02, n=1))
    for z in (1.1, 2.2, 3.05):
        P.add("Body", box((2.2, 2.0, 0.05), flat("#dfe9ee"), loc=(0, 0.15, z), r=0.0, n=1))
    P.add("Body", box((0.5, 0.5, 0.9), plain(WHITE), loc=(-0.6, 0.3, 1.58), r=0.04, n=1))
    P.add("Body", box((0.3, 0.3, 0.12), plain(CORAL), loc=(-0.6, 0.3, 2.07), r=0.02, n=1))
    P.add("Body", cyl(0.3, 0.35, plain("#43a047", grime=0.1), loc=(0.5, 0.3, 2.4), seg=10))
    P.add("Body", box((0.8, 0.6, 0.4), plain("#fdd835", grime=0.1), loc=(0.3, 0.2, 1.33), r=0.05, n=1))
    P.add("Glow", box((1.0, 0.3, 0.08), glow("#fff8e1"), loc=(0, 0.2, 3.8), r=0.02, n=1))
    P.add("Door", box((2.45, 0.18, 3.8), shell, loc=(0, -1.2, 1.95), r=0.12, n=1))
    P.add("Door", handle(-1.0, 2.8, -1.29, 1.2, vertical=True))
    P.add("Door2", box((2.45, 0.18, 2.0), shell, loc=(0, -1.2, 4.95), r=0.12, n=1))
    P.add("Door2", handle(-1.0, 4.4, -1.29, 0.7, vertical=True))
    for x, z, c in ((0.4, 2.9, "#e53935"), (0.7, 2.5, "#1e88e5"), (0.3, 2.2, "#fdd835")):
        P.add("Door", box((0.18, 0.05, 0.18), plain(c), loc=(x, -1.31, z), r=0.05, n=1))
    P.add("Door", box((0.5, 0.02, 0.65), plain("#fffdf5", grime=0.2), loc=(0.55, -1.3, 1.6), rot=(0, 6, 0), r=0.01, n=1))
    P.add("Door2", tag(0.7, 5.3, -1.3))


@item("stove", "furniture", pivots={"Flap": (0, -1.0, 0.55)})
def stove(P):
    P.add("Body", box((2.5, 2, 2.8), enamel(WHITE), loc=(0, 0, 1.4), r=0.12, n=1))
    P.add("Body", box((2.5, 2, 0.12), enamel(CHAR), loc=(0, 0, 2.86), r=0.05, n=1))
    for x in (-0.6, 0.6):
        for y in (-0.45, 0.45):
            P.add("Body", cyl(0.38, 0.05, metal("#2b2b2b", rust=0.2), loc=(x, y, 2.94), seg=16, bevel=0.02))
            P.add("Glow", cyl(0.26, 0.04, glow("#ff5722", core="#ffab91"), loc=(x, y, 2.98), seg=16, bevel=0.0))
    P.add("Body", box((2.5, 0.35, 0.6), enamel(WHITE), loc=(0, 0.85, 3.2), r=0.08, n=1))
    for x in (-0.8, -0.3, 0.3, 0.8):
        P.add("Body", cyl(0.1, 0.12, plain(CHAR), loc=(x, 0.66, 3.25), rot=(90, 0, 0), seg=8, bevel=0.02))
    P.add("Body", box((2.0, 0.1, 1.5), flat("#2a2c33"), loc=(0, -0.97, 1.35), r=0.02, n=1))
    P.add("Body", box((1.6, 1.4, 0.05), metal("#9a9da3", rust=0.2), loc=(0, -0.2, 1.1), r=0.0, n=1))
    P.add("Flap", box((2.1, 0.12, 1.6), enamel(WHITE), loc=(0, -1.06, 1.35), r=0.06, n=1))
    P.add("Flap", box((1.5, 0.04, 0.8), flat("#1a1c22"), loc=(0, -1.13, 1.45), r=0.04, n=1))
    P.add("Flap", handle(0, 2.0, -1.12, 1.6))


@item("kitchen_table", "furniture")
def kitchen_table(P):
    P.add("Body", box((4, 2.6, 0.18), pine(), loc=(0, 0, 2.41), r=0.06, n=1))
    P.add("Body", box((3.6, 2.2, 0.3), pine(), loc=(0, 0, 2.18), r=0.03, n=1))
    P.add("Body", legs4(3.9, 2.5, 2.05, pine(), t=0.2))
    P.add("Body", box((1.4, 1.0, 0.02), cloth(CORAL, dirt=0.1, weave=40), loc=(0.6, 0.2, 2.51), r=0.0, n=1))


@item("kitchen_chair", "furniture")
def kitchen_chair(P):
    P.add("Body", box((1.6, 1.5, 0.14), pine(), loc=(0, 0, 1.45), r=0.05, n=1))
    P.add("Body", box((1.4, 1.3, 0.12), fabric(CORAL), loc=(0, -0.02, 1.58), r=0.06, n=1))
    P.add("Body", legs4(1.5, 1.4, 1.38, pine(), t=0.14, inset=0.12))
    for x in (-0.65, 0.65):
        P.add("Body", box((0.14, 0.14, 1.75), pine(), loc=(x, 0.63, 2.4), r=0.04, n=1))
    for z in (2.55, 3.1):
        P.add("Body", box((1.44, 0.12, 0.28), pine(), loc=(0, 0.63, z), r=0.04, n=1))


@item("pantry", "furniture", pivots={"Door": (-1.2, -0.9, 3)})
def pantry(P):
    P.add("Body", hollow(2.5, 1.8, 6, enamel(BUTTER), r=0.08))
    cans = ("#e8794a", "#c62828", "#43a047", "#1e88e5", "#fdd835")
    for k, z in enumerate((1.5, 3.0, 4.5)):
        P.add("Body", box((2.26, 1.6, 0.08), pine(), loc=(0, 0.05, z), r=0.0, n=1))
        for i in range(4):
            if (i + k) % 3 == 2:
                continue
            P.add("Body", cyl(0.18, 0.42, plain(cans[(i + k) % 5], grime=0.2), loc=(-0.8 + i * 0.52, 0.1, z + 0.25), seg=10))
    P.add("Body", box((1.0, 0.7, 0.8), cardboard(), loc=(0.3, 0.2, 0.52), r=0.03, n=1))
    P.add("Door", box((2.35, 0.12, 5.6), enamel("#f2cd5e"), loc=(0, -0.92, 3.0), r=0.06, n=1))
    P.add("Door", door_lines(0, 4.3, 1.9, 1.8, -0.98, enamel(BUTTER)))
    P.add("Door", door_lines(0, 1.8, 1.9, 2.6, -0.98, enamel(BUTTER)))
    P.add("Door", handle(0.9, 3.0, -1.0, 0.7, vertical=True))
    P.add("Door", tag(-0.6, 5.5, -1.0))


main()
