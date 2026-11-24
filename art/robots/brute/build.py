import os, sys; sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "_kit")); from kit import *
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from rparts import *  # noqa

# Brute: a night hunter. Huge shoulders, a small sunk head with a visor slit, giant grabber hands.
R = Robot(night("brute"), folder="robots", max_h=8.5)
white = shell("#ebe9e3")
line = panel()
dark = rubber("#24272c")
joint = steel("#5f646b")
hazard = accent("#f2b632")
scan = scanner()

# Torso: wide pelvis, thick waist, a chest that is all shoulders, back vents.
R.add("Torso", box((1.8, 1.15, 0.6), joint, (0, 0, 3.75), r=0.12, n=1))
R.add("Torso", cyl(0.62, 0.5, dark, (0, 0, 4.25), seg=6, bevel=0.03))
chest = box((3.0, 1.75, 2.9), white, (0, 0, 5.95), r=0.35, n=2)
warp(chest, lambda v: V((v.x * (0.62 + 0.38 * (v.z - 4.5) / 2.9), v.y - 0.12 * (v.z - 4.5), v.z)))
R.add("Torso", chest)
for x in (-0.55, 0.55) if not NIGHT else ():  # at night these two panels plus the grille would read as a face
    p, n = front(chest, x, 6.4)
    R.add("Torso", aim(box((0.7, 0.04, 0.7), line, r=0.06, n=1), p + n * 0.005, n))
oil(R, "Torso", chest, [(-0.9, 6.8, 0.8), (0.35, 6.1, 0.6), (1.0, 6.6, 0.5), (-0.25, 6.9, 0.45)])
cracks(R, "Torso", chest, [(0.6, 6.75), (-0.65, 6.3)], size=1.4)
if NIGHT:
    R.add("Torso", spikes([(sx * x, 0.1, 7.2, h, sx * lean) for sx in (-1, 1) for x, h, lean in ((0.8, 0.55, -8), (1.1, 0.75, 6), (1.4, 0.5, 18))], joint))
p, n = front(chest, 0, 5.35)
for i in range(7):
    R.add("Torso", aim(box((0.14, 0.05, 0.3), hazard if i % 2 else dark, (-0.42 + i * 0.14, 0, 0), r=0.0, n=1), p, n))
p, n = front(chest, -0.6, 5.0)
R.add("Torso", aim(label("BR-X", 0.12, (0, 0, 0), hazard, "#2a2420"), p + n * 0.01, n))
p, n = front(chest, 0.7, 5.75)
R.add("Torso", tape(0.5, 0.16, p + n * 0.02, n, roll=-18, color="#9fb8c8"))
for x in (-0.5, 0.5):
    R.add("Torso", box((0.5, 0.5, 0.9), joint, (x, 0.62, 7.75), r=0.06, n=1))
    for z in (7.6, 7.8, 8.0):
        R.add("Torso", box((0.52, 0.3, 0.05), dark, (x, 0.54, z), r=0.0, n=1))
for x in (-1.5, 1.5):
    R.add("Torso", cyl(0.42, 0.14, dark, (x, 0, 7.05), (0, 90, 0), seg=6, bevel=0.01))
R.joint("hip", (0, 0, 3.6))

# Head: small, low and forward between the shoulders. Brow plate, visor slit; the glow strip goes in Extra.
hy, hz = -1.2, 7.62
R.add("Head", box((0.92, 0.85, 0.66), white, (0, hy, hz), r=0.16, n=1))
R.add("Head", box((1.0, 0.5, 0.14), joint, (0, hy - 0.22, hz + 0.3), (12, 0, 0), r=0.04, n=1))
R.add("Head", box((0.78, 0.06, 0.18), screen(), (0, hy - 0.43, hz - 0.02), r=0.03, n=1))
for x in (-1, 1):
    R.add("Head", box((0.1, 0.5, 0.4), dark, (x * 0.48, hy, hz - 0.05), r=0.03, n=1))
R.add("Extra", box((0.64, 0.04, 0.07), scan, (0, hy - 0.465, hz - 0.02), r=0.02, n=1))
R.joint("neck", (0, -0.95, 7.3))
R.joint("extra", (0, hy - 0.465, hz - 0.02))

# Arms: long and heavy, grabber hands that hang near the floor.
for side in (-1, 1):
    s, e, w = (side * 1.85, 0, 7.05), (side * 2.12, 0.12, 5.25), (side * 2.08, -0.25, 3.55)
    arm(R, side, s, e, w, 0.55, 0.65, white, joint, claw(side, w, white, dark, size=2.8 if NIGHT else 2.5, curl=1.5 if NIGHT else 1.2),
        stripe=hazard, pad=(1.8, 1.5, 1.1), fore=0.95, grip=(0, -1.5))

for x in (-0.75, 0.75):
    leg(R, x, (0, 3.6), (-0.1, 2.2), (0.04, 0.85), 0.6, 0.7, white, joint, stripe=hazard, foot_size=(1.0, 1.4, 0.5), shin=0.95)

R.finish(quick="quick" in sys.argv, big=("Head",))
