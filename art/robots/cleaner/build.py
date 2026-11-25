import os, sys; sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "_kit")); from kit import *
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from rparts import *  # noqa

# Cleaner: a round friendly day bot with a vacuum head for a right hand and a tank on its back.
R = Robot(night("cleaner"), folder="robots", max_h=5.6)
white = shell()
line = panel()
dark = rubber()
joint = steel()
teal = accent("#2fb8a8")
orange = accent("#f28c38")
eyes = scanner() if NIGHT else lit("#7ff0ff")

# Torso: pelvis, hex waist, rounded chest, neck, tank on the back.
R.add("Torso", box((1.0, 0.72, 0.36), joint, (0, 0, 2.27), r=0.08, n=1))
R.add("Torso", cyl(0.36, 0.34, dark, (0, 0, 2.55), seg=6, bevel=0.02))
chest = box((1.5, 1.05, 1.35), white, (0, 0, 3.33), r=0.3, n=2)
warp(chest, lambda v: V((v.x * (0.9 + 0.1 * (v.z - 2.65) / 1.35), v.y, v.z)))
R.add("Torso", chest)
fy = -0.525
R.add("Torso", box((0.9, 0.03, 0.03), line, (0, fy - 0.005, 3.62), r=0.0, n=1))
R.add("Torso", box((0.03, 0.03, 0.62), line, (0, fy - 0.005, 3.28), r=0.0, n=1))
R.add("Torso", box((0.62, 0.04, 0.36), teal, (0, fy - 0.01, 2.94), r=0.06, n=1))
R.add("Torso", box((0.4, 0.05, 0.05), dark, (0, fy - 0.03, 2.94), r=0.0, n=1))
oil(R, "Torso", chest, [(-0.4, 3.75, 0.55), (0.3, 3.5, 0.4), (0.5, 3.85, 0.7)])
cracks(R, "Torso", chest, [(-0.3, 3.55), (0.45, 3.3)])
R.add("Torso", label("CL-2", 0.11, (0.36, fy - 0.01, 3.82), orange, "#2a2420"))
# A faded store vest scrap tied round its chest, with a name tag nobody ever filled in
vest = cloth(blend("#8a2f2a", "#5a514a", 0.45) if not NIGHT else "#2e2422", dirt=0.75, dirtcolor="#2d2620")
rag = [(-0.62, 0), (-0.2, -0.06), (0.25, 0.02), (0.62, -0.04), (0.6, 0.42), (0.1, 0.38), (-0.6, 0.44)]
p, n = front(chest, 0, 3.2)
R.add("Torso", aim(slab(rag, 0.03, vest), p + n * 0.015 + V((0, 0, -0.2)), n))
R.add("Torso", label("HI, I'M", 0.05, (-0.3, fy - 0.07, 3.2), plain("#e9e2cf", 0.45), "#2a2420", w=0.3))
R.add("Torso", box((0.24, 0.02, 0.012), flat("#2a2420"), (-0.3, fy - 0.095, 3.15), r=0.0, n=1))
R.add("Torso", cyl(0.2, 0.26, joint, (0, 0, 4.07), seg=6, bevel=0.02))
for x in (-0.76, 0.76):
    R.add("Torso", cyl(0.22, 0.1, dark, (x, 0, 3.75), (0, 90, 0), seg=6, bevel=0.01))
tank = [cyl(0.3, 0.95, teal, (0, 0.74, 3.3), seg=12, bevel=0.04)] + [cyl(0.33, 0.1, joint, (0, 0.74, z), seg=12, bevel=0.02) for z in (2.82, 3.78)]
R.add("Torso", move(tank, rot=(0, 9, 0), pivot=(0, 0.74, 3.78)))  # the tank hangs crooked off one strap
R.add("Torso", box((0.5, 0.2, 0.12), joint, (0, 0.55, 3.3), r=0.02, n=1))
R.joint("hip", (0, 0, 2.2))

# Head: rounded shell with a screen face, ear pods. Eyes go in Extra for the night glow.
R.add("Head", box((1.25, 1.0, 0.9), white, (0, 0, 4.62), r=0.32, n=2))
R.add("Head", box((0.95, 0.06, 0.6), screen(), (0, -0.5, 4.6), r=0.12, n=1))
R.add("Head", box((0.7, 0.03, 0.03), line, (0, -0.505, 5.0), r=0.0, n=1))
# the screen is cracked down its right side
for k, (x, z, a) in enumerate(((-0.3, 4.82, 25), (-0.27, 4.66, -30), (-0.31, 4.5, 20), (-0.28, 4.36, -25))):
    R.add("Head", box((0.014, 0.02, 0.17), plain("#a9adb0", grime=0.3), (x, -0.535, z), (0, a, 0), r=0.0, n=1))
for x in (-1, 1):
    R.add("Head", cyl(0.22, 0.12, teal, (x * 0.66, 0, 4.62), (0, 90, 0), seg=12, bevel=0.03))
    R.add("Head", cyl(0.12, 0.16, dark, (x * 0.68, 0, 4.62), (0, 90, 0), seg=6, bevel=0.01))
if NIGHT:  # slanted angry slits and a jagged grin instead of the friendly face
    for x in (-0.2, 0.2):
        R.add("Extra", box((0.24, 0.04, 0.07), eyes, (x, -0.54, 4.68), (0, 22 if x < 0 else -22, 0), r=0.02, n=1))
    for i in range(5):
        R.add("Extra", box((0.08, 0.04, 0.05), eyes, (-0.2 + i * 0.1, -0.54, 4.44 + (0.03 if i % 2 else -0.02)), (0, 40 if i % 2 else -40, 0), r=0.0, n=1))
else:
    for x in (-0.2, 0.2):  # the cracked side's eye has slipped down a little
        R.add("Extra", box((0.15, 0.04, 0.24), eyes, (x, -0.54, 4.64 - (0.05 if x < 0 else 0)), r=0.07, n=1))
    R.add("Extra", box((0.22, 0.04, 0.05), eyes, (0.02, -0.54, 4.42), (0, -6, 0), r=0.02, n=1))
R.joint("neck", (0, 0, 4.15))
extra = V((0, -0.54, 4.6))
if NIGHT:  # head cocked to one side, like it heard you
    move(R.parts["Head"] + R.parts["Extra"], rot=(0, 18, 0), pivot=(0, 0, 4.15))
    extra = V((0, 0, 4.15)) + Euler((0, math.radians(18), 0)).to_matrix() @ (extra - V((0, 0, 4.15)))
R.joint("extra", extra)

# Arms. Right hand is a vacuum head on a duct, left is a three finger gripper.
vac = [cyl(0.16, 0.14, joint, (0, 0, -0.07), seg=6, bevel=0.01)]
vac += limb((0, 0, -0.12), (0, -0.22, -0.72), 0.24, 0.24, teal, 0.22, 0.2, r=0.04)
vac.append(box((0.78, 0.36, 0.17), white, (0, -0.3, -0.82), r=0.07, n=1))
vac.append(box((0.8, 0.06, 0.08), orange, (0, -0.49, -0.82), r=0.02, n=1))
vac.append(box((0.7, 0.28, 0.06), dark, (0, -0.3, -0.92), r=0.01, n=1))
if NIGHT:  # scrap teeth bent into the vacuum mouth
    for i in range(6):
        vac.append(slab([(-0.05, 0), (0.05, 0), (0, -0.14)], 0.03, joint, loc=(-0.3 + i * 0.12, -0.46, -0.94), bevel=0.0))
vac.append(box((0.3, 0.3, 0.06), joint, (0, -0.3, -0.71), r=0.02, n=1))
move(vac, loc=(-1.06, -0.12, 2.3))
arm(R, -1, (-0.92, 0, 3.75), (-1.02, -0.02, 3.0), (-1.06, -0.12, 2.3), 0.3, 0.36, white, joint, vac, stripe=teal, grip=(-0.3, -0.85))
arm(R, 1, (0.92, 0, 3.75), (1.02, -0.02, 3.0), (1.06, -0.12, 2.3), 0.3, 0.36, white, joint,
    claw(1, (1.06, -0.12, 2.3), white, dark, size=0.9), stripe=teal)

# Legs: short, sturdy, big flat feet.
for x in (-0.38, 0.38):
    leg(R, x, (0, 2.15), (-0.04, 1.35), (0.02, 0.55), 0.34, 0.4, white, joint, stripe=teal, foot_size=(0.55, 0.95, 0.34))

# laid out at about 5.1 studs, grown to about 5.5
for obs in R.parts.values():
    move(obs, scl=1.08)
for k in R.joints:
    R.joints[k] *= 1.08
R.finish(quick="quick" in sys.argv, big=("Head",))
