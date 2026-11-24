import math, os, random, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "_kit"))
from ykit import *  # noqa

# The things that make the warehouse feel wrong. Faces -y, the figure's own left is +x.
# Figures use the robot part names (Torso, Head, UpperArm, Forearm, Hand, Thigh, Shin and Left*) with origins at the
# joints, so _kit/animate.py can rig them the same way as the robots.
SKIN = "#9aa29f"  # grey, a bit blue, nothing alive


def limb_pivots(shoulder, elbow, wrist, hip, knee):
    """Joint origins for both sides from the right side's points (x < 0)."""
    out = {}
    for pre, k in (("", 1), ("Left", -1)):
        for part, p in (("UpperArm", shoulder), ("Forearm", elbow), ("Hand", wrist), ("Thigh", hip), ("Shin", knee)):
            out[pre + part] = (p[0] * k, p[1], p[2])
    return out


KID = limb_pivots((-0.42, 0.02, 2.55), (-0.56, 0.0, 2.0), (-0.6, -0.04, 1.42), (-0.15, 0.02, 1.5), (-0.16, 0.0, 0.95))
KID["Head"] = (0, 0.02, 2.8)


def coat_r(z):
    """Raincoat radius at height z: wide hem at the knees, narrow at the shoulders."""
    prof = [(1.0, 0.6), (1.6, 0.5), (2.2, 0.42), (2.55, 0.38), (2.72, 0.24)]
    for (z0, r0), (z1, r1) in zip(prof, prof[1:]):
        if z <= z1:
            return r0 + (r1 - r0) * max(0.0, (z - z0) / (z1 - z0))
    return prof[-1][1]


@item("lost_kid", "haunt", size=1024, pivots=KID)
def lost_kid(P):
    coat = fade("#4d4524", "#c4a63c", lo=0.05, hi=0.45, grime=0.5)  # wet and dirty at the hem
    coat_dark = plain("#8a7426", grime=0.5)
    skin = plain(SKIN, grime=0.45, vary=0.3)
    bag = cardboard("#ad9670")
    ink = flat("#0b0b0b")
    hair = plain("#141414", grime=0.1)

    # Torso: the raincoat, toggles down the front, pocket flaps, a torn hem.
    body = lathe([(0, 1.02), (0.6, 1.0), (0.58, 1.12), (0.5, 1.6), (0.42, 2.2), (0.38, 2.55), (0.24, 2.72), (0.1, 2.78), (0, 2.78)],
                 coat, scl=(1, 0.78, 1), seg=22)
    crumple(body, 0.035, 2.4, seed=3)
    P.add("Torso", body)
    for z in (1.35, 1.75, 2.1, 2.45):
        P.add("Torso", box((0.12, 0.05, 0.05), plain("#2b2620", grime=0.3), (0.03, -coat_r(z) * 0.78 - 0.02, z), (0, 8, 0), r=0.02, n=1))
    P.add("Torso", box((0.03, 0.03, 1.7), coat_dark, (-0.02, -0.4, 1.85), (-8, 0, 0), r=0.01, n=1))
    for x in (-0.3, 0.3):
        P.add("Torso", box((0.26, 0.05, 0.1), coat_dark, (x, -coat_r(1.5) * 0.74 - 0.01, 1.5), (0, 0, x * 40), r=0.03, n=1))

    # Head: hood, a paper bag over the face with two torn eye holes and a crayon smile far too wide. Wet hair hangs out.
    P.add("Head", cyl(0.07, 0.3, skin, (0, 0.02, 2.82)))
    hood = ball((0.4, 0.42, 0.45), coat, (0, 0.14, 3.2), seg=18, rings=12)
    P.add("Head", crumple(hood, 0.025, 3, seed=5))
    rim = torus(0.29, 0.06, coat_dark, (0, -0.25, 3.2), (90, 0, 0), seg=20, sub=6, scl=(1, 1, 1.25))
    P.add("Head", crumple(rim, 0.015, 4, seed=2))
    sack = box((0.5, 0.46, 0.6), bag, (0, -0.06, 3.18), r=0.06, n=3)
    P.add("Head", crumple(sack, 0.03, 5, seed=8))
    P.add("Head", slab([(-0.27, 0), (-0.15, -0.07), (-0.02, 0.0), (0.1, -0.09), (0.27, -0.01), (0.27, 0.06), (-0.27, 0.06)], 0.44, bag,
                       loc=(0, -0.06, 2.86)))  # crumpled bottom edge of the bag over the neck
    # torn eye holes, not matching: the left one big and sagging, the right one a ragged slit
    P.add("Head", slab([(-0.05, 0.05), (0.02, 0.07), (0.07, 0.02), (0.06, -0.06), (0.01, -0.11), (-0.04, -0.07), (-0.07, -0.01)], 0.02, ink,
                       loc=(0.12, -0.305, 3.3), rot=(0, -12, 0)))
    P.add("Head", slab([(-0.06, 0.015), (-0.01, 0.03), (0.05, 0.02), (0.06, -0.01), (0.0, -0.035), (-0.05, -0.02)], 0.02, ink,
                       loc=(-0.12, -0.305, 3.33), rot=(0, 8, 0)))
    smile = [(-0.25, -0.3, 3.2), (-0.17, -0.31, 3.1), (-0.05, -0.312, 3.05), (0.08, -0.312, 3.04), (0.18, -0.31, 3.12), (0.25, -0.3, 3.27)]
    P.add("Head", tube(smile, 0.014, ink, seg=6))
    for k in range(9):  # crooked teeth ticks across the smile, uneven
        x = -0.19 + k * 0.045
        z = 3.06 + 0.9 * x * x + 0.08 * max(0.0, x)
        P.add("Head", box((0.009, 0.01, 0.06 + 0.03 * (k % 3)), ink, (x, -0.313, z), (0, k * 11 - 40, 0), r=0.0, n=1))
    rnd = random.Random(4)
    for side in (-1, 1):
        for k in range(3):
            x0 = side * (0.2 + k * 0.03)
            pts = [(x0, -0.22 + k * 0.02, 3.42), (x0 + side * 0.06, -0.27, 3.15), (x0 + side * rnd.uniform(0.02, 0.07), -0.26, 2.9 - k * 0.07)]
            P.add("Head", tube(pts, [0.03, 0.018, 0.008], hair, seg=5))

    # Arms: sleeves a little too long, cuffs hang open. Thin grey fingers poke out, too many joints.
    for pre, s in (("", -1), ("Left", 1)):
        sh, el, wr = V(KID[pre + "UpperArm"]), V(KID[pre + "Forearm"]), V(KID[pre + "Hand"])
        P.add(pre + "UpperArm", tube([sh + V((-s * 0.05, 0, 0.02)), el], [0.12, 0.105], coat, seg=10))
        cuff = wr + V((s * 0.02, -0.01, -0.12))
        P.add(pre + "Forearm", tube([el, wr, cuff], [0.105, 0.12, 0.15], coat, seg=10, ends=False))
        P.add(pre + "Forearm", cyl(0.13, 0.02, ink, cuff, bevel=0.0))
        P.add(pre + "Forearm", torus(0.14, 0.025, coat_dark, cuff, seg=14, sub=5))
        P.add(pre + "Hand", ball((0.06, 0.04, 0.07), skin, wr + V((0, 0, -0.14)), seg=8, rings=6))
        for k, dx in enumerate((-0.05, -0.017, 0.017, 0.05)):
            top = wr + V((dx, -0.01, -0.16))
            ln = 0.26 + (0.04 if k in (1, 2) else 0)
            pts = [top, top + V((dx * 0.3, -0.03, -ln * 0.5)), top + V((dx * 0.5, -0.07, -ln))]
            P.add(pre + "Hand", tube(pts, [0.02, 0.016, 0.011], skin, seg=5, smooth_path=False))

        # Legs: bare grey legs and feet below the coat. Thigh mostly hidden.
        hip, knee = V(KID[pre + "Thigh"]), V(KID[pre + "Shin"])
        P.add(pre + "Thigh", tube([hip, knee], [0.1, 0.085], skin, seg=8))
        ankle = V((knee.x, 0.02, 0.18))
        P.add(pre + "Shin", tube([knee, ankle], [0.08, 0.06], skin, seg=8))
        P.add(pre + "Shin", box((0.16, 0.3, 0.1), skin, (knee.x, -0.08, 0.06), r=0.04, n=2))
        for t in range(4):
            P.add(pre + "Shin", ball(0.028, skin, (knee.x + (t - 1.5) * 0.035, -0.24, 0.035), seg=6, rings=4))


@item("stuffed_robot", "haunt")
def stuffed_robot(P):
    """The kid's toy, left on the floor where it vanished. Worn plush, one button eye gone, stuffing out of a seam."""
    plush = cloth("#5d8fb3", dirt=0.75, weave=70, dirtcolor="#3a3128")
    belly = cloth("#d8cfb8", dirt=0.7, weave=70)
    thread = flat("#221d18")
    P.add("Body", crumple(box((0.5, 0.36, 0.48), plush, (0, 0, 0.42), r=0.14, n=3), 0.02, 6))
    P.add("Body", crumple(box((0.3, 0.06, 0.26), belly, (0, -0.18, 0.4), r=0.08, n=2), 0.01, 8))
    P.add("Body", crumple(box((0.46, 0.38, 0.38), plush, (0, 0, 0.88), (0, 0, 0), r=0.14, n=3), 0.02, 6, seed=1))
    P.add("Body", ball(0.05, plain("#1c1c1c", grime=0.1), (-0.11, -0.19, 0.92), seg=10, rings=6))  # the one button eye left
    P.add("Body", stitch([(0.06, -0.195, 0.95), (0.16, -0.195, 0.89)], 3, 0.03, thread, cross=True))  # where the other one was
    P.add("Body", stitch([(-0.1, -0.195, 0.8), (0.1, -0.195, 0.8)], 5, 0.025, thread))
    P.add("Body", cyl(0.02, 0.14, thread, (0, 0, 1.12)), ball(0.05, cloth("#c75a4a", 0.7), (0, 0, 1.2), seg=8, rings=6))
    for x in (-0.33, 0.33):
        P.add("Body", crumple(box((0.16, 0.18, 0.36), plush, (x, 0, 0.5), (0, x * 40, 0), r=0.07, n=2), 0.015, 8))
        P.add("Body", crumple(box((0.17, 0.22, 0.14), plush, (x * 0.45, -0.08, 0.08), r=0.06, n=2), 0.015, 8))
    for k in range(5):  # stuffing coming out of a split seam on the side
        P.add("Body", crumple(ball(0.05 + k * 0.006, cloth("#efeae0", 0.4), (0.25 + k * 0.012, -0.05 + k * 0.03, 0.55 + k * 0.03), seg=8, rings=6), 0.012, 12))


@item("kid_ball", "haunt")
def kid_ball(P):
    """A faded, half flat playground ball. It rolls toward you out of the dark."""
    b = ball((0.42, 0.42, 0.34), plain("#b2483c", grime=0.6, vary=0.4), (0, 0, 0.34), seg=20, rings=12)
    P.add("Body", crumple(b, 0.03, 3))
    P.add("Body", torus(0.415, 0.025, plain("#e0d6c0", grime=0.6), (0, 0, 0.36), (90, 0, 20), seg=24, sub=5, scl=(1, 0.82, 1)))
    P.add("Body", torus(0.415, 0.025, plain("#e0d6c0", grime=0.6), (0, 0, 0.36), (90, 0, 110), seg=24, sub=5, scl=(1, 0.82, 1)))


MANNEQUIN = limb_pivots((-0.62, 0.0, 4.55), (-0.72, 0.0, 3.6), (-0.76, -0.02, 2.75), (-0.27, 0.0, 2.85), (-0.29, 0.0, 1.5))
MANNEQUIN["Head"] = (0, 0, 4.8)


@item("mannequin", "haunt", size=1024, pivots=MANNEQUIN)
def mannequin(P):
    """Old store mannequin, faceless, chipped. Moves only when nobody looks."""
    shell = paint("#ddd6c8", chip=0.35, under="#8d8577", under2="#4a443c", grime=0.5, streaks=0.5)
    seam = plain("#6d675e", grime=0.4)
    chest = lathe([(0.0, 2.75), (0.42, 2.78), (0.5, 3.0), (0.44, 3.4), (0.5, 3.9), (0.62, 4.35), (0.55, 4.6), (0.22, 4.75), (0, 4.78)],
                  shell, scl=(1, 0.62, 1), seg=22)
    P.add("Torso", chest, torus(0.47, 0.018, seam, (0, 0, 3.4), scl=(1, 0.62, 1), seg=24, sub=4))
    P.add("Head", cyl(0.13, 0.35, shell, (0, 0, 4.9)))
    P.add("Head", ball((0.3, 0.34, 0.4), shell, (0, -0.03, 5.25), seg=18, rings=12))
    P.add("Head", torus(0.3, 0.012, seam, (0, -0.03, 5.25), (0, 90, 0), seg=24, sub=4, scl=(1, 1.13, 1.33)))
    for pre, s in (("", -1), ("Left", 1)):
        sh, el, wr = V(MANNEQUIN[pre + "UpperArm"]), V(MANNEQUIN[pre + "Forearm"]), V(MANNEQUIN[pre + "Hand"])
        P.add(pre + "UpperArm", ball(0.16, shell, sh, seg=12, rings=8), tube([sh, el], [0.14, 0.11], shell, seg=12))
        P.add(pre + "Forearm", ball(0.11, seam, el, seg=10, rings=6), tube([el, wr], [0.1, 0.075], shell, seg=12))
        P.add(pre + "Hand", box((0.12, 0.22, 0.42), shell, wr + V((0, -0.02, -0.24)), (0, -s * 6, 0), r=0.06, n=2))
        P.add(pre + "Hand", tube([wr + V((-s * 0.05, -0.1, -0.15)), wr + V((-s * 0.06, -0.16, -0.3))], 0.035, shell, seg=6))
        hip, knee = V(MANNEQUIN[pre + "Thigh"]), V(MANNEQUIN[pre + "Shin"])
        P.add(pre + "Thigh", tube([hip, knee], [0.22, 0.15], shell, seg=12))
        P.add(pre + "Shin", ball(0.14, seam, knee, seg=10, rings=6), tube([knee, V((knee.x, 0.02, 0.22))], [0.13, 0.085], shell, seg=12))
        P.add(pre + "Shin", box((0.22, 0.52, 0.2), shell, (knee.x, -0.12, 0.1), r=0.08, n=2))


@item("greeter", "haunt", size=1024, pivots={"Head": (0, 0.0, 4.55), "Screen": (0, 0.0, 4.55), "Arm": (-0.85, 0.0, 4.1)})
def greeter(P):
    """The old store greeter at the doors. Still waves. Still says welcome. Wave: Arm swings up and out. Head and Screen tilt together."""
    shell = paint("#eceae4", chip=0.3, grime=0.6, streaks=0.6)
    teal = paint("#1fa79a", chip=0.4, grime=0.5)
    dark = plain("#2a2d33", grime=0.4)
    P.add("Body", box((2.4, 1.4, 2.6), teal, (0, 0.2, 1.3), r=0.15, n=2))
    P.add("Body", box((2.6, 1.6, 0.2), shell, (0, 0.2, 2.65), r=0.06, n=1))
    P.add("Body", words("HELLO!", 0.55, flat("#ffffff"), (0, -0.52, 1.6)))
    P.add("Body", lathe([(0.6, 2.7), (0.75, 3.1), (0.8, 3.7), (0.62, 4.25), (0.2, 4.4), (0, 4.4)], shell, scl=(1, 0.75, 1), seg=20))
    P.add("Body", ball(0.2, dark, (0.85, 0.0, 4.1), seg=10, rings=6), tube([(0.85, 0, 4.0), (0.95, -0.1, 3.4), (0.9, -0.3, 3.0)], 0.13, shell, seg=10))
    P.add("Body", hand(1, shell, loc=(0.88, -0.35, 2.9), rot=(0, 0, 10), size=0.7))
    P.add("Body", box((0.3, 0.05, 0.12), glow("#ff3b30", amount=0.3), (0.35, -0.6, 3.75), r=0.02, n=1))
    P.add("Head", cyl(0.14, 0.25, dark, (0, 0, 4.6)))
    P.add("Head", box((1.3, 0.95, 1.0), shell, (0, 0.02, 5.2), r=0.2, n=2))
    P.add("Head", box((1.1, 0.06, 0.8), dark, (0, -0.44, 5.2), r=0.05, n=1))
    P.add("Head", cyl(0.03, 0.4, dark, (0.4, 0.1, 5.85), (0, 15, 0)), ball(0.06, glow("#7cf5e6"), (0.45, 0.1, 6.04)))
    P.add("Screen", box((1.0, 0.02, 0.72), flat("#0d1a22"), (0, -0.48, 5.2), r=0.0, n=1))
    P.add("Arm", ball(0.2, dark, (-0.85, 0.0, 4.1), seg=10, rings=6), tube([(-0.85, 0, 4.0), (-1.0, -0.1, 3.4), (-1.0, -0.2, 2.9)], 0.13, shell, seg=10))
    P.add("Arm", hand(-1, shell, loc=(-1.0, -0.22, 2.8), rot=(0, 0, -10), size=0.7))


@item("robot_pile", "haunt", size=1024, pivots={"Twitch": (0.6, -0.4, 2.4)})
def robot_pile(P):
    """A heap of shut down robots. Twitch is one arm sticking out that jerks now and then; Glow is a pair of eyes that flickers."""
    rnd = random.Random(11)
    shells = [paint(c, chip=0.5, grime=0.7, streaks=0.6) for c in ("#eceae4", "#d8d2c4", "#c9cfd2", "#e2b04a")]
    dark = plain("#24262b", grime=0.5)
    steel = metal("#6f6c69", 0.6)
    # a lumpy dark heap of scrap underneath so nothing floats, then parts packed over it
    # small faces on purpose: cull drops any face a piece half covers, and a big one leaves a hole
    dome = lathe([(0, 0), (1.0, 0), (0.99, 0.12), (0.97, 0.25), (0.92, 0.4), (0.85, 0.55), (0.75, 0.68), (0.62, 0.8), (0.48, 0.89), (0.32, 0.95),
                  (0.16, 0.99), (0, 1.0)], plain("#3a3936", grime=0.7, vary=0.4), scl=(3.0, 2.3, 1.9), seg=28)
    P.add("Body", crumple(dome, 0.2, 0.8))
    for k in range(30):
        a, d = rnd.uniform(0, 2 * math.pi), rnd.uniform(0, 1) ** 0.8
        x, y = math.cos(a) * d * 2.8, math.sin(a) * d * 2.1
        z = 1.9 * math.sqrt(max(0.0, 1 - d * d)) + rnd.uniform(0.0, 0.15)
        rot = (rnd.uniform(-50, 50), rnd.uniform(-50, 50), rnd.uniform(0, 360))
        kind = k % 4
        sh = shells[rnd.randrange(4)]
        if kind == 0:  # torso
            P.add("Body", box((1.0, 0.7, 1.1), sh, (x, y, z), rot, r=0.15, n=2))
        elif kind == 1:  # head with a dead screen face
            P.add("Body", box((0.8, 0.65, 0.65), sh, (x, y, z), rot, r=0.15, n=2))
        elif kind == 2:  # arm segment
            P.add("Body", cyl(0.14, 1.3, sh, (x, y, z), rot))
        else:  # wheel
            P.add("Body", cyl(0.35, 0.22, dark, (x, y, z), rot, bevel=0.06), cyl(0.15, 0.25, steel, (x, y, z), rot))
    for k in range(5):
        a = rnd.uniform(0, 2 * math.pi)
        pts = [(math.cos(a) * 2.6, math.sin(a) * 2.0, 0.1), (math.cos(a) * 1.4, math.sin(a) * 1.1, 1.5), (math.cos(a + 0.6) * 0.5, math.sin(a + 0.6) * 0.4, 2.4)]
        P.add("Body", tube(pts, 0.05, plain(("#222222", "#8a2a22", "#2a4e8a")[k % 3], grime=0.3), seg=6))
    # the one head on top facing out, eyes still lit
    P.add("Body", box((0.9, 0.75, 0.7), shells[0], (-0.4, -1.0, 2.25), (8, -10, -15), r=0.18, n=2))
    P.add("Body", box((0.7, 0.05, 0.48), dark, (-0.42, -1.38, 2.24), (8, -10, -15), r=0.04, n=1))
    for x in (-0.58, -0.3):
        P.add("Glow", box((0.12, 0.04, 0.16), glow("#ff3b30", amount=0.25), (x, -1.42, 2.27), (8, -10, -15), r=0.02, n=1))
    P.add("Twitch", ball(0.18, dark, (0.6, -0.4, 2.4), seg=10, rings=6))
    P.add("Twitch", tube([(0.6, -0.4, 2.4), (0.9, -0.9, 3.1), (1.0, -1.5, 3.4)], [0.13, 0.11], shells[1], seg=10))
    P.add("Twitch", hand(1, shells[1], loc=(1.02, -1.62, 3.45), rot=(60, 0, 20), size=0.65, curl=1.4))


@item("shirt_folder", "haunt", size=1024, pivots={"Arm": (0.0, 1.0, 3.25), "Shirt": (0.0, -0.1, 3.12)})
def shirt_folder(P):
    """A robot arm folding the same shirt forever, next to a tower of the same shirt. Loop: Arm swings down, Shirt flips its half over."""
    top = wood("#8b6b4a", wear=0.8)
    steel = metal("#7b7874", 0.5)
    orange = paint("#f28c28", chip=0.45, grime=0.6)
    shirt_c = cloth("#7c8f6a", dirt=0.5, weave=80)
    P.add("Body", box((5.0, 2.6, 0.2), top, (0, 0, 3.0), r=0.04, n=1))
    for x in (-2.3, 2.3):
        for y in (-1.1, 1.1):
            P.add("Body", box((0.18, 0.18, 2.9), steel, (x, y, 1.45), r=0.03, n=1))
    P.add("Body", cyl(0.45, 0.25, steel, (0, 1.0, 3.22)))
    for k in range(14):  # the tower of identical folded shirts
        P.add("Body", crumple(box((1.3, 1.0, 0.12), shirt_c, (1.6 + (k % 3) * 0.02, 0.0, 3.17 + k * 0.125), (0, 0, (k * 7) % 5 - 2), r=0.05, n=2), 0.012, 5, seed=k))
    P.add("Body", crumple(box((1.3, 1.0, 0.12), shirt_c, (0, 0.45, 3.17), r=0.05, n=2), 0.012, 5, seed=40))  # the half that stays down
    P.add("Shirt", crumple(box((1.3, 1.0, 0.1), shirt_c, (0, -0.55, 3.16), r=0.05, n=2), 0.012, 5, seed=41))
    for x in (-0.75, 0.75):
        P.add("Shirt", crumple(box((0.4, 0.5, 0.08), shirt_c, (x, -0.3, 3.16), (0, 0, x * 30), r=0.04, n=2), 0.01, 6))
    P.add("Arm", cyl(0.3, 0.35, orange, (0.0, 1.0, 3.45)))
    P.add("Arm", tube([(0, 1.0, 3.6), (0, 0.6, 4.8), (0, -0.3, 4.6)], [0.18, 0.15, 0.13], orange, seg=10))
    P.add("Arm", ball(0.2, steel, (0, 0.6, 4.8), seg=10, rings=6), cyl(0.12, 0.6, steel, (0, -0.35, 4.3)))
    for x in (-0.12, 0.12):
        P.add("Arm", box((0.05, 0.16, 0.3), steel, (x, -0.35, 3.9), r=0.02, n=1))


@item("security_cam", "haunt", pivots={"Cam": (0, -0.55, 0.0), "Glow": (0, -0.55, 0.0)})
def security_cam(P):
    """Ceiling cam on a wall arm. Cam turns slowly to follow you; Glow is its red light."""
    grey = paint("#cfcbc2", chip=0.3, grime=0.6)
    dark = plain("#202227", grime=0.4)
    P.add("Body", box((0.5, 0.12, 0.7), grey, (0, 0.06, 0.25), r=0.04, n=1))
    P.add("Body", tube([(0, 0.0, 0.25), (0, -0.35, 0.2), (0, -0.55, 0.06)], 0.06, grey, seg=8))
    P.add("Cam", ball(0.1, dark, (0, -0.55, 0.0), seg=10, rings=6))
    P.add("Cam", box((0.36, 0.9, 0.34), grey, (0, -0.95, -0.12), (12, 0, 0), r=0.06, n=2))
    P.add("Cam", box((0.42, 0.95, 0.04), grey, (0, -1.0, 0.07), (12, 0, 0), r=0.01, n=1))
    P.add("Cam", cyl(0.12, 0.08, dark, (0, -1.42, -0.2), (90 - 12, 0, 0)), ball((0.09, 0.02, 0.09), plain("#0a0e14", grime=0.0), (0, -1.47, -0.21)))
    P.add("Glow", ball(0.035, glow("#ff2a20", amount=0.2), (0.12, -1.42, -0.06)))


@item("drawing_wall", "haunt", size=512)
def drawing_wall(P):
    """A cork board of kids' drawings, happy at the start and darker by the end. The drawings are the Screen image."""
    frame = wood("#7a5a3a", wear=0.7)
    P.add("Body", box((6.4, 0.16, 3.1), frame, (0, 0.08, 1.55 + 2.0), r=0.04, n=1))
    P.add("Screen", box((6.0, 0.02, 2.67), flat("#8a6d4b"), (0, -0.01, 3.55), r=0.0, n=1))
    P.add("Body", box((6.4, 0.4, 0.08), frame, (0, -0.15, 2.04), r=0.02, n=1))
    for k, col in enumerate(("#d64a3a", "#3a8fd8", "#f1c40f", "#3c9a3c", "#222222")):
        P.add("Body", cyl(0.04, 0.4, plain(col, grime=0.2), (-2.2 + k * 0.3, -0.18, 2.12), (90, 0, 80 + k * 7), r2=0.035, seg=8))


main()
