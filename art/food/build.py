import math, os, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "_kit"))
from ykit import *  # noqa

PAINT_RED = "#e8361c"


def melon_skin():
    """Pale green rind with dark wavy stripes running the melon's length, plus a creamy field spot."""
    g = G("melon")
    band = g.step(g.noise(7.0, 4, (1, 1, 0.05), 0.5), 0.49, 0.53)  # lathe axis is local z, so the stripes stretch along z
    c = g.mix(band, "#a8c47a", "#24521f")
    spot = g.step(g.noise(1.4, 2, (1, 1, 0.5), 0.4), 0.62, 0.7)
    c = g.mix(g.math("MULTIPLY", spot, 0.8), c, "#ddd08c")
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(3.5, 6, world=True), 0.5, 0.8), 0.35), c, "#6a5646", "MULTIPLY")
    return g.done(c)


def printed(text, size, ink, loc, rot=(0, 0, 0)):
    """A made-up label printed flat on the surface, not stuck on as a raised slab."""
    return words(text, size, flat(ink), loc=loc, rot=rot, depth=0.002)


@item("canned_food", "food")
def canned_food(P):
    tin = metal("#b8b4ac", rust=0.25)
    P.add("Body", cyl(0.17, 0.42, plain("#e8794a", grime=0.2), seg=16, bevel=0.01))
    for z in (-0.2, 0.2):
        P.add("Body", cyl(0.175, 0.03, tin, loc=(0, 0, z), seg=16, bevel=0.01))
    P.add("Body", box((0.2, 0.01, 0.16), plain("#f4ecd8", grime=0.1), loc=(0, -0.168, 0.0), r=0.01, n=1))
    P.add("Body", words("BEAN", 0.07, flat("#3a2a20"), loc=(0, -0.176, 0.0)))


@item("snack_bar", "food")
def snack_bar(P):
    """A thin foil-wrapped bar, slightly bent, with sawtooth crimp seals fanning out at both ends and the label printed on."""
    wrap = paint("#e8b93a", chip=0.15, under="#c9cdd2", under2="#9aa0a6", grime=0.45, streaks=0.3)
    bar = box((0.54, 0.26, 0.06), wrap, r=0.025, n=3)
    crumple(bar, 0.006, 8, seed=2)
    warp(bar, lambda v: V((v.x, v.y, v.z + 0.02 * (1 - (v.x / 0.27) ** 2))))
    P.add("Body", bar)
    seal = paint("#d9a52e", chip=0.25, under="#c9cdd2", under2="#9aa0a6", grime=0.4, streaks=0.2)
    for sx in (-1, 1):
        teeth = [(0, -0.14)] + [(0.07 if k % 2 else 0.055, -0.14 + 0.28 * k / 14) for k in range(15)] + [(0, 0.14)]
        P.add("Body", slab(teeth, 0.012, seal, loc=(sx * 0.27, 0, 0.012), rot=(90, 0, 0 if sx > 0 else 180)))
    P.add("Body", box((0.26, 0.002, 0.04), plain("#b03a2e", grime=0.35), loc=(0, -0.131, 0.01), r=0.0, n=1))
    P.add("Body", printed("CRNCH", 0.03, "#fff3d8", (0, -0.1325, 0.01)))
    P.add("Body", box((0.07, 0.002, 0.035), plain("#f2ead2", grime=0.5), loc=(0.18, -0.1315, 0.012), rot=(0, 10, 0), r=0.0, n=1))  # price sticker
    P.add("Body", printed("1.99", 0.016, "#3a2a20", (0.18, -0.1335, 0.012), rot=(0, 10, 0)))


@item("sandwich", "food")
def sandwich(P):
    """A triangle half standing in a store wedge pack: card tray behind and under, clear rim round the front,
    soft domed bread with a dark crust, wavy lettuce and filling bulging out past the bread. Faces -y."""
    bread = plain("#e2c08a", grime=0.35)
    crust = plain("#9a6430", grime=0.4)
    tri = lambda inset: [(-0.29 + inset * 1.7, inset), (0.29 - inset * 1.7, inset), (0, 0.41 - inset * 1.4)]
    for y in (-0.055, 0.055):  # two slices, crust first, soft domed bread face on top of it
        P.add("Body", slab(tri(0.0), 0.05, crust, loc=(0, y, 0.015), bevel=0.018))
        dome = slab(tri(0.022), 0.05, bread, loc=(0, y - 0.004 * (1 if y < 0 else -1), 0.015), bevel=0.02)
        P.add("Body", dome)
    lettuce = plain("#7aa83e", grime=0.3, vary=0.4)
    wave = [(-0.31 + 0.62 * i / 16, -0.012 + 0.018 * (i % 2)) for i in range(17)] + [(0.0, 0.43)]
    ruffle = []
    for i in range(30):  # lettuce frill all the way round, sticking out past the crust
        t = i / 30
        if t < 1 / 3:
            x, z = -0.3 + 0.6 * t * 3, 0.0
        elif t < 2 / 3:
            x, z = 0.3 - 0.3 * (t - 1 / 3) * 3, 0.42 * (t - 1 / 3) * 3
        else:
            x, z = -0.3 * (t - 2 / 3) * 3, 0.42 - 0.42 * (t - 2 / 3) * 3
        cx, cz = x * 1.08, (z - 0.14) * 1.08 + 0.14 + (0.012 if i % 2 else -0.004)
        ruffle.append((cx, cz))
    P.add("Body", slab(ruffle, 0.022, lettuce, loc=(0, -0.018, 0.012)))
    P.add("Body", slab(tri(-0.02), 0.032, plain("#d9827a", grime=0.3), loc=(0, 0.008, 0.012), bevel=0.014))  # ham bulging out
    P.add("Body", slab(tri(-0.008), 0.016, plain("#f0d27a", grime=0.25), loc=(0, 0.03, 0.012)))  # cheese
    # the pack: card tray along the bottom and back, clear plastic rim round the front window
    card = cardboard("#c9b48c")
    P.add("Body", box((0.62, 0.19, 0.012), card, loc=(0, 0, 0.006), r=0.003, n=1))
    P.add("Body", slab(tri(-0.01), 0.012, card, loc=(0, 0.089, 0.012)))
    film = plain("#d8e4e8", grime=0.5, vary=0.3)
    P.add("Body", box((0.62, 0.012, 0.03), film, loc=(0, -0.09, 0.02), r=0.004, n=1))  # clear lip of the tray at the front
    # BEST BEFORE sticker on the card, a hand-written price on the rim
    P.add("Body", box((0.2, 0.004, 0.07), plain("#f2ead2", grime=0.45), loc=(0.13, 0.097, 0.1), r=0.0, n=1))
    P.add("Body", printed("BEST BEFORE", 0.018, "#3a2a20", (0.13, 0.1, 0.115), rot=(0, 0, 180)))
    P.add("Body", printed("04 MAR 29", 0.018, "#b03a2e", (0.13, 0.1, 0.085), rot=(0, 0, 180)))


@item("apple", "food")
def apple(P):
    """Rounded, wide at the shoulders and narrow at the base, with a deep stem dimple and streaky red to yellow-green skin."""
    skin = fade("#d2b452", "#b8261c", 0.25, 0.75, grime=0.35)
    # outline sampled finely so it renders round, not faceted: narrow base, wide shoulders, dimples top and bottom
    outline = [(0, -0.15), (0.03, -0.162)]
    for k in range(13):
        t = k / 12
        a = math.pi * (-0.42 + 0.84 * t)
        outline.append((0.19 * math.cos(a) * (0.86 + 0.14 * t), -0.008 + 0.168 * math.sin(a)))
    outline += [(0.022, 0.142), (0, 0.112)]
    P.add("Body", lathe(outline, skin, seg=36, lobes=5, lobe=0.004, smooth=80))
    P.add("Body", box((0.03, 0.03, 0.09), wood("#5d4037", "#3e2723"), loc=(0, 0, 0.15), rot=(0, 12, 0), r=0.012, n=1))
    P.add("Body", slab([(0, 0), (0.06, 0.03), (0.13, 0), (0.06, -0.03)], 0.01, plain("#6b8a3a", grime=0.4), loc=(0.02, 0, 0.19), rot=(0, -20, 0)))


@item("water_bottle", "food")
def water_bottle(P):
    P.add("Body", lathe([(0, -0.35), (0.11, -0.35), (0.12, -0.3), (0.12, 0.12), (0.09, 0.22), (0.05, 0.27), (0.05, 0.3), (0, 0.3)],
                        plain("#9fd3e6", grime=0.05, vary=0.15), seg=16, lobes=8, lobe=0.004))
    P.add("Body", cyl(0.055, 0.07, plain("#1e88e5", grime=0.1), loc=(0, 0, 0.33), seg=12, bevel=0.01))
    P.add("Body", cyl(0.123, 0.18, plain("#ffffff", grime=0.1), loc=(0, 0, -0.08), seg=16, bevel=0.0))
    P.add("Body", words("AQUA", 0.06, flat("#1565c0"), loc=(0, -0.126, -0.08)))


@item("energy_drink", "food")
def energy_drink(P):
    """A tall slim can: concave base, sharp neck taper, rolled rim, recessed lid with a pull tab.
    Green paint scratched through to silver, a made-up claw-mark logo printed flat, a dent in one side."""
    can = paint("#2fa84a", chip=0.28, under="#c2c6ca", under2="#8d9196", grime=0.35, streaks=0.2)
    alu = metal("#c4c8cc", rust=0.05)
    body = lathe([(0, -0.245), (0.07, -0.272), (0.1, -0.265), (0.11, -0.24), (0.11, 0.19), (0.088, 0.245), (0.084, 0.258), (0, 0.258)],
                 can, seg=24)
    crumple(body, 0.004, 6, seed=7)
    warp(body, lambda v: V((v.x, v.y + 0.018 * max(0.0, 1 - ((v.z + 0.02) / 0.09) ** 2) * max(0.0, -v.y / 0.11) ** 3, v.z)))  # the dent
    P.add("Body", body)
    P.add("Body", lathe([(0.068, 0.252), (0.086, 0.258), (0.089, 0.266), (0.084, 0.273), (0.07, 0.268), (0.066, 0.262), (0, 0.262)], alu, seg=24))
    P.add("Body", box((0.07, 0.035, 0.006), alu, loc=(0.0, 0.012, 0.267), r=0.006, n=1))
    P.add("Body", cyl(0.011, 0.006, alu, loc=(0, -0.004, 0.268), seg=8, bevel=0.002))
    P.add("Body", cyl(0.016, 0.004, flat("#2a2c2e"), loc=(0, -0.05, 0.264), seg=10, bevel=0.0))
    # printed black band with three claw marks and a made-up name, flush with the paint
    P.add("Body", lathe([(0.1102, -0.08), (0.1102, 0.09)], plain("#151515", grime=0.3), seg=24))
    for k, x in enumerate((-0.03, 0.0, 0.03)):
        P.add("Body", slab([(-0.008, -0.05), (0.008, -0.05), (0.012, 0.05), (-0.004, 0.05)], 0.003, flat("#8dff3a"),
                           loc=(x, -0.1115, 0.02 + 0.006 * (k % 2)), rot=(0, -12, 0)))
    P.add("Body", printed("RAVAGE", 0.028, "#e8f5d8", (0, -0.1118, -0.055)))


@item("dog_treats", "food")
def dog_treats(P):
    bag = plain("#f9a825", grime=0.2)
    P.add("Body", loft([[(x * w, y * d, z) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
                        for z, w, d in ((0, 0.22, 0.1), (0.3, 0.24, 0.11), (0.5, 0.22, 0.06), (0.56, 0.22, 0.02))], bag))
    P.add("Body", box((0.46, 0.05, 0.05), plain("#e65100", grime=0.2), loc=(0, 0, 0.56), r=0.01, n=1))
    paw = flat("#4e342e")
    P.add("Body", ball((0.06, 0.01, 0.05), paw, loc=(0, -0.112, 0.2)))
    for x, z in ((-0.06, 0.28), (-0.02, 0.3), (0.02, 0.3), (0.06, 0.28)):
        P.add("Body", ball((0.02, 0.01, 0.025), paw, loc=(x, -0.112, z)))
    P.add("Body", words("YUM", 0.06, flat("#4e342e"), loc=(0, -0.112, 0.42)))


# Round two food. Real life sizes (1 stud is about 0.3 m) so they feel right when grabbed and turned.
# Brands are made up. Lid, Flap: hinged parts (see BRIEF.md "Moving parts").
def wedge(r, a0, a1, mat, z, h, steps=4):
    """Flat pie slice lying on the floor plane, tip at the origin."""
    pts = [(0.0, 0.0)] + [(r * math.cos(math.radians(a0 + (a1 - a0) * i / steps)), r * math.sin(math.radians(a0 + (a1 - a0) * i / steps))) for i in range(steps + 1)]
    return slab(pts, h, mat, loc=(0, 0, z), rot=(90, 0, 0))


def top_words(text, size, mat, x, y, z):
    """Words printed on a top face, readable from the front."""
    return words(text, size, mat, loc=(x, y, z), rot=(-90, 0, 0), depth=0.008)


@item("pizza_box", "food", pivots={"Lid": (0, 0.6, 0.18)})
def pizza_box(P):
    card = plain("#d8c39a", grime=0.35)
    P.add("Body", box((1.2, 1.2, 0.02), card, loc=(0, 0, 0.01), r=0.0, n=1))
    for x, y, w, d in ((0, -0.59, 1.2, 0.02), (0, 0.59, 1.2, 0.02), (-0.59, 0, 0.02, 1.2), (0.59, 0, 0.02, 1.2)):
        P.add("Body", box((w, d, 0.16), card, loc=(x, y, 0.08), r=0.0, n=1))
    for i in range(8):
        if i == 2:
            continue  # someone already ate one
        a0 = i * 45
        P.add("Body", wedge(0.53, a0 + 1, a0 + 44, plain("#c98b45", grime=0.2), 0.05, 0.05))
        P.add("Body", wedge(0.47, a0 + 2, a0 + 43, plain("#f3c34f", grime=0.15), 0.065, 0.04))
        for k, (rr, da) in enumerate(((0.3, 14), (0.18, 30), (0.38, 33))):
            a = math.radians(a0 + da)
            P.add("Body", cyl(0.055, 0.015, plain("#b8402f", grime=0.2), loc=(rr * math.cos(a), rr * math.sin(a), 0.09), seg=10, bevel=0.0))
    P.add("Lid", box((1.22, 1.22, 0.02), card, loc=(0, 0, 0.17), r=0.0, n=1))
    P.add("Lid", box((1.22, 0.02, 0.05), card, loc=(0, -0.6, 0.15), r=0.0, n=1))
    P.add("Lid", top_words("SLICE 29", 0.15, flat("#c0392b"), 0, 0.05, 0.181))
    P.add("Lid", top_words("HOT AND FAST", 0.06, flat("#3a2a20"), 0, -0.2, 0.181))


@item("cereal_box", "food", pivots={"Flap": (0, 0.115, 1.07)})
def cereal_box(P):
    P.add("Body", box((0.83, 0.23, 1.07), plain("#f2994a", grime=0.25), loc=(0, 0, 0.535), r=0.01, n=1))
    P.add("Body", box((0.46, 0.012, 0.32), plain("#eceae4", grime=0.15), loc=(0, -0.118, 0.45), r=0.04, n=1))
    P.add("Body", box((0.36, 0.014, 0.18), flat("#1d2733"), loc=(0, -0.126, 0.47), r=0.03, n=1))
    for x in (-0.08, 0.08):
        P.add("Body", box((0.05, 0.016, 0.07), flat("#7cf5e6"), loc=(x, -0.13, 0.49), r=0.0, n=1))
    P.add("Body", words("CHOCO", 0.12, flat("#5d2e0c"), loc=(0, -0.118, 0.9), depth=0.008))
    P.add("Body", words("BOLTS", 0.16, flat("#fff6e0"), loc=(0, -0.118, 0.74), depth=0.008))
    P.add("Body", words("NOW WITH MORE IRON", 0.04, flat("#5d2e0c"), loc=(0, -0.118, 0.17), depth=0.008))
    P.add("Flap", box((0.83, 0.23, 0.015), plain("#e8873a", grime=0.25), loc=(0, 0, 1.077), r=0.0, n=1))


@item("noodle_cup", "food", pivots={"Lid": (0, 0.14, 0.35)})
def noodle_cup(P):
    """Tapered foam cup gone yellow, label printed on, a dirty thumbprint."""
    P.add("Body", lathe([(0, 0), (0.11, 0), (0.15, 0.33), (0.155, 0.345), (0, 0.345)], plain("#e9e1cc", grime=0.55), seg=24))
    P.add("Body", lathe([(0, 0.1), (0.128, 0.1), (0.144, 0.26), (0, 0.26)], paint("#c9481e", chip=0.15, under="#e9e1cc", under2="#cfc5ad", grime=0.4, streaks=0.3), seg=24))
    P.add("Body", printed("RAMEN", 0.045, "#fff3c4", (0, -0.14, 0.18), rot=(-7, 0, 0)))
    P.add("Body", printed("SPICY ROBOT", 0.016, "#fff3c4", (0, -0.137, 0.135), rot=(-7, 0, 0)))
    P.add("Body", aim(slab([(0.02 * math.cos(a / 8 * math.tau), 0.026 * math.sin(a / 8 * math.tau)) for a in range(8)], 0.002, flat("#7a6a55")),
                      V((0.09, -0.1, 0.3)), V((0.6, -0.8, 0.0)).normalized()))
    P.add("Lid", cyl(0.158, 0.012, metal("#cfd3d8", rust=0.1), loc=(0, 0, 0.352), seg=24, bevel=0.0))
    P.add("Lid", box((0.08, 0.06, 0.008), metal("#cfd3d8", rust=0.1), loc=(0, -0.18, 0.352), r=0.0, n=1))


@item("milk_carton", "food")
def milk_carton(P):
    w = plain("#f4f2ee", grime=0.25)
    P.add("Body", box((0.23, 0.23, 0.62), w, loc=(0, 0, 0.31), r=0.01, n=1))
    P.add("Body", slab([(-0.115, 0), (0.115, 0), (0, 0.11)], 0.23, w, loc=(0, 0, 0.62), rot=(0, 0, 90)))
    P.add("Body", box((0.23, 0.03, 0.07), w, loc=(0, 0, 0.765), r=0.0, n=1))
    P.add("Body", box((0.232, 0.232, 0.16), plain("#42a5f5", grime=0.15), loc=(0, 0, 0.12), r=0.0, n=1))
    P.add("Body", words("MOO", 0.08, flat("#1565c0"), loc=(0, -0.117, 0.42), depth=0.006))
    P.add("Body", words("2029", 0.04, flat("#1565c0"), loc=(0, -0.117, 0.34), depth=0.006))
    # the back of the carton: a missing poster, for a robot
    P.add("Body", box((0.16, 0.006, 0.2), plain("#eceae4", grime=0.2), loc=(0, 0.117, 0.38), r=0.0, n=1))
    P.add("Body", words("MISSING", 0.03, flat("#222222"), loc=(0, 0.121, 0.45), rot=(0, 0, 180), depth=0.004))
    P.add("Body", box((0.07, 0.006, 0.07), flat("#4a4d55"), loc=(0, 0.121, 0.36), r=0.0, n=1))


@item("chips_bag", "food")
def chips_bag(P):
    bag = box((0.6, 0.22, 0.7), plain("#8e24aa", grime=0.2), loc=(0, 0, 0.45), r=0.08, n=4)
    warp(bag, lambda v: V((v.x, v.y * (1 - ((v.z - 0.45) / 0.35) ** 4), v.z)))
    crumple(bag, 0.015, 3, seed=3)
    P.add("Body", bag)
    for z in (0.08, 0.82):
        P.add("Body", box((0.62, 0.02, 0.06), plain("#6a1b9a", grime=0.2), loc=(0, 0, z), r=0.005, n=1))
    P.add("Body", words("CRNCHY", 0.1, flat("#ffeb3b"), loc=(0, -0.112, 0.55), depth=0.008))
    P.add("Body", words("EXTRA LOUD", 0.04, flat("#fff6e0"), loc=(0, -0.11, 0.42), depth=0.006))


@item("peanut_butter", "food", pivots={"Lid": (0, 0, 0.36)})
def peanut_butter(P):
    P.add("Body", lathe([(0, 0), (0.14, 0), (0.15, 0.02), (0.15, 0.3), (0.12, 0.34), (0.12, 0.36), (0, 0.36)], plain("#c98b45", grime=0.15), seg=16))
    P.add("Body", lathe([(0, 0.06), (0.153, 0.06), (0.153, 0.26), (0, 0.26)], plain("#fff3c4", grime=0.1), seg=16))
    P.add("Body", box((0.17, 0.01, 0.12), plain("#fff3c4", grime=0.1), loc=(0, -0.152, 0.16), r=0.0, n=1))
    P.add("Body", words("NUTTY", 0.05, flat("#8d4b14"), loc=(0, -0.158, 0.17), depth=0.005))
    P.add("Lid", cyl(0.135, 0.07, plain("#c62828", grime=0.2), loc=(0, 0, 0.395), seg=24, bevel=0.01))


@item("juice_box", "food")
def juice_box(P):
    """A crisp carton brick with flaps folded flat on top, a printed fruit and made-up name, a dented face and a bendy straw."""
    carton = paint("#6da83a", chip=0.12, under="#e8e2d0", under2="#c9c1aa", grime=0.45, streaks=0.3)
    brick = box((0.2, 0.13, 0.33), carton, loc=(0, 0, 0.165), r=0.004, n=3)
    warp(brick, lambda v: V((v.x, v.y + 0.012 * max(0.0, 1 - ((v.x + 0.03) / 0.07) ** 2 - ((v.z - 0.12) / 0.09) ** 2) * (1 if v.y < 0 else 0), v.z)))  # dent
    P.add("Body", brick)
    for sx in (-1, 1):  # top flaps folded down onto the sides
        P.add("Body", slab([(-0.065, 0), (0.065, 0), (0, -0.06)], 0.004, carton, loc=(sx * 0.1015, 0, 0.33), rot=(0, 0, 90)))
    P.add("Body", box((0.2, 0.02, 0.006), carton, loc=(0, 0.055, 0.333), r=0.002, n=1))
    P.add("Body", cyl(0.045, 0.002, plain("#f2c94c", grime=0.3), loc=(0, -0.066, 0.2), rot=(90, 0, 0), seg=12, bevel=0.0))  # printed orange
    P.add("Body", printed("JUICY", 0.032, "#f4f2ee", (0, -0.0665, 0.1)))
    P.add("Body", cyl(0.012, 0.002, metal("#c4c8cc", rust=0.0), loc=(0.05, 0.02, 0.331), seg=10, bevel=0.0))
    straw = plain("#f4f2ee", grime=0.3)
    P.add("Body", box((0.018, 0.018, 0.12), straw, loc=(0.05, 0.02, 0.39), r=0.0, n=1))
    for z in (0.455, 0.47):
        P.add("Body", box((0.019, 0.019, 0.008), plain("#d84315"), loc=(0.05, 0.02, z), r=0.0, n=1))
    P.add("Body", box((0.018, 0.018, 0.06), straw, loc=(0.035, 0.02, 0.495), rot=(0, -35, 0), r=0.0, n=1))


@item("watermelon", "food", size=1024)
def watermelon(P):
    """A slightly squashed oval melon: dark wavy stripes on pale green, a creamy field spot where it sat, a dry stem nub."""
    P.add("Body", lathe([(0, -0.62), (0.2, -0.58), (0.38, -0.42), (0.46, -0.15), (0.47, 0.0), (0.46, 0.15), (0.38, 0.42), (0.2, 0.58), (0, 0.62)],
                        melon_skin(), loc=(0, 0, 0.45), rot=(0, 90, 0), scl=(1, 1, 1), seg=24, lobes=0))
    stem = wood("#8a6a44", "#4a3626", wear=0.6)
    P.add("Body", cyl(0.035, 0.05, stem, loc=(0.625, 0, 0.45), rot=(0, 90, 0), seg=6, bevel=0.008))
    P.add("Body", box((0.05, 0.02, 0.02), stem, loc=(0.655, 0.01, 0.46), rot=(0, 20, 30), r=0.005, n=1))


@item("watermelon_slice", "food")
def watermelon_slice(P):
    skin = [(0.46 * math.cos(math.radians(180 + a)), 0.46 + 0.46 * math.sin(math.radians(180 + a))) for a in range(0, 181, 15)]
    rind = [(0.42 * math.cos(math.radians(180 + a)), 0.46 + 0.42 * math.sin(math.radians(180 + a))) for a in range(0, 181, 15)]
    flesh = [(0.38 * math.cos(math.radians(180 + a)), 0.46 + 0.38 * math.sin(math.radians(180 + a))) for a in range(0, 181, 15)]
    P.add("Body", slab(skin, 0.14, plain("#2e7d32", grime=0.15), loc=(0, 0, 0)))
    P.add("Body", slab(rind, 0.15, plain("#e8f5c8", grime=0.1), loc=(0, 0, 0)))
    P.add("Body", slab(flesh, 0.16, plain("#ef5350", grime=0.1, vary=0.3), loc=(0, 0, 0)))
    for x, z in ((-0.2, 0.36), (-0.07, 0.2), (0.08, 0.3), (0.21, 0.38), (0.0, 0.4), (-0.14, 0.42), (0.14, 0.18)):
        for y in (-0.082, 0.082):
            P.add("Body", box((0.025, 0.006, 0.04), flat("#1d1d1f"), loc=(x, y, z), rot=(0, 20 * x / 0.2, 0), r=0.0, n=1))


@item("cheese_wedge", "food")
def cheese_wedge(P):
    c = plain("#f6c453", grime=0.15, vary=0.3)
    P.add("Body", slab([(-0.25, 0), (0.25, 0), (0.0, 0.45)], 0.2, c, loc=(0, 0, 0.1), rot=(90, 0, 0)))
    P.add("Body", box((0.5, 0.02, 0.2), plain("#e0a83a", grime=0.2), loc=(0, 0.0, 0.1), r=0.0, n=1))
    hole = flat("#c9932c")
    for x, y, r in ((-0.06, -0.18, 0.04), (0.06, -0.3, 0.03), (0.0, -0.08, 0.025)):
        P.add("Body", cyl(r, 0.01, hole, loc=(x, y, 0.2), seg=10, bevel=0.0))


@item("ration_pack", "food")
def ration_pack(P):
    pack = box((0.83, 1.0, 0.17), plain("#6b7a3a", grime=0.35), loc=(0, 0, 0.085), r=0.05, n=3)
    crumple(pack, 0.01, 4, seed=7)
    P.add("Body", pack)
    P.add("Body", box((0.85, 0.06, 0.03), plain("#5a6830", grime=0.3), loc=(0, 0.5, 0.09), r=0.005, n=1))
    P.add("Body", top_words("RATION 29", 0.1, flat("#1e2412"), 0, 0.08, 0.171))
    P.add("Body", top_words("MEAL READY TO EAT", 0.04, flat("#1e2412"), 0, -0.12, 0.171))
    P.add("Body", top_words("EAT ME", 0.06, flat(PAINT_RED), 0.2, -0.32, 0.172))


@item("egg_carton", "food", pivots={"Lid": (0, 0.17, 0.2)})
def egg_carton(P):
    card = plain("#c9c2b4", grime=0.35)
    P.add("Body", box((1.0, 0.34, 0.12), card, loc=(0, 0, 0.06), r=0.03, n=1))
    for i in range(6):
        P.add("Body", ball((0.075, 0.075, 0.1), plain("#f3e3c8", grime=0.1, vary=0.3), loc=(-0.38 + i * 0.152, 0, 0.15), seg=10, rings=7))
    P.add("Lid", box((1.0, 0.34, 0.03), card, loc=(0, 0, 0.215), r=0.02, n=1))
    for i in range(6):
        P.add("Lid", box((0.15, 0.2, 0.05), card, loc=(-0.38 + i * 0.152, 0, 0.245), r=0.03, n=1))
    P.add("Lid", box((0.3, 0.008, 0.06), plain("#f4f2ee", grime=0.2), loc=(0, -0.172, 0.2), r=0.0, n=1))
    P.add("Lid", words("EGGS", 0.035, flat("#4a3a20"), loc=(0, -0.177, 0.2), depth=0.004))


@item("popcorn_bag", "food")
def popcorn_bag(P):
    bag = box((0.67, 0.4, 0.06), plain("#f4f2ee", grime=0.25), loc=(0, 0, 0.03), r=0.02, n=3)
    crumple(bag, 0.006, 4, seed=11)
    P.add("Body", bag)
    P.add("Body", box((0.4, 0.3, 0.004), plain("#e53935", grime=0.15), loc=(0, 0, 0.062), r=0.0, n=1))
    P.add("Body", top_words("POP!", 0.12, flat("#fff6e0"), 0, 0.0, 0.065))
    P.add("Body", top_words("THIS SIDE UP", 0.03, flat("#4a4d55"), 0, -0.17, 0.062))


@item("cupcake", "food")
def cupcake(P):
    P.add("Body", lathe([(0, 0), (0.08, 0), (0.105, 0.15), (0, 0.15)], plain("#4fc3f7", grime=0.15), seg=16, lobes=12, lobe=0.006))
    P.add("Body", lathe([(0, 0.14), (0.115, 0.14), (0.11, 0.19), (0.08, 0.22), (0.085, 0.25), (0.05, 0.28), (0.035, 0.3), (0, 0.31)],
                        plain("#f8bbd0", grime=0.05), seg=16, lobes=6, lobe=0.008))
    P.add("Body", box((0.012, 0.012, 0.08), plain("#f4f2ee"), loc=(0.02, 0, 0.33), r=0.0, n=1))
    P.add("Body", box((0.1, 0.01, 0.075), plain("#eceae4", grime=0.1), loc=(0.02, 0, 0.4), r=0.01, n=1))
    for x in (-0.003, 0.043):
        P.add("Body", box((0.014, 0.012, 0.02), flat("#1d2733"), loc=(x, -0.006, 0.405), r=0.0, n=1))


@item("lunchbox", "food", pivots={"Lid": (0, 0.165, 0.4)})
def lunchbox(P):
    tin = plain("#ef5350", grime=0.35)
    P.add("Body", box((0.83, 0.33, 0.4), tin, loc=(0, 0, 0.2), r=0.04, n=1))
    P.add("Body", box((0.1, 0.02, 0.08), metal("#cfd3d8", rust=0.2), loc=(0, -0.17, 0.38), r=0.01, n=1))
    P.add("Body", box((0.3, 0.008, 0.2), plain("#eceae4", grime=0.25), loc=(-0.15, -0.166, 0.2), r=0.02, n=1))
    P.add("Body", box((0.18, 0.01, 0.1), flat("#1d2733"), loc=(-0.15, -0.171, 0.21), r=0.02, n=1))
    for x in (-0.19, -0.11):
        P.add("Body", box((0.03, 0.012, 0.035), flat("#7cf5e6"), loc=(x, -0.176, 0.22), r=0.0, n=1))
    P.add("Body", words("A+", 0.07, flat("#fff6e0"), loc=(0.2, -0.166, 0.2), depth=0.006))
    P.add("Lid", box((0.85, 0.35, 0.16), plain("#e53935", grime=0.35), loc=(0, 0, 0.48), r=0.05, n=1))
    for x in (-0.18, 0.18):
        P.add("Lid", box((0.05, 0.06, 0.1), plain("#4a4d55"), loc=(x, 0, 0.6), r=0.01, n=1))
    P.add("Lid", box((0.46, 0.07, 0.05), plain("#4a4d55"), loc=(0, 0, 0.67), r=0.02, n=1))


main()
