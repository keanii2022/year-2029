import math, os, random, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "_kit"))
import kit  # noqa
from ykit import *  # noqa

# Things survivors left, and the building falling apart. Faces -y, floor at z = 0.
kit.DUST = 0.6


@item("survivor_tent", "story", size=1024)
def survivor_tent(P):
    """Bedsheets over a broom handle between two shelf posts, held down with paint cans. A spray painted KEEP OUT."""
    sheet_a = cloth("#9fb2c4", dirt=0.7, weave=50)
    sheet_b = cloth("#c9a9a0", dirt=0.7, weave=50)
    steel = metal("#7b7874", 0.6)
    P.add("Body", cyl(0.06, 6.4, wood("#a07a4a"), (0, 0, 3.1), (90, 0, 0)))
    for y in (-3.0, 3.0):
        P.add("Body", box((0.25, 0.25, 3.2), steel, (0, y, 1.6), r=0.03, n=1))
    for s, mat in ((-1, sheet_a), (1, sheet_b)):
        w = box((0.06, 6.2, 3.9), mat, (s * 1.2, 0, 1.55), (0, -s * 38, 0), r=0.03, n=3)
        P.add("Body", crumple(w, 0.12, 0.9, seed=s + 2))
        for y in (-2.6, 0, 2.6):
            P.add("Body", cyl(0.3, 0.45, paint("#4a6a8a" if y else "#a8452e", grime=0.6), (s * 2.55, y, 0.23), seg=14))
    back = slab([(-2.5, 0), (2.5, 0), (0, 3.05)], 0.06, sheet_a, loc=(0, 3.05, 0))
    P.add("Body", crumple(back, 0.06, 1.3, seed=9))
    P.add("Body", crumple(box((3.6, 5.6, 0.12), cloth("#5a4a3a", dirt=0.8), (0, 0.3, 0.06), r=0.04, n=3), 0.04, 1.5))
    P.add("Body", box((1.4, 0.06, 0.9), cardboard("#b58a5a"), (1.9, -3.2, 1.0), (0, 0, -8), r=0.02, n=1))
    P.add("Body", words("KEEP", 0.3, plain("#e8361c", grime=0.2), (1.88, -3.24, 1.15), (0, 0, -8)))
    P.add("Body", words("OUT", 0.3, plain("#e8361c", grime=0.2), (1.9, -3.24, 0.8), (0, 0, -8)))


@item("sleeping_bag", "story")
def sleeping_bag(P):
    bag = cloth("#3e5a7a", dirt=0.65, weave=40)
    lining = cloth("#a8432e", dirt=0.6, weave=70)
    P.add("Body", crumple(box((2.2, 5.6, 0.35), bag, (0, 0.2, 0.18), r=0.15, n=3), 0.06, 1.4))
    flap = box((2.1, 2.2, 0.12), lining, (0.5, -1.7, 0.42), (0, 8, 22), r=0.06, n=3)
    P.add("Body", crumple(flap, 0.05, 1.8, seed=2))
    P.add("Body", crumple(box((1.6, 0.9, 0.35), cloth("#d8d0c0", dirt=0.6), (0, 2.4, 0.5), r=0.15, n=3), 0.05, 2, seed=3))


@item("candles", "story", pivots={"Glow": (0, 0, 0.6)})
def candles(P):
    """A plate of melted candles. Glow is the flames, so they can flicker as Neon."""
    wax = plain("#e8dcc0", grime=0.3, vary=0.2)
    rnd = random.Random(5)
    P.add("Body", cyl(0.75, 0.06, paint("#d8d2c4", chip=0.4), (0, 0, 0.03), seg=24, bevel=0.02))
    P.add("Body", crumple(cyl(0.6, 0.08, wax, (0, 0, 0.1), seg=20), 0.03, 3))  # the puddle of melted wax
    for k, (x, y, h) in enumerate(((0, 0, 0.9), (0.3, -0.2, 0.55), (-0.32, -0.1, 0.7), (0.15, 0.32, 0.4), (-0.2, 0.3, 1.1))):
        r = 0.11 + rnd.uniform(-0.02, 0.02)
        P.add("Body", crumple(cyl(r, h, wax, (x, y, 0.1 + h / 2), seg=12, bevel=0.03), 0.012, 9, seed=k))
        P.add("Body", drip(0.07, h * 0.4, wax, (x + r * 0.9, y - r * 0.3, 0.1 + h)))
        P.add("Body", cyl(0.012, 0.08, flat("#1a1410"), (x, y, 0.14 + h)))
        flame = lathe([(0, 0), (0.035, 0.03), (0.04, 0.07), (0.022, 0.13), (0, 0.19)], glow("#ffb347", core="#fff4c8", amount=0.5), seg=10)
        P.add("Glow", move(flame, (x, y, 0.16 + h)))


@item("notes_wall", "story", size=512)
def notes_wall(P):
    """A plywood board of survivor notes, propped on two milk crates. The notes are the Screen image."""
    ply = wood("#b8946a", dark="#7a5a3a", axis="x", wear=0.7)
    crate = paint("#2f6db0", chip=0.2, grime=0.6)
    for x in (-1.9, 1.9):
        P.add("Body", box((1.4, 1.4, 1.1), crate, (x, 0.3, 0.55), r=0.06, n=1))
        P.add("Body", box((1.2, 1.42, 0.7), plain("#1e3a5c"), (x, 0.3, 0.6), r=0.02, n=1))
    P.add("Body", box((5.6, 0.12, 3.2), ply, (0, 0.3, 2.7), (-6, 0, 0), r=0.02, n=1))
    P.add("Screen", box((5.33, 0.02, 3.0), flat("#9c7a52"), (0, 0.22, 2.7), (-6, 0, 0), r=0.0, n=1))
    P.add("Body", cyl(0.12, 0.6, plain("#2a2a2a"), (1.2, 0.0, 1.17), (0, 90, 30)))  # a dead flashlight on the crate


@item("leak_bucket", "story")
def leak_bucket(P):
    """Bucket under a roof leak, half full."""
    blue = plain("#3d6fa8", grime=0.55)
    P.add("Body", lathe([(0, 0), (0.62, 0), (0.64, 0.05), (0.82, 1.3), (0.86, 1.34), (0.8, 1.34), (0.58, 0.08), (0, 0.08)], blue, seg=24))
    P.add("Body", cyl(0.76, 0.02, plain("#3c4a50", grime=0.1), (0, 0, 0.85), seg=24, bevel=0.0))
    P.add("Body", torus(0.84, 0.025, metal("#8a8680", 0.5), (0, 0, 1.25), (90, 0, 0), seg=24, sub=5, scl=(1, 1, 0.9)))


@item("puddle", "story")
def puddle(P):
    """Flat dark water under the leaks. Set it a little shiny and see-through in Roblox."""
    rnd = random.Random(3)
    pts = []
    for k in range(18):
        a = 2 * math.pi * k / 18
        r = 2.2 + rnd.uniform(-0.6, 0.6) + 0.6 * math.sin(a * 3)
        pts.append((math.cos(a) * r, math.sin(a) * r * 0.7))
    P.add("Body", slab(pts, 0.04, flat("#1f2428"), rot=(90, 0, 0), loc=(0, 0, 0.02)))


@item("broken_skylight", "story", size=1024)
def broken_skylight(P):
    """Roof skylight with a metal grid and smashed panes. Glass is its own part so Roblox can make it see-through."""
    steel = metal("#5d5a57", 0.7)
    glassm = plain("#9fb8c4", grime=0.4, vary=0.1)
    P.add("Body", box((10.4, 10.4, 0.6), steel, (0, 0, 0.3), r=0.05, n=1))
    P.add("Body", box((9.6, 9.6, 0.64), plain("#0a0a0a"), (0, 0, 0.3), r=0.0, n=1))
    for k in (-1, 0, 1):
        P.add("Body", box((0.18, 9.6, 0.3), steel, (k * 2.4, 0, 0.5), r=0.02, n=1), box((9.6, 0.18, 0.3), steel, (0, k * 2.4, 0.5), r=0.02, n=1))
    rnd = random.Random(8)
    for i in range(4):
        for j in range(4):
            cx, cy = -3.6 + i * 2.4, -3.6 + j * 2.4
            if (i, j) in ((1, 2), (2, 1), (3, 3)):  # smashed: a few jagged shards left in the corners
                for cxs, cys in ((-1, -1), (1, 1)):
                    pts = [(cx + cxs * 1.15, cy + cys * 1.15), (cx + cxs * 1.15, cy + cys * rnd.uniform(-0.4, 0.4)), (cx + cxs * rnd.uniform(0.0, 0.5), cy + cys * 1.15)]
                    P.add("Glass", slab([(p[0], -p[1]) for p in pts], 0.03, glassm, rot=(90, 0, 0), loc=(0, 0, 0.62)))
            else:
                P.add("Glass", box((2.2, 2.2, 0.03), glassm, (cx, cy, 0.62), r=0.0, n=1))


@item("weeds", "story")
def weeds(P):
    """Weeds and a little sapling pushing up through cracked concrete. It's been years."""
    concrete = plain("#8f8c86", grime=0.6)
    greens = [plain(c, grime=0.3) for c in ("#5c7a3a", "#6f8f42", "#4a6332")]
    rnd = random.Random(2)
    for k in range(3):
        a = k * 2.1
        P.add("Body", crumple(box((1.6, 1.2, 0.25), concrete, (math.cos(a) * 0.9, math.sin(a) * 0.7, 0.1), (rnd.uniform(-8, 8), rnd.uniform(-8, 8), a * 40), r=0.04, n=2), 0.04, 2, seed=k))
    for k in range(26):
        a, d = rnd.uniform(0, 2 * math.pi), rnd.uniform(0, 0.5)
        h = rnd.uniform(0.6, 1.5)
        blade = slab([(-0.05, 0), (0.05, 0), (0.01, h * 0.6), (0, h)], 0.015, greens[k % 3])
        move(blade, rot=(rnd.uniform(-25, 25), rnd.uniform(-25, 25), rnd.uniform(0, 180)), loc=(math.cos(a) * d, math.sin(a) * d, 0.15))
        P.add("Body", blade)
    P.add("Body", tube([(0.2, 0.1, 0.1), (0.25, 0.05, 1.2), (0.15, 0.0, 2.4)], [0.06, 0.04, 0.025], wood("#6a5038"), seg=6))
    for k in range(9):
        z = 1.2 + k * 0.14
        leaf = slab([(0, 0), (0.12, 0.1), (0.1, 0.3), (0, 0.38), (-0.1, 0.3), (-0.12, 0.1)], 0.015, greens[k % 3])
        move(leaf, rot=(rnd.uniform(-60, -20), 0, k * 137), loc=(0.2 - k * 0.006, 0.03, z))
        P.add("Body", leaf)


@item("vines", "story")
def vines(P):
    """Ivy hanging down from the rafters, about 8 studs long."""
    stem = wood("#5a4a32")
    greens = [plain(c, grime=0.35) for c in ("#3f5f2e", "#557a36", "#2f4a24")]
    rnd = random.Random(6)
    for s in range(3):
        x0 = (s - 1) * 0.6
        pts = [(x0 + math.sin(z * 0.9 + s) * 0.3, math.cos(z * 0.7 + s) * 0.2, 8 - z) for z in (0, 2, 4, 6, 8 - s * 1.5)]
        P.add("Body", tube(pts, [0.06, 0.05, 0.04, 0.03, 0.02], stem, seg=6))
        for k in range(14 - s * 2):
            z = 0.3 + k * (7.5 - s * 1.5) / 14
            p = (x0 + math.sin(z * 0.9 + s) * 0.3, math.cos(z * 0.7 + s) * 0.2, 8 - z)
            leaf = slab([(0, 0), (0.18, 0.12), (0.14, 0.32), (0, 0.24), (-0.14, 0.32), (-0.18, 0.12)], 0.015, greens[k % 3])
            move(leaf, rot=(rnd.uniform(-30, 30), rnd.uniform(-30, 30), rnd.uniform(0, 360)), loc=p)
            P.add("Body", leaf)
    P.add("Body", box((2.4, 0.4, 0.3), metal("#5d5a57", 0.7), (0, 0, 8.1), r=0.03, n=1))


@item("locker", "story", size=1024, pivots={"Door": (-1.05, -1.0, 3.5)})
def locker(P):
    """Your locker: the only stash that comes with you to every server. Door swings on its left hinge."""
    green = paint("#4f6e5a", chip=0.35, grime=0.55, streaks=0.5)
    dark = plain("#1d2023", grime=0.3)
    P.add("Body", box((2.2, 2.0, 7.0), green, (0, 0, 3.5), r=0.05, n=1))
    P.add("Body", box((2.0, 0.1, 6.8), dark, (0, -0.96, 3.5), r=0.0, n=1))
    door = box((2.1, 0.1, 6.8), green, (0, -1.04, 3.5), r=0.03, n=2)
    P.add("Door", crumple(door, 0.03, 1.5, seed=4))  # a few dents
    for k in range(6):
        P.add("Door", box((1.2, 0.04, 0.08), dark, (0, -1.1, 6.2 - k * 0.22), r=0.0, n=1))
    P.add("Door", box((0.18, 0.12, 0.5), metal("#9a968f", 0.4), (0.8, -1.12, 3.6), r=0.03, n=1))
    P.add("Door", torus(0.12, 0.03, metal("#b8b4ac", 0.3), (0.8, -1.2, 3.25), (0, 90, 0), seg=14, sub=5))
    P.add("Door", box((0.28, 0.12, 0.3), metal("#b8b4ac", 0.35), (0.8, -1.22, 3.05), r=0.05, n=1))
    P.add("Door", box((0.7, 0.03, 0.45), plain("#f2e6c8", grime=0.5), (-0.3, -1.1, 4.6), (0, 6, 0), r=0.0, n=1))
    P.add("Door", words("MINE", 0.22, plain("#e8361c", grime=0.2), (-0.3, -1.12, 4.6), (0, 6, 0)))
    P.add("Body", box((2.2, 0.2, 0.3), dark, (0, -0.9, 0.15), r=0.02, n=1))


@item("paper_and_pen", "story")
def paper_and_pen(P):
    """A spiral notepad with a pen clipped on. You need one to draw up a blueprint."""
    P.add("Body", box((0.7, 0.95, 0.06), cardboard("#7a5a3a"), (0, 0, 0.03), r=0.01, n=1))
    for k in range(4):
        P.add("Body", box((0.66, 0.9, 0.025), plain("#f2eee2", grime=0.35, vary=0.1), (0.005 * k, -0.01, 0.075 + k * 0.025), (0, 0, k * 1.5 - 2), r=0.005, n=1))
    for k in range(8):
        P.add("Body", torus(0.04, 0.008, metal("#9a968f", 0.3), (-0.28 + k * 0.08, 0.45, 0.12), (0, 90, 0), seg=10, sub=4))
    for k in range(3):
        P.add("Body", box((0.45 - k * 0.08, 0.008, 0.012), plain("#2f4a8a"), (-0.04, -0.2 + k * 0.1, 0.17), (90, 0, 0), r=0.0, n=1))
    P.add("Body", cyl(0.035, 0.75, plain("#1f3f8a", grime=0.2), (0.38, -0.05, 0.2), (90, 0, 4), seg=10))
    P.add("Body", cyl(0.03, 0.08, metal("#c8c4bc", 0.2), (0.38, -0.44, 0.2), (90, 0, 4), r2=0.008, seg=10, bevel=0.0))
    P.add("Body", box((0.03, 0.3, 0.05), metal("#c8c4bc", 0.2), (0.38, 0.12, 0.13), r=0.01, n=1))


@item("blueprint", "story")
def blueprint(P):
    """A rolled up blueprint of your fort, a corner peeling open, held with a rubber band."""
    blue = plain("#2f5f9a", grime=0.35, vary=0.15)
    P.add("Body", cyl(0.18, 1.8, blue, (0, 0, 0.18), (0, 90, 0), seg=18, bevel=0.01))
    P.add("Body", cyl(0.12, 1.82, plain("#d8e4f0"), (0, 0, 0.18), (0, 90, 0), seg=14, bevel=0.0))
    P.add("Body", torus(0.185, 0.02, plain("#b8452e", grime=0.2), (0.3, 0, 0.18), (0, 90, 0), seg=16, sub=4))
    flap = slab([(-0.9, 0), (0.9, 0), (0.85, 0.5), (-0.6, 0.6)], 0.01, blue)
    move(flap, rot=(78, 0, 0), loc=(0, -0.2, 0.02))
    P.add("Body", flap)
    for k in range(3):
        P.add("Body", box((0.5, 0.006, 0.01), plain("#e8f0f8"), (-0.3 + k * 0.35, -0.3 - k * 0.03, 0.05), (78 - 90, 0, k * 30), r=0.0, n=1))


@item("dog_bowl", "story")
def dog_bowl(P):
    """A dented steel bowl. Fill it to win the dog over."""
    P.add("Body", lathe([(0, 0), (0.5, 0), (0.62, 0.05), (0.7, 0.3), (0.66, 0.32), (0.52, 0.08), (0, 0.08)], metal("#a8a49c", 0.25), seg=24))
    rnd = random.Random(1)
    for k in range(16):
        a, d = rnd.uniform(0, 6.28), rnd.uniform(0, 0.4)
        P.add("Body", ball((0.07, 0.06, 0.045), plain("#7a4a28", grime=0.3), (math.cos(a) * d, math.sin(a) * d, 0.12 + rnd.uniform(0, 0.04)), (0, 0, k * 40), seg=6, rings=4))


@item("generator", "story", size=1024, pivots={"Handle": (-1.25, -0.2, 1.1)})
def generator(P):
    """Small gas generator in a pipe frame. Runs on fuel and lights a section. Handle is the pull start; Glow is its run light."""
    frame = paint("#2b2d30", chip=0.3, grime=0.6)
    body = paint("#d9a020", chip=0.45, grime=0.65, streaks=0.5)
    steel = metal("#7b7874", 0.6)
    for x in (-1.1, 1.1):
        P.add("Body", tube([(x, -0.75, 0.1), (x, -0.75, 1.8), (x, 0.75, 1.8), (x, 0.75, 0.1)], 0.07, frame, seg=8, smooth_path=False, ends=False))
    for y in (-0.75, 0.75):
        P.add("Body", cyl(0.07, 2.2, frame, (0, y, 0.1), (0, 90, 0), seg=8), cyl(0.07, 2.2, frame, (0, y, 1.8), (0, 90, 0), seg=8))
    P.add("Body", box((1.5, 1.1, 0.9), body, (0.2, 0, 0.65), r=0.1, n=2))
    P.add("Body", box((1.3, 1.0, 0.5), body, (0.3, 0, 1.42), r=0.18, n=2))
    P.add("Body", cyl(0.14, 0.12, plain("#1d1f22"), (0.6, 0, 1.72), seg=14))
    P.add("Body", cyl(0.4, 0.2, steel, (-0.7, 0, 0.75), (0, 90, 0), seg=18))
    P.add("Body", box((0.5, 0.6, 0.35), steel, (0.85, 0.35, 0.45), r=0.08, n=1))
    P.add("Body", box((0.6, 0.05, 0.45), plain("#1d1f22", grime=0.4), (0.3, -0.56, 0.7), r=0.02, n=1))
    for x in (0.15, 0.45):
        P.add("Body", box((0.12, 0.04, 0.14), plain("#e8e2d0"), (x, -0.59, 0.72), r=0.02, n=1))
    P.add("Body", torus(0.3, 0.05, plain("#e07a1f", grime=0.5), (1.6, -0.3, 0.06), seg=18, sub=6, scl=(1, 1, 0.5)))
    P.add("Body", tube([(0.15, -0.58, 0.7), (0.6, -0.8, 0.2), (1.3, -0.5, 0.06)], 0.05, plain("#e07a1f", grime=0.5), seg=6))
    P.add("Handle", box((0.08, 0.32, 0.1), plain("#1d1f22"), (-1.25, -0.2, 1.1), r=0.04, n=1))
    P.add("Handle", cyl(0.012, 0.35, plain("#bdb7a8"), (-1.0, -0.2, 1.08), (0, 90, 0), seg=5, bevel=0.0))
    P.add("Glow", box((0.08, 0.04, 0.08), glow("#59f07a", amount=0.3), (0.65, -0.59, 0.95), r=0.02, n=1))


@item("fuel_can", "story")
def fuel_can(P):
    """Red jerry can. Pour it into a generator."""
    red = paint("#b8321f", chip=0.4, grime=0.6)
    P.add("Body", box((0.5, 1.2, 1.5), red, (0, 0, 0.75), r=0.08, n=2))
    for z in (0.4, 0.75, 1.1):
        P.add("Body", box((0.52, 1.0, 0.04), paint("#9a2a1a", chip=0.4, grime=0.6), (0, 0, z), r=0.02, n=1))
    for y in (-0.25, 0.0, 0.25):
        P.add("Body", box((0.12, 0.08, 0.28), red, (0, y, 1.62), r=0.03, n=1))
    P.add("Body", box((0.14, 0.62, 0.08), red, (0, 0.0, 1.78), r=0.03, n=1))
    P.add("Body", cyl(0.1, 0.25, red, (0, -0.48, 1.6), (-30, 0, 0), seg=12), cyl(0.12, 0.08, plain("#1d1f22"), (0, -0.55, 1.72), (-30, 0, 0), seg=12))


@item("cassette_tape", "story")
def cassette_tape(P):
    """A survivor's tape. Play it in a walkie to hear what happened."""
    P.add("Body", box((0.64, 0.42, 0.07), plain("#222428", grime=0.3), (0, 0, 0.035), r=0.01, n=1))
    P.add("Body", box((0.5, 0.16, 0.01), plain("#efe6cf", grime=0.4), (0, 0.1, 0.075), r=0.0, n=1))
    P.add("Body", words("DAY 12", 0.07, flat("#1f2a44"), (0, 0.1, 0.082), (-90, 0, 0)))
    for x in (-0.14, 0.14):
        P.add("Body", cyl(0.06, 0.01, plain("#f4f0e4"), (x, -0.06, 0.075), seg=12, bevel=0.0))
        P.add("Body", cyl(0.025, 0.012, flat("#0a0a0a"), (x, -0.06, 0.08), seg=8, bevel=0.0))


@item("journal", "story")
def journal(P):
    """A survivor journal held shut with a rubber band, pages sticking out."""
    cover = cloth("#4a3a2c", dirt=0.7, weave=40)
    P.add("Body", crumple(box((0.8, 1.1, 0.12), cover, (0, 0, 0.06), r=0.03, n=2), 0.01, 5))
    P.add("Body", box((0.76, 1.06, 0.18), plain("#e8e0cc", grime=0.5), (0.01, 0, 0.13), r=0.01, n=1))
    P.add("Body", crumple(box((0.8, 1.1, 0.06), cover, (0, 0, 0.25), (0, 0, 1.5), r=0.03, n=2), 0.01, 5, seed=2))
    for k, (y, a) in enumerate(((-0.3, 4), (0.1, -6), (0.35, 8))):
        P.add("Body", box((0.3, 0.12, 0.01), plain("#f2ecd8", grime=0.4), (0.45, y, 0.13 + k * 0.03), (0, 0, a), r=0.0, n=1))
    P.add("Body", box((0.84, 0.05, 0.33), plain("#b8452e", grime=0.2), (0, 0.2, 0.15), r=0.01, n=1))  # the rubber band


main()
