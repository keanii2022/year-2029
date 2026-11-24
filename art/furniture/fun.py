"""Fun props that do something: switch on, spin, pop, ring, show channels.
Moving pieces are their own parts (see BRIEF.md "Moving parts"). What each part does in game is in MOVES.md."""
import math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *  # noqa

kit.DUST = 0.0  # fun props stay bright, they still work

RED = "#e53935"
TEAL = "#1fa79a"
CHROME = "#cfd3d8"


@item("lava_lamp", "fun")
def lava_lamp(P):
    base = metal("#b8902e", rust=0.1)
    P.add("Body", lathe([(0, 0), (0.42, 0), (0.42, 0.08), (0.24, 0.75), (0.2, 0.8), (0, 0.8)], base, seg=10))
    P.add("Body", lathe([(0, 2.15), (0.17, 2.15), (0.12, 2.5), (0, 2.5)], base, seg=10))
    P.add("Glow", lathe([(0, 0.8), (0.2, 0.8), (0.3, 1.25), (0.25, 1.8), (0.17, 2.15), (0, 2.15)], glow("#ff7043", core="#ffccbc", amount=0.5), seg=12))
    blob = plain("#ffeb3b", grime=0.0)
    for x, z, s in ((-0.08, 1.05, 0.13), (0.09, 1.45, 0.09), (-0.04, 1.85, 0.07)):
        P.add("Blob", ball((s * 1.2, s, s * 0.9), blob, loc=(x, 0, z), seg=8, rings=6))


@item("crt_tv", "fun", size=1024, pivots={"Knob": (1.45, -1.25, 1.75)})
def crt_tv(P):
    shell = plain("#7b5b3a", grime=0.3)
    P.add("Body", box((3.6, 2.6, 2.7), wood("#8a6440", "#5a3e26", axis="x", wear=0.4), loc=(0, 0.1, 1.75), r=0.18, n=2))
    P.add("Body", box((2.4, 1.2, 2.0), plain(CHAR, grime=0.3), loc=(-0.2, 1.6, 1.75), r=0.3, n=1))
    P.add("Body", box((2.6, 0.12, 2.2), plain("#2b2b2e", grime=0.2), loc=(-0.4, -1.2, 1.75), r=0.12, n=1))
    P.add("Screen", box((2.3, 0.05, 1.85), flat("#30363d"), loc=(-0.4, -1.28, 1.75), r=0.0, n=1))
    P.add("Body", box((0.75, 0.1, 2.2), plain("#c8b48a", grime=0.2), loc=(1.35, -1.2, 1.75), r=0.05, n=1))
    for z in (1.0, 1.15, 1.3):
        P.add("Body", box((0.5, 0.04, 0.05), flat(CHAR), loc=(1.35, -1.26, z), r=0.0, n=1))
    P.add("Knob", cyl(0.22, 0.12, plain(CHAR), loc=(1.35, -1.3, 1.75), rot=(90, 0, 0), seg=8, bevel=0.03))
    P.add("Knob", box((0.06, 0.03, 0.2), flat("#f4f2ee"), loc=(1.35, -1.37, 1.85), r=0.0, n=1))
    P.add("Body", cyl(0.12, 0.1, plain(CHAR), loc=(1.35, -1.28, 2.3), rot=(90, 0, 0), seg=8, bevel=0.02))
    for sx in (-1, 1):
        P.add("Body", box((0.14, 0.04, 2.2), metal(CHROME, rust=0.1), loc=(sx * 0.55, 0.3, 3.95), rot=(0, sx * 28, 0), r=0.01, n=1))
        P.add("Body", box((0.22, 0.12, 0.08), metal(CHROME, rust=0.1), loc=(sx * 1.07, 0.3, 4.92), rot=(0, sx * 28, 0), r=0.01, n=1))
    P.add("Body", box((0.7, 0.5, 0.3), plain(CHAR), loc=(0, 0.3, 3.2), r=0.1, n=1))
    for sx in (-1, 1):
        for sy in (-1, 1):
            P.add("Body", box((0.2, 0.2, 0.42), wood("#5a3e26", "#3a281a"), loc=(sx * 1.5, sy * 1.0, 0.21), r=0.04, n=1))


@item("press_button", "fun", pivots={"Button": (0, 0, 0.35)})
def press_button(P):
    P.add("Body", box((1.1, 1.1, 0.35), plain("#f4f2ee", grime=0.15), loc=(0, 0, 0.175), r=0.12, n=1))
    P.add("Body", cyl(0.45, 0.06, plain("#c0c4c8"), loc=(0, 0, 0.38), seg=16, bevel=0.0))
    P.add("Button", cyl(0.4, 0.22, plain(RED, grime=0.05), loc=(0, 0, 0.5), seg=16, r2=0.36, bevel=0.08))
    P.add("Body", words("PRESS ME", 0.13, flat("#222222"), loc=(0, -0.56, 0.18), depth=0.01))


@item("boombox", "fun", size=1024, pivots={"Flap": (0, -0.55, 0.75)})
def boombox(P):
    P.add("Body", box((3.2, 1.0, 1.8), plain("#cfd3d8", grime=0.2), loc=(0, 0, 0.9), r=0.15, n=1))
    for sx in (-1, 1):
        P.add("Body", cyl(0.62, 0.08, plain(CHAR), loc=(sx * 1.0, -0.5, 0.85), rot=(90, 0, 0), seg=16, bevel=0.02))
        P.add("Body", lathe([(0, -0.05), (0.15, -0.05), (0.5, 0.1), (0.55, 0.12), (0, 0.12)], plain("#2b2b2e"), loc=(sx * 1.0, -0.56, 0.85), rot=(-90, 0, 0), seg=16))
    P.add("Body", box((0.9, 0.06, 0.5), flat("#1d1d1f"), loc=(0, -0.5, 0.65), r=0.03, n=1))
    P.add("Flap", box((0.95, 0.08, 0.55), plain("#9aa0a6"), loc=(0, -0.55, 1.02), r=0.03, n=1))
    P.add("Flap", box((0.6, 0.02, 0.25), plain("#ef8a72"), loc=(0, -0.6, 1.02), r=0.0, n=1))
    for i in range(6):
        P.add("Glow", box((0.08, 0.04, 0.12 + (i % 3) * 0.08), glow("#7cff6b"), loc=(-0.3 + i * 0.12, -0.52, 1.5), r=0.0, n=1))
    for i in range(4):
        P.add("Button", box((0.16, 0.2, 0.08), plain(CHAR if i else RED), loc=(-0.4 + i * 0.25, 0.1, 1.84), r=0.02, n=1))
    P.add("Body", box((2.6, 0.2, 0.16), plain(CHAR), loc=(0, 0, 2.55), r=0.06, n=1))
    for sx in (-1, 1):
        P.add("Body", box((0.16, 0.2, 0.75), plain(CHAR), loc=(sx * 1.22, 0, 2.15), r=0.05, n=1))


@item("arcade_cabinet", "fun", size=1024, pivots={"Lever": (-0.6, -1.35, 3.3)})
def arcade_cabinet(P):
    side = plain("#3949ab", grime=0.25)
    outline = [(-1.55, 0), (1.6, 0), (1.6, 6.6), (0.25, 6.6), (0.25, 5.8), (-0.1, 3.7), (-1.6, 3.45), (-1.6, 3.0), (-1.55, 2.95)]
    for sx in (-1, 1):
        P.add("Body", slab(outline, 0.15, side, loc=(sx * 1.4, 0, 0), rot=(0, 0, 90)))
    body = plain("#1d1f2b", grime=0.25)
    P.add("Body", box((2.65, 2.0, 3.1), body, loc=(0, -0.5, 1.55), r=0.04, n=1))
    P.add("Body", box((2.65, 0.8, 0.7), body, loc=(0, 0.0, 3.35), r=0.04, n=1))
    P.add("Body", box((2.65, 1.2, 3.8), body, loc=(0, 1.0, 4.7), r=0.04, n=1))
    P.add("Body", box((2.65, 1.2, 0.3), plain("#26283a"), loc=(0, -0.95, 3.2), rot=(-10, 0, 0), r=0.04, n=1))
    P.add("Body", box((2.65, 0.3, 2.0), body, loc=(0, 0.3, 4.6), rot=(-15, 0, 0), r=0.04, n=1))
    P.add("Screen", box((2.0, 0.04, 1.55), flat("#141a2a"), loc=(0, 0.13, 4.6), rot=(-15, 0, 0), r=0.0, n=1))
    P.add("Body", box((2.65, 0.9, 0.8), body, loc=(0, 0.75, 6.2), r=0.04, n=1))
    P.add("Glow", box((2.4, 0.06, 0.6), glow("#ffca28", core="#fff8e1"), loc=(0, 0.28, 6.2), r=0.02, n=1))
    P.add("Body", words("ROBO RUN", 0.32, flat("#c62828"), loc=(0, 0.24, 6.2), depth=0.01))
    P.add("Lever", box((0.1, 0.1, 0.4), plain(CHAR), loc=(-0.6, -1.35, 3.5), r=0.03, n=1))
    P.add("Lever", box((0.24, 0.24, 0.24), plain(RED), loc=(-0.6, -1.35, 3.75), r=0.08, n=1))
    for i, c in enumerate(("#fdd835", "#43a047", "#1e88e5")):
        P.add("Button", cyl(0.11, 0.08, plain(c), loc=(0.2 + i * 0.32, -1.3, 3.35), rot=(-10, 0, 0), seg=10, bevel=0.02))
    P.add("Body", box((0.5, 0.06, 0.6), metal("#9aa0a6", rust=0.3), loc=(0, -1.52, 1.8), r=0.02, n=1))
    P.add("Body", box((0.16, 0.04, 0.3), flat("#111111"), loc=(0, -1.56, 1.85), r=0.0, n=1))


@item("microwave", "fun", pivots={"Door": (-0.9, -0.62, 0.55), "Spin": (-0.25, 0.0, 0.2)})
def microwave(P):
    P.add("Body", hollow(2.4, 1.3, 1.1, plain("#f4f2ee", grime=0.25), x=0, y=0.0, z0=0.0, t=0.08, r=0.05))
    P.add("Body", box((0.6, 1.2, 1.0), plain("#d6d9dd", grime=0.2), loc=(0.85, 0, 0.55), r=0.04, n=1))
    P.add("Glow", box((0.4, 0.05, 0.15), glow("#7cff6b"), loc=(0.85, -0.62, 0.85), r=0.0, n=1))
    for i in range(6):
        P.add("Button", box((0.12, 0.05, 0.1), plain("#9aa0a6"), loc=(0.75 + (i % 2) * 0.2, -0.62, 0.62 - (i // 2) * 0.16), r=0.02, n=1))
    P.add("Glow", box((0.3, 0.05, 0.04), glow("#fff8e1"), loc=(-0.25, 0.4, 1.0), r=0.0, n=1))
    P.add("Spin", cyl(0.45, 0.04, plain("#d8eef2", grime=0.05), loc=(-0.25, 0, 0.12), seg=16, bevel=0.0))
    P.add("Body", box((0.5, 0.4, 0.25), plain("#ffb74d"), loc=(-0.25, 0, 0.27), r=0.08, n=1))
    P.add("Door", box((1.75, 0.08, 1.05), plain("#f4f2ee", grime=0.25), loc=(-0.02, -0.66, 0.55), r=0.04, n=1))
    P.add("Door", box((1.3, 0.02, 0.75), flat("#232629"), loc=(-0.1, -0.71, 0.55), r=0.03, n=1))
    P.add("Door", box((0.08, 0.1, 0.8), plain(CHAR), loc=(0.72, -0.73, 0.55), r=0.03, n=1))


@item("toaster", "fun", pivots={"Lever": (0.62, 0, 0.6)})
def toaster(P):
    P.add("Body", box((1.2, 0.8, 0.85), metal(CHROME, rust=0.05), loc=(0, 0, 0.47), r=0.25, n=2))
    P.add("Body", box((1.25, 0.85, 0.08), plain(CHAR), loc=(0, 0, 0.04), r=0.04, n=1))
    for y in (-0.17, 0.17):
        P.add("Body", box((0.8, 0.12, 0.02), flat("#1d1d1f"), loc=(0, y, 0.905), r=0.0, n=1))
    P.add("Body", box((0.04, 0.12, 0.55), flat("#333333"), loc=(0.62, 0, 0.5), r=0.0, n=1))
    P.add("Lever", box((0.14, 0.2, 0.08), plain(CHAR), loc=(0.68, 0, 0.75), r=0.03, n=1))
    toast = plain("#d9a35b", grime=0.3)
    for y in (-0.17, 0.17):
        P.add("Toast", box((0.62, 0.08, 0.6), toast, loc=(0, y, 0.95), r=0.12, n=1))
        P.add("Toast", box((0.5, 0.085, 0.45), plain("#f0d29a", grime=0.1), loc=(0, y, 0.93), r=0.1, n=1))


@item("desk_lamp", "fun", pivots={"Arm": (0, 0.1, 0.25)})
def desk_lamp(P):
    c = plain("#26a69a", grime=0.2)
    P.add("Body", box((0.9, 0.9, 0.16), c, loc=(0, 0.1, 0.08), r=0.08, n=1))
    P.add("Body", box((0.25, 0.25, 0.16), plain(CHAR), loc=(0, 0.1, 0.22), r=0.04, n=1))
    P.add("Arm", box((0.34, 0.22, 0.16), plain(CHAR), loc=(0, 0.12, 0.3), r=0.03, n=1))  # square hinge block so the arm has no round end alone
    P.add("Arm", box((0.12, 0.12, 1.2), c, loc=(0, 0.25, 0.8), rot=(-14, 0, 0), r=0.04, n=1))
    P.add("Arm", box((0.2, 0.2, 0.2), plain(CHAR), loc=(0, 0.4, 1.4), r=0.04, n=1))
    P.add("Arm", box((0.12, 0.12, 1.0), c, loc=(0, 0.05, 1.6), rot=(70, 0, 0), r=0.04, n=1))
    P.add("Arm", lathe([(0, 0.0), (0.12, 0.0), (0.18, -0.15), (0.38, -0.45), (0, -0.45)], c, loc=(0, -0.45, 1.78), rot=(25, 0, 0), seg=12))
    P.add("Glow", cyl(0.3, 0.03, glow("#fff1c1"), loc=(0, -0.57, 1.37), rot=(25, 0, 0), seg=12, bevel=0.0))


@item("table_fan", "fun", pivots={"Spin": (0, -0.35, 1.9)})
def table_fan(P):
    c = plain("#9fd8c4", grime=0.2)
    P.add("Body", box((1.2, 1.0, 0.2), c, loc=(0, 0.1, 0.1), r=0.1, n=1))
    P.add("Body", box((0.2, 0.2, 1.4), c, loc=(0, 0.1, 0.9), r=0.05, n=1))
    P.add("Body", box((0.5, 0.6, 0.5), c, loc=(0, 0.1, 1.9), r=0.15, n=1))
    for i in range(12):
        a = i * 30
        P.add("Body", box((0.04, 0.04, 1.6), metal("#c9ccd1", rust=0.1), loc=(0, -0.4, 1.9), rot=(0, a, 0), r=0.0, n=1))
    P.add("Body", cyl(0.82, 0.05, metal("#c9ccd1", rust=0.1), loc=(0, -0.2, 1.9), rot=(90, 0, 0), r2=0.82, seg=6, bevel=0.0))
    P.add("Body", cyl(0.14, 0.06, plain("#9fd8c4"), loc=(0, -0.43, 1.9), rot=(90, 0, 0), seg=8, bevel=0.02))
    for i in range(4):
        P.add("Spin", slab([(0.05, -0.08), (0.65, -0.18), (0.7, 0.05), (0.05, 0.08)], 0.02, plain("#f4f2ee", grime=0.1),
                           loc=(0, -0.35, 1.9), rot=(0, i * 90, 0)))
    P.add("Spin", cyl(0.12, 0.12, plain(CHAR), loc=(0, -0.35, 1.9), rot=(90, 0, 0), seg=8, bevel=0.02))


@item("wall_clock", "fun", pivots={"Spin": (0, -0.12, 0), "Spin2": (0, -0.12, 0)})
def wall_clock(P):
    P.add("Body", cyl(1.1, 0.2, plain("#ef8a72", grime=0.2), rot=(90, 0, 0), seg=24, bevel=0.05))
    P.add("Screen", cyl(0.95, 0.02, flat("#fffdf5"), loc=(0, -0.1, 0), rot=(90, 0, 0), seg=24, bevel=0.0))
    P.add("Spin", slab([(-0.04, -0.1), (0.04, -0.1), (0.02, 0.8), (0, 0.85), (-0.02, 0.8)], 0.02, flat("#222222"), loc=(0, -0.13, 0)))
    P.add("Spin2", slab([(-0.05, -0.08), (0.05, -0.08), (0.03, 0.5), (0, 0.56), (-0.03, 0.5)], 0.02, flat("#c62828"), loc=(0, -0.15, 0), rot=(0, 120, 0)))
    P.add("Body", cyl(0.06, 0.04, plain(CHAR), loc=(0, -0.17, 0), rot=(90, 0, 0), seg=8, bevel=0.0))


@item("rotary_phone", "fun", pivots={"Spin": (0.1, -0.35, 0.55)})
def rotary_phone(P):
    c = plain("#e53935", grime=0.2)
    P.add("Body", loft([[(x * w, y * d, z) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
                        for z, w, d in ((0, 0.6, 0.55), (0.35, 0.55, 0.5), (0.6, 0.4, 0.42))], c))
    P.add("Body", box((0.9, 0.25, 0.12), c, loc=(0, 0.1, 0.66), r=0.05, n=1))
    for sx in (-1, 1):
        P.add("Body", box((0.15, 0.2, 0.12), plain(CHAR), loc=(sx * 0.4, 0.1, 0.75), r=0.03, n=1))
    P.add("Spin", cyl(0.27, 0.04, plain("#f4f2ee", grime=0.15), loc=(0.1, -0.35, 0.55), rot=(55, 0, 0), seg=16, bevel=0.0))
    for i in range(10):
        a = math.radians(30 + i * 28)
        P.add("Spin", box((0.06, 0.06, 0.03), flat(CHAR), loc=(0.1 + math.cos(a) * 0.19, -0.35 - math.sin(a) * 0.19 * math.cos(math.radians(55)),
                                                             0.55 + math.sin(a) * 0.19 * math.sin(math.radians(55))), rot=(55, 0, 0), r=0.0, n=1))
    P.add("Handset", box((1.0, 0.2, 0.14), c, loc=(0, 0.1, 0.9), r=0.06, n=1))
    for sx in (-1, 1):
        P.add("Handset", box((0.28, 0.32, 0.2), c, loc=(sx * 0.42, 0.1, 0.84), r=0.07, n=1))


@item("disco_ball", "fun", pivots={"Spin": (0, 0, 0)})
def disco_ball(P):
    P.add("Body", box((0.6, 0.6, 0.12), plain(CHAR), loc=(0, 0, 3.0), r=0.04, n=1))
    P.add("Body", box((0.08, 0.08, 1.6), metal("#9aa0a6", rust=0.1), loc=(0, 0, 2.15), r=0.0, n=1))
    P.add("Body", box((0.2, 0.2, 0.12), plain(CHAR), loc=(0, 0, 1.33), r=0.02, n=1))
    arc = [(math.sin(math.radians(a)) * 0.6, -math.cos(math.radians(a)) * 0.6) for a in range(0, 181, 20)]
    P.add("Spin", lathe(arc, metal("#e8eaed", rust=0.0), loc=(0, 0, 0.68), seg=14, smooth=0))


@item("vending_machine", "fun", size=1024, pivots={"Flap": (-0.3, -1.35, 1.3)})
def vending_machine(P):
    P.add("Body", box((3.4, 2.6, 6.6), plain("#c62828", grime=0.3), loc=(0, 0, 3.3), r=0.12, n=1))
    P.add("Body", box((2.3, 0.1, 4.2), flat("#20262b"), loc=(-0.4, -1.3, 3.9), r=0.03, n=1))
    snacks = ("#fdd835", "#43a047", "#1e88e5", "#fb8c00", "#8e24aa", "#e53935")
    for r_, z in enumerate((2.3, 3.3, 4.3, 5.3)):
        P.add("Body", box((2.1, 0.5, 0.06), metal("#9aa0a6", rust=0.2), loc=(-0.4, -1.1, z - 0.35), r=0.0, n=1))
        for k in range(4):
            P.add("Body", box((0.38, 0.12, 0.55), plain(snacks[(k + r_ * 2) % 6], grime=0.1), loc=(-1.15 + k * 0.5, -1.15, z), r=0.04, n=1))
    P.add("Body", box((2.3, 0.04, 4.2), plain("#cfe9f2", grime=0.15, vary=0.1), loc=(-0.4, -1.37, 3.9), r=0.0, n=1))
    P.add("Body", box((0.8, 0.1, 3.0), plain("#e0e0e0", grime=0.2), loc=(1.2, -1.32, 4.3), r=0.04, n=1))
    P.add("Glow", box((0.6, 0.05, 0.3), glow("#7cff6b"), loc=(1.2, -1.38, 5.4), r=0.0, n=1))
    for i in range(9):
        P.add("Button", box((0.15, 0.06, 0.15), plain(CHAR), loc=(1.0 + (i % 3) * 0.2, -1.38, 4.8 - (i // 3) * 0.22), r=0.03, n=1))
    P.add("Body", box((0.3, 0.06, 0.5), plain(CHAR), loc=(1.2, -1.38, 3.6), r=0.03, n=1))
    P.add("Body", box((2.0, 0.1, 0.9), flat("#111111"), loc=(-0.3, -1.3, 0.9), r=0.03, n=1))
    P.add("Flap", box((2.0, 0.08, 0.85), plain(CHAR, grime=0.2), loc=(-0.3, -1.38, 0.9), r=0.03, n=1))
    P.add("Glow", box((3.2, 0.06, 0.6), glow("#fff8e1"), loc=(0, -1.3, 6.25), r=0.02, n=1))
    P.add("Body", words("SNACKS", 0.4, flat("#c62828"), loc=(0, -1.34, 6.25), depth=0.01))


@item("toilet", "fun", pivots={"Lid": (0, 0.55, 1.35), "Lever": (-0.65, 0.95, 2.4)})
def toilet(P):
    w = plain("#f4f2ee", grime=0.2)
    P.add("Body", lathe([(0, 0), (0.45, 0), (0.42, 0.5), (0.6, 1.0), (0.66, 1.3), (0, 1.3)], w, loc=(0, -0.2, 0), scl=(1, 1.3, 1), seg=16))
    P.add("Body", box((1.6, 0.7, 1.4), w, loc=(0, 1.0, 2.0), r=0.12, n=1))
    P.add("Body", box((1.7, 0.8, 0.12), w, loc=(0, 1.0, 2.76), r=0.05, n=1))
    P.add("Body", box((0.8, 0.5, 0.6), w, loc=(0, 0.75, 1.1), r=0.1, n=1))
    P.add("Lid", lathe([(0, 0), (0.64, 0), (0.6, 0.08), (0, 0.08)], plain("#cfe9f2", grime=0.15), loc=(0, -0.2, 1.33), scl=(1, 1.3, 1), seg=16))
    P.add("Lever", box((0.35, 0.1, 0.1), metal(CHROME, rust=0.1), loc=(-0.6, 0.62, 2.4), r=0.03, n=1))
    P.add("Body", box((0.4, 0.4, 0.5), plain("#fffdf5", grime=0.1), loc=(0.55, 1.0, 3.05), r=0.18, n=1))


@item("jack_in_the_box", "fun", pivots={"Lid": (0, 0.5, 1.0), "Crank": (0.5, 0, 0.5), "Jack": (0, 0, 0.6)})
def jack_in_the_box(P):
    for i, c in enumerate(("#e53935", "#fdd835")):
        P.add("Body", box((1.0, 1.0, 0.5), plain(c, grime=0.2), loc=(0, 0, 0.25 + i * 0.5), r=0.05, n=1))
    P.add("Body", box((0.6, 0.02, 0.6), plain("#1e88e5"), loc=(0, -0.51, 0.5), rot=(0, 45, 0), r=0.0, n=1))
    P.add("Lid", box((1.05, 1.05, 0.12), plain("#43a047", grime=0.2), loc=(0, 0, 1.06), r=0.04, n=1))
    P.add("Crank", box((0.1, 0.1, 0.1), plain(CHAR), loc=(0.55, 0, 0.5), r=0.02, n=1))
    P.add("Crank", box((0.08, 0.08, 0.4), metal("#b8902e", rust=0.1), loc=(0.62, 0, 0.35), r=0.02, n=1))
    P.add("Crank", box((0.25, 0.14, 0.14), plain(RED), loc=(0.72, 0, 0.18), r=0.05, n=1))
    for i in range(5):
        P.add("Jack", box((0.5 - (i % 2) * 0.12, 0.5 - (i % 2) * 0.12, 0.1), plain("#f4f2ee" if i % 2 else "#e53935"), loc=(0, 0, 0.62 + i * 0.1), rot=(0, 0, 45 * (i % 2)), r=0.02, n=1))
    P.add("Jack", box((0.6, 0.55, 0.55), plain("#f4f2ee", grime=0.1), loc=(0, 0, 1.4), r=0.12, n=1))
    P.add("Jack", box((0.4, 0.02, 0.08), flat("#c62828"), loc=(0, -0.28, 1.28), r=0.0, n=1))
    for sx in (-1, 1):
        P.add("Jack", box((0.1, 0.02, 0.1), flat("#222222"), loc=(sx * 0.13, -0.28, 1.5), r=0.0, n=1))
    P.add("Jack", slab([(-0.3, 0), (0.3, 0), (0, 0.45)], 0.5, plain("#8e24aa"), loc=(0, 0, 1.67)))


@item("rubber_duck", "fun")
def rubber_duck(P):
    y = plain("#fdd835", grime=0.1)
    P.add("Body", ball((0.45, 0.35, 0.28), y, loc=(0.05, 0, 0.26), seg=12, rings=8))
    P.add("Body", ball(0.22, y, loc=(-0.25, 0, 0.62), seg=12, rings=8))
    P.add("Body", box((0.2, 0.14, 0.08), plain("#fb8c00"), loc=(-0.48, 0, 0.58), r=0.04, n=1))
    for sy in (-1, 1):
        P.add("Body", box((0.05, 0.02, 0.06), flat("#222222"), loc=(-0.33, sy * 0.19, 0.7), r=0.0, n=1))


@item("neon_open_sign", "fun")
def neon_open_sign(P):
    P.add("Body", box((3.0, 0.15, 1.3), plain("#1d1d1f", grime=0.2), loc=(0, 0, 0.65), r=0.08, n=1))
    P.add("Glow", words("OPEN", 0.75, glow("#ff4081", core="#ffd1e3"), loc=(0, -0.12, 0.65), depth=0.06))
    for z in (0.12, 1.18):
        P.add("Glow", box((2.8, 0.06, 0.06), glow("#40c4ff", core="#d6f3ff"), loc=(0, -0.1, z), r=0.02, n=1))
    for x in (-1.4, 1.4):
        P.add("Glow", box((0.06, 0.06, 1.06), glow("#40c4ff", core="#d6f3ff"), loc=(x, -0.1, 0.65), r=0.02, n=1))


@item("record_player", "fun", pivots={"Spin": (-0.2, 0, 0.42), "Arm": (0.75, 0.55, 0.45), "Lid": (0, 0.85, 0.42)})
def record_player(P):
    P.add("Body", box((2.2, 1.8, 0.4), wood("#8a6440", "#5a3e26", axis="x"), loc=(0, 0, 0.2), r=0.06, n=1))
    P.add("Body", cyl(0.75, 0.04, plain(CHAR), loc=(-0.2, 0, 0.42), seg=20, bevel=0.0))
    P.add("Spin", cyl(0.7, 0.03, flat("#151515"), loc=(-0.2, 0, 0.455), seg=20, bevel=0.0))
    P.add("Spin", cyl(0.22, 0.032, plain("#ef8a72"), loc=(-0.2, 0, 0.46), seg=12, bevel=0.0))
    P.add("Arm", box((0.18, 0.18, 0.12), metal(CHROME, rust=0.1), loc=(0.75, 0.55, 0.47), r=0.03, n=1))
    P.add("Arm", box((0.06, 1.0, 0.05), metal(CHROME, rust=0.1), loc=(0.68, 0.1, 0.55), rot=(0, 0, -15), r=0.0, n=1))
    P.add("Arm", box((0.12, 0.18, 0.06), plain(CHAR), loc=(0.55, -0.4, 0.53), rot=(0, 0, -15), r=0.02, n=1))
    for x in (0.7, 0.9):
        P.add("Body", cyl(0.08, 0.06, plain("#c0c4c8"), loc=(x, -0.65, 0.42), seg=8, bevel=0.01))
    P.add("Lid", box((2.2, 1.8, 0.04), plain("#e0f2f7", grime=0.1, vary=0.05), loc=(0, 0, 0.9), r=0.02, n=1))
    for sx in (-1, 1):
        P.add("Lid", box((0.04, 1.8, 0.48), plain("#e0f2f7", grime=0.1, vary=0.05), loc=(sx * 1.08, 0, 0.66), r=0.0, n=1))
    P.add("Lid", box((2.2, 0.04, 0.48), plain("#e0f2f7", grime=0.1, vary=0.05), loc=(0, -0.88, 0.66), r=0.0, n=1))


@item("music_box", "fun", pivots={"Lid": (0, 0.4, 0.5), "Spin": (0, -0.05, 0.5)})
def music_box(P):
    P.add("Body", hollow(1.1, 0.8, 0.5, wood("#f2b8c6", "#d98ca0", axis="x", wear=0.2), open_side="top", t=0.06, r=0.02))
    P.add("Body", box((1.0, 0.7, 0.04), cloth("#8e24aa", dirt=0.05, weave=40), loc=(0, 0, 0.3), r=0.0, n=1))
    P.add("Body", words("29", 0.15, flat("#fff59d"), loc=(0, -0.41, 0.25), depth=0.005))
    P.add("Lid", box((1.14, 0.84, 0.08), wood("#f2b8c6", "#d98ca0", axis="x", wear=0.2), loc=(0, 0, 0.54), r=0.03, n=1))
    P.add("Lid", box((0.9, 0.02, 0.4), plain("#cfd8dc", grime=0.0), loc=(0, 0.42, 0.78), r=0.0, n=1))
    P.add("Spin", cyl(0.1, 0.08, plain("#fff59d"), loc=(0, -0.05, 0.36), seg=10, bevel=0.01))
    P.add("Spin", box((0.14, 0.1, 0.22), plain("#f4f2ee"), loc=(0, -0.05, 0.52), r=0.03, n=1))
    P.add("Spin", box((0.12, 0.1, 0.1), plain("#f4f2ee"), loc=(0, -0.05, 0.69), r=0.03, n=1))
    P.add("Spin", slab([(-0.18, 0), (0.18, 0), (0, 0.08)], 0.06, plain("#ff8a80"), loc=(0, -0.05, 0.42)))
    P.add("Spin", box((0.04, 0.04, 0.02), glow("#40c4ff"), loc=(0, -0.11, 0.7), r=0.0, n=1))


@item("poster_frame", "fun")
def poster_frame(P):
    w, h = 3.0, 4.5
    frame = plain("#2b2b2e", grime=0.2)
    P.add("Body", box((w, 0.12, h), frame, loc=(0, 0, h / 2), r=0.03, n=1))
    P.add("Screen", box((w - 0.24, 0.02, h - 0.24), flat("#ffffff"), loc=(0, -0.07, h / 2), r=0.0, n=1))


# Real life sizes (1 stud is about 0.3 m) so they feel right in the hand when grabbed and turned.
@item("spray_can", "fun", pivots={"Button": (0, 0, 0.61)})
def spray_can(P):
    paint = plain(PAINT, grime=0.25)
    # stepped rim, flat cone shoulder and a collar, like a real can: a smooth round top alone reads badly in moderation
    P.add("Body", lathe([(0, 0.01), (0.1, 0.01), (0.1, 0), (0.112, 0.012), (0.112, 0.03), (0.108, 0.035), (0.108, 0.49), (0.114, 0.5), (0.114, 0.515),
                         (0.1, 0.52), (0.066, 0.575), (0.066, 0.585), (0.05, 0.585), (0.05, 0.61), (0, 0.61)],
                        metal("#2b2b2e", rust=0.15), seg=16, smooth=20))
    P.add("Body", lathe([(0, 0.12), (0.113, 0.12), (0.113, 0.42), (0, 0.42)], paint, seg=16))
    for x, ln in ((-0.05, 0.06), (0.02, 0.09), (0.06, 0.04)):
        P.add("Body", box((0.014, 0.008, ln), paint, loc=(x, -0.109, 0.12 - ln / 2), r=0.0, n=1))
    P.add("Button", box((0.075, 0.065, 0.05), plain(PAINT, grime=0.4), loc=(0, 0, 0.635), r=0.008, n=1))
    P.add("Button", box((0.03, 0.006, 0.02), flat("#1d1d1f"), loc=(0, -0.034, 0.64), r=0.0, n=1))


@item("walkie_talkie", "fun", pivots={"Knob": (-0.06, 0, 0.5), "Button": (-0.11, 0, 0.33)})
def walkie_talkie(P):
    shell = plain("#f2c94c", grime=0.35)
    P.add("Body", box((0.22, 0.13, 0.5), shell, loc=(0, 0, 0.25), r=0.04, n=1))
    P.add("Body", box((0.235, 0.14, 0.18), plain(CHAR, grime=0.3), loc=(0, 0, 0.1), r=0.04, n=1))
    for i in range(4):
        P.add("Body", box((0.14, 0.006, 0.014), flat(CHAR), loc=(0, -0.066, 0.3 + i * 0.03), r=0.0, n=1))
    P.add("Body", box((0.12, 0.006, 0.06), flat("#9ccc65"), loc=(0, -0.066, 0.215), r=0.0, n=1))
    P.add("Body", box((0.05, 0.05, 0.27), plain(CHAR, grime=0.3), loc=(0.06, 0.02, 0.635), r=0.015, n=1))
    P.add("Body", box((0.065, 0.065, 0.03), plain(CHAR, grime=0.3), loc=(0.06, 0.02, 0.765), r=0.01, n=1))
    P.add("Knob", cyl(0.032, 0.05, plain("#3a3c42"), loc=(-0.06, 0, 0.525), seg=10, bevel=0.005))
    P.add("Button", box((0.02, 0.06, 0.12), plain(CHAR), loc=(-0.12, 0, 0.33), r=0.008, n=1))
    P.add("Glow", box((0.025, 0.006, 0.025), glow("#ff3b30"), loc=(0.07, -0.066, 0.455), r=0.0, n=1))


@item("baby_monitor_cam", "fun", pivots={"Spin": (0, 0, 0.18), "Glow": (0, 0, 0.18)})
def baby_monitor_cam(P):
    w = plain(WHITE, grime=0.35)
    P.add("Body", box((0.4, 0.32, 0.06), w, loc=(0, 0, 0.03), r=0.025, n=1))
    P.add("Body", box((0.1, 0.1, 0.13), plain(GREY), loc=(0, 0, 0.12), r=0.02, n=1))
    P.add("Spin", box((0.36, 0.3, 0.3), w, loc=(0, 0, 0.33), r=0.09, n=2))
    P.add("Spin", box((0.27, 0.012, 0.2), flat("#22252b"), loc=(0, -0.152, 0.33), r=0.0, n=1))
    P.add("Spin", cyl(0.065, 0.04, plain("#101216", grime=0.0), loc=(0, -0.165, 0.33), rot=(90, 0, 0), seg=14, bevel=0.01))
    P.add("Spin", cyl(0.035, 0.012, flat("#3a5a7a"), loc=(0, -0.187, 0.33), rot=(90, 0, 0), seg=12, bevel=0.0))
    P.add("Glow", box((0.022, 0.008, 0.022), glow("#ff3b30"), loc=(0.1, -0.16, 0.41), r=0.0, n=1))


@item("baby_monitor_screen", "fun")
def baby_monitor_screen(P):
    w = plain(WHITE, grime=0.35)
    P.add("Body", box((0.42, 0.12, 0.52), w, loc=(0, 0, 0.3), r=0.05, n=1))
    P.add("Body", box((0.36, 0.22, 0.04), plain(GREY), loc=(0, 0.02, 0.02), r=0.015, n=1))
    P.add("Body", box((0.06, 0.05, 0.12), plain(GREY), loc=(0.15, 0.02, 0.6), r=0.015, n=1))
    P.add("Body", box((0.37, 0.01, 0.29), flat("#22252b"), loc=(0, -0.062, 0.38), r=0.0, n=1))
    P.add("Screen", box((0.34, 0.01, 0.26), flat("#30363d"), loc=(0, -0.066, 0.38), r=0.0, n=1))
    for i in range(5):
        h = 0.02 + i * 0.01
        P.add("Glow", box((0.035, 0.008, h), glow("#7cff6b"), loc=(-0.1 + i * 0.05, -0.064, 0.11 + h / 2), r=0.0, n=1))
    P.add("Button", box((0.04, 0.012, 0.03), plain(CHAR), loc=(0.15, -0.064, 0.13), r=0.008, n=1))


@item("crank_radio", "fun", pivots={"Crank": (0.365, 0, 0.2), "Knob": (0.14, -0.15, 0.12)})
def crank_radio(P):
    P.add("Body", box((0.62, 0.27, 0.38), plain("#e8662c", grime=0.4), loc=(0, 0, 0.19), r=0.04, n=1))
    for sx in (-1, 1):
        P.add("Body", box((0.07, 0.29, 0.4), plain(CHAR, grime=0.3), loc=(sx * 0.31, 0, 0.2), r=0.035, n=1))
        P.add("Body", box((0.04, 0.05, 0.1), plain(CHAR), loc=(sx * 0.22, 0, 0.43), r=0.012, n=1))
    P.add("Body", box((0.48, 0.05, 0.04), plain(CHAR), loc=(0, 0, 0.48), r=0.015, n=1))
    for i in range(5):
        P.add("Body", box((0.2, 0.006, 0.016), flat(CHAR), loc=(-0.12, -0.137, 0.1 + i * 0.045), r=0.0, n=1))
    P.add("Body", box((0.34, 0.17, 0.012), flat("#1f2a44"), loc=(0.02, 0, 0.386), r=0.0, n=1))
    for x in (-0.06, 0.02, 0.1):
        P.add("Body", box((0.006, 0.17, 0.004), flat("#8a94a6"), loc=(x, 0, 0.393), r=0.0, n=1))
    P.add("Body", box((0.24, 0.008, 0.1), flat("#22252b"), loc=(0.14, -0.137, 0.26), r=0.0, n=1))
    P.add("Glow", box((0.21, 0.008, 0.07), glow("#ffb74d"), loc=(0.14, -0.141, 0.26), r=0.0, n=1))
    P.add("Glow", box((0.02, 0.008, 0.02), glow("#ff3b30"), loc=(0.0, -0.139, 0.33), r=0.0, n=1))
    P.add("Knob", cyl(0.05, 0.04, plain("#3a3c42"), loc=(0.14, -0.15, 0.12), rot=(90, 0, 0), seg=10, bevel=0.006))
    P.add("Crank", box((0.03, 0.08, 0.08), plain(CHAR), loc=(0.36, 0, 0.2), r=0.01, n=1))
    P.add("Crank", box((0.03, 0.05, 0.2), plain(GREY), loc=(0.375, 0, 0.12), r=0.01, n=1))
    P.add("Crank", box((0.08, 0.05, 0.05), plain(CHAR), loc=(0.41, 0, 0.04), r=0.012, n=1))


main()
