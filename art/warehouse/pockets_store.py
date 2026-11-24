"""Store, mall and office pockets: lit sets for the installations, the pitch-dark halls inside the warehouse.
A dead mall concourse, a kids' party room, a yellowed office, a basement stair that goes nowhere, a library desk.
Everything a little too clean, too big or slightly off; rust, dust and black oil from robot hands.
Run from art: _kit/run.sh warehouse/pockets_store.py <name> ...

Walls are 16 x 1 x 16 on the wall line (y -0.5 to 0.5), front faces -y. Floor tiles are 32 x 32 with the top at 0.05.
stairs_down has its origin at the bottom of its shaft like floor_hatch (see its docstring).
"""
import math, os, random, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "furniture"))
from common import *  # noqa
import bmesh
import kit
from mathutils import Matrix, Vector as V

OIL = "#0b0a0a"
TAU = 2 * math.pi


# ---------------------------------------------------------------- material helpers (made per item: each build wipes the scene)
def _pos(g):
    s = g.n("ShaderNodeSeparateXYZ")
    g.t.links.new(g.geo.outputs["Position"], s.inputs[0])
    return s.outputs


def _normal(g):
    s = g.n("ShaderNodeSeparateXYZ")
    g.t.links.new(g.geo.outputs["Normal"], s.inputs[0])
    return s.outputs


def _local(g):
    s = g.n("ShaderNodeSeparateXYZ")
    g.t.links.new(g.lp, s.inputs[0])
    return s.outputs


def _lines(g, v, period, width):
    return g.math("LESS_THAN", g.math("FRACT", g.math("DIVIDE", v, period)), width / period)


def _band(g, v, period, width, off=0.0):
    """1 within width/2 of every multiple of period (after the offset)."""
    t = g.math("FLOORED_MODULO", g.math("ADD", v, off), period)
    return g.math("LESS_THAN", g.math("MINIMUM", t, g.math("SUBTRACT", period, t)), width / 2)


def _wave(g, v, wavelength, amp, phase=0.0):
    return g.math("MULTIPLY", g.math("SINE", g.math("ADD", g.math("MULTIPLY", v, TAU / wavelength), phase)), amp)


def _cell(g, v, period, off):
    """Position inside a repeating cell, centred on 0."""
    return g.math("SUBTRACT", g.math("FLOORED_MODULO", g.math("ADD", v, off), period), period / 2)


def _dist(g, x, y, cx, cy):
    dx, dy = g.math("SUBTRACT", x, cx), g.math("SUBTRACT", y, cy)
    return g.math("SQRT", g.math("ADD", g.math("MULTIPLY", dx, dx), g.math("MULTIPLY", dy, dy)))


def _mul(g, *v):
    out = v[0]
    for b in v[1:]:
        out = g.math("MULTIPLY", out, b)
    return out


def _inv(g, a):
    return g.math("SUBTRACT", 1.0, a)


def _patch(g, x, y, cx, cy, r, seed):
    """Wobbly round patch on a floor: returns (inside, tide ring just outside it)."""
    n = g.math("SUBTRACT", g.noise(0.6 + seed * 0.07, 4, world=True), 0.5)
    d = g.math("ADD", _dist(g, x, y, cx, cy), g.math("MULTIPLY", n, r * 0.9))
    inside = _inv(g, g.step(d, r * 0.8, r))
    ring = _mul(g, g.step(d, r * 0.85, r), _inv(g, g.step(d, r, r * 1.12)))
    return inside, ring


# ---------------------------------------------------------------- materials
def oil():
    return flat(OIL)


def floor_done(g, c, dust=0.3):
    """g.done with less settled dust: at full strength every flat-up floor bakes out grey."""
    kept, kit.DUST = kit.DUST, dust
    m = g.done(c, ao=0.8)
    kit.DUST = kept
    return m


@cached
def tile(color, grout, size):
    """Square tile with grout lines on every face, whatever way it faces."""
    g = kit.G("tile")
    n = _normal(g)
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(1.4, 4), 0.38, 0.72), 0.35), color, g.mix(0.5, color, "#fff4e0"))
    line = None
    for v, nv in zip(_pos(g), n):
        across = _inv(g, g.step(g.math("ABSOLUTE", nv), 0.5, 0.9))
        l = g.math("MULTIPLY", _band(g, v, size, 0.07, size * 0.5), across)
        line = l if line is None else g.math("MAXIMUM", line, l)
    c = g.mix(g.math("MULTIPLY", line, 0.85), c, grout)
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(2.0, 5, world=True), 0.5, 0.75), 0.4), c, "#6a5848", "MULTIPLY")
    return g.done(c, ao=0.85)


@cached
def leaf(color):
    """Moulded plastic leaves: speckled two-tone with the panel seams showing."""
    g = kit.G("leaf")
    x, y, z = _pos(g)
    c = g.mix(g.step(g.noise(9, 3), 0.42, 0.58), g.mix(0.45, color, "#1c3a20"), color)
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(14, 2), 0.66, 0.7), 0.6), c, g.mix(0.5, color, "#eaffd0"))
    seam = g.math("MAXIMUM", _lines(g, g.math("ADD", x, y), 2.0, 0.03), _lines(g, z, 2.0, 0.03))
    c = g.mix(g.math("MULTIPLY", seam, 0.55), c, "#1a2a18")
    return g.done(c, ao=0.8)


@cached
def dusty_glass():
    """Dark display glass with dust drifted up from the bottom of each pane."""
    g = kit.G("dglass")
    c = g.mix(g.step(g.noise(2, 3), 0.4, 0.7), "#262c34", "#353d46")
    d = g.step(g.math("ADD", g.math("MULTIPLY", _inv(g, g.g), 0.6), g.math("MULTIPLY", g.noise(3, 5), 0.6)), 0.55, 0.95)
    c = g.mix(g.math("MULTIPLY", d, 0.85), c, "#a29c8e")
    return g.done(c, ao=0.4)


@cached
def crate_plastic(color, half):
    """Milk crate wall: a row of dark slots and a hand hole near the top. half = half the wall length."""
    g = kit.G("crate")
    lx, ly, lz = _local(g)
    u = g.math("ADD", lx, ly)
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(2.5, 5), 0.35, 0.75), 0.25), color, g.mix(0.5, color, "#fff2dc"))
    slot = _mul(g, _inv(g, _band(g, u, 0.3, 0.12)), g.math("LESS_THAN", g.math("ABSOLUTE", u), half - 0.18),
                g.math("LESS_THAN", g.math("ABSOLUTE", g.math("ADD", lz, 0.08)), 0.3))
    grip = _mul(g, g.math("LESS_THAN", g.math("ABSOLUTE", u), 0.28), g.math("LESS_THAN", g.math("ABSOLUTE", g.math("SUBTRACT", lz, 0.38)), 0.07))
    c = g.mix(g.math("MAXIMUM", slot, grip), c, "#141218")
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(3.5, 6, world=True), 0.45, 0.75), 0.4), c, "#6a5646", "MULTIPLY")
    return g.done(c, ao=0.8)


@cached
def party_carpet():
    """Loud party-room carpet: neon squiggles, rings, triangles and dots on dark navy, faded, a worn path along x."""
    g = kit.G("carpetp")
    x, y, _ = _pos(g)
    c = g.mix(g.step(g.noise(40, 2), 0.4, 0.6), "#151a40", "#1e2654")
    diag, anti = g.math("SUBTRACT", x, y), g.math("ADD", x, y)
    for col, v, u, wl, amp, off, w in (("#d8418c", y, x, 4.0, 0.7, 0.0, 0.32),
                                        ("#2fc4d0", x, y, 4.0, 0.6, 4.0, 0.28),
                                        ("#ef8a2c", diag, anti, 16 / 3, 0.8, 2.0, 0.26)):
        c = g.mix(_band(g, g.math("ADD", v, _wave(g, u, wl, amp)), 8.0, w, off), c, col)
    fx, fy = _cell(g, x, 8.0, 2.0), _cell(g, y, 8.0, 6.0)
    d2 = g.math("ADD", g.math("MULTIPLY", fx, fx), g.math("MULTIPLY", fy, fy))
    c = g.mix(g.math("MULTIPLY", g.math("LESS_THAN", d2, 0.56), g.math("GREATER_THAN", d2, 0.25)), c, "#9ad63a")
    ex, ey = _cell(g, x, 8.0, 6.0), _cell(g, y, 8.0, 2.0)
    tri = g.math("MULTIPLY", g.math("GREATER_THAN", ey, -0.35),
                 g.math("LESS_THAN", g.math("ADD", g.math("MULTIPLY", g.math("ABSOLUTE", ex), 1.6), ey), 0.45))
    c = g.mix(tri, c, "#f2c63a")
    dx, dy = _cell(g, x, 4.0, 3.0), _cell(g, y, 4.0, 1.0)
    c = g.mix(g.math("LESS_THAN", g.math("ADD", g.math("MULTIPLY", dx, dx), g.math("MULTIPLY", dy, dy)), 0.02), c, "#efe6d6")
    c = g.mix(0.1, c, "#5a5c70")
    worn = _mul(g, _inv(g, g.step(g.math("ABSOLUTE", y), 2.5, 4.5)), g.step(g.noise(0.5, 4, world=True), 0.35, 0.6), 0.6)
    c = g.mix(worn, c, "#4a4e66")
    stain, ring = _patch(g, x, y, 7.0, -8.0, 2.4, 1)
    c = g.mix(g.math("MULTIPLY", stain, 0.6), c, "#3a2c22", "MULTIPLY")
    c = g.mix(g.math("MULTIPLY", ring, 0.5), c, "#4a3a2a")
    return floor_done(g, c)


@cached
def office_carpet():
    """Worn mustard-green office carpet: faint squiggle loops, seams, damp darker patches with tide lines."""
    g = kit.G("carpeto")
    x, y, _ = _pos(g)
    c = g.mix(g.step(g.noise(60, 2), 0.35, 0.65), "#6c6a33", "#8a8642")
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(0.15, 3, world=True), 0.35, 0.7), 0.4), c, "#9a9450")
    c = g.mix(g.math("MULTIPLY", _band(g, g.math("ADD", y, _wave(g, x, 2.0, 0.25)), 1.0, 0.12), 0.25), c, "#b0aa62")
    seam = g.math("MAXIMUM", _band(g, y, 16.0, 0.07), _band(g, x, 32.0, 0.07))
    c = g.mix(g.math("MULTIPLY", seam, 0.6), c, "#3e3c1e")
    for cx, cy, r, seed in ((-6.0, 5.0, 4.0, 1), (8.0, -6.0, 2.5, 2), (2.0, -10.0, 1.6, 3)):
        inside, ring = _patch(g, x, y, cx, cy, r, seed)
        c = g.mix(g.math("MULTIPLY", inside, 0.7), c, "#4a4c26")
        c = g.mix(g.math("MULTIPLY", ring, 0.4), c, "#5a5426")
    worn = _mul(g, _inv(g, g.step(g.math("ABSOLUTE", g.math("SUBTRACT", y, 8.0)), 1.5, 3.5)), g.step(g.noise(0.6, 4, world=True), 0.4, 0.65), 0.4)
    c = g.mix(worn, c, "#a8a26a")
    return floor_done(g, c)


@cached
def wallpaper():
    """Yellowed office wallpaper: faint vertical stripes, brown water stains bleeding down from the top, grime low."""
    g = kit.G("wallpaper")
    x, y, z = _pos(g)
    u = g.math("ADD", x, y)
    c = g.mix(g.step(g.noise(1.2, 4), 0.35, 0.7), "#cdbf80", "#dcd099")
    c = g.mix(g.math("MULTIPLY", _band(g, u, 1.2, 0.5), 0.12), c, "#e8dfae")
    c = g.mix(g.math("MULTIPLY", _band(g, u, 1.2, 0.04, 0.6), 0.3), c, "#a89c5e")
    v = g.math("ADD", g.noise(0.35, 4, (1, 1, 0.5), world=True), g.math("MULTIPLY", z, 0.03))
    stain = g.step(v, 0.95, 0.98)
    ring = g.math("MULTIPLY", g.step(v, 0.93, 0.95), _inv(g, g.step(v, 0.96, 0.99)))
    c = g.mix(g.math("MULTIPLY", stain, 0.25), c, "#b29660")
    c = g.mix(g.math("MULTIPLY", ring, 0.4), c, "#8a6c3a")
    drip = _mul(g, g.step(g.noise(3, 3, (1, 1, 0.06), world=True), 0.62, 0.72), g.step(z, 6.0, 12.0), 0.3)
    c = g.mix(drip, c, "#9a8550")
    c = g.mix(g.math("MULTIPLY", _inv(g, g.step(z, 0.6, 2.5)), 0.3), c, "#7a6a40", "MULTIPLY")
    return g.done(c, ao=0.8)


@cached
def basement_carpet():
    """Beige stair carpet, fuzz worn grey off the nosings."""
    g = kit.G("carpetb")
    c = g.mix(g.step(g.noise(50, 2), 0.35, 0.65), "#a89c86", "#bdb19a")
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(0.8, 4, world=True), 0.45, 0.7), 0.35), c, "#6e6656")
    e = g.math("MINIMUM", g.math("MULTIPLY", g.edge(0.08), 4.0), 1.0)
    c = g.mix(g.math("MULTIPLY", e, 0.5), c, "#5a5244")
    return g.done(c, ao=0.9)


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


def blk(size, mat, loc):
    """Sharp box, 12 triangles."""
    return box(size, mat, loc=loc, r=0.0, n=1)


def flat_blob(r, seed, n=9):
    rnd = random.Random(seed)
    return [(math.cos(TAU * i / n) * r * rnd.uniform(0.55, 1.0), math.sin(TAU * i / n) * r * rnd.uniform(0.55, 1.0)) for i in range(n)]


def wall_blot(x, z, y, r, seed, mat=None):
    """Smudge on a wall facing -y (black oil unless another material is given)."""
    return slab(flat_blob(r, seed), 0.01, mat or oil(), loc=(x, y - 0.005, z))


def floor_blot(x, y, z, r, seed):
    """Black oil stain lying on a floor at height z."""
    return slab(flat_blob(r, seed, 11), 0.01, oil(), loc=(x, y, z + 0.005), rot=(90, 0, 0))


def handprint(x, z, y, s=1.0, rot=0, back=False):
    """Black oil handprint with a smear, on a face at depth y (facing -y, or +y if back)."""
    out = [blk((0.34 * s, 0.008, 0.32 * s), oil(), (0, 0, 0)),
           blk((0.14 * s, 0.008, 0.22 * s), oil(), (0.03 * s, 0, -0.25 * s)),
           box((0.07 * s, 0.008, 0.2 * s), oil(), loc=(-0.22 * s, 0, 0.02 * s), rot=(0, 40, 0), r=0.0, n=1)]
    for dx, ln in ((-0.12, 0.24), (-0.04, 0.28), (0.04, 0.27), (0.12, 0.22)):
        out.append(blk((0.065 * s, 0.008, ln * s), oil(), (dx * s, 0, (0.16 + ln / 2) * s)))
    move(out, rot=(0, rot, 180 if back else 0))
    return move(out, loc=(x, y, z))


def drips(x0, x1, ztop, y, lengths, seed):
    rnd = random.Random(seed)
    return [blk((rnd.uniform(0.05, 0.1), 0.01, ln), oil(), (rnd.uniform(x0, x1), y - 0.005, ztop - ln / 2)) for ln in lengths]


def star(r, inner=0.45, points=5, turn=90.0):
    return [(math.cos(math.radians(turn + 180 * i / points)) * (r if i % 2 == 0 else r * inner),
             math.sin(math.radians(turn + 180 * i / points)) * (r if i % 2 == 0 else r * inner)) for i in range(points * 2)]


def fan_slab(poly, depth, mat, loc=(0, 0, 0), rot=(0, 0, 0)):
    """Like slab, for outlines that are star-shaped around (0, 0): fanned from the centre so the concave
    star points triangulate cleanly (a plain n-gon fill leaves dark slivers)."""
    bm = bmesh.new()
    for y, faces in ((-depth / 2, 1), (depth / 2, -1)):
        c = bm.verts.new((0, y, 0))
        ring = [bm.verts.new((x, y, z)) for x, z in poly]
        for i in range(len(ring)):
            tri = (c, ring[i], ring[(i + 1) % len(ring)])
            bm.faces.new(tri if faces > 0 else tri[::-1])
        if faces > 0:
            front = ring
        else:
            back = ring
    for i in range(len(poly)):
        j = (i + 1) % len(poly)
        bm.faces.new((front[i], back[i], back[j], front[j]))
    return kit._finish(bm, mat, loc, rot, smooth=30)


def floor_tile(P, mat):
    """32 x 32 floor with its top at 0.05."""
    P.add("Body", blk((32, 32, 0.05), mat, (0, 0, 0.025)))


def stair_profile(steps, rise, tread, y0, z0, down=False):
    """Saw-tooth top edge of a flight as (y, z) points from y0, climbing (or dropping) one step at a time."""
    pts = []
    for k in range(steps):
        z = z0 - (k + 1) * rise if down else z0 + (k + 1) * rise
        pts += [(y0 + k * tread, z), (y0 + (k + 1) * tread, z)]
    return pts


# ---------------------------------------------------------------- mall
@item("mall_shutter", "warehouse", size=1024, pivots={"Door": (0, 0, 11)})
def mall_shutter(P):
    """Storefront with the security grille rolled all the way down over dark glass. The sign band is blank: a row
    of cleaner patches and screw holes where the letters were pried off. A faded sale burst on the glass,
    an oily handprint on the grille's kick plate. The grille is the Door, origin at the top of the opening (11 up)."""
    pier = tile("#d9d2c2", "#7a7266", 1.0)
    for sx in (-1, 1):
        P.add("Body", blk((1.5, 1.0, 11.0), pier, (sx * 7.25, 0, 5.5)),
              blk((0.15, 0.5, 10.8), metal("#5a5c5c", rust=0.5), (sx * 6.42, -0.2, 5.5)))
    band = paint("#c9c2b0", chip=0.08, under="#8a8478", grime=0.6, streaks=0.7)
    P.add("Body", blk((16, 0.9, 5.0), plaster_mat(), (0, 0.05, 13.5)),
          blk((13.0, 0.5, 1.0), metal("#6a6c6a", rust=0.5), (0, -0.15, 11.5)),
          blk((14.6, 0.06, 2.8), band, (0, -0.42, 13.9)))
    # ghost of pulled-off letters: sun-faded paint everywhere except where each letter sat, plus its screw holes
    clean = plain("#d0cab9", grime=0.35, vary=0.2)
    hole = flat("#26221e")
    x = -5.6
    for w in (1.0, 0.9, 1.1, 0.5, 1.0, 1.2, 0.9, 1.0):
        P.add("Body", blk((w, 0.01, 1.6), clean, (x + w / 2, -0.455, 13.85)),
              blk((0.08, 0.012, 0.08), hole, (x + w * 0.3, -0.462, 14.3)),
              blk((0.08, 0.012, 0.08), hole, (x + w * 0.7, -0.462, 13.4)))
        x += w + 0.35
    P.add("Body", drips(-6.5, 6.5, 12.4, -0.4, (0.6, 1.1, 0.4), 3))
    # shop behind: dark glass on a low sill, a black room behind it
    P.add("Body", blk((12.7, 0.1, 9.9), plain("#262c3a", grime=0.15, vary=0.15, ao=0.5), (0, 0.25, 6.0)),
          blk((12.7, 0.4, 1.05), plain("#3a3834", grime=0.5), (0, 0.25, 0.525)),
          blk((12.7, 0.05, 10.9), flat("#0a0a0c", ao=0.0), (0, 0.47, 5.45)))
    P.add("Body", slab([(-1.6, -3.6), (-0.9, -3.6), (1.4, 3.6), (0.7, 3.6)], 0.01, plain("#4a5466", grime=0.1), loc=(2.5, 0.195, 6.5)))
    P.add("Body", fan_slab(star(1.0, 0.72, 10), 0.01, plain("#d98a4a", grime=0.7, vary=0.3), loc=(-3.4, 0.195, 6.4)),
          fan_slab(star(0.72, 0.72, 10), 0.012, plain("#e8c27a", grime=0.7, vary=0.3), loc=(-3.4, 0.188, 6.4)))
    grille = metal("#8a8c88", rust=0.5)
    W = 12.7
    for k in range(20):
        P.add("Door", blk((W, 0.1, 0.06), grille, (0, -0.15, 1.6 + k * 0.48)))
    for k in range(14):
        P.add("Door", blk((0.05, 0.08, 9.4), grille, (-W / 2 + 0.2 + k * (W - 0.4) / 13, -0.15, 6.25)))
    kick = metal("#6e706c", rust=0.6)
    P.add("Door", blk((W, 0.14, 1.3), kick, (0, -0.15, 0.95)),
          blk((W, 0.3, 0.3), metal("#4a4c4a", rust=0.6), (0, -0.15, 0.15)),
          box((0.6, 0.32, 0.4), metal("#2c2c2a", rust=0.3), loc=(3.2, -0.15, 0.4), r=0.04, n=1))
    P.add("Door", handprint(-2.4, 1.0, -0.225, s=1.1, rot=-12), handprint(-1.7, 0.8, -0.225, s=0.9, rot=8),
          drips(-2.8, -1.4, 0.6, -0.22, (0.25, 0.4), 5))


def plaster_mat():
    return plain("#cfc8b8", grime=0.5, vary=0.25)


@item("mall_planter", "warehouse", size=1024)
def mall_planter(P):
    """Raised quarry-tile planter, 8 x 8 x 2.5, with a dead plastic ficus: square trunk, faceted canopy too round and
    too even, dusty, a few fake leaves fallen on the soil, the ledge and the floor."""
    side = tile("#9a5e3e", "#4a3428", 0.8)
    for sx in (-1, 1):
        P.add("Body", blk((8.0, 0.6, 2.2), side, (0, sx * 3.7, 1.1)), blk((0.6, 6.8, 2.2), side, (sx * 3.7, 0, 1.1)))
    cap = tile("#cbbfa8", "#7a6e5c", 0.8)
    for sx in (-1, 1):
        P.add("Body", blk((8.0, 0.8, 0.3), cap, (0, sx * 3.6, 2.35)), blk((0.8, 6.4, 0.3), cap, (sx * 3.6, 0, 2.35)))
    P.add("Body", blk((6.4, 6.4, 0.1), plain("#2e2620", grime=0.5, vary=0.4), (0, 0, 2.05)))
    rnd = random.Random(7)
    for _ in range(9):
        P.add("Body", box((rnd.uniform(0.25, 0.5), rnd.uniform(0.25, 0.5), 0.12), plain("#8a8276", grime=0.4),
                          loc=(rnd.uniform(-2.8, 2.8), rnd.uniform(-2.8, 2.8), 2.12), rot=(0, 0, rnd.uniform(0, 90)), r=0.04, n=1))
    bark = plain("#6e5642", grime=0.4, vary=0.3)
    P.add("Body", blk((1.0, 1.0, 0.3), plain("#3a3430", grime=0.4), (0, 0, 2.25)),
          bar((0, 0, 2.2), (0.3, 0.2, 6.6), 0.45, bark),
          bar((0.12, 0.08, 4.0), (-1.3, 0.5, 5.9), 0.25, bark),
          bar((0.2, 0.13, 4.8), (1.5, -0.6, 6.4), 0.22, bark))
    for i, (x, y, z, r) in enumerate(((0.3, 0.2, 7.4, 1.8), (-1.4, 0.6, 6.6, 1.3), (1.6, -0.6, 6.9, 1.3), (0.1, 1.3, 6.8, 1.1),
                                      (0.5, -1.2, 7.0, 1.1), (0.2, 0.0, 8.6, 1.0))):
        o = ball((r, r, r * 0.85), leaf(("#76805a", "#6d7a52", "#80845c")[i % 3]), loc=(x, y, z), seg=7, rings=5)
        o.data.set_sharp_from_angle(angle=math.radians(10))
        P.add("Body", o)
    shape = [(0.0, -0.3), (0.13, -0.05), (0.08, 0.2), (0.0, 0.3), (-0.08, 0.2), (-0.13, -0.05)]
    spots = [(rnd.uniform(-2.8, 2.8), rnd.uniform(-2.8, 2.8), 2.18) for _ in range(6)]
    spots += [(rnd.choice((-3.6, 3.6)), rnd.uniform(-3, 3), 2.5) for _ in range(3)]
    spots += [(4.5 + rnd.uniform(0, 1.2), rnd.uniform(-3, 3), 0.0) for _ in range(3)] + [(rnd.uniform(-3, 3), -4.6 - rnd.uniform(0, 1), 0.0) for _ in range(3)]
    for x, y, z in spots:
        col = rnd.choice(("#7a8f56", "#8a8a52", "#9a8a5a"))
        P.add("Body", slab(shape, 0.03, leaf(col), loc=(x, y, z + 0.02), rot=(90, 0, rnd.uniform(0, 180))))
    P.add("Body", handprint(1.4, 1.2, -4.005, s=0.9, rot=15))


@item("mall_kiosk", "warehouse", size=1024)
def mall_kiosk(P):
    """Closed concourse kiosk: laminate counter, dusty glass cases on three sides with one pane gone (dust heaps and
    an empty riser inside), the roller cover pulled down over the front, a blank canopy band. Front faces -y."""
    lam = plain("#d2c4aa", grime=0.55, vary=0.25)
    teal = plain("#4f8a86", grime=0.5)
    P.add("Body", blk((9.6, 5.6, 0.4), plain("#2c2a28", grime=0.4), (0, 0, 0.2)),
          blk((10.0, 6.0, 2.8), lam, (0, 0, 1.8)),
          blk((10.2, 6.2, 0.16), plain("#3a3632", grime=0.4), (0, 0, 3.28)))
    for sy in (-1, 1):
        P.add("Body", blk((10.02, 0.02, 0.3), teal, (0, sy * 3.0, 2.75)))
    for sx in (-1, 1):
        P.add("Body", blk((0.02, 6.02, 0.3), teal, (sx * 5.0, 0, 2.75)))
    frame = metal("#9a9890", rust=0.3)
    glass = dusty_glass()
    zc, gh = 4.6, 2.5
    for sx in (-1, 1):
        P.add("Body", blk((0.08, 5.4, gh), glass, (sx * 4.85, 0.1, zc)))
    for x0, x1 in ((-4.8, -1.7), (1.7, 4.8)):
        P.add("Body", blk((x1 - x0, 0.08, gh), glass, ((x0 + x1) / 2, 2.85, zc)))
    for x in (-4.85, -1.7, 1.7, 4.85):
        P.add("Body", blk((0.12, 0.12, gh), frame, (x, 2.85, zc)))
    P.add("Body", blk((9.8, 5.9, 0.08), glass, (0, 0.05, 5.9)))
    # inside the case: an empty riser, dust heaps where stock used to sit, one shelf tag with nothing on it
    P.add("Body", blk((2.6, 1.4, 0.6), plain("#e6e0d4", grime=0.6), (0, 1.6, 3.66)),
          blk((1.6, 1.0, 0.5), plain("#e6e0d4", grime=0.6), (0, 1.8, 4.21)))
    rnd = random.Random(31)
    for _ in range(7):
        x, y = rnd.uniform(-4.2, 4.2), rnd.uniform(0.3, 2.4)
        P.add("Body", ball((rnd.uniform(0.25, 0.55), rnd.uniform(0.2, 0.4), 0.1), plain("#b5ad9e", grime=0.3), loc=(x, y, 3.38), seg=6, rings=3))
    P.add("Body", tag(0.0, 3.55, 0.88, "0"))
    for sx in (-1, 1):
        for sy in (-1, 1):
            P.add("Body", blk((0.3, 0.3, 4.05), frame, (sx * 4.95, sy * 2.95, 5.38)))
    P.add("Body", blk((10.4, 6.4, 0.6), lam, (0, 0, 7.7)),
          blk((10.42, 6.42, 0.3), plain("#e8e2d2", grime=0.5), (0, 0, 7.7)))
    cover = metal("#b0b0aa", rust=0.35)
    P.add("Body", blk((10.0, 0.6, 0.6), frame, (0, -2.75, 7.1)))
    for k in range(14):
        P.add("Body", blk((9.6, 0.08, 0.24), cover, (0, -2.95, 3.5 + k * 0.25)))
    P.add("Body", blk((9.7, 0.2, 0.2), metal("#6a6a66", rust=0.5), (0, -2.98, 3.45)),
          box((0.5, 0.12, 0.35), metal("#2c2c2a", rust=0.3), loc=(2.0, -3.06, 3.5), r=0.03, n=1),
          handprint(-1.5, 4.6, -3.0, s=1.0, rot=-20), drips(-2.0, -1.0, 4.2, -2.995, (0.5, 0.8), 32),
          floor_blot(-1.8, -3.8, 0.0, 0.6, 33))


# ---------------------------------------------------------------- party room
@item("carpet_party", "warehouse", size=1024)
def carpet_party(P):
    """Party-room carpet, 32 x 32, top at 0.05. Neon squiggles on navy, a worn path along x, a drink stain, oil."""
    floor_tile(P, party_carpet())
    P.add("Body", floor_blot(-9.0, 7.0, 0.05, 1.1, 41), floor_blot(-7.8, 8.2, 0.05, 0.4, 42))


@item("wall_party", "warehouse", size=1024)
def wall_party(P):
    """Party-room wall split corner to corner, faded blue over coral pink, stencilled stars (one peeling, one gone,
    leaving its clean outline), chair rail and baseboard on both faces."""
    pink = plain("#d86a7c", grime=0.45, vary=0.25)
    blue = plain("#2f4c9a", grime=0.45, vary=0.25)
    P.add("Body", blk((16, 0.96, 16), pink, (0, 0, 8)))
    for sy in (-1, 1):
        y = sy * 0.5
        P.add("Body", plate([(-8, y, 0), (8, y, 16), (-8, y, 16)], 0.02, blue, out=(0, sy, 0)),
              plate([(-8, y, 0), (8, y, 0), (8, y, 16)], 0.02, pink, out=(0, sy, 0)))
    rail = paint("#efe6d4", chip=0.2, under="#8a8070", grime=0.5, streaks=0.3)
    base = plain("#2a2a30", grime=0.4)
    for sy in (-1, 1):
        P.add("Body", blk((16, 0.2, 0.35), rail, (0, sy * 0.58, 3.2)), blk((16, 0.15, 0.6), base, (0, sy * 0.555, 0.3)))
    cols = ("#f2d36a", "#efe8da", "#e8803a", "#f2d36a", "#efe8da")
    for (x, z, r, tw), col in zip(((-5.2, 9.0, 1.1, 4), (-1.5, 13.0, 0.8, -10), (-6.2, 4.6, 0.6, 14), (2.6, 14.4, 0.7, 2), (5.2, 6.2, 0.9, -6)), cols):
        P.add("Body", fan_slab(star(r), 0.012, plain(col, grime=0.35, vary=0.2), loc=(x, -0.506, z), rot=(0, tw, 0)))
    # peeling star: four arms still stuck, one arm lifted off the wall
    x, z, r = -3.4, 6.2, 0.9
    pts = star(r)
    P.add("Body", fan_slab(pts[3:] + pts[:2], 0.012, plain("#efe8da", grime=0.35), loc=(x, -0.506, z)))
    a, b, tip = V((x + pts[1][0], -0.5, z + pts[1][1])), V((x + pts[3][0], -0.5, z + pts[3][1])), V((x + pts[2][0], -0.66, z + pts[2][1] - 0.1))
    P.add("Body", plate([a, tip, b], 0.012, plain("#efe8da", grime=0.35), out=(0, -1, 0)))
    # the clean paint the lifted arm used to cover
    P.add("Body", slab([pts[1], pts[2], pts[3]], 0.006, plain("#4a6cc0", grime=0.15, vary=0.1), loc=(x, -0.503, z)))
    P.add("Body", handprint(4.6, 2.2, -0.505, s=1.0, rot=-15), drips(4.2, 5.0, 1.9, -0.505, (0.5, 0.9), 43))


@item("crate_stack_plastic", "warehouse")
def crate_stack_plastic(P):
    """Bright plastic milk crates, dusty and faded, stacked four columns high and low, leaning a little."""
    w, d, h = 2.0, 1.5, 1.2
    colors = ("#c8382f", "#2f5fbf", "#e3b52a", "#3a9a4a", "#e0702a")
    rnd = random.Random(61)

    def crate(col, z):
        long, short = crate_plastic(col, w / 2), crate_plastic(col, d / 2)
        out = [blk((w, 0.1, h), long, (0, sy * (d / 2 - 0.05), z + h / 2)) for sy in (-1, 1)]
        out += [blk((0.1, d - 0.2, h), short, (sx * (w / 2 - 0.05), 0, z + h / 2)) for sx in (-1, 1)]
        out.append(blk((w - 0.2, d - 0.2, 0.1), plain(col, grime=0.5), (0, 0, z + 0.05)))
        return move(out, rot=(0, 0, rnd.uniform(-2.5, 2.5)))

    # every column leans toward +x, the right ones more, so neighbours never cut into each other
    for (cx, cy), n, lean in (((-1.0, -0.76), 5, (0, 2.0, 0)), ((1.0, -0.76), 3, (0, 3.0, 0)),
                              ((-1.0, 0.76), 4, (-1.5, 2.0, 0)), ((1.0, 0.76), 5, (-1.0, 3.0, 0))):
        column = []
        for k in range(n):
            column += crate(rnd.choice(colors), k * h)
        P.add("Body", move(column, rot=lean, loc=(cx, cy, 0)))
    P.add("Body", handprint(-1.2, 2.0, -1.53, s=0.8, rot=10))


# ---------------------------------------------------------------- office
@item("wall_office", "warehouse", size=1024)
def wall_office(P):
    """Yellowed striped office wallpaper with water stains bleeding down from the ceiling, a dead outlet with a
    scorch mark, a scuffed vinyl baseboard on both faces."""
    P.add("Body", blk((16, 1.0, 16), wallpaper(), (0, 0, 8)))
    base = paint("#5e5244", chip=0.3, under="#2a2420", grime=0.6, streaks=0.2)
    for sy in (-1, 1):
        P.add("Body", blk((16, 0.15, 0.7), base, (0, sy * 0.575, 0.35)))
    rnd = random.Random(71)
    for _ in range(9):
        x = rnd.uniform(-7.5, 7.5)
        P.add("Body", blk((rnd.uniform(0.3, 1.2), 0.01, rnd.uniform(0.05, 0.12)), flat("#2a2420"), (x, -0.655, rnd.uniform(0.15, 0.6))))
    plate_mat = plain("#e8e2d0", grime=0.6)
    P.add("Body", box((0.5, 0.06, 0.8), plate_mat, loc=(4.0, -0.53, 1.4), rot=(0, 6, 0), r=0.02, n=1),
          box((0.08, 0.02, 0.08), metal("#8a8478", rust=0.4), loc=(4.0, -0.565, 1.4), rot=(0, 6, 0), r=0.0, n=1),
          wall_blot(4.1, 2.2, -0.5, 0.45, 72, flat("#3a2e22")))
    P.add("Body", handprint(3.3, 2.6, -0.505, s=0.9, rot=20), drips(3.0, 3.6, 2.3, -0.505, (0.7, 0.4), 73))


@item("carpet_office", "warehouse", size=1024)
def carpet_office(P):
    """Mustard-green office carpet, 32 x 32, top at 0.05: seams, damp patches with tide lines, a trodden path."""
    floor_tile(P, office_carpet())


@item("stairs_to_wall", "warehouse", size=1024)
def stairs_to_wall(P):
    """Carpeted stairs to nowhere: 24 steps of 0.5 up and 1 deep, 4 wide, rising toward +y to 12 and stopping flat
    against a blank plaster panel. Wooden stringers, a square handrail and balusters on the +x side. Origin at the
    bottom centre of the whole piece; the first riser is at y = -12 before the shift."""
    steps, rise, tread, w = 24, 0.5, 1.0, 4.0
    run, top = steps * tread, steps * rise
    y0 = -run / 2
    prof = [(y0, 0.0)] + stair_profile(steps, rise, tread, y0, 0.0) + [(run / 2, top - 1.2), (y0 + 2.4, 0.0)]
    P.add("Body", slab(prof, w, basement_carpet(), rot=(0, 0, 90)))
    oak = wood("#9a6a3c", "#5a3a20", axis="x", wear=0.4)
    nose = lambda y: rise + (y - y0) * rise / tread
    string = [(y0, 0.0), (y0, nose(y0) + 0.4), (run / 2, nose(run / 2) + 0.4), (run / 2, top - 1.2), (y0 + 2.4, 0.0)]
    for sx in (-1, 1):
        P.add("Body", slab(string, 0.3, oak, loc=(sx * (w / 2 + 0.15), 0, 0), rot=(0, 0, 90)))
    rx, rh = w / 2 + 0.15, 3.0
    P.add("Body", blk((0.5, 0.5, nose(y0) + rh + 0.6), oak, (rx, y0 + 0.3, (nose(y0) + rh + 0.6) / 2)))
    for k in range(2, steps, 2):
        y = y0 + k * tread + 0.5
        P.add("Body", blk((0.16, 0.16, rh), oak, (rx, y, nose(y) + 0.4 + rh / 2)))
    P.add("Body", bar((rx, y0 + 0.3, nose(y0 + 0.3) + 0.4 + rh), (rx, run / 2, nose(run / 2) + 0.4 + rh), 0.3, oak))
    P.add("Body", blk((6.0, 1.0, top + 8.0), plaster_mat(), (0, run / 2 + 0.5, (top + 8.0) / 2)),
          handprint(-0.6, top + 3.6, run / 2, s=1.0, rot=-8), handprint(0.5, top + 3.2, run / 2, s=1.0, rot=12),
          drips(-1.0, 0.9, top + 3.0, run / 2, (0.8, 1.5, 0.5), 91))


@item("doorway_blue", "warehouse", size=1024)
def doorway_blue(P):
    """A lone door frame, 4.5 x 8.2, with no door: the opening is filled by a cold blue light plane (Glow) set 2 back,
    inside a short pale-lit reveal, so it reads as a lit blue room beyond. Blue spill on the floor in front."""
    jamb = paint("#a07850", chip=0.25, under="#5a4430", grime=0.5, streaks=0.4)
    for sx in (-1, 1):
        P.add("Body", box((0.4, 0.6, 7.8), jamb, loc=(sx * 2.05, 0, 3.9), r=0.04, n=1),
              box((0.7, 1.6, 0.12), jamb, loc=(sx * 2.05, -0.5, 0.06), r=0.02, n=1))
    P.add("Body", box((4.5, 0.6, 0.4), jamb, loc=(0, 0, 8.0), r=0.04, n=1))
    shell = plain("#24262a", grime=0.4)
    for sx in (-1, 1):
        P.add("Body", blk((0.4, 1.9, 7.8), shell, (sx * 2.05, 1.25, 3.9)))
    P.add("Body", blk((4.5, 1.9, 0.4), shell, (0, 1.25, 8.0)), blk((4.5, 0.2, 8.2), shell, (0, 2.3, 4.1)))
    lit = plain("#a9cdf2", grime=0.15, vary=0.15, ao=0.6)
    for sx in (-1, 1):
        P.add("Body", blk((0.02, 1.9, 7.8), lit, (sx * 1.84, 1.25, 3.9)))
    P.add("Body", blk((3.7, 1.9, 0.02), lit, (0, 1.25, 7.79)), blk((3.7, 1.9, 0.03), plain("#c6def6", grime=0.1, vary=0.1), (0, 1.25, 0.015)))
    P.add("Glow", blk((3.7, 0.05, 7.8), glow("#8fc4ff", core="#e8f6ff", amount=0.25), (0, 2.18, 3.9)))
    for k, (near, far, depth, col) in enumerate(((3.7, 5.6, 3.6, "#2e4466"), (3.6, 4.8, 2.4, "#45648e"), (3.5, 4.1, 1.2, "#6c90c2"))):
        P.add("Body", slab([(-near / 2, 0.3), (near / 2, 0.3), (far / 2, 0.3 + depth), (-far / 2, 0.3 + depth)], 0.004,
                           flat(col, ao=0.0), loc=(0, 0, 0.004 + k * 0.004), rot=(90, 0, 0)))
    P.add("Body", handprint(2.05, 4.2, -0.305, s=0.55, rot=8))


@item("reading_desk", "warehouse", size=1024)
def reading_desk(P):
    """Long library table, 12 x 4, with two green banker lamps on square stems (one lit, warm Glow bulb; one dead),
    an open book of blank pages with an oily thumb smudge, and a chair pushed back as if someone just got up."""
    oak = wood("#a8784a", "#5a3a20", axis="x", wear=0.4)
    P.add("Body", box((12.0, 4.0, 0.3), oak, loc=(0, 0, 2.65), r=0.04, n=1))
    for sx in (-1, 1):
        P.add("Body", blk((0.3, 3.4, 2.5), oak, (sx * 5.3, 0, 1.25)), blk((0.5, 3.6, 0.2), oak, (sx * 5.3, 0, 0.1)))
    P.add("Body", blk((10.3, 0.3, 0.5), oak, (0, 0, 0.9)), blk((11.4, 3.4, 0.25), oak, (0, 0, 2.38)))
    brass = metal("#a88a4a", rust=0.2)
    shade = plain("#2f6a45", grime=0.3, vary=0.2)
    for x, lit in ((-3.0, True), (3.0, False)):
        P.add("Body", blk((1.0, 0.6, 0.12), brass, (x, 0.4, 2.86)),
              blk((0.12, 0.12, 1.3), brass, (x, 0.4, 3.57)),
              blk((0.12, 0.6, 0.12), brass, (x, 0.15, 4.16)),
              slab([(-0.55, 0.0), (0.55, 0.0), (0.3, 0.42), (-0.3, 0.42)], 1.6, shade, loc=(x, -0.05, 4.1), rot=(0, 0, 90)),
              blk((0.03, 0.03, 0.45), brass, (x + 0.6, -0.3, 3.88)),
              blk((0.08, 0.08, 0.1), brass, (x + 0.6, -0.3, 3.62)))
        bulb = blk((1.3, 0.7, 0.06), glow("#ffc978", core="#fff0cf", amount=0.25) if lit else plain("#4a4844", grime=0.4), (x, -0.05, 4.08))
        P.add("Glow" if lit else "Body", bulb)
    page = plain("#efe8d6", grime=0.3, vary=0.15)
    P.add("Body", blk((1.6, 1.1, 0.05), plain("#5a2e2a", grime=0.4), (-2.6, -1.0, 2.825)))
    for sx in (-1, 1):
        P.add("Body", box((0.75, 1.0, 0.08), page, loc=(-2.6 + sx * 0.38, -1.0, 2.9), rot=(0, sx * -5, 0), r=0.0, n=1))
    P.add("Body", slab(flat_blob(0.08, 81), 0.004, oil(), loc=(-2.25, -1.2, 2.945), rot=(90, 0, 0)))
    chair = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            chair.append(blk((0.18, 0.18, 1.5), oak, (sx * 0.7, sy * 0.7, 0.75)))
        chair.append(blk((0.18, 0.18, 2.0), oak, (sx * 0.7, -0.7, 2.58)))
    chair.append(box((1.7, 1.7, 0.18), oak, loc=(0, 0, 1.59), r=0.03, n=1))
    for z in (2.3, 2.9, 3.45):
        chair.append(blk((1.3, 0.1, 0.22), oak, (0, -0.7, z)))
    P.add("Body", move(chair, rot=(0, 0, 14), loc=(-2.2, -3.6, 0)))
    P.add("Body", floor_blot(1.4, -2.8, 0.0, 0.5, 82))


@item("stairs_down", "warehouse", size=1024)
def stairs_down(P):
    """Steps going down into black: 20 steps of 0.5 down and 1 deep (10 in all), 4 wide, dropping toward +y to a
    landing that ends in a black wall. Tiled surround at floor level with a square guard rail, a square wall rail.
    The origin is the bottom of the shaft, like floor_hatch: put it 10 below the other floors so the surround top
    (10.2) lines up with their floor level (0.2)."""
    depth, top, w = 10.0, 10.2, 4.0
    steps, rise, tread = 20, 0.5, 1.0
    y0, y_end = -10.0, 12.0
    prof = [(y0, 0.0)] + stair_profile(steps, rise, tread, y0, top, down=True) + [(y_end, 0.2), (y_end, 0.0)]
    P.add("Body", slab(prof, w, fade("#050505", "#8a8478", lo=0.15, hi=0.85, grime=0.4), rot=(0, 0, 90)))
    wall = fade("#040404", "#9a9488", lo=0.2, hi=0.9, grime=0.4)
    for sx in (-1, 1):
        P.add("Body", blk((0.3, y_end - y0, depth), wall, (sx * (w / 2 + 0.15), (y0 + y_end) / 2, depth / 2)))
    P.add("Body", blk((w, 0.3, depth), wall, (0, y0 - 0.15, depth / 2)),
          blk((w, 0.3, depth), flat("#020202", ao=0.0), (0, y_end + 0.15, depth / 2)))
    surround = tile("#d8d0be", "#6a6256", 1.0)
    outer = w / 2 + 2.0
    for sx in (-1, 1):
        P.add("Body", blk((outer - w / 2, y_end - y0 + 4.0, 0.4), surround, (sx * (w / 2 + outer) / 2, (y0 + y_end) / 2, top - 0.2)))
    for y in (y0 - 1.0, y_end + 1.0):
        P.add("Body", blk((w, 2.0, 0.4), surround, (0, y, top - 0.2)))
    rail = metal("#7a7f80", rust=0.4)
    px = w / 2 + 0.6
    for sx in (-1, 1):
        for y in (y0 + 3.0, y0 + 10.0, y0 + 17.0, y_end + 0.6):
            P.add("Body", blk((0.25, 0.25, 3.2), rail, (sx * px, y, top + 1.6)))
        P.add("Body", blk((0.25, y_end + 0.6 - y0 - 3.0, 0.25), rail, (sx * px, (y0 + 3.0 + y_end + 0.6) / 2, top + 3.2)))
    P.add("Body", blk((2 * px, 0.25, 0.25), rail, (0, y_end + 0.6, top + 3.2)),
          blk((2 * px, 0.25, 0.25), rail, (0, y_end + 0.6, top + 1.6)))
    hx = -w / 2 + 0.25
    nose = lambda y: top - (y - y0) * rise / tread
    P.add("Body", bar((hx, y0 + 0.5, nose(y0 + 0.5) + 3.0), (hx, y0 + steps * tread, 3.0), 0.22, rail))
    for k in range(1, steps, 6):
        y = y0 + k * tread + 0.5
        P.add("Body", blk((0.3, 0.1, 0.4), rail, (hx - 0.18, y, nose(y) + 2.6)), blk((0.1, 0.25, 0.1), rail, (hx - 0.05, y, nose(y) + 2.85)))
    # a robot steadied itself on the shaft wall on the way down
    P.add("Body", move(handprint(0, 0, 0, s=0.9, rot=-20), rot=(0, 0, -90), loc=(w / 2 - 0.005, y0 + 4.0, 8.4)),
          floor_blot(3.0, y0 - 1.0, top, 0.6, 101), floor_blot(0.4, y0 + 0.5, top - rise, 0.4, 102))


main()
