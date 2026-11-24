import math, os, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "_kit"))
from ykit import *  # noqa

PAINT_RED = "#e8361c"


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
    P.add("Body", box((0.56, 0.26, 0.07), plain("#f2c94c", grime=0.15), r=0.02, n=1))
    for x in (-0.31, 0.31):
        P.add("Body", box((0.07, 0.28, 0.015), plain("#e3b43a", grime=0.15), loc=(x, 0, 0), r=0.005, n=1))
    P.add("Body", box((0.24, 0.01, 0.05), plain("#c0392b", grime=0.1), loc=(0, -0.131, 0.0), r=0.005, n=1))
    P.add("Body", words("CRNCH", 0.035, flat("#fff6e0"), loc=(0, -0.137, 0.0), depth=0.005))


@item("sandwich", "food")
def sandwich(P):
    bread = plain("#e6c48a", grime=0.2)
    crust = plain("#a8743a", grime=0.2)
    tri = [(-0.3, 0), (0.3, 0), (0, 0.42)]
    for z in (0.0, 0.12):
        P.add("Body", slab(tri, 0.07, crust, loc=(0, 0, z), rot=(90, 0, 0), bevel=0.02))
        P.add("Body", slab([(-0.26, 0.025), (0.26, 0.025), (0, 0.38)], 0.072, bread, loc=(0, 0, z), rot=(90, 0, 0)))
    P.add("Body", slab([(-0.31, -0.01), (0.31, -0.01), (0, 0.43)], 0.02, plain("#7cb342", grime=0.1), loc=(0, 0, 0.045), rot=(90, 0, 0)))
    P.add("Body", slab([(-0.28, 0.01), (0.28, 0.01), (0, 0.39)], 0.03, plain("#e57373", grime=0.1), loc=(0, 0, 0.07), rot=(90, 0, 0)))


@item("apple", "food")
def apple(P):
    P.add("Body", lathe([(0, -0.17), (0.1, -0.165), (0.17, -0.1), (0.19, 0.02), (0.16, 0.13), (0.07, 0.16), (0, 0.13)],
                        plain("#c62828", grime=0.15, vary=0.4), seg=16, lobes=5, lobe=0.015))
    P.add("Body", box((0.025, 0.025, 0.1), wood("#5d4037", "#3e2723"), loc=(0, 0, 0.18), rot=(0, 12, 0), r=0.01, n=1))
    P.add("Body", slab([(0, 0), (0.06, 0.03), (0.13, 0), (0.06, -0.03)], 0.01, plain("#558b2f"), loc=(0.02, 0, 0.21), rot=(0, -20, 0)))


@item("water_bottle", "food")
def water_bottle(P):
    P.add("Body", lathe([(0, -0.35), (0.11, -0.35), (0.12, -0.3), (0.12, 0.12), (0.09, 0.22), (0.05, 0.27), (0.05, 0.3), (0, 0.3)],
                        plain("#9fd3e6", grime=0.05, vary=0.15), seg=16, lobes=8, lobe=0.004))
    P.add("Body", cyl(0.055, 0.07, plain("#1e88e5", grime=0.1), loc=(0, 0, 0.33), seg=12, bevel=0.01))
    P.add("Body", cyl(0.123, 0.18, plain("#ffffff", grime=0.1), loc=(0, 0, -0.08), seg=16, bevel=0.0))
    P.add("Body", words("AQUA", 0.06, flat("#1565c0"), loc=(0, -0.126, -0.08)))


@item("energy_drink", "food")
def energy_drink(P):
    P.add("Body", lathe([(0, -0.27), (0.08, -0.27), (0.11, -0.23), (0.11, 0.22), (0.085, 0.27), (0, 0.27)],
                        metal("#39d353", rust=0.0), seg=16))
    P.add("Body", cyl(0.112, 0.2, plain("#111111", grime=0.1), loc=(0, 0, 0.0), seg=16, bevel=0.0))
    P.add("Body", slab([(-0.03, 0.08), (0.02, 0.0), (-0.005, 0.0), (0.03, -0.08), (-0.02, 0.0), (0.005, 0.0)], 0.01,
                       glow("#b9ff3a"), loc=(0, -0.114, 0.0)))
    P.add("Body", box((0.05, 0.02, 0.008), metal("#cfcfcf", rust=0.0), loc=(0.02, 0, 0.272), r=0.004, n=1))


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
    P.add("Body", lathe([(0, 0), (0.11, 0), (0.15, 0.33), (0.155, 0.345), (0, 0.345)], plain("#f4f2ee", grime=0.2), seg=16))
    P.add("Body", lathe([(0, 0.1), (0.128, 0.1), (0.144, 0.26), (0, 0.26)], plain("#d84315", grime=0.15), seg=16))
    P.add("Body", box((0.16, 0.01, 0.07), plain("#fff3c4", grime=0.1), loc=(0, -0.14, 0.18), rot=(-7, 0, 0), r=0.0, n=1))
    P.add("Body", words("RAMEN", 0.045, flat("#b71c1c"), loc=(0, -0.147, 0.18), rot=(-7, 0, 0), depth=0.005))
    P.add("Lid", cyl(0.158, 0.012, metal("#cfd3d8", rust=0.0), loc=(0, 0, 0.352), seg=16, bevel=0.0))
    P.add("Lid", box((0.08, 0.06, 0.008), metal("#cfd3d8", rust=0.0), loc=(0, -0.18, 0.352), r=0.0, n=1))


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
    P.add("Body", box((0.2, 0.13, 0.33), plain("#7cb342", grime=0.2), loc=(0, 0, 0.165), r=0.01, n=1))
    P.add("Body", box((0.12, 0.008, 0.1), plain("#ffeb3b", grime=0.1), loc=(0, -0.066, 0.17), r=0.0, n=1))
    P.add("Body", words("JUICY", 0.035, flat("#33691e"), loc=(0, -0.071, 0.17), depth=0.004))
    P.add("Body", box((0.022, 0.022, 0.16), plain("#f4f2ee", grime=0.1), loc=(0.05, 0.02, 0.38), rot=(0, -12, 0), r=0.0, n=1))
    P.add("Body", box((0.03, 0.03, 0.02), plain("#e0e0e0"), loc=(0.05, 0.02, 0.335), r=0.0, n=1))


@item("watermelon", "food", size=1024)
def watermelon(P):
    P.add("Body", lathe([(0, -0.62), (0.2, -0.58), (0.38, -0.42), (0.46, -0.15), (0.47, 0.0), (0.46, 0.15), (0.38, 0.42), (0.2, 0.58), (0, 0.62)],
                        plain("#2e7d32", grime=0.15, vary=0.5), loc=(0, 0, 0.45), rot=(0, 90, 0), scl=(1, 1, 1), seg=20, lobes=9, lobe=0.012))
    P.add("Body", box((0.07, 0.07, 0.05), plain("#8d6e63"), loc=(0.62, 0, 0.45), rot=(0, 90, 0), r=0.01, n=1))


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
