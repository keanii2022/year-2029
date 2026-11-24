import os, sys; sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "_kit")); from kit import *
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from rparts import *  # noqa

# Carrier: a square, sturdy day bot with box forearms, lift paddle hands and a flat rack on its back.
R = Robot(night("carrier"), folder="robots", max_h=5.9)
white = shell()
line = panel()
dark = rubber()
joint = steel()
yellow = accent("#f2c94c") if NIGHT else plain("#f2c94c", grime=0.2, vary=0.15)
sky = accent("#6fb7e8") if NIGHT else plain("#6fb7e8", grime=0.15, vary=0.15)
eyes = scanner() if NIGHT else lit("#7ff0ff")

# Torso: pelvis, waist, square chest, neck, back rack with a taped box on it.
R.add("Torso", box((1.15, 0.8, 0.38), joint, (0, 0, 2.42), r=0.08, n=1))
R.add("Torso", cyl(0.4, 0.34, dark, (0, 0, 2.7), seg=6, bevel=0.02))
body = box((1.7, 1.1, 1.45), white, (0, 0, 3.55), r=0.18, n=2)
R.add("Torso", body)
oil(R, "Torso", body, [(-0.6, 4.1, 0.6), (0.55, 3.95, 0.45)])
cracks(R, "Torso", body, [(-0.45, 3.4)], size=1.2)
fy = -0.55
R.add("Torso", box((1.3, 0.03, 0.03), line, (0, fy - 0.005, 3.95), r=0.0, n=1))
R.add("Torso", box((1.3, 0.03, 0.03), line, (0, fy - 0.005, 3.1), r=0.0, n=1))
R.add("Torso", box((0.03, 0.03, 0.82), line, (-0.3, fy - 0.005, 3.52), r=0.0, n=1))
for i in range(5):
    R.add("Torso", box((0.1, 0.05, 0.36), yellow if i % 2 else dark, (0.15 + i * 0.1, fy - 0.01, 3.52), r=0.0, n=1))
R.add("Torso", label("CR-7", 0.11, (-0.62, fy - 0.01, 3.75), sky, "#1e2a36"))
R.add("Torso", cyl(0.22, 0.24, joint, (0, 0, 4.36), seg=6, bevel=0.02))
for x in (-0.86, 0.86):
    R.add("Torso", cyl(0.24, 0.1, dark, (x, 0, 3.95), (0, 90, 0), seg=6, bevel=0.01))
for x in (-0.62, 0.62):
    R.add("Torso", box((0.1, 0.1, 1.7), joint, (x, 0.72, 3.5), r=0.02, n=1))
    for z in (3.0, 4.0):
        R.add("Torso", box((0.1, 0.22, 0.1), joint, (x, 0.6, z), r=0.0, n=1))
R.add("Torso", box((1.44, 0.7, 0.07), joint, (0, 0.98, 2.72), r=0.02, n=1))
R.add("Torso", box((1.44, 0.08, 0.1), yellow, (0, 1.3, 2.8), r=0.02, n=1))
R.add("Torso", box((1.34, 0.1, 0.1), joint, (0, 0.74, 4.3), r=0.02, n=1))
crate = box((0.95, 0.55, 0.62), cardboard(), (0, 1.0, 3.07), r=0.03, n=2)
crumple(crate, 0.04 if NIGHT else 0.015, 3)
R.add("Torso", crate)
if NIGHT:  # the box it was carrying, torn open
    for x, lean in ((-0.4, -35), (0.4, 35)):
        R.add("Torso", box((0.04, 0.5, 0.32), cardboard(), (x, 1.0, 3.48), (0, lean, 0), r=0.0, n=1))
R.add("Torso", box((0.97, 0.18, 0.04), plain("#cdb98a", 0.4), (0, 1.0, 3.39), r=0.0, n=1))
R.add("Torso", box((0.04, 0.57, 0.66), dark, (0, 1.0, 3.07), r=0.0, n=1))
R.joint("hip", (0, 0, 2.35))

# Head: low and wide with a visor screen. The eyes go in Extra.
R.add("Head", box((1.2, 0.85, 0.7), white, (0, 0, 4.78), r=0.22, n=2))
R.add("Head", box((1.0, 0.06, 0.34), screen(), (0, -0.425, 4.76), r=0.08, n=1))
R.add("Head", box((1.1, 0.5, 0.06), yellow, (0, 0, 5.13), r=0.03, n=1))
for x in (-1, 1):
    R.add("Head", box((0.08, 0.4, 0.34), joint, (x * 0.63, 0, 4.78), r=0.03, n=1))
if NIGHT:  # both eyes merge into one thin scanning bar
    R.add("Extra", box((0.86, 0.04, 0.07), eyes, (0, -0.46, 4.77), r=0.02, n=1))
else:
    for x in (-0.24, 0.24):
        R.add("Extra", box((0.2, 0.04, 0.17), eyes, (x, -0.46, 4.77), r=0.05, n=1))
R.joint("neck", (0, 0, 4.42))
R.joint("extra", (0, -0.46, 4.77))


def paddle(side, at):
    """Lift paddle: a ribbed plate with a rubber pad on the inside and a lip under it."""
    k = -side
    obs = [cyl(0.17, 0.14, joint, (0, 0, -0.07), seg=6, bevel=0.01)]
    obs.append(box((0.3, 0.34, 0.18), joint, (0, 0, -0.2), r=0.04, n=1))
    obs.append(box((0.12, 0.62, 0.66), white, (k * 0.02, -0.02, -0.6), r=0.04, n=1))
    obs.append(box((0.05, 0.54, 0.56), dark, (k * 0.1, -0.02, -0.6), r=0.02, n=1))
    for z in (-0.42, -0.6, -0.78):
        obs.append(box((0.04, 0.5, 0.06), line, (-k * 0.07, -0.02, z), r=0.0, n=1))
    obs.append(box((0.3, 0.62, 0.08), yellow, (k * 0.12, -0.02, -0.95), r=0.03, n=1))
    if NIGHT:  # bent scrap prongs along the lip
        for y in (-0.24, -0.02, 0.2):
            obs.append(slab([(-0.06, 0), (0.06, 0), (0, -0.2)], 0.04, joint, loc=(k * 0.12, y, -0.99), rot=(0, 0, 90), bevel=0.0))
    return move(obs, loc=at)


# Arms: box forearms held forward, ready to carry.
for side in (-1, 1):
    s, e, w = (side * 1.05, 0, 3.95), (side * 1.15, 0.05, 3.18), (side * 1.12, -0.4, 2.62)
    arm(R, side, s, e, w, 0.36, 0.42, white, joint, paddle(side, w), stripe=sky, fore=1.2, grip=(0, -0.6))

for x in (-0.45, 0.45):
    leg(R, x, (0, 2.3), (-0.05, 1.45), (0.02, 0.6), 0.38, 0.44, white, joint, stripe=sky, foot_size=(0.6, 1.0, 0.36))

# laid out at about 5.2 studs, grown to about 5.7
for obs in R.parts.values():
    move(obs, scl=1.1)
for k in R.joints:
    R.joints[k] *= 1.1
R.finish(quick="quick" in sys.argv, big=("Head",))
