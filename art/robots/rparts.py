"""Shared pieces for the Year 2029 robots, on top of kit.py.

Moderation: Roblox judges every part alone in flat grey. So limbs here are boxy plates or hex
prisms with flat ends, shoulders are flat-topped armor plates, and elbows and knees are hex hinge
barrels with clevis forks. No round-ended rods, no ring bands.
Coordinates are world studs: +z up, the robot faces -y, robot right is -x.
"""
import math, os

from kit import *  # noqa
from kit import V, Matrix

# Night hunter look: run a hunter's build.py with NIGHT=1 to get <name>_night beside the day model.
NIGHT = bool(os.environ.get("NIGHT"))
NIGHT_RED = "#ff2414"
OIL = "#0d0e0c"


def night(name):
    return name + "_night" if NIGHT else name


def blend(a, b, t):
    """Hex colour a moved t of the way toward b."""
    ca = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    cb = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(ca, cb))


def shell(color="#f1efe9"):
    """Old company plastic gone yellow and grimy, chipped down to grey and rust. At night: scorched, rusty, filthy."""
    if NIGHT:
        return paint("#3b3d42", chip=0.6, under="#6b3f22", under2="#1b1714", grime=0.65, streaks=0.7)
    return paint(blend(color, "#c4b99f", 0.55), chip=0.38, under="#8f8b83", under2="#5a4636", grime=0.55, streaks=0.5)


def panel(color="#b4b8bd"):
    if NIGHT:
        return plain("#25272b", grime=0.4, vary=0.15)
    return plain(color, grime=0.1, vary=0.1)


def rubber(color="#2c2f34"):
    return plain(color, grime=0.25, vary=0.15)


def steel(color="#767b82"):
    return metal(color, rust=0.08)


def screen(color="#13171c"):
    return flat(color, ao=0.2)


def lit(color):
    return glow(color, amount=0.25)


def orient(obs, a, b):
    """Turns pieces built along +z from the origin so they run from a to b.
    Local x stays as close to world x as it can, local -y faces the robot's front."""
    a, b = V(a), V(b)
    z = (b - a).normalized()
    ref = V((-1, 0, 0)) if abs(z.x) < 0.9 else V((0, 0, 1))
    x = (ref - z * ref.dot(z)).normalized()
    y = z.cross(x)
    m = Matrix(((x.x, y.x, z.x, a.x), (x.y, y.y, z.y, a.y), (x.z, y.z, z.z, a.z), (0, 0, 0, 1)))
    for o in obs if isinstance(obs, (list, tuple)) else [obs]:
        o.data.transform(m)
    return obs


def limb(a, b, w, d, mat, w2=None, d2=None, r=0.05, stripe=None):
    """Tapered box from a to b, w x d at a and w2 x d2 at b, flat ends. stripe = material of a
    panel strip down the front."""
    a, b = V(a), V(b)
    L = (b - a).length
    w2 = w * 0.8 if w2 is None else w2
    d2 = d * 0.8 if d2 is None else d2
    o = box((w, d, L), mat, (0, 0, L / 2), r=r, n=1, smooth=40)
    warp(o, lambda v: V((v.x * (1 + (w2 / w - 1) * v.z / L), v.y * (1 + (d2 / d - 1) * v.z / L), v.z)))
    obs = [o]
    if stripe:
        obs.append(box((min(w, w2) * 0.3, 0.05, L * 0.6), stripe, (0, -(d + d2) / 4, L / 2), r=0.0, n=1))
    return orient(obs, a, b)


def hexlimb(a, b, r, mat, r2=None):
    L = (V(b) - V(a)).length
    return orient([cyl(r, L, mat, (0, 0, L / 2), r2=r * 0.85 if r2 is None else r2, seg=6, bevel=0.02)], a, b)


def hinge(at, r, length, mat, axle=None):
    """Hex barrel across x with a thinner hex axle poking out both ends."""
    obs = [cyl(r, length, mat, at, (0, 90, 0), seg=6, bevel=0.02)]
    if axle:
        obs.append(cyl(r * 0.55, length + 0.08, axle, at, (0, 90, 0), seg=6, bevel=0.01))
    return obs


def clevis(at, w, d, h, mat):
    """Two side plates that hug a hinge barrel, so a limb end reads as a machine joint."""
    return [box((0.06, d, h), mat, (at[0] + k * (w / 2 + 0.03), at[1], at[2] + h * 0.15), r=0.02, n=1) for k in (-1, 1)]


def pauldron(side, at, w, d, h, mat, axle):
    """Flat-topped shoulder armor, sitting a little outboard, with an axle into the torso."""
    x, y, z = at
    obs = [box((w, d, h), mat, (x - side * w * 0.12, y, z + h * 0.15), r=0.08, n=1)]
    obs.append(box((w * 0.9, d * 0.5, 0.05), panel(), (x - side * w * 0.12, y, z + h * 0.65 + 0.01), r=0.0, n=1))
    obs.append(cyl(min(d, h) * 0.32, w * 0.5, axle, (x + side * w * 0.5, y, z), (0, 90, 0), seg=6, bevel=0.01))
    return obs


def foot(x, y, w, l, h, mat, sole):
    """Boxy robot foot standing on the floor at (x, y), toe toward -y."""
    top = box((w, l, h), mat, (x, y, 0.08 + h / 2), r=min(0.1, h * 0.4), n=1)

    def toe(v):
        t = max(0.0, (y - v.y) / (l / 2))
        return V((v.x, v.y, 0.08 + (v.z - 0.08) * (1 - 0.4 * t)))

    warp(top, toe)
    return [top, box((w * 1.06, l * 1.04, 0.1), sole, (x, y, 0.05), r=0.03, n=1),
            box((w * 0.6, 0.04, 0.06), sole, (x, y - l * 0.52, 0.14), r=0.0, n=1)]


def leg(R, x, hip, knee, ankle, w, d, mat, joint, stripe=None, foot_size=(0.6, 1.0, 0.32), shin=0.85):
    """One leg as Thigh and Shin (Left* when x > 0): hip barrel, thigh, knee barrel, shin, ankle block, foot.
    hip, knee, ankle are (y, z) at this x."""
    H, K, A = V((x, *hip)), V((x, *knee)), V((x, *ankle))
    pre = "Left" if x > 0 else ""
    sole = rubber()
    top = hinge(H, w * 0.52, w * 1.15, joint, axle=rubber())
    top += limb(H, K, w, d, mat, w * 0.85, d * 0.85, stripe=stripe)
    top += clevis(K, w * 0.8, d * 0.7, w * 0.8, joint)
    R.add(pre + "Thigh", top)
    R.joint("leftThigh" if pre else "thigh", H)
    R.joint("leftKnee" if pre else "knee", K)
    obs = hinge(K, w * 0.42, w * 0.8, joint, axle=rubber())
    obs += limb(K, A, w * shin, d * shin, mat, w * shin * 0.8, d * shin * 0.8, stripe=stripe)
    obs.append(box((w * 0.7, w * 0.7, 0.22), joint, A + V((0, 0, -0.02)), r=0.03, n=1))
    fw, fl, fh = foot_size
    obs += foot(x, A.y - fl * 0.18, fw, fl, fh, mat, sole)
    R.add(pre + "Shin", obs)


def arm(R, side, s, e, wr, w, d, mat, joint, hand, stripe=None, pad=(1.6, 1.4, 0.9), fore=0.85, grip=(0, -0.6)):
    """One arm as UpperArm, Forearm, Hand. hand = list of objects already at the wrist.
    side -1 = robot right (viewer left). grip = (forward y, down z) offset of the grip point from the wrist."""
    pre = "" if side < 0 else "Left"
    s, e, wr = V(s), V(e), V(wr)
    U = pauldron(side, s, w * pad[0], d * pad[1], w * pad[2], mat, joint)
    U += limb(s, e, w, d, mat, w * 0.85, d * 0.85, stripe=stripe)
    U += clevis(e, w * 0.85, d * 0.8, w * 0.9, joint)
    F = hinge(e, w * 0.45, w * 0.85, joint, axle=rubber())
    F += limb(e, wr, w * fore, d * fore, mat, w * fore * 0.85, d * fore * 0.85, stripe=stripe)
    F.append(box((w * fore, d * fore, 0.07), joint, wr + V((0, 0, 0.04)), r=0.02, n=1))
    R.add(pre + "UpperArm", U)
    R.add(pre + "Forearm", F)
    R.add(pre + "Hand", hand)
    key = (lambda n: n) if side < 0 else (lambda n: "left" + n[0].upper() + n[1:])
    R.joint(key("shoulder"), s)
    R.joint(key("elbow"), e)
    R.joint(key("wrist"), wr)
    R.joint(key("grip"), wr + V((0, grip[0], grip[1])))


def claw(side, at, mat, fmat, size=1.0, fingers=3, curl=1.0, long=1.0, thumb=True):
    """Robot hand hanging down from the wrist: hex wrist, boxy palm, flat plate fingers."""
    k = -side
    obs = [cyl(0.15, 0.14, fmat, (0, 0, -0.07), seg=6, bevel=0.01)]
    obs.append(box((0.28, 0.42, 0.36), mat, (0, 0, -0.3), r=0.06, n=1))
    obs.append(box((0.24, 0.46, 0.08), fmat, (0, 0, -0.48), r=0.02, n=1))
    for i in range(fingers):
        y = -0.15 + 0.3 * i / max(fingers - 1, 1)
        c = curl * (0.7 + 0.5 * i / max(fingers - 1, 1))
        p0 = V((k * 0.02, y, -0.48))
        p1 = p0 + V((k * 0.05 * c, 0, -0.22 * long))
        p2 = p1 + V((k * 0.15 * c, 0, -0.16 * long))
        obs += limb(p0, p1, 0.1, 0.1, fmat, 0.09, 0.09, r=0.0)
        obs.append(box((0.11, 0.11, 0.06), mat, p1, r=0.0, n=1))
        obs += limb(p1, p2, 0.09, 0.09, fmat, 0.07, 0.05, r=0.0)
    if thumb:
        p0, p1 = V((k * 0.06, -0.2, -0.26)), V((k * 0.1, -0.33, -0.42))
        p2 = p1 + V((k * 0.06, 0.05, -0.16 * long))
        obs += limb(p0, p1, 0.1, 0.1, fmat, 0.09, 0.09, r=0.0)
        obs += limb(p1, p2, 0.09, 0.09, fmat, 0.07, 0.05, r=0.0)
    move(obs, scl=size)
    return move(obs, loc=at)


def label(text, size, at, plate, ink, w=None):
    """Small made-up label plate facing -y."""
    w = w or size * len(text) * 0.7 + 0.08
    return [box((w, 0.03, size * 1.5), plate, at, r=0.0, n=1), words(text, size, flat(ink), V(at) + V((0, -0.02, 0)))]


def accent(color):
    """Stripe color by day, red glow at night (Roblox switches these to Neon)."""
    return glow(NIGHT_RED, amount=0.35) if NIGHT else plain(blend(color, "#6f6b62", 0.45), grime=0.6, vary=0.25)


def scanner():
    return lit(NIGHT_RED) if NIGHT else lit("#ff4d3a")


def oil(R, part, surf, spots):
    """Night only: black oil streaks running down a surface from (x, z, length) spots."""
    if not NIGHT:
        return
    for x, z, ln in spots:
        p, n = front(surf, x, z)
        R.add(part, aim([box((0.13, 0.02, 0.1), flat(OIL), (0, 0, 0), r=0.0, n=1),
                         box((0.06, 0.02, ln), flat(OIL), (0.02, 0, -ln / 2), r=0.0, n=1)], p + n * 0.012, n))


def cracks(R, part, surf, spots, size=1.0):
    """Night only: red glowing zigzag cracks in the shell at (x, z) spots."""
    if not NIGHT:
        return
    red = glow(NIGHT_RED, amount=0.35)
    for i, (x, z) in enumerate(spots):
        p, n = front(surf, x, z)
        segs, at = [], V((0, 0, 0))
        for k in range(4):
            a = (35 if (k + i) % 2 else -35)
            ln = 0.16 * size
            d = V((math.sin(math.radians(a)) * ln, 0, -math.cos(math.radians(a)) * ln))
            segs.append(box((0.035 * size, 0.02, ln), red, at + d / 2, (0, -a, 0), r=0.0, n=1))
            at = at + d
        R.add(part, aim(segs, p + n * 0.012, n))


def spikes(points, mat):
    """Jagged flat scrap plates (triangles) standing up at (x, y, z, height, lean) points."""
    out = []
    for x, y, z, h, lean in points:
        out.append(slab([(-h * 0.22, 0), (h * 0.22, 0), (h * 0.08, h)], 0.06, mat, loc=(x, y, z), rot=(0, lean, 0), bevel=0.0))
    return out


# ---------------------------------------------------------------- store junk the robots wear
def oval(w, h, depth, mat, seg=28):
    """Flat smooth oval plate in the x-z plane, thick along y."""
    return slab([(w / 2 * math.cos(math.tau * i / seg), h / 2 * math.sin(math.tau * i / seg)) for i in range(seg)], depth, mat, bevel=depth * 0.3)


def mannequin_plate(w=0.36, h=0.48):
    """A cracked mannequin face plate: a blank smooth oval, no features, built facing -y at the origin."""
    skin = paint("#d9c6ad", chip=0.3, under="#9c8a74", under2="#5b4a3a", grime=0.45, streaks=0.35)
    crack = flat("#2a2420")
    return [oval(w, h, 0.05, skin), box((0.012, 0.02, h * 0.45), crack, (w * 0.12, -0.03, h * 0.12), (0, 18, 0), r=0.0, n=1),
            box((0.012, 0.02, h * 0.2), crack, (w * 0.2, -0.03, -h * 0.08), (0, -30, 0), r=0.0, n=1)]


def hivis(w, h):
    """A torn scrap of hi-vis safety vest with two dull reflective strips, facing -y at the origin."""
    vest = cloth(blend("#c9d43a", "#6d6a45", 0.35), dirt=0.7, dirtcolor="#3d3826")
    strip = plain("#a7aaa8", grime=0.55)
    rag = [(-w / 2, -h / 2), (-w * 0.2, -h / 2 + 0.08), (w * 0.05, -h / 2 - 0.05), (w * 0.35, -h / 2 + 0.06), (w / 2, -h / 2),
           (w / 2 - 0.05, h / 2), (w * 0.1, h / 2 - 0.07), (-w / 2 + 0.04, h / 2)]
    out = [slab(rag, 0.03, vest)]
    for z in (-h * 0.12, h * 0.18):
        out.append(box((w * 0.92, 0.035, h * 0.1), strip, (0, -0.005, z), r=0.0, n=1))
    return out


def doll_head(r=0.3):
    """A doll's head lying face down: a smooth oval with flat tufts of hair on what is now its top."""
    skin = paint("#e2cdb7", chip=0.35, under="#a08c78", under2="#5b4a3a", grime=0.6, streaks=0.4)
    hair = plain("#4a3527", grime=0.5)
    out = [ball((r, r * 1.1, r * 0.92), skin, seg=14, rings=9)]
    for x, y, a in ((-0.1, 0.05, 20), (0.08, -0.06, -15), (0.0, 0.14, 5), (0.14, 0.1, 35)):
        out.append(slab([(-0.05, 0), (0.05, 0), (0.0, 0.16)], 0.02, hair, loc=(x * r / 0.3, y * r / 0.3, r * 0.82), rot=(70, 0, a)))
    return out
