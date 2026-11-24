"""Warehouse structure kit: walls, columns, giant pillars, roof, dock door, floors, curb, ramp,
plus the liminal pockets (drop ceiling, tile and pastel walls, sky wall, window wall, mall shutter,
coloured checker, pool and turf floors). Sizes and how the pieces fit: KIT.md next to this file.

Most textures are procedural and use world position. finish() bakes after moving the origin to the
bottom centre of the bounding box, so every piece is built centred with its floor at z = 0: the
coordinates here are the final ones and the floor masks (tile edges, joints) line up.
"""
import os, sys, math, random

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "_kit"))
from ykit import *  # noqa
import bpy, bmesh
from mathutils import noise as mnoise
from kit import _finish

OIL = "#0b0a09"
RUST = "#7a3c1a"
RUST2 = "#3b2014"
DUST = "#86817a"
GALV = "#7b8184"
BLOCK = "#77766f"
COLUMN = "#4b5661"
TRUSS = "#6a6c6b"
CONCRETE = "#7c7a74"
FLOOR = "#4a4844"
SAFETY = "#b8962e"
WALL_D = 0.5  # every wall piece spans y -0.5..0.5 so they share one origin line


# ---------------------------------------------------------------- material helpers (world position, baked)
def _sep(g, sock):
    s = g.n("ShaderNodeSeparateXYZ")
    g.t.links.new(sock, s.inputs[0])
    return s.outputs[0], s.outputs[1], s.outputs[2]


def _pos(g):
    return _sep(g, g.geo.outputs["Position"])


def _nz(g):
    return _sep(g, g.geo.outputs["Normal"])[2]


def _map(g, stretch, seed):
    x = g.n("ShaderNodeMapping")
    g.t.links.new(g.geo.outputs["Position"], x.inputs[0])
    x.inputs["Scale"].default_value = stretch
    x.inputs["Location"].default_value = (seed * 13.7, seed * 7.3, seed * 3.1)
    return x.outputs[0]


def _wn(g, scale, detail=4, stretch=(1, 1, 1), seed=0, rough=0.6):
    """World noise, 0..1. scale 0.1 = blotches about 10 studs across."""
    x = g.n("ShaderNodeTexNoise")
    x.inputs["Scale"].default_value = scale
    x.inputs["Detail"].default_value = detail
    x.inputs["Roughness"].default_value = rough
    g.t.links.new(_map(g, stretch, seed), x.inputs["Vector"])
    return x.outputs[0]


def _blot(g, scale, lo, hi, detail=4, stretch=(1, 1, 1), seed=0):
    return g.step(_wn(g, scale, detail, stretch, seed), lo, hi)


def _vor(g, scale, seed=0):
    """Distance to the nearest cell edge: small values draw a crack network."""
    x = g.n("ShaderNodeTexVoronoi")
    x.feature = "DISTANCE_TO_EDGE"
    x.inputs["Scale"].default_value = scale
    g.t.links.new(_map(g, (1, 1, 1), seed), x.inputs["Vector"])
    return x.outputs["Distance"]


def _rand(g, a, b, seed=0):
    """Repeatable random 0..1 for an integer cell (a, b)."""
    c = g.n("ShaderNodeCombineXYZ")
    g.put(c.inputs[0], a)
    g.put(c.inputs[1], b)
    c.inputs[2].default_value = seed
    w = g.n("ShaderNodeTexWhiteNoise")
    w.noise_dimensions = "3D"
    g.t.links.new(c.outputs[0], w.inputs["Vector"])
    return w.outputs["Value"]


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


def _cell(g, v, size, offset=0.0):
    return g.math("FLOOR", g.math("DIVIDE", g.math("ADD", v, offset), size))


def _is(g, v, k):
    """1 where an integer-valued socket equals k."""
    return _inv(g, g.step(g.math("ABSOLUTE", g.math("SUBTRACT", v, k)), 0.3, 0.5))


def _inner(g, half=16.0, margin=3.0):
    """1 in the middle of a floor tile, fading to 0 at its edges, so stains never cross a seam."""
    x, y, _ = _pos(g)
    d = g.math("SUBTRACT", half, g.math("MAXIMUM", g.math("ABSOLUTE", x), g.math("ABSOLUTE", y)))
    return g.step(d, 0.4, margin)


def _disc(g, cx, cy, r, soft, wobble=0.0, seed=0):
    """1 inside a wobbly circle on the floor."""
    x, y, _ = _pos(g)
    dx, dy = g.math("SUBTRACT", x, cx), g.math("SUBTRACT", y, cy)
    d = g.math("SQRT", g.math("ADD", g.math("MULTIPLY", dx, dx), g.math("MULTIPLY", dy, dy)))
    if wobble:
        d = g.math("ADD", d, g.math("MULTIPLY", g.math("SUBTRACT", _wn(g, 0.35, 3, seed=seed), 0.5), wobble))
    return _inv(g, g.step(d, r - soft, r + soft)), d


def _tone(g, c, other, amount, scale=0.12, seed=0, mask=None):
    m = _mul(g, _blot(g, scale, 0.3, 0.72, 4, seed=seed), amount)
    return g.mix(_mul(g, m, mask) if mask is not None else m, c, other)


def _speckle(g, c, amount=0.15, scale=7.0, seed=0):
    return g.mix(_mul(g, _blot(g, scale, 0.3, 0.7, 3, seed=seed), amount), c, "#2a2622", "MULTIPLY")


def _dust(g, c, amount, seed=0):
    up = g.step(_nz(g), 0.45, 0.95)
    m = _mul(g, up, g.math("ADD", 0.35, _mul(g, _blot(g, 0.7, 0.3, 0.7, 5, seed=seed), 0.65)), amount)
    return g.mix(m, c, DUST)


def _rust(g, c, amount, edges=1.0, seed=0, scale=1.8):
    col = g.mix(_blot(g, 9, 0.4, 0.65, 4, seed=seed + 1), RUST2, RUST)
    e = g.math("MINIMUM", _mul(g, g.edge(0.06), 4.0), 1.0)
    v = g.math("ADD", _wn(g, scale, 6, seed=seed, rough=0.68), _mul(g, e, 0.3 * edges))
    thr = 0.8 - amount * 0.3
    return g.mix(g.step(v, thr, thr + 0.04), c, col)


def _streaks(g, c, amount, color, seed=0, scale=0.9, blend="MIX", lo=0.6, region=0.12):
    """Long vertical runs (oil, rust, rain) in patches."""
    s = _mul(g, g.step(_wn(g, scale, 3, (1, 1, 0.06), seed), lo, lo + 0.1),
             _blot(g, region, 0.42, 0.6, 2, seed=seed + 5), amount)
    return g.mix(s, c, color, blend)


def _tide(g, c, amount, seed=0):
    """Water stains: a brown fill with darker tide-line rings."""
    n = _wn(g, 0.22, 3, (1, 1, 0.55), seed)
    fill = g.step(n, 0.57, 0.62)
    ring = _inv(g, g.step(g.math("ABSOLUTE", g.math("SUBTRACT", n, 0.62)), 0.003, 0.012))
    c = g.mix(_mul(g, fill, amount, 0.45), c, "#8f7a5a", "MULTIPLY")
    return g.mix(_mul(g, ring, amount, 0.8), c, "#5a4a36", "MULTIPLY")


def _low(g, c, amount, h=1.6, seed=0):
    """Floor grime splashed up the bottom of a wall."""
    _, _, z = _pos(g)
    m = _mul(g, _inv(g, g.step(z, 0.0, h)), g.math("ADD", 0.4, _mul(g, _blot(g, 1.2, 0.3, 0.7, 4, seed=seed), 0.6)), amount)
    return g.mix(m, c, "#2e2a25", "MULTIPLY")


def _height(g, lo, hi):
    return g.step(_pos(g)[2], lo, hi)


# ---------------------------------------------------------------- materials
@cached
def steel(color, rust=0.35, dust=0.6, oil=0.0, seed=0):
    """Painted structural steel gone dull: rust at edges and bolts, dust on every top face."""
    g = G("steel")
    c = _tone(g, color, g.mix(0.5, color, "#2a2a2a"), 0.5, 0.3, seed)
    c = _speckle(g, c, 0.12, 5, seed)
    c = _streaks(g, c, 0.5, "#4a3a2c", seed + 2, 1.2, "MULTIPLY")
    c = _rust(g, c, rust, seed=seed)
    if oil:
        c = _streaks(g, c, oil, OIL, seed + 9, 0.8, lo=0.62)
    return g.done(_dust(g, c, dust, seed), ao=0.9)


@cached
def sheet(color=GALV, rust=0.3, oil=0.0, water=0.5, girts=(), low=False, seed=0):
    """Corrugated wall steel: sheet-to-sheet tone shifts, rust bleeding down from the girt screws."""
    g = G("sheet")
    x, _, z = _pos(g)
    c = g.mix(_mul(g, _rand(g, _cell(g, x, 4.0, 8.0), 0, seed), 0.35), color, g.mix(0.4, color, "#3a3a38"))
    c = _tone(g, c, "#5c5a52", 0.45, 0.15, seed)
    c = _speckle(g, c, 0.15, 6, seed)
    for gz in girts:
        m = _mul(g, g.step(z, gz - 4.0, gz - 0.3), _inv(g, g.step(z, gz - 0.1, gz + 0.1)))
        r = _mul(g, m, g.step(_wn(g, 1.6, 3, (1, 1, 0.05), seed + 3), 0.52, 0.62), 0.85)
        c = g.mix(r, c, g.mix(0.5, RUST, RUST2))
    c = _tide(g, c, water, seed + 4)
    c = _streaks(g, c, 0.4, "#5b5144", seed + 6, 1.0, "MULTIPLY", 0.55, 0.2)
    c = _rust(g, c, rust, seed=seed)
    if oil:
        c = _streaks(g, c, oil, OIL, seed + 8, 1.4, lo=0.56, region=0.22)
    if low:
        c = _low(g, c, 0.7, 7.0, seed)
    return g.done(_dust(g, c, 0.5, seed), ao=0.95, dist=0.4)


@cached
def block(color=BLOCK, oil=0.0, seed=0):
    """Painted concrete block in running bond, paint peeling to raw block, grime splashed up."""
    g = G("block")
    x, _, z = _pos(g)
    row = _cell(g, z, 1.0)
    shift = _mul(g, g.math("FLOORED_MODULO", row, 2.0), 1.0)
    joint = g.math("MAXIMUM", _band(g, z, 1.0, 0.09), _band(g, g.math("ADD", x, shift), 2.0, 0.09))
    c = g.mix(_mul(g, _rand(g, _cell(g, g.math("ADD", x, shift), 2.0), row, seed), 0.3), color, g.mix(0.5, color, "#45433e"))
    peel = _blot(g, 0.7, 0.66, 0.68, 6, seed=seed + 1)
    c = g.mix(peel, c, "#5e5b55")
    c = _speckle(g, c, 0.25, 9, seed)
    c = g.mix(_mul(g, joint, 0.55), c, "#3a3832", "MULTIPLY")
    c = _tide(g, c, 0.5, seed + 2)
    c = _low(g, c, 0.9, 1.8, seed)
    if oil:
        smear = _mul(g, g.step(_wn(g, 0.7, 3, (0.08, 1, 1.4), seed + 4), 0.6, 0.72), _height(g, 1.5, 2.5),
                     _inv(g, _height(g, 4.0, 4.8)), oil)
        c = g.mix(smear, c, OIL)
        c = _streaks(g, c, oil, OIL, seed + 5, 1.2, lo=0.6, region=0.3)
    return g.done(_dust(g, c, 0.7, seed), ao=0.9)


@cached
def concrete(color=CONCRETE, stains=0.6, low=0.0, ties=False, silt=0.0, seed=0):
    """Cast concrete for pillars, curbs, ramps. ties = formwork panel lines and tie holes with rust tears.
    silt = a brown flood-tide stain climbing from the floor (darkest low, fading out by z 22)."""
    g = G("concrete")
    x, y, z = _pos(g)
    c = _tone(g, color, g.mix(0.5, color, "#3d3a35"), 0.6, 0.08, seed)
    c = _tone(g, c, g.mix(0.4, color, "#d8d2c4"), 0.3, 0.3, seed + 1)
    c = _speckle(g, c, 0.25, 8, seed)
    c = g.mix(_mul(g, _band(g, z, 8.0, 0.08), 0.35), c, "#3d3a35", "MULTIPLY")
    if ties:
        h = g.math("ADD", x, y)
        forms = g.math("MAXIMUM", _band(g, z, 3.0, 0.07), _band(g, h, 6.0, 0.07))
        c = g.mix(_mul(g, forms, 0.4), c, "#4a463e", "MULTIPLY")
        hole = _mul(g, _band(g, h, 4.0, 0.22, 2.0), _band(g, z, 4.0, 0.22, 2.0))
        tear = _mul(g, _band(g, h, 4.0, 0.14, 2.0), g.step(g.math("FLOORED_MODULO", g.math("ADD", z, 2.0), 4.0), 1.2, 3.8),
                    _blot(g, 0.5, 0.45, 0.6, 2, seed=seed + 7), 0.7)
        c = g.mix(tear, c, g.mix(0.5, RUST, "#6a5a48"))
        c = g.mix(hole, c, "#1e1b18")
    c = _tide(g, c, stains, seed + 2)
    c = _streaks(g, c, stains, "#4a4036", seed + 3, 0.7, "MULTIPLY", 0.55, 0.15)
    c = _streaks(g, c, stains * 0.8, OIL, seed + 4, 0.9, lo=0.64, region=0.1)
    if silt:
        rise = g.math("ADD", _inv(g, g.step(z, 2.0, 22.0)), _mul(g, g.math("SUBTRACT", _wn(g, 0.3, 3, (1, 1, 0.3), seed + 6), 0.5), 0.3))
        c = g.mix(_mul(g, g.math("MINIMUM", g.math("MAXIMUM", rise, 0.0), 1.0), silt), c, "#6e5634")
        line = _inv(g, g.step(g.math("ABSOLUTE", g.math("SUBTRACT", z, 22.0)), 0.1, 0.4))
        c = g.mix(_mul(g, line, silt, 0.4), c, "#5a4428", "MULTIPLY")
    if low:
        c = _low(g, c, low, 2.5, seed)
    return g.done(_dust(g, c, 0.8, seed), ao=0.85)


@cached
def hazard(fade=0.35, seed=0):
    """Yellow and black diagonal stripes, faded and scraped through to grey."""
    g = G("hazard")
    x, y, z = _pos(g)
    s = _band(g, g.math("ADD", g.math("ADD", x, y), z), 1.2, 0.6)
    c = g.mix(s, "#1c1b19", SAFETY)
    c = g.mix(fade, c, "#7e786c")
    scrape = _mul(g, g.step(_wn(g, 1.2, 4, (0.12, 0.12, 1.5), seed), 0.62, 0.68), 0.9)
    c = g.mix(scrape, c, "#6a6a66")
    c = _speckle(g, c, 0.2, 9, seed)
    c = _rust(g, c, 0.2, seed=seed)
    return g.done(_dust(g, c, 0.5, seed), ao=0.85)


@cached
def worn_paint(color, fade=0.4, seed=0):
    """Stencil paint gone patchy: letters, numbers, lane paint."""
    g = G("worn")
    c = g.mix(fade, color, "#77736a")
    c = g.mix(_blot(g, 1.6, 0.58, 0.64, 5, seed=seed), c, "#5d5a54")
    return g.done(_speckle(g, c, 0.2, 10, seed), ao=0.6, top=0.0)


@cached
def oil():
    g = G("oil")
    c = g.mix(_mul(g, _blot(g, 2.5, 0.4, 0.7, 3), 0.25), OIL, "#2a2420")
    return g.done(c, ao=0.3, top=0.0)


@cached
def insulation(seed=0):
    """Vinyl-faced roof insulation, yellowed, rings of old leaks and mould spots."""
    g = G("insulation")
    c = _tone(g, "#c9c2ae", "#a99c78", 0.6, 0.1, seed)
    c = _tide(g, c, 1.0, seed + 1)
    c = _tide(g, c, 0.7, seed + 2)
    c = g.mix(_mul(g, _blot(g, 3.0, 0.7, 0.74, 3, seed=seed + 3), _blot(g, 0.2, 0.5, 0.7, 2, seed=seed + 4)), c, "#3a3a30")
    return g.done(_speckle(g, c, 0.15, 5, seed), ao=0.95, dist=1.2)


@cached
def floor_concrete(seed=0, lane=False, cracks=False, stain=False, wet=False):
    """Dark warehouse slab. Saw-cut joints every 16 land on the tile edges; stains stay off the seams."""
    g = G("floorc")
    x, y, _ = _pos(g)
    inner = _inner(g)
    c = _tone(g, FLOOR, "#2a2825", 0.9, 0.07, seed, inner)
    c = _tone(g, c, "#67635a", 0.6, 0.11, seed + 1, inner)
    c = _speckle(g, c, 0.25, 9, seed)
    c = g.mix(_mul(g, _blot(g, 0.9, 0.55, 0.75, 3, (1, 0.4, 1), seed + 2), 0.18, inner), c, "#6a665e")
    tyre = _mul(g, _inv(g, g.step(g.math("ABSOLUTE", g.math("SUBTRACT", _wn(g, 0.25, 2, (0.15, 1, 1), seed + 3), 0.5)), 0.006, 0.02)),
                _blot(g, 0.15, 0.45, 0.65, 2, seed=seed + 4), inner, 0.6)
    c = g.mix(tyre, c, "#1a1918")
    blots = _mul(g, _blot(g, 0.35, 0.6, 0.72, 5, seed=seed + 5), inner, 0.8)
    c = g.mix(blots, c, "#1e1c1a")
    damp = _mul(g, _blot(g, 0.15, 0.55, 0.7, 4, seed=seed + 13), inner, 0.55)
    c = g.mix(damp, c, "#1a1917")
    drops = _mul(g, _blot(g, 1.3, 0.71, 0.73, 3, seed=seed + 12), inner, 0.9)
    c = g.mix(drops, c, OIL)
    c = _dust(g, c, 0.25, seed)
    if lane:
        wear = _inv(g, _blot(g, 1.4, 0.56, 0.66, 5, seed=seed + 6))
        line = _inv(g, g.step(g.math("ABSOLUTE", y), 0.28, 0.34))
        inx = _mul(g, _inv(g, g.step(g.math("ABSOLUTE", g.math("ADD", x, 8.0)), 4.0, 4.1)),
                   _inv(g, g.step(g.math("ABSOLUTE", g.math("SUBTRACT", y, 8.0)), 4.0, 4.1)))
        box_edge = g.math("SUBTRACT", inx, _mul(g, _inv(g, g.step(g.math("ABSOLUTE", g.math("ADD", x, 8.0)), 3.6, 3.7)),
                                                _inv(g, g.step(g.math("ABSOLUTE", g.math("SUBTRACT", y, 8.0)), 3.6, 3.7))))
        hatch = _mul(g, inx, _band(g, g.math("ADD", x, y), 1.6, 0.55))
        paint = g.math("MAXIMUM", g.math("MAXIMUM", line, box_edge), _mul(g, hatch, 0.8))
        hatch_wear = _inv(g, _mul(g, _blot(g, 0.4, 0.45, 0.6, 3, seed=seed + 7), inx, 0.8))
        c = g.mix(_mul(g, paint, wear, hatch_wear, 0.85), c, "#a3862c")
    if cracks:
        big = _inv(g, g.step(_vor(g, 0.11, seed), 0.004, 0.012))
        small = _inv(g, g.step(_vor(g, 0.35, seed + 1), 0.003, 0.008))
        region = _blot(g, 0.12, 0.4, 0.55, 2, seed=seed + 8)
        crack = g.math("MAXIMUM", _mul(g, big, region), _mul(g, small, region, _blot(g, 0.5, 0.5, 0.6, 2, seed=seed + 9)))
        halo = _mul(g, _inv(g, g.step(_vor(g, 0.11, seed), 0.01, 0.04)), region, 0.25)
        c = g.mix(_mul(g, halo, inner), c, "#6e6a62")
        c = g.mix(_mul(g, crack, inner), c, "#0f0e0d")
    if stain:
        core, d = _disc(g, 4.5, -3.5, 3.6, 0.8, 3.0, seed)
        rim = _mul(g, _inv(g, g.step(g.math("ABSOLUTE", g.math("SUBTRACT", d, 4.2)), 0.1, 0.45)), 0.9)
        drops = _mul(g, g.step(_wn(g, 3.2, 2, seed=seed + 10), 0.7, 0.72), _inv(g, g.step(d, 4.5, 8.0)))
        c = g.mix(core, c, OIL)
        c = g.mix(g.math("MAXIMUM", rim, drops), c, "#060505")
    if wet:
        damp, _ = _disc(g, -1.0, 1.0, 10.0, 2.0, 4.0, seed + 11)
        c = g.mix(_mul(g, damp, 0.6), c, "#3a3a38", "MULTIPLY")
    joint = g.math("MAXIMUM", _band(g, x, 16.0, 0.14), _band(g, y, 16.0, 0.14))
    c = g.mix(joint, c, "#161514")
    return g.done(c, ao=0.9)


@cached
def wet_patch():
    g = G("wet")
    c = _tone(g, "#191a1a", "#2c2f30", 0.6, 0.2)
    c = g.mix(_mul(g, g.step(_wn(g, 0.6, 2, (1, 0.3, 1)), 0.62, 0.7), 0.35), c, "#4a5054")
    return g.done(c, ao=0.0, top=0.0)


@cached
def wood_floor(seed=0):
    """Showroom planks 0.8 wide along x, butt joints every 8 so a tile wraps cleanly at 32."""
    g = G("woodf")
    x, y, _ = _pos(g)
    row = _cell(g, y, 0.8, 16.0)
    off = _mul(g, _rand(g, row, 0, seed), 8.0)
    along = g.math("ADD", g.math("ADD", x, 16.0), off)
    seg = _cell(g, g.math("FLOORED_MODULO", along, 32.0), 8.0)
    pr = _rand(g, row, seg, seed + 1)
    c = g.mix(pr, "#a8835a", "#c4a074")
    c = g.mix(_mul(g, g.step(_wn(g, 1.2, 6, (0.05, 1.4, 1), seed), 0.35, 0.7), 0.5), c, "#7a5a38")
    traffic = _mul(g, _blot(g, 0.08, 0.4, 0.7, 3, seed=seed + 2), _inner(g, margin=5.0), 0.55)
    c = g.mix(traffic, c, "#8a7e6a")
    scratch = _mul(g, g.step(_wn(g, 2.0, 3, (0.1, 3, 1), seed + 3), 0.66, 0.7), _inner(g), 0.6)
    c = g.mix(scratch, c, "#2a1e14")
    c = g.mix(_mul(g, _blot(g, 0.3, 0.68, 0.74, 4, seed=seed + 4), _inner(g), 0.6), c, "#2a2018")
    seam = g.math("MAXIMUM", _band(g, y, 0.8, 0.05, 16.0), _band(g, along, 8.0, 0.05))
    c = g.mix(_mul(g, seam, 0.8), c, "#1e140c")
    return g.done(_dust(g, c, 0.2, seed), ao=0.85)


@cached
def carpet(seed=0):
    """Dingy showroom carpet tiles (8 square, pile turned every other tile), a wavy squiggle print
    worn flat on the walk lines, stains and a coffee ring."""
    g = G("carpet")
    x, y, _ = _pos(g)
    par = g.math("FLOORED_MODULO", g.math("ADD", _cell(g, x, 8.0), _cell(g, y, 8.0)), 2.0)
    c = g.mix(_mul(g, par, 0.2), "#5a5446", "#6a6452")
    wave = g.math("ADD", y, _mul(g, g.math("SINE", _mul(g, x, math.pi / 1.0)), 0.25))
    wave = g.math("ADD", wave, _mul(g, g.math("SINE", _mul(g, x, math.pi / 2.0)), 0.3))
    squiggle = _mul(g, _band(g, wave, 0.5, 0.12), _blot(g, 1.6, 0.35, 0.5, 2, seed=seed + 3))
    c = g.mix(_mul(g, squiggle, 0.55), c, "#2e2a22")
    c = g.mix(_mul(g, _blot(g, 30, 0.3, 0.7, 2, seed=seed), 0.3), c, "#1e1c18", "MULTIPLY")
    worn = _mul(g, _blot(g, 0.1, 0.45, 0.7, 3, seed=seed + 1), _inner(g, margin=5.0), 0.45)
    c = g.mix(worn, c, "#7a7462")
    st = _mul(g, _blot(g, 0.45, 0.68, 0.73, 4, seed=seed + 2), _inner(g), 0.75)
    c = g.mix(st, c, "#3a2a1e", "MULTIPLY")
    ring, d = _disc(g, -6.0, 5.0, 1.2, 0.05)
    c = g.mix(_mul(g, _inv(g, g.step(g.math("ABSOLUTE", g.math("SUBTRACT", d, 1.2)), 0.04, 0.1)), 0.7), c, "#3a2414")
    seam = g.math("MAXIMUM", _band(g, x, 8.0, 0.04), _band(g, y, 8.0, 0.04))
    c = g.mix(_mul(g, seam, 0.6), c, "#24221c")
    return g.done(_dust(g, c, 0.25, seed), ao=0.8)


@cached
def store_tile(seed=0):
    """Old 2-stud store tile in cream and faded terracotta, cracked, a few tiles gone to black glue."""
    g = G("tile")
    x, y, _ = _pos(g)
    i, j = _cell(g, x, 2.0), _cell(g, y, 2.0)
    par = g.math("FLOORED_MODULO", g.math("ADD", i, j), 2.0)
    c = g.mix(par, "#a39c8c", "#7a4c3e")
    c = g.mix(_mul(g, _rand(g, i, j, seed), 0.25), c, "#5a5550")
    c = _speckle(g, c, 0.2, 12, seed)
    c = g.mix(_mul(g, _blot(g, 0.12, 0.45, 0.7, 3, seed=seed + 1), _inner(g, margin=5.0), 0.45), c, "#5a544a")
    crack = _mul(g, _inv(g, g.step(_vor(g, 0.25, seed), 0.003, 0.009)), _blot(g, 0.15, 0.48, 0.58, 2, seed=seed + 2), _inner(g))
    c = g.mix(crack, c, "#1a1816")
    grout = g.math("MAXIMUM", _band(g, x, 2.0, 0.06), _band(g, y, 2.0, 0.06))
    c = g.mix(_mul(g, grout, 0.8), c, "#3a3630")
    gone = g.step(_rand(g, i, j, seed + 3), 0.955, 0.96)
    c = g.mix(gone, c, g.mix(_blot(g, 4, 0.4, 0.7, 3, seed=seed + 4), "#1b1916", "#2e2a24"))
    return g.done(_dust(g, c, 0.25, seed), ao=0.85)


@cached
def color_checker(seed=0):
    """Bright primary checker, cream between the colours, faded and scuffed."""
    g = G("cchecker")
    x, y, _ = _pos(g)
    i, j = _cell(g, x, 2.0), _cell(g, y, 2.0)
    par = g.math("FLOORED_MODULO", g.math("ADD", i, j), 2.0)
    k = g.math("FLOORED_MODULO", g.math("ADD", i, _mul(g, j, 2.0)), 4.0)
    col = "#b8433a"
    col = g.mix(_is(g, k, 1.0), col, "#d6b545")
    col = g.mix(_is(g, k, 2.0), col, "#3c62a6")
    col = g.mix(_is(g, k, 3.0), col, "#3d8a58")
    c = g.mix(par, "#d6cebb", col)
    c = g.mix(0.22, c, "#b1aba0")
    c = g.mix(_mul(g, _rand(g, i, j, seed), 0.15), c, "#7a756c")
    c = g.mix(_mul(g, _blot(g, 0.1, 0.45, 0.7, 3, seed=seed + 1), _inner(g, margin=5.0), 0.35), c, "#8a8478")
    c = g.mix(_mul(g, g.step(_wn(g, 1.6, 3, (0.12, 1, 1), seed + 2), 0.66, 0.7), _inner(g), 0.6), c, "#2a2826")
    crack = _mul(g, _inv(g, g.step(_vor(g, 0.2, seed), 0.003, 0.008)), _blot(g, 0.15, 0.52, 0.6, 2, seed=seed + 3), _inner(g))
    c = g.mix(crack, c, "#2a2624")
    grout = g.math("MAXIMUM", _band(g, x, 2.0, 0.05), _band(g, y, 2.0, 0.05))
    c = g.mix(_mul(g, grout, 0.6), c, "#6a665e")
    return g.done(_dust(g, c, 0.2, seed), ao=0.8)


@cached
def pool_tile(seed=0):
    """Small aqua pool mosaic with a dark lane line along x, limescale and algae."""
    g = G("pool")
    x, y, _ = _pos(g)
    i, j = _cell(g, x, 1.0), _cell(g, y, 1.0)
    c = g.mix(_mul(g, _rand(g, i, j, seed), 0.35), "#7fb5b6", "#5f9aa2")
    lane = _inv(g, g.step(g.math("ABSOLUTE", y), 0.95, 1.05))
    c = g.mix(lane, c, "#2c4f68")
    c = g.mix(_mul(g, _blot(g, 0.25, 0.6, 0.72, 4, seed=seed + 1), _inner(g), 0.6), c, "#3e5a3a", "MULTIPLY")
    c = g.mix(_mul(g, _blot(g, 0.6, 0.62, 0.7, 4, seed=seed + 2), 0.4), c, "#d8d8cc")
    grout = g.math("MAXIMUM", _band(g, x, 1.0, 0.07), _band(g, y, 1.0, 0.07))
    c = g.mix(_mul(g, grout, 0.75), c, "#8c938e")
    return g.done(_speckle(g, c, 0.12, 10, seed), ao=0.8)


@cached
def water():
    """Shallow blue-green water over the pool tile: the grid shows through faintly, light ripples on top."""
    g = G("water")
    x, y, _ = _pos(g)
    c = _tone(g, "#2a9c92", "#46bfb0", 0.6, 0.15)
    c = g.mix(_mul(g, g.math("MAXIMUM", _band(g, x, 1.0, 0.07), _band(g, y, 1.0, 0.07)), 0.25), c, "#6ab0aa")
    c = g.mix(_mul(g, _inv(g, g.step(g.math("ABSOLUTE", g.math("SUBTRACT", _wn(g, 0.5, 2, seed=3), 0.5)), 0.01, 0.03)), 0.45), c, "#bfe4dc")
    return g.done(c, ao=0.0, top=0.0)


@cached
def turf(seed=0):
    """Faded indoor fake grass on 16-wide rolls, a worn path along x down to the black backing."""
    g = G("turf")
    x, y, _ = _pos(g)
    c = _tone(g, "#3f7e34", "#5f9a48", 0.6, 0.12, seed, _inner(g, margin=5.0))
    c = g.mix(_mul(g, _blot(g, 22, 0.3, 0.7, 2, seed=seed), 0.5), c, "#1e3016", "MULTIPLY")
    c = g.mix(_mul(g, _band(g, y, 0.3, 0.1), 0.2), c, "#2a3a20", "MULTIPLY")
    edge = g.math("ADD", 3.0, _mul(g, g.math("SINE", _mul(g, x, math.pi / 8)), 0.8))
    edge = g.math("ADD", edge, _mul(g, g.math("SINE", _mul(g, x, math.pi / 4)), 0.4))
    path = _inv(g, g.step(g.math("SUBTRACT", g.math("ABSOLUTE", g.math("ADD", y, 2.0)), edge), -0.6, 0.8))
    c = g.mix(_mul(g, path, 0.8), c, "#6d6a50")
    bald = _mul(g, path, g.step(_wn(g, 1.5, 4, seed=seed + 1), 0.6, 0.66))
    c = g.mix(bald, c, "#2a2924")
    c = g.mix(_mul(g, _band(g, y, 16.0, 0.08), 0.7), c, "#1a2214")
    return g.done(_dust(g, c, 0.25, seed), ao=0.85)


@cached
def tile_wall(seed=0):
    """White square bathroom tile on a 0.8 grid, grimy grout, a dark trim course, a few cracked tiles."""
    g = G("tilew")
    x, _, z = _pos(g)
    row = _cell(g, z, 0.8)
    col = _cell(g, x, 0.8)
    c = g.mix(_mul(g, _rand(g, col, row, seed), 0.2), "#dcdad2", "#b9b6aa")
    trim = _mul(g, _height(g, 3.2, 3.22), _inv(g, _height(g, 3.98, 4.0)))
    c = g.mix(trim, c, "#2f5a62")
    c = _tide(g, c, 0.6, seed + 1)
    c = _streaks(g, c, 0.5, "#7a6a50", seed + 2, 1.0, "MULTIPLY", 0.58, 0.2)
    crack = _mul(g, _inv(g, g.step(_vor(g, 0.5, seed), 0.003, 0.008)), _blot(g, 0.2, 0.55, 0.62, 2, seed=seed + 3))
    c = g.mix(crack, c, "#2a2824")
    grout = g.math("MAXIMUM", _band(g, z, 0.8, 0.05), _band(g, x, 0.8, 0.05))
    c = g.mix(grout, c, g.mix(_blot(g, 0.6, 0.3, 0.7, 3, seed=seed + 4), "#8a8478", "#4a463e"))
    c = _low(g, c, 0.8, 2.0, seed)
    return g.done(c, ao=0.8)


@cached
def plaster(color, stripe=None, seed=0):
    """Smooth pastel plaster, scuffed low, a faded double stripe at hand height."""
    g = G("plaster")
    c = _tone(g, color, g.mix(0.25, color, "#8a8070"), 0.35, 0.12, seed)
    c = _speckle(g, c, 0.06, 5, seed)
    if stripe:
        s = g.math("MAXIMUM", g.math("SUBTRACT", _height(g, 3.3, 3.32), _height(g, 3.58, 3.6)),
                   g.math("SUBTRACT", _height(g, 3.75, 3.77), _height(g, 3.86, 3.88)))
        c = g.mix(_mul(g, s, _inv(g, _mul(g, _blot(g, 1.0, 0.55, 0.65, 4, seed=seed + 1), 0.6))), c, stripe)
    c = _tide(g, c, 0.25, seed + 2)
    c = g.mix(_mul(g, g.step(_wn(g, 1.5, 3, (0.1, 1, 1.5), seed + 3), 0.66, 0.7), _inv(g, _height(g, 1.5, 3.0)), 0.6), c, "#4a443a")
    c = _low(g, c, 0.5, 1.2, seed)
    return g.done(c, ao=0.85)


@cached
def ceiling_tile(seed=0):
    """Fissured acoustic tile, yellowed, brown leak rings."""
    g = G("ceil")
    c = _tone(g, "#d4cfc2", "#bdb39a", 0.6, 0.15, seed)
    c = g.mix(_mul(g, g.step(_wn(g, 6, 3, (1, 0.4, 1), seed), 0.62, 0.68), 0.35), c, "#8a8474")
    c = _speckle(g, c, 0.15, 14, seed)
    return g.done(_tide(g, c, 0.9, seed + 1), ao=0.8, top=0.0)


@cached
def marble(seed=0):
    """Diamond checker of pink-beige and cream marble with dark marble bands and grey veins."""
    g = G("marble")
    x, y, _ = _pos(g)
    u, v = g.math("ADD", x, y), g.math("SUBTRACT", x, y)
    par = g.math("FLOORED_MODULO", g.math("ADD", _cell(g, u, 4.0), _cell(g, v, 4.0)), 2.0)
    c = g.mix(par, "#e2d6c4", "#c7a596")
    vein = _inv(g, g.step(g.math("ABSOLUTE", g.math("SUBTRACT", _wn(g, 0.35, 5, (1, 0.5, 1), seed), 0.5)), 0.004, 0.018))
    c = g.mix(_mul(g, vein, 0.45), c, "#8a7e76")
    c = g.mix(_mul(g, _blot(g, 0.12, 0.45, 0.7, 3, seed=seed + 1), _inner(g, margin=5.0), 0.35), c, "#8a8074")
    c = g.mix(_mul(g, g.step(_wn(g, 1.8, 3, (0.1, 1, 1), seed + 2), 0.66, 0.7), _inner(g), 0.5), c, "#3a3430")
    crack = _mul(g, _inv(g, g.step(_vor(g, 0.2, seed), 0.003, 0.008)), _blot(g, 0.15, 0.55, 0.62, 2, seed=seed + 3), _inner(g))
    c = g.mix(crack, c, "#2a2420")
    band = g.math("MAXIMUM", _band(g, u, 4.0, 0.22), _band(g, v, 4.0, 0.22))
    c = g.mix(band, c, "#2b2523")
    return g.done(_dust(g, c, 0.15, seed), ao=0.8)


@cached
def carpet_blue(seed=0):
    """Faded periwinkle office carpet, flat and clean-looking until you look at the stains."""
    g = G("carpetb")
    x, y, _ = _pos(g)
    c = _tone(g, "#5a68a2", "#6f7cb0", 0.5, 0.1, seed, _inner(g, margin=5.0))
    c = g.mix(_mul(g, _blot(g, 30, 0.3, 0.7, 2, seed=seed), 0.35), c, "#20243a", "MULTIPLY")
    c = g.mix(_mul(g, _blot(g, 0.1, 0.45, 0.7, 3, seed=seed + 1), _inner(g, margin=5.0), 0.35), c, "#8a8c9a")
    c = g.mix(_mul(g, _blot(g, 0.45, 0.68, 0.73, 4, seed=seed + 2), _inner(g), 0.7), c, "#3a3040", "MULTIPLY")
    seam = g.math("MAXIMUM", _band(g, x, 16.0, 0.04), _band(g, y, 16.0, 0.04))
    c = g.mix(_mul(g, seam, 0.5), c, "#2a2e48")
    return g.done(_dust(g, c, 0.2, seed), ao=0.8)


@cached
def carpet_wild(seed=0):
    """Loud arcade carpet: neon squiggle bands, stars and dots on near-black, faded and trodden."""
    g = G("carpetw")
    x, y, _ = _pos(g)
    c = "#16142a"
    for k, (col, ph, f) in enumerate((("#e0408a", 0.0, 4), ("#3fd07a", 1.7, 2), ("#f2c63a", 3.1, 4), ("#3a8ae0", 4.4, 8))):
        wave = g.math("ADD", y, _mul(g, g.math("SINE", g.math("ADD", _mul(g, x, 2 * math.pi / (32 / f)), ph)), 1.1))
        wave = g.math("ADD", wave, _mul(g, g.math("SINE", g.math("ADD", _mul(g, x, 2 * math.pi / 16), ph * 2)), 0.5))
        c = g.mix(_band(g, wave, 4.0, 0.35, k * 1.0), c, col)
    dots = _mul(g, _band(g, g.math("ADD", x, 0.7), 2.0, 0.22), _band(g, g.math("ADD", y, 1.3), 2.0, 0.22))
    c = g.mix(dots, c, "#f4f0e6")
    c = g.mix(0.25, c, "#6a6670")
    c = g.mix(_mul(g, _blot(g, 30, 0.3, 0.7, 2, seed=seed), 0.4), c, "#141218", "MULTIPLY")
    worn = _mul(g, _blot(g, 0.1, 0.45, 0.7, 3, seed=seed + 1), _inner(g, margin=5.0), 0.45)
    c = g.mix(worn, c, "#4a4650")
    c = g.mix(_mul(g, _blot(g, 0.45, 0.66, 0.72, 4, seed=seed + 2), _inner(g), 0.8), c, "#2a2018", "MULTIPLY")
    return g.done(_dust(g, c, 0.2, seed), ao=0.8)


@cached
def stair_carpet(seed=0):
    """Beige basement carpet, trodden grey down the middle of each tread, fuzz worn off the nosings."""
    g = G("carpets")
    x, _, _ = _pos(g)
    c = _tone(g, "#b9ae98", "#a39884", 0.5, 0.2, seed)
    c = g.mix(_mul(g, _blot(g, 30, 0.3, 0.7, 2, seed=seed), 0.3), c, "#3a3428", "MULTIPLY")
    mid = _mul(g, _inv(g, g.step(g.math("ABSOLUTE", x), 0.6, 2.8)), g.step(_nz(g), 0.5, 0.9), 0.5)
    c = g.mix(mid, c, "#6e6656")
    e = g.math("MINIMUM", _mul(g, g.edge(0.08), 4.0), 1.0)
    c = g.mix(_mul(g, e, 0.5), c, "#5a5244")
    c = g.mix(_mul(g, _blot(g, 0.6, 0.68, 0.73, 4, seed=seed + 1), 0.7), c, "#4a3a28", "MULTIPLY")
    return g.done(c, ao=0.9)


@cached
def lime_plaster(seed=0):
    """Glossy lime-green curved wall, a slate-blue base band, scuffs where chairs hit it."""
    g = G("lime")
    c = _tone(g, "#a6c43a", "#8fb032", 0.4, 0.15, seed)
    c = _speckle(g, c, 0.06, 5, seed)
    c = g.mix(_inv(g, _height(g, 0.5, 0.52)), c, "#4a5878")
    c = g.mix(_mul(g, g.step(_wn(g, 1.5, 3, (0.4, 0.4, 2.0), seed + 3), 0.66, 0.7), _inv(g, _height(g, 1.5, 3.0)), 0.6), c, "#4a5a2a")
    c = _tide(g, c, 0.35, seed + 2)
    return g.done(c, ao=0.85)


@cached
def diamond_plate(seed=0):
    g = G("plate")
    x, y, _ = _pos(g)
    studs = _mul(g, _band(g, g.math("ADD", x, y), 0.5, 0.1), _band(g, g.math("SUBTRACT", x, y), 0.5, 0.3))
    c = _tone(g, "#7a7c7a", "#5a5c5a", 0.5, 0.4, seed)
    c = g.mix(_mul(g, studs, 0.6), c, "#b4b4ae")
    c = _rust(g, c, 0.4, seed=seed)
    c = _streaks(g, c, 0.6, OIL, seed + 3, 1.0, lo=0.6, region=0.4)
    return g.done(_dust(g, c, 0.5, seed), ao=0.85)


# ---------------------------------------------------------------- shapes
def corrugated(u0, u1, w0, w1, crown, pan, back, mat, pitch=1.0, rows=1, place=None):
    """Trapezoid-rib steel sheet as one closed solid. The profile runs along u, ribs run along w,
    v is depth: ribs stick out to crown, valleys sit at pan, the flat back is at back.
    place(u, v, w) -> (x, y, z); default is a wall (u = x, v = y, w = z)."""
    place = place or (lambda u, v, w: (u, v, w))
    n = round((u1 - u0) / pitch)
    prof = []
    for i in range(n):
        a = u0 + i * pitch
        prof += [(a, pan), (a + 0.2 * pitch, pan), (a + 0.35 * pitch, crown), (a + 0.65 * pitch, crown), (a + 0.8 * pitch, pan)]
    prof.append((u1, pan))
    rings = []
    for k in range(rows + 1):
        w = w0 + (w1 - w0) * k / rows
        rings.append([place(u, v, w) for u, v in prof] + [place(u1, back, w), place(u0, back, w)])
    return loft(rings, mat, smooth=20)


def girt(z, mat, x0=-8.0, x1=8.0):
    """Z-girt across the wall, in front of the sheet."""
    L, cx = x1 - x0, (x0 + x1) / 2
    return [box((L, 0.62, 0.06), mat, loc=(cx, -0.19, z), r=0.0, n=1),
            box((L, 0.06, 0.7), mat, loc=(cx, -0.47, z - 0.32), r=0.0, n=1),
            box((L, 0.06, 0.5), mat, loc=(cx, 0.09, z + 0.22), r=0.0, n=1)]


def block_base(mat, h=5.0):
    """Concrete block knee wall with a proud cap course."""
    return [box((16, 0.92, h - 0.4), mat, loc=(0, 0.04, (h - 0.4) / 2), r=0.0, n=1),
            box((16, 1.0, 0.4), mat, loc=(0, 0, h - 0.2), r=0.04, n=1)]


def handprint(x, z, y, mat, size=0.7, rot=0.0, smear=0.0):
    """Flat oily hand on a -y facing surface. smear drags it downward."""
    s = size
    out = [box((0.5 * s, 0.01, 0.55 * s), mat, loc=(0, 0, 0), r=0.15 * s, n=1)]
    for i, (dx, ln) in enumerate(((-0.18, 0.38), (-0.06, 0.45), (0.06, 0.42), (0.18, 0.32))):
        out.append(box((0.1 * s, 0.01, ln * s), mat, loc=(dx * s, 0, (0.27 + ln / 2) * s), rot=(0, (i - 1.5) * 4, 0), r=0.045 * s, n=1))
    out.append(box((0.11 * s, 0.01, 0.3 * s), mat, loc=(0.3 * s, 0, 0.0), rot=(0, -50, 0), r=0.05 * s, n=1))
    if smear:
        for dx, k in ((-0.12, 1.0), (0.0, 0.8), (0.12, 0.6)):
            out.append(box((0.05 * s, 0.008, smear * k), mat, loc=(dx * s, 0.001, -smear * k / 2), r=0.0, n=1))
    move(out, loc=(x, y, z), rot=(0, rot, 0))
    return out


def chamfer_ring(half, c, z, chips=None):
    """Square ring with chamfered corners. chips[k] grows corner k's chamfer (a broken edge)."""
    pts = []
    for k, (sx, sy) in enumerate(((1, -1), (1, 1), (-1, 1), (-1, -1))):
        cc = c + (chips[k] if chips else 0.0)
        cx, cy = sx * half, sy * half
        if k % 2 == 0:
            pts += [(cx - sx * cc, cy, z), (cx - sx * cc * 0.3, cy - sy * cc * 0.3, z), (cx, cy - sy * cc, z)]
        else:
            pts += [(cx, cy - sy * cc, z), (cx - sx * cc * 0.3, cy - sy * cc * 0.3, z), (cx - sx * cc, cy, z)]
    return pts


def pillar_shaft(half, z0, z1, mat, seed, step=2.0):
    """Concrete pillar shaft, chamfered, corners chipped at random heights. Ends stay clean so segments stack."""
    rng = random.Random(seed)
    n = round((z1 - z0) / step)
    rings = []
    for k in range(n + 1):
        chips = None
        if 0 < k < n:
            chips = [rng.random() ** 3 * 1.4 if rng.random() < 0.35 else 0.0 for _ in range(4)]
        rings.append(chamfer_ring(half, 0.45, z0 + (z1 - z0) * k / n, chips))
    return loft(rings, mat, smooth=30)


def flat_poly(pts, depth, mat, z):
    """Flat shape lying on the floor: pts are (x, y), top at z."""
    return slab([(x, -y) for x, y in pts], depth, mat, loc=(0, 0, z - depth / 2), rot=(90, 0, 0))


def blob(cx, cy, r, wob, seed, n=28):
    rng = random.Random(seed)
    ph = [rng.random() * 6.28 for _ in range(3)]
    out = []
    for i in range(n):
        a = 2 * math.pi * i / n
        rr = r * (1 + wob * (0.5 * math.sin(2 * a + ph[0]) + 0.3 * math.sin(3 * a + ph[1]) + 0.2 * math.sin(5 * a + ph[2])))
        out.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return out


def tray(w, d, h, mat):
    """Box with no bottom face: floors are never seen from below, and the top then gets the whole texture."""
    bm = bmesh.new()
    lo = [bm.verts.new((sx * w / 2, sy * d / 2, 0)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    hi = [bm.verts.new((v.co.x, v.co.y, h)) for v in lo]
    bm.faces.new(hi)
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    ob = _finish(bm, mat, smooth=30)
    top = max(ob.data.polygons, key=lambda p: p.center.z)
    if top.normal.z < 0:
        ob.data.flip_normals()
    return ob


def floor_slab(P, mat, h=0.2):
    P.add("Body", tray(32, 32, h, mat))


def grid_surface(xs, ys, height, mat, keep=None):
    """Open surface over a grid, facing down (seen from below). height(x, y) -> z. keep(x, y) drops cells."""
    bm = bmesh.new()
    vs = [[bm.verts.new((x, y, height(x, y))) for y in ys] for x in xs]
    for i in range(len(xs) - 1):
        for j in range(len(ys) - 1):
            if keep and not keep((xs[i] + xs[i + 1]) / 2, (ys[j] + ys[j + 1]) / 2):
                continue
            bm.faces.new((vs[i][j], vs[i][j + 1], vs[i + 1][j + 1], vs[i + 1][j]))
    for v in [v for v in bm.verts if not v.link_faces]:
        bm.verts.remove(v)
    ob = _finish(bm, mat, smooth=60)
    if sum(p.normal.z for p in ob.data.polygons) > 0:
        ob.data.flip_normals()
    return ob


def shards(x0, x1, y0, y1, p, angles, gap=0.05, hole=None):
    """Splits a pane (x-y rectangle) into wedges radiating from impact point p, angles in degrees CCW.
    hole: per-wedge distance cut from the impact point (a broken pane). Returns (x, y) polygons."""
    w, h = x1 - x0, y1 - y0
    px, py = p

    def hit(a):
        dx, dy = math.cos(math.radians(a)), math.sin(math.radians(a))
        ts = [t for t in ((x1 - px) / dx if dx > 1e-6 else None, (x0 - px) / dx if dx < -1e-6 else None,
                          (y1 - py) / dy if dy > 1e-6 else None, (y0 - py) / dy if dy < -1e-6 else None) if t is not None]
        t = min(ts)
        return px + dx * t, py + dy * t

    def perim(q):
        x, y = q
        if abs(y - y0) < 1e-5:
            return (x - x0) / w
        if abs(x - x1) < 1e-5:
            return 1 + (y - y0) / h
        if abs(y - y1) < 1e-5:
            return 2 + (x1 - x) / w
        return 3 + (y1 - y) / h

    corners = [(1.0, (x1, y0)), (2.0, (x1, y1)), (3.0, (x0, y1)), (4.0, (x0, y0))]
    hits = [hit(a) for a in angles]
    out = []
    for i in range(len(angles)):
        a, b = hits[i], hits[(i + 1) % len(angles)]
        sa, sb = perim(a), perim(b)
        if sb <= sa:
            sb += 4
        mid = [q for s, q in corners + [(s + 4, q) for s, q in corners] if sa < s < sb]
        if hole:
            ra, rb = hole[i], hole[(i + 1) % len(angles)]
            da = (math.cos(math.radians(angles[i])), math.sin(math.radians(angles[i])))
            db = (math.cos(math.radians(angles[(i + 1) % len(angles)])), math.sin(math.radians(angles[(i + 1) % len(angles)])))
            poly = [(px + db[0] * rb, py + db[1] * rb), (px + da[0] * ra, py + da[1] * ra), a] + mid + [b]
        else:
            poly = [p, a] + mid + [b]
        cx = sum(q[0] for q in poly) / len(poly)
        cy = sum(q[1] for q in poly) / len(poly)
        shrunk = []
        for q in poly:
            dx, dy = cx - q[0], cy - q[1]
            d = math.hypot(dx, dy) or 1.0
            shrunk.append((q[0] + dx / d * gap, q[1] + dy / d * gap))
        out.append(shrunk)
    return out


def paint_image(path, size, fn):
    """Writes a PNG from fn(u, v) -> (r, g, b) in 0..1, u and v 0..1 from the bottom left."""
    img = bpy.data.images.new(os.path.basename(path), size, size)
    px = []
    for j in range(size):
        for i in range(size):
            r, g, b = fn(i / size, j / size)
            px += (r, g, b, 1.0)
    img.pixels = px
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()


def _hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def _lerp(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


# ---------------------------------------------------------------- walls
GIRTS_LOWER = (10.0,)
GIRTS_UPPER = (2.0, 10.0)


def steel_wall(P, z0, girts, mat, rows=1):
    P.add("Body", corrugated(-8, 8, z0, 16, 0.12, 0.38, WALL_D, mat, rows=rows))
    for gz in girts:
        P.add("Body", girt(gz, steel(COLUMN, 0.4, 0.8)))


@item("wall_lower", "warehouse", size=1024)
def wall_lower(P):
    P.add("Body", block_base(block()))
    steel_wall(P, 5.0, GIRTS_LOWER, sheet(girts=GIRTS_LOWER, seed=1))


@item("wall_upper", "warehouse", size=1024)
def wall_upper(P):
    steel_wall(P, 0.0, GIRTS_UPPER, sheet(girts=GIRTS_UPPER, water=0.7, seed=2))


@item("wall_lower_damaged", "warehouse", size=1024)
def wall_lower_damaged(P):
    mat = sheet(rust=0.6, water=0.6, girts=GIRTS_LOWER, low=True, seed=3)
    P.add("Body", block_base(block(seed=3)))
    # a forklift hit: crumpled dent on the right, the lower left corner torn and peeled inward
    right = corrugated(-3, 8, 5.0, 16, 0.12, 0.38, WALL_D, mat, rows=11)

    def dent(v):
        d = math.hypot((v.x - 2.5) / 3.6, (v.z - 7.2) / 2.6)
        k = max(0.0, 1 - d) ** 1.5
        n = mnoise.noise(v * 1.7) * 0.12 * k
        y = v.y + (0.32 * k if v.y < 0.45 else 0.0) + n
        return (v.x + n * 0.5, min(max(y, v.y - 0.1), WALL_D), v.z - 0.35 * k * (1 if v.y < 0.45 else 0))

    P.add("Body", warp(right, dent))
    P.add("Body", corrugated(-8, -3, 8.4, 16, 0.12, 0.38, WALL_D, mat, rows=1))
    flap = corrugated(-8, -3, 5.6, 8.4, 0.12, 0.38, 0.44, mat, rows=4)

    def peel(v):
        t = (8.4 - v.z) / 2.8
        rng = mnoise.noise((v.x * 2.1, 0, 3.3))
        z = v.z + (0.25 * rng if t > 0.95 else 0)
        return (v.x, v.y - 0.6 * t * t - 0.02, z + 0.25 * t * t)

    P.add("Body", warp(flap, peel))
    P.add("Body", box((5.0, 0.04, 3.4), flat("#0e0d0c"), loc=(-5.5, 0.48, 6.7), r=0.0, n=1))
    for gz in GIRTS_LOWER:
        P.add("Body", girt(gz, steel(COLUMN, 0.6, 0.8, seed=3)))


@item("wall_oily", "warehouse", size=1024)
def wall_oily(P):
    blk = block(oil=0.8, seed=4)
    P.add("Body", block_base(blk))
    steel_wall(P, 5.0, GIRTS_LOWER, sheet(oil=0.9, water=0.8, girts=GIRTS_LOWER, low=True, seed=4))
    ink = oil()
    y = -0.42 - 0.006
    for x, z, s, r, sm in ((-5.2, 3.4, 0.7, -12, 0.0), (-4.3, 3.0, 0.7, 8, 0.9), (1.6, 2.4, 0.75, -4, 0.0),
                           (2.5, 3.6, 0.7, 20, 1.4), (5.9, 1.6, 0.68, -30, 0.0)):
        P.add("Body", handprint(x, z, y, ink, s, r, sm))


@item("wall_corner", "warehouse", size=512)
def wall_corner(P):
    mat = steel("#55595c", 0.45, 0.7, seed=5)
    P.add("Body", box((1.2, 1.2, 16), mat, loc=(0, 0, 8), r=0.05, n=1))
    for sx in (-1, 1):
        for sy in (-1, 1):
            P.add("Body", box((0.5, 0.06, 15.6), mat, loc=(sx * 0.42, sy * 0.63, 8), r=0.0, n=1))
            P.add("Body", box((0.06, 0.5, 15.6), mat, loc=(sx * 0.63, sy * 0.42, 8), r=0.0, n=1))
    for z in (0.15, 15.85):
        P.add("Body", box((1.4, 1.4, 0.3), mat, loc=(0, 0, z), r=0.03, n=1))
    for z in (4.0, 8.0, 12.0):
        for sy in (-1, 1):
            P.add("Body", cyl(0.07, 0.06, mat, loc=(0, sy * 0.63, z), rot=(90, 0, 0), seg=6, bevel=0.01))


# ---------------------------------------------------------------- columns and pillars
def ibeam(z0, z1, mat):
    h, zc = z1 - z0, (z0 + z1) / 2
    out = [box((0.1, 1.36, h), mat, loc=(0, 0, zc), r=0.0, n=1)]
    for sy in (-1, 1):
        out.append(box((1.6, 0.14, h), mat, loc=(0, sy * 0.73, zc), r=0.02, n=1))
    return out


def splice(z0, mat):
    out = []
    for sy in (-1, 1):
        out.append(box((1.3, 0.08, 1.4), mat, loc=(0, sy * 0.84, z0 + 0.7), r=0.02, n=1))
        for bx in (-0.4, 0.4):
            for bz in (0.3, 0.7, 1.1):
                out.append(cyl(0.09, 0.08, mat, loc=(bx, sy * 0.9, z0 + bz), rot=(90, 0, 0), seg=6, bevel=0.015))
    return out


@item("column", "warehouse", size=1024)
def column(P):
    mat = steel(COLUMN, 0.35, 0.6, seed=6)
    P.add("Body", ibeam(0, 32, mat))
    P.add("Body", splice(0, steel(COLUMN, 0.7, 0.6, seed=7)))


@item("column_base", "warehouse", size=1024)
def column_base(P):
    mat = steel(COLUMN, 0.45, 0.6, oil=0.4, seed=8)
    foot = steel("#4a4c4c", 0.9, 0.5, oil=0.6, seed=9)
    P.add("Body", box((3.2, 3.2, 0.15), concrete("#5e5b55", 0.8, seed=8), loc=(0, 0, 0.075), r=0.03, n=1))
    P.add("Body", box((2.8, 2.8, 0.25), foot, loc=(0, 0, 0.275), r=0.03, n=1))
    for sx in (-1, 1):
        for sy in (-1, 1):
            P.add("Body", cyl(0.2, 0.08, foot, loc=(sx * 1.1, sy * 1.1, 0.44), seg=8, bevel=0.01))
            P.add("Body", cyl(0.14, 0.14, foot, loc=(sx * 1.1, sy * 1.1, 0.55), seg=6, bevel=0.015))
            P.add("Body", cyl(0.07, 0.12, foot, loc=(sx * 1.1, sy * 1.1, 0.68), seg=6, bevel=0.01))
    P.add("Body", ibeam(0.4, 32, mat))
    guard = hazard(0.4, seed=8)
    for sx in (-1, 1):
        P.add("Body", box((0.16, 2.4, 4.0), guard, loc=(sx * 1.12, 0, 2.4), r=0.05, n=1))
        P.add("Body", box((2.08, 0.16, 4.0), guard, loc=(0, sx * 1.12, 2.4), r=0.05, n=1))
    P.add("Body", box((2.5, 2.5, 0.12), steel("#2a2a28", 0.3, 0.9, seed=8), loc=(0, 0, 4.44), r=0.03, n=1))
    P.add("Body", flat_poly(blob(0.6, -0.95, 0.3, 0.35, 8), 0.02, oil(), 0.41))


@item("giant_pillar", "warehouse", size=1024)
def giant_pillar(P):
    mat = concrete(ties=True, seed=10)
    P.add("Body", pillar_shaft(12, 0, 32, mat, 10))
    P.add("Body", box((7.0, 0.03, 6.0), worn_paint("#8a8a80", 0.5, 10), loc=(0, -12.0, 15), r=0.0, n=1))
    P.add("Body", words("D7", 4.2, worn_paint("#1e1e1c", 0.35, 11), loc=(0, -12.03, 15), depth=0.02))
    # the same mark on the back face keeps the bounding box centred on the shaft
    P.add("Body", box((7.0, 0.03, 6.0), worn_paint("#8a8a80", 0.5, 10), loc=(0, 12.0, 15), r=0.0, n=1))
    P.add("Body", words("D7", 4.2, worn_paint("#1e1e1c", 0.35, 11), loc=(0, 12.03, 15), rot=(0, 0, 180), depth=0.02))


@item("giant_pillar_base", "warehouse", size=1024)
def giant_pillar_base(P):
    foot = concrete("#6e6b64", 0.5, low=0.8, seed=12)
    # a frame around the shaft, not a slab under it: hidden faces then cull away whole
    P.add("Body", [box((3, 30, 2), foot, loc=(sx * 13.5, 0, 1), r=0.25, n=1) for sx in (-1, 1)])
    P.add("Body", [box((24, 3, 2), foot, loc=(0, sy * 13.5, 1), r=0.25, n=1) for sy in (-1, 1)])
    P.add("Body", pillar_shaft(12, 0, 32, concrete(ties=True, low=0.9, silt=0.8, seed=13), 13))
    stripe = hazard(0.5, seed=12)
    for sx in (-1, 1):
        P.add("Body", box((24.0, 0.04, 1.2), stripe, loc=(0, sx * 12.0, 2.6), r=0.0, n=1))
        P.add("Body", box((0.04, 24.0, 1.2), stripe, loc=(sx * 12.0, 0, 2.6), r=0.0, n=1))
    P.add("Body", box((7.0, 0.03, 6.0), worn_paint("#8a8a80", 0.5, 12), loc=(0, -12.0, 13), r=0.0, n=1))
    P.add("Body", words("D7", 4.2, worn_paint("#1e1e1c", 0.35, 13), loc=(0, -12.03, 13), depth=0.02))
    ink = oil()
    P.add("Body", flat_poly(blob(-5.0, -13.0, 0.9, 0.4, 12), 0.02, ink, 2.0))
    P.add("Body", flat_poly(blob(9.0, 13.0, 0.7, 0.4, 13), 0.02, ink, 2.0))


# ---------------------------------------------------------------- roof
def truss(mat, length=32.0, depth=4.0):
    half = length / 2
    out = [box((length, 0.7, 0.45), mat, loc=(0, 0, depth - 0.225), r=0.03, n=1),
           box((length, 0.7, 0.45), mat, loc=(0, 0, 0.225), r=0.03, n=1)]
    lo, hi = 0.45, depth - 0.45
    panels = 8
    inside = half - 0.3  # diagonals stop at the end posts so the truss stays exactly 32 long
    step = 2 * inside / panels
    for i in range(panels):
        xa, xb = -inside + i * step, -inside + (i + 1) * step
        za, zb = (lo, hi) if i % 2 == 0 else (hi, lo)
        dx, dz = xb - xa, zb - za
        ln = math.hypot(dx, dz)
        out.append(box((ln + 0.2, 0.3, 0.3), mat, loc=((xa + xb) / 2, 0, (za + zb) / 2), rot=(0, -math.degrees(math.atan2(dz, dx)), 0), r=0.0, n=1))
    for sx in (-1, 1):
        out.append(box((0.3, 0.3, hi - lo), mat, loc=(sx * (half - 0.15), 0, depth / 2), r=0.0, n=1))
        out.append(box((0.3, 0.3, hi - lo), mat, loc=(sx * 4.0, 0, depth / 2), r=0.0, n=1))
    return out


@item("roof_truss", "warehouse", size=1024)
def roof_truss(P):
    P.add("Body", truss(steel(TRUSS, 0.4, 1.0, seed=14)))


PURLINS = (-12.0, -4.0, 4.0, 12.0)
DECK_Z = (1.4, 1.65, 1.8)  # rib crowns, valleys, flat top


def purlin(x, mat, y0=-16.0, y1=16.0):
    L, cy = y1 - y0, (y0 + y1) / 2
    return [box((0.06, L, 1.4), mat, loc=(x, cy, 0.7), r=0.0, n=1),
            box((0.6, L, 0.06), mat, loc=(x + 0.27, cy, 0.03), r=0.0, n=1),
            box((0.6, L, 0.06), mat, loc=(x - 0.27, cy, 1.37), r=0.0, n=1)]


def sag(x, y):
    """Insulation hangs from the purlin tops and sags between them. Periodic so panels join."""
    t = math.sin(math.pi * (x - 4.0) / 8.0) ** 2
    return 1.38 - 0.95 * t * (0.85 + 0.15 * math.cos(2 * math.pi * y / 16.0))


def deck(mat, x0=-16.0, x1=16.0, y0=-16.0, y1=16.0):
    crown, pan, top = DECK_Z
    return corrugated(y0, y1, x0, x1, crown, pan, top, mat, place=lambda u, v, w: (w, u, v))


def roof_base(P, keep):
    dmat = steel("#5d625f", 0.5, 0.0, seed=15)
    P.add("Body", [purlin(x, steel(TRUSS, 0.45, 1.0, seed=16)) for x in PURLINS])
    xs = [-16 + i for i in range(33)]
    ys = [-16 + 2 * j for j in range(17)]
    P.add("Body", grid_surface(xs, ys, sag, insulation(15), keep))
    return dmat


def flap(x, y, w, ln, mat, seed):
    """A torn strip of insulation hanging down out of a hole."""
    top = sag(x, y)
    o = box((w, 0.05, ln), mat, loc=(x, y, top - ln / 2 + 0.05), rot=(8, 0, 0), r=0.0, n=4)
    crumple(o, 0.12, 0.8, seed)
    return warp(o, lambda v: (v.x, v.y, max(v.z, 0.05)))


@item("roof_panel", "warehouse", size=1024)
def roof_panel(P):
    holes = ((-8.5, 5.0, 3.0, 4.0), (6.0, -9.0, 2.0, 2.0))

    def keep(x, y):
        return not any(abs(x - hx) < hw / 2 and abs(y - hy) < hh / 2 for hx, hy, hw, hh in holes)

    dmat = roof_base(P, keep)
    P.add("Body", deck(dmat))
    ins = insulation(15)
    P.add("Body", flap(-9.6, 3.1, 1.6, 1.1, ins, 1))
    P.add("Body", flap(-7.6, 6.9, 1.2, 0.9, ins, 2))
    P.add("Body", flap(5.6, -9.9, 1.0, 0.8, ins, 3))


@item("roof_skylight", "warehouse", size=1024)
def roof_skylight(P):
    def keep(x, y):
        return not (abs(x) < 4.0 and abs(y) < 8.0)

    dmat = roof_base(P, keep)
    P.add("Body", deck(dmat, -16, -4))
    P.add("Body", deck(dmat, 4, 16))
    P.add("Body", deck(dmat, -4, 4, -16, -8))
    P.add("Body", deck(dmat, -4, 4, 8, 16))
    curb = steel("#4c504e", 0.6, 0.8, seed=17)
    for sx in (-1, 1):
        P.add("Body", box((0.3, 16.0, 1.2), curb, loc=(sx * 3.85, 0, 2.0), r=0.0, n=1))
        P.add("Body", box((7.4, 0.3, 1.2), curb, loc=(0, sx * 7.85, 2.0), r=0.0, n=1))
    gz = 2.5
    bar = steel("#3a3c3b", 0.5, 0.6, seed=18)
    P.add("Body", box((0.14, 15.4, 0.12), bar, loc=(0, 0, gz - 0.1), r=0.0, n=1))
    for y in (-3.85, 0.0, 3.85):
        P.add("Body", box((7.4, 0.14, 0.12), bar, loc=(0, y, gz - 0.1), r=0.0, n=1))
    glass = glow("#a9b7c4", core="#d9e2ea", amount=0.25)
    rng = random.Random(19)
    for ix, x0 in enumerate((-3.7, 0.07)):
        for iy, y0 in enumerate((-7.7, -3.78, 0.07, 3.92)):
            x1, y1 = x0 + 3.63, y0 + 3.78
            pane = (ix, iy)
            if pane in ((0, 1), (1, 3), (1, 0)):
                p = (x0 + 1.1 + rng.random() * 1.4, y0 + 1.1 + rng.random() * 1.6)
                ang = sorted(rng.uniform(0, 360) for _ in range(5))
                polys = shards(x0, x1, y0, y1, p, ang, 0.035)
            elif pane == (1, 2):
                p = ((x0 + x1) / 2 + 0.2, (y0 + y1) / 2 - 0.3)
                ang = [20, 75, 140, 200, 250, 315]
                cut = [1.0 + rng.random() * 0.9 for _ in ang]
                polys = [s for k, s in enumerate(shards(x0, x1, y0, y1, p, ang, 0.04, cut)) if k != 2]
            else:
                polys = [[(x0, y0), (x1, y0), (x1, y1), (x0, y1)]]
            for poly in polys:
                P.add("Glow", flat_poly(poly, 0.06, glass, gz))
    leaf = flat("#1c1a16", ao=0.0)
    for k in range(9):
        x, y = rng.uniform(-3.3, 3.3), rng.uniform(-7.3, 7.3)
        if 0.07 < x < 3.7 and 0.07 < y < 3.85:
            continue
        P.add("Body", flat_poly(blob(x, y, rng.uniform(0.2, 0.55), 0.5, k), 0.02, leaf, gz + 0.02))


# ---------------------------------------------------------------- dock
@item("dock_door", "warehouse", size=1024, pivots={"Door": (0, 0, 12)})
def dock_door(P):
    pier = block(color="#6c6b64", oil=0.3, seed=20)
    for sx in (-1, 1):
        P.add("Body", box((2.0, 1.0, 12.0), pier, loc=(sx * 7.0, 0, 6.0), r=0.04, n=1))
        P.add("Body", box((0.5, 0.5, 5.0), hazard(0.4, seed=20 + sx), loc=(sx * 6.2, -0.26, 2.5), r=0.03, n=1))
        P.add("Body", box((0.12, 0.62, 12.0), steel("#3e4246", 0.5, 0.6, seed=21), loc=(sx * 6.06, -0.2, 6.0), r=0.0, n=1))
        rub = plain("#1d1c1b", grime=0.4, vary=0.2)
        P.add("Body", box((1.6, 0.6, 2.2), rub, loc=(sx * 5.0, 0.8, 1.3), r=0.1, n=1))
        P.add("Body", box((1.2, 0.08, 1.8), rub, loc=(sx * 5.0, 1.06, 1.3), r=0.02, n=1))
    P.add("Body", box((16.0, 1.0, 4.0), concrete("#6e6c66", 0.8, seed=20), loc=(0, 0, 14.0), r=0.04, n=1))
    hood = steel("#4a4e50", 0.6, 1.0, oil=0.3, seed=22)
    P.add("Body", box((13.0, 0.6, 2.4), hood, loc=(0, -0.8, 13.3), r=0.1, n=1))
    P.add("Body", box((3.2, 0.04, 1.1), worn_paint("#a08530", 0.45, 20), loc=(-3.2, -0.51, 15.2), r=0.0, n=1))
    P.add("Body", words("BAY 3", 0.85, worn_paint("#1a1a18", 0.3, 21), loc=(-3.2, -0.535, 15.2), depth=0.02))
    P.add("Body", box((1.0, 0.5, 0.6), plain("#2a2a28", grime=0.3), loc=(4.6, -0.75, 15.3), r=0.08, n=1))
    P.add("Body", box((0.4, 0.06, 0.2), glow("#6a2a20", core="#8a3a2a", amount=0.2), loc=(4.6, -1.02, 15.3), r=0.0, n=1))
    door = sheet("#7d7a6c", rust=0.5, oil=0.5, water=0.4, low=True, seed=23)
    P.add("Door", corrugated(0.0, 12.0, -6.2, 6.2, -0.15, -0.02, 0.15, door, pitch=0.8, place=lambda u, v, w: (w, v, u)))
    P.add("Door", box((12.4, 0.4, 0.3), plain("#1c1b1a", grime=0.4), loc=(0, 0, 0.15), r=0.04, n=1))
    handle = steel("#3a3c3c", 0.6, 0.3, seed=24)
    P.add("Door", [box((0.12, 0.25, 0.12), handle, loc=(x, -0.27, 1.4), r=0.0, n=1) for x in (3.6, 4.4)])
    P.add("Door", box((0.92, 0.12, 0.14), handle, loc=(4.0, -0.4, 1.4), r=0.03, n=1))


# ---------------------------------------------------------------- floors
@item("floor_tile", "warehouse", size=1024)
def floor_tile(P):
    floor_slab(P, floor_concrete(seed=30))


@item("floor_lane", "warehouse", size=1024)
def floor_lane(P):
    floor_slab(P, floor_concrete(seed=31, lane=True))


@item("floor_cracked", "warehouse", size=1024)
def floor_cracked(P):
    floor_slab(P, floor_concrete(seed=32, cracks=True, stain=True))


@item("floor_wet", "warehouse", size=1024)
def floor_wet(P):
    floor_slab(P, floor_concrete(seed=33, wet=True))
    P.add("Wet", flat_poly(blob(-1.0, 1.0, 7.5, 0.35, 33, 36), 0.02, wet_patch(), 0.215))


@item("floor_wood", "warehouse", size=1024)
def floor_wood(P):
    floor_slab(P, wood_floor(34))


@item("floor_carpet", "warehouse", size=1024)
def floor_carpet(P):
    floor_slab(P, carpet(35))


@item("floor_checker", "warehouse", size=1024)
def floor_checker(P):
    floor_slab(P, store_tile(36))


@item("curb", "warehouse", size=1024)
def curb(P):
    coat = paint(SAFETY, chip=0.4, under="#77746c", under2="#5a5852", grime=0.5, streaks=0.35, scale=0.3)
    c = box((32, 1.2, 1.0), coat, loc=(0, 0, 0.5), r=0.08, n=6)

    def chip(v):
        corner = v.z > 0.8 and abs(v.y) > 0.45 and abs(v.x) < 15.5
        k = max(0.0, mnoise.noise((v.x * 0.9, v.y, 2.2)) - 0.1) * 0.35 if corner else 0.0
        return (v.x, v.y * (1 - k * 0.3), v.z - k)

    P.add("Body", warp(c, chip))


@item("ramp", "warehouse", size=1024)
def ramp(P):
    rise, run = 4.0, 16.0
    mat = concrete("#6f6c66", 0.6, seed=38)

    def wedge(v):
        t = (v.y + run / 2) / run
        return (v.x, v.y, (v.z + 0.5) * (0.15 + (rise - 0.15) * t))

    P.add("Body", warp(box((14.0, run, 1.0), mat, loc=(0, 0, 0), r=0.0, n=4), wedge))
    for sx in (-1, 1):
        P.add("Body", warp(box((1.0, run, 1.0), concrete("#6a675f", 0.7, seed=39), loc=(sx * 7.5, 0, 0), r=0.04, n=4),
                           lambda v: (v.x, v.y, (v.z + 0.5) * (0.6 + (rise - 0.15) * (v.y + run / 2) / run))))
        P.add("Body", warp(box((0.98, run - 0.4, 0.3), hazard(0.45, seed=38 + sx), loc=(sx * 7.5, 0.2, 0), r=0.0, n=4),
                           lambda v: (v.x, v.y, v.z + 0.6 + (rise - 0.15) * (v.y + run / 2) / run)))
    for k in range(1, 15):
        y = -run / 2 + k * run / 15
        z = 0.15 + (rise - 0.15) * (y + run / 2) / run
        P.add("Body", box((13.6, 0.12, 0.04), steel("#3c3c3a", 0.6, 0.0, seed=40), loc=(0, y, z + 0.01), rot=(math.degrees(math.atan2(rise - 0.15, run)), 0, 0), r=0.0, n=1))
    P.add("Body", box((14.0, 0.25, 0.2), steel("#3c3c3a", 0.8, 0.0, seed=41), loc=(0, -run / 2 + 0.12, 0.1), r=0.02, n=1))


# ---------------------------------------------------------------- liminal pockets
@item("drop_ceiling", "warehouse", size=1024)
def drop_ceiling(P):
    tmat = ceiling_tile(50)
    bar = plain("#c9c5ba", grime=0.4, vary=0.15)
    missing, dropped, light = (2, 1), (5, 2), (3, 2)
    for i in range(8):
        for j in range(4):
            x, y = -7 + 2 * i, -6 + 4 * j
            if (i, j) in (missing, light):
                continue
            if (i, j) == dropped:
                P.add("Body", box((1.9, 3.9, 0.1), tmat, loc=(x, y - 0.3, 0.75), rot=(-14, 0, 0), r=0.0, n=1))
                continue
            P.add("Body", box((1.94, 3.94, 0.1), tmat, loc=(x, y, 0.17), r=0.0, n=1))
    for k in range(9):
        x = -8 + 2 * k
        w = 0.06 if k in (0, 8) else 0.12
        P.add("Body", box((w, 16, 0.12), bar, loc=(x + (0.03 if k == 0 else -0.03 if k == 8 else 0), 0, 0.06), r=0.0, n=1))
    for k in range(5):
        y = -8 + 4 * k
        d = 0.06 if k in (0, 4) else 0.12
        P.add("Body", box((16, d, 0.1), bar, loc=(0, y + (0.03 if k == 0 else -0.03 if k == 4 else 0), 0.05), r=0.0, n=1))
    lx, ly = -7 + 2 * light[0], -6 + 4 * light[1]
    P.add("Body", box((1.94, 3.94, 0.5), plain("#bdb9ae", grime=0.5), loc=(lx, ly, 0.6), r=0.03, n=1))
    for sx in (-1, 1):
        P.add("Body", box((0.12, 3.94, 0.3), plain("#d8d6ce", grime=0.3), loc=(lx + sx * 0.91, ly, 0.27), r=0.0, n=1))
    P.add("Glow", box((1.7, 3.7, 0.04), glow("#e4eef2", core="#ffffff", amount=0.15), loc=(lx, ly, 0.34), r=0.0, n=1))
    mx, my = -7 + 2 * missing[0], -6 + 4 * missing[1]
    P.add("Body", box((1.94, 3.94, 0.02), flat("#0c0b0a", ao=0.0), loc=(mx, my, 1.4), r=0.0, n=1))


@item("wall_tile", "warehouse", size=1024)
def wall_tile(P):
    P.add("Body", box((16, 1.0, 16), tile_wall(51), loc=(0, 0, 8), r=0.0, n=1))


@item("wall_pastel", "warehouse", size=1024)
def wall_pastel(P):
    P.add("Body", box((16, 0.9, 16), plaster("#e2d4a2", stripe="#c08a3a", seed=52), loc=(0, 0.05, 8), r=0.0, n=1))
    P.add("Body", box((16, 1.0, 0.5), plain("#8a7e66", grime=0.6), loc=(0, 0, 0.25), r=0.03, n=1))


def sky_pixel(u, v):
    top, low, haze = _hexrgb("#5f8fcf"), _hexrgb("#a9c6e6"), _hexrgb("#e3e6e2")
    c = _lerp(haze, low, min(1.0, v * 2.2))
    c = _lerp(c, top, max(0.0, v - 0.45) / 0.55)
    n = mnoise.fractal((u * 3.0, v * 7.0, 0.5), 0.6, 2.2, 4)
    soft = mnoise.noise((u * 1.3, v * 2.0, 4.0))
    cl = max(0.0, min(1.0, (n + soft * 0.5 - 0.15) * 2.2)) * (0.4 + 0.6 * math.sin(math.pi * min(1.0, v * 1.3)))
    c = _lerp(c, _hexrgb("#f4f1ea"), cl)
    return tuple(max(0.0, min(1.0, k * 0.92)) for k in c)


def sign_pixel(u, v):
    c = _hexrgb("#d9d4c6")
    c = _lerp(c, _hexrgb("#9a907c"), max(0.0, mnoise.noise((u * 4, v * 2, 1.0))) * 0.5 + (1 - v) * 0.15)
    return c


@item("wall_sky", "warehouse", size=1024)
def wall_sky(P):
    paint_image(os.path.join(P.dir, "screen.png"), 512, sky_pixel)
    P.add("Body", box((16, 0.94, 16), plaster("#d8d2c4", seed=53), loc=(0, 0.03, 8), r=0.0, n=1))
    P.add("Body", box((16, 1.0, 0.6), plain("#7a7466", grime=0.5), loc=(0, 0, 0.3), r=0.03, n=1))
    P.add("Screen", box((15.6, 0.02, 15.0), flat("#7cb6d8"), loc=(0, -0.48, 8.2), r=0.0, n=1))


@item("wall_windows", "warehouse", size=1024)
def wall_windows(P):
    wall = plaster("#d9cfbc", seed=54)
    frame = plain("#3c3a36", grime=0.4)
    pane = glow("#d8d0a8", core="#f2ecd2", amount=0.3)
    cols, rows, win = (-6.0, -2.0, 2.0, 6.0), (2.0, 6.0, 10.0, 14.0), 2.2
    P.add("Body", box((16, 1.0, rows[0] - win / 2), wall, loc=(0, 0, (rows[0] - win / 2) / 2), r=0.0, n=1))
    for z in rows:
        top = min(z + 4.0 - win / 2, 16.0)
        P.add("Body", box((16, 1.0, top - z - win / 2), wall, loc=(0, 0, (top + z + win / 2) / 2), r=0.0, n=1))
        for x0, x1 in ((-8.0, -7.1), (-4.9, -3.1), (-0.9, 0.9), (3.1, 4.9), (7.1, 8.0)):
            P.add("Body", box((x1 - x0, 1.0, win), wall, loc=((x0 + x1) / 2, 0, z), r=0.0, n=1))
        for x in cols:
            for s in (-1, 1):
                P.add("Body", box((0.12, 0.6, win), frame, loc=(x + s * (win / 2 - 0.06), 0, z), r=0.0, n=1))
                P.add("Body", box((win, 0.6, 0.12), frame, loc=(x, 0, z + s * (win / 2 - 0.06)), r=0.0, n=1))
            P.add("Body", box((win + 0.4, 0.3, 0.14), wall, loc=(x, -0.35, z - win / 2 - 0.07), r=0.03, n=1))
            P.add("Body", box((0.08, 0.1, win), frame, loc=(x, 0.05, z), r=0.0, n=1))
            P.add("Body", box((win, 0.1, 0.08), frame, loc=(x, 0.05, z), r=0.0, n=1))
            P.add("Glow", box((win - 0.2, 0.04, win - 0.2), pane, loc=(x, 0.12, z), r=0.0, n=1))


@item("shutter_front", "warehouse", size=1024, pivots={"Door": (0, 0, 11)})
def shutter_front(P):
    pier = tile_wall(55)
    for sx in (-1, 1):
        P.add("Body", box((1.5, 0.9, 11.0), pier, loc=(sx * 7.25, 0.05, 5.5), r=0.04, n=1))
        P.add("Body", box((0.15, 0.4, 11.0), steel("#5a5c5c", 0.5, 0.6, seed=55), loc=(sx * 6.45, 0, 5.5), r=0.0, n=1))
    P.add("Body", box((16, 0.9, 5.0), plaster("#cfc8b8", seed=55), loc=(0, 0.05, 13.5), r=0.0, n=1))
    P.add("Body", box((13.0, 0.5, 1.2), steel("#6a6c6a", 0.5, 0.9, seed=56), loc=(0, -0.15, 11.6), r=0.06, n=1))
    paint_image(os.path.join(P.dir, "screen.png"), 256, sign_pixel)
    P.add("Body", box((14.6, 0.08, 2.8), plain("#2a2a28", grime=0.3), loc=(0, -0.42, 13.9), r=0.02, n=1))
    P.add("Screen", box((14.0, 0.02, 2.3), flat("#d9d4c6"), loc=(0, -0.49, 13.9), r=0.0, n=1))
    grille = steel("#8a8c88", 0.45, 0.4, seed=57)
    W = 13.0
    for k in range(22):
        z = 0.35 + k * 0.5
        P.add("Door", box((W, 0.1, 0.06), grille, loc=(0, 0, z), r=0.0, n=1))
    for k in range(27):
        x = -W / 2 + 0.25 + k * 0.5 * (W - 0.5) / 13.0
        P.add("Door", box((0.05, 0.08, 10.7), grille, loc=(x, 0, 5.65), r=0.0, n=1))
    P.add("Door", box((W, 0.3, 0.3), steel("#4a4c4a", 0.6, 0.4, seed=58), loc=(0, 0, 0.15), r=0.03, n=1))
    P.add("Door", box((0.6, 0.32, 0.4), steel("#2c2c2a", 0.6, 0.0, seed=59), loc=(3.2, 0, 0.3), r=0.04, n=1))


@item("floor_checker_color", "warehouse", size=1024)
def floor_checker_color(P):
    floor_slab(P, color_checker(60))


@item("floor_pool", "warehouse", size=1024)
def floor_pool(P):
    floor_slab(P, pool_tile(61))
    P.add("Body", flat_poly(blob(1.0, -1.0, 11.0, 0.18, 61, 40), 0.05, water(), 0.25))


@item("floor_grass", "warehouse", size=1024)
def floor_grass(P):
    floor_slab(P, turf(62), 0.3)


# ---------------------------------------------------------------- installations (dark halls, lit dreamcore rooms)
@item("floor_marble", "warehouse", size=1024)
def floor_marble(P):
    floor_slab(P, marble(70))


@item("floor_carpet_blue", "warehouse", size=1024)
def floor_carpet_blue(P):
    floor_slab(P, carpet_blue(71))


@item("floor_carpet_wild", "warehouse", size=1024)
def floor_carpet_wild(P):
    floor_slab(P, carpet_wild(72))


@item("wall_curved", "warehouse", size=1024)
def wall_curved(P):
    """Quarter-round wall. The convex face is a radius 16 arc around the back corner (8, 8)."""
    rings = []
    n = 24
    for z in (0.0, 16.0):
        outer = [(8 - 16 * math.cos(math.pi / 2 * k / n), 8 - 16 * math.sin(math.pi / 2 * k / n), z) for k in range(n + 1)]
        inner = [(8 - 15 * math.cos(math.pi / 2 * k / n), 8 - 15 * math.sin(math.pi / 2 * k / n), z) for k in range(n, -1, -1)]
        rings.append(outer + inner)
    P.add("Body", loft(rings, lime_plaster(73), smooth=40))


@item("floor_hatch", "warehouse", size=1024, pivots={"Door": (0, 2.7, 6.39)})
def floor_hatch(P):
    """A 32 floor tile with a 5 x 5 hatch down a 6-deep shaft. Floor top is 6.2 above the origin."""
    depth, hole = 6.0, 5.0
    floor = floor_concrete(seed=74)
    side = (32 - hole) / 2
    for sx in (-1, 1):
        P.add("Body", move(tray(side, 32, 0.2, floor), loc=(sx * (hole / 2 + side / 2), 0, depth)))
        P.add("Body", move(tray(hole, side, 0.2, floor), loc=(0, sx * (hole / 2 + side / 2), depth)))
    liner = wood("#8a6a48", "#5a4430", axis="z", wear=0.3)
    for sx in (-1, 1):
        P.add("Body", box((0.2, hole, depth), liner, loc=(sx * (hole / 2 - 0.1), 0, depth / 2), r=0.0, n=1))
        P.add("Body", box((hole - 0.4, 0.2, depth), liner, loc=(0, sx * (hole / 2 - 0.1), depth / 2), r=0.0, n=1))
    P.add("Body", box((hole, hole, 0.1), flat("#0c0b0a", ao=0.0), loc=(0, 0, 0.05), r=0.0, n=1))
    collar = hazard(0.4, seed=74)
    for sx in (-1, 1):
        P.add("Body", box((0.4, hole + 0.8, 0.12), collar, loc=(sx * (hole / 2 + 0.2), 0, depth + 0.26), r=0.02, n=1))
        P.add("Body", box((hole, 0.4, 0.12), collar, loc=(0, sx * (hole / 2 + 0.2), depth + 0.26), r=0.02, n=1))
    rail = steel("#8c8e8a", 0.4, 0.5, seed=75)
    for sx in (-1, 1):
        P.add("Body", box((0.16, 0.3, depth - 0.2), rail, loc=(sx * 0.9, -hole / 2 + 0.45, depth / 2), r=0.0, n=1))
    for k in range(8):
        P.add("Body", box((1.8, 0.14, 0.1), rail, loc=(0, -hole / 2 + 0.45, 0.6 + k * 0.7), r=0.0, n=1))
    for sx in (-1, 1):
        P.add("Body", box((0.3, 0.3, 0.2), rail, loc=(sx * 1.6, hole / 2 + 0.25, depth + 0.3), r=0.03, n=1))
    lid = diamond_plate(76)
    P.add("Door", box((hole + 0.4, hole + 0.4, 0.14), lid, loc=(0, 0, depth + 0.39), r=0.03, n=1))
    P.add("Door", box((1.2, 0.12, 0.12), rail, loc=(0, -hole / 2 + 0.4, depth + 0.52), r=0.03, n=1))
    P.add("Door", [box((0.12, 0.12, 0.1), rail, loc=(x, -hole / 2 + 0.4, depth + 0.48), r=0.0, n=1) for x in (-0.55, 0.55)])


@item("stair_flight", "warehouse", size=1024)
def stair_flight(P):
    """Carpeted stairs, 8 wide, 16 steps of 0.5 up and 1 deep, rising toward +y."""
    steps, rise, tread, w = 16, 0.5, 1.0, 8.0
    run = steps * tread
    prof = [(-run / 2, 0.0)]
    for k in range(steps):
        prof += [(-run / 2 + k * tread, (k + 1) * rise), (-run / 2 + (k + 1) * tread, (k + 1) * rise)]
    prof += [(run / 2, 0.0)]
    P.add("Body", slab(prof, w, stair_carpet(77), rot=(0, 0, 90)))
    oak = wood("#9a6a3c", "#5a3a20", axis="x", wear=0.4)
    for k in range(0, steps + 1, 4):
        k = min(k, steps - 1)
        y = -run / 2 + (k + 0.5) * tread
        P.add("Body", box((0.2, 0.2, 3.0), oak, loc=(3.7, y, (k + 1) * rise + 1.5), r=0.03, n=1))
    ang = math.degrees(math.atan2(rise, tread))
    ln = math.hypot(run, steps * rise)
    P.add("Body", box((0.3, ln - 0.6, 0.22), oak, loc=(3.7, 0, (steps * rise) / 2 + 0.5 + 2.95), rot=(ang, 0, 0), r=0.06, n=1))


main()
