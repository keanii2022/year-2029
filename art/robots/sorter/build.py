import math, os, sys; sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "_kit")); from kit import *
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from rparts import *  # noqa

# Sorter: a robot built into a store mannequin. Standing still it is just another mannequin in a torn store shirt.
# The tells are small: a chip in the face plate, a hairline seam round the plate, a service hatch low on its back.
# Extra is a faint lens behind the chipped plate plus light leaking round the plate's edge: code shows it only at night.
# DECOY=1 builds sorter_decoy: the same mesh with no Extra, a plain mannequin to stand among the real ones.
DECOY = bool(os.environ.get("DECOY"))
R = Robot("sorter_decoy" if DECOY else "sorter", folder="robots", max_h=5.9)
skin = paint("#ddd6c8", chip=0.35, under="#8d8577", under2="#4a443c", grime=0.5, streaks=0.5)
seam = plain("#6d675e", grime=0.4)
gap = flat("#141210")
joint = steel("#8a8780")
lens = glow("#ff3a24", core="#ffb39c", amount=0.12)

CHEST = [(0.0, 2.55), (0.36, 2.56), (0.44, 2.7), (0.47, 2.95), (0.42, 3.35), (0.47, 3.85), (0.6, 4.3), (0.54, 4.58), (0.2, 4.74), (0.0, 4.76)]
DEPTH = 0.62  # the chest is a flattened lathe, this deep front to back


def chest_r(z):
    for (r0, z0), (r1, z1) in zip(CHEST, CHEST[1:]):
        if z0 <= z <= z1:
            return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
    return 0.0


def segment(a, b, r1, r2, mat, bulge=1.06):
    """A mannequin limb piece from a to b: smooth taper, slightly oval, flat cut ends."""
    L = (V(b) - V(a)).length
    prof = [(0.0, 0.0), (r1 * 0.9, 0.0), (r1, 0.025), (max(r1, r2) * bulge, L * 0.3), (r2, L - 0.025), (r2 * 0.9, L), (0.0, L)]
    return orient([lathe(prof, mat, scl=(1, 0.88, 1), seg=18)], a, b)


def socket(at, r, w, mat):
    """Flat octagonal peg joint across the limb. Octagonal so a limb part alone never ends in a round knob (moderation)."""
    return cyl(r, w, mat, at, (0, 90, 22.5), seg=8, bevel=0.008)


def mannequin_hand(side, at):
    """Smooth display hand, fingers together and gently curled, thumb in. A dark hairline at the wrist."""
    obs = [cyl(0.085, 0.02, gap, (0, 0, -0.01), seg=14, bevel=0.0), cyl(0.08, 0.06, skin, (0, 0, -0.05), seg=14, bevel=0.01)]
    palm = box((0.09, 0.24, 0.26), skin, (0, -0.01, -0.2), r=0.04, n=2)
    warp(palm, lambda v: V((v.x * (1 - 0.3 * (v.z + 0.2)), v.y, v.z)))
    obs.append(palm)
    for i, y in enumerate((-0.085, -0.03, 0.025, 0.08)):
        f = box((0.07, 0.052, 0.24 - abs(i - 1.2) * 0.03), skin, (-side * 0.012, y, -0.43), (side * 10, 0, 0), r=0.024, n=1)
        obs.append(f)
    obs.append(box((0.06, 0.06, 0.15), skin, (-side * 0.05, -0.13, -0.26), (0, 0, side * 22), r=0.025, n=1))
    return move(obs, loc=at)


def plate_outline(w, h, chip=True, seg=40):
    """The face plate edge, with a bite chipped out at the robot's right eye where the lens shows through."""
    pts = []
    for i in range(seg):
        a = math.tau * i / seg
        k = 1.0
        d = math.degrees(a)
        if chip and 150 <= d <= 176:  # robot right is -x, so the chip sits left of centre as you face it
            k = 0.66 + 0.1 * math.sin((d - 150) / 26 * math.pi * 3)
        pts.append((w / 2 * math.cos(a) * k, h / 2 * math.sin(a) * k))
    return pts


def curve_to_face(ob, cx=1.6, cz=0.7):
    """Bends a flat plate back at its edges so it sits on the egg-shaped head."""
    return warp(ob, lambda v: V((v.x, v.y + cx * v.x * v.x + cz * v.z * v.z, v.z)))


# Torso: the mannequin chest with a seam at the waist, a torn store shirt with its price tag still on,
# and a service hatch low on the back where the shirt doesn't reach.
chest = lathe(CHEST, skin, scl=(1, DEPTH, 1), seg=26)
R.add("Torso", chest, torus(0.432, 0.016, seam, (0, 0, 3.32), scl=(1, DEPTH, 1), seg=26, sub=4))
R.add("Torso", cyl(0.14, 0.06, seam, (0, 0, 4.74), seg=16, bevel=0.01))
shirt_c = blend("#3f7f74", "#7d7a70", 0.45)
shirt = lathe([(chest_r(z) * 1.04 + 0.012, z) for z in (3.22, 3.4, 3.6, 3.85, 4.05, 4.3, 4.45, 4.56, 4.66, 4.71)], cloth(shirt_c, dirt=0.7, dirtcolor="#3a352c"),
              scl=(1, DEPTH, 1), seg=26, smooth=60)
lo = 3.22


def torn_hem(v):
    if v.z > lo + 0.01:
        return v
    a = math.atan2(v.y / DEPTH, v.x)
    rip = max(0.0, math.cos(a - math.radians(200))) ** 6 * 0.14  # a long rip up the robot's right hip
    return V((v.x, v.y, v.z + 0.05 * math.sin(a * 5) + 0.035 * math.sin(a * 11 + 1) + 0.02 + rip))


warp(shirt, torn_hem)
R.add("Torso", shirt)
sleeve_cloth = cloth(shirt_c, dirt=0.7, dirtcolor="#3a352c")
collar = torus(0.28, 0.035, cloth(blend(shirt_c, "#2a2a26", 0.25), dirt=0.6), (0, 0, 4.71), scl=(1, DEPTH, 0.6), seg=20, sub=6)
R.add("Torso", collar)
p, n = front(chest, 0.22, 3.3)
R.add("Torso", tube([p + V((0, -0.045, 0.02)), p + V((0.015, -0.07, -0.08)), p + V((0.02, -0.075, -0.14))], 0.006, plain("#e9e2cf", 0.4), seg=4))
tag = [box((0.11, 0.012, 0.16), plain("#e9e2cf", 0.45), (0, 0, 0), r=0.0, n=1), words("50%", 0.04, flat("#a6342b"), (0, -0.008, 0.02)),
       words("OFF", 0.03, flat("#2a2420"), (0, -0.008, -0.035))]
R.add("Torso", move(tag, loc=p + V((0.02, -0.078, -0.22)), rot=(0, 8, -12)))
by = chest_r(2.9) * DEPTH
R.add("Torso", box((0.3, 0.03, 0.2), seam, (0, by - 0.005, 2.92), r=0.01, n=1))
for x in (-0.12, 0.12):
    for z in (2.85, 2.99):
        R.add("Torso", cyl(0.012, 0.02, joint, (x, by + 0.012, z), (90, 0, 0), seg=6, bevel=0.0))
R.add("Torso", move(label("SR-4", 0.035, (0, 0, 0), plain("#cfc8b8", 0.4), "#2a2420"), loc=(0.02, by + 0.03, 2.92), rot=(0, 0, 180)))
R.joint("hip", (0, 0, 2.72))

# Head: neck, a smooth egg head and the face plate. Behind the plate is a dark recess, so a thin dark seam shows
# round its edge and a dark socket shows in the chip. The lens and the light leak live in Extra.
R.add("Head", cyl(0.12, 0.32, skin, (0, 0, 4.9), seg=16, bevel=0.02))
R.add("Head", ball((0.29, 0.32, 0.38), skin, (0, 0.0, 5.22), seg=20, rings=14))
FACE_Y, FACE_Z = -0.305, 5.2
R.add("Head", move(curve_to_face(slab(plate_outline(0.4, 0.52, chip=False), 0.02, gap)), loc=(0, FACE_Y + 0.012, FACE_Z)))
plate = slab(plate_outline(0.38, 0.5), 0.05, skin, bevel=0.012)
crack = [box((0.008, 0.02, 0.13), gap, (-0.07, -0.028, 0.12), (0, 22, 0), r=0.0, n=1),
         box((0.008, 0.02, 0.07), gap, (-0.02, -0.028, 0.03), (0, -28, 0), r=0.0, n=1)]
R.add("Head", move(curve_to_face([plate] + crack), loc=(0, FACE_Y - 0.02, FACE_Z)))
EYE = V((-0.135, FACE_Y + 0.02, FACE_Z + 0.04))
R.add("Head", cyl(0.06, 0.02, joint, EYE + V((0, 0.02, 0)), (90, 0, 0), seg=14, bevel=0.004))
R.joint("neck", (0, 0, 4.76))
if not DECOY:
    rim = move(curve_to_face(slab(plate_outline(0.395, 0.515, chip=False), 0.006, lens)), loc=(0, FACE_Y - 0.006, FACE_Z))
    R.add("Extra", rim, cyl(0.04, 0.012, lens, EYE + V((0, 0.006, 0)), (90, 0, 0), seg=14, bevel=0.003))
    R.joint("extra", EYE)

# Arms hang at the sides with a soft bend, like a display pose. Hands sit in Hand so they can be posed too.
for side in (-1, 1):
    pre = "" if side < 0 else "Left"
    key = (lambda nm: nm) if side < 0 else (lambda nm: "left" + nm[0].upper() + nm[1:])
    s, e, w = V((side * 0.6, 0, 4.48)), V((side * 0.7, 0.02, 3.6)), V((side * 0.74, -0.07, 2.8))
    R.add(pre + "UpperArm", cyl(0.15, 0.2, skin, s, (0, 90, 0), seg=18, bevel=0.04), segment(s, e, 0.13, 0.1, skin),
          socket(e + V((0, 0, 0.035)), 0.105, 0.17, seam))
    # short sleeve closed over the shoulder cap, built hem up, torn at the hem
    sleeve = lathe([(0.168, 0.0), (0.176, 0.1), (0.19, 0.29), (0.175, 0.37), (0.13, 0.41), (0.0, 0.41)], sleeve_cloth, scl=(1, 0.9, 1), seg=18, smooth=60)
    warp(sleeve, lambda v: V((v.x, v.y, v.z + 0.025 * math.sin(math.atan2(v.y, v.x) * 4 + side) - 0.02 if v.z < 0.02 else v.z)))
    R.add(pre + "UpperArm", orient([sleeve], s + (e - s) * 0.33, s))
    R.add(pre + "Forearm", socket(e, 0.095, 0.15, skin), segment(e, w, 0.095, 0.072, skin))
    R.add(pre + "Forearm", orient([cyl(0.1, 0.035, seam, (0, 0, 0.0175), (0, 0, 22.5), seg=8, bevel=0.006)], w + (e - w).normalized() * 0.02, e))
    R.add(pre + "Hand", mannequin_hand(side, w))
    R.joint(key("shoulder"), s)
    R.joint(key("elbow"), e)
    R.joint(key("wrist"), w)
    R.joint(key("grip"), w + V((0, -0.03, -0.28)))

# Legs: straight display legs with peg knees and smooth flat feet.
for x in (-0.25, 0.25):
    pre = "Left" if x > 0 else ""
    H, K, A = V((x, 0, 2.72)), V((x, 0.02, 1.48)), V((x, 0.04, 0.2))
    R.add(pre + "Thigh", cyl(0.2, 0.18, skin, H + V((0, 0, 0.02)), seg=18, bevel=0.05), segment(H, K, 0.2, 0.135, skin, bulge=1.04),
          socket(K + V((0, 0, 0.04)), 0.135, 0.25, seam))
    shin = [socket(K, 0.125, 0.23, skin), segment(K, A, 0.125, 0.075, skin, bulge=1.08)]
    shin.append(cyl(0.085, 0.02, gap, A, seg=14, bevel=0.0))
    foot = box((0.2, 0.52, 0.23), skin, (x, -0.1, 0.115), r=0.07, n=2)
    warp(foot, lambda v: V((v.x, v.y, v.z * (1 - 0.5 * max(0.0, -(v.y + 0.05)) / 0.36) if v.z > 0.04 else v.z)))
    shin.append(foot)
    R.add(pre + "Shin", shin)
    R.joint("leftThigh" if pre else "thigh", H)
    R.joint("leftKnee" if pre else "knee", K)

R.finish(quick="quick" in sys.argv, big=("Head", "Torso"))
