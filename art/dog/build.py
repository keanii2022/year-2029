import os, random, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "_kit"))
from ykit import *  # noqa

# Friendly scruffy mutt, facing -y. Dog's left is +x. Parts with pivots move in code.
NECK = (0, -0.72, 1.55)
JAW = (0, -1.08, 1.66)
TAIL = (0, 0.9, 1.3)
HIPS = {"LegFL": (0.25, -0.5, 1.05), "LegFR": (-0.25, -0.5, 1.05), "LegBL": (0.27, 0.6, 1.05), "LegBR": (-0.27, 0.6, 1.05)}


def furtube(points, radii, mat, n=10, rough=0.18, squash=1.0):
    """Tube through points with a ridged, furry cross section and flat ends. squash < 1 flattens it in x."""
    pts = [V(p) for p in points]
    rings = []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        ref = V((1, 0, 0)) if abs(t.x) < 0.9 else V((0, 0, 1))
        side = (ref - t * ref.dot(t)).normalized()
        up = t.cross(side)
        ring = []
        for j in range(n):
            a = 2 * math.pi * j / n
            r = radii[i] * (1 - rough * (j % 2))
            ring.append(p + side * math.cos(a) * r * squash + up * math.sin(a) * r)
        rings.append(ring)
    return loft(rings, mat, smooth=60)


def tufts(center, radii, mat, count, seed, keep, size=0.07):
    """Little pointed fur tufts on an ellipsoid. keep(normal) picks where they grow."""
    rnd = random.Random(seed)
    c, r = V(center), V(radii)
    out = []
    while len(out) < count:
        d = V((rnd.gauss(0, 1), rnd.gauss(0, 1), rnd.gauss(0, 1))).normalized()
        nrm = V((d.x / r.x, d.y / r.y, d.z / r.z)).normalized()
        if not keep(nrm):
            continue
        p = c + V((d.x * r.x, d.y * r.y, d.z * r.z))
        h = size * rnd.uniform(0.9, 1.3)
        t = cyl(size * rnd.uniform(1.0, 1.4), h, mat, (0, -h / 2 + 0.02, 0), (90, rnd.uniform(0, 90), 0), r2=0.0, seg=4, bevel=0.0)
        out.append(aim(t, p, (nrm + V((rnd.uniform(-0.2, 0.2), 0.9, -0.2))).normalized()))
    return out


def leg(P, name, pts, radii, fur, paw):
    """A furry leg down to a paw with three toes. Starts buried in the body."""
    P.add(name, furtube(pts, radii, fur))
    x, y = pts[-1][0], pts[-1][1]
    P.add(name, box((0.22, 0.26, 0.11), paw, (x, y - 0.04, 0.06), r=0.05, n=1))
    for k in (-1, 0, 1):
        P.add(name, box((0.07, 0.08, 0.08), paw, (x + k * 0.07, y - 0.18, 0.04), r=0.03, n=1))


@item("dog", "dog", size=1024, pivots={"Head": NECK, "Jaw": JAW, "Tail": TAIL, **HIPS})
def dog(P):
    fur = cloth("#b5895a", dirt=0.25, weave=38, dirtcolor="#6a4a30")
    light = cloth("#e3cba2", dirt=0.2, weave=38)
    patch = cloth("#6e4a2e", dirt=0.2, weave=38)
    nose = plain("#2a201c", grime=0.1)
    paw = plain("#4a382c", grime=0.3)

    # Body: barrel, chest, belly, a dark patch, scruff on the back, collar with a glowing tag.
    body = ball((0.5, 0.82, 0.46), fur, (0, 0.15, 1.12), seg=16, rings=10)
    crumple(body, 0.04, 3)
    P.add("Body", body)
    P.add("Body", crumple(ball((0.44, 0.42, 0.48), fur, (0, -0.5, 1.3), seg=14, rings=9), 0.03, 3))
    P.add("Body", crumple(ball((0.36, 0.6, 0.22), light, (0, 0.0, 0.84), seg=12, rings=7), 0.02, 4))
    P.add("Body", crumple(ball((0.3, 0.4, 0.3), patch, (0.24, 0.35, 1.3), seg=10, rings=7), 0.02, 4))
    P.add("Body", tufts((0, 0.15, 1.12), (0.5, 0.82, 0.46), fur, 12, 3, lambda n: n.z > 0.5))
    P.add("Body", torus(0.3, 0.05, plain("#2fb8a8", grime=0.2), (0, -0.66, 1.5), (62, 0, 0), seg=18, sub=6))
    P.add("Body", box((0.12, 0.04, 0.14), glow("#7ff0ff", amount=0.2), (0, -0.98, 1.34), (-28, 0, 0), r=0.03, n=1))
    P.add("Body", box((0.05, 0.05, 0.05), metal("#9a9690", 0.2), (0, -0.96, 1.42), r=0.0, n=1))

    # Head: round skull, muzzle, nose, kind eyes, one floppy ear and one half up, scruffy brows.
    P.add("Head", crumple(ball((0.38, 0.4, 0.36), fur, (0, -0.9, 1.84), seg=16, rings=10), 0.025, 4))
    P.add("Head", ball((0.2, 0.26, 0.15), light, (0, -1.24, 1.74), seg=12, rings=8))
    P.add("Head", ball((0.08, 0.06, 0.06), nose, (0, -1.49, 1.79), seg=10, rings=6))
    for x in (-0.15, 0.15):
        P.add("Head", ball(0.06, nose, (x, -1.24, 1.92), seg=10, rings=6))
        P.add("Head", ball(0.018, flat("#ffffff"), (x + 0.015, -1.295, 1.945), seg=6, rings=4))
        P.add("Head", box((0.14, 0.05, 0.04), fur, (x, -1.17, 2.01), (0, -x * 80, 0), r=0.02, n=1))
    ear_l = slab([(0, 0), (0.2, 0.02), (0.18, -0.34), (0.06, -0.38), (-0.02, -0.2)], 0.05, patch, bevel=0.015)
    move(ear_l, rot=(0, -30, 10), loc=(0.3, -0.86, 2.05))
    ear_r = slab([(0, 0), (0.18, 0.0), (0.12, 0.3), (0.02, 0.26)], 0.05, fur, bevel=0.015)
    move(ear_r, rot=(0, -40, -10), loc=(-0.34, -0.86, 2.02))
    P.add("Head", ear_l, ear_r)
    P.add("Head", tufts((0, -0.9, 1.84), (0.38, 0.4, 0.36), fur, 12, 9, lambda n: n.z > 0.45 and n.y > -0.6, 0.06))

    # Jaw: lower jaw with a little tongue out. Hinge under the ears.
    jaw = ball((0.13, 0.17, 0.055), light, (0, -1.22, 1.61), seg=10, rings=6)
    P.add("Jaw", jaw, box((0.1, 0.14, 0.03), plain("#e07a8a", grime=0.1), (0, -1.33, 1.635), (-12, 0, 0), r=0.015, n=1))
    P.add("Jaw", ball((0.1, 0.12, 0.06), light, (0, -1.1, 1.62), seg=8, rings=5))

    # Tail: a fluffy flat tuft curving up, ending in splayed flat wisps.
    tail_pts = [(0, 0.82, 1.28), (0, 1.02, 1.38), (0, 1.18, 1.56), (0, 1.26, 1.76)]
    P.add("Tail", furtube(tail_pts, [0.11, 0.15, 0.14, 0.11], fur, n=12, rough=0.3, squash=1.6))
    for a in (-30, 0, 30):
        w = slab([(-0.05, 0), (0.05, 0), (0.0, 0.16)], 0.04, light)
        move(w, rot=(0, a, 0), loc=(0, 1.26, 1.74))
        move(w, rot=(-20, 0, 0), pivot=(0, 1.26, 1.74))
        P.add("Tail", w)

    leg(P, "LegFL", [(0.25, -0.5, 1.05), (0.26, -0.55, 0.6), (0.26, -0.58, 0.12)], [0.15, 0.1, 0.08], fur, paw)
    leg(P, "LegFR", [(-0.25, -0.5, 1.05), (-0.26, -0.55, 0.6), (-0.26, -0.58, 0.12)], [0.15, 0.1, 0.08], light, paw)
    leg(P, "LegBL", [(0.27, 0.6, 1.1), (0.3, 0.52, 0.62), (0.3, 0.75, 0.32), (0.3, 0.72, 0.12)], [0.22, 0.13, 0.085, 0.08], fur, paw)
    leg(P, "LegBR", [(-0.27, 0.6, 1.1), (-0.3, 0.52, 0.62), (-0.3, 0.75, 0.32), (-0.3, 0.72, 0.12)], [0.22, 0.13, 0.085, 0.08], fur, paw)


main()
