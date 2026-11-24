import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *  # noqa


def sofa(P, w, color):
    f = fabric(color)
    P.add("Body", box((w - 1.4, 2.9, 1.0), f, loc=(0, 0, 0.85), r=0.25, n=2))
    P.add("Body", box((w - 0.2, 0.9, 1.9), f, loc=(0, 1.05, 1.9), r=0.4, n=2))
    for sx in (-1, 1):
        P.add("Body", box((0.8, 3, 1.9), f, loc=(sx * (w / 2 - 0.4), 0, 1.25), r=0.35, n=2))
    seats = max(1, round((w - 1.6) / 2.2))
    sw = (w - 1.7) / seats
    for i in range(seats):
        x = -(w - 1.7) / 2 + sw * (i + 0.5)
        P.add("Body", box((sw - 0.08, 2.0, 0.55), f, loc=(x, -0.35, 1.6), r=0.22, n=2))
    for sx in (-1, 1):
        for sy in (-1, 1):
            P.add("Body", cyl(0.12, 0.35, wood("#6e4b2c", "#3e2a18"), loc=(sx * (w / 2 - 0.3), sy * 1.2, 0.175), r2=0.09, seg=6))


@item("couch", "furniture", size=1024)
def couch(P):
    sofa(P, 7, SKY)
    P.add("Body", box((1.3, 0.5, 1.1), fabric(BUTTER), loc=(-2.1, 0.45, 2.3), rot=(-15, 0, 12), r=0.3, n=2))
    P.add("Body", tag(2.0, 1.5, -1.52))


@item("armchair", "furniture")
def armchair(P):
    sofa(P, 3.3, CORAL)


@item("coffee_table", "furniture")
def coffee_table(P):
    P.add("Body", box((4, 2.2, 0.2), oak(), loc=(0, 0, 1.3), r=0.06, n=1))
    P.add("Body", box((3.6, 1.8, 0.12), oak(), loc=(0, 0, 0.45), r=0.03, n=1))
    P.add("Body", legs4(3.9, 2.1, 1.2, oak(), t=0.18, taper=1.0))
    for i, c in enumerate(("#e53935", "#1e88e5", "#43a047")):
        P.add("Body", box((0.9, 0.65, 0.1), plain(c), loc=(-0.9, 0.2, 0.56 + i * 0.1), rot=(0, 0, i * 9), r=0.02, n=1))
    P.add("Body", cyl(0.18, 0.4, plain(WHITE), loc=(1.1, -0.2, 1.6), seg=10, r2=0.2))


@item("tv_stand", "furniture", size=1024, pivots={"DoorL": (-2.45, -0.8, 0.9), "DoorR": (2.45, -0.8, 0.9)})
def tv_stand(P):
    P.add("Body", hollow(5, 1.6, 1.8, oak()))
    P.add("Body", box((0.12, 1.4, 1.6), oak(), loc=(0, 0, 0.9), r=0.02, n=1))
    for i, c in enumerate(("#e53935", "#1e88e5", "#fdd835")):
        P.add("Body", box((0.15, 0.9, 1.1), plain(c, grime=0.15), loc=(-1.8 + i * 0.2, 0.1, 0.67), r=0.02, n=1))
    P.add("Body", box((1.2, 0.8, 0.35), plain(CHAR), loc=(1.2, 0.1, 0.3), r=0.05, n=1))
    for name, x in (("DoorL", -1.25), ("DoorR", 1.25)):
        P.add(name, box((2.4, 0.1, 1.55), wood("#c79a68", "#6e4b2c", axis="x"), loc=(x, -0.85, 0.9), r=0.03, n=1))
        P.add(name, handle(x + (0.9 if x < 0 else -0.9), 0.9, -0.9, 0.35, vertical=True))
    P.add("Body", box((1.4, 0.7, 0.12), plain(CHAR), loc=(0, 0.1, 1.86), r=0.04, n=1))
    P.add("Body", box((0.25, 0.2, 0.5), plain(CHAR), loc=(0, 0.1, 2.1), r=0.04, n=1))
    P.add("Body", box((4.4, 0.2, 2.5), plain("#26272b", grime=0.1), loc=(0, 0.1, 3.45), r=0.06, n=1))
    P.add("Screen", box((4.15, 0.02, 2.25), flat("#1b2a3a"), loc=(0, -0.005, 3.45), r=0.0, n=1))


@item("bookshelf", "furniture", size=1024)
def bookshelf(P):
    w, d, h = 3.6, 1.2, 6.2
    mat = pine()
    P.add("Body", box((w, d, 0.15), mat, loc=(0, 0, h - 0.075), r=0.03, n=1))
    for sx in (-1, 1):
        P.add("Body", box((0.15, d, h), mat, loc=(sx * (w / 2 - 0.075), 0, h / 2), r=0.03, n=1))
    P.add("Body", box((w, 0.08, h), wood("#c7a77a", "#a8875c"), loc=(0, d / 2 - 0.04, h / 2), r=0.0, n=1))
    cols = ["#e53935", "#1e88e5", "#43a047", "#fdd835", "#8e24aa", "#fb8c00", "#00897b", "#f4f2ee"]
    import random
    rnd = random.Random(4)
    for k, z in enumerate((0.0, 1.5, 3.0, 4.5)):
        P.add("Body", box((w - 0.3, d, 0.14), mat, loc=(0, 0, z + 0.07), r=0.02, n=1))
        x = -w / 2 + 0.25
        while x < w / 2 - 0.5 and z < 4.4:
            bw = rnd.uniform(0.15, 0.32)
            bh = rnd.uniform(0.8, 1.2)
            lean = 12 if rnd.random() < 0.12 else 0
            P.add("Body", box((bw, d * 0.75, bh), plain(rnd.choice(cols), grime=0.15), loc=(x + bw / 2, 0.05, z + 0.14 + bh / 2),
                              rot=(0, lean, 0), r=0.02, n=1))
            x += bw + 0.02
            if rnd.random() < 0.08:
                x += 0.5
    P.add("Body", ball(0.35, plain(CORAL), loc=(0.6, 0, 4.98), seg=10, rings=6))


@item("floor_lamp", "furniture")
def floor_lamp(P):
    P.add("Body", cyl(0.6, 0.12, metal(CHAR, rust=0.1), loc=(0, 0, 0.06), seg=6, bevel=0.03))
    P.add("Body", box((0.14, 0.14, 4.6), metal(CHAR, rust=0.1), loc=(0, 0, 2.4), r=0.03, n=1))
    P.add("Body", cyl(0.7, 1.0, cloth(CREAM, dirt=0.1), loc=(0, 0, 4.9), r2=0.45, seg=12, bevel=0.0))
    P.add("Glow", cyl(0.42, 0.04, glow("#fff1c1"), loc=(0, 0, 4.42), seg=12, bevel=0.0))
    P.add("Body", box((0.08, 0.08, 0.5), metal(CHAR, rust=0.1), loc=(0.2, 0, 4.15), r=0.02, n=1))
    P.add("Button", box((0.16, 0.16, 0.12), plain("#c9a227"), loc=(0.2, 0, 3.86), r=0.03, n=1))


main()
