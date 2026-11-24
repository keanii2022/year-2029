import os, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "_kit"))
from ykit import *  # noqa

# First-person pieces, shown close to the camera. Forward is -y, like the guns.
LIGHT = "#2bb3a8"  # starter_pistol ammo color, matches gear/build.py
WHITE = "#ecebe6"
GREY = "#9aa0a4"
DARK = "#2b2d31"
ORANGE = "#f07f2a"

ARM_X = 0.06  # forearm axis, a little toward the back of the hand so the fist sits in front of the wrist
ELBOW_Y = 1.3
ARM_PIVOT = (ARM_X, ELBOW_Y, 0.02)


def leather():
    return paint("#a8875c", chip=0.22, under="#6e5236", under2="#4a3524", grime=0.6, streaks=0.15)


def oily():
    return plain("#3a3026", grime=0.4, vary=0.3)


def canvas():
    return cloth("#6d6c47", dirt=0.5, dirtcolor="#3d3826")


def lit(color):
    """Glow parts are one flat color: Roblox swaps them between Neon and dull."""
    return glow(color, amount=0.0)


def marker(loc):
    """Hidden 0.08 cube the game code reads for a position."""
    return box((0.08, 0.08, 0.08), flat("#34322f"), loc=loc, r=0.0, n=1)


def bar(a, b, w, h, mat, r=0.03, extra=0.05):
    """Box from a to b, w wide sideways and h tall. extra makes neighbours overlap at the joints."""
    a, b = V(a), V(b)
    d = b - a
    yaw = math.degrees(math.atan2(d.y, d.x))
    pitch = math.degrees(math.asin(d.z / d.length))
    return box((d.length + extra, w, h), mat, loc=(a + b) / 2, rot=(0, -pitch, yaw), r=r, n=1)


def dashes(a, b, n, mat, top=True):
    """Stitch dashes along a seam line, lying on a top face (or a +x face)."""
    a, b = V(a), V(b)
    size = (0.012, 0.03, 0.006) if top else (0.006, 0.03, 0.012)
    return [box(size, mat, loc=a.lerp(b, (i + 0.5) / n), r=0.0, n=1) for i in range(n)]


def sleeve(side_seed=0):
    """Faded canvas forearm from the glove cuff back to the elbow, with a rolled, frayed cuff."""
    obs = []
    arm = box((0.4, ELBOW_Y - 0.15, 0.38), canvas(), loc=(ARM_X, (ELBOW_Y + 0.15) / 2, 0.02), r=0.08, n=2, smooth=40)
    warp(arm, lambda v: V((ARM_X + (v.x - ARM_X) * (1 + 0.16 * (v.y - 0.15)), v.y, 0.02 + (v.z - 0.02) * (1 + 0.14 * (v.y - 0.15)))))
    crumple(arm, 0.014, 3.5, seed=side_seed)
    obs.append(arm)
    roll = cloth("#7a7852", dirt=0.55, dirtcolor="#3d3826")
    obs.append(crumple(box((0.47, 0.09, 0.45), roll, loc=(ARM_X, 0.2, 0.02), r=0.04, n=1), 0.01, 6, seed=side_seed + 1))
    obs.append(crumple(box((0.455, 0.09, 0.435), roll, loc=(ARM_X, 0.285, 0.02), r=0.04, n=1), 0.01, 6, seed=side_seed + 2))
    thread = plain("#9a9670", grime=0.4)
    # frayed threads hanging off the front edge of the roll
    for x, z, ang in ((-0.12, 0.24, 20), (0.0, 0.245, -15), (0.15, 0.24, 30), (0.27, 0.12, 80), (0.27, -0.06, 100),
                      (-0.17, -0.1, -80), (0.1, -0.2, 160), (-0.06, -0.2, 200)):
        obs.append(box((0.035, 0.05, 0.007), thread, loc=(ARM_X + x * 0.95, 0.148, 0.02 + z * 0.92), rot=(25, 0, ang), r=0.0, n=1))
    return obs


def gauntlet(tab_top=True):
    """Glove cuff at the wrist with a strap and a velcro tab."""
    strap = plain("#7a5a3a", grime=0.5)
    obs = [box((0.36, 0.26, 0.34), leather(), loc=(ARM_X, 0.08, 0.0), r=0.05, n=1),
           box((0.385, 0.09, 0.365), strap, loc=(ARM_X, 0.04, 0.0), r=0.03, n=1)]
    velcro = plain("#34332f", grime=0.2, vary=0.4)
    if tab_top:
        obs += [box((0.17, 0.11, 0.025), velcro, loc=(ARM_X + 0.04, 0.04, 0.19), r=0.008, n=1),
                box((0.03, 0.08, 0.035), strap, loc=(ARM_X + 0.135, 0.04, 0.188), r=0.008, n=1)]
    else:
        obs += [box((0.025, 0.11, 0.17), velcro, loc=(ARM_X + 0.2, 0.04, 0.02), r=0.008, n=1),
                box((0.035, 0.08, 0.03), strap, loc=(ARM_X + 0.198, 0.04, 0.115), r=0.008, n=1)]
    return obs


def fist():
    """Right hand closed round an empty space 0.35 across, standing up along z at GRIP. Thumb over the index."""
    G = V((0, -0.3, 0))
    rc = 0.23
    obs = [box((0.13, 0.44, 0.42), leather(), loc=(0.235, -0.2, 0.0), r=0.05, n=1),
           box((0.4, 0.16, 0.4), leather(), loc=(0.02, -0.06, -0.02), r=0.05, n=1)]

    def at(deg, z):
        a = math.radians(deg)
        return G + V((rc * math.cos(a), rc * math.sin(a), z))

    for i, z in enumerate((0.152, 0.051, -0.05, -0.15)):
        end = -165 if i < 3 else -150
        obs.append(bar(at(-15, z), at(-65, z), 0.11, 0.095, leather()))
        obs.append(bar(at(-65, z), at(-115, z), 0.105, 0.093, leather()))
        obs.append(bar(at(-115, z), at(end, z), 0.1, 0.09, oily()))
    obs.append(bar((-0.1, -0.09, 0.1), (-0.29, -0.25, 0.17), 0.13, 0.125, leather()))
    obs.append(bar((-0.29, -0.25, 0.17), (-0.26, -0.46, 0.175), 0.115, 0.11, oily()))
    seam = plain("#6e5236", grime=0.4)
    thread = plain("#d8cfb4", grime=0.3)
    obs.append(box((0.022, 0.36, 0.014), seam, loc=(0.22, -0.2, 0.211), r=0.005, n=1))
    obs += dashes((0.198, -0.37, 0.215), (0.198, -0.03, 0.215), 6, thread)
    obs += dashes((0.242, -0.37, 0.215), (0.242, -0.03, 0.215), 6, thread)
    return obs, G


def open_hand():
    """Right hand open, palm up, fingers a little cupped. Returns the parts and the point just above the palm."""
    obs = [box((0.4, 0.42, 0.13), leather(), loc=(ARM_X, -0.19, 0.0), r=0.05, n=1)]
    for dx, k in ((0.135, 0.95), (0.045, 1.0), (-0.045, 0.97), (-0.135, 0.82)):
        x = ARM_X + dx
        a, b, c, d = (x, -0.36, 0.0), (x, -0.36 - 0.15 * k, 0.025), (x, -0.36 - 0.27 * k, 0.065), (x, -0.36 - 0.37 * k, 0.115)
        obs.append(bar(a, b, 0.086, 0.1, leather()))
        obs.append(bar(b, c, 0.084, 0.095, leather()))
        obs.append(bar(c, d, 0.08, 0.09, oily()))
    obs.append(bar((ARM_X + 0.17, -0.08, 0.0), (ARM_X + 0.29, -0.25, 0.05), 0.12, 0.11, leather()))
    obs.append(bar((ARM_X + 0.29, -0.25, 0.05), (ARM_X + 0.32, -0.4, 0.1), 0.105, 0.1, oily()))
    patch = plain("#8a6a44", grime=0.55)
    thread = plain("#d8cfb4", grime=0.3)
    obs.append(box((0.3, 0.28, 0.014), patch, loc=(ARM_X, -0.2, 0.068), r=0.006, n=1))
    for x in (-0.135, 0.135):
        obs += dashes((ARM_X + x, -0.32, 0.077), (ARM_X + x, -0.08, 0.077), 5, thread)
    return obs, V((ARM_X, -0.2, 0.14))


def flip(obs, left):
    if left:
        move(obs, scl=(-1, 1, 1))
    return obs


def glove_fist(P, left):
    hand, grip_at = fist()
    obs = flip(sleeve(2 if left else 0) + gauntlet() + hand, left)
    P.add("Body", obs)
    P.add("Grip", marker((-grip_at.x if left else grip_at.x, grip_at.y, grip_at.z)))


@item("viewmodel_arm_right", "viewmodel", pivots={"Body": ARM_PIVOT})
def viewmodel_arm_right(P):
    """Right forearm, sleeve and gloved fist. Body's pivot is the elbow end of the sleeve, so the code swings the arm from there.
    Grip is the hidden cube in the middle of the fist's hole."""
    glove_fist(P, left=False)


@item("viewmodel_arm_left", "viewmodel", pivots={"Body": (-ARM_PIVOT[0], ARM_PIVOT[1], ARM_PIVOT[2])})
def viewmodel_arm_left(P):
    """Mirror of viewmodel_arm_right. Body's pivot is the elbow end of the sleeve. Grip is the hidden cube in the fist's hole."""
    glove_fist(P, left=True)


@item("viewmodel_arm_left_open", "viewmodel", pivots={"Body": (-ARM_PIVOT[0], ARM_PIVOT[1], ARM_PIVOT[2])})
def viewmodel_arm_left_open(P):
    """Left forearm with the hand open, palm up, for resting a bandage or a can. Body's pivot is the elbow end of the sleeve.
    Grip is the hidden cube floating just above the palm centre."""
    hand, rest = open_hand()
    P.add("Body", flip(sleeve(4) + gauntlet(tab_top=False) + hand, True))
    P.add("Grip", marker((-rest.x, rest.y, rest.z)))


@item("viewmodel_blaster", "viewmodel")
def viewmodel_blaster(P):
    """First-person starter_pistol: same size and colors, crisper edges, more on the top and back.
    Muzzle is the hidden cube at the barrel tip, Grip the one at the handle centre (where viewmodel_arm_right's Grip goes)."""
    worn = paint(WHITE, chip=0.25, under="#8d8f92", under2="#5d6064", grime=0.6, streaks=0.3)
    g = plain(GREY, grime=0.5)
    dark = plain(DARK)
    steel = plain("#3a3c40", grime=0.2)
    P.add("Body", box((0.22, 0.86, 0.22), worn, loc=(0, -0.04, 0.62), r=0.025, n=1))
    P.add("Body", box((0.2, 0.72, 0.12), g, loc=(0, -0.02, 0.46), r=0.018, n=1))
    P.add("Body", box((0.25, 0.1, 0.2), g, loc=(0, -0.5, 0.6), r=0.015, n=1))
    P.add("Body", cyl(0.055, 0.07, steel, loc=(0, -0.58, 0.61), rot=(90, 0, 0), seg=6, bevel=0.006))
    P.add("Body", cyl(0.03, 0.01, flat("#0c0c0e"), loc=(0, -0.617, 0.61), rot=(90, 0, 0), seg=6, bevel=0.0))
    P.add("Body", box((0.17, 0.23, 0.46), plain(DARK, grime=0.25, vary=0.15), loc=(0, 0.22, 0.22), rot=(14, 0, 0), r=0.03, n=1))
    P.add("Body", box((0.12, 0.17, 0.44), plain(LIGHT, grime=0.3), loc=(0, 0.225, 0.24), rot=(14, 0, 0), r=0.015, n=1))
    P.add("Body", box((0.2, 0.27, 0.05), plain(ORANGE, grime=0.4), loc=(0, 0.28, 0.0), rot=(14, 0, 0), r=0.012, n=1))
    P.add("Body", box((0.185, 0.245, 0.07), plain("#cdb98a", grime=0.55), loc=(0, 0.21, 0.27), rot=(14, 0, 0), r=0.008, n=1))
    P.add("Body", [box((0.05, 0.26, 0.035), g, loc=(0, -0.09, 0.3), r=0.01, n=1),
                   box((0.05, 0.035, 0.13), g, loc=(0, -0.21, 0.36), r=0.01, n=1),
                   box((0.035, 0.035, 0.09), plain(ORANGE, grime=0.2), loc=(0, -0.06, 0.37), rot=(-15, 0, 0), r=0.008, n=1)])
    # rear sight: two posts with a notch that lines up with the orange front dot
    P.add("Body", box((0.17, 0.06, 0.03), dark, loc=(0, 0.33, 0.745), r=0.008, n=1))
    for sx in (1, -1):
        P.add("Body", box((0.05, 0.06, 0.06), dark, loc=(sx * 0.06, 0.33, 0.775), r=0.008, n=1))
    P.add("Body", box((0.05, 0.05, 0.05), plain(ORANGE), loc=(0, -0.42, 0.75), r=0.01, n=1))
    P.add("Body", box((0.04, 0.3, 0.006), flat("#3a3c40"), loc=(0, -0.13, 0.731), r=0.0, n=1))
    for i in range(5):
        P.add("Body", box((0.15, 0.012, 0.01), g, loc=(0, 0.12 + 0.03 * i, 0.733), r=0.002, n=1))
    P.add("Body", box((0.005, 0.11, 0.004), flat("#6c6e70"), loc=(0.05, -0.3, 0.731), rot=(0, 0, 14), r=0.0, n=1))
    # back plate the player looks at down the sights
    P.add("Body", box((0.16, 0.012, 0.15), g, loc=(0, 0.394, 0.62), r=0.004, n=1))
    P.add("Body", [bolt(0.014, loc=(sx * 0.06, 0.401, z), normal=(0, 1, 0)) for sx in (1, -1) for z in (0.565, 0.675)])
    P.add("Body", cyl(0.03, 0.02, dark, loc=(0, 0.405, 0.62), rot=(90, 0, 0), seg=6, bevel=0.004))
    for sx in (1, -1):
        P.add("Glow", box((0.012, 0.34, 0.025), lit(LIGHT), loc=(sx * 0.111, -0.18, 0.66), r=0.004, n=1))
    hz = slab([(-0.1, -0.04), (0.1, -0.04), (0.1, 0.04), (-0.1, 0.04)], 0.01, flat("#f2c230"))
    stripes = [slab([(x0, -0.04), (min(x0 + 0.033, 0.1), -0.04), (min(x0 + 0.033 + 0.056, 0.1), 0.04), (min(x0 + 0.056, 0.1), 0.04)], 0.016, flat("#1e1e22"))
               for x0 in (-0.1, -0.033, 0.033)]
    P.add("Body", aim([hz] + stripes, (0.112, 0.2, 0.6), (1, 0, 0)))
    P.add("Body", [bolt(0.018, loc=p, normal=(1 if p[0] > 0 else -1, 0, 0)) for p in ((0.111, 0.08, 0.56), (0.111, -0.36, 0.56), (-0.111, 0.08, 0.56))])
    P.add("Body", box((0.006, 0.12, 0.05), flat("#6c6e70"), loc=(0.112, -0.32, 0.67), rot=(18, 0, 0), r=0.0, n=1))
    P.add("Muzzle", marker((0, -0.615, 0.61)))
    P.add("Grip", marker((0, 0.22, 0.22)))


def burst(scale, depth, mat):
    """Star-burst card in the x-z plane, back point at z = 0, longest spikes forward (+z)."""
    poly = []
    n = 9
    for i in range(2 * n):
        a = math.pi * i / n
        fwd = math.cos(a)
        reach = 0.3 + 0.6 * max(fwd, 0) + 0.07 * (1 - abs(fwd)) if i % 2 == 0 else 0.11 + 0.05 * max(fwd, 0)
        poly.append((math.sin(a) * reach * scale * 1.0, 0.3 * scale + fwd * reach * scale))
    return slab(poly, depth, mat)


@item("muzzle_flash", "viewmodel", pivots={"Glow": (0, 0, 0)})
def muzzle_flash(P):
    """Three crossed star-burst cards pointing along -y. Glow's pivot is the back centre, so it attaches at the gun's Muzzle."""
    for spin in (0, 60, 120):
        cards = [burst(1.0, 0.01, lit("#ff8a2a")), burst(0.6, 0.02, lit("#ffc95a")), burst(0.32, 0.03, lit("#fff4c8"))]
        # inner cards share the outer card's back point, so the hot core sits near the muzzle
        P.add("Glow", move(cards, rot=(90, spin, 0)))


main()
