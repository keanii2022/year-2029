"""Pretend neighborhood: the cul-de-sac the robots built inside the dark warehouse after studying human homes.
A stage set. Pastel house fronts that are only fronts (raw plywood, studs and sandbagged braces behind),
painted-on doors, warm windows with nobody home, a street, lamps and lawn props, all a little too perfect.
Run from art: _kit/run.sh warehouse/neighborhood.py <name> ...

Houses: the front face is the plane y = 0 before the origin moves to the bottom centre of the bounding box,
so after export the front sits (depth / 2) in front of the origin; braces and side flats run back toward +y.
Floor pieces: asphalt top at 0.2 like the other floor tiles, curb, sidewalk and driveway tops at 0.7.
"""
import math, os, random, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "furniture"))
from common import *  # noqa
import bmesh
import kit
from mathutils import Matrix, Vector as V

TRIM = "#efeae0"
LUMBER = "#b8905c"
OIL = "#0b0a0a"
FONT_INK = "#3a3640"


# ---------------------------------------------------------------- materials (made per item: each build wipes the scene)
def _pos(g):
    s = g.n("ShaderNodeSeparateXYZ")
    g.t.links.new(g.geo.outputs["Position"], s.inputs[0])
    return s.outputs


def _lines(g, v, period, width):
    return g.math("LESS_THAN", g.math("FRACT", g.math("DIVIDE", v, period)), width / period)


@cached
def siding(color):
    """Lap siding: a shadow line under every board, faded and lightly streaked."""
    g = kit.G("siding")
    _, _, z = _pos(g)
    lap = g.math("SUBTRACT", 1.0, g.step(g.math("FRACT", g.math("DIVIDE", z, 0.55)), 0.0, 0.16))
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(1.2, 4), 0.35, 0.75), 0.3), color, g.mix(0.5, color, "#fff4e2"))
    c = g.mix(g.math("MULTIPLY", lap, 0.45), c, g.mix(0.5, color, "#3a3040"))
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(3, 4, (1, 1, 0.08), world=True), 0.6, 0.75), 0.25), c, "#6a5a4c", "MULTIPLY")
    return g.done(c)


def stucco(color):
    return plain(color, grime=0.3, vary=0.3)


@cached
def shingles(color):
    """Asphalt shingle rows with staggered tab cuts."""
    g = kit.G("shingle")
    x, y, z = _pos(g)
    row = g.math("FLOOR", g.math("DIVIDE", z, 0.55))
    off = g.math("MULTIPLY", g.math("FLOORED_MODULO", row, 2.0), 0.6)
    tab = _lines(g, g.math("ADD", g.math("ADD", x, y), off), 1.2, 0.06)
    line = _lines(g, z, 0.55, 0.07)
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(2.5, 4), 0.3, 0.7), 0.45), color, g.mix(0.5, color, "#1e1c22"))
    c = g.mix(g.math("MULTIPLY", g.math("MAXIMUM", tab, line), 0.6), c, g.mix(0.6, color, "#141216"))
    return g.done(c, ao=0.7)


@cached
def plywood():
    """Raw stage-set plywood: 4 x 8 sheets, pencil-pale grain, dark seams, an old water stain."""
    g = kit.G("plywood")
    x, y, z = _pos(g)
    c = g.mix(g.step(g.noise(2.2, 6, (1, 1, 0.15)), 0.35, 0.7), "#a5814f", "#d2b07c")
    seam = g.math("MAXIMUM", _lines(g, z, 8.0, 0.06), _lines(g, g.math("ADD", x, y), 4.0, 0.06))
    c = g.mix(g.math("MULTIPLY", seam, 0.7), c, "#5e4a30")
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(0.4, 3, world=True), 0.6, 0.66), 0.35), c, "#7a5c38", "MULTIPLY")
    return g.done(c, ao=0.9)


@cached
def asphalt():
    g = kit.G("asphalt")
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(6, 2), 0.55, 0.72), 0.5), "#3c3c3e", "#6a6864")
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(0.08, 4), 0.45, 0.7), 0.6), c, "#2a2a2c")
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(0.2, 3), 0.62, 0.75), 0.4), c, "#5a5752")
    return g.done(c, ao=0.4)


@cached
def worn_line(color):
    """Road paint worn through to the asphalt in patches."""
    g = kit.G("worn")
    c = g.mix(0.25, color, "#6a6864")
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(1.0, 5), 0.5, 0.62), 0.8), c, "#4a4a4a")
    return g.done(c, ao=0.3, top=0.0)


@cached
def leaf(color):
    """Moulded plastic leaves: speckled two-tone green with the panel seams showing."""
    g = kit.G("leaf")
    x, y, z = _pos(g)
    c = g.mix(g.step(g.noise(9, 3), 0.42, 0.58), g.mix(0.45, color, "#1c3a20"), color)
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(14, 2), 0.66, 0.7), 0.6), c, g.mix(0.5, color, "#eaffd0"))
    seam = g.math("MAXIMUM", _lines(g, g.math("ADD", x, y), 2.0, 0.03), _lines(g, z, 2.0, 0.03))
    c = g.mix(g.math("MULTIPLY", seam, 0.55), c, "#1a2a18")
    return g.done(c, ao=0.8)


def oil():
    return flat(OIL)


def trim():
    return paint(TRIM, chip=0.12, under="#9a9080", grime=0.45, streaks=0.5)


def lumber():
    return wood(LUMBER, "#7a5a34", axis="z", wear=0.3)


def concrete():
    return plain("#b3ada2", grime=0.5, vary=0.35)


def warm():
    return glow("#ffc978", core="#fff0cf", amount=0.25)


def dark_glass():
    return plain("#262c3a", grime=0.15, vary=0.15, ao=0.5)


def ink():
    return flat(FONT_INK)


# ---------------------------------------------------------------- shapes
def bar(a, b, t, mat):
    """Square-section bar from point a to point b."""
    a, b = V(a), V(b)
    d = b - a
    o = box((t, t, d.length), mat, r=0.0, n=1)
    q = V((0, 0, 1)).rotation_difference(d.normalized())
    o.data.transform(Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4())
    return o


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


def skinned(pts, skin, out, t_skin=0.08, t_ply=0.3):
    """A painted flat with raw plywood behind it: the skin faces `out`, the plywood shows from the back."""
    n = V(out).normalized()
    return [plate(pts, t_skin, skin, out), plate([V(p) - n * t_skin for p in pts], t_ply, plywood(), out)]


def roof(pts, color, out=(0, 0, 1)):
    """Shingled roof plate with a plywood underside (seen from behind the set)."""
    n = (V(pts[1]) - V(pts[0])).cross(V(pts[2]) - V(pts[0])).normalized()
    if n.dot(V(out)) < 0:
        n = -n
    return [plate(pts, 0.15, shingles(color), out), plate([V(p) - n * 0.15 for p in pts], 0.2, plywood(), out)]


def flat_blob(r, seed, n=9):
    rnd = random.Random(seed)
    return [(math.cos(2 * math.pi * i / n) * r * rnd.uniform(0.55, 1.0), math.sin(2 * math.pi * i / n) * r * rnd.uniform(0.55, 1.0))
            for i in range(n)]


def wall_blot(x, z, y, r, seed):
    """Black oil smudge on a wall facing -y."""
    return slab(flat_blob(r, seed), 0.01, oil(), loc=(x, y - 0.005, z))


def floor_blot(x, y, z, r, seed):
    """Black oil stain lying on a floor at height z."""
    return slab(flat_blob(r, seed, 11), 0.01, oil(), loc=(x, y, z + 0.005), rot=(90, 0, 0))


def drips(x0, x1, ztop, y, lengths, seed):
    rnd = random.Random(seed)
    return [box((rnd.uniform(0.05, 0.1), 0.01, ln), oil(), loc=(rnd.uniform(x0, x1), y - 0.005, ztop - ln / 2), r=0.0, n=1)
            for ln in lengths]


def house_number(x, z, text):
    return [box((0.5 + 0.38 * len(text), 0.08, 0.7), trim(), loc=(x, -0.04, z), r=0.0, n=1),
            words(text, 0.5, ink(), loc=(x, -0.09, z), depth=0.02)]


# ---------------------------------------------------------------- house parts
def back_frame(P, x0, x1, h, y=0.38):
    """Studs every 4 and three plates on the back of a flat."""
    lum = lumber()
    n = max(1, round((x1 - x0) / 4))
    for i in range(n + 1):
        x = x0 + 0.15 + (x1 - x0 - 0.3) * i / n
        P.add("Body", box((0.3, 0.5, h - 0.6), lum, loc=(x, y + 0.25, h / 2), r=0.0, n=1))
    for z in (0.15, h / 2, h - 0.15):
        P.add("Body", box((x1 - x0, 0.5, 0.3), lum, loc=((x0 + x1) / 2, y + 0.25, z), r=0.0, n=1))


def braces(P, xs, top, reach, y=0.88, seed=0):
    """Diagonal kickers from the back of the set down to floor runners held by sandbags, like a movie set."""
    lum = lumber()
    bag = cloth("#b9a982", dirt=0.5)
    rnd = random.Random(seed)
    for x in xs:
        P.add("Body", bar((x, y, top), (x, y + reach, 0.3), 0.3, lum),
              box((0.3, reach + 0.6, 0.3), lum, loc=(x, y + reach / 2 + 0.2, 0.15), r=0.0, n=1),
              box((1.1, 0.75, 0.45), bag, loc=(x + rnd.uniform(-0.1, 0.1), y + reach - 0.2, 0.52), rot=(0, 0, rnd.uniform(-12, 12)), r=0.15, n=1))


def side_flats(P, w, depth, profile, skin):
    """Short painted side walls under the roof so the corners read as a whole house from the front.
    profile: [(y, z), ...] outline in the y-z plane."""
    for sx in (-1, 1):
        x = sx * w / 2
        P.add("Body", skinned([(x, y, z) for y, z in profile], skin, (sx, 0, 0)))


def foundation(P, w):
    P.add("Body", box((w + 0.2, 0.35, 0.9), concrete(), loc=(0, -0.12, 0.45), r=0.0, n=1))


def window(P, x, z0, w, h, lit=False, shutter=None, curtain="#efe2c8", picture=False):
    """Trimmed window. lit glass goes in the Glow part; dark glass is a flat picture of a window."""
    t = trim()
    zc = z0 + h / 2
    for sx in (-1, 1):
        P.add("Body", box((0.3, 0.3, h + 0.6), t, loc=(x + sx * (w / 2 + 0.15), -0.12, zc), r=0.0, n=1))
    P.add("Body", box((w + 0.6, 0.3, 0.3), t, loc=(x, -0.12, z0 + h + 0.15), r=0.0, n=1),
          box((w + 1.0, 0.55, 0.2), t, loc=(x, -0.25, z0 - 0.1), r=0.0, n=1))
    glass = box((w, 0.04, h), warm() if lit else dark_glass(), loc=(x, -0.02, zc), r=0.0, n=1)
    P.add("Glow" if lit else "Body", glass)
    P.add("Body", box((0.12, 0.06, h), t, loc=(x, -0.07, zc), r=0.0, n=1),
          box((w, 0.06, 0.12), t, loc=(x, -0.07, zc), r=0.0, n=1))
    cm = plain(curtain, grime=0.2, vary=0.2)
    for sx in (-1, 1):
        P.add("Body", box((w * 0.18, 0.02, h * 0.92), cm, loc=(x + sx * w * 0.38, -0.05, zc + h * 0.02), r=0.0, n=1))
    if picture:
        # painted reflection streak: the glass is a picture, not glass
        P.add("Body", slab([(-w * 0.3, -h * 0.4), (-w * 0.15, -h * 0.4), (w * 0.2, h * 0.4), (w * 0.05, h * 0.4)], 0.01,
                           plain("#5d6a80", grime=0.1), loc=(x, -0.045, zc)))
    if shutter:
        sm = paint(shutter, chip=0.15, grime=0.4, streaks=0.4)
        for sx in (-1, 1):
            sxc = x + sx * (w / 2 + 0.3 + w * 0.22)
            P.add("Body", box((w * 0.42, 0.14, h + 0.4), sm, loc=(sxc, -0.07, zc), r=0.0, n=1))
            for k in range(5):
                P.add("Body", box((w * 0.34, 0.05, 0.1), sm, loc=(sxc, -0.16, z0 + h * (0.12 + 0.19 * k)), r=0.0, n=1))


def painted_door(P, x, color, w=3.5, h=7.0, z0=0.0):
    """A door painted flat on the wall: frame, panels and knob are all paint."""
    paint_mat = plain(color, grime=0.25, vary=0.2)
    shade = flat(kit_mix(color, "#2a2430", 0.35))
    t = plain(TRIM, grime=0.3, vary=0.2)
    P.add("Body", box((w + 0.8, 0.01, h + 0.4), t, loc=(x, -0.006, z0 + (h + 0.4) / 2), r=0.0, n=1),
          box((w, 0.01, h), paint_mat, loc=(x, -0.014, z0 + h / 2), r=0.0, n=1))
    for zc, ph in ((z0 + h * 0.72, h * 0.34), (z0 + h * 0.27, h * 0.38)):
        for sx in (-1, 1):
            P.add("Body", box((w * 0.32, 0.01, ph), shade, loc=(x + sx * w * 0.22, -0.02, zc), r=0.0, n=1))
    P.add("Body", cyl(0.17, 0.01, flat("#c9a54a"), loc=(x + w * 0.36, -0.024, z0 + h * 0.48), rot=(90, 0, 0), seg=12, bevel=0.0))


def kit_mix(a, b, k):
    ca = [int(a.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)]
    cb = [int(b.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)]
    return "#" + "".join(f"{round(p + (q - p) * k):02x}" for p, q in zip(ca, cb))


def real_door(P, x, color, w=3.5, h=7.0, knob_z=None, y=0.0):
    """A raised panel door that never opens (part of Body)."""
    d = paint(color, chip=0.15, grime=0.4, streaks=0.4)
    t = trim()
    P.add("Body", box((w, 0.2, h), d, loc=(x, y - 0.08, h / 2), r=0.0, n=1))
    for sx in (-1, 1):
        P.add("Body", box((0.3, 0.35, h + 0.3), t, loc=(x + sx * (w / 2 + 0.15), y - 0.15, (h + 0.3) / 2), r=0.0, n=1))
    P.add("Body", box((w + 0.9, 0.35, 0.35), t, loc=(x, y - 0.15, h + 0.2), r=0.0, n=1))
    for zc, ph in ((h * 0.72, h * 0.32), (h * 0.28, h * 0.36)):
        for sx in (-1, 1):
            P.add("Body", box((w * 0.32, 0.06, ph), d, loc=(x + sx * w * 0.22, y - 0.2, zc), r=0.0, n=1))
    kz = h * 0.48 if knob_z is None else knob_z
    knob = metal("#b9a26a", rust=0.2)
    P.add("Body", box((0.22, 0.06, 0.34), knob, loc=(x + w * 0.36 if knob_z is None else x, y - 0.21, kz), r=0.0, n=1),
          box((0.2, 0.22, 0.2), knob, loc=(x + w * 0.36 if knob_z is None else x, y - 0.33, kz), r=0.04, n=1))


def step(P, x, w, d, h, y0=0.0):
    P.add("Body", box((w, d, h), concrete(), loc=(x, y0 - d / 2, h / 2), r=0.0, n=1))


# ---------------------------------------------------------------- houses
@item("house_ranch", "warehouse", size=1024)
def house_ranch(P):
    """Single storey, side gable, peach stucco, painted-on door, two lit windows."""
    w, h, depth = 24.0, 9.0, 6.0
    skin = stucco("#f0b8a6")
    P.add("Body", skinned([(-w / 2, 0, 0), (w / 2, 0, 0), (w / 2, 0, h), (-w / 2, 0, h)], skin, (0, -1, 0)))
    foundation(P, w)
    eave_y, eave_z, ridge_y, ridge_z = -1.6, 8.75, depth, 13.2
    slope = (ridge_z - eave_z) / (ridge_y - eave_y)
    under = eave_z + (0 - eave_y) * slope - 0.35
    side_flats(P, w, depth, [(0.38, 0), (depth, 0), (depth, ridge_z - 0.4), (0.38, under + 0.38 * slope)], skin)
    o = w / 2 + 1.0
    P.add("Body", roof([(-o, eave_y, eave_z), (o, eave_y, eave_z), (o, ridge_y, ridge_z), (-o, ridge_y, ridge_z)], "#6f6987"))
    t = trim()
    P.add("Body", box((2 * o + 0.2, 0.25, 0.7), t, loc=(0, eave_y - 0.05, eave_z - 0.25), r=0.0, n=1),
          box((2 * o + 0.2, 0.7, 0.35), shingles("#5c5672"), loc=(0, ridge_y - 0.2, ridge_z + 0.05), r=0.0, n=1),
          box((w, 0.4, 0.5), t, loc=(0, -0.1, h + 0.1), r=0.0, n=1))
    for sx in (-1, 1):
        P.add("Body", box((0.5, 0.3, h), t, loc=(sx * (w / 2 - 0.25), -0.1, h / 2), r=0.0, n=1))
        window(P, sx * 6.8, 3.0, 4.2, 3.8, lit=True, shutter="#86c2b0")
    painted_door(P, 0.0, "#7fa3c4", z0=0.55)
    step(P, 0.0, 5.0, 1.8, 0.55)
    P.add("Body", house_number(0.0, 8.35, "12"))
    # the robots tried the painted knob: oily smears around it, drips down the paint, a puddle on the step
    P.add("Body", wall_blot(1.35, 3.95, -0.03, 0.35, 3), wall_blot(1.0, 3.6, -0.03, 0.22, 8),
          drips(0.9, 1.6, 3.7, -0.03, (0.9, 1.6, 0.6), 4), floor_blot(0.6, -0.9, 0.55, 0.5, 5))
    back_frame(P, -w / 2 + 0.1, w / 2 - 0.1, h)
    braces(P, (-9.0, -3.0, 3.0, 9.0), h * 0.75, 4.6, seed=1)


@item("house_twostory", "warehouse", size=1024)
def house_twostory(P):
    """Two storeys, front gable, mint lap siding, one lit window, a door knob in the wrong place."""
    w, h, apex, depth = 20.0, 17.0, 24.0, 7.0
    skin = siding("#a9d6c2")
    P.add("Body", skinned([(-w / 2, 0, 0), (w / 2, 0, 0), (w / 2, 0, h), (0, 0, apex), (-w / 2, 0, h)], skin, (0, -1, 0)))
    foundation(P, w)
    side_flats(P, w, depth, [(0.38, 0), (depth, 0), (depth, h), (0.38, h)], skin)
    ex, ez, ay = w / 2 + 1.2, h - 0.75, -1.2
    k = (apex - h) / (w / 2)
    az = apex + 0.35
    for sx in (-1, 1):
        P.add("Body", roof([(0, ay, az), (sx * ex, ay, az - ex * k), (sx * ex, depth, az - ex * k), (0, depth, az)], "#66707e"))
    t = trim()
    for sx in (-1, 1):
        a, b = V((0, ay - 0.15, az - 0.25)), V((sx * ex, ay - 0.15, az - ex * k - 0.25))
        rake = box(((b - a).length + 0.3, 0.3, 0.6), t, r=0.0, n=1)
        move(rake, rot=(0, -math.degrees(math.atan2(b.z - a.z, b.x - a.x)), 0), loc=(a + b) / 2)
        P.add("Body", rake, box((0.6, 0.3, h), t, loc=(sx * (w / 2 - 0.3), -0.12, h / 2), r=0.0, n=1))
    P.add("Body", box((w, 0.3, 0.45), t, loc=(0, -0.12, 8.6), r=0.0, n=1))
    # louvred gable vent
    P.add("Body", box((2.4, 0.2, 1.8), t, loc=(0, -0.08, 19.6), r=0.0, n=1))
    for i in range(4):
        P.add("Body", box((2.0, 0.12, 0.16), plain("#5b6662", grime=0.4), loc=(0, -0.2, 18.95 + i * 0.42), r=0.0, n=1))
    window(P, -6.0, 10.6, 3.2, 4.2, lit=True, curtain="#f2d9c4")
    window(P, 0.0, 10.6, 3.2, 4.2, picture=True)
    window(P, 6.0, 10.6, 3.2, 4.2, picture=True, curtain="#e8cfd6")
    window(P, -4.8, 2.8, 5.4, 4.0, picture=True)
    real_door(P, 5.2, "#c98e98", knob_z=3.6)
    # door hood on two brackets
    P.add("Body", box((5.4, 1.8, 0.3), t, loc=(5.2, -0.9, 7.9), r=0.0, n=1),
          roof([(2.4, -2.0, 8.5), (8.0, -2.0, 8.5), (8.0, -0.05, 9.3), (2.4, -0.05, 9.3)], "#66707e"))
    for sx in (-1, 1):
        P.add("Body", bar((5.2 + sx * 2.4, -0.05, 6.8), (5.2 + sx * 2.4, -1.5, 7.75), 0.25, t))
    step(P, 5.2, 4.8, 2.4, 0.3)
    step(P, 5.2, 4.8, 1.2, 0.6)
    P.add("Body", house_number(8.6, 5.6, "14"))
    P.add("Body", drips(-7.0, -5.0, 10.4, -0.04, (2.2, 3.5, 1.4), 2), wall_blot(-8.4, 1.4, -0.04, 0.6, 7),
          floor_blot(4.2, -1.2, 0.3, 0.45, 9))
    back_frame(P, -w / 2 + 0.1, w / 2 - 0.1, h)
    braces(P, (-7.0, 0.0, 7.0), 12.5, 5.6, seed=2)


@item("house_garage", "warehouse", size=1024, pivots={"Door": (-5.5, 0.1, 8.7)})
def house_garage(P):
    """Butter yellow siding, hip roof, a sectional garage door that slides up onto nothing."""
    w, h, depth = 24.0, 10.5, 6.0
    gx0, gx1, gz0, gz1 = -10.5, -0.5, 0.7, 8.7
    skin = siding("#f2db93")
    face = lambda x0, x1, z0, z1: skinned([(x0, 0, z0), (x1, 0, z0), (x1, 0, z1), (x0, 0, z1)], skin, (0, -1, 0))
    P.add("Body", face(-w / 2, gx0, 0, h), face(gx1, w / 2, 0, h), face(gx0, gx1, gz1, h))
    P.add("Body", box((w / 2 - gx1 + 0.1, 0.35, 0.9), concrete(), loc=((gx1 + w / 2) / 2, -0.12, 0.45), r=0.0, n=1),
          box((gx0 + w / 2 + 0.1, 0.35, 0.9), concrete(), loc=((gx0 - w / 2) / 2, -0.12, 0.45), r=0.0, n=1),
          box((gx1 - gx0, 2.0, gz0), concrete(), loc=((gx0 + gx1) / 2, 0.6, gz0 / 2), r=0.0, n=1))
    side_flats(P, w, depth, [(0.38, 0), (depth, 0), (depth, h), (0.38, h)], skin)
    ey, ez, rz = -1.6, h - 0.4, h + 3.6
    o = w / 2 + 1.0
    rx = o - (depth - ey)
    rc = "#8a6f7c"
    P.add("Body", roof([(-o, ey, ez), (o, ey, ez), (rx, depth, rz), (-rx, depth, rz)], rc))
    for sx in (-1, 1):
        P.add("Body", roof([(sx * o, ey, ez), (sx * o, depth, ez), (sx * rx, depth, rz)], rc, out=(sx, 0, 1)))
    t = trim()
    P.add("Body", box((2 * o + 0.2, 0.25, 0.7), t, loc=(0, ey - 0.05, ez - 0.25), r=0.0, n=1),
          box((2 * rx + 0.4, 0.7, 0.35), shingles("#715a66"), loc=(0, depth - 0.2, rz + 0.05), r=0.0, n=1))
    for sx in (-1, 1):
        P.add("Body", box((0.5, 0.3, h), t, loc=(sx * (w / 2 - 0.25), -0.1, h / 2), r=0.0, n=1))
    # opening trim, then the sectional door recessed in it
    for x in (gx0 - 0.25, gx1 + 0.25):
        P.add("Body", box((0.5, 0.4, gz1 - gz0 + 0.5), t, loc=(x, -0.15, (gz0 + gz1 + 0.5) / 2), r=0.0, n=1))
    P.add("Body", box((gx1 - gx0 + 1.0, 0.4, 0.5), t, loc=((gx0 + gx1) / 2, -0.15, gz1 + 0.25), r=0.0, n=1))
    gd = paint("#f4efe2", chip=0.1, grime=0.5, streaks=0.6)
    gw, gh, gc = gx1 - gx0 - 0.1, gz1 - gz0, (gx0 + gx1) / 2
    P.add("Door", box((gw, 0.2, gh), gd, loc=(gc, 0.1, gz0 + gh / 2), r=0.0, n=1))
    for i in range(1, 4):
        P.add("Door", box((gw, 0.03, 0.08), plain("#a9a294", grime=0.4), loc=(gc, -0.005, gz0 + gh * i / 4), r=0.0, n=1))
    for i in range(4):
        for j in range(4):
            zc = gz0 + gh * (i + 0.5) / 4
            P.add("Door", box((gw / 4 - 0.6, 0.05, gh / 4 - 0.6), gd, loc=(gc + gw * (j - 1.5) / 4, -0.02, zc), r=0.0, n=1))
    for j in range(4):
        P.add("Door", box((gw / 4 - 0.8, 0.02, 0.9), dark_glass(), loc=(gc + gw * (j - 1.5) / 4, -0.05, gz0 + gh * 3.5 / 4), r=0.0, n=1))
    P.add("Door", box((1.0, 0.18, 0.18), metal("#8a8780", rust=0.3), loc=(gc, -0.1, gz0 + 0.8), r=0.03, n=1))
    P.add("Door", drips(gc - 3.0, gc + 2.0, gz0 + 2.6, -0.05, (1.8, 1.1, 2.4), 6))
    painted_door(P, 3.4, "#9fb7d6", z0=0.0)
    window(P, 8.6, 3.0, 4.0, 3.8, lit=True, shutter="#e7a3a8")
    P.add("Body", house_number(5.9, 6.6, "16"), floor_blot(gc + 1.5, -0.6, 0.0, 1.2, 11))
    back_frame(P, gx1 + 0.1, w / 2 - 0.1, h)
    back_frame(P, -w / 2 + 0.1, gx0 - 0.1, h)
    P.add("Body", box((gx1 - gx0 + 0.4, 0.5, 0.6), lumber(), loc=(gc, 0.63, gz1 + 0.5), r=0.0, n=1))
    braces(P, (-11.2, 0.4, 6.0, 11.2), h * 0.75, 4.6, seed=3)


@item("house_tiny", "warehouse", size=1024)
def house_tiny(P):
    """A house built a little too small: a 3 tall door, low windows, everything else perfectly normal."""
    w, h, apex, depth = 9.0, 5.5, 9.2, 4.0
    skin = stucco("#c6b4de")
    P.add("Body", skinned([(-w / 2, 0, 0), (w / 2, 0, 0), (w / 2, 0, h), (0, 0, apex), (-w / 2, 0, h)], skin, (0, -1, 0)))
    foundation(P, w)
    side_flats(P, w, depth, [(0.38, 0), (depth, 0), (depth, h), (0.38, h)], skin)
    ex, ay = w / 2 + 0.8, -0.9
    k = (apex - h) / (w / 2)
    az = apex + 0.3
    for sx in (-1, 1):
        P.add("Body", roof([(0, ay, az), (sx * ex, ay, az - ex * k), (sx * ex, depth, az - ex * k), (0, depth, az)], "#6c5a74"))
    t = trim()
    for sx in (-1, 1):
        a, b = V((0, ay - 0.12, az - 0.2)), V((sx * ex, ay - 0.12, az - ex * k - 0.2))
        rake = box(((b - a).length + 0.2, 0.25, 0.45), t, r=0.0, n=1)
        move(rake, rot=(0, -math.degrees(math.atan2(b.z - a.z, b.x - a.x)), 0), loc=(a + b) / 2)
        P.add("Body", rake, box((0.35, 0.25, h), t, loc=(sx * (w / 2 - 0.18), -0.1, h / 2), r=0.0, n=1))
    real_door(P, 0.0, "#e8a0a8", w=1.6, h=3.0)
    window(P, -2.9, 1.9, 1.4, 1.5, lit=True, curtain="#f6e3cf")
    window(P, 2.9, 1.9, 1.4, 1.5, picture=True)
    # round attic window, painted shut
    P.add("Body", cyl(0.6, 0.2, t, loc=(0, -0.08, 6.8), rot=(90, 0, 0), seg=16, bevel=0.02),
          cyl(0.45, 0.06, dark_glass(), loc=(0, -0.2, 6.8), rot=(90, 0, 0), seg=16, bevel=0.0))
    step(P, 0.0, 2.4, 1.0, 0.3)
    P.add("Body", house_number(1.6, 3.6, "18"), floor_blot(-0.4, -0.6, 0.3, 0.3, 13), wall_blot(-1.2, 1.2, -0.03, 0.3, 14))
    back_frame(P, -w / 2 + 0.1, w / 2 - 0.1, h)
    braces(P, (-2.6, 2.6), h * 0.72, 2.8, seed=4)


# ---------------------------------------------------------------- street pieces
def dashes(xs, y, z, length, width, color):
    return [box((length, width, 0.01), worn_line(color), loc=(x, y, z + 0.005), r=0.0, n=1) for x in xs]


def sealed_cracks(seed, n, z, span=13.0):
    """Black tar crack sealant squiggles."""
    rnd = random.Random(seed)
    out = []
    for _ in range(n):
        x, y = rnd.uniform(-span, span), rnd.uniform(-span, span)
        a = rnd.uniform(0, 360)
        for _ in range(rnd.randint(3, 6)):
            ln = rnd.uniform(0.8, 2.2)
            a += rnd.uniform(-50, 50)
            dx, dy = math.cos(math.radians(a)) * ln, math.sin(math.radians(a)) * ln
            out.append(box((ln + 0.1, 0.16, 0.01), flat("#1d1d1f"), loc=(x + dx / 2, y + dy / 2, z + 0.004), rot=(0, 0, a), r=0.0, n=1))
            x, y = x + dx, y + dy
    return out


@item("street_tile", "warehouse", size=1024)
def street_tile(P):
    P.add("Body", box((32, 32, 0.2), asphalt(), loc=(0, 0, 0.1), r=0.0, n=1))
    P.add("Body", dashes((-12, -4, 4, 12), 0.0, 0.2, 4.0, 0.4, "#e6dfc8"))
    cover = metal("#4a4844", rust=0.5)
    P.add("Body", cyl(1.35, 0.06, cover, loc=(9.0, -8.0, 0.22), seg=20, bevel=0.02),
          cyl(1.1, 0.04, cover, loc=(9.0, -8.0, 0.26), seg=20, bevel=0.01))
    for i in range(-2, 3):
        P.add("Body", box((1.8 - abs(i) * 0.35, 0.12, 0.03), cover, loc=(9.0, -8.0 + i * 0.36, 0.29), r=0.0, n=1))
    P.add("Body", sealed_cracks(21, 3, 0.2), floor_blot(-6.0, 6.0, 0.2, 1.6, 22), floor_blot(-4.6, 7.2, 0.2, 0.6, 23))


def sidewalk_slabs(P, y0, y1, z_top, seed, oil_at=None):
    """Concrete flags 4 long with saw joints between them, one oil spot."""
    rnd = random.Random(seed)
    for i in range(8):
        x = -14 + i * 4
        P.add("Body", box((3.92, y1 - y0, z_top), concrete(), loc=(x, (y0 + y1) / 2, z_top / 2), r=0.0, n=1))
    P.add("Body", box((32, y1 - y0 - 0.2, z_top - 0.08), plain("#6f6a62", grime=0.3), loc=(0, (y0 + y1) / 2, (z_top - 0.08) / 2), r=0.0, n=1))
    if oil_at is not None:
        P.add("Body", floor_blot(oil_at, (y0 + y1) / 2 + rnd.uniform(-0.8, 0.8), z_top, 0.7, seed + 1))


@item("street_curb", "warehouse", size=1024)
def street_curb(P):
    """32 long: curb on the street side (-y), 5 wide sidewalk behind it. Curb face meets the road at y = -3."""
    P.add("Body", box((32, 1.0, 0.7), concrete(), loc=(0, -2.5, 0.35), r=0.0, n=1))
    sidewalk_slabs(P, -2.0, 3.0, 0.7, 31, oil_at=6.0)


@item("sidewalk", "warehouse", size=1024)
def sidewalk(P):
    sidewalk_slabs(P, -2.5, 2.5, 0.7, 41, oil_at=-10.0)


@item("driveway", "warehouse", size=1024)
def driveway(P):
    """16 wide, 32 long along y; a 2 long apron at -y ramps from road level (0.2) up to 0.7."""
    c = concrete()
    for j in range(4):
        y = -14 + 3.75 + j * 7.5
        for sx in (-1, 1):
            P.add("Body", box((7.94, 7.44, 0.7), c, loc=(sx * 4, y, 0.35), r=0.0, n=1))
    P.add("Body", box((16, 30, 0.6), plain("#6f6a62", grime=0.3), loc=(0, 1.0, 0.3), r=0.0, n=1))
    P.add("Body", slab([(-16, 0), (-14, 0), (-14, 0.7), (-16, 0.2)], 16, c, rot=(0, 0, 90)))
    P.add("Body", floor_blot(1.0, 4.0, 0.7, 1.8, 51), floor_blot(-1.4, 3.0, 0.7, 0.7, 52), floor_blot(2.0, 11.0, 0.7, 0.9, 53))


@item("culdesac_end", "warehouse", size=1024)
def culdesac_end(P):
    """Quarter of the round turnaround: radius 32 around the corner at (-16, -16), curb on the arc inside the tile.
    Four make a 64 wide circle. Asphalt top sits at 0.22, a hair above street_tile, so it can overlap the last
    street tile where the bulb meets the road without flickering."""
    cx, cy, n = -16.0, -16.0, 24
    arc = lambda r: [(cx + r * math.cos(math.pi / 2 * i / n), cy + r * math.sin(math.pi / 2 * i / n)) for i in range(n + 1)]
    road = [(cx, cy)] + arc(31.0)
    P.add("Body", plate([(x, y, 0.22) for x, y in road], 0.22, asphalt()))
    inner, outer = arc(31.0), arc(32.0)
    c = concrete()
    for i in range(n):
        P.add("Body", plate([(*inner[i], 0.7), (*inner[i + 1], 0.7), (*outer[i + 1], 0.7), (*outer[i], 0.7)], 0.7, c))
    P.add("Body", sealed_cracks(61, 2, 0.22, span=6.0), floor_blot(-8.0, -6.0, 0.22, 2.2, 62), floor_blot(-5.5, -4.4, 0.22, 0.8, 63))


@item("turf_tile", "warehouse", size=1024)
def turf_tile(P):
    """Lawn: a 32 square of too-green fake turf laid in 8 wide rolls on a raised base, top flush with the sidewalk
    (0.7). Roll seams show, one corner has lifted, a black oil smear where something dragged across it."""
    base = plain("#5d5a54", grime=0.3)
    P.add("Body", box((32, 32, 0.6), base, loc=(0, 0, 0.3), r=0.0, n=1))
    for i in range(4):
        green = cloth(("#5fae4a", "#58a646", "#62b04c", "#5aa948")[i], dirt=0.25, weave=200, dirtcolor="#3e4a30")
        P.add("Body", box((7.9, 32, 0.1), green, loc=(-12 + i * 8, 0, 0.65), r=0.0, n=1))
    flap = cloth("#5aa948", dirt=0.35, weave=200, dirtcolor="#3e4a30")
    P.add("Body", plate([(13.0, -16.0, 0.72), (16.0, -16.0, 1.3), (16.0, -12.6, 0.72)], 0.08, flap))
    P.add("Body", floor_blot(-5.0, 4.0, 0.7, 1.4, 91), floor_blot(-3.6, 5.6, 0.7, 0.6, 92))


# ---------------------------------------------------------------- props
@item("streetlamp", "warehouse")
def streetlamp(P):
    """Suburban post lantern: square post, flat-capped lantern head, warm glass."""
    post = paint("#4f5d58", chip=0.2, grime=0.5, streaks=0.5)
    P.add("Body", box((1.4, 1.4, 0.9), post, loc=(0, 0, 0.45), r=0.05, n=1),
          box((1.0, 1.0, 0.4), post, loc=(0, 0, 1.1), r=0.04, n=1),
          box((0.45, 0.45, 9.0), post, loc=(0, 0, 5.8), r=0.03, n=1),
          box((0.9, 0.9, 0.3), post, loc=(0, 0, 10.35), r=0.03, n=1))
    for sx in (-1, 1):
        for sy in (-1, 1):
            P.add("Body", bar((sx * 0.42, sy * 0.42, 10.5), (sx * 0.62, sy * 0.62, 12.3), 0.1, post))
    P.add("Body", box((1.8, 1.8, 0.18), post, loc=(0, 0, 12.4), r=0.02, n=1),
          box((0.7, 0.7, 0.25), post, loc=(0, 0, 13.0), r=0.02, n=1))
    for sy in (-1, 1):
        P.add("Body", plate([(-0.85, sy * 0.85, 12.3), (0.85, sy * 0.85, 12.3), (0.3, sy * 0.3, 13.1), (-0.3, sy * 0.3, 13.1)], 0.08, post,
                            out=(0, sy, 1)))
        P.add("Body", plate([(sy * 0.85, -0.85, 12.3), (sy * 0.85, 0.85, 12.3), (sy * 0.3, 0.3, 13.1), (sy * 0.3, -0.3, 13.1)], 0.08, post,
                            out=(sy, 0, 1)))
    P.add("Glow", lathe([(0.0, 10.5), (0.56, 10.5), (0.82, 12.3), (0.0, 12.3)], warm(), rot=(0, 0, 45), seg=4, smooth=10))
    P.add("Body", floor_blot(0.6, -0.9, 0.0, 0.5, 71))


@item("mailbox", "warehouse")
def mailbox(P):
    """Mailbox shaped like a tiny house with a pitched roof, on a square post with a base plate. No slot, no door seam:
    nothing can go in. Price tag still on the post."""
    post = paint("#efeae0", chip=0.2, grime=0.5)
    P.add("Body", box((0.4, 0.4, 3.0), post, loc=(0, 0, 1.5), r=0.03, n=1),
          box((0.5, 1.9, 0.18), post, loc=(0, 0, 3.09), r=0.02, n=1),
          bar((0, 0.1, 2.4), (0, 0.7, 3.0), 0.16, post))
    P.add("Body", box((1.0, 1.0, 0.12), post, loc=(0, 0, 0.06), r=0.0, n=1))
    arch = [(-0.5, 0.0), (0.5, 0.0), (0.5, 0.6), (0.0, 1.0), (-0.5, 0.6)]
    body = slab(arch, 1.8, paint("#9cc9dc", chip=0.1, grime=0.35, streaks=0.3), bevel=0.0)
    move(body, loc=(0, 0, 3.18))
    P.add("Body", body)
    red = paint("#d0473c", chip=0.2, grime=0.3)
    P.add("Body", box((0.05, 0.12, 0.9), red, loc=(0.45, 0.35, 3.6), r=0.0, n=1),
          box((0.05, 0.55, 0.35), red, loc=(0.45, 0.58, 3.95), r=0.0, n=1),
          box((0.06, 0.14, 0.14), metal("#8a8780"), loc=(0.44, 0.35, 3.55), r=0.0, n=1))
    P.add("Body", tag(0.0, 1.9, -0.2, "4"))


@item("hedge", "warehouse")
def hedge(P):
    """Plastic hedge, cut too perfectly square, panel seams showing, sitting on a hidden tray."""
    green = leaf("#5f9a52")
    P.add("Body", box((6.0, 2.0, 3.0), green, loc=(0, 0, 1.6), r=0.12, n=1),
          box((5.8, 1.8, 0.2), plain("#3d3f3a", grime=0.4), loc=(0, 0, 0.1), r=0.0, n=1))


@item("fake_tree", "warehouse", size=1024)
def fake_tree(P):
    """Lollipop tree: faceted plastic canopy cut flat underneath, boxy trunk, bolted base plate."""
    bark = plain("#7a5a40", grime=0.4, vary=0.3)
    P.add("Body", box((2.2, 2.2, 0.16), metal("#6a6a66", rust=0.4), loc=(0, 0, 0.08), r=0.02, n=1),
          box((0.9, 0.9, 7.1), bark, loc=(0, 0, 3.65), r=0.02, n=1))
    for sx in (-1, 1):
        for sy in (-1, 1):
            P.add("Body", box((0.18, 0.18, 0.1), metal("#5a5a56"), loc=(sx * 0.85, sy * 0.85, 0.2), r=0.0, n=1))
    green = plain("#7fbf6a", grime=0.2, vary=0.3)
    lumps = [(0, 0, 9.2, 3.6), (-2.0, 0.6, 8.6, 2.4), (2.1, -0.4, 8.8, 2.5), (0.3, 1.8, 9.0, 2.3), (-0.4, -1.8, 8.9, 2.3), (0.2, 0.2, 10.9, 2.2)]
    for x, y, z, r in lumps:
        o = ball((r, r, r * 0.9), green, loc=(x, y, z), seg=8, rings=6)
        kit.warp(o, lambda c: V((c.x, c.y, max(c.z, 6.9))))
        o.data.set_sharp_from_angle(angle=math.radians(15))
        P.add("Body", o)


@item("lawn_flamingo", "warehouse")
def lawn_flamingo(P):
    """Flat painted plywood flamingo cut-out on two steel stakes: a lawn ornament that is obviously a prop."""
    pink = paint("#ea8fa8", chip=0.35, under="#c9b08a", grime=0.35, streaks=0.3)
    t = 0.1
    body = [(math.cos(math.radians(a)) * 0.78 + 0.05, math.sin(math.radians(a)) * 0.4 + 2.0) for a in range(0, 360, 24)]
    P.add("Body", slab(body, t, pink), slab([(0.6, 2.15), (1.05, 2.3), (0.75, 1.95)], t, pink))
    neck = [(-0.5, 2.1), (-0.78, 2.6), (-0.58, 3.0), (-0.38, 3.3), (-0.6, 3.52)]
    for (x0, z0), (x1, z1) in zip(neck, neck[1:]):
        w = 0.13
        P.add("Body", slab([(x0 - w, z0), (x0 + w, z0), (x1 + w, z1 + 0.03), (x1 - w, z1 + 0.03)], t, pink))
    head = [(math.cos(math.radians(a)) * 0.22 - 0.66, math.sin(math.radians(a)) * 0.17 + 3.6) for a in range(0, 360, 30)]
    P.add("Body", slab(head, t, pink),
          slab([(-0.82, 3.66), (-0.84, 3.5), (-1.12, 3.36)], t, plain("#f2e6d0", grime=0.2)),
          box((0.06, t + 0.02, 0.06), flat("#1b1a1c"), loc=(-0.7, 0, 3.64), r=0.0, n=1))
    leg = metal("#8a8780", rust=0.4)
    for x in (-0.12, 0.18):
        P.add("Body", box((0.1, 0.05, 1.9), leg, loc=(x, 0.08, 0.95), r=0.0, n=1))


@item("tricycle", "warehouse")
def tricycle(P):
    """Kid's tricycle left out, paint faded and chipped."""
    red = paint("#c45e55", chip=0.5, under="#6a5a52", grime=0.55, streaks=0.4)
    tyre = plain("#2a2827", grime=0.3)
    hub = plain("#e7e1d4", grime=0.4)
    fy, fz, fr = -0.9, 0.6, 0.6
    P.add("Body", cyl(fr, 0.2, tyre, loc=(0, fy, fz), rot=(0, 90, 0), seg=16, bevel=0.05),
          cyl(fr * 0.55, 0.24, hub, loc=(0, fy, fz), rot=(0, 90, 0), seg=12, bevel=0.02))
    for sx in (-1, 1):
        P.add("Body", cyl(0.34, 0.16, tyre, loc=(sx * 0.7, 0.75, 0.34), rot=(0, 90, 0), seg=14, bevel=0.04),
              cyl(0.18, 0.2, hub, loc=(sx * 0.7, 0.75, 0.34), rot=(0, 90, 0), seg=10, bevel=0.02),
              bar((sx * 0.14, fy, fz), (sx * 0.1, fy + 0.25, 1.45), 0.09, red),
              box((0.08, 0.3, 0.08), plain("#2a2827"), loc=(sx * 0.3, fy, fz), r=0.0, n=1),
              box((0.22, 0.14, 0.32), plain("#2a2827"), loc=(sx * 0.42, fy, fz), r=0.02, n=1))
    P.add("Body", bar((0, fy + 0.25, 1.45), (0, fy + 0.25, 1.75), 0.12, red),
          box((1.1, 0.1, 0.1), red, loc=(0, fy + 0.3, 1.78), r=0.0, n=1),
          bar((0, fy + 0.3, 1.3), (0, 0.7, 0.4), 0.14, red),
          box((1.5, 0.14, 0.14), red, loc=(0, 0.75, 0.34), r=0.0, n=1),
          box((1.1, 0.5, 0.08), red, loc=(0, 0.95, 0.5), r=0.0, n=1),
          bar((0, 0.15, 0.75), (0, 0.15, 1.05), 0.12, red),
          box((0.55, 0.6, 0.16), plain("#f2e2c4", grime=0.5), loc=(0, 0.12, 1.12), r=0.06, n=1))
    for sx in (-1, 1):
        P.add("Body", box((0.3, 0.18, 0.18), plain("#e7e1d4", grime=0.4), loc=(sx * 0.62, fy + 0.3, 1.78), r=0.04, n=1))


@item("welcome_mat", "warehouse")
def welcome_mat(P):
    coir = cloth("#b28d58", dirt=0.5, weave=120)
    P.add("Body", box((3.2, 2.0, 0.1), coir, loc=(0, 0, 0.05), r=0.02, n=1),
          box((2.8, 1.6, 0.012), cloth("#8a6a3e", dirt=0.3, weave=120), loc=(0, 0, 0.106), r=0.0, n=1),
          box((2.6, 1.4, 0.014), coir, loc=(0, 0, 0.108), r=0.0, n=1))
    P.add("Body", words("HOME", 0.75, flat("#3e2c1c"), loc=(0, 0, 0.12), rot=(-90, 0, 0), depth=0.02))
    P.add("Body", floor_blot(1.0, -0.5, 0.115, 0.25, 81))


@item("garden_sprinkler", "warehouse", pivots={"Spin": (0, 0, 0.55)})
def garden_sprinkler(P):
    """Rotary sprinkler: weighted base, hose stub out the back, three-arm head that spins."""
    green = plain("#4f9a6a", grime=0.4, vary=0.3)
    yellow = plain("#e6c14e", grime=0.4, vary=0.3)
    P.add("Body", slab([(math.cos(math.radians(30 + 60 * i)) * 0.6, math.sin(math.radians(30 + 60 * i)) * 0.6) for i in range(6)], 0.12, green,
                       loc=(0, 0, 0.06), rot=(90, 0, 0)),
          cyl(0.16, 0.42, yellow, loc=(0, 0, 0.31), seg=6, bevel=0.02),
          cyl(0.1, 0.5, yellow, loc=(0, 0.55, 0.12), rot=(90, 0, 0), seg=6, bevel=0.02),
          box((0.3, 0.2, 0.2), green, loc=(0, 0.85, 0.12), r=0.0, n=1))
    for i in range(3):
        a = 90 + 120 * i
        arm = box((0.62, 0.14, 0.06), green, loc=(0.38, 0, 0), r=0.0, n=1)
        tip = box((0.12, 0.12, 0.16), yellow, loc=(0.7, 0, 0.04), rot=(0, -25, 0), r=0.0, n=1)
        P.add("Spin", move([arm, tip], rot=(0, 0, a), loc=(0, 0, 0.55)))
    P.add("Spin", cyl(0.14, 0.12, yellow, loc=(0, 0, 0.58), seg=6, bevel=0.02))


@item("porch_light", "warehouse", pivots={"Body": (0, 0, 0), "Glow": (0, 0, 0)})
def porch_light(P):
    """Wall lantern. Origin at the back-centre of the wall plate."""
    b = paint("#2f3134", chip=0.2, grime=0.4, streaks=0.3)
    P.add("Body", box((0.5, 0.08, 1.0), b, loc=(0, -0.04, 0), r=0.02, n=1),
          box((0.14, 0.4, 0.14), b, loc=(0, -0.28, 0.0), r=0.0, n=1),
          box((0.62, 0.62, 0.1), b, loc=(0, -0.75, -0.4), r=0.0, n=1),
          plate([(-0.42, -1.17, 0.42), (0.42, -1.17, 0.42), (0.42, -0.33, 0.42), (-0.42, -0.33, 0.42)], 0.06, b),
          box((0.2, 0.2, 0.18), b, loc=(0, -0.75, 0.52), r=0.0, n=1))
    for sx in (-1, 1):
        for sy in (-1, 1):
            P.add("Body", box((0.06, 0.06, 0.76), b, loc=(sx * 0.27, -0.75 + sy * 0.27, 0.0), r=0.0, n=1))
    P.add("Glow", box((0.5, 0.5, 0.74), warm(), loc=(0, -0.75, 0.0), r=0.0, n=1))


@item("sun_panel", "warehouse", size=1024)
def sun_panel(P):
    """The fake sun: a 32 square ceiling panel glowing downward, in a dusty frame. Origin at the bottom of the frame."""
    frame = paint("#d8d3c8", chip=0.1, under="#8a8478", grime=0.7, streaks=0.8)
    housing = metal("#6a6c6e", rust=0.3)
    for sx in (-1, 1):
        P.add("Body", box((32, 1.2, 0.6), frame, loc=(0, sx * 15.4, 0.3), r=0.0, n=1),
              box((1.2, 29.6, 0.6), frame, loc=(sx * 15.4, 0, 0.3), r=0.0, n=1))
    P.add("Body", box((31.6, 31.6, 1.0), housing, loc=(0, 0, 1.1), r=0.0, n=1),
          box((3.0, 2.0, 0.8), housing, loc=(6.0, -4.0, 2.0), r=0.0, n=1))
    for sx in (-1, 1):
        for sy in (-1, 1):
            P.add("Body", box((0.8, 0.8, 0.5), housing, loc=(sx * 13.0, sy * 13.0, 1.85), r=0.0, n=1))
    P.add("Glow", box((29.6, 29.6, 0.1), glow("#fff3da", core="#ffffff", amount=0.12), loc=(0, 0, 0.35), r=0.0, n=1))
    # dead bugs and dust caught along the inside lip
    rnd = random.Random(91)
    for _ in range(14):
        side = rnd.choice((-1, 1))
        along = rnd.uniform(-13, 13)
        x, y = (along, side * 14.3) if rnd.random() < 0.5 else (side * 14.3, along)
        P.add("Body", box((0.25, 0.18, 0.02), flat("#2a2622"), loc=(x, y, 0.29), rot=(0, 0, rnd.uniform(0, 90)), r=0.0, n=1))


main()
