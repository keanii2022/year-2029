import os, sys; sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "_kit")); from kit import *
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from rparts import *  # noqa

# Scout: a night hunter. Too thin, too tall, long arms and fingers, one big scanner eye on a long neck.
R = Robot(night("scout"), folder="robots", max_h=7.0)
white = shell("#eceae4")
line = panel()
dark = rubber("#24272c")
joint = steel("#5f646b")
orange = accent("#f28c38")
scan = scanner()

# Torso: small pelvis, exposed hex spine, narrow hunched chest, long neck.
R.add("Torso", box((0.6, 0.42, 0.3), joint, (0, 0, 3.82), r=0.06, n=1))
R.add("Torso", hexlimb((0, 0, 3.9), (0, 0.04, 4.48), 0.13, dark, 0.13))
for z in (4.05, 4.25):
    R.add("Torso", box((0.36, 0.3, 0.07), joint, (0, 0.02, z), r=0.0, n=1))
chest = box((0.86, 0.56, 1.12), white, (0, 0, 4.98), r=0.16, n=2)
warp(chest, lambda v: V((v.x * (0.7 + 0.3 * (v.z - 4.42) / 1.12), v.y - 0.16 * (v.z - 4.42), v.z)))
R.add("Torso", chest)
p, n = front(chest, 0, 5.0)
R.add("Torso", aim(box((0.03, 0.03, 0.7), line, r=0.0, n=1), p + n * 0.005, n))
p, n = front(chest, 0.18, 5.25)
R.add("Torso", aim(label("SC-9", 0.07, (0, 0, 0), orange, "#2a2420"), p + n * 0.01, n))
for x in (-0.25, 0.25):
    p, n = front(chest, x, 4.7)
    R.add("Torso", aim(box((0.12, 0.04, 0.3), dark, r=0.0, n=1), p, n))
oil(R, "Torso", chest, [(-0.2, 5.3, 0.5), (0.12, 4.95, 0.35), (0.3, 5.45, 0.6)])
cracks(R, "Torso", chest, [(-0.12, 5.15)], size=0.8)
R.add("Torso", hexlimb((0, -0.12, 5.48), (0, -0.32, 5.98), 0.1, joint, 0.09))
for x in (-0.47, 0.47):
    R.add("Torso", cyl(0.14, 0.1, dark, (x, -0.12, 5.35), (0, 90, 0), seg=6, bevel=0.01))
R.joint("hip", (0, 0, 3.8))

# Head: narrow wedge, swept-back fins, one big scanner eye. The lens goes in Extra.
hy, hz = -0.42, 6.2
head = box((0.5, 0.78, 0.5), white, (0, hy, hz), r=0.12, n=1)
warp(head, lambda v: V((v.x * (1.0 - 0.3 * max(0.0, v.y - hy) / 0.39), v.y, v.z)))
R.add("Head", head)
R.add("Head", cyl(0.29, 0.16, dark, (0, hy - 0.4, hz), (90, 0, 0), seg=16, bevel=0.03))
R.add("Head", cyl(0.31, 0.04, orange, (0, hy - 0.36, hz), (90, 0, 0), seg=16, bevel=0.01))
for x in (-1, 1):
    fin = slab([(0, 0), (0.5, 0.06), (0.62, 0.22), (0.1, 0.2)], 0.04, white, bevel=0.01)
    move(fin, rot=(0, 0, 90), loc=(x * 0.24, hy + 0.05, hz + 0.02))
    move(fin, rot=(0, -x * 25, 0), pivot=(x * 0.24, hy, hz))
    R.add("Head", fin)
R.add("Head", box((0.06, 0.6, 0.1), joint, (0, hy + 0.05, hz + 0.29), r=0.02, n=1))
R.add("Extra", cyl(0.2, 0.04, scan, (0, hy - 0.49, hz), (90, 0, 0), seg=16, bevel=0.01))
R.add("Extra", cyl(0.07, 0.03, flat("#1a0d0b"), (0, hy - 0.515, hz), (90, 0, 0), seg=10, bevel=0.0))
move(R.parts["Head"] + R.parts["Extra"], scl=1.4, pivot=(0, -0.3, 5.95))
R.joint("neck", (0, -0.3, 5.95))
R.joint("extra", V((0, -0.3, 5.95)) + (V((0, hy - 0.49, hz)) - V((0, -0.3, 5.95))) * 1.4)

# Arms: long and thin, hanging to the knees, with long fingers.
for side in (-1, 1):
    s, e, w = (side * 0.55, -0.12, 5.35), (side * 0.7, 0.02, 3.95), (side * 0.72, -0.18, 2.62)
    arm(R, side, s, e, w, 0.18, 0.22, white, joint, claw(side, w, white, dark, size=1.05, long=2.6 if NIGHT else 1.9, curl=0.9 if NIGHT else 0.6),
        stripe=orange, pad=(2.0, 1.6, 1.2), grip=(0, -0.7))

for x in (-0.3, 0.3):
    leg(R, x, (0, 3.7), (-0.16, 2.1), (0.02, 0.48), 0.22, 0.26, white, joint, stripe=orange, foot_size=(0.34, 0.95, 0.24), shin=0.9)

# laid out at about 6.7 studs, grown to about 7
for obs in R.parts.values():
    move(obs, scl=1.05)
for k in R.joints:
    R.joints[k] *= 1.05
R.finish(quick="quick" in sys.argv, big=("Head",))
