import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *  # noqa


@item("desk", "furniture", size=1024)
def desk(P):
    top = wood(WHITE, "#d8d2c6", axis="x", wear=0.3)
    P.add("Body", box((5, 2.5, 0.16), top, loc=(0, 0, 2.42), r=0.04, n=1))
    P.add("Body", box((1.6, 2.3, 2.34), enamel(GREY), loc=(1.6, 0, 1.17), r=0.05, n=1))
    for i, z in enumerate((0.5, 1.2, 1.9)):
        P.add(f"Drawer{i + 1}", drawer(1.6, z, 1.4, 0.62, -1.13, 1.8, enamel("#cfd2d8")))
    P.add("Body", box((0.12, 2.3, 2.34), enamel(GREY), loc=(-2.4, 0, 1.17), r=0.03, n=1))
    P.add("Body", box((1.8, 0.12, 1.1), plain(CHAR), loc=(-0.4, 0.6, 3.25), r=0.05, n=1))
    P.add("Screen", box((1.65, 0.02, 0.95), flat("#21405e"), loc=(-0.4, 0.535, 3.27), r=0.0, n=1))
    P.add("Body", box((0.15, 0.15, 0.45), plain(CHAR), loc=(-0.4, 0.7, 2.7), r=0.03, n=1))
    P.add("Body", box((0.7, 0.4, 0.04), plain(CHAR), loc=(-0.4, 0.7, 2.52), r=0.02, n=1))
    P.add("Body", box((1.3, 0.45, 0.06), plain("#dcdcdc"), loc=(-0.4, -0.3, 2.53), r=0.02, n=1))
    P.add("Body", box((0.5, 0.5, 0.03), plain("#fff59d"), loc=(0.9, -0.5, 2.52), rot=(0, 0, 14), r=0.0, n=1))


@item("office_chair", "furniture", pivots={"Spin": (0, 0, 1.3)})
def office_chair(P):
    base = plain(CHAR, grime=0.2)
    for i in range(5):
        a = i * 72
        P.add("Body", box((1.15, 0.22, 0.14), base, loc=(0, 0, 0.32), rot=(0, 0, a), r=0.05, n=1))
    import math
    for i in range(5):
        a = math.radians(i * 72)
        P.add("Body", cyl(0.14, 0.12, base, loc=(math.cos(a) * 1.05, math.sin(a) * 1.05, 0.12), rot=(90, 0, i * 72 + 90), seg=8))
    P.add("Body", cyl(0.14, 1.0, metal("#9a9da3", rust=0.05), loc=(0, 0, 0.85), seg=6))
    P.add("Spin", box((1.8, 1.7, 0.35), fabric(CORAL), loc=(0, 0, 1.5), r=0.15, n=2))
    P.add("Spin", box((0.5, 0.5, 0.2), base, loc=(0, 0, 1.28), r=0.05, n=1))
    P.add("Spin", box((1.7, 0.35, 2.0), fabric(CORAL), loc=(0, 0.75, 2.75), rot=(-8, 0, 0), r=0.15, n=2))
    for sx in (-1, 1):
        P.add("Spin", box((0.18, 1.0, 0.12), base, loc=(sx * 0.95, 0.1, 2.15), r=0.04, n=1))
        P.add("Spin", box((0.14, 0.14, 0.5), base, loc=(sx * 0.95, 0.35, 1.85), r=0.04, n=1))


@item("filing_cabinet", "furniture")
def filing_cabinet(P):
    P.add("Body", box((1.7, 2.2, 4.5), metal("#a7adb5", rust=0.15), loc=(0, 0, 2.25), r=0.06, n=1))
    for i, z in enumerate((0.75, 2.2, 3.65)):
        P.add(f"Drawer{i + 1}", drawer(0, z, 1.5, 1.3, -1.08, 1.9, metal("#b8bec6", rust=0.1)))
        P.add(f"Drawer{i + 1}", box((0.4, 0.02, 0.2), plain("#fffdf5"), loc=(0, -1.2, z + 0.4), r=0.0, n=1))
        for k in range(5):
            P.add(f"Drawer{i + 1}", box((1.2, 0.04, 0.75), plain("#f2e6c9" if k % 2 else "#e7d3a8"), loc=(0, -0.7 + k * 0.32, z - 0.05), r=0.0, n=1))
    P.add("Body", box((0.9, 0.7, 0.5), cardboard(), loc=(0.1, 0.2, 4.75), rot=(0, 0, 8), r=0.03, n=1))


@item("whiteboard", "furniture", size=1024)
def whiteboard(P):
    frame = metal("#c9ccd1", rust=0.05)
    P.add("Body", box((5.2, 0.2, 3.4), frame, loc=(0, 0, 4.0), r=0.05, n=1))
    P.add("Screen", box((5.0, 0.04, 3.2), flat("#fbfbf8"), loc=(0, -0.11, 4.0), r=0.0, n=1))
    for sx in (-1, 1):
        P.add("Body", box((0.16, 0.16, 5.4), frame, loc=(sx * 2.4, 0, 2.8), r=0.04, n=1))
        P.add("Body", box((0.2, 1.8, 0.16), frame, loc=(sx * 2.4, 0, 0.3), r=0.04, n=1))
        for sy in (-1, 1):
            P.add("Body", cyl(0.14, 0.1, plain(CHAR), loc=(sx * 2.4, sy * 0.8, 0.12), rot=(0, 90, 0), seg=8))
    P.add("Body", box((5.0, 0.3, 0.08), frame, loc=(0, -0.15, 2.32), r=0.02, n=1))


main()
