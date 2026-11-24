import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *  # noqa


@item("bathtub", "furniture", size=1024)
def bathtub(P):
    white = enamel(WHITE)
    w, d, h = 5.6, 2.8, 2.0
    P.add("Body", box((w - 0.5, 0.3, h - 0.04), white, loc=(0, -d / 2 + 0.15, h / 2), r=0.12, n=1))
    P.add("Body", box((w - 0.5, 0.3, h - 0.04), white, loc=(0, d / 2 - 0.15, h / 2), r=0.12, n=1))
    for sx in (-1, 1):
        P.add("Body", box((0.3, d, h), white, loc=(sx * (w / 2 - 0.15), 0, h / 2), r=0.12, n=1))
    P.add("Body", box((w - 0.4, d - 0.4, 0.5), white, loc=(0, 0, 0.25), r=0.1, n=1))
    P.add("Body", box((w - 0.5, d - 0.5, 0.04), flat("#bfe3f2"), loc=(0, 0, 1.2), r=0.0, n=1))
    for i in range(6):
        P.add("Body", ball(0.22, plain("#fff8e1", grime=0.05), loc=(-1.6 + i * 0.5, (i % 2) * 0.4 - 0.2, 1.25), seg=8, rings=5))
    P.add("Tap", box((0.3, 0.3, 0.7), metal("#d0d4d8", rust=0.05), loc=(w / 2 - 0.5, d / 2 - 0.25, 2.3), r=0.06, n=1))
    P.add("Tap", box((0.25, 0.6, 0.18), metal("#d0d4d8", rust=0.05), loc=(w / 2 - 0.5, d / 2 - 0.6, 2.55), r=0.06, n=1))
    P.add("Body", box((0.6, 0.45, 0.35), plain("#ffd54f"), loc=(-1.5, -0.2, 1.42), r=0.15, n=2))


@item("sink_cabinet", "furniture", pivots={"DoorL": (-1.3, -0.9, 1.3), "DoorR": (1.3, -0.9, 1.3)})
def sink_cabinet(P):
    P.add("Body", hollow(2.8, 1.8, 2.7, enamel(MINT), r=0.06))
    P.add("Body", box((0.3, 0.3, 0.9), plain("#eceff1"), loc=(0, 0.3, 1.6), r=0.05, n=1))
    P.add("Body", box((0.5, 0.35, 0.6), plain(SKY), loc=(-0.8, 0.2, 0.42), r=0.08, n=1))
    P.add("Body", box((0.45, 0.45, 0.4), plain(WHITE), loc=(0.8, 0.1, 0.32), r=0.15, n=1))
    P.add("Body", box((3.0, 2.0, 0.3), enamel(WHITE), loc=(0, 0, 2.85), r=0.08, n=1))
    P.add("Body", box((1.8, 1.1, 0.04), flat("#d8dde2"), loc=(0, -0.1, 3.01), r=0.0, n=1))
    for name, x in (("DoorL", -0.68), ("DoorR", 0.68)):
        P.add(name, box((1.3, 0.1, 2.3), enamel("#8cc9b4"), loc=(x, -0.95, 1.35), r=0.04, n=1))
        P.add(name, handle(x * 0.35, 1.9, -1.0, 0.35, vertical=True))
    tap = metal("#d0d4d8", rust=0.05)
    P.add("Tap", box((0.25, 0.25, 0.6), tap, loc=(0, 0.75, 3.3), r=0.06, n=1))
    P.add("Tap", box((0.2, 0.55, 0.16), tap, loc=(0, 0.5, 3.55), r=0.05, n=1))
    P.add("Body", box((0.35, 0.3, 0.55), plain(CORAL), loc=(1.0, 0.6, 3.27), r=0.08, n=1))


@item("shower_door", "furniture")
def shower_door(P):
    frame = metal("#cfd3d8", rust=0.05)
    w, h = 3.4, 6.8
    for sx in (-1, 1):
        P.add("Body", box((0.16, 0.2, h), frame, loc=(sx * (w / 2), 0, h / 2), r=0.04, n=1))
    for z in (0.08, h - 0.08):
        P.add("Body", box((w, 0.2, 0.16), frame, loc=(0, 0, z), r=0.04, n=1))
    P.add("Slide", box((w - 0.16, 0.06, h - 0.16), plain("#cfe9f2", grime=0.05, vary=0.1), loc=(0, 0, h / 2), r=0.0, n=1))
    P.add("Slide", box((0.12, 0.2, 1.4), frame, loc=(w / 2 - 0.4, -0.12, 3.4), r=0.04, n=1))
    for i, (x, z) in enumerate(((-0.8, 5.2), (0.3, 4.6), (-0.2, 3.1), (0.9, 2.2))):
        P.add("Slide", box((0.05, 0.01, 0.6 + i * 0.1), flat("#a9cfdc"), loc=(x, -0.035, z), r=0.0, n=1))


main()
