import math, os, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "_kit"))
from ykit import *  # noqa

# Small life in the warehouse. Facing -y, the animal's own left is +x. Moving parts have origins at their joints
# and _kit/animate.py knows them by part name (WingL, WingR, Tail, Head).


@item("pigeon", "critters", pivots={"Head": (0, -0.24, 0.62), "WingL": (0.16, -0.12, 0.58), "WingR": (-0.16, -0.12, 0.58), "Tail": (0, 0.36, 0.44)})
def pigeon(P):
    grey = plain("#7f838c", grime=0.35, vary=0.3)
    pale = plain("#a3a7ae", grime=0.3)
    dark = plain("#4a4d55", grime=0.3)
    neck = fade("#5d7a62", "#6c5a7e", lo=0.3, hi=0.7, grime=0.1)  # the green to purple sheen
    pink = plain("#b9707a", grime=0.4)
    P.add("Body", ball((0.2, 0.36, 0.22), grey, (0, 0.06, 0.42), (-12, 0, 0), seg=14, rings=9))
    P.add("Body", ball((0.18, 0.2, 0.2), pale, (0, -0.16, 0.44), seg=12, rings=8))
    P.add("Body", ball((0.14, 0.14, 0.16), neck, (0, -0.22, 0.58), seg=12, rings=8))
    for x in (-0.07, 0.07):
        P.add("Body", tube([(x, -0.02, 0.28), (x, -0.04, 0.05)], 0.022, pink, seg=6))
        for a in (-35, 0, 35):
            d = V((math.sin(math.radians(a)), -math.cos(math.radians(a)), 0)) * 0.1
            P.add("Body", tube([(x, -0.04, 0.02), (x + d.x, -0.04 + d.y, 0.015)], 0.014, pink, seg=5))
    P.add("Head", ball(0.12, dark, (0, -0.31, 0.72), seg=12, rings=8))
    P.add("Head", cyl(0.035, 0.13, plain("#2c2a2a", grime=0.2), (0, -0.46, 0.7), (90, 0, 0), r2=0.01, seg=8, bevel=0.0))
    P.add("Head", ball((0.04, 0.04, 0.025), pale, (0, -0.41, 0.735), seg=8, rings=5))
    for x in (-0.085, 0.085):
        P.add("Head", ball(0.03, plain("#e0752a", grime=0.1), (x, -0.36, 0.75), seg=8, rings=5))
        P.add("Head", ball(0.016, flat("#0a0a0a"), (x * 1.18, -0.37, 0.755), seg=6, rings=4))
    for part, s in (("WingL", 1), ("WingR", -1)):
        P.add(part, ball((0.06, 0.34, 0.15), grey, (s * 0.19, 0.12, 0.48), (-14, s * 8, 0), seg=12, rings=8))
        for k in (0, 1):  # the two black wing bars
            P.add(part, box((0.03, 0.06, 0.15), dark, (s * 0.24, 0.12 + k * 0.12, 0.47 - k * 0.02), (-14, s * 8, 0), r=0.01, n=1))
        P.add(part, box((0.04, 0.22, 0.1), dark, (s * 0.17, 0.42, 0.4), (-18, s * 6, 0), r=0.02, n=1))
    P.add("Tail", box((0.2, 0.3, 0.035), grey, (0, 0.52, 0.38), (-18, 0, 0), r=0.015, n=1))
    P.add("Tail", box((0.21, 0.07, 0.04), dark, (0, 0.66, 0.335), (-18, 0, 0), r=0.015, n=1))


@item("rat", "critters", pivots={"Head": (0, -0.34, 0.27)})
def rat(P):
    fur = cloth("#5f5650", dirt=0.5, weave=60, dirtcolor="#2e2925")
    belly = cloth("#8a807a", dirt=0.4, weave=60)
    pink = plain("#c39a92", grime=0.45)
    P.add("Body", crumple(ball((0.22, 0.46, 0.2), fur, (0, 0.04, 0.24), seg=14, rings=9), 0.015, 8))
    P.add("Body", ball((0.16, 0.34, 0.08), belly, (0, 0.04, 0.12), seg=12, rings=6))
    for x, y in ((-0.14, -0.22), (0.14, -0.22), (-0.16, 0.28), (0.16, 0.28)):
        P.add("Body", box((0.07, 0.13, 0.05), pink, (x, y - 0.04, 0.03), r=0.02, n=1))
    P.add("Head", crumple(ball((0.13, 0.22, 0.12), fur, (0, -0.48, 0.26), (8, 0, 0), seg=12, rings=8), 0.01, 10))
    P.add("Head", ball(0.035, pink, (0, -0.69, 0.24), seg=8, rings=5))
    for x in (-0.07, 0.07):
        P.add("Head", ball(0.028, flat("#050505"), (x, -0.56, 0.32), seg=8, rings=5), ball(0.009, flat("#ffffff"), (x * 1.1, -0.585, 0.335), seg=4, rings=3))
        P.add("Head", cyl(0.075, 0.02, pink, (x * 1.5, -0.4, 0.38), (80, 0, x * 200), seg=12, bevel=0.0))
        for a in (-12, 0, 12):  # whiskers
            P.add("Head", box((0.18, 0.006, 0.006), plain("#d8d0c8"), (x * 2.2, -0.64, 0.25), (0, a, -x * 120), r=0.0, n=1))
    tail = [(0, 0.46, 0.18), (0.05, 0.75, 0.08), (-0.08, 1.05, 0.04), (0.06, 1.3, 0.03)]
    P.add("Body", tube(tail, [0.04, 0.03, 0.018, 0.008], pink, seg=6))  # part of Body: alone in grey a tail reads as a stray rod to moderation


@item("moth", "critters", pivots={"WingL": (0.03, 0.0, 0.05), "WingR": (-0.03, 0.0, 0.05)})
def moth(P):
    fuzz = cloth("#8a7a62", dirt=0.3, weave=90)
    wing = plain("#b8a888", grime=0.5, vary=0.45)
    spot = flat("#3a3026")
    P.add("Body", ball((0.04, 0.12, 0.04), fuzz, (0, 0.02, 0.05), seg=10, rings=6))
    P.add("Body", ball(0.035, fuzz, (0, -0.1, 0.055), seg=8, rings=5))
    for x in (-1, 1):
        P.add("Body", tube([(x * 0.012, -0.12, 0.07), (x * 0.05, -0.2, 0.1)], 0.005, fuzz, seg=4))
    for part, s in (("WingL", 1), ("WingR", -1)):
        P.add(part, ball((0.15, 0.1, 0.008), wing, (s * 0.17, -0.02, 0.055), (0, 0, s * 15), seg=12, rings=5))
        P.add(part, ball((0.1, 0.07, 0.007), wing, (s * 0.11, 0.1, 0.05), (0, 0, -s * 20), seg=10, rings=4))
        P.add(part, ball((0.035, 0.035, 0.004), spot, (s * 0.2, -0.03, 0.064), seg=8, rings=3))


main()
