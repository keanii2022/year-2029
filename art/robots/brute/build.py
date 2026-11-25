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
# A torn hi-vis vest scrap stretched across the chest (in place of the two chest panels)
p, n = front(chest, 0.15, 6.25)
R.add("Torso", aim(hivis(1.9, 1.15), p + n * 0.02, n))
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
# the slit eye is broken in two, a short piece and a long one, so it reads lopsided in the dark
R.add("Extra", box((0.16, 0.04, 0.07), scan, (-0.23, hy - 0.465, hz - 0.02), r=0.02, n=1))
R.add("Extra", box((0.36, 0.04, 0.07), scan, (0.13, hy - 0.465, hz - 0.03), (0, -4, 0), r=0.02, n=1))
# a crack across the visor, and a hard hat welded on crooked
for k, (x, a) in enumerate(((-0.12, 30), (0.02, -35), (0.14, 25))):
    R.add("Head", box((0.016, 0.02, 0.1), plain("#8d9296", grime=0.3), (x, hy - 0.465, hz - 0.02 + (k % 2) * 0.02), (0, a, 0), r=0.0, n=1))
hat_mat = paint(blend("#e0b732", "#6f6b62", 0.25) if not NIGHT else "#4a3d22", chip=0.5, under="#5b4a3a", grime=0.6, streaks=0.5)
hat = [ball((0.42, 0.48, 0.3), hat_mat, (0, 0, 0), seg=14, rings=8), box((0.95, 1.08, 0.04), hat_mat, (0, -0.05, -0.02), r=0.02, n=1),
       box((0.08, 0.7, 0.08), hat_mat, (0, 0, 0.27), r=0.02, n=1)]
hat = [o for o in hat]
R.add("Head", move(hat, rot=(8, -16, 0), loc=(0.12, hy + 0.05, hz + 0.42)))
R.joint("neck", (0, -0.95, 7.3))
R.joint("extra", (0, hy - 0.465, hz - 0.02))

def forklift(at):
    """A pallet clamp in place of a hand: a heavy back plate and two long flat tines that drag on the floor."""
    w = V(at)
    plate_mat = metal("#5a5d60", rust=0.55)
    obs = [box((0.9, 0.3, 0.8), plate_mat, w + V((0, -0.05, -0.35)), r=0.04, n=1),
           box((1.0, 0.12, 0.12), plate_mat, w + V((0, -0.2, -0.05)), r=0.02, n=1)]
    for x in (-0.3, 0.3):
        obs.append(box((0.16, 0.14, 1.6), plate_mat, w + V((x, -0.18, -1.45)), r=0.02, n=1))
        obs.append(box((0.16, 0.9, 0.1), plate_mat, w + V((x, -0.58, -2.2)), (-6, 0, 0), r=0.02, n=1))
        obs.append(box((0.17, 0.03, 0.5), flat(OIL), w + V((x, -0.26, -1.2)), r=0.0, n=1))
    return obs


# Arms: lopsided. The right arm ends in a forklift clamp that scrapes the floor; the left keeps a smaller grabber.
for side in (-1, 1):
    s, e, w = (side * 1.85, 0, 7.05), (side * 2.12, 0.12, 5.25), (side * 2.08, -0.25, 3.55)
    hand = forklift(w) if side < 0 else claw(side, w, white, dark, size=2.2 if NIGHT else 1.9, curl=1.5 if NIGHT else 1.2)
    arm(R, side, s, e, w, 0.55, 0.65, white, joint, hand, stripe=hazard if side > 0 else None,
        pad=(2.3, 1.8, 1.4) if side < 0 else (1.5, 1.3, 0.9), fore=0.95, grip=(0, -1.5))

for x in (-0.75, 0.75):
    leg(R, x, (0, 3.6), (-0.1, 2.2), (0.04, 0.85), 0.6, 0.7, white, joint, stripe=hazard, foot_size=(1.0, 1.4, 0.5), shin=0.95)

R.finish(quick="quick" in sys.argv, big=("Head",))
