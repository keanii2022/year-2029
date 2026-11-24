import os, sys; sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "_kit")); from kit import *
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from rparts import *  # noqa

# Cook: a slim day bot with a round screen face, a chef hat, an apron and a spatula hand.
R = Robot(night("cook"), folder="robots", max_h=5.6)
white = shell()
line = panel()
dark = rubber()
joint = steel()
mint = accent("#7fd6b5") if NIGHT else plain("#7fd6b5", grime=0.15, vary=0.15)
apron = cloth("#4a2a26", dirt=0.9, weave=70, dirtcolor="#0d0e0c") if NIGHT else cloth("#f07a6a", dirt=0.3, weave=70)
eyes = scanner() if NIGHT else lit("#7ff0ff")

# Torso: pelvis, waist, chest, apron bib and skirt, neck.
R.add("Torso", box((0.92, 0.66, 0.34), joint, (0, 0, 2.25), r=0.08, n=1))
R.add("Torso", cyl(0.32, 0.34, dark, (0, 0, 2.52), seg=6, bevel=0.02))
chest = box((1.3, 0.92, 1.3), white, (0, 0, 3.3), r=0.3, n=2)
warp(chest, lambda v: V((v.x * (0.88 + 0.12 * (v.z - 2.65) / 1.3), v.y, v.z)))
R.add("Torso", chest)
oil(R, "Torso", chest, [(-0.4, 3.85, 0.5), (0.42, 3.7, 0.4)])
cracks(R, "Torso", chest, [(0.4, 3.55)], size=0.9)
fy = -0.46
bib = [(-0.34, 0.0), (0.34, 0.0), (0.38, 0.8), (-0.38, 0.8)]
R.add("Torso", slab(bib, 0.04, apron, (0, fy - 0.03, 2.82), bevel=0.01))
skirt = [(-0.5, 0.0), (0.5, 0.0), (0.4, 0.86), (-0.4, 0.86)]
sk = slab(skirt, 0.04, apron, (0, fy - 0.04, 1.98), bevel=0.01)
warp(sk, lambda v: V((v.x, v.y - 0.12 * (2.84 - v.z), v.z)))
R.add("Torso", sk)
R.add("Torso", box((0.36, 0.03, 0.22), plain("#f6ead8", 0.2), (0, fy - 0.09, 2.45), r=0.02, n=1))
R.add("Torso", box((1.18, 0.08, 0.07), apron, (0, 0, 2.84), r=0.02, n=1))
for x in (-0.3, 0.3):
    R.add("Torso", box((0.07, 0.94, 0.05), apron, (x, 0, 3.92), r=0.0, n=1))
R.add("Torso", box((0.8, 0.03, 0.03), line, (0, fy - 0.005, 3.74), r=0.0, n=1))
R.add("Torso", label("CK-1", 0.1, (0, fy - 0.06, 3.3), mint, "#1f3a30"))
R.add("Torso", cyl(0.18, 0.26, joint, (0, 0, 4.06), seg=6, bevel=0.02))
for x in (-0.66, 0.66):
    R.add("Torso", cyl(0.2, 0.1, dark, (x, 0, 3.72), (0, 90, 0), seg=6, bevel=0.01))
R.joint("hip", (0, 0, 2.2))

# Head: round shell, round screen, chef hat. Happy ^ ^ eyes go in Extra.
R.add("Head", box((1.1, 0.95, 0.92), white, (0, 0, 4.6), r=0.4, n=2))
R.add("Head", cyl(0.36, 0.06, screen(), (0, -0.47, 4.58), (90, 0, 0), seg=18, bevel=0.02))
R.add("Head", cyl(0.4, 0.04, mint, (0, -0.45, 4.58), (90, 0, 0), seg=18, bevel=0.01))
hat = lathe([(0, 0), (0.4, 0), (0.42, 0.28), (0.55, 0.4), (0.58, 0.56), (0.45, 0.68), (0, 0.7)], cloth("#3a3632", 0.9, dirtcolor="#0d0e0c") if NIGHT else cloth("#f4f1ea", 0.2), (0, 0, 5.02),
            seg=18, lobes=6, lobe=0.07)
R.add("Head", hat, cyl(0.43, 0.12, line, (0, 0, 5.08), seg=18, bevel=0.02))
for x in (-0.15, 0.15):
    if NIGHT:  # happy ^ ^ eyes become slanted angry slits
        R.add("Extra", box((0.2, 0.04, 0.055), eyes, (x, -0.51, 4.66), (0, 24 if x < 0 else -24, 0), r=0.02, n=1))
        continue
    for t in (-1, 1):
        R.add("Extra", box((0.13, 0.04, 0.045), eyes, (x + t * 0.045, -0.51, 4.64), (0, t * 35, 0), r=0.02, n=1))
R.add("Extra", box((0.16, 0.04, 0.04), eyes, (0, -0.51, 4.44), r=0.02, n=1))
R.joint("neck", (0, 0, 4.13))
R.joint("extra", (0, -0.51, 4.58))

# Spatula hand: a gripper block holding a flat handle, flat slotted blade.
spat = [cyl(0.15, 0.14, joint, (0, 0, -0.07), seg=6, bevel=0.01)]
spat.append(box((0.26, 0.34, 0.3), white, (0, 0, -0.28), r=0.06, n=1))
spat.append(box((0.3, 0.2, 0.14), dark, (0, -0.06, -0.4), r=0.03, n=1))
spat += limb((0, -0.06, -0.3), (0, -0.28, -0.88), 0.09, 0.05, wood("#c7955e", "#8a5a30"), 0.08, 0.04, r=0.01)
spat += limb((0, -0.28, -0.86), (0, -0.4, -1.22), 0.26, 0.03, steel("#a9aeb4"), 0.34, 0.03, r=0.01)
if NIGHT:  # blade edge chewed into teeth
    for x in (-0.12, 0.0, 0.12):
        spat.append(move(slab([(-0.05, 0), (0.05, 0), (0, -0.12)], 0.03, steel("#a9aeb4"), bevel=0.0), rot=(-18, 0, 0), loc=(x, -0.41, -1.25)))
for x in (-0.07, 0.07):
    spat += limb((x, -0.31, -0.95), (x, -0.385, -1.15), 0.035, 0.035, dark, 0.035, 0.035, r=0.0)
move(spat, loc=(-0.92, -0.14, 2.3))
arm(R, -1, (-0.82, 0, 3.72), (-0.9, -0.02, 3.0), (-0.92, -0.14, 2.3), 0.27, 0.32, white, joint, spat, stripe=mint, grip=(-0.06, -0.4))
arm(R, 1, (0.82, 0, 3.72), (0.9, -0.02, 3.0), (0.92, -0.14, 2.3), 0.27, 0.32, white, joint,
    claw(1, (0.92, -0.14, 2.3), white, dark, size=0.85), stripe=mint)

for x in (-0.34, 0.34):
    leg(R, x, (0, 2.15), (-0.04, 1.35), (0.02, 0.55), 0.3, 0.36, white, joint, stripe=mint, foot_size=(0.5, 0.9, 0.32))

R.finish(quick="quick" in sys.argv, big=("Head",))
