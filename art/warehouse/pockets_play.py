"""Play, night outside and giant things: installation sets for the dark warehouse halls.
A parking lot under sodium light, a playground at dusk, a padded play room, a 70s ceiling fan, and things that are
too big: a floating black slab, a giant rocking horse, a maze hedge cut too perfectly. Clean, quiet, a little wrong.
Run from art: _kit/run.sh warehouse/pockets_play.py <name> ...

Floor pieces: parking_tile top at 0.2 (matches street_tile), mulch_tile 0.3, padded_floor 0.4.
Every pole, rail, post and chain is a square bar or a flat strip.
"""
import math, os, random, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "furniture"))
from common import *  # noqa
import bmesh
import kit
from mathutils import Matrix, Vector as V

OIL = "#0b0a0a"
VINYL = ("#c42a22", "#2448a8", "#e8b416", "#13908a")


# ---------------------------------------------------------------- materials (made per item: each build wipes the scene)
def undusted(g, c, **k):
    """g.done without the kit-wide dust film, which turns dark and saturated colours to grey felt."""
    saved = kit.DUST
    kit.DUST = 0
    try:
        return g.done(c, **k)
    finally:
        kit.DUST = saved


@cached
def asphalt():
    g = kit.G("asphalt")
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(6, 2), 0.55, 0.72), 0.5), "#3c3c3e", "#6a6864")
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(0.08, 4), 0.45, 0.7), 0.6), c, "#2a2a2c")
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(0.2, 3), 0.62, 0.75), 0.4), c, "#5a5752")
    return g.done(c, ao=0.4)


@cached
def worn_line(color):
    """Lot paint worn through to the asphalt in patches."""
    g = kit.G("worn")
    c = g.mix(0.25, color, "#6a6864")
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(1.0, 5), 0.5, 0.62), 0.8), c, "#4a4a4a")
    return g.done(c, ao=0.3, top=0.0)


@cached
def mulch():
    """Shredded bark chips: mixed browns, pale splinters, darker damp patches."""
    g = kit.G("mulch")
    c = g.mix(g.step(g.noise(1.6, 4, (1, 3, 1)), 0.4, 0.6), "#2e1e14", "#6a4428")
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(3.5, 2, (3, 1, 1)), 0.62, 0.7), 0.7), c, "#8a6440")
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(0.25, 3), 0.5, 0.7), 0.45), c, "#24180f")
    return undusted(g, c, ao=0.6, top=0.0)


@cached
def leaf(color):
    """Moulded plastic leaves: speckled two-tone green, flat-cut."""
    g = kit.G("leaf")
    c = g.mix(g.step(g.noise(9, 3), 0.42, 0.58), g.mix(0.45, color, "#1c3a20"), color)
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(14, 2), 0.66, 0.7), 0.6), c, g.mix(0.5, color, "#eaffd0"))
    return g.done(c, ao=0.8)


@cached
def chip(color):
    """Loose bark chip, same undusted finish as the mulch bed."""
    g = kit.G("chip")
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(4, 3), 0.4, 0.7), 0.3), color, "#1e140c")
    return undusted(g, c, ao=0.5, top=0.0)


def oil():
    return flat(OIL)


def concrete():
    return plain("#b3ada2", grime=0.5, vary=0.35)


@cached
def walnut():
    """Dark 70s fan-blade veneer with a long grain."""
    g = kit.G("walnut")
    c = g.mix(g.step(g.noise(3, 6, (0.15, 1, 1)), 0.4, 0.65), "#3a2414", "#6a4428")
    return undusted(g, c, ao=0.6, top=0.1)


def sodium():
    return glow("#ff9a3c", core="#ffd08a", amount=0.3)


@cached
def vinyl(color):
    """Saturated play-mat vinyl: a faint sheen mottle and grubby handling marks, no dust."""
    g = kit.G("vinyl")
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(3, 4), 0.4, 0.7), 0.12), color, "#ffffff")
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(1.5, 5, world=True), 0.5, 0.75), 0.3), c, "#5a4a40", "MULTIPLY")
    return undusted(g, c, ao=0.7, top=0.0)


@cached
def void():
    """Matte near-black that barely shows its own surface."""
    g = kit.G("void")
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(1.2, 4), 0.4, 0.7), 0.5), "#0b0b0d", "#18181b")
    return undusted(g, c, ao=0.5, top=0.0)


# ---------------------------------------------------------------- shapes
def bar(a, b, t, mat):
    """Square-section bar from point a to point b."""
    a, b = V(a), V(b)
    d = b - a
    o = box((t, t, d.length), mat, r=0.0, n=1)
    q = V((0, 0, 1)).rotation_difference(d.normalized())
    o.data.transform(Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4())
    return o


def beam(a, b, w, t, mat, side=(1, 0, 0)):
    """Flat strip from a to b: w wide along `side`, t thick across it."""
    a, b = V(a), V(b)
    z = (b - a).normalized()
    x = V(side)
    x = (x - z * x.dot(z)).normalized()
    o = box((w, t, (b - a).length), mat, r=0.0, n=1)
    o.data.transform(Matrix.Translation((a + b) / 2) @ Matrix((x, z.cross(x), z)).transposed().to_4x4())
    return o


def taper(a, b, t0, t1, mat):
    """Square-section post narrowing from t0 at a to t1 at b."""
    a, b = V(a), V(b)
    d = (b - a).normalized()
    side = d.cross(V((0, 0, 1))) if abs(d.z) < 0.99 else V((1, 0, 0))
    side.normalize()
    up = side.cross(d).normalized()
    ring = lambda c, t: [c + (side * sx + up * sy) * t / 2 for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    return loft([ring(a, t0), ring(b, t1)], mat, smooth=30)


def plate(pts, t, mat, out=(0, 0, 1)):
    """Flat panel through planar 3D points, thickened by t away from the side facing `out`."""
    pts = [V(p) for p in pts]
    n = (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
    if n.dot(V(out)) < 0:
        n = -n
    bm = bmesh.new()
    A = [bm.verts.new(p) for p in pts]
    B = [bm.verts.new(p - n * t) for p in pts]
    bm.faces.new(A)
    bm.faces.new(list(reversed(B)))
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        bm.faces.new((A[j], A[i], B[i], B[j]))
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    return kit._finish(bm, mat, smooth=30)


def flat_blob(r, seed, n=9):
    rnd = random.Random(seed)
    return [(math.cos(2 * math.pi * i / n) * r * rnd.uniform(0.55, 1.0), math.sin(2 * math.pi * i / n) * r * rnd.uniform(0.55, 1.0))
            for i in range(n)]


def wall_blot(x, z, y, r, seed):
    """Black oil smudge on a wall facing -y."""
    return slab(flat_blob(r, seed), 0.01, oil(), loc=(x, y - 0.005, z))


def floor_blot(x, y, z, r, seed, mat=None):
    """Black oil stain (or any flat blot) lying on a floor at height z."""
    return slab(flat_blob(r, seed, 11), 0.01, mat or oil(), loc=(x, y, z + 0.005), rot=(90, 0, 0))


def oil_hand(x, z, y, s, seed):
    """Robot hand smear on a wall facing -y: a pressed palm blot with three fingers dragged down and apart."""
    rnd = random.Random(seed)
    out = [wall_blot(x, z, y, 0.42 * s, seed)]
    for k in (-1, 0, 1):
        ln = s * rnd.uniform(0.7, 1.3)
        out.append(box((0.07 * s, 0.01, ln), oil(), loc=(x + k * 0.2 * s + k * ln * 0.12, y - 0.005, z - ln / 2), rot=(0, -k * 7, 0), r=0.0, n=1))
    return out


def blades(x, y, z, h, seed, n=6, mat=None):
    """Clump of flat weed blades."""
    rnd = random.Random(seed)
    mat = mat or plain("#5d7a3c", grime=0.3, vary=0.4)
    out = []
    for _ in range(n):
        hh = h * rnd.uniform(0.5, 1.0)
        w = rnd.uniform(0.06, 0.12)
        b = slab([(-w, 0), (w, 0), (rnd.uniform(-0.4, 0.4) * hh, hh)], 0.02, mat)
        out.append(move(b, rot=(rnd.uniform(-15, 15), 0, rnd.uniform(0, 180)), loc=(x + rnd.uniform(-0.2, 0.2), y + rnd.uniform(-0.2, 0.2), z)))
    return out


# ---------------------------------------------------------------- night outside
@item("sodium_lamp", "warehouse")
def sodium_lamp(P):
    """Parking-lot light: concrete pier, square pole, flat shoebox head with an orange lens, bird spikes on top."""
    pole = paint("#55534e", chip=0.25, under="#7a4a2a", grime=0.5, streaks=0.6)
    steel = metal("#7d7a74", rust=0.5)
    P.add("Body", box((2.6, 2.6, 2.5), concrete(), loc=(0, 0, 1.25), r=0.1, n=1),
          box((1.4, 1.4, 0.12), steel, loc=(0, 0, 2.56), r=0.0, n=1),
          box((0.55, 0.55, 22.9), pole, loc=(0, 0, 14.05), r=0.0, n=1),
          box((0.3, 0.06, 0.7), pole, loc=(0, -0.3, 4.2), r=0.0, n=1))
    for sx in (-1, 1):
        for sy in (-1, 1):
            P.add("Body", box((0.18, 0.18, 0.18), steel, loc=(sx * 0.55, sy * 0.55, 2.7), r=0.0, n=1))
    P.add("Body", box((0.3, 3.4, 0.3), pole, loc=(0, -1.75, 25.2), r=0.0, n=1),
          box((2.0, 3.4, 0.8), pole, loc=(0, -4.6, 25.1), r=0.06, n=1),
          box((1.8, 3.2, 0.06), steel, loc=(0, -4.6, 24.69), r=0.0, n=1))
    P.add("Glow", box((1.6, 2.8, 0.1), sodium(), loc=(0, -4.6, 24.64), r=0.0, n=1))
    spike = metal("#9a9890", rust=0.2)
    P.add("Body", box((0.2, 3.0, 0.06), spike, loc=(0, -4.6, 25.53), r=0.0, n=1))
    for i in range(10):
        y = -5.95 + i * 0.3
        for sx in (-1, 1):
            P.add("Body", beam((0, y, 25.55), (sx * 0.2, y, 25.98), 0.03, 0.03, spike))
    # rust bleeding down from the base plate, an oily grab on the pole where something climbed
    P.add("Body", box((0.5, 0.01, 1.2), plain("#7a4a2a", grime=0.3), loc=(0.4, -1.305, 1.85), r=0.0, n=1),
          oil_hand(0.05, 6.4, -0.28, 0.7, 3), floor_blot(0.8, -1.8, 0.0, 0.7, 4))


def stall_line(x, y0, y1, z, w=0.4):
    return box((w, y1 - y0, 0.01), worn_line("#e8e3d0"), loc=(x, (y0 + y1) / 2, z + 0.005), r=0.0, n=1)


@item("parking_tile", "warehouse", size=1024)
def parking_tile(P):
    """32 square lot: four 8 wide stalls nosing toward +y, half-width lines on the edges so neighbours join."""
    P.add("Body", box((32, 32, 0.2), asphalt(), loc=(0, 0, 0.1), r=0.0, n=1))
    y0, y1 = -9.0, 9.0
    for x in (-8, 0, 8):
        P.add("Body", stall_line(x, y0, y1, 0.2))
    for x in (-15.9, 15.9):
        P.add("Body", stall_line(x, y0, y1, 0.2, w=0.2))
    P.add("Body", box((32, 0.4, 0.01), worn_line("#e8e3d0"), loc=(0, y1, 0.205), r=0.0, n=1))
    stop = plain("#bdb7ab", grime=0.6, vary=0.4)
    P.add("Body", box((6.0, 0.8, 0.5), stop, loc=(-4.0, 7.4, 0.45), r=0.1, n=1),
          box((6.0, 0.8, 0.5), stop, loc=(12.3, 7.1, 0.45), rot=(0, 0, 6), r=0.1, n=1),
          box((0.8, 0.12, 0.3), plain("#6f6a62"), loc=(10.0, 6.68, 0.45), rot=(0, 0, 6), r=0.0, n=1))
    P.add("Body", words("27", 2.2, worn_line("#d8d3c0"), loc=(4.0, -6.5, 0.21), rot=(-90, 0, 0), depth=0.01))
    P.add("Body", floor_blot(-4.0, 2.5, 0.2, 1.5, 21), floor_blot(-3.2, 3.6, 0.2, 0.6, 22), floor_blot(12.0, 1.0, 0.2, 1.1, 23),
          floor_blot(-12.0, -3.0, 0.2, 0.5, 24), floor_blot(5.0, 11.5, 0.2, 0.8, 25))


@item("cart_corral", "warehouse")
def cart_corral(P):
    """Cart return: open at -x, closed at +x with a blank sign. Galvanized square tube, a little rust at the feet."""
    tube = metal("#a2a7a8", rust=0.3)
    t = 0.2
    for sy in (-1, 1):
        y = sy * 1.9
        P.add("Body", box((10.0, 0.3, 0.12), tube, loc=(0, y, 0.06), r=0.0, n=1))
        for x in (-4.9, 0.0, 4.9):
            P.add("Body", box((t, t, 3.0), tube, loc=(x, y, 1.5), r=0.0, n=1),
                  box((0.5, 0.5, 0.06), tube, loc=(x, y, 0.15), r=0.0, n=1))
        for z in (0.6, 1.7, 2.9):
            P.add("Body", box((9.8 + t, t, t), tube, loc=(0, y, z), r=0.0, n=1))
    for z in (0.6, 1.7, 2.9):
        P.add("Body", box((t, 3.8 + t, t), tube, loc=(4.9, 0, z), r=0.0, n=1))
    P.add("Body", box((t, 3.8 + t, t), tube, loc=(-4.9, 0, 2.9), r=0.0, n=1))
    sign = paint("#d9d4c6", chip=0.2, under="#7a7268", grime=0.6, streaks=0.7)
    P.add("Body", box((0.08, 3.2, 1.0), sign, loc=(5.05, 0, 3.0), r=0.02, n=1),
          box((0.02, 3.0, 0.22), plain("#5f7896", grime=0.5), loc=(5.1, 0, 3.32), r=0.0, n=1))
    for sy in (-1, 1):
        P.add("Body", box((0.06, 0.12, 0.12), tube, loc=(5.11, sy * 1.4, 3.0), r=0.0, n=1))
    P.add("Body", floor_blot(-2.0, 0.4, 0.0, 0.8, 31), box((0.25, 0.01, 0.5), oil(), loc=(1.2, -2.005, 2.75), r=0.0, n=1))


@item("stairs_nowhere", "warehouse", size=1024)
def stairs_nowhere(P):
    """Outdoor concrete flight, 8 steps rising toward +y to 6, and then nothing: the top tread drops off into the air."""
    rise, tread, w, n = 0.75, 1.4, 6.0, 8
    c = concrete()
    under = plain("#8a847a", grime=0.5, vary=0.3)
    chipped = {1: 1.4, 4: -1.8, 6: 0.6}
    y_start = -n * tread / 2
    for i in range(n):
        y0 = y_start + i * tread
        top = (i + 1) * rise
        P.add("Body", box((w, tread, top - 0.08), c, loc=(0, y0 + tread / 2, (top - 0.08) / 2), r=0.0, n=1))
        if i in chipped:
            cx, cw = chipped[i], 0.7
            P.add("Body", box((w, tread - 0.25, 0.08), c, loc=(0, y0 + 0.25 + (tread - 0.25) / 2, top - 0.04), r=0.0, n=1),
                  box((cx - cw / 2 + w / 2, 0.25, 0.08), c, loc=((-w / 2 + cx - cw / 2) / 2, y0 + 0.125, top - 0.04), r=0.0, n=1),
                  box((w / 2 - cx - cw / 2, 0.25, 0.08), c, loc=((w / 2 + cx + cw / 2) / 2, y0 + 0.125, top - 0.04), r=0.0, n=1),
                  box((cw, 0.3, 0.012), under, loc=(cx, y0 + 0.15, top - 0.074), r=0.0, n=1))
        else:
            P.add("Body", box((w, tread, 0.08), c, loc=(0, y0 + tread / 2, top - 0.04), r=0.0, n=1))
        # weeds where tread meets the next riser, and up through a crack
        rnd = random.Random(40 + i)
        if i < n - 1 and rnd.random() < 0.7:
            P.add("Body", blades(rnd.choice((-2.7, 2.6, -1.0)), y0 + tread - 0.15, top, rnd.uniform(0.6, 1.1), 50 + i))
    crack = flat("#4a4640")
    for (x, y, a, ln) in ((-1.2, y_start + 2.2, 20, 1.6), (0.3, y_start + 2.3, -35, 1.0), (1.4, y_start + 6.4, 70, 1.1), (-0.4, y_start + 9.1, 10, 2.0)):
        z = (int((y - y_start) / tread) + 1) * rise
        P.add("Body", box((ln, 0.06, 0.01), crack, loc=(x, y, z + 0.004), rot=(0, 0, a), r=0.0, n=1))
    P.add("Body", blades(-0.4, y_start + 9.1, 5.25, 0.9, 61, n=7), blades(-3.2, y_start - 0.2, 0.0, 1.4, 62, n=8),
          blades(3.3, y_start + 3.0, 0.0, 1.6, 63, n=8), blades(3.2, y_start + 0.4, 0.0, 1.0, 64))
    # handrails: square tube posts on treads 0, 4 and 7, two rails parallel to the nosing line, a short level run at the top
    rail = paint("#9fb0b8", chip=0.3, under="#6a5040", grime=0.45, streaks=0.5)
    posts = (0, 4, 7)
    for sx in (-1, 1):
        x = sx * 2.7
        pts = []
        for i in posts:
            yc = y_start + i * tread + tread / 2
            zt = (i + 1) * rise
            P.add("Body", box((0.18, 0.18, 3.0), rail, loc=(x, yc, zt + 1.5), r=0.0, n=1),
                  box((0.4, 0.4, 0.05), rail, loc=(x, yc, zt + 0.025), r=0.0, n=1))
            pts.append((yc, zt))
        (ya, za), (yb, zb) = pts[0], pts[-1]
        for h in (3.0, 1.5):
            P.add("Body", bar((x, ya - 0.1, za + h - 0.06), (x, yb, zb + h), 0.16, rail))
            for yc, zt in pts:
                P.add("Body", box((0.26, 0.26, 0.26), rail, loc=(x, yc, zt + h), r=0.0, n=1))
        P.add("Body", bar((x, yb, zb + 3.0), (x, yb + 1.0, zb + 3.0), 0.16, rail),
              bar((x, yb + 0.95, zb + 3.0), (x, yb + 0.95, zb + 2.3), 0.16, rail))
    P.add("Body", floor_blot(0.6, y_start + 5 * tread + 0.6, 5 * rise, 0.45, 71))


# ---------------------------------------------------------------- playground
def chute_path(n_pts):
    """Bed centre line (y, z) of the slide: an S from the deck at 6 down to a flat runout at 1."""
    out = []
    for k in range(n_pts):
        y = 1.5 - 8.0 * k / (n_pts - 1)
        t = min(max((y + 4.5) / 6.0, 0.0), 1.0)
        out.append((y, 1.0 + 5.0 * t * t * (3 - 2 * t)))
    return out


@item("slide", "warehouse", size=1024)
def slide(P):
    """Playground slide, chute running toward -y. Faded green plastic, scuffed, mulch dust in the runout."""
    green = plain("#6e9a6a", grime=0.55, vary=0.35)
    post = paint("#5d7f9a", chip=0.35, under="#6a5040", grime=0.5, streaks=0.5)
    path = chute_path(14)
    prof = [(-1.25, 0.7), (-1.25, -0.12), (1.25, -0.12), (1.25, 0.7), (1.1, 0.7), (1.1, 0.0), (-1.1, 0.0), (-1.1, 0.7)]
    rings = []
    for k, (y, z) in enumerate(path):
        a, b = path[max(k - 1, 0)], path[min(k + 1, len(path) - 1)]
        ty, tz = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(ty, tz)
        ny, nz = tz / ln, -ty / ln
        if nz < 0:
            ny, nz = -ny, -nz
        rings.append([(px, y + ny * pn, z + nz * pn) for px, pn in prof])
    P.add("Body", loft(rings, green, smooth=40))
    # deck, corner posts, side panels, grab bar
    P.add("Body", box((3.0, 2.5, 0.25), post, loc=(0, 2.75, 5.875), r=0.0, n=1))
    for sx in (-1, 1):
        for y in (1.5, 4.0):
            P.add("Body", box((0.35, 0.35, 9.0), post, loc=(sx * 1.5, y, 4.5), r=0.0, n=1))
        P.add("Body", box((0.12, 2.15, 2.3), green, loc=(sx * 1.5, 2.75, 7.35), r=0.04, n=1))
    P.add("Body", box((3.35, 0.2, 0.2), post, loc=(0, 1.5, 8.7), r=0.0, n=1),
          box((3.35, 0.2, 0.2), post, loc=(0, 4.0, 8.7), r=0.0, n=1))
    # ladder: square-strip stringers, flat treads
    for sx in (-1, 1):
        P.add("Body", beam((sx * 1.2, 6.0, 0.0), (sx * 1.2, 4.05, 6.0), 0.15, 0.5, post, side=(1, 0, 0)))
    for k in range(1, 8):
        f = k / 8
        P.add("Body", box((2.25, 0.55, 0.12), post, loc=(0, 6.0 - 1.95 * f, 6.0 * f - 0.06), r=0.0, n=1))
    # runout leg
    for sx in (-1, 1):
        P.add("Body", box((0.3, 0.3, 0.95), post, loc=(sx * 1.0, -5.6, 0.47), r=0.0, n=1))
    P.add("Body", box((2.3, 0.3, 0.2), post, loc=(0, -5.6, 0.78), r=0.0, n=1))
    scuff = flat("#3e443c")
    for x, y, a, ln in ((-0.3, -5.0, 8, 0.9), (0.4, -5.7, -12, 0.6), (0.1, -6.1, 3, 1.1)):
        P.add("Body", box((ln, 0.08, 0.01), scuff, loc=(x, y, 1.006), rot=(0, 0, a), r=0.0, n=1))
    dust = plain("#6e5038", grime=0.3)
    P.add("Body", floor_blot(0.2, -6.0, 1.0, 0.55, 81, dust), floor_blot(-0.4, -5.2, 1.0, 0.35, 82, dust),
          floor_blot(0.5, 2.9, 6.0, 0.6, 83, dust), floor_blot(0.0, 5.3, 0.0, 0.6, 84))


def link_chain(x, z0, z1, mat, y=0.0):
    """Flat link strip hanging from z0 down to z1: links alternate their flat side."""
    out = []
    n = max(1, round((z0 - z1) / 0.38))
    step = (z0 - z1) / n
    for k in range(n):
        zc = z0 - step * (k + 0.5)
        size = (0.14, 0.04, step + 0.06) if k % 2 == 0 else (0.04, 0.14, step + 0.06)
        out.append(box(size, mat, loc=(x, y, zc), r=0.0, n=1))
    return out


def belt_seat(x0, x1, z_end, sag, mat):
    """Rubber belt seat between two chain ends, sagging in the middle."""
    xm = (x0 + x1) / 2
    a, b = (xm - 0.5, z_end - sag), (xm + 0.5, z_end - sag)
    return [beam((x0, 0, z_end), (a[0], 0, a[1]), 0.12, 0.8, mat, side=(0, 0, 1)),
            box((1.0, 0.8, 0.12), mat, loc=(xm, 0, z_end - sag), r=0.0, n=1),
            beam((b[0], 0, b[1]), (x1, 0, z_end), 0.12, 0.8, mat, side=(0, 0, 1))]


@item("swing_set", "warehouse")
def swing_set(P):
    """A-frame swing set. One seat hangs; the other has been wound up and over the top bar."""
    frame = paint("#a8574a", chip=0.45, under="#6a5040", grime=0.5, streaks=0.6)
    chain = metal("#8f8c86", rust=0.45)
    rubber = plain("#2a2827", grime=0.35)
    top = 10.0
    P.add("Body", box((14.0, 0.45, 0.45), frame, loc=(0, 0, top - 0.22), r=0.0, n=1))
    for sx in (-1, 1):
        for sy in (-1, 1):
            P.add("Body", bar((sx * 6.7, 0, top - 0.2), (sx * 7.0, sy * 3.4, 0.0), 0.4, frame),
                  box((0.8, 0.8, 0.08), frame, loc=(sx * 7.0, sy * 3.4, 0.04), r=0.0, n=1))
        P.add("Body", box((0.3, 4.2, 0.3), frame, loc=(sx * 6.82, 0, 3.4), r=0.0, n=1))
    for x in (-4.6, -2.4, 2.4, 4.6):
        P.add("Body", box((0.25, 0.55, 0.55), chain, loc=(x, 0, top - 0.22), r=0.0, n=1))
    # hanging seat
    for x in (-4.6, -2.4):
        P.add("Body", link_chain(x, top - 0.5, 2.0, chain), box((0.2, 0.2, 0.2), chain, loc=(x, 0, 2.0), r=0.0, n=1))
    P.add("Body", belt_seat(-4.6, -2.4, 1.95, 0.3, rubber))
    # wound seat: chains wrapped twice around the bar, seat jammed up under it
    for x in (2.4, 4.6):
        for dx in (-0.12, 0.12):
            xx = x + dx
            P.add("Body", box((0.1, 0.04, 0.75), chain, loc=(xx, -0.27, top - 0.22), r=0.0, n=1),
                  box((0.1, 0.58, 0.04), chain, loc=(xx, 0, top + 0.03), r=0.0, n=1),
                  box((0.1, 0.04, 0.75), chain, loc=(xx, 0.27, top - 0.22), r=0.0, n=1))
        P.add("Body", link_chain(x, top - 0.55, 8.6, chain, y=0.27))
    seat = belt_seat(2.4, 4.6, 8.55, 0.15, rubber)
    P.add("Body", move(seat, rot=(28, 0, 0), loc=(0, 0.27, 0), pivot=(3.5, 0, 8.55)))
    P.add("Body", floor_blot(-3.5, 0.3, 0.0, 1.0, 91, plain("#6e5038", grime=0.3)), floor_blot(-3.0, -0.6, 0.0, 0.4, 92))


@item("mulch_tile", "warehouse", size=1024)
def mulch_tile(P):
    """32 square of wood chips inside a low timber border. The border is half width on each edge, so neighbours share one timber."""
    P.add("Body", box((31.2, 31.2, 0.3), mulch(), loc=(0, 0, 0.15), r=0.0, n=1))
    timber = wood("#7a5a3a", "#3e2a1a", axis="x", wear=0.4)
    timber_y = wood("#7a5a3a", "#3e2a1a", axis="y", wear=0.4)
    for s in (-1, 1):
        P.add("Body", box((32, 0.4, 0.7), timber, loc=(0, s * 15.8, 0.35), r=0.02, n=1),
              box((0.4, 31.2, 0.7), timber_y, loc=(s * 15.8, 0, 0.35), r=0.02, n=1))
    rnd = random.Random(101)
    tones = [chip(c) for c in ("#6a4a32", "#8a6444", "#4e3524", "#9a7048")]
    for _ in range(150):
        x, y = rnd.uniform(-15, 15), rnd.uniform(-15, 15)
        P.add("Body", box((rnd.uniform(0.5, 1.0), rnd.uniform(0.18, 0.35), 0.05), rnd.choice(tones),
                          loc=(x, y, 0.31), rot=(0, rnd.uniform(-6, 6), rnd.uniform(0, 180)), r=0.0, n=1))
    P.add("Body", floor_blot(5.0, -6.0, 0.3, 1.3, 102), floor_blot(6.2, -4.8, 0.3, 0.5, 103))


# ---------------------------------------------------------------- padded play room
@item("padded_floor", "warehouse", size=1024)
def padded_floor(P):
    """Sixteen 8 square vinyl mats in a four colour checker, dark seams between, one lifted at a corner."""
    P.add("Body", box((32, 32, 0.1), plain("#1c1c20", grime=0.2), loc=(0, 0, 0.05), r=0.0, n=1))
    for i in range(4):
        for j in range(4):
            x, y = -12 + i * 8, -12 + j * 8
            mat = vinyl(VINYL[(i + 2 * (j % 2)) % 4])
            if (i, j) == (2, 1):
                m = box((7.9, 7.9, 0.3), mat, loc=(x, y, 0.25), r=0.1, n=3)
                cx, cy = x + 3.95, y + 3.95
                kit.warp(m, lambda c: V((c.x, c.y, c.z + 1.6 * max(0.0, 1.0 - (abs(c.x - cx) + abs(c.y - cy)) / 4.0) ** 2)))
                P.add("Body", m)
            else:
                P.add("Body", box((7.9, 7.9, 0.3), mat, loc=(x, y, 0.25), r=0.1, n=1))
    P.add("Body", floor_blot(-11.0, 4.5, 0.4, 0.7, 111), floor_blot(-10.2, 5.4, 0.4, 0.3, 112))


@item("padded_wall", "warehouse", size=1024, pivots={"Body": (0, 0, 0)})
def padded_wall(P):
    """16 x 1 x 16 wall of buttoned vinyl panels (4 square) on a plywood back. One panel torn open to the foam.
    The flap and foam crumbs stick out in front, so the origin is pinned to the wall line instead of the bounding box."""
    P.add("Body", box((16, 0.6, 16), plain("#6a5a44", grime=0.4), loc=(0, 0.2, 8), r=0.0, n=1))
    torn = (2, 1)
    for i in range(4):
        for j in range(4):
            x, z = -6 + i * 4, 2 + j * 4
            color = VINYL[(i + j) % 4]
            mat = vinyl(color)
            if (i, j) == torn:
                continue
            P.add("Body", box((3.94, 0.4, 3.94), mat, loc=(x, -0.3, z), r=0.15, n=1))
            for bx in (-1, 1):
                for bz in (-1, 1):
                    P.add("Body", box((0.2, 0.06, 0.2), plain(kit_mix(color, "#101014", 0.35), grime=0.2),
                                      loc=(x + bx * 0.95, -0.51, z + bz * 0.95), r=0.0, n=1))
    x, z = -6 + torn[0] * 4, 2 + torn[1] * 4
    mat = vinyl(VINYL[sum(torn) % 4])
    foam = cloth("#e3cf8e", dirt=0.35, weave=90, dirtcolor="#8a7448")
    P.add("Body", box((3.7, 0.3, 3.7), foam, loc=(x, -0.25, z), r=0.1, n=1),
          box((0.6, 0.4, 3.94), mat, loc=(x - 1.67, -0.3, z), r=0.12, n=1),
          box((3.94, 0.4, 0.7), mat, loc=(x, -0.3, z - 1.62), r=0.12, n=1),
          box((1.2, 0.4, 0.5), mat, loc=(x + 1.37, -0.3, z + 1.72), r=0.12, n=1))
    # the torn skin peels down and out from the top edge
    P.add("Body", plate([(x - 1.37, -0.5, z + 1.97), (x + 0.77, -0.5, z + 1.97), (x + 0.5, -1.2, z + 0.4), (x - 1.0, -1.0, z + 0.1)],
                        0.08, mat, out=(0, -1, 0.4)))
    rnd = random.Random(121)
    for _ in range(5):
        P.add("Body", box((rnd.uniform(0.2, 0.45),) * 2 + (0.18,), foam, loc=(x + rnd.uniform(-1.5, 1.5), -0.9 - rnd.uniform(0, 0.8), 0.09),
                          rot=(0, 0, rnd.uniform(0, 90)), r=0.05, n=1))
    P.add("Body", oil_hand(x + 3.2, z + 0.3, -0.5, 0.8, 122), oil_hand(x - 3.6, z - 2.8, -0.5, 0.7, 123))


def kit_mix(a, b, k):
    ca = [int(a.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)]
    cb = [int(b.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)]
    return "#" + "".join(f"{round(p + (q - p) * k):02x}" for p, q in zip(ca, cb))


FAN_TOP, FAN_HUB = 3.0, 1.2


@item("ceiling_fan", "warehouse", pivots={"Body": (0, 0, FAN_TOP), "Glow": (0, 0, FAN_TOP), "Spin": (0, 0, FAN_HUB)})
def ceiling_fan(P):
    """70s ceiling fan. Body and Glow pivot at the ceiling mount; Spin (blades) pivots at the hub, turn it about z."""
    brass = metal("#a88a52", rust=0.15)
    shell = paint("#6a4e36", chip=0.1, under="#3a2a1c", grime=0.4, streaks=0.3)
    P.add("Body", cyl(0.55, 0.32, brass, loc=(0, 0, FAN_TOP - 0.16), seg=16, bevel=0.06),
          bar((0, 0, FAN_TOP - 0.3), (0, 0, 1.85), 0.16, brass),
          cyl(0.75, 0.5, shell, loc=(0, 0, 1.6), r2=0.6, seg=20, bevel=0.08),
          cyl(0.8, 0.08, brass, loc=(0, 0, 1.38), seg=20, bevel=0.02),
          cyl(0.62, 0.1, brass, loc=(0, 0, 1.0), seg=16, bevel=0.02),
          beam((0.35, 0, 0.75), (0.35, 0, 0.2), 0.05, 0.02, brass),
          box((0.12, 0.03, 0.18), brass, loc=(0.35, 0, 0.12), r=0.0, n=1))
    P.add("Glow", cyl(0.55, 0.32, glow("#ffe2a8", core="#fff6e0", amount=0.2), loc=(0, 0, 0.8), r2=0.45, seg=16, bevel=0.06))
    blade = walnut()
    P.add("Spin", cyl(0.7, 0.14, brass, loc=(0, 0, FAN_HUB + 0.05), seg=20, bevel=0.03))
    for k in range(5):
        iron = box((1.3, 0.24, 0.06), brass, loc=(1.05, 0, FAN_HUB - 0.04), r=0.0, n=1)
        b = slab([(1.3, -0.42), (4.5, -0.5), (4.85, -0.3), (4.85, 0.3), (4.5, 0.5), (1.3, 0.42)], 0.06, blade, rot=(90, 0, 0))
        move(b, rot=(10, 0, 0), loc=(0, 0, FAN_HUB - 0.1))
        P.add("Spin", move([iron, b], rot=(0, 0, 72 * k)))


# ---------------------------------------------------------------- giant things
@item("monolith", "warehouse", size=1024)
def monolith(P):
    """The slab: 20 x 6 x 40, matte black, faint seams, one cold line of light. Hang it in the air, no wires."""
    black = void()
    seam = flat("#060607")
    P.add("Body", box((20, 6, 40), black, loc=(0, 0, 20), r=0.04, n=1))
    for z in (8, 16, 32):
        P.add("Body", box((20.02, 6.02, 0.05), seam, loc=(0, 0, z), r=0.0, n=1))
    P.add("Body", box((19.0, 6.02, 0.05), seam, loc=(-0.5, 0, 24), r=0.0, n=1))
    for x in (-5.0, 5.0):
        P.add("Body", box((0.05, 6.02, 39.9), seam, loc=(x, 0, 20), r=0.0, n=1))
    P.add("Body", box((20.02, 0.05, 39.9), seam, loc=(0, 0, 20), r=0.0, n=1))
    P.add("Glow", box((13.0, 0.03, 0.06), glow("#bfe6ff", core="#ffffff", amount=0.15), loc=(-3.5, -3.012, 24), r=0.0, n=1))


@item("rocking_horse_giant", "warehouse", size=1024)
def rocking_horse_giant(P):
    """A wooden rocking horse 22 tall, facing -y. Chunky carved blocks, square tapered legs, yarn mane, painted eye."""
    hide = paint("#e4d8c0", chip=0.35, under="#a07a50", under2="#6a4a30", grime=0.5, streaks=0.5)
    red = paint("#b0483c", chip=0.45, under="#a07a50", under2="#6a4a30", grime=0.5, streaks=0.5)
    dark = paint("#2e2622", chip=0.3, under="#a07a50", grime=0.3, streaks=0.2)
    yarn = cloth("#4a3226", dirt=0.25, weave=140)
    # rockers: arcs of radius 37, touching the floor at y = 0
    R, L, h = 37.0, 24.0, 1.2
    bot = lambda y: R - math.sqrt(R * R - y * y)
    for sx in (-1, 1):
        for k in range(12):
            y0, y1 = -L / 2 + L * k / 12, -L / 2 + L * (k + 1) / 12
            P.add("Body", slab([(y0, bot(y0)), (y1, bot(y1)), (y1, bot(y1) + h), (y0, bot(y0) + h)], 0.9, red,
                               loc=(sx * 3.3, 0, 0), rot=(0, 0, 90)))
    for y in (-9.5, 0.0, 9.5):
        P.add("Body", box((7.5, 0.9, 0.5), red, loc=(0, y, bot(y) + 0.8), r=0.0, n=1))
    for sx in (-1, 1):
        for sy in (-1, 1):
            top, foot = V((sx * 1.7, sy * 4.3, 10.8)), V((sx * 3.3, sy * 6.6, bot(6.6) + 1.0))
            knee = top.lerp(foot, 0.86)
            P.add("Body", taper(top, knee, 1.7, 1.05, hide), taper(knee, foot, 1.05, 0.95, dark))
    P.add("Body", box((5.0, 12.0, 5.0), hide, loc=(0, 0, 13.0), r=0.7, n=1))
    P.add("Body", taper((0, -4.4, 13.8), (0, -7.6, 19.6), 3.6, 2.9, hide))
    # saddle and girth strap
    P.add("Body", box((5.3, 3.4, 0.16), red, loc=(0, 0.8, 15.52), r=0.05, n=1),
          box((5.25, 0.5, 0.06), dark, loc=(0, -0.6, 13.0), r=0.0, n=1))
    for sx in (-1, 1):
        P.add("Body", box((0.06, 2.8, 2.4), red, loc=(sx * 2.52, 0.8, 14.3), r=0.02, n=1),
              beam((sx * 2.62, 0.8, 14.0), (sx * 2.62, 0.8, 11.8), 0.18, 0.06, dark),
              box((0.08, 0.7, 0.18), dark, loc=(sx * 2.62, 0.8, 11.7), r=0.0, n=1))
    # dapples
    rnd = random.Random(131)
    for _ in range(9):
        sx = rnd.choice((-1, 1))
        y, z, r = rnd.uniform(-4.5, 4.5), rnd.uniform(11.2, 13.6), rnd.uniform(0.3, 0.6)
        P.add("Body", slab(flat_blob(r, rnd.randint(0, 999), 8), 0.01, plain("#a8a296", grime=0.2), loc=(sx * 2.51, y, z), rot=(0, 0, 90)))
    # head, built level at the origin, then tipped nose-down and set on the neck
    head = [box((2.9, 6.0, 3.0), hide, r=0.5, n=1),
            box((2.96, 1.4, 1.0), dark, loc=(0, -2.4, -0.8), r=0.3, n=1),
            bar((-2.2, 0.6, 0.9), (2.2, 0.6, 0.9), 0.35, dark)]
    for sx in (-1, 1):
        head += [box((0.5, 0.5, 0.5), red, loc=(sx * 2.3, 0.6, 0.9), r=0.05, n=1),
                 slab([(-0.35, 0.0), (0.35, 0.0), (0.05, 1.1)], 0.25, hide, loc=(sx * 0.8, 2.0, 1.4)),
                 cyl(0.45, 0.02, plain("#f2ead8", grime=0.1), loc=(sx * 1.46, -0.6, 0.55), rot=(0, 90, 0), seg=12, bevel=0.0),
                 cyl(0.22, 0.02, flat("#1a1614"), loc=(sx * 1.48, -0.7, 0.5), rot=(0, 90, 0), seg=10, bevel=0.0),
                 box((0.02, 1.2, 0.06), flat("#3a2a24"), loc=(sx * 1.49, -2.3, -1.15), r=0.0, n=1),
                 box((0.5, 0.02, 0.3), flat("#1a1614"), loc=(sx * 0.6, -3.01, -0.6), r=0.0, n=1),
                 beam((sx * 1.46, -1.6, -0.9), (sx * 1.46, 1.8, 0.6), 0.2, 0.05, red, side=(0, 0, 1))]
    P.add("Body", move(head, rot=(25, 0, 0), loc=(0, -9.6, 19.9)))
    # yarn mane: flat strips hanging off the neck crest to both sides, then a forelock and a tail
    for k in range(10):
        f = k / 9
        half = (3.6 - 0.7 * f) / 2
        crest = V((0, -4.4 - 3.2 * f, 13.8 + 5.8 * f)) + V((0, 0.876, 0.483)) * (half + 0.03)
        for sx in (-1, 1) if k % 2 == 0 else (rnd.choice((-1, 1)),):
            side = crest + V((sx * (half + 0.04), -0.5, -0.4))
            P.add("Body", beam(crest, side, 0.45, 0.06, yarn, side=(0, 1, 0)),
                  beam(side, side + V((sx * 0.15, 0.3, -rnd.uniform(1.6, 2.6))), 0.45, 0.06, yarn, side=(0, 1, 0)))
    P.add("Body", beam((0, -7.9, 21.6), (0, -9.4, 20.6), 0.6, 0.06, yarn, side=(1, 0, 0)))
    for k, dx in enumerate((-0.5, -0.2, 0.15, 0.45, 0.0)):
        P.add("Body", beam((dx * 0.6, 6.0, 14.6), (dx * 1.6, 8.4 + k * 0.15, 9.2 + k * 0.3), 0.45, 0.06, yarn, side=(1, 0, 0)))
    P.add("Body", floor_blot(1.5, -3.0, 0.0, 1.2, 132), oil_hand(-2.0, 12.6, -6.0, 1.0, 133))


@item("hedge_wall", "warehouse", size=1024)
def hedge_wall(P):
    """Maze hedge 16 x 3 x 24: moulded plastic panels on a dark core, cut flat, sitting on a hidden tray. Ends butt flush."""
    P.add("Body", box((15.98, 2.6, 0.32), plain("#2e302c", grime=0.4), loc=(0, 0, 0.16), r=0.0, n=1),
          box((16, 2.8, 23.6), plain("#22381f", grime=0.2), loc=(0, 0, 12.1), r=0.0, n=1))
    shades = [leaf(c) for c in ("#4f8446", "#4a7e42", "#548a4a")]
    rnd = random.Random(141)
    for sy in (-1, 1):
        for i in range(4):
            for j in range(6):
                P.add("Body", box((3.94, 0.1, 3.87), rnd.choice(shades), loc=(-6 + i * 4, sy * 1.45, 0.3 + 3.93 * j + 1.965), r=0.0, n=1))
    for i in range(4):
        P.add("Body", box((3.94, 2.94, 0.1), rnd.choice(shades), loc=(-6 + i * 4, 0, 23.95), r=0.0, n=1))
    P.add("Body", oil_hand(-3.0, 4.2, -1.5, 1.0, 142))


main()
