"""Water and sky pockets: lit installations inside the dark warehouse where the robots copied pictures of pools,
skies and empty courtyards. Everything is a little too clean, too big or the wrong colour.
Run from art: _kit/run.sh warehouse/pockets_water.py <name> ...

finish() moves every origin to the bottom centre of the bounding box, so heights below are from that bottom:
- pool_floor: tile top 0.2, water top 2.2. pool_edge shares that origin height; its lip top is 3.1.
  Put both origins 2.9 below the floor level so the lip meets the floor (0.2) and the water sits 0.7 under it.
- sky_ceiling: the origin is the sky face (bottom). Hang it with the origin at ceiling height.
- grid_floor top at 0.7 like the sidewalk and turf_tile. sand_floor edges at 0.
"""
import math, os, random, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "furniture"))
from common import *  # noqa
import bmesh
import kit
from mathutils import Matrix, Vector as V, noise as mnoise

OIL = "#0b0a0a"
TILE = "#e9ebe6"
GROUT = "#a9aea8"
WATER_TOP = 2.2


# ---------------------------------------------------------------- shader helpers (world position, baked)
def _sep(g, sock):
    s = g.n("ShaderNodeSeparateXYZ")
    g.t.links.new(sock, s.inputs[0])
    return s.outputs[0], s.outputs[1], s.outputs[2]


def _pos(g):
    return _sep(g, g.geo.outputs["Position"])


def _wn(g, scale, detail=4, stretch=(1, 1, 1), seed=0):
    x = g.n("ShaderNodeTexNoise")
    x.inputs["Scale"].default_value = scale
    x.inputs["Detail"].default_value = detail
    m = g.n("ShaderNodeMapping")
    g.t.links.new(g.geo.outputs["Position"], m.inputs[0])
    m.inputs["Scale"].default_value = stretch
    m.inputs["Location"].default_value = (seed * 13.7, seed * 7.3, seed * 3.1)
    g.t.links.new(m.outputs[0], x.inputs["Vector"])
    return x.outputs[0]


def _blot(g, scale, lo, hi, detail=4, stretch=(1, 1, 1), seed=0):
    return g.step(_wn(g, scale, detail, stretch, seed), lo, hi)


def _mul(g, *v):
    out = v[0]
    for b in v[1:]:
        out = g.math("MULTIPLY", out, b)
    return out


def _inv(g, a):
    return g.math("SUBTRACT", 1.0, a)


def _band(g, v, period, width, offset=0.0):
    """1 on lines every period (soft edged), 0 between."""
    t = g.math("FLOORED_MODULO", g.math("ADD", v, offset), period)
    d = g.math("MINIMUM", t, g.math("SUBTRACT", period, t))
    return _inv(g, g.step(d, width * 0.35, width * 0.5))


def _cell(g, v, size):
    return g.math("FLOOR", g.math("DIVIDE", v, size))


def _is(g, v, k):
    return _inv(g, g.step(g.math("ABSOLUTE", g.math("SUBTRACT", v, k)), 0.3, 0.5))


def _rand(g, a, b, seed=0):
    c = g.n("ShaderNodeCombineXYZ")
    g.put(c.inputs[0], a)
    g.put(c.inputs[1], b)
    c.inputs[2].default_value = seed
    w = g.n("ShaderNodeTexWhiteNoise")
    w.noise_dimensions = "3D"
    g.t.links.new(c.outputs[0], w.inputs["Vector"])
    return w.outputs["Value"]


def _inner(g, half=16.0, margin=3.0):
    """1 in the middle of a floor tile, 0 at its edges, so stains never cross a seam."""
    x, y, _ = _pos(g)
    d = g.math("SUBTRACT", half, g.math("MAXIMUM", g.math("ABSOLUTE", x), g.math("ABSOLUTE", y)))
    return g.step(d, 0.4, margin)


def _rect(g, u, v, cu, cv, hu, hv):
    d = g.math("MAXIMUM", g.math("DIVIDE", g.math("ABSOLUTE", g.math("SUBTRACT", u, cu)), hu),
               g.math("DIVIDE", g.math("ABSOLUTE", g.math("SUBTRACT", v, cv)), hv))
    return _inv(g, g.step(d, 0.8, 1.0))


def _oil_hands(g, c, u, v, spots, seed=0):
    """Black oil prints of a robot hand (square palm, three flat fingers) on the plane (u, v).
    spots: [(cu, cv, angle_deg, size)]. Painted in the texture so no MeshPart carries a hand shape."""
    for k, (cu, cv, ang, s) in enumerate(spots):
        ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))
        du, dv = g.math("SUBTRACT", u, cu), g.math("SUBTRACT", v, cv)
        ru = g.math("ADD", _mul(g, du, ca), _mul(g, dv, sa))
        rv = g.math("SUBTRACT", _mul(g, dv, ca), _mul(g, du, sa))
        m = _rect(g, ru, rv, 0.0, 0.0, 0.3 * s, 0.28 * s)
        for fx in (-0.2, 0.0, 0.2):
            m = g.math("MAXIMUM", m, _rect(g, ru, rv, fx * s, 0.52 * s, 0.075 * s, 0.24 * s))
        smear = g.math("ADD", 0.35, _mul(g, _blot(g, 3.0, 0.3, 0.6, 3, seed=seed + k), 0.65))
        c = g.mix(_mul(g, m, smear), c, OIL)
    return c


def _grout(g, pitch, width):
    """Grout lines on every face of a box: each face only uses the two axes that run across it."""
    x, y, z = _pos(g)
    nx, ny, nz = _sep(g, g.geo.outputs["Normal"])
    lines = None
    for v, n in ((x, nx), (y, ny), (z, nz)):
        b = _mul(g, _band(g, v, pitch, width), _inv(g, g.step(g.math("ABSOLUTE", n), 0.5, 0.9)))
        lines = b if lines is None else g.math("MAXIMUM", lines, b)
    return lines


# ---------------------------------------------------------------- materials (made per item: each build wipes the scene)
@cached
def tile(color=TILE, grout=GROUT, pitch=0.5, seed=0, hands=(), waterline=None, low=0.0):
    """Small square glazed tile, faintly uneven, grubby grout. waterline = height of a scum line."""
    g = kit.G("tile")
    x, y, z = _pos(g)
    cell = g.math("ADD", _cell(g, x, pitch), _mul(g, _cell(g, z, pitch), 131.0))
    c = g.mix(_mul(g, _rand(g, cell, _cell(g, y, pitch), seed), 0.18), color, g.mix(0.5, color, "#b7b9b0"))
    c = g.mix(_mul(g, _blot(g, 0.3, 0.55, 0.75, 4, seed=seed + 1), 0.35), c, "#c9c7b4", "MULTIPLY")
    c = g.mix(_mul(g, _grout(g, pitch, 0.06), 0.8), c, g.mix(_blot(g, 0.5, 0.3, 0.7, 3, seed=seed + 2), grout, "#5a5e58"))
    if waterline is not None:
        band = _mul(g, g.step(z, waterline - 0.35, waterline - 0.05), _inv(g, g.step(z, waterline + 0.02, waterline + 0.12)))
        c = g.mix(_mul(g, band, 0.8), c, "#6f6a48", "MULTIPLY")
        below = _mul(g, _inv(g, g.step(z, waterline - 0.6, waterline - 0.3)), _blot(g, 0.8, 0.4, 0.7, 3, seed=seed + 3), 0.35)
        c = g.mix(below, c, "#7f9a86", "MULTIPLY")
    if low:
        c = g.mix(_mul(g, _inv(g, g.step(z, 0.0, 1.6)), _blot(g, 1.2, 0.3, 0.7, 4, seed=seed + 4), low), c, "#2e2a25", "MULTIPLY")
    for axis, spots in hands:
        u, v = (x, z) if axis == "xz" else (x, y)
        c = _oil_hands(g, c, u, v, spots, seed + 5)
    return g.done(c, ao=0.8)


@cached
def water(seed=0):
    """Turquoise pool water: tile grid faint underneath, light ripple lines, yellow-green scum drifting on top."""
    g = kit.G("water")
    x, y, _ = _pos(g)
    c = g.mix(_blot(g, 0.12, 0.3, 0.72, 4, seed=seed), "#139c96", "#36c4ba")
    c = g.mix(_mul(g, g.math("MAXIMUM", _band(g, x, 1.0, 0.06), _band(g, y, 1.0, 0.06)), 0.18), c, "#8ad0c6")
    ripple = _inv(g, g.step(g.math("ABSOLUTE", g.math("SUBTRACT", _wn(g, 0.5, 2, seed=seed + 1), 0.5)), 0.01, 0.03))
    c = g.mix(_mul(g, ripple, 0.3), c, "#c4f0e6")
    c = g.mix(_mul(g, _blot(g, 0.35, 0.66, 0.74, 4, seed=seed + 2), 0.55), c, "#8a9a62")
    return g.done(c, ao=0.0, top=0.0)


@cached
def sky(seed=0, scale=0.09, odd=None):
    """Painted sky seen from below: blue wash, soft clouds with grey-blue undersides.
    odd = (i, j) 8-stud panel painted from a different picture, so its clouds don't line up."""
    g = kit.G("sky")
    x, y, _ = _pos(g)
    n = _wn(g, scale, 5, seed=seed)
    if odd:
        swap = _mul(g, _is(g, _cell(g, x, 8.0), odd[0]), _is(g, _cell(g, y, 8.0), odd[1]))
        n = g.math("ADD", n, _mul(g, swap, g.math("SUBTRACT", _wn(g, scale * 1.4, 5, seed=seed + 9), n)))
    c = g.mix(_blot(g, scale * 0.5, 0.3, 0.7, 3, seed=seed + 1), "#4f82c8", "#8fb8e6")
    c = g.mix(g.step(n, 0.47, 0.56), c, "#b8c6dc")
    c = g.mix(g.step(n, 0.53, 0.68), c, "#f3f1ea")
    if odd:
        c = g.mix(_mul(g, swap, 0.25), c, "#e6e0c8")
    return g.done(c, ao=0.0, top=0.0)


@cached
def turf(color, seed=0):
    """Fake grass far too green, each square a slightly different dye lot."""
    g = kit.G("turf")
    x, y, _ = _pos(g)
    c = g.mix(_mul(g, _rand(g, _cell(g, x, 4.0), _cell(g, y, 4.0), seed), 0.4), color, g.mix(0.5, color, "#2f7a24"))
    c = g.mix(_mul(g, g.step(g.noise(40, 2), 0.4, 0.7), 0.25), c, g.mix(0.4, color, "#b8ff7a"))
    c = g.mix(_mul(g, _blot(g, 0.2, 0.55, 0.72, 3, seed=seed + 1), _inner(g), 0.5), c, "#3e4a30", "MULTIPLY")
    return g.done(c, ao=0.7)


@cached
def white_concrete(seed=0, hands=()):
    g = kit.G("conc")
    x, y, _ = _pos(g)
    c = g.mix(_blot(g, 0.8, 0.3, 0.7, 5, seed=seed), "#e9e7e0", "#c9c6bc")
    c = g.mix(_mul(g, _blot(g, 4.0, 0.5, 0.7, 2, seed=seed + 1), 0.3), c, "#9a978e")
    for axis, spots in hands:
        c = _oil_hands(g, c, x, y, spots, seed + 2)
    return g.done(c, ao=0.8)


@cached
def plaster(color, seed=0):
    """Smooth render with grey rain-like streaks running down under every window."""
    g = kit.G("plaster")
    _, _, z = _pos(g)
    c = g.mix(_mul(g, _blot(g, 0.5, 0.3, 0.75, 5, seed=seed), 0.3), color, g.mix(0.5, color, "#8f8a80"))
    s = _mul(g, g.step(_wn(g, 1.1, 3, (1, 1, 0.07), seed + 1), 0.58, 0.7), 0.45)
    c = g.mix(s, c, "#77736a", "MULTIPLY")
    c = g.mix(_mul(g, _inv(g, g.step(z, 0.0, 1.4)), 0.5), c, "#3a352e", "MULTIPLY")
    return g.done(c, ao=0.85)


@cached
def sand(seed=0):
    """Soft powder-blue sand, wind ripples, red in the hollows (low z) but never at the tile edges."""
    g = kit.G("sand")
    x, y, z = _pos(g)
    c = g.mix(_blot(g, 0.15, 0.3, 0.7, 4, seed=seed), "#5d86d6", "#8fb0ec")
    red = _mul(g, _inv(g, g.step(z, 0.05, 0.4)), _inner(g, margin=5.0), 0.85)
    c = g.mix(red, c, "#a8323e")
    ripple = _band(g, g.math("ADD", y, _mul(g, _wn(g, 0.25, 2, seed=seed + 1), 3.0)), 0.7, 0.18)
    c = g.mix(_mul(g, ripple, 0.25), c, "#3a5aa8")
    c = g.mix(_mul(g, g.step(g.noise(30, 2), 0.5, 0.7), 0.2), c, "#e8eeff")
    return g.done(c, ao=0.6)


@cached
def chrome():
    """Fake mirror: a painted reflection keyed off the surface normal, so it reads as chrome from any side.
    It reflects blue sky, a white horizon and red-blue dunes that are nowhere in the dark warehouse.
    Built as a "glow" graph on purpose: kit.G skips the dust pass for that name and the orb must stay spotless."""
    g = kit.G("glow")
    nx, ny, nz = _sep(g, g.geo.outputs["Normal"])
    x, y, z = _pos(g)
    wave = g.math("ADD", nz, _mul(g, g.math("SINE", g.math("ADD", _mul(g, nx, 7.0), _mul(g, ny, 3.0))), 0.04))
    c = g.mix(g.step(wave, 0.04, 0.45), "#a8c4ec", "#0c1228")
    c = g.mix(_inv(g, g.step(g.math("ABSOLUTE", g.math("SUBTRACT", wave, 0.03)), 0.005, 0.03)), c, "#e4eefa")
    dunes = g.math("SINE", g.math("ADD", g.math("ADD", _mul(g, nx, 13.0), _mul(g, ny, 8.0)), _mul(g, wave, 22.0)))
    ground = g.mix(g.step(dunes, 0.2, 0.45), "#26408a", "#a02c38")
    ground = g.mix(g.step(wave, -0.12, -0.02), ground, "#7896d0")
    ground = g.mix(g.step(wave, -0.75, -0.35), "#06070a", ground)
    c = g.mix(_inv(g, g.step(wave, 0.0, 0.03)), c, ground)
    hl = g.step(g.math("ADD", g.math("ADD", _mul(g, nx, -0.4), _mul(g, ny, -0.55)), _mul(g, nz, 0.73)), 0.975, 0.995)
    c = g.mix(hl, c, "#ffffff")
    c = _oil_hands(g, c, x, z, [(-3.2, 3.4, 8, 1.6), (-1.4, 4.1, -12, 1.6), (2.6, 2.6, 4, 1.5)], 7)
    return g.done(c, ao=0.0, top=0.0)


def oil():
    return flat(OIL)


def warm():
    return glow("#ffc978", core="#fff0cf", amount=0.25)


def dark_glass():
    return plain("#1d222c", grime=0.15, vary=0.2, ao=0.5)


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


def tray(w, d, h, mat):
    """Box with no bottom face: floors are never seen from below, and the top gets the whole texture."""
    bm = bmesh.new()
    lo = [bm.verts.new((sx * w / 2, sy * d / 2, 0)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    hi = [bm.verts.new((v.co.x, v.co.y, h)) for v in lo]
    bm.faces.new(hi)
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    ob = kit._finish(bm, mat, smooth=30)
    top = max(ob.data.polygons, key=lambda p: p.center.z)
    if top.normal.z < 0:
        ob.data.flip_normals()
    return ob


def ring(r0, r1, h, mat, seg=48):
    """Flat annulus lying on z = 0, h thick."""
    return lathe([(r0, 0.0), (r1, 0.0), (r1, h), (r0, h), (r0, 0.0)], mat, seg=seg, smooth=20)


def heightfield(n, half, height, mat):
    """Open surface facing up over a square, n x n quads. height(x, y) -> z."""
    bm = bmesh.new()
    vs = [[bm.verts.new((-half + 2 * half * i / n, -half + 2 * half * j / n, 0)) for i in range(n + 1)] for j in range(n + 1)]
    for row in vs:
        for v in row:
            v.co.z = height(v.co.x, v.co.y)
    # triangles, not quads: kit.cull probes from each face centre, and a bent quad's centre sits under its own surface
    for j in range(n):
        for i in range(n):
            a, b, c, d = vs[j][i], vs[j][i + 1], vs[j + 1][i + 1], vs[j + 1][i]
            bm.faces.new((a, b, c))
            bm.faces.new((a, c, d))
    ob = kit._finish(bm, mat, smooth=60)
    if sum(p.normal.z for p in ob.data.polygons) < 0:
        ob.data.flip_normals()
    return ob


# ---------------------------------------------------------------- pool
@item("pool_floor", "warehouse", size=1024)
def pool_floor(P):
    """Sunken pool bottom: small white tile 2 under a turquoise Wet surface, a square drain, limescale."""
    P.add("Body", tray(32, 32, 0.2, tile("#e6ebe6", "#9fb0aa", 0.5, 61)))
    grate = metal("#9a9e9c", rust=0.35)
    P.add("Body", box((2.0, 2.0, 0.06), grate, loc=(6.0, -5.0, 0.23), r=0.0, n=1))
    for i in range(-3, 4):
        P.add("Body", box((1.5, 0.12, 0.02), flat("#1a1c1c"), loc=(6.0, -5.0 + i * 0.22, 0.27), r=0.0, n=1))
    P.add("Body", box((2.4, 2.4, 0.01), plain("#5a6a50", grime=0.6), loc=(6.0, -5.0, 0.205), r=0.0, n=1))
    P.add("Wet", box((32, 32, 0.1), water(62), loc=(0, 0, WATER_TOP - 0.05), r=0.0, n=1))


@item("pool_edge", "warehouse", size=1024)
def pool_edge(P):
    """32 long rim: pool side faces -y. Step under the water, tiled wall, coping lip on top (3.1).
    Scum line at the water height, a faded depth tile and a black oil handprint on the lip."""
    lip_top, step_top = 3.1, 1.2
    hand = (("xy", ((-7.0, 0.3, 172, 1.0),)),)
    t = tile("#e6ebe6", "#9fb0aa", 0.5, 71, waterline=WATER_TOP)
    cop = tile("#f0f0ea", "#8a8e88", 1.0, 72, hands=hand)
    P.add("Body", box((32, 1.0, step_top), t, loc=(0, -1.0, step_top / 2), r=0.0, n=1),
          box((32, 2.0, lip_top - 0.3), t, loc=(0, 0.5, (lip_top - 0.3) / 2), r=0.0, n=1),
          box((32, 2.3, 0.3), cop, loc=(0, 0.35, lip_top - 0.15), r=0.05, n=1))
    P.add("Body", box((32, 0.04, 0.06), flat("#22241f"), loc=(0, -0.51, lip_top - 0.33), r=0.0, n=1))
    P.add("Body", box((1.0, 1.0, 0.01), plain("#9fb4c0", grime=0.5, vary=0.4), loc=(4.0, -0.2, lip_top + 0.005), r=0.0, n=1),
          words("4", 0.7, flat("#6e7f8c"), loc=(4.0, -0.2, lip_top + 0.012), rot=(-90, 0, 180), depth=0.01))


@item("wall_tile_doorway", "warehouse", size=1024)
def wall_tile_doorway(P):
    """16 x 1 x 16 small white tile wall with an open 6 x 9 doorway into the dark. Grime splashed up the foot,
    oil hands beside the opening where something steadied itself going through."""
    hand = (("xz", ((-3.6, 4.4, 4, 1.0), (3.7, 3.6, -6, 1.0))),)
    t = tile(TILE, GROUT, 0.5, 81, hands=hand, low=0.7)
    P.add("Body", box((5.0, 1.0, 16), t, loc=(-5.5, 0, 8), r=0.0, n=1),
          box((5.0, 1.0, 16), t, loc=(5.5, 0, 8), r=0.0, n=1),
          box((6.0, 1.0, 7.0), t, loc=(0, 0, 12.5), r=0.0, n=1))
    P.add("Body", box((6.0, 1.0, 0.04), plain("#3a3832", grime=0.7), loc=(0, 0, 0.02), r=0.0, n=1))


@item("window_grid_wall", "warehouse", size=1024)
def window_grid_wall(P):
    """16 x 1 x 16 flat wall of 7 x 6 small recessed windows, nearly all dark. Three glow warm, one glows cold green."""
    wall = plaster("#dedbd2", 91)
    cols = [-6.6 + 2.2 * i for i in range(7)]
    rows = [2.6 + 2.2 * j for j in range(6)]
    win, recess = 1.2, 0.4
    P.add("Body", box((16, 1.0 - recess, 16), wall, loc=(0, recess / 2, 8), r=0.0, n=1))
    edges = [0.0] + [z for zc in rows for z in (zc - win / 2, zc + win / 2)] + [16.0]
    for z0, z1 in zip(edges[::2], edges[1::2]):
        P.add("Body", box((16, recess, z1 - z0), wall, loc=(0, -0.5 + recess / 2, (z0 + z1) / 2), r=0.0, n=1))
    xs = [-8.0] + [x for xc in cols for x in (xc - win / 2, xc + win / 2)] + [8.0]
    for zc in rows:
        for x0, x1 in zip(xs[::2], xs[1::2]):
            P.add("Body", box((x1 - x0, recess, win), wall, loc=((x0 + x1) / 2, -0.5 + recess / 2, zc), r=0.0, n=1))
    lit = {(1, 4): warm(), (5, 2): warm(), (2, 1): warm(), (4, 5): glow("#8ef0b0", core="#e2ffea", amount=0.3)}
    for i, x in enumerate(cols):
        for j, z in enumerate(rows):
            m = lit.get((i, j))
            P.add("Glow" if m else "Body", box((win, 0.04, win), m or dark_glass(), loc=(x, -0.5 + recess - 0.02, z), r=0.0, n=1))
            P.add("Body", box((win, 0.08, 0.06), plain("#6a675f", grime=0.5), loc=(x, -0.5 + recess - 0.06, z - win / 2 + 0.03), r=0.0, n=1))


# ---------------------------------------------------------------- sky
@item("sky_ceiling", "warehouse", size=1024)
def sky_ceiling(P):
    """32 x 32 ceiling panel: painted sky on the underside, hairline seams every 8. One panel was replaced from
    a different picture and its clouds stop dead at the seam. Grey backing on top."""
    P.add("Body", box((32, 32, 0.06), sky(101, 0.09, (1, -2)), loc=(0, 0, 0.03), r=0.0, n=1))
    seam = flat("#3a4658")
    for k in range(-1, 2):
        P.add("Body", box((32, 0.06, 0.01), seam, loc=(0, k * 8.0, -0.004), r=0.0, n=1),
              box((0.06, 32, 0.01), seam, loc=(k * 8.0, 0, -0.004), r=0.0, n=1))
    P.add("Body", box((31.8, 31.8, 0.24), flat("#5a5c5e"), loc=(0, 0, 0.18), r=0.0, n=1))


@item("black_sun", "warehouse", size=512)
def black_sun(P):
    """40 across, 1 thick, standing up facing -y. Pure black with a faint cold rim on both faces."""
    P.add("Body", cyl(20.0, 1.0, flat("#060607"), loc=(0, 0, 20.0), rot=(90, 0, 0), seg=64, bevel=0.05))
    rim = glow("#3e566c", core="#7f9ab2", amount=0.3)
    for s in (-1, 1):
        o = ring(19.62, 19.88, 0.04, rim, seg=64)
        move(o, rot=(90 * s, 0, 0))
        move(o, loc=(0, s * 0.54, 20.0))
        P.add("Glow", o)


@item("grid_floor", "warehouse", size=1024)
def grid_floor(P):
    """32 x 32 of too-green turf squares (4 stud cells) sunk 0.1 into a raised white concrete grid, top 0.7.
    Edge strips are half width so neighbouring tiles make a full strip. One oil hand on a strip."""
    P.add("Body", tray(32, 32, 0.6, turf("#12b812", 111)))
    c = white_concrete(112, hands=(("xy", ((4.1, -2.1, 30, 1.0),)),))
    for k in range(-4, 5):
        w = 0.25 if abs(k) == 4 else 0.5
        p = k * 4.0 - math.copysign(w / 2, k) if abs(k) == 4 else k * 4.0
        P.add("Body", box((w, 32, 0.7), c, loc=(p, 0, 0.35), r=0.0, n=1),
              box((32, w, 0.7), c, loc=(0, p, 0.35), r=0.0, n=1))


@item("catwalk", "warehouse", size=1024)
def catwalk(P):
    """8 x 32 white tiled walkway over a void: glowing strip along each edge, low square-bar rails, posts every 4.
    The underside is a clean soffit with a shadow reveal. Too white, too lit, an oil smear halfway along."""
    top = tile("#f2f4f2", "#b4bcbc", 1.0, 121, hands=(("xy", ((1.4, 3.0, 200, 1.0),)),))
    P.add("Body", box((8.0, 32, 0.6), top, loc=(0, 0, 0.9), r=0.0, n=1),
          box((7.6, 32, 0.1), flat("#3c4044"), loc=(0, 0, 0.55), r=0.0, n=1),
          box((7.2, 32, 0.5), plain("#e2e4e0", grime=0.2, vary=0.15), loc=(0, 0, 0.25), r=0.0, n=1))
    strip = glow("#dff4ff", core="#ffffff", amount=0.2)
    rail = paint("#e8eae6", chip=0.1, under="#8a8e8c", grime=0.3, streaks=0.2)
    for s in (-1, 1):
        P.add("Glow", box((0.3, 32, 0.04), strip, loc=(s * 3.35, 0, 1.22), r=0.0, n=1))
        P.add("Body", box((0.22, 32, 0.22), rail, loc=(s * 3.85, 0, 3.6), r=0.0, n=1))
        for k in range(8):
            P.add("Body", box((0.22, 0.22, 2.4), rail, loc=(s * 3.85, -14.0 + 4.0 * k, 2.4), r=0.0, n=1))


@item("chrome_orb", "warehouse", size=1024)
def chrome_orb(P):
    """30 across mirror ball resting in a flat dark ring. It reflects a bright desert sky the room doesn't have.
    Three oil handprints at robot height."""
    P.add("Body", ball(15.0, chrome(), loc=(0, 0, 15.1), seg=40, rings=22))
    g = kit.G("shadow")
    x, y, _ = _pos(g)
    d = g.math("SQRT", g.math("ADD", _mul(g, x, x), _mul(g, y, y)))
    shade = g.mix(g.step(d, 4.0, 10.0), "#0c0c10", "#3a3a42")
    P.add("Body", ring(0.01, 10.0, 0.3, g.done(shade, ao=0.3), seg=48))


@item("sand_floor", "warehouse", size=1024)
def sand_floor(P):
    """32 x 32 of blue sand: low dunes rising from flat edges at 0, red in the hollows. A line of small
    footprints walks in from the -y edge and stops dead in the middle."""
    def h(x, y):
        fall = min(1.0, max(0.0, (16.0 - max(abs(x), abs(y))) / 6.0))
        fall = fall * fall * (3 - 2 * fall)
        ridge = max(0.0, math.sin(0.32 * x + 1.1 * math.sin(0.15 * y) + 0.6)) ** 1.6
        bump = max(0.0, mnoise.noise((x * 0.12, y * 0.12, 3.0)) * 0.5 + 0.5)
        # small ripple keeps neighbouring faces off-plane so cull's limited dissolve can't merge them into bent n-gons
        edge = min(1.0, (16.0 - max(abs(x), abs(y))) / 1.2)
        ripple = 0.07 * math.sin(1.7 * x + 0.4) * math.sin(1.9 * y + 1.1) * edge + 0.08 * edge
        return round(fall * (1.9 * ridge * (0.6 + 0.6 * bump) + 0.25 * bump) + ripple, 4)

    P.add("Body", heightfield(28, 16.0, h, sand(131)))
    print_mat = plain("#3e5fae", grime=0.2, vary=0.2)
    rnd = random.Random(132)
    for k in range(15):
        y = -13.0 + k * 0.9
        x = 0.35 * math.sin(k * 0.4) + (0.28 if k % 2 else -0.28)
        a = math.radians(rnd.uniform(-8, 8))
        pts = []
        for i in range(6):
            t = 2 * math.pi * i / 6
            lx, ly = math.cos(t) * 0.17, math.sin(t) * 0.32
            px, py = x + lx * math.cos(a) - ly * math.sin(a), y + lx * math.sin(a) + ly * math.cos(a)
            pts.append((px, py, h(px, py) + 0.06))
        P.add("Body", plate(pts, 0.1, print_mat))


@item("sky_hatch", "warehouse", size=1024)
def sky_hatch(P):
    """6 x 4 floor hatch frame. The opening is painted sky and clouds (Glow) lying on the floor, sloped wood
    lining fakes the depth, and a wooden ladder pokes up out of the clouds."""
    frame = metal("#8c8e8a", rust=0.35)
    for s in (-1, 1):
        P.add("Body", box((6.0, 0.5, 0.25), frame, loc=(0, s * 1.75, 0.125), r=0.03, n=1),
              box((0.5, 3.0, 0.25), frame, loc=(s * 2.75, 0, 0.125), r=0.03, n=1))
    lining = wood("#c49a64", "#7a5634", axis="x", wear=0.2)
    hx, hy, ix, iy, low = 2.5, 1.5, 2.2, 1.2, 0.05
    P.add("Body", plate([(-hx, -hy, 0.25), (hx, -hy, 0.25), (ix, -iy, low), (-ix, -iy, low)], 0.03, lining, out=(0, 1, 1)),
          plate([(-hx, hy, 0.25), (-ix, iy, low), (ix, iy, low), (hx, hy, 0.25)], 0.03, lining, out=(0, -1, 1)),
          plate([(-hx, -hy, 0.25), (-ix, -iy, low), (-ix, iy, low), (-hx, hy, 0.25)], 0.03, lining, out=(1, 0, 1)),
          plate([(hx, -hy, 0.25), (hx, hy, 0.25), (ix, iy, low), (ix, -iy, low)], 0.03, lining, out=(-1, 0, 1)))
    P.add("Glow", box((2 * ix, 2 * iy, 0.02), sky(141, 0.6), loc=(0, 0, 0.01), r=0.0, n=1))
    ladder = wood("#b98a54", "#6a4a2a", axis="z", wear=0.4)
    base, tip = V((0, 0.7, 0.1)), V((0, 1.25, 3.8))
    for s in (-1, 1):
        P.add("Body", bar(base + V((s * 0.62, 0, 0)), tip + V((s * 0.62, 0, 0)), 0.16, ladder))
    for k in range(1, 4):
        p = base + (tip - base) * (k / 3.6)
        P.add("Body", box((1.24, 0.24, 0.07), ladder, loc=tuple(p), r=0.0, n=1))


main()
