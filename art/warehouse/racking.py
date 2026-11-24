"""Warehouse racking, stock and clutter for the abandoned big-box store.

Dull galvanized and faded painted steel, sun-bleached cardboard, dusty shrink wrap, black robot oil.
Rack bays: 12 wide (uprights' outer faces at x = +-6, so bays butt side by side), 4.5 deep,
beam tops at 5.5 / 11 / 16.5 / 22, frames 26 tall. Each bay carries both of its frames.
"""
import math, os, random, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "_kit"))
from ykit import *  # noqa
from mathutils import Matrix, Vector
import kit

kit.DUST = 1.0

BAY_W, BAY_D, RACK_H, POST = 12.0, 4.5, 26.0, 0.3
LEVELS = (5.5, 11.0, 16.5, 22.0)
PAL_W, PAL_D, PAL_H = 5.0, 4.4, 0.48
SLOT_X = (-2.8, 2.8)

TEAL = "#3f706b"
ORANGE = "#bf6a36"
GALV = "#8c918d"
YELLOW = "#c8a23c"
CREAM = "#d4c9ab"
CARTON = ("#b08a5c", "#9c7650", "#c2a47a", "#8a6a46", "#bfa070", "#a8865e")
CHEER = ("#c98a74", "#d2b978", "#8db3a1", "#8aa8c2", "#c27d6d", "#b3a3c4")  # faded old-store colours
PRIMARY = ("#b04a40", "#c9a43c", "#4a6c9c", "#4f8a5a", "#d9a3b0", "#9cc4c9")  # faded primaries and pastels: the dreamcore pockets
WORDS = ("KORVA", "FENK", "MUNO", "DRASK", "OLLU", "PIRK", "ZEBB", "VOBA")


# ---------------------------------------------------------------- materials
def upright_paint():
    return paint(TEAL, chip=0.3, grime=0.55, streaks=0.5)


def beam_paint():
    return paint(ORANGE, chip=0.35, grime=0.5, streaks=0.4)


def galv():
    return metal(GALV, rust=0.3)


def rusty():
    return metal("#6f5b4a", rust=0.85)


def oil():
    return flat("#0d0c0b")  # flat: dust must not settle on wet oil


def label():
    return plain(CREAM, grime=0.45, vary=0.3)


def ink():
    return plain("#2b2623", grime=0.3, vary=0.45)


def mix(a, b, t):
    ca, cb = (int(a[i:i + 2], 16) for i in (1, 3, 5)), (int(b[i:i + 2], 16) for i in (1, 3, 5))
    return "#" + "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(ca, cb))


def film(under="#9c8a70"):
    """Dusty stretch wrap: milky grey with what's underneath showing through."""
    return plain(mix("#c3c6c0", under, 0.5), grime=0.55, vary=0.15)


def pallet_wood():
    return wood("#8f7350", "#4e3c28", axis="x", wear=0.3)


def crate_wood():
    return wood("#9b7a50", "#4f3b26", axis="x", wear=0.35)


def carton_mat(R, color):
    if R.random() < 0.18:  # sat in a puddle: water wicked up the bottom
        return fade("#6a5034", color, lo=0.05, hi=0.4, grime=0.35)
    return cardboard(color)


def fabric(color):
    return cloth(color, dirt=0.55, weave=70)


# ---------------------------------------------------------------- helpers
def strap(a, b, w, t, mat, up=(0, 0, 1)):
    """Straight bar from a to b: t thick, w wide toward `up`."""
    a, b = V(a), V(b)
    x = (b - a).normalized()
    y = V(up).cross(x)
    if y.length < 1e-4:
        y = V((0, 1, 0)).cross(x)
    y.normalize()
    z = x.cross(y)
    o = box(((b - a).length, t, w), mat, r=0.0, n=1)
    rot = Matrix(((x.x, y.x, z.x, 0), (x.y, y.y, z.y, 0), (x.z, y.z, z.z, 0), (0, 0, 0, 1)))
    o.data.transform(Matrix.Translation((a + b) / 2) @ rot)
    return o


def face_turn(obs, face):
    """Decor is built on the -y face; face=+1 spins it to the back."""
    if face > 0:
        move(obs, rot=(0, 0, 180))
    return obs


def streak(x, y, z, length, w=0.14, face=-1, mat=None):
    """Black oil run down a surface facing -y (or +y), top at z."""
    poly = [(-w / 2, 0), (w / 2, 0), (w * 0.35, -length * 0.5), (w * 0.22, -length * 0.85), (0, -length),
            (-w * 0.25, -length * 0.7), (-w * 0.4, -length * 0.3)]
    o = slab(poly, 0.01, mat or oil(), loc=(0, -0.005, 0))
    face_turn(o, face)
    return move(o, loc=(x, y, z))


def handprint(x, y, z, s=1.0, tilt=0, face=-1):
    """A robot's three-fingered oily handprint on a surface facing -y."""
    m = oil()
    out = [box((0.28 * s, 0.01, 0.3 * s), m, r=0.0, n=1)]
    for i, fx in enumerate((-0.09, 0.0, 0.09)):
        out.append(box((0.065 * s, 0.01, 0.24 * s), m, loc=(fx * s, 0, 0.25 * s), rot=(0, (i - 1) * -12, 0), r=0.0, n=1))
    out.append(box((0.065 * s, 0.01, 0.18 * s), m, loc=(-0.18 * s, 0, 0.0), rot=(0, 45, 0), r=0.0, n=1))
    move(out, loc=(0, -0.006, 0), rot=(0, tilt, 0))
    face_turn(out, face)
    return move(out, loc=(x, y, z))


def puddle(R, x, y, r=1.0, mat=None):
    """Flat irregular oil puddle on the floor."""
    pts = []
    for i in range(10):
        a = 2 * math.pi * i / 10
        k = r * R.uniform(0.6, 1.15)
        pts.append((math.cos(a) * k * 1.3, math.sin(a) * k))
    return slab(pts, 0.02, mat or oil(), loc=(x, y, 0.011), rot=(90, 0, R.uniform(0, 180)))


def arrows(x, y, z, s, face=-1):
    """Stencilled 'this way up' arrows."""
    poly = [(-0.08, -0.4), (0.08, -0.4), (0.08, 0.08), (0.22, 0.08), (0, 0.4), (-0.22, 0.08), (-0.08, 0.08)]
    out = [slab([(px * s + dx, pz * s) for px, pz in poly], 0.012, ink(), loc=(0, -0.006, 0)) for dx in (-0.3 * s, 0.3 * s)]
    face_turn(out, face)
    return move(out, loc=(x, y, z))


def carton(R, size, loc=(0, 0, 0), rot=0, color=None, faces=(-1,), crushed=0.0, deco=0.5, tip=(0, 0), word=False):
    """One cardboard box, bottom centre at loc. Decor (label, arrows, a faded store-colour band) on the faces asked for."""
    w, d, h = size
    color = color or R.choice(CARTON)
    mat = carton_mat(R, color) if color in CARTON else plain(color, grime=0.5, vary=0.35)
    o = box(size, mat, loc=(0, 0, h / 2), r=0.0, n=2 if crushed else 1)
    out = [o]
    if crushed:
        crumple(o, 0.04 + crushed * 0.06, 1.4, seed=R.randint(0, 99))
        warp(o, lambda v: V((v.x * (1 + crushed * 0.12 * v.z / h), v.y, v.z * (1 - crushed * 0.35 * v.z / h))))
    else:
        for f in faces:
            dec = []
            r = R.random()
            if r < deco and w > 0.6 and h > 0.5:
                lw, lh = min(0.9, w * 0.42), min(0.55, h * 0.32)
                lx = R.uniform(-(w - lw) / 2 + 0.05, (w - lw) / 2 - 0.05)
                lz = R.uniform(h * 0.5, h * 0.78)
                dec.append(box((lw, 0.02, lh), label(), loc=(lx, -d / 2 - 0.01, lz), r=0.0, n=1))
                if word:
                    dec.append(words(R.choice(WORDS), lh * 0.42, ink(), loc=(lx, -d / 2 - 0.022, lz + lh * 0.12), depth=0.006))
                else:
                    dec.append(box((lw * 0.7, 0.022, 0.05), ink(), loc=(lx, -d / 2 - 0.012, lz + lh * 0.15), r=0.0, n=1))
            elif r < deco + 0.15 and h > 0.7:
                dec += arrows(R.uniform(-w * 0.2, w * 0.2), -d / 2, h * 0.5, min(0.7, h * 0.5))
            elif r < deco + 0.27:
                dec.append(box((w * 0.98, 0.02, h * 0.16), plain(R.choice(CHEER), grime=0.5, vary=0.35),
                               loc=(0, -d / 2 - 0.01, h * R.uniform(0.25, 0.7)), r=0.0, n=1))
            out += face_turn(dec, f)
    if tip != (0, 0):
        move(out, rot=(tip[0], tip[1], 0), pivot=(0, 0, 0))
        move(out, loc=(0, 0, -min(v.co.z for o in out for v in o.data.vertices)))  # tipped boxes rest on the floor
    return move(out, loc=loc, rot=(0, 0, rot))


def open_carton(R, size, loc=(0, 0, 0), rot=0, color=None, spill=True):
    """Box with its top flaps folded open, a few small packs inside."""
    w, d, h = size
    t = 0.05
    m = cardboard(color or R.choice(CARTON))
    out = [box((w, d, t), m, loc=(0, 0, t / 2), r=0.0, n=1)]
    for sx in (-1, 1):
        out.append(box((t, d, h), m, loc=(sx * (w / 2 - t / 2), 0, h / 2), r=0.0, n=1))
        out.append(box((w, t, h), m, loc=(0, sx * (d / 2 - t / 2), h / 2), r=0.0, n=1))
    for sx in (-1, 1):
        f = box((w * 0.98, t, d * 0.48), m, loc=(0, 0, d * 0.24), r=0.0, n=1)
        move(f, rot=(sx * R.uniform(100, 140), 0, 0))
        out.append(move(f, loc=(0, sx * d / 2, h)))
        f = box((t, d * 0.98, w * 0.45), m, loc=(0, 0, w * 0.22), r=0.0, n=1)
        move(f, rot=(0, sx * -R.uniform(95, 150), 0))
        out.append(move(f, loc=(sx * w / 2, 0, h)))
    if spill:
        c = R.choice(CHEER)
        for i in range(3):
            out.append(box((w * 0.3, d * 0.35, h * 0.5), plain(c, grime=0.5, vary=0.3),
                           loc=(R.uniform(-w * 0.25, w * 0.25), R.uniform(-d * 0.2, d * 0.2), h * (0.55 + 0.15 * i)),
                           rot=(R.uniform(-30, 30), R.uniform(-30, 30), R.uniform(0, 90)), r=0.0, n=1))
    return move(out, loc=loc, rot=(0, 0, rot))


def pallet(x=0.0, y=0.0, z=0.0, rot=0, w=PAL_W, d=PAL_D, mat=None, boards=5, broken=None):
    """Wooden pallet, 0.48 tall: bottom boards, three runners, top boards running along x."""
    mat = mat or pallet_wood()
    out = []
    for i in range(3):
        out.append(box((w, 0.55, 0.08), mat, loc=(0, -d / 2 + 0.275 + i * (d - 0.55) / 2, 0.04), r=0.0, n=1))
        out.append(box((0.55, d, 0.3), mat, loc=(-w / 2 + 0.275 + i * (w - 0.55) / 2, 0, 0.23), r=0.0, n=1))
    for i in range(boards):
        by = -d / 2 + 0.3 + i * (d - 0.6) / (boards - 1)
        if i == broken:
            out.append(box((w * 0.55, 0.6, 0.1), mat, loc=(-w * 0.225, by, 0.43), r=0.0, n=1))
            b = box((w * 0.42, 0.6, 0.1), mat, loc=(w * 0.21, 0, 0), r=0.0, n=1)
            out.append(move(b, loc=(w * 0.08, by, 0.45), rot=(0, -6, 0)))
        else:
            out.append(box((w, 0.6, 0.1), mat, loc=(0, by, 0.43), r=0.0, n=1))
    return move(out, loc=(x, y, z), rot=(0, 0, rot))


def stack_boxes(R, x, y, z, w=PAL_W, d=PAL_D, hmax=3.8, fill=0.8, color=None, words_on=0):
    """Pallet load of cartons in columns, some columns short where boxes were taken."""
    out = []
    cols, rows = R.choice((2, 2, 3, 1)), R.choice((1, 2, 2))
    bh = R.choice((0.9, 1.1, 1.3, 1.6))
    layers = max(1, int(hmax / (bh + 0.01)))
    bw, bd = w / cols, d / rows
    color = color or (R.choice(PRIMARY) if R.random() < 0.15 else R.choice(CARTON))
    for i in range(cols):
        for j in range(rows):
            n = layers if R.random() < fill else R.randint(0, layers - 1)
            for k in range(n):
                fs = ((-1,) if j == 0 else ()) + ((1,) if j == rows - 1 else ())
                out += carton(R, (bw - 0.06, bd - 0.06, bh),
                              loc=(x - w / 2 + bw * (i + 0.5) + R.uniform(-0.05, 0.05), y - d / 2 + bd * (j + 0.5) + R.uniform(-0.04, 0.04), z + k * (bh + 0.005)),
                              rot=R.uniform(-3, 3), color=color if R.random() < 0.8 else R.choice(CARTON), faces=fs,
                              word=words_on > 0 and j == 0 and k == n - 1 and R.random() < 0.5)
    return out


def wrapped(R, x, y, z, w=PAL_W, d=PAL_D, h=3.6, torn=True, full=False):
    """Shrink-wrapped pallet load: dusty film, top layer of boxes peeking out, a torn flap."""
    out = []
    bh = h / 3
    color = R.choice(CARTON)
    if not full:
        for i in range(2):
            for j in range(2):
                out += carton(R, (w / 2 - 0.05, d / 2 - 0.05, bh), loc=(x - w / 4 + i * w / 2, y - d / 4 + j * d / 2, z + 2 * bh),
                              rot=R.uniform(-2, 2), color=color, faces=((-1,) if j == 0 else (1,)), deco=0.35)
    fh = h if full else 2 * bh + bh * R.uniform(0.3, 0.6)
    f = box((w + 0.16, d + 0.16, fh), film(color), loc=(x, y, z + fh / 2), r=0.0 if not full else 0.15, n=3)
    crumple(f, 0.045, 1.8, seed=R.randint(0, 99))
    out.append(f)
    seam = plain(mix("#c3c6c0", color, 0.6), grime=0.5, vary=0.2)
    for sy in (-1, 1):  # box seams showing through the wrap, and the overlapping wrap bands
        out.append(box((0.05, 0.02, fh * 0.9), seam, loc=(x, y + sy * (d / 2 + 0.13), z + fh * 0.5), r=0.0, n=1))
        out.append(box((w * 0.9, 0.02, 0.05), seam, loc=(x, y + sy * (d / 2 + 0.13), z + bh), r=0.0, n=1))
    for zz in (fh * 0.3, fh * 0.72):
        out.append(box((w + 0.26, d + 0.26, 0.3), film(color), loc=(x, y, z + zz), r=0.0, n=1))
    if torn:
        tx, tz = x + R.uniform(-w * 0.25, w * 0.25), z + fh * R.uniform(0.35, 0.6)
        hole = [(-0.3, -0.6), (-0.05, -0.4), (0.2, -0.65), (0.35, -0.2), (0.5, 0.15), (0.3, 0.35), (0.4, 0.7),
                (0.0, 0.5), (-0.2, 0.7), (-0.4, 0.25), (-0.55, -0.15)]
        out.append(slab(hole, 0.02, cardboard(color), loc=(tx, y - d / 2 - 0.2, tz)))
        flap = box((1.1, 0.03, 1.0), film(color), loc=(0, 0, -0.5), r=0.0, n=2)
        crumple(flap, 0.06, 2.5, seed=R.randint(0, 99))
        out.append(move(flap, loc=(tx + 0.1, y - d / 2 - 0.12, tz - 0.4), rot=(-18, 0, R.uniform(-15, 15))))
    return out


def sacks(R, x, y, z, w=PAL_W, d=PAL_D, layers=4, color=None):
    """Paper or burlap sacks laid in alternating courses."""
    out = []
    color = color or R.choice(("#c8b991", "#b5a27a", "#d2c7a8"))
    m = cloth(color, dirt=0.45, weave=40)
    band = plain(R.choice(CHEER), grime=0.5, vary=0.35)
    sh = 0.55
    for k in range(layers):
        along = k % 2 == 0
        n = 2 if along else 3
        for i in range(n):
            if k == layers - 1 and R.random() < 0.3:
                continue
            if along:
                size, loc = (w - 0.1, d / 2 - 0.08, sh), (x, y - d / 4 + i * d / 2, 0)
            else:
                size, loc = (w / 3 - 0.08, d - 0.1, sh), (x - w / 3 + i * w / 3, y, 0)
            s = box(size, m, loc=(0, 0, sh / 2), r=0.2, n=1)
            crumple(s, 0.05, 1.5, seed=k * 5 + i)
            out.append(move(s, loc=(loc[0] + R.uniform(-0.08, 0.08), loc[1] + R.uniform(-0.08, 0.08), z + k * (sh - 0.04)),
                            rot=(0, 0, R.uniform(-4, 4))))
            if along and i == 0 and R.random() < 0.6:
                out.append(box((size[0] * 0.5, 0.02, sh * 0.35), band, loc=(loc[0], loc[1] - size[1] / 2 - 0.02, z + k * (sh - 0.04) + sh * 0.5), r=0.0, n=1))
    return out


def drum(R, x, y, z, color=None, h=2.9, r=0.95, dent=0.0, lid=True):
    """Steel drum: two rolling ribs, top rim, a bung. dent pushes in one side."""
    m = paint(color or R.choice((TEAL, ORANGE, "#5c5f5b", "#2e302f", "#7a6a3a")), chip=0.45, grime=0.6, streaks=0.6)
    out = [cyl(r, h, m, loc=(0, 0, h / 2), seg=10, bevel=0.06, rows=3 if dent else 1)]
    for zz in (h * 0.33, h * 0.66):
        out.append(cyl(r + 0.05, 0.1, m, loc=(0, 0, zz), seg=10, bevel=0.0))
    if lid:
        out.append(cyl(0.14, 0.06, rusty(), loc=(r * 0.55, 0, h + 0.02), seg=6, bevel=0.0))
    if dent:
        a = R.uniform(0, 2 * math.pi)
        dv = V((math.cos(a), math.sin(a), 0))
        def push(v):
            k = max(0.0, V((v.x, v.y, 0)).normalized().dot(dv) - 0.6) * dent * (1 - abs(v.z - h * 0.5) / h)
            return V((v.x - dv.x * k, v.y - dv.y * k, v.z))
        warp(out, push)
    return move(out, loc=(x, y, z))


def crate(R, size, loc=(0, 0, 0), rot=0, word=True, tip=(0, 0)):
    """Wooden shipping crate with edge battens and a stencilled made-up word."""
    w, d, h = size
    m, b = crate_wood(), wood("#7d6040", "#3e2e1e", axis="x", wear=0.4)
    out = [box((w - 0.12, d - 0.12, h - 0.12), m, loc=(0, 0, h / 2), r=0.0, n=1)]
    for sy in (-1, 1):
        y = sy * (d / 2 - 0.05)
        for zz in (0.15, h - 0.15):
            out.append(box((w, 0.1, 0.3), b, loc=(0, y, zz), r=0.0, n=1))
        for sx in (-1, 1):
            out.append(box((0.3, 0.1, h), b, loc=(sx * (w / 2 - 0.15), y, h / 2), r=0.0, n=1))
    for sx in (-1, 1):
        for zz in (0.15, h - 0.15):
            out.append(box((0.1, d, 0.3), b, loc=(sx * (w / 2 - 0.05), 0, zz), r=0.0, n=1))
    if word:
        out.append(words(R.choice(WORDS), min(0.6, h * 0.22), ink(), loc=(0, -d / 2 + 0.05, h * 0.55), depth=0.008))
        out.append(box((w * 0.4, 0.01, 0.08), ink(), loc=(0, -d / 2 + 0.055, h * 0.36), r=0.0, n=1))
    move(out, rot=(tip[0], tip[1], 0))
    return move(out, loc=loc, rot=(0, 0, rot))


def couch(x, y, z, color, rot=0, w=7.0, wrap=False, flip=False, seed=0):
    """Old couch, optionally wrapped in dusty plastic (film shape follows the couch, fabric shows at a tear)."""
    m = film(color) if wrap else fabric(color)
    out = [box((w, 3.0, 1.4), m, loc=(0, 0, 0.7), r=0.12, n=1),
           box((w, 0.8, 2.8), m, loc=(0, 1.1, 1.4), r=0.15, n=1)]
    for sx in (-1, 1):
        out.append(box((0.7, 3.0, 2.0), m, loc=(sx * (w / 2 - 0.35), 0, 1.0), r=0.15, n=1))
    if not wrap:
        out.append(box((w - 1.5, 2.2, 0.4), m, loc=(0, -0.3, 1.6), r=0.15, n=1))
    else:
        crumple(out, 0.07, 1.2, seed=seed)
        out.append(slab([(-0.5, -0.3), (0.1, -0.45), (0.55, -0.1), (0.3, 0.35), (-0.4, 0.3)], 0.02, fabric(color),
                        loc=(w * 0.2, -1.56, 0.8)))
    if flip:
        move(out, rot=(0, 180, 0), pivot=(0, 0, 1.4))
    return move(out, loc=(x, y, z), rot=(0, 0, rot))


def mattress(x, y, z, color="#d6cfbf", rot=0, wrap=False, seed=0, w=7.0, d=4.5):
    m = film(color) if wrap else fabric(color)
    o = box((w, d, 0.9), m, loc=(0, 0, 0.45), r=0.25, n=1)
    crumple(o, 0.06 if wrap else 0.03, 1.0, seed=seed)
    return move(o, loc=(x, y, z), rot=(0, 0, rot))


def chair(x, y, z, rot=0, tip=(0, 0), broken=False, mat=None):
    """Plain wooden dining chair, seat at 1.5. broken drops one leg and snaps the back."""
    m = mat or wood("#a0784e", "#55391f", axis="z", wear=0.45)
    out = [box((1.6, 1.6, 0.16), m, loc=(0, 0, 1.5), r=0.0, n=1)]
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        if broken and i == 1:
            out.append(box((0.16, 0.16, 0.6), m, loc=(sx * 0.68, sy * 0.68, 1.12), r=0.0, n=1))
            continue
        out.append(box((0.16, 0.16, 1.42), m, loc=(sx * 0.68, sy * 0.68, 0.71), r=0.0, n=1))
    for sx in (-1, 1):
        out.append(box((0.16, 0.16, 1.6), m, loc=(sx * 0.68, 0.68, 2.38), r=0.0, n=1))
    back = box((1.5, 0.12, 0.55), m, loc=(0, 0.68, 2.9), r=0.0, n=1)
    if broken:
        move(back, rot=(-35, 0, 10), pivot=(0.7, 0.68, 2.62))
    out.append(back)
    move(out, rot=(tip[0], tip[1], 0))
    return move(out, loc=(x, y, z), rot=(0, 0, rot))


def table(x, y, z, rot=0, tip=(0, 0), w=5.0, d=3.0):
    m = wood("#8a6644", "#45301c", axis="x", wear=0.5)
    out = [box((w, d, 0.18), m, loc=(0, 0, 2.41), r=0.0, n=1)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            out.append(box((0.26, 0.26, 2.32), m, loc=(sx * (w / 2 - 0.3), sy * (d / 2 - 0.3), 1.16), r=0.0, n=1))
    move(out, rot=(tip[0], tip[1], 0))
    return move(out, loc=(x, y, z), rot=(0, 0, rot))


def caution_tape(points, w=0.24):
    """Yellow-and-black hazard tape (stripes, no words) strung through points."""
    yel, blk = plain("#c9a92e", grime=0.35, vary=0.3), flat("#1c1a18")
    out = []
    for a, b in zip(points, points[1:]):
        a, b = V(a), V(b)
        out.append(strap(a, b, w, 0.02, yel))
        n = int((b - a).length / 0.9)
        for i in range(n):
            p = a.lerp(b, (i + 0.5) / max(n, 1))
            q = a.lerp(b, (i + 0.5) / max(n, 1) + 0.25 / max((b - a).length, 0.01))
            out.append(strap(p, q, w * 0.7, 0.03, blk))
    return out


# ---------------------------------------------------------------- racking
def frame(x, mat, h=RACK_H, segs=1):
    """One upright frame in the y-z plane at x: two posts, footplates, zigzag bracing."""
    out = []
    py = BAY_D / 2 - POST / 2
    for sy in (-1, 1):
        for i in range(segs):
            out.append(box((POST, POST, h / segs), mat, loc=(x, sy * py, h / segs * (i + 0.5)), r=0.0, n=1))
        out.append(box((POST, 0.6, 0.08), rusty(), loc=(x, sy * py, 0.04), r=0.0, n=1))
    zs = [0.6 + (h - 1.2) * i / 8 for i in range(9)]
    for z in (zs[0], zs[-1]):
        out.append(strap((x, -py, z), (x, py, z), 0.14, 0.14, mat, up=(1, 0, 0)))
    for i in range(8):
        s = 1 if i % 2 == 0 else -1
        out.append(strap((x, -s * py, zs[i]), (x, s * py, zs[i + 1]), 0.12, 0.12, mat, up=(1, 0, 0)))
    return out


def beam(z, sy, mat, sag=0.0):
    """Front (sy=-1) or back beam with its top at z, rusty connector plates at both posts."""
    x0, x1 = -BAY_W / 2 + POST, BAY_W / 2 - POST
    L = x1 - x0
    y = sy * (BAY_D / 2 - 0.1)
    o = box((L, 0.2, 0.5), mat, loc=(0, y, z - 0.25), r=0.0, n=4 if sag else 1)
    if sag:
        warp(o, lambda v: V((v.x, v.y, v.z - sag * max(0.0, 1 - (v.x / (L / 2)) ** 2))))
    out = [o]
    for sx in (-1, 1):
        out.append(box((0.2, 0.24, 0.8), rusty(), loc=(sx * (L / 2 - 0.1), y, z - 0.3), r=0.0, n=1))
    return out


def bay(R, upright=None, beams=None, sag=None, skip=()):
    """Two frames and the beam pairs. sag: {level index: drop}. skip: (level index, side) beams left out."""
    upright = upright or upright_paint()
    beams = beams or beam_paint()
    sag = sag or {}
    out = []
    for sx in (-1, 1):
        out += frame(sx * (BAY_W / 2 - POST / 2), upright)
    for i, z in enumerate(LEVELS):
        for sy in (-1, 1):
            if (i, sy) not in skip:
                out += beam(z, sy, beams, sag.get(i, 0.0) if sy < 0 else sag.get(i, 0.0) * 0.6)
    return out


def slot(R, kind, x, z, hmax, words_on=0):
    """One pallet position's load, bottom at z."""
    out = []
    if kind == "none":
        return out
    if kind in ("pallet", "boxes", "wrapped", "full_wrap", "drums", "sacks", "few", "crate"):
        out += pallet(x + R.uniform(-0.1, 0.1), R.uniform(-0.05, 0.05), z, rot=R.uniform(-1.5, 1.5),
                      broken=R.choice((None, None, None, 1, 3)))
    top = z + PAL_H
    if kind == "boxes":
        out += stack_boxes(R, x, 0, top, hmax=hmax - PAL_H, fill=0.88, words_on=words_on)
    elif kind == "wrapped":
        out += wrapped(R, x, 0, top, h=min(3.6, hmax - PAL_H - 0.1))
    elif kind == "full_wrap":
        out += wrapped(R, x, 0, top, h=min(3.4, hmax - PAL_H - 0.2), full=True, torn=R.random() < 0.6)
    elif kind == "drums":
        for i in (-1, 1):
            for j in (-1, 1):
                if R.random() < 0.85:
                    out += drum(R, x + i * 1.2, j * 1.1, top, h=min(2.9, hmax - PAL_H - 0.1), dent=R.choice((0, 0, 0.25)))
    elif kind == "sacks":
        out += sacks(R, x, 0, top, layers=min(5, int((hmax - PAL_H) / 0.51)))
    elif kind == "few":
        for i in range(R.randint(1, 3)):
            s = (R.uniform(1.2, 2.2), R.uniform(1.2, 2.0), R.uniform(0.8, 1.4))
            out += carton(R, s, loc=(x + R.uniform(-1.4, 1.4), R.uniform(-1.0, 1.0), top), rot=R.uniform(-25, 25),
                          faces=(-1, 1), crushed=R.choice((0, 0, 0.5)))
    elif kind == "crate":
        h = min(3.4, hmax - PAL_H - 0.1)
        out += crate(R, (PAL_W - 0.2, PAL_D - 0.2, h), loc=(x, 0, top), rot=R.uniform(-2, 2), word=R.random() < 0.4)
    elif kind == "big_crate":
        h = min(4.0, hmax - 0.1)
        out += crate(R, (5.4, PAL_D, h), loc=(x, 0, z), rot=R.uniform(-1, 1), word=R.random() < 0.5)
    elif kind == "loose":
        for i in range(R.randint(1, 2)):
            out += carton(R, (R.uniform(1.6, 2.6), 4.3, R.uniform(0.9, 1.6)), loc=(x + R.uniform(-1.2, 1.2), 0, z),
                          rot=R.uniform(-4, 4), faces=(-1, 1))
    return out


def fill(R, rows, words_on=1):
    """rows: bottom to top, each (left kind, right kind). Ground level sits on the floor."""
    out = []
    zs = (0.0,) + LEVELS
    for li, kinds in enumerate(rows):
        z = zs[li]
        hmax = (zs[li + 1] - 0.5 - z - 0.15) if li + 1 < len(zs) else 3.8
        for sx, kind in zip(SLOT_X, kinds):
            out += slot(R, kind, sx, z, hmax, words_on=words_on)
    return out


def oil_marks(R, prints=2, streaks=3, pool=True):
    """Robots leak black oil: runs down the front posts and beams, three-fingered handprints, a puddle."""
    out = []
    px = BAY_W / 2 - POST / 2
    for i in range(streaks):
        sx = R.choice((-1, 1))
        z = R.choice(LEVELS) - 0.4
        out.append(streak(sx * px + R.uniform(-0.05, 0.05), -BAY_D / 2, z, R.uniform(1.5, 4.0), w=0.13))
    for i in range(prints):
        out += handprint((1 if i % 2 else -1) * px, -BAY_D / 2, R.uniform(3.0, 4.8), s=0.85, tilt=R.uniform(-15, 15))
    if pool:  # kept inside the bay footprint so bays still line up by their bounds
        out.append(puddle(R, R.choice((-1, 1)) * R.uniform(2.5, 4.0), -BAY_D / 2 + 1.1, R.uniform(0.5, 0.75)))
    return out


@item("rack_bay_full", "warehouse", size=1024)
def rack_bay_full(P):
    R = random.Random(11)
    P.add("Body", bay(R))
    P.add("Body", fill(R, [("boxes", "wrapped"), ("boxes", "boxes"), ("full_wrap", "none"), ("boxes", "wrapped"), ("pallet", "boxes")]))
    P.add("Body", oil_marks(R))


@item("rack_bay_sparse", "warehouse", size=1024)
def rack_bay_sparse(P):
    R = random.Random(23)
    P.add("Body", bay(R, upright=paint(GALV, chip=0.2, under="#6a4a32", grime=0.6, streaks=0.6), sag={1: 0.55}))
    P.add("Body", fill(R, [("few", "none"), ("none", "loose"), ("pallet", "none"), ("none", "few"), ("none", "none")]))
    P.add("Body", carton(R, (1.8, 1.6, 1.2), loc=(1.2, -0.5, LEVELS[1] - 0.45), rot=12, crushed=0.8))
    P.add("Body", oil_marks(R, prints=1, streaks=2))


@item("rack_bay_bulk", "warehouse", size=1024)
def rack_bay_bulk(P):
    R = random.Random(37)
    P.add("Body", bay(R, beams=paint(YELLOW, chip=0.4, grime=0.55, streaks=0.5)))
    P.add("Body", fill(R, [("big_crate", "crate"), ("drums", "crate"), ("crate", "none"), ("full_wrap", "drums"), ("crate", "crate")]))
    P.add("Body", oil_marks(R, prints=1, streaks=4))


@item("rack_bay_furniture", "warehouse", size=1024)
def rack_bay_furniture(P):
    R = random.Random(41)
    P.add("Body", bay(R))
    deck = galv()
    for z in LEVELS:
        P.add("Body", box((BAY_W - 2 * POST, BAY_D - 0.4, 0.06), deck, loc=(0, 0, z + 0.03), r=0.0, n=1))
    P.add("Body", couch(0, 0, 0.0, "#6e6a5c", rot=0, wrap=True, seed=1))
    P.add("Body", chair(4.4, -0.3, 0, rot=-20))
    P.add("Body", [mattress(0, 0, LEVELS[0] + 0.06 + 0.86 * i, wrap=i != 1, seed=i, rot=R.uniform(-3, 3)) for i in range(3)])
    P.add("Body", couch(-2.6, 0, LEVELS[1] + 0.06, "#7a5c4c", w=3.4, wrap=True, seed=4))
    P.add("Body", couch(2.6, 0.1, LEVELS[1] + 0.06, "#5d6b70", w=3.4, wrap=False, rot=6))
    P.add("Body", [mattress(-0.3, 0, LEVELS[2] + 0.06 + 0.86 * i, color="#c7c4b4", wrap=True, seed=10 + i) for i in range(2)])
    P.add("Body", carton(R, (2.2, 2.0, 1.2), loc=(3.5, -0.6, LEVELS[2] + 1.8), rot=10, faces=(-1, 1)))
    P.add("Body", couch(0, 0, LEVELS[3] + 0.06, "#8a7a5a", wrap=True, seed=7))
    P.add("Body", oil_marks(R, prints=2, streaks=2))


@item("rack_end", "warehouse", size=1024)
def rack_end(P):
    """End-of-run frame (y-z plane at x = 0). Guard and load plate face -x, the cross aisle."""
    R = random.Random(53)
    m = upright_paint()
    P.add("Body", frame(0, m))
    guard = paint(YELLOW, chip=0.5, grime=0.6, streaks=0.5)
    py = BAY_D / 2 - POST / 2
    for sy in (-1, 1):
        g = box((0.7, 0.7, 2.2), guard, loc=(-0.05, sy * py, 1.1), r=0.0, n=2)
        warp(g, lambda v, sy=sy: V((v.x + 0.12 * max(0.0, 1 - abs(v.z - 1.0)) if v.x < -0.3 else v.x, v.y, v.z)))
        P.add("Body", g)
    rail = []
    for z in (0.9, 1.8):
        r = box((0.3, BAY_D + 0.8, 0.45), guard, loc=(-1.0, 0, z), r=0.0, n=4)
        warp(r, lambda v: V((v.x + 0.35 * max(0.0, 1 - abs(v.y + 0.6) / 1.2), v.y, v.z)))
        rail.append(r)
    for sy in (-1, 1):
        rail.append(box((0.4, 0.4, 2.1), guard, loc=(-1.0, sy * (BAY_D / 2 + 0.2), 1.05), r=0.0, n=1))
        rail.append(box((0.8, 0.8, 0.08), rusty(), loc=(-1.0, sy * (BAY_D / 2 + 0.2), 0.04), r=0.0, n=1))
    for i in range(5):
        rail.append(box((0.02, 0.35, 0.47), flat("#1c1a18"), loc=(-1.16, -2.0 + i * 1.0, 1.8), rot=(35, 0, 0), r=0.0, n=1))
    P.add("Body", rail)
    plate = [box((0.06, 2.2, 1.6), plain("#cfc2a0", grime=0.6, vary=0.4), loc=(0, 0, 0), r=0.0, n=1),
             box((0.065, 2.2, 0.35), plain("#b8613a", grime=0.5, vary=0.35), loc=(0, 0, 0.6), r=0.0, n=1),
             move(words("900", 0.6, ink(), depth=0.006), rot=(0, 0, -90), loc=(-0.04, 0, -0.1)),
             box((0.066, 1.4, 0.06), ink(), loc=(0, 0, -0.55), r=0.0, n=1)]
    P.add("Body", move(plate, loc=(-0.2, 0, 7.5), rot=(4, 0, 0)))
    P.add("Body", strap((-0.17, -py, 6.5), (-0.17, py, 6.5), 0.2, 0.06, m, up=(1, 0, 0)))
    for z, ln in ((5.5, 3.2), (16.0, 5.0)):
        P.add("Body", move(streak(0, -0.0, z, ln, w=0.14), rot=(0, 0, -90), loc=(-0.15, -py, 0)))
    P.add("Body", move(handprint(0, 0, 4.6, s=0.9, tilt=-20), rot=(0, 0, -90), loc=(-1.2, 0.8, 0)))
    P.add("Body", puddle(R, -1.6, 0.5, 0.9))


def bend(out, lean, power=2.0, h=RACK_H):
    """Leans everything toward -y, more the higher it is: buckled, not snapped."""
    return warp(out, lambda v: V((v.x, v.y - lean * (max(v.z, 0) / h) ** power, v.z)))


@item("rack_collapsed", "warehouse", size=1024)
def rack_collapsed(P):
    """Buckled bay leaning out over the aisle, top beam dangling, its load spilled across the floor."""
    R = random.Random(67)
    up, bm = upright_paint(), beam_paint()
    body = []
    for sx in (-1, 1):
        body += frame(sx * (BAY_W / 2 - POST / 2), up, segs=8)
    for i, z in enumerate(LEVELS[:3]):
        for sy in (-1, 1):
            body += beam(z, sy, bm, sag=0.4 + 0.3 * i)
    body += beam(LEVELS[3], 1, bm)
    hang = beam(0, -1, bm)
    move(hang, rot=(0, 52, 0), pivot=(-5.7, 0, 0))
    body += move(hang, loc=(0, 0, LEVELS[3]))
    body += fill(R, [("wrapped", "none"), ("none", "boxes"), ("pallet", "none"), ("none", "none")], words_on=0)
    bend(body, 7.5)
    P.add("Body", body)
    for sx in (-1, 1):
        P.add("Body", box((0.6, 0.55, 0.08), rusty(), loc=(sx * (BAY_W / 2 - 0.15), BAY_D / 2 - 0.15 + 0.6, 0.04), r=0.0, n=1))
    spill = []
    spill += pallet(2.5, -5.5, 0, rot=24, broken=2)
    spill += carton(R, (2.0, 1.8, 1.3), loc=(2.4, -5.4, PAL_H), rot=30, crushed=0.6)
    for i in range(9):
        s = (R.uniform(1.0, 2.2), R.uniform(1.0, 2.0), R.uniform(0.8, 1.5))
        spill += carton(R, s, loc=(R.uniform(-5.0, 5.0), R.uniform(-8.5, -3.0), 0), rot=R.uniform(0, 360),
                        faces=(-1, 1), crushed=R.choice((0, 0.5, 0.9)), tip=R.choice(((0, 0), (90, 0), (0, 90))))
    spill += open_carton(R, (1.8, 1.6, 1.2), loc=(-3.2, -6.5, 0), rot=40)
    spill += carton(R, (2.0, 1.8, 1.4), loc=(-1.0, -4.0, 0.0), rot=-15, tip=(0, 30))
    spill.append(puddle(R, 0.5, -3.5, 1.4))
    spill += handprint(-4.6, -BAY_D / 2 - 0.4, 3.6, tilt=10)
    P.add("Body", spill)


@item("rack_toppled_beam", "warehouse", size=1024)
def rack_toppled_beam(P):
    """A front beam came unhooked at one end and dropped; what it held is on the floor."""
    R = random.Random(71)
    bm = beam_paint()
    P.add("Body", bay(R, skip={(1, -1)}))
    fallen = beam(0, -1, bm)
    move(fallen, rot=(0, 58, 0), pivot=(-5.7, 0, 0))
    P.add("Body", move(fallen, loc=(0, -0.05, LEVELS[1])))
    P.add("Body", fill(R, [("boxes", "few"), ("none", "none"), ("wrapped", "pallet"), ("boxes", "none"), ("full_wrap", "none")]))
    tilted = pallet(0, 0, 0) + stack_boxes(R, 0, 0, PAL_H, hmax=2.2, fill=0.6)
    move(tilted, rot=(-34, 0, 0), pivot=(0, -2.2, 0))
    P.add("Body", move(tilted, loc=(2.8, 0.15, LEVELS[1] - 0.5)))
    spill = []
    for i in range(7):
        s = (R.uniform(1.0, 2.0), R.uniform(1.0, 1.8), R.uniform(0.8, 1.4))
        spill += carton(R, s, loc=(R.uniform(-5.0, 1.5), R.uniform(-5.5, -2.8), 0), rot=R.uniform(0, 360),
                        faces=(-1, 1), crushed=R.choice((0, 0.4, 0.8)), tip=R.choice(((0, 0), (90, 0), (0, 90))))
    spill += open_carton(R, (1.6, 1.5, 1.1), loc=(-2.0, -4.2, 0), rot=-25)
    spill.append(puddle(R, -3.0, -3.4, 0.9))
    P.add("Body", spill)
    P.add("Body", oil_marks(R, prints=1, streaks=2, pool=False))


# ---------------------------------------------------------------- pallets
@item("pallet", "warehouse", size=512)
def pallet_item(P):
    R = random.Random(81)
    P.add("Body", pallet(broken=2))
    P.add("Body", streak(1.2, -PAL_D / 2 + 0.3, 0.48, 0.3, w=0.2))
    P.add("Body", box((1.0, 0.7, 0.012), oil(), loc=(-1.2, 0.6, 0.486), rot=(0, 0, 20), r=0.0, n=1))


@item("pallet_boxes", "warehouse", size=512)
def pallet_boxes(P):
    R = random.Random(83)
    P.add("Body", pallet())
    color = "#b08a5c"
    out = []
    for i in range(2):
        for j in range(2):
            n = (3, 2, 3, 1)[i * 2 + j]
            for k in range(n):
                crushed = 0.7 if (k == n - 1 and (i + j) % 2 == 1) else 0.0
                out += carton(R, (2.42, 2.12, 1.15), loc=(-1.25 + i * 2.5, -1.1 + j * 2.2, PAL_H + k * 1.155), rot=R.uniform(-3, 3),
                              color=color if R.random() < 0.75 else R.choice(CARTON), faces=((-1,) if j == 0 else (1,)),
                              crushed=crushed, word=k == 0 and j == 0 and i == 0)
    P.add("Body", out)
    P.add("Body", carton(R, (1.6, 1.4, 1.0), loc=(1.1, -1.4, PAL_H + 1.155), rot=20, crushed=0.9))


@item("pallet_wrapped", "warehouse", size=512)
def pallet_wrapped(P):
    R = random.Random(87)
    P.add("Body", pallet())
    P.add("Body", wrapped(R, 0, 0, PAL_H, h=3.9))
    P.add("Body", handprint(-1.4, -PAL_D / 2 - 0.1, 2.6, s=1.0, tilt=15))


@item("pallet_sacks", "warehouse", size=512)
def pallet_sacks(P):
    R = random.Random(89)
    P.add("Body", pallet())
    P.add("Body", sacks(R, 0, 0, PAL_H, layers=5))
    s = box((1.6, 2.4, 0.4), cloth("#c8b991", dirt=0.6, weave=40), loc=(0, 0, 0.2), r=0.18, n=1)
    crumple(s, 0.08, 1.5, seed=3)
    P.add("Body", move(s, loc=(1.3, -3.1, 0), rot=(0, 0, 70)))
    spill = [slab([(-0.9, -0.4), (-0.2, -0.7), (0.8, -0.5), (1.1, 0.1), (0.4, 0.6), (-0.6, 0.5)], 0.03,
                  plain("#ddd6c3", grime=0.4, vary=0.3), loc=(2.0, -3.6, 0.016), rot=(90, 0, 15))]
    P.add("Body", spill)


@item("pallet_tower", "warehouse", size=512)
def pallet_tower(P):
    R = random.Random(97)
    out = []
    z = 0.0
    for i in range(16):
        out += pallet(R.uniform(-0.15, 0.15), R.uniform(-0.12, 0.12), z, rot=R.uniform(-3, 3) + (90 if i in (9,) else 0),
                      boards=3, broken=1 if i in (4, 12) else None,
                      mat=pallet_wood() if R.random() < 0.7 else wood("#8c7a62", "#4a3d2c", axis="x", wear=0.35))
        z += PAL_H
    P.add("Body", out)
    P.add("Body", streak(-1.2, -PAL_D / 2 - 0.15, 5.5, 2.5, w=0.18))


# ---------------------------------------------------------------- store gondolas
G_W, G_H, G_SIDE = 8.0, 7.0, 1.7
G_SHELVES = (1.9, 3.3, 4.7, 6.0)


def gondola_paint():
    return paint("#cfc7b4", chip=0.2, grime=0.55, streaks=0.5)


def gondola(R, sides=(-1, 1), w=G_W, shelves=G_SHELVES, fallen=None, missing=()):
    """Store shelf frame: centre back panel, end uprights, base deck and kick plate, shelves with price strips.
    fallen: (side, shelf index) that came off one bracket and hangs down. missing: (side, shelf index) taken away."""
    m = gondola_paint()
    strip = plain("#5f8a85", grime=0.45, vary=0.3)
    kick = paint("#4a4946", chip=0.3, grime=0.5)
    out = [box((w, 0.2, G_H), m, loc=(0, 0, G_H / 2), r=0.0, n=1)]
    for sx in (-1, 1):
        out.append(box((0.25, 0.35, G_H), m, loc=(sx * (w / 2 - 0.125), 0, G_H / 2), r=0.0, n=1))
    for s in sides:
        yc = s * (0.1 + G_SIDE / 2)
        out.append(box((w, G_SIDE + 0.1, 0.1), m, loc=(0, yc + s * 0.05, 0.6), r=0.0, n=1))
        out.append(box((w, 0.08, 0.55), kick, loc=(0, s * (0.15 + G_SIDE), 0.3), r=0.0, n=1))
        for i, z in enumerate(shelves):
            if (s, i) in missing:
                continue
            sh = [box((w - 0.5, G_SIDE, 0.08), m, loc=(0, yc, z), r=0.0, n=1),
                  box((w - 0.5, 0.06, 0.24), strip, loc=(0, s * (0.1 + G_SIDE + 0.03), z - 0.02), r=0.0, n=1)]
            if fallen == (s, i):
                move(sh, rot=(0, 20, 0), pivot=(-(w / 2 - 0.25), yc, z))
                move(sh, rot=(s * 8, 0, 0), pivot=(0, s * 0.1, z))
            out += sh
    return out


def shelf_stock(R, s, z, clear, w=G_W, gaps=0.3, kinds=None):
    """A row of faded store boxes facing out on one shelf, with gaps where things were taken."""
    out = []
    kinds = kinds or 1
    pw = R.uniform(0.55, 0.95)
    ph = min(clear - 0.15, R.uniform(0.6, 1.15))
    pd = G_SIDE - 0.25
    c = R.choice(CHEER + PRIMARY + ("#d6cfbd",))
    tall = R.random() < 0.4
    x = -w / 2 + 0.35
    while x + pw < w / 2 - 0.3:
        if R.random() > gaps:
            mat = plain(c, grime=0.5, vary=0.35) if R.random() < 0.9 else cardboard(R.choice(CARTON))
            yc = s * (0.1 + G_SIDE / 2 + 0.05)
            fall = R.random() < 0.06
            o = box((pw, pd, ph), mat, loc=(0, 0, ph / 2), r=0.0, n=1)
            parts = [o]
            if R.random() < 0.5:
                parts.append(box((pw * 0.96, 0.02, ph * 0.22), label(), loc=(0, -pd / 2 - 0.01, ph * (0.6 if tall else 0.45)), r=0.0, n=1))
            face_turn(parts, s)
            if fall:
                move(parts, rot=(s * -90, 0, 0), pivot=(0, s * pd / 2, 0))
            out += move(parts, loc=(x + pw / 2 + R.uniform(-0.04, 0.04), yc, z + 0.04), rot=(0, 0, R.uniform(-4, 4)))
        x += pw + 0.06
    return out


@item("gondola_shelf", "warehouse", size=1024)
def gondola_shelf(P):
    R = random.Random(101)
    P.add("Body", gondola(R))
    zs = (0.65,) + G_SHELVES
    for s in (-1, 1):
        for i, z in enumerate(zs):
            clear = (zs[i + 1] - z - 0.1) if i + 1 < len(zs) else 1.2
            P.add("Body", shelf_stock(R, s, z, clear, gaps=R.choice((0.15, 0.3, 0.5, 0.7))))
    P.add("Body", streak(-3.95, -(0.1 + G_SIDE) - 0.04, 4.6, 2.2, w=0.12))
    P.add("Body", handprint(1.6, -(0.1 + G_SIDE) - 0.07, 3.28, s=0.7, tilt=-90))
    P.add("Body", puddle(R, 2.5, -2.6, 0.7))


@item("gondola_end", "warehouse", size=1024)
def gondola_end(P):
    """Endcap: one-sided, as wide as a gondola is deep, a pyramid display and a faded header card."""
    R = random.Random(103)
    w = 2 * (0.1 + G_SIDE) + 0.2
    m = gondola_paint()
    out = []
    out.append(box((w, 0.2, G_H), m, loc=(0, 0.9, G_H / 2), r=0.0, n=1))
    for sx in (-1, 1):
        out.append(box((0.25, 1.9, G_H), m, loc=(sx * (w / 2 - 0.125), 0.05, G_H / 2), r=0.0, n=1))
    out.append(box((w, 1.9, 0.6), paint("#4a4946", chip=0.3, grime=0.5), loc=(0, 0.05, 0.3), r=0.0, n=1))
    for z in (3.6, 5.0):
        out.append(box((w - 0.5, 1.6, 0.08), m, loc=(0, 0.0, z), r=0.0, n=1))
        out.append(box((w - 0.5, 0.06, 0.24), plain("#5f8a85", grime=0.45, vary=0.3), loc=(0, -0.83, z - 0.02), r=0.0, n=1))
    P.add("Body", out)
    c1, c2 = plain(PRIMARY[0], grime=0.5, vary=0.35), plain(PRIMARY[1], grime=0.5, vary=0.35)
    pyr = []
    for k, n in enumerate((5, 4, 3, 2)):
        for i in range(n):
            if k == 3 and i == 1:
                continue
            x = (i - (n - 1) / 2) * 0.72
            pyr += move(face_turn([box((0.66, 1.2, 0.7), c1 if (i + k) % 2 == 0 else c2, loc=(0, 0, 0.35), r=0.0, n=1),
                                   box((0.6, 0.02, 0.18), label(), loc=(0, -0.61, 0.4), r=0.0, n=1)], -1),
                        loc=(x + R.uniform(-0.04, 0.04), -0.2, 0.6 + k * 0.71), rot=(0, 0, R.uniform(-5, 5)))
    pyr += move([box((0.66, 1.2, 0.7), c2, loc=(0, 0, 0.35), r=0.0, n=1)], loc=(1.0, -1.6, 0), rot=(0, 0, 33))
    P.add("Body", pyr)
    for z in (3.64, 5.04):
        P.add("Body", shelf_stock(R, -1, z, 1.2, w=w, gaps=0.45))
    head = [box((w + 0.4, 0.12, 1.4), plain("#ddd3bc", grime=0.55, vary=0.35), loc=(0, 0, 0), r=0.0, n=1)]
    head.append(cyl(0.55, 0.02, plain("#c97a62", grime=0.45, vary=0.3), loc=(-1.3, -0.07, 0.0), rot=(90, 0, 0), seg=12, bevel=0.0))
    head.append(cyl(0.38, 0.02, plain("#d2b978", grime=0.45, vary=0.3), loc=(-1.3, -0.08, 0.0), rot=(90, 0, 0), seg=12, bevel=0.0))
    head.append(words("9.99", 0.55, plain("#a33a2c", grime=0.5, vary=0.4), loc=(0.45, -0.075, -0.05), depth=0.008))
    P.add("Body", move(head, loc=(0, 0.85, G_H + 0.75), rot=(0, -3, 0)))
    for x in (-1.5, 1.5):
        P.add("Body", box((0.1, 0.1, 0.12), m, loc=(x, 0.9, G_H + 0.04), r=0.0, n=1))
    P.add("Body", streak(1.0, -0.9, 0.55, 0.5, w=0.3))


@item("gondola_empty", "warehouse", size=1024)
def gondola_empty(P):
    R = random.Random(107)
    P.add("Body", gondola(R, fallen=(-1, 1), missing={(-1, 0)}))
    P.add("Body", carton(R, (0.8, 1.0, 0.7), loc=(-2.0, 1.0, 1.94), rot=30, faces=(), crushed=0.7))
    P.add("Body", carton(R, (0.8, 0.9, 0.6), loc=(2.6, -2.6, 0), rot=-50, faces=(), crushed=0.9))
    P.add("Body", box((0.7, 0.9, 0.5), plain("#8aa8c2", grime=0.5, vary=0.35), loc=(1.3, -1.0, 0.95), rot=(0, 0, 70), r=0.0, n=1))
    P.add("Body", box((0.3, 0.02, 0.18), label(), loc=(3.0, -2.0, 0.012), rot=(90, 0, 25), r=0.0, n=1))
    P.add("Body", handprint(-0.5, -0.1, 5.4, s=0.9, tilt=8))
    P.add("Body", streak(-0.5, -0.1, 5.1, 3.0, w=0.12))


# ---------------------------------------------------------------- piles and clutter
@item("box_pile_small", "warehouse", size=512)
def box_pile_small(P):
    R = random.Random(113)
    out = []
    out += carton(R, (2.2, 1.8, 1.4), loc=(-0.6, 0, 0), rot=8, faces=(-1, 1), word=True)
    out += carton(R, (1.8, 1.6, 1.2), loc=(1.4, 0.2, 0), rot=-15, faces=(-1, 1))
    out += carton(R, (1.6, 1.4, 1.0), loc=(-0.5, 0.1, 1.4), rot=-10, faces=(-1,))
    out += carton(R, (1.4, 1.2, 1.1), loc=(1.0, -1.5, 0), rot=30, tip=(0, 90), faces=(-1,))
    out += open_carton(R, (1.6, 1.4, 1.0), loc=(-2.2, -1.1, 0), rot=25)
    out += carton(R, (1.2, 1.0, 0.8), loc=(0.2, -2.0, 0), rot=60, crushed=0.8)
    P.add("Body", out)


@item("box_pile_big", "warehouse", size=1024)
def box_pile_big(P):
    R = random.Random(127)
    out = []
    base = [(-2.6, 0.4), (-0.4, 0.6), (1.8, 0.3), (-1.6, -1.6), (0.8, -1.5), (3.4, -1.0)]
    for i, (x, y) in enumerate(base):
        out += carton(R, (2.1, 2.0, 1.5), loc=(x, y, 0), rot=R.uniform(-15, 15), faces=(-1, 1), word=i == 1)
    for i, (x, y) in enumerate(((-1.6, 0.5), (0.6, 0.4), (-0.4, -1.2))):
        out += carton(R, (1.9, 1.8, 1.15), loc=(x, y, 1.5), rot=R.uniform(-20, 20), faces=(-1,))
    out += carton(R, (1.7, 1.6, 1.1), loc=(-0.5, -0.1, 2.65), rot=25, faces=(-1,), crushed=0.5)
    out += open_carton(R, (1.8, 1.6, 1.2), loc=(2.4, 0.4, 1.5), rot=-10)
    for i in range(5):
        out += carton(R, (R.uniform(0.8, 1.4), R.uniform(0.7, 1.2), R.uniform(0.6, 1.0)),
                      loc=(R.uniform(-4.0, 4.0), R.uniform(-4.2, -2.8), 0), rot=R.uniform(0, 360),
                      faces=(-1,), crushed=R.choice((0, 0.6)), tip=R.choice(((0, 0), (90, 0), (0, 90))))
    c = plain(R.choice(CHEER), grime=0.5, vary=0.35)
    for i in range(6):
        out.append(box((0.5, 0.35, 0.6), c, loc=(R.uniform(1.5, 4.2), R.uniform(-2.6, -1.8), 0.2),
                       rot=(R.choice((0, 90)), 0, R.uniform(0, 180)), r=0.0, n=1))
    out.append(puddle(R, -3.0, -2.6, 0.6, mat=plain("#3a2f26", grime=0.2, vary=0.3)))
    P.add("Body", out)


@item("furniture_heap", "warehouse", size=1024)
def furniture_heap(P):
    """Old couches, chairs and tables piled up and taped off."""
    R = random.Random(131)
    out = []
    out += couch(-0.5, 0.6, 0, "#6f6a58", rot=4)
    out += couch(-0.3, 0.3, 2.8, "#4f6a8c", rot=-6, flip=True, w=6.4)
    side = table(0, 0, 0, w=4.6, d=2.8)
    move(side, rot=(-90, 0, 0))
    move(side, rot=(0, 0, 90))
    out += move(side, loc=(-4.4, 0.3, 1.4))
    out += table(3.8, -0.4, 0, rot=80, w=5.0, d=3.0)
    out += chair(3.8, -0.4, 2.5 + 3.17, rot=200, tip=(180, 0))
    out += chair(-1.0, -2.6, 0, rot=-30, broken=True)
    out += chair(1.4, -3.0, 0.8, rot=70, tip=(0, 90))
    bed = mattress(0, 0, 0, color="#cfc6b3", w=5.0, d=3.6, seed=3)
    move(bed, rot=(0, 62, 0), pivot=(2.5, 0, 0))
    out.append(move(bed, loc=(4.0, 0.9, 0)))
    out += carton(R, (1.8, 1.6, 1.3), loc=(-3.4, -2.4, 0), rot=20, faces=(-1,))
    out += caution_tape([(-6.8, 0.3, 2.8), (-3.65, -0.95, 2.02), (-0.5, -1.05, 1.47), (2.65, -0.75, 2.02), (2.4, -1.6, 2.52),
                         (2.3, -2.2, 1.2), (2.0, -2.6, 0.02)])
    out += caution_tape([(-3.4, -1.3, 4.9), (-3.3, -1.3, 5.62), (2.8, -1.3, 5.62), (2.9, -1.3, 4.5)])
    out += handprint(-1.5, -0.92, 1.0, s=0.9, tilt=20)
    P.add("Body", out)


def cart(R):
    """Bent store cart frame lying on its side: wire basket, chassis, four castors."""
    m = metal("#9a9d9a", rust=0.45)
    out = []
    L, W, H, z0 = 3.4, 2.0, 1.5, 1.4
    for a, b in (((-L / 2, -W / 2), (L / 2, -W / 2)), ((L / 2, -W / 2), (L / 2, W / 2)), ((L / 2, W / 2), (-L / 2, W / 2)), ((-L / 2, W / 2), (-L / 2, -W / 2))):
        out.append(strap((a[0], a[1], z0 + H), (b[0], b[1], z0 + H), 0.08, 0.08, m))
        out.append(strap((a[0] * 0.85, a[1] * 0.85, z0), (b[0] * 0.85, b[1] * 0.85, z0), 0.07, 0.07, m))
    for i in range(9):
        x = -L / 2 + L * i / 8
        for sy in (-1, 1):
            out.append(strap((x * 0.85, sy * W / 2 * 0.85, z0), (x, sy * W / 2, z0 + H), 0.05, 0.05, m, up=(1, 0, 0)))
    for j in range(5):
        y = -W / 2 + W * j / 4
        for sx in (-1, 1):
            out.append(strap((sx * L / 2 * 0.85, y * 0.85, z0), (sx * L / 2, y, z0 + H), 0.05, 0.05, m, up=(0, 1, 0)))
    out.append(strap((L / 2 + 0.5, -W / 2, z0 + H + 0.3), (L / 2 + 0.5, W / 2, z0 + H + 0.3), 0.18, 0.18, plain("#7a3a2e", grime=0.5)))
    for sy in (-1, 1):
        out.append(strap((L / 2, sy * W / 2, z0 + H), (L / 2 + 0.5, sy * W / 2, z0 + H + 0.3), 0.08, 0.08, m))
        out.append(strap((-L / 2 * 0.8, sy * 0.7, 0.45), (L / 2 * 0.8, sy * 0.7, 0.45), 0.1, 0.1, m))
        for sx in (-1, 1):
            out.append(strap((sx * L / 2 * 0.8, sy * 0.7, 0.45), (sx * L / 2 * 0.8, sy * 0.7 * 0.9, z0), 0.09, 0.09, m))
            out.append(cyl(0.3, 0.16, plain("#262422", grime=0.3), loc=(sx * L / 2 * 0.8, sy * 0.7, 0.3), rot=(90, 0, 0), seg=8, bevel=0.03))
    warp(out, lambda v: V((v.x, v.y, v.z - 0.5 * max(0.0, v.x) ** 2 / 4)))
    move(out, rot=(-90, 0, 0), pivot=(0, 0, 0))
    move(out, loc=(0, 0, W / 2 + 0.1))
    return out


def toy(R):
    """A faded little toy robot lying face up, one eye gone."""
    body = plain("#b8574a", grime=0.5, vary=0.35)
    head = plain("#d2b978", grime=0.5, vary=0.35)
    out = [box((0.5, 0.35, 0.6), body, loc=(0, 0, 0.3), r=0.04, n=1),
           box((0.45, 0.4, 0.4), head, loc=(0, 0, 0.82), r=0.05, n=1),
           cyl(0.07, 0.03, flat("#1a1818"), loc=(-0.1, -0.21, 0.85), rot=(90, 0, 0), seg=8, bevel=0.0),
           box((0.12, 0.02, 0.03), flat("#1a1818"), loc=(0.1, -0.21, 0.85), r=0.0, n=1)]
    for sx in (-1, 1):
        out.append(box((0.14, 0.18, 0.45), body, loc=(sx * 0.33, 0, 0.32), rot=(0, sx * 20, 0), r=0.03, n=1))
        out.append(box((0.16, 0.2, 0.3), head, loc=(sx * 0.13, 0, -0.15), r=0.03, n=1))
    move(out, rot=(80, 0, 0), pivot=(0, 0, 0))
    return out


@item("junk_pile", "warehouse", size=1024)
def junk_pile(P):
    R = random.Random(137)
    out = []
    out += move(cart(R), loc=(-1.0, 0.5, 0), rot=(0, 0, 15))
    out += carton(R, (2.0, 1.8, 1.4), loc=(2.0, 0.6, 0), rot=-12, faces=(-1,), crushed=0.6)
    out += carton(R, (1.6, 1.4, 1.1), loc=(1.6, 1.0, 1.3), rot=20, faces=(-1,), tip=(0, 15))
    out += open_carton(R, (1.5, 1.3, 1.0), loc=(3.4, -1.0, 0), rot=35)
    out += chair(0.6, -1.8, 0, rot=110, broken=True, tip=(0, 90))
    move(out[-9:], loc=(0, 0, 0.82))
    cab = plain("#1d1c1c", grime=0.25, vary=0.2)
    for pts in (((-3.4, -2.0, 0.06), (-2.0, -1.4, 0.06), (-1.2, -2.4, 0.06), (0.4, -2.8, 0.06)),
                ((2.4, -0.4, 0.06), (1.4, -1.0, 0.4), (0.0, -0.4, 1.1), (-1.6, 0.2, 2.0)),
                ((-2.6, 1.6, 0.06), (-3.6, 0.2, 0.06), (-3.0, -0.8, 0.06))):
        out.append(tube(pts, 0.06, cab, seg=6, per=4))
    out += move(toy(R), loc=(-2.2, -2.6, 0.2), rot=(0, 0, 25))
    out.append(puddle(R, 2.8, -2.4, 0.7))
    P.add("Body", out)


@item("oil_drum", "warehouse", size=512)
def oil_drum(P):
    R = random.Random(139)
    P.add("Body", drum(R, 0, 0, 0, color=TEAL))
    # streaks sit on the flat facet that faces -y (10-sided drum), so they hug the steel
    P.add("Body", streak(0.12, -0.903, 2.6, 2.55, w=0.13))
    P.add("Body", streak(-0.14, -0.903, 2.1, 2.05, w=0.09))
    pool = [(math.cos(a) * r, math.sin(a) * r * 0.75) for a, r in ((2 * math.pi * i / 12, R.uniform(0.9, 1.6)) for i in range(12))]
    P.add("Body", slab(pool, 0.02, oil(), loc=(0.2, -1.6, 0.011), rot=(90, 0, 0)))
    P.add("Body", box((0.5, 0.5, 0.02), oil(), loc=(0.55, 0.0, 2.92), r=0.0, n=1))


@item("crate_stack", "warehouse", size=512)
def crate_stack(P):
    R = random.Random(149)
    out = []
    out += crate(R, (4.0, 3.0, 3.0), loc=(-1.2, 0, 0), rot=3)
    out += crate(R, (3.0, 3.0, 2.4), loc=(2.4, 0.2, 0), rot=-6, word=False)
    out += crate(R, (3.0, 2.6, 2.4), loc=(-0.6, 0.1, 3.0), rot=12)
    out += crate(R, (2.2, 2.0, 1.8), loc=(2.2, 0.0, 2.4), rot=-20, word=False)
    out.append(streak(-2.6, -1.55, 2.4, 1.8, w=0.16))
    P.add("Body", out)


@item("lone_display", "warehouse", size=512)
def lone_display(P):
    """A single store display plinth, emptied, one leftover box on top. Meant to stand alone in an empty room."""
    R = random.Random(151)
    top = plain("#d9a3b0", grime=0.45, vary=0.3)
    side = plain("#e2dccd", grime=0.5, vary=0.3)
    out = [box((3.2, 3.2, 0.3), plain("#5a5752", grime=0.4), loc=(0, 0, 0.15), r=0.0, n=1),
           box((3.0, 3.0, 2.4), side, loc=(0, 0, 1.5), r=0.04, n=1),
           box((3.3, 3.3, 0.18), top, loc=(0, 0, 2.79), r=0.04, n=1),
           box((3.02, 0.02, 0.22), plain(PRIMARY[2], grime=0.45, vary=0.3), loc=(0, -1.51, 2.2), r=0.0, n=1)]
    out += carton(R, (1.0, 0.8, 1.2), loc=(0.45, 0.3, 2.88), rot=-14, color=PRIMARY[1], faces=(-1,), deco=1.0)
    out += [box((0.7, 0.04, 0.45), label(), loc=(-0.8, -1.2, 3.12), rot=(-15, 0, 8), r=0.0, n=1),
            box((0.06, 0.25, 0.25), side, loc=(-0.8, -1.08, 2.98), r=0.0, n=1),
            words("4.99", 0.18, plain("#a33a2c", grime=0.5, vary=0.4), loc=(-0.8, -1.235, 3.1), rot=(-15, 0, 8), depth=0.006)]
    out.append(box((1.2, 1.0, 0.012), plain("#cfc8ba", grime=0.2, vary=0.2), loc=(-0.6, 0.4, 2.885), r=0.0, n=1))
    out += handprint(1.0, -1.51, 1.4, s=0.9, tilt=-10)
    P.add("Body", out)

# ---------------------------------------------------------------- dreamcore installation pieces
def cubby(color, loc=(0, 0, 0), rot=0, tip=(0, 0), w=2.2, d=1.6, h=1.1):
    """Kids' stacking cubby bin: open scooped front so you see inside."""
    m = plain(color, grime=0.35, vary=0.2)
    t = 0.08
    side = [(-d / 2, 0), (d / 2, 0), (d / 2, h), (-d / 2 + 0.5, h), (-d / 2, h * 0.45)]
    out = [box((w, d, t), m, loc=(0, 0, t / 2), r=0.0, n=1),
           box((w, t, h), m, loc=(0, d / 2 - t / 2, h / 2), r=0.0, n=1),
           box((w, t, h * 0.45), m, loc=(0, -d / 2 + t / 2, h * 0.225), r=0.0, n=1),
           box((w, 0.5, t), m, loc=(0, d / 2 - 0.25, h - t / 2), r=0.0, n=1)]
    for sx in (-1, 1):
        out.append(slab(side, t, m, loc=(sx * (w / 2 - t / 2), 0, 0), rot=(0, 0, 90)))
    move(out, rot=(tip[0], tip[1], 0))
    return move(out, loc=loc, rot=(0, 0, rot))


@item("cubbies", "warehouse", size=512)
def cubbies(P):
    """A tall stack of bright kids' cubby bins, two columns, a couple pulled out, one dropped on the floor."""
    R = random.Random(157)
    cols = ("#e0789a", "#3f78c8", "#e6c23a", "#55b06a", "#e8843a")
    out = []
    for c in range(2):
        for k in range(6):
            pulled = (c, k) in ((0, 2), (1, 4))
            out += cubby(cols[(k + c * 2) % len(cols)], loc=(-1.15 + c * 2.3 + R.uniform(-0.04, 0.04), -0.5 if pulled else R.uniform(-0.04, 0.04), k * 1.1),
                         rot=R.uniform(-4, 4) if pulled else R.uniform(-1, 1))
    out += cubby(cols[1], loc=(1.4, -2.4, 0.0), rot=35, tip=(-90, 0))
    move(out[-6:], loc=(0, 0, 0.8))
    out.append(box((0.5, 0.4, 0.4), plain("#c27d6d", grime=0.4, vary=0.3), loc=(-1.1, -0.1, 3 * 1.1 + 0.28), rot=(0, 0, 20), r=0.05, n=1))
    P.add("Body", out)


def wood_shelves(w, h, d, bays, levels, m, back=True, tilt=None):
    """Store shelving in plain honey wood: end panels, kick base, back, shelves. tilt: (bay, level) that slipped."""
    out = [box((w, d, 0.5), m, loc=(0, 0, 0.25), r=0.0, n=1)]
    bw = w / bays
    for i in range(bays + 1):
        out.append(box((0.18, d + 0.1, h), m, loc=(-w / 2 + i * bw, 0, h / 2), r=0.0, n=1))
    if back:
        out.append(box((w, 0.12, h - 0.5), m, loc=(0, d / 2 - 0.06, h / 2 + 0.25), r=0.0, n=1))
    out.append(box((w + 0.18, d + 0.2, 0.16), m, loc=(0, 0, h + 0.08), r=0.0, n=1))
    for i in range(bays):
        x = -w / 2 + bw * (i + 0.5)
        for j, z in enumerate(levels):
            s = box((bw - 0.18, d - 0.12, 0.1), m, loc=(x, -0.06, z), r=0.0, n=1)
            if tilt == (i, j):
                move(s, rot=(0, 16, 0), pivot=(x - bw / 2, 0, z))
            out.append(s)
    return out


def honey():
    return wood("#b88a56", "#7a5532", axis="x", wear=0.35)


@item("bookshelf_empty", "warehouse", size=512)
def bookshelf_empty(P):
    """One tall unit of plain store shelving, stripped completely bare."""
    P.add("Body", wood_shelves(6.0, 7.5, 2.0, 1, (1.9, 3.3, 4.7, 6.1), honey()))


@item("bookshelf_wall", "warehouse", size=1024)
def bookshelf_wall(P):
    """A 32-long run of empty wood shelves for along a wall. One shelf has slipped its pegs."""
    P.add("Body", wood_shelves(32.0, 7.5, 2.0, 8, (1.9, 3.3, 4.7, 6.1), honey(), tilt=(5, 2)))


def checkout(P, number, lit):
    """One checkout lane, 12 long along y: counter with a dead belt, register, bagging well, empty impulse rack, and a
    lane light on a square pole. Rows of these go every 8 studs, so the lane between counters is about 5 wide."""
    R = random.Random(300 + number)
    shell = plain("#d8d2c4", grime=0.55, vary=0.25)
    kick = plain("#4a4844", grime=0.5)
    belt = plain("#1f1e1d", grime=0.3)
    steel = metal("#9a968e", 0.35)
    P.add("Body", box((2.6, 9.0, 0.3), kick, loc=(0, -0.5, 0.15), r=0.0, n=1),
          box((2.6, 9.0, 2.7), shell, loc=(0, -0.5, 1.65), r=0.04, n=1),
          box((2.2, 6.0, 0.08), belt, loc=(0, -2.0, 3.04), r=0.01, n=1),
          box((2.4, 0.12, 0.25), steel, loc=(0, -5.0, 3.1), r=0.02, n=1),
          box((0.12, 6.0, 0.18), steel, loc=(-1.15, -2.0, 3.1), r=0.0, n=1),
          box((0.12, 6.0, 0.18), steel, loc=(1.15, -2.0, 3.1), r=0.0, n=1))
    # register and dead card reader
    P.add("Body", box((1.1, 0.9, 0.6), plain("#3a3a3c", grime=0.4), loc=(0.6, 2.2, 3.3), r=0.04, n=1),
          box((0.9, 0.06, 0.6), plain("#151617"), loc=(0.6, 1.72, 3.75), rot=(-20, 0, 0), r=0.01, n=1),
          box((0.35, 0.3, 0.5), plain("#2a2b2d", grime=0.4), loc=(-0.8, 1.6, 3.25), r=0.03, n=1))
    # bagging well at the far end, square bars
    P.add("Body", box((2.6, 2.6, 0.12), steel, loc=(0, 5.3, 2.6), r=0.0, n=1))
    for x in (-1.25, 1.25):
        for y in (4.05, 6.55):
            P.add("Body", box((0.1, 0.1, 2.6), steel, loc=(x, y, 1.3), r=0.0, n=1))
    # empty impulse rack on the customer side, a few leftovers
    P.add("Body", box((0.6, 3.0, 4.2), plain(PRIMARY[R.randrange(len(PRIMARY))], grime=0.55, vary=0.3), loc=(-1.75, -3.4, 2.1), r=0.03, n=1))
    for z in (1.0, 2.0, 3.0, 4.0):
        P.add("Body", box((0.5, 2.9, 0.06), steel, loc=(-2.1, -3.4, z), r=0.0, n=1))
    for k in range(R.randint(1, 3)):
        P.add("Body", box((0.3, 0.4, 0.5), plain(PRIMARY[R.randrange(len(PRIMARY))], grime=0.4), loc=(-2.15, -4.5 + R.random() * 2.2, 1.0 + R.randint(0, 3) + 0.28), rot=(0, 0, R.uniform(-20, 20)), r=0.02, n=1))
    # lane light: square pole, number box; one lane's light is still on
    P.add("Body", box((0.25, 0.25, 6.0), steel, loc=(1.1, -4.6, 6.0), r=0.0, n=1),
          box((1.0, 1.0, 1.0), plain("#e6e1d6", grime=0.5), loc=(1.1, -4.6, 9.5), r=0.05, n=1))
    for face in (-1, 1):
        P.add("Body", words(str(number), 0.55, plain("#2a2a2a"), loc=(1.1, -4.6 + face * 0.51, 9.25), rot=(0, 0, 0 if face < 0 else 180)))
    if lit:
        P.add("Glow", box((1.02, 1.02, 0.25), plain("#ffd27a"), loc=(1.1, -4.6, 10.1), r=0.02, n=1))
    else:
        P.add("Body", box((1.02, 1.02, 0.25), plain("#6a6458", grime=0.5), loc=(1.1, -4.6, 10.1), r=0.02, n=1))
    P.add("Body", streak(0.4, -5.02 + 0.0, 2.9, 1.6), handprint(-0.6, -5.02, 2.3, s=0.9, tilt=10))
    P.add("Body", puddle(R, -2.3, 1.5, 0.9))


@item("checkout_lane", "warehouse")
def checkout_lane(P):
    checkout(P, 7, lit=False)


@item("checkout_lane_lit", "warehouse")
def checkout_lane_lit(P):
    """The one lane whose light still works."""
    checkout(P, 4, lit=True)


main()
