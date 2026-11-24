import os, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "_kit"))
from ykit import *  # noqa

LAB_WHITE = "#eceae4"
LAB_GREY = "#8d9096"
ORANGE = "#f28c28"
TEAL = "#1fa79a"
CHAR = "#3b3e45"


def stripes(w, h, loc, n=6, rot=(0, 0, 0)):
    """Hazard stripes as a band of slanted tiles on a dark strip, facing -y."""
    out = [box((w, 0.04, h), flat("#1d1d1f"), loc=loc, rot=rot, r=0.0, n=1)]
    step = w / n
    for i in range(n):
        x = loc[0] - w / 2 + step * (i + 0.5)
        out.append(box((step * 0.5, 0.05, h * 1.0), flat("#f6c026"), loc=(x, loc[1] - 0.01, loc[2]), rot=(0, 35, 0), r=0.0, n=1))
    return out


@item("pillar_base", "lab", size=1024)
def pillar_base(P):
    P.add("Body", box((10, 10, 3), paint(LAB_GREY, chip=0.15, grime=0.3), loc=(0, 0, 1.5), r=0.2, n=1))
    P.add("Body", box((8, 8, 37), paint(LAB_WHITE, chip=0.08, grime=0.35, streaks=0.5), loc=(0, 0, 21.5), r=0.15, n=1))
    P.add("Body", stripes(8, 0.8, (0, -4.03, 3.6), n=8))
    P.add("Body", box((3.2, 0.1, 3.2), plain(TEAL, grime=0.1), loc=(0, -4.05, 12), r=0.1, n=1))
    P.add("Body", words("A17", 1.6, flat("#ffffff"), loc=(0, -4.12, 12), depth=0.02))


@item("pillar_segment", "lab", size=1024)
def pillar_segment(P):
    P.add("Body", box((8, 8, 40), paint(LAB_WHITE, chip=0.06, grime=0.3, streaks=0.6), loc=(0, 0, 20), r=0.15, n=1))
    for z in (0.3, 39.7):
        P.add("Body", box((8.3, 8.3, 0.6), paint(LAB_GREY, chip=0.1, grime=0.2), loc=(0, 0, z), r=0.1, n=1))


@item("aisle_sign", "lab", size=512)
def aisle_sign(P):
    P.add("Body", box((5, 0.5, 2.4), plain(TEAL, grime=0.15), loc=(0, 0, 0), r=0.15, n=1))
    P.add("Body", box((4.6, 0.52, 2.0), plain("#f7f5ef", grime=0.15), loc=(0, 0, 0), r=0.1, n=1))
    P.add("Body", words("417", 1.3, flat("#1b1d22"), loc=(0, -0.28, -0.05), depth=0.02))
    for x in (-1.8, 1.8):
        P.add("Body", box((0.12, 0.12, 6), metal(LAB_GREY, rust=0.2), loc=(x, 0, 4.2), r=0.03, n=1))


@item("ceiling_light", "lab", size=512)
def ceiling_light(P):
    P.add("Body", box((10, 2.4, 0.6), metal("#d8d8d4", rust=0.1), loc=(0, 0, 0.3), r=0.12, n=1))
    P.add("Glow", box((9.4, 1.9, 0.06), glow("#fff8e7", core="#ffffff", amount=0.1), loc=(0, 0, -0.01), r=0.0, n=1))
    for x in (-4.5, 4.5):
        P.add("Body", box((0.1, 0.1, 4), metal(LAB_GREY, rust=0.2), loc=(x, 0, 2.6), r=0.03, n=1))


@item("emergency_light", "lab", size=512)
def emergency_light(P):
    P.add("Body", box((1.6, 0.6, 0.9), plain(LAB_WHITE, grime=0.25), loc=(0, 0, 0.45), r=0.1, n=1))
    for x in (-0.45, 0.45):
        P.add("Glow", cyl(0.3, 0.35, glow("#ff3b30", core="#ffb3ad"), loc=(x, -0.4, 0.5), rot=(90, 0, 0), r2=0.22, seg=10))
    P.add("Body", box((0.5, 0.02, 0.18), glow("#43a047"), loc=(0, -0.31, 0.15), r=0.0, n=1))


@item("speaker_horn", "lab", size=512)
def speaker_horn(P):
    P.add("Body", box((0.8, 0.8, 0.8), plain(CHAR), loc=(0, 0.4, 0), r=0.1, n=1))
    P.add("Body", cyl(0.35, 2.0, plain("#f2f0ea", grime=0.3), loc=(0, -0.9, 0), rot=(90, 0, 0), r2=0.85, seg=14, bevel=0.03))
    P.add("Body", box((0.3, 0.3, 1.6), metal(LAB_GREY, rust=0.3), loc=(0, 0.4, 1.1), r=0.05, n=1))
    P.add("Body", box((1.2, 1.2, 0.2), metal(LAB_GREY, rust=0.3), loc=(0, 0.4, 1.9), r=0.05, n=1))


@item("siren_light", "lab", size=512, pivots={"Spin": (0, 0, 0.95)})
def siren_light(P):
    P.add("Body", box((1.2, 1.2, 0.5), plain(CHAR), loc=(0, 0, 0.25), r=0.08, n=1))
    P.add("Glow", cyl(0.5, 0.9, glow("#ff9100", core="#ffe0b2"), loc=(0, 0, 0.95), r2=0.42, seg=10, bevel=0.05))
    P.add("Body", box((1.06, 1.06, 0.12), plain(CHAR), loc=(0, 0, 1.45), r=0.05, n=1))
    for a in (0, 90, 180, 270):
        P.add("Body", box((0.08, 1.1, 0.9), plain(CHAR), loc=(0, 0, 0.95), rot=(0, 0, a + 45), r=0.02, n=1))
    P.add("Spin", box((0.5, 0.06, 0.6), metal("#e0e0e0", rust=0.0), loc=(0, 0.12, 0.95), r=0.02, n=1))
    P.add("Spin", box((0.12, 0.12, 0.7), plain(CHAR), loc=(0, 0, 0.95), r=0.03, n=1))


@item("entrance_gate", "lab", size=1024)
def entrance_gate(P):
    frame = paint(LAB_GREY, chip=0.2, grime=0.4)
    for sx in (-1, 1):
        P.add("Body", box((3, 3, 16), frame, loc=(sx * 11.5, 0, 8), r=0.2, n=1))
        P.add("Body", stripes(3, 1, (sx * 11.5, -1.52, 1.2), n=4))
    P.add("Body", box((26, 3, 3), frame, loc=(0, 0, 17.5), r=0.2, n=1))
    P.add("Body", box((16, 0.3, 2.2), plain(LAB_WHITE, grime=0.2), loc=(0, -1.6, 17.5), r=0.1, n=1))
    P.add("Body", words("WELCOME", 1.3, flat(TEAL), loc=(0, -1.78, 17.5), depth=0.03))
    for i in range(10):
        x = -9 + i * 2
        P.add("Slide", box((0.5, 0.5, 15.8), metal("#b7bac0", rust=0.3), loc=(x, 0, 8.1), r=0.06, n=1))
    for z in (4, 10, 15):
        P.add("Slide", box((20, 0.4, 0.5), metal("#b7bac0", rust=0.3), loc=(0, 0, z), r=0.06, n=1))
    paint_red = plain("#e8361c", grime=0.25, vary=0.25)
    P.add("Slide", words("GO BACK", 2.2, paint_red, loc=(0, -0.32, 12.2), rot=(0, -3, 0), depth=0.04))
    for x, ln in ((-5.2, 2.4), (-1.9, 1.3), (1.4, 3.1), (4.6, 1.8)):
        P.add("Slide", box((0.16, 0.03, ln), paint_red, loc=(x, -0.3, 11.4 - ln / 2), r=0.0, n=1))
    for sx in (-1, 1):
        P.add("Body", box((1.2, 0.5, 1.2), plain(CHAR), loc=(sx * 11.5, -1.7, 14), r=0.08, n=1))
        P.add("Glow", box((0.9, 0.1, 0.9), glow(ORANGE), loc=(sx * 11.5, -1.97, 14), r=0.05, n=1))


@item("charging_dock", "lab", size=512)
def charging_dock(P):
    P.add("Body", box((3.6, 3.6, 0.5), plain(CHAR, grime=0.3), loc=(0, 0, 0.25), r=0.15, n=1))
    P.add("Glow", box((3.0, 3.0, 0.06), glow(TEAL, core="#b2f5ea", amount=0.2), loc=(0, 0, 0.52), r=0.0, n=1))
    P.add("Body", box((3.6, 0.8, 6.5), plain(LAB_WHITE, grime=0.3), loc=(0, 1.6, 3.5), r=0.2, n=1))
    P.add("Glow", box((2.2, 0.06, 0.4), glow(TEAL), loc=(0, 1.18, 5.6), r=0.02, n=1))
    P.add("Body", box((1.6, 0.4, 1.2), plain(CHAR), loc=(0, 1.0, 4.4), r=0.1, n=1))
    for x in (-0.4, 0.0, 0.4):
        P.add("Body", box((0.18, 0.05, 0.6), glow("#7cff6b"), loc=(x, 0.78, 4.4), r=0.0, n=1))
    P.add("Body", stripes(3.6, 0.5, (0, -1.83, 0.25), n=6))


@item("arm_bench", "lab", size=1024, pivots={"Arm": (1.2, 0.4, 3.4)})
def arm_bench(P):
    top = plain(LAB_WHITE, grime=0.25)
    P.add("Body", box((5, 3, 0.3), top, loc=(0, 0, 2.85), r=0.08, n=1))
    for sx in (-1, 1):
        for sy in (-1, 1):
            P.add("Body", box((0.3, 0.3, 2.7), metal(LAB_GREY, rust=0.15), loc=(sx * 2.2, sy * 1.2, 1.35), r=0.05, n=1))
    P.add("Body", box((4.6, 2.6, 0.15), metal(LAB_GREY, rust=0.15), loc=(0, 0, 0.6), r=0.04, n=1))
    arm = plain("#f28c28", grime=0.25)
    P.add("Body", cyl(0.7, 0.4, plain(CHAR), loc=(1.2, 0.4, 3.2), seg=8))
    P.add("Arm", box((0.6, 0.6, 2.0), arm, loc=(1.2, 0.4, 4.3), r=0.15, n=1))
    P.add("Arm", box((0.75, 0.75, 0.75), plain(CHAR), loc=(1.2, 0.4, 5.35), r=0.1, n=1))
    P.add("Arm", box((2.2, 0.5, 0.5), arm, loc=(0.2, 0.4, 5.35), rot=(0, 25, 0), r=0.12, n=1))
    P.add("Arm", box((0.6, 0.6, 0.6), plain(CHAR), loc=(-0.8, 0.4, 4.85), r=0.1, n=1))
    for x in (-1.0, -0.6):
        P.add("Arm", box((0.15, 0.4, 0.6), metal("#cfd2d6", rust=0.1), loc=(x, 0.4, 4.3), r=0.04, n=1))
    P.add("Body", box((1.2, 0.8, 0.5), cardboard(), loc=(-1.0, -0.6, 3.25), r=0.03, n=1))
    P.add("Body", box((1.4, 0.1, 1.0), plain(CHAR), loc=(1.6, -1.1, 3.6), rot=(-15, 0, 0), r=0.04, n=1))
    P.add("Body", box((1.25, 0.02, 0.85), glow(TEAL, amount=0.2), loc=(1.6, -1.16, 3.6), rot=(-15, 0, 0), r=0.0, n=1))
    P.add("Body", words("REC", 0.3, flat("#ff3b30"), loc=(1.6, -1.18, 3.65), rot=(-15, 0, 0), depth=0.005))


main()
