import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *  # noqa


def mattress(P, w, l, z, blanket):
    P.add("Body", box((w, l, 0.7), fabric(WHITE), loc=(0, 0, z + 0.35), r=0.2, n=2))
    P.add("Body", box((w + 0.06, l * 0.62, 0.22), fabric(blanket), loc=(0, -l * 0.19, z + 0.68), r=0.1, n=2))
    P.add("Body", box((w * 0.7, 1.0, 0.35), fabric(CREAM), loc=(0, l / 2 - 0.75, z + 0.85), rot=(-8, 0, 0), r=0.17, n=2))


@item("bed", "furniture", size=1024)
def bed(P):
    w, l = 4.5, 7
    P.add("Body", box((w + 0.2, l, 0.9), pine(), loc=(0, 0, 0.75), r=0.06, n=1))
    P.add("Body", legs4(w + 0.1, l - 0.1, 0.4, pine(), t=0.22, taper=1.0))
    P.add("Body", box((w + 0.3, 0.3, 3.4), pine(), loc=(0, l / 2 + 0.05, 1.7), r=0.12, n=1))
    P.add("Body", box((w - 0.4, 0.06, 1.6), fabric(MINT), loc=(0, l / 2 - 0.12, 2.3), r=0.1, n=1))
    mattress(P, w - 0.1, l - 0.3, 1.2, MINT)
    P.add("Body", tag(-1.6, 0.85, -l / 2 - 0.02))


@item("bunk_bed", "furniture", size=1024)
def bunk_bed(P):
    w, l = 3.6, 7
    mat = wood(WHITE, "#d8d2c6", axis="z", wear=0.3)
    for sx in (-1, 1):
        for sy in (-1, 1):
            P.add("Body", box((0.3, 0.3, 6.2), mat, loc=(sx * (w / 2), sy * (l / 2), 3.1), r=0.06, n=1))
    for z in (0.9, 3.9):
        P.add("Body", box((w, l, 0.3), mat, loc=(0, 0, z), r=0.05, n=1))
        mattress(P, w - 0.4, l - 0.4, z + 0.15, SKY if z < 2 else CORAL)
    for sy in (-1, 1):
        P.add("Body", box((w, 0.2, 0.4), mat, loc=(0, sy * l / 2, 5.6), r=0.05, n=1))
    P.add("Body", box((0.2, l * 0.6, 0.4), mat, loc=(-w / 2, 0.6, 5.1), r=0.05, n=1))
    for z in (1.5, 2.3, 3.1, 3.9, 4.7):
        P.add("Body", box((0.16, 1.0, 0.14), mat, loc=(-w / 2 - 0.05, -l / 2 + 1.0, z), r=0.04, n=1))
    for y in (-l / 2 + 0.5, -l / 2 + 1.5):
        P.add("Body", box((0.18, 0.18, 4.8), mat, loc=(-w / 2 - 0.05, y, 3.0), r=0.05, n=1))


@item("wardrobe", "furniture", size=1024, pivots={"DoorL": (-2.0, -1.0, 3.25), "DoorR": (2.0, -1.0, 3.25)})
def wardrobe(P):
    P.add("Body", hollow(4, 2, 6.5, enamel(SKY)))
    P.add("Body", box((3.7, 0.1, 0.1), metal("#c9c6c0", rust=0.1), loc=(0, 0.1, 5.6), r=0.03, n=1))
    for i, c in enumerate((CORAL, MINT, BUTTER, WHITE)):
        x = -1.2 + i * 0.7
        P.add("Body", box((0.6, 0.12, 0.08), plain(CHAR), loc=(x, 0.1, 5.45), r=0.02, n=1))
        P.add("Body", box((0.62, 0.3, 2.2), fabric(c), loc=(x, 0.1, 4.25), r=0.08, n=2))
    P.add("Body", box((1.0, 0.6, 0.5), plain("#8d6e63", grime=0.2), loc=(1.0, 0.2, 0.37), r=0.08, n=1))
    P.add("Body", box((4.2, 2.2, 0.25), enamel("#7ab2d8"), loc=(0, 0, 6.55), r=0.05, n=1))
    for name, sx in (("DoorL", -1), ("DoorR", 1)):
        P.add(name, box((1.96, 0.12, 6.0), enamel("#9dcdee"), loc=(sx * 0.99, -1.02, 3.3), r=0.06, n=1))
        P.add(name, door_lines(sx * 0.99, 4.7, 1.5, 2.0, -1.08, enamel(SKY)))
        P.add(name, door_lines(sx * 0.99, 2.0, 1.5, 2.8, -1.08, enamel(SKY)))
        P.add(name, handle(sx * 0.2, 3.4, -1.1, 0.8, vertical=True))
    P.add("Body", tag(1.2, 6.0, -1.12))


@item("dresser", "furniture", size=1024)
def dresser(P):
    P.add("Body", box((3.6, 1.6, 3), pine(), loc=(0, 0, 1.6), r=0.06, n=1))
    P.add("Body", legs4(3.4, 1.4, 0.2, pine(), t=0.2, taper=1.0))
    for i, z in enumerate((0.75, 1.65, 2.55)):
        P.add(f"Drawer{i + 1}", drawer(0, z, 3.3, 0.8, -0.78, 1.3, enamel(CORAL)))
    P.add("Body", box((0.9, 0.6, 0.06), cloth(MINT, dirt=0.1), loc=(-0.8, 0, 3.13), r=0.0, n=1))
    P.add("Body", box((0.5, 0.35, 0.7), plain(BUTTER), loc=(1.0, 0.1, 3.45), r=0.08, n=1))


@item("nightstand", "furniture")
def nightstand(P):
    P.add("Body", box((1.6, 1.4, 1.8), pine(), loc=(0, 0, 1.1), r=0.06, n=1))
    P.add("Body", legs4(1.4, 1.2, 0.2, pine(), t=0.16, taper=1.0))
    P.add("Drawer1", drawer(0, 1.5, 1.35, 0.6, -0.68, 1.1, enamel(MINT)))
    P.add("Body", box((0.8, 0.45, 0.4), plain(CHAR), loc=(0.2, 0, 2.2), r=0.08, n=1))
    P.add("Glow", box((0.6, 0.02, 0.22), glow("#ff6e40", core="#ffab91"), loc=(0.2, -0.23, 2.22), r=0.0, n=1))


main()
