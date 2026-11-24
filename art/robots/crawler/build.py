import os, sys; sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "_kit")); from kit import *
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from rparts import *  # noqa

# Crawler: a night hunter. Low and long on six legs, slides under beds and tables, two pincer arms up front.
R = Robot(night("crawler"), folder="robots", max_h=4.0)
white = shell("#ebe9e3")
line = panel()
dark = rubber("#24272c")
joint = steel("#5f646b")
teal = accent("#2fb8a8")
scan = scanner()

# Torso: long low shell, tapered at the back, with armor plates along the top.
body = box((1.5, 3.4, 0.78), white, (0, 0.3, 1.3), r=0.24, n=2)
warp(body, lambda v: V((v.x * (1 - 0.3 * max(0.0, v.y - 0.3) / 1.7), v.y, v.z - 0.12 * max(0.0, v.y - 0.8))))
R.add("Torso", body)
for i, y in enumerate((-0.9, -0.2, 0.5, 1.15)):
    R.add("Torso", box((1.1 - i * 0.12, 0.55, 0.1), white if i % 2 else line, (0, y, 1.71 - max(0.0, y - 0.8) * 0.12), r=0.04, n=1))
for x in (-0.76, 0.76):
    R.add("Torso", box((0.03, 2.6, 0.03), line, (x, 0.2, 1.25), r=0.0, n=1))
R.add("Torso", box((0.5, 0.04, 0.14), teal, (0, -1.41, 1.05), r=0.02, n=1))
R.add("Torso", label("CW-4", 0.09, (0.45, 1.6, 1.2), teal, "#1f3a30"))
move(R.parts["Torso"][-2:], rot=(0, 0, 180), pivot=(0.45, 1.6, 1.2))
R.joint("hip", (0, 0.3, 1.3))

# Head: a flat wedge at the front with a row of four lenses. The lenses go in Extra.
hy, hz = -1.62, 1.32
head = R.add("Head", box((1.1, 0.6, 0.56), white, (0, hy, hz), r=0.16, n=1))
oil(R, "Head", head, [(-0.4, hz - 0.14, 0.16), (0.3, hz - 0.14, 0.12)])
R.add("Head", box((0.94, 0.06, 0.24), screen(), (0, hy - 0.3, hz + 0.02), r=0.05, n=1))
R.add("Head", box((1.16, 0.4, 0.08), joint, (0, hy - 0.06, hz + 0.3), r=0.03, n=1))
eyes = [(-0.33, 0.02, 0.06), (-0.11, 0.02, 0.075), (0.11, 0.02, 0.075), (0.33, 0.02, 0.06)]
if NIGHT:  # a spider cluster of seven
    eyes = [(-0.36, -0.03, 0.055), (-0.12, -0.04, 0.07), (0.12, -0.04, 0.07), (0.36, -0.03, 0.055), (-0.24, 0.09, 0.045), (0, 0.1, 0.05), (0.24, 0.09, 0.045)]
for x, z, r in eyes:
    R.add("Extra", cyl(r, 0.04, scan, (x, hy - 0.34, hz + z), (90, 0, 0), seg=10, bevel=0.01))
R.joint("neck", (0, -1.32, 1.3))
R.joint("extra", (0, hy - 0.34, hz + 0.02))

# Legs: a chassis tray and six bent legs with flat pads.
R.add("Legs", box((1.1, 2.9, 0.16), joint, (0, 0.3, 0.86), r=0.04, n=1))
n = 0
for side in (-1, 1):
    for y in (-0.85, 0.3, 1.4):
        n += 1
        leg_n = f"Leg{n}"
        h, k, f = V((side * 0.62, y, 0.95)), V((side * 1.3, y + 0.05, 1.4)), V((side * 1.6, y + 0.1, 0.12))
        R.add(leg_n, box((0.26, 0.3, 0.26), dark, h, r=0.04, n=1))
        R.add(leg_n, limb(h, k, 0.2, 0.18, white, 0.17, 0.15, r=0.03))
        R.add(leg_n, box((0.24, 0.26, 0.24), joint, k, r=0.03, n=1))
        R.add(leg_n, limb(k, f, 0.18, 0.16, white, 0.1, 0.1, r=0.02))
        R.add(leg_n, box((0.26, 0.3, 0.1), dark, (f.x, f.y, 0.05), r=0.02, n=1))
        R.joint(leg_n.lower(), h)


def pincer(side, at):
    """Two flat jaws on a hex wrist, opening forward."""
    obs = [cyl(0.13, 0.12, joint, (0, 0, -0.06), seg=6, bevel=0.01)]
    obs.append(box((0.22, 0.3, 0.2), white, (0, 0, -0.2), r=0.04, n=1))
    for t in (-1, 1):
        a, b, c = V((0, t * 0.1, -0.28)), V((0, t * 0.2, -0.55)), V((0, t * 0.06, -0.74))
        obs += limb(a, b, 0.07, 0.12, dark, 0.07, 0.1, r=0.0)
        obs += limb(b, c, 0.07, 0.1, dark, 0.06, 0.05, r=0.0)
    move(obs, scl=1.35 if NIGHT else 1.0)
    return move(obs, loc=at)


for side in (-1, 1):
    s, e, w = (side * 0.55, -1.25, 1.62), (side * 0.85, -1.95, 2.1), (side * 0.78, -2.55, 1.18)
    arm(R, side, s, e, w, 0.2, 0.24, white, joint, pincer(side, w), stripe=teal, pad=(1.5, 1.3, 0.8), grip=(0, -0.55))

R.finish(quick="quick" in sys.argv, big=("Head",))
