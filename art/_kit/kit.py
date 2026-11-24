"""The creepy robot kit for Year 2029. Robot takes folder= and max_h=.
Shared kit for the creepy robots. Run a robot with:
    /opt/homebrew/bin/blender -b --factory-startup -P art/robots/creepy/<name>/build.py

Space: 1 unit = 1 stud. +z up, the robot faces -y, floor at z = 0.
The robot's RIGHT side is -x (the viewer's left). Same as the game once imported.
Every prim returns a joined-ready object with its transform already applied. Give it to
Robot.add(part, *objs). Angles are degrees. Colors are "#rrggbb".
"""
import bpy, bmesh, math, os, random, sys
from mathutils import Vector, Matrix, Euler, noise
from mathutils.bvhtree import BVHTree

V = Vector
_mats = {}


def wipe():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()


def lin(hexcol):
    h = hexcol.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i : i + 2], 16) / 255
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, 1)


# ---------------------------------------------------------------- materials (baked to one texture)
class G:
    """Tiny node graph helper. Everything ends in one emission, so a bake is just color."""

    def __init__(self, name):
        self.m = bpy.data.materials.new(name)
        self.m.use_nodes = True
        self.t = self.m.node_tree
        self.t.nodes.clear()
        a = self.n("ShaderNodeAttribute")
        a.attribute_name = "lp"
        self.lp = a.outputs["Vector"]
        g = self.n("ShaderNodeAttribute")
        g.attribute_name = "g"
        self.g = g.outputs["Fac"]
        self.geo = self.n("ShaderNodeNewGeometry")

    def n(self, kind):
        return self.t.nodes.new(kind)

    def put(self, sock, val):
        if isinstance(val, bpy.types.NodeSocket):
            self.t.links.new(val, sock)
        elif isinstance(val, str):
            sock.default_value = lin(val)
        else:
            sock.default_value = val

    def math(self, op, a, b=0.0, clamp=False):
        x = self.n("ShaderNodeMath")
        x.operation = op
        x.use_clamp = clamp
        self.put(x.inputs[0], a)
        self.put(x.inputs[1], b)
        return x.outputs[0]

    def step(self, v, lo, hi):
        x = self.n("ShaderNodeMapRange")
        x.interpolation_type = "SMOOTHSTEP"
        self.put(x.inputs[0], v)
        x.inputs[1].default_value = lo
        x.inputs[2].default_value = hi
        return x.outputs[0]

    def mix(self, f, a, b, blend="MIX"):
        x = self.n("ShaderNodeMix")
        x.data_type = "RGBA"
        x.blend_type = blend
        self.put(x.inputs[0], f)
        self.put(x.inputs[6], a)
        self.put(x.inputs[7], b)
        return x.outputs[2]

    def vec(self, scale=(1, 1, 1), world=False):
        x = self.n("ShaderNodeMapping")
        self.t.links.new(self.geo.outputs["Position"] if world else self.lp, x.inputs[0])
        x.inputs["Scale"].default_value = scale
        return x.outputs[0]

    def noise(self, scale=4, detail=4, stretch=(1, 1, 1), rough=0.6, world=False):
        x = self.n("ShaderNodeTexNoise")
        x.inputs["Scale"].default_value = scale
        x.inputs["Detail"].default_value = detail
        x.inputs["Roughness"].default_value = rough
        self.t.links.new(self.vec(stretch, world), x.inputs["Vector"])
        return x.outputs[0]

    def edge(self, radius=0.07):
        b = self.n("ShaderNodeBevel")
        b.samples = 8
        b.inputs[0].default_value = radius
        d = self.n("ShaderNodeVectorMath")
        d.operation = "DOT_PRODUCT"
        self.t.links.new(b.outputs[0], d.inputs[0])
        self.t.links.new(self.geo.outputs["Normal"], d.inputs[1])
        return self.math("SUBTRACT", 1.0, d.outputs["Value"])

    def done(self, color, ao=0.85, top=0.22, dist=0.6):
        if DUST and self.m.name.split(".")[0] not in ("glow", "flat"):
            color = self.mix(0.16 * DUST, color, "#b9b2a6")  # sun faded, a bit grey
            s = self.n("ShaderNodeSeparateXYZ")
            self.t.links.new(self.geo.outputs["Normal"], s.inputs[0])
            settled = self.math("MULTIPLY", self.step(s.outputs[2], 0.35, 0.95), self.step(self.noise(5, 6, world=True), 0.3, 0.68))
            patchy = self.math("MULTIPLY", self.step(self.noise(1.6, 3, world=True), 0.5, 0.8), 0.14)
            color = self.mix(self.math("MULTIPLY", self.math("ADD", settled, patchy), 0.6 * DUST, clamp=True), color, "#cfc8ba")
        if top:
            s = self.n("ShaderNodeSeparateXYZ")
            self.t.links.new(self.geo.outputs["Normal"], s.inputs[0])
            k = self.math("ADD", self.math("MULTIPLY", s.outputs[2], top), 1.0 - top * 0.15)
            color = self.mix(1.0, color, k, "MULTIPLY")
        if ao:
            a = self.n("ShaderNodeAmbientOcclusion")
            a.samples = 8
            a.inputs["Distance"].default_value = dist
            k = self.math("POWER", a.outputs["AO"], 1.3)
            color = self.mix(ao, color, self.mix(k, "#1a1420", "#ffffff"), "MULTIPLY")
        e = self.n("ShaderNodeEmission")
        self.put(e.inputs[0], color)
        o = self.n("ShaderNodeOutputMaterial")
        self.t.links.new(e.outputs[0], o.inputs[0])
        return self.m


def cached(fn):
    def wrap(*a, **k):
        key = fn.__name__ + repr(a) + repr(sorted(k.items()))
        if key not in _mats:
            _mats[key] = fn(*a, **k)
        return _mats[key]

    return wrap


@cached
def paint(color, chip=0.35, under="#5b3a26", under2="#2d2420", grime=0.45, streaks=0.4, scale=1.0):
    """Old chipped paint over rust. chip 0 = fresh, 1 = wrecked. The main look of our robots."""
    g = G("paint")
    tone = g.mix(g.math("MULTIPLY", g.step(g.noise(1.6 * scale, 5), 0.35, 0.75), 0.35), color,
                 g.mix(0.5, color, "#f4e6c8"))
    rust = g.mix(g.step(g.noise(9 * scale, 5), 0.38, 0.62), under2, under)
    e = g.math("MULTIPLY", g.edge(0.09), 5.0)
    flake = g.math("ADD", g.noise(3.4 * scale, 8, rough=0.68), g.math("MULTIPLY", e, 0.32))
    fine = g.math("MULTIPLY", g.noise(16 * scale, 3), 0.12)
    thr = 0.75 - chip * 0.27
    mask = g.step(g.math("ADD", flake, fine), thr, thr + 0.03)
    rim = g.step(g.math("ADD", flake, fine), thr - 0.05, thr)
    c = g.mix(g.math("MULTIPLY", rim, 0.35), tone, g.mix(0.6, color, under2))
    c = g.mix(g.math("MULTIPLY", mask, 1.0 if chip > 0 else 0.0), c, rust)
    if grime:
        d = g.step(g.noise(2.2 * scale, 6, world=True), 0.46, 0.72)
        c = g.mix(g.math("MULTIPLY", d, grime), c, "#4a3a2c", "MULTIPLY")
    if streaks:
        s = g.step(g.noise(5 * scale, 4, (1, 1, 0.09)), 0.58, 0.72)
        c = g.mix(g.math("MULTIPLY", s, streaks), c, "#5a4030", "MULTIPLY")
    return g.done(c)


@cached
def metal(color="#7d7a78", rust=0.45):
    g = G("metal")
    base = g.mix(g.step(g.noise(6, 6, (1, 1, 0.3)), 0.3, 0.7), color, g.mix(0.45, color, "#2a2624"))
    r = g.mix(g.step(g.noise(14, 4), 0.4, 0.65), "#5a2f18", "#9a5426")
    e = g.math("MULTIPLY", g.edge(0.05), 2.5)
    c = g.mix(g.step(g.noise(3.2, 8, rough=0.7), 0.74 - rust * 0.3, 0.8 - rust * 0.25), base, r)
    c = g.mix(g.math("MULTIPLY", g.math("MINIMUM", e, 1.0), 0.45), c, "#d8d4cc")
    return g.done(c)


@cached
def wood(color="#9a6a3c", dark="#4d2f1a", axis="z", wear=0.5):
    g = G("wood")
    st = {"z": (6, 6, 0.5), "x": (0.5, 6, 6), "y": (6, 0.5, 6)}[axis]
    grain = g.noise(2.2, 8, st, 0.7)
    c = g.mix(g.step(grain, 0.36, 0.66), dark, color)
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(1.3, 3), 0.4, 0.7), 0.35), c, g.mix(0.5, color, "#f0d8ac"))
    e = g.math("MULTIPLY", g.math("MINIMUM", g.math("MULTIPLY", g.edge(0.08), 4.0), 1.0), wear)
    c = g.mix(g.math("MULTIPLY", e, g.step(g.noise(7, 4), 0.35, 0.6)), c, "#d9b684")
    return g.done(c)


@cached
def cardboard(color="#b58a5a"):
    g = G("cardboard")
    c = g.mix(g.step(g.noise(3, 8), 0.35, 0.7), color, g.mix(0.4, color, "#6b4a2c"))
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(11, 2, (1, 1, 0.04)), 0.45, 0.6), 0.25), c, "#7d5a36")
    return g.done(c)


@cached
def cloth(color, dirt=0.4, weave=60, dirtcolor="#4a3d30"):
    """Canvas, felt, sneaker fabric. dirt climbs up from the bottom of the piece."""
    g = G("cloth")
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(weave, 2), 0.35, 0.65), 0.3), color, g.mix(0.5, color, "#1c1820"))
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(2.5, 5), 0.4, 0.75), 0.3), c, g.mix(0.5, color, "#f2e8d8"))
    low = g.math("SUBTRACT", 1.0, g.g)
    d = g.step(g.math("ADD", g.math("MULTIPLY", low, 0.55), g.math("MULTIPLY", g.noise(4, 6), 0.75)), 0.62, 0.95)
    c = g.mix(g.math("MULTIPLY", d, dirt), c, dirtcolor)
    return g.done(c)


@cached
def plain(color, grime=0.35, vary=0.25, ao=0.85):
    """Plastic, rubber, enamel, icing, anything smooth. Slightly uneven and grubby."""
    g = G("plain")
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(2.5, 5), 0.35, 0.75), vary), color, g.mix(0.55, color, "#fff2dc"))
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(3.5, 6, world=True), 0.45, 0.75), grime), c, "#6a5646", "MULTIPLY")
    return g.done(c, ao=ao)


@cached
def flat(color, ao=0.5):
    """No wear at all. For pupils, dark mouth insides, doodles."""
    return G("flat").done(color, ao=ao, top=0.0)


@cached
def glow(color, core="#ffffff", amount=0.3):
    """Bright, no shadows baked in. For bulbs, flames, glowing eyes."""
    g = G("glow")
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(3, 2), 0.3, 0.7), amount), color, core)
    return g.done(c, ao=0.0, top=0.0)


@cached
def fade(bottom, top, lo=0.2, hi=0.8, ao=0.8, grime=0.2):
    """Two colors up the height of the piece (its own local z)."""
    g = G("fade")
    c = g.mix(g.step(g.math("ADD", g.g, g.math("MULTIPLY", g.math("SUBTRACT", g.noise(5, 4), 0.5), 0.3)), lo, hi), bottom, top)
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(3.5, 6), 0.45, 0.75), grime), c, "#6a5646", "MULTIPLY")
    return g.done(c, ao=ao)


@cached
def toothmat(color="#efe3c4", root="#8a6a3a"):
    """Root at g=0, tip at g=1 (the tooth prim sets g that way)."""
    g = G("tooth")
    c = g.mix(g.step(g.math("ADD", g.g, g.math("MULTIPLY", g.math("SUBTRACT", g.noise(7, 4), 0.5), 0.4)), 0.0, 0.5), root, color)
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(5, 5, (1, 1, 0.3)), 0.55, 0.7), 0.35), c, "#a88a52", "MULTIPLY")
    return g.done(c, ao=0.7)


@cached
def eyewhite(color="#efe9dc", pink="#d4828a", veins=0.6):
    """Front of the eyeball is local -y. Pink and veins toward the back."""
    g = G("eyewhite")
    nrm = g.n("ShaderNodeVectorMath")
    nrm.operation = "NORMALIZE"
    g.t.links.new(g.lp, nrm.inputs[0])
    s = g.n("ShaderNodeSeparateXYZ")
    g.t.links.new(nrm.outputs[0], s.inputs[0])
    back = g.step(s.outputs[1], -0.9, -0.1)
    vo = g.n("ShaderNodeTexVoronoi")
    vo.feature = "DISTANCE_TO_EDGE"
    vo.inputs["Scale"].default_value = 3.2
    wob = g.n("ShaderNodeVectorMath")
    wob.operation = "ADD"
    g.t.links.new(nrm.outputs[0], wob.inputs[0])
    no = g.n("ShaderNodeTexNoise")
    no.inputs["Scale"].default_value = 4
    g.t.links.new(nrm.outputs[0], no.inputs["Vector"])
    sc = g.n("ShaderNodeVectorMath")
    sc.operation = "SCALE"
    sc.inputs["Scale"].default_value = 0.35
    g.t.links.new(no.outputs[1], sc.inputs[0])
    g.t.links.new(sc.outputs[0], wob.inputs[1])
    g.t.links.new(wob.outputs[0], vo.inputs["Vector"])
    vein = g.math("SUBTRACT", 1.0, g.step(vo.outputs[0], 0.01, 0.07))
    c = g.mix(g.math("MULTIPLY", back, 0.7), color, pink)
    c = g.mix(g.math("MULTIPLY", g.math("MULTIPLY", vein, g.step(s.outputs[1], -0.88, -0.45)), veins), c, "#b8424c")
    return g.done(c, ao=0.6, top=0.1)


# ---------------------------------------------------------------- mesh plumbing
def _finish(bm, mat, loc=(0, 0, 0), rot=(0, 0, 0), scl=(1, 1, 1), smooth=40, gvals=None, flip=False):
    if isinstance(scl, (int, float)):
        scl = (scl,) * 3
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if flip:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    me = bpy.data.meshes.new("p")
    bm.to_mesh(me)
    bm.free()
    co = [v.co.copy() for v in me.vertices]
    lo = min((c.z for c in co), default=0)
    hi = max((c.z for c in co), default=1)
    lp = me.attributes.new("lp", "FLOAT_VECTOR", "POINT")
    ga = me.attributes.new("g", "FLOAT", "POINT")
    for i, c in enumerate(co):
        lp.data[i].vector = V((c.x * scl[0], c.y * scl[1], c.z * scl[2]))
        ga.data[i].value = gvals(c) if gvals else (c.z - lo) / max(hi - lo, 1e-6)
    me.transform(Matrix.LocRotScale(V(loc), Euler([math.radians(a) for a in rot]), V(scl)))
    if scl[0] * scl[1] * scl[2] < 0:
        me.flip_normals()
    for p in me.polygons:
        p.use_smooth = True
    me.set_sharp_from_angle(angle=math.radians(smooth))
    ob = bpy.data.objects.new("p", me)
    bpy.context.scene.collection.objects.link(ob)
    if mat:
        me.materials.append(mat)
    return ob


def move(ob, loc=(0, 0, 0), rot=(0, 0, 0), scl=(1, 1, 1), pivot=(0, 0, 0)):
    """Moves an already built prim about a pivot point. Works on lists too. Returns what it got."""
    if isinstance(ob, (list, tuple)):
        for o in ob:
            move(o, loc, rot, scl, pivot)
        return ob
    if isinstance(scl, (int, float)):
        scl = (scl,) * 3
    p = V(pivot)
    m = Matrix.Translation(V(loc) + p) @ Matrix.LocRotScale(None, Euler([math.radians(a) for a in rot]), V(scl)) @ Matrix.Translation(-p)
    ob.data.transform(m)
    if scl[0] * scl[1] * scl[2] < 0:
        ob.data.flip_normals()
    return ob


def copy(ob):
    if isinstance(ob, (list, tuple)):
        return [copy(o) for o in ob]
    o = ob.copy()
    o.data = ob.data.copy()
    bpy.context.scene.collection.objects.link(o)
    return o


def mirror(ob):
    """Copy across x=0."""
    c = copy(ob)
    move(c, scl=(-1, 1, 1))
    return c


def crumple(ob, amount=0.06, scale=1.2, seed=0):
    """Lumpy dents so nothing looks machine made. Needs some geometry to bend."""
    if isinstance(ob, (list, tuple)):
        for o in ob:
            crumple(o, amount, scale, seed)
        return ob
    off = V((seed * 7.3, seed * 3.1, seed * 5.7))
    for v in ob.data.vertices:
        v.co += noise.noise_vector(v.co * scale + off) * amount
    return ob


def warp(ob, fn):
    """fn(Vector) -> Vector on every vertex. Bend, taper, lean, squash a shape with it."""
    if isinstance(ob, (list, tuple)):
        for o in ob:
            warp(o, fn)
        return ob
    for v in ob.data.vertices:
        v.co = V(fn(v.co.copy()))
    return ob


def front(obs, x, z, y0=-30):
    """Where a straight line from the front hits these objects: (point, normal). To stick things on."""
    best = None
    for o in obs if isinstance(obs, (list, tuple)) else [obs]:
        t = BVHTree.FromPolygons([v.co for v in o.data.vertices], [p.vertices for p in o.data.polygons])
        loc, nor, _, d = t.ray_cast(V((x, y0, z)), V((0, 1, 0)))
        if loc is not None and (best is None or d < best[2]):
            best = (loc, nor if nor.y < 0 else -nor, d)
    return (best[0], best[1]) if best else (V((x, 0, z)), V((0, -1, 0)))


def aim(ob, at, normal):
    """Turns a prim built facing -y at the origin to face along normal, and puts it at a point."""
    n = V(normal).normalized()
    q = V((0, -1, 0)).rotation_difference(n)
    m = Matrix.Translation(V(at)) @ q.to_matrix().to_4x4()
    for o in ob if isinstance(ob, (list, tuple)) else [ob]:
        o.data.transform(m)
    return ob


def bez(points, per=6):
    """Smooth curve through points (Catmull-Rom). Returns a list of Vectors."""
    P = [V(p) for p in points]
    if len(P) < 3:
        return P
    P = [2 * P[0] - P[1]] + P + [2 * P[-1] - P[-2]]
    out = []
    for i in range(1, len(P) - 2):
        a, b, c, d = P[i - 1 : i + 3]
        for k in range(per):
            t = k / per
            out.append(0.5 * ((2 * b) + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (3 * b - a - 3 * c + d) * t ** 3))
    out.append(P[-2])
    return out


# ---------------------------------------------------------------- prims
def box(size, mat, loc=(0, 0, 0), rot=(0, 0, 0), r=0.08, n=2, smooth=50, **k):
    """Rounded box. r = corner radius, n = grid cuts per face (more = can dent/warp nicely).
    n=1 costs 108 triangles, n=2 432, n=4 768, n=6 1200."""
    hx, hy, hz = (s / 2 for s in size)
    r = min(r, hx, hy, hz)

    def grid(h):
        inner = [-(h - r) + (2 * (h - r)) * i / n for i in range(n + 1)] if h - r > 1e-5 else [0.0]
        if r <= 1e-4:
            return inner
        return [-h] + inner + [h] if n == 1 else [-h, -h + r * 0.35] + inner + [h - r * 0.35, h]

    bm = bmesh.new()
    gx, gy, gz = grid(hx), grid(hy), grid(hz)
    cache = {}

    def vert(p):
        q = V((max(-(hx - r), min(hx - r, p[0])), max(-(hy - r), min(hy - r, p[1])), max(-(hz - r), min(hz - r, p[2]))))
        d = V(p) - q
        co = q + d.normalized() * r if d.length > 1e-6 and r > 1e-4 else V(p)
        key = tuple(round(c, 4) for c in co)
        if key not in cache:
            cache[key] = bm.verts.new(co)
        return cache[key]

    def face(A, B, f):
        for i in range(len(A) - 1):
            for j in range(len(B) - 1):
                vs = []
                for v in (vert(f(A[i], B[j])), vert(f(A[i + 1], B[j])), vert(f(A[i + 1], B[j + 1])), vert(f(A[i], B[j + 1]))):
                    if v not in vs:
                        vs.append(v)
                if len(vs) > 2:
                    try:
                        bm.faces.new(vs)
                    except ValueError:
                        pass

    for s in (-1, 1):
        face(gx, gz, lambda a, b: (a, s * hy, b))
        face(gx, gy, lambda a, b: (a, b, s * hz))
        face(gy, gz, lambda a, b: (s * hx, a, b))
    return _finish(bm, mat, loc, rot, smooth=smooth, **k)


def ball(r, mat, loc=(0, 0, 0), rot=(0, 0, 0), seg=16, rings=10, **k):
    """r is a number or (rx, ry, rz)."""
    s = (r, r, r) if isinstance(r, (int, float)) else r
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1)
    return _finish(bm, mat, loc, rot, s, smooth=80, **k)


def lathe(profile, mat, loc=(0, 0, 0), rot=(0, 0, 0), scl=(1, 1, 1), seg=24, lobes=0, lobe=0.0, smooth=35, **k):
    """Spin [(radius, z), ...] bottom to top around z. Radius 0 ends close it. lobes/lobe = ribs."""
    bm = bmesh.new()
    rings = []
    for rad, z in profile:
        if rad < 1e-5:
            rings.append([bm.verts.new((0, 0, z))])
            continue
        ring = []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            q = rad * (1 - lobe * (1 - abs(math.sin(a * lobes / 2)) ** 0.6)) if lobes else rad
            ring.append(bm.verts.new((q * math.cos(a), q * math.sin(a), z)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            vs = []
            for v in (a[i % len(a)], a[j % len(a)], b[j % len(b)], b[i % len(b)]):
                if v not in vs:
                    vs.append(v)
            if len(vs) > 2:
                bm.faces.new(vs)
    return _finish(bm, mat, loc, rot, scl, smooth=smooth, **k)


def cyl(r, h, mat, loc=(0, 0, 0), rot=(0, 0, 0), r2=None, seg=20, bevel=0.04, rows=1, **k):
    """Cylinder or cone along z, centered. r bottom, r2 top, soft bevel."""
    r2 = r if r2 is None else r2
    b = min(bevel, h / 2, r * 0.9 or 1)
    prof = [(0, -h / 2), (max(r - b, 0.001), -h / 2)]
    for i in range(rows + 1):
        t = i / rows
        prof.append((r + (r2 - r) * t, -h / 2 + b + (h - 2 * b) * t))
    prof += [(max(r2 - b, 0.001), h / 2), (0, h / 2)]
    return lathe(prof, mat, loc, rot, seg=seg, **k)


def torus(R, r, mat, loc=(0, 0, 0), rot=(0, 0, 0), seg=24, sub=8, scl=(1, 1, 1), **k):
    """Ring around z."""
    bm = bmesh.new()
    rings = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        rings.append([bm.verts.new(((R + r * math.cos(b)) * math.cos(a), (R + r * math.cos(b)) * math.sin(a), r * math.sin(b)))
                      for b in (2 * math.pi * j / sub for j in range(sub))])
    for i in range(seg):
        for j in range(sub):
            A, B = rings[i], rings[(i + 1) % seg]
            bm.faces.new((A[j], B[j], B[(j + 1) % sub], A[(j + 1) % sub]))
    return _finish(bm, mat, loc, rot, scl, smooth=80, **k)


def tube(points, radius, mat, seg=8, smooth_path=True, per=5, ends=True, flatten=1.0, **k):
    """Round tube through points. radius is a number or a list (one per given point). Round ends."""
    path = bez(points, per) if smooth_path else [V(p) for p in points]
    n = len(path)
    if isinstance(radius, (int, float)):
        rad = [radius] * n
    else:
        rad = []
        for i in range(n):
            t = i / (n - 1) * (len(radius) - 1)
            a = min(int(t), len(radius) - 2)
            rad.append(radius[a] + (radius[a + 1] - radius[a]) * (t - a))
    if ends:
        d0 = (path[0] - path[1]).normalized()
        d1 = (path[-1] - path[-2]).normalized()
        path = [path[0] + d0 * rad[0] * 0.8, path[0] + d0 * rad[0] * 0.5] + path + [path[-1] + d1 * rad[-1] * 0.5, path[-1] + d1 * rad[-1] * 0.8]
        rad = [rad[0] * 0.45, rad[0] * 0.85] + rad + [rad[-1] * 0.85, rad[-1] * 0.45]
    bm = bmesh.new()
    rings = []
    up = V((0, 1, 0.01))
    for i, p in enumerate(path):
        t = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        side = t.cross(up)
        if side.length < 1e-3:
            side = t.cross(V((1, 0, 0)))
        side.normalize()
        up = side.cross(t).normalized()
        rings.append([bm.verts.new(p + (side * math.cos(a) + up * math.sin(a) * flatten) * rad[i])
                      for a in (2 * math.pi * j / seg for j in range(seg))])
    for A, B in zip(rings, rings[1:]):
        for j in range(seg):
            bm.faces.new((A[j], A[(j + 1) % seg], B[(j + 1) % seg], B[j]))
    bm.faces.new(rings[0])
    bm.faces.new(rings[-1])
    return _finish(bm, mat, smooth=60, **k)


def spring(a, b, R, r, mat, turns=5, seg=4, per=8):
    a, b = V(a), V(b)
    d = b - a
    q = V((0, 0, 1)).rotation_difference(d.normalized())
    pts = [a + q @ V((R * math.cos(t), R * math.sin(t), d.length * t / (2 * math.pi * turns)))
           for t in (2 * math.pi * i / per for i in range(turns * per + 1))]
    return tube(pts, r, mat, seg=seg, smooth_path=False)


def slab(poly, depth, mat, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.0, **k):
    """Flat cut-out shape [(x, z), ...] in the x-z plane, thick along y. Front face at y = -depth/2."""
    bm = bmesh.new()
    A = [bm.verts.new((x, -depth / 2, z)) for x, z in poly]
    B = [bm.verts.new((x, depth / 2, z)) for x, z in poly]
    f = bm.faces.new(A)
    bm.faces.new(list(reversed(B)))
    for i in range(len(poly)):
        j = (i + 1) % len(poly)
        bm.faces.new((A[i], B[i], B[j], A[j]))
    if bevel:
        bmesh.ops.bevel(bm, geom=list(f.edges), offset=bevel, segments=2, affect="EDGES")
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    return _finish(bm, mat, loc, rot, smooth=35, **k)


def loft(rings, mat, loc=(0, 0, 0), rot=(0, 0, 0), smooth=50, cap=True, **k):
    """Skin over a list of rings (each a list of points, same count)."""
    bm = bmesh.new()
    R = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(R[0])
    for A, B in zip(R, R[1:]):
        for j in range(n):
            bm.faces.new((A[j], A[(j + 1) % n], B[(j + 1) % n], B[j]))
    if cap:
        bm.faces.new(R[0])
        bm.faces.new(R[-1])
        bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    return _finish(bm, mat, loc, rot, smooth=smooth, **k)


def words(text, size, mat, loc=(0, 0, 0), rot=(0, 0, 0), depth=0.02, res=1):
    """Text in the x-z plane facing -y, centered. About 60 to 100 triangles a letter: keep it short."""
    cu = bpy.data.curves.new("t", "FONT")
    cu.body = text
    cu.size = size
    cu.extrude = depth / 2
    cu.resolution_u = res
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    tmp = bpy.data.objects.new("t", cu)
    bpy.context.scene.collection.objects.link(tmp)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bm = bmesh.new()
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    bm.from_mesh(me)
    bpy.data.objects.remove(tmp)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Euler((math.radians(90), 0, 0)).to_matrix())
    return _finish(bm, mat, loc, rot, smooth=30)


# ---------------------------------------------------------------- character bits
INK = "#120e14"
MOUTH = "#1a0c12"


def tooth(w, h, mat=None, loc=(0, 0, 0), rot=(0, 0, 0), point=0.2, d=None, up=False):
    """One tooth hanging down from loc (root at loc, tip below). up=True points it up.
    point 0 = square snack tooth, 1 = fang (keep most under 0.5, we are funny creepy)."""
    d = d or w * 0.6
    rings = []
    for t, k in ((0, 0.86), (0.12, 1), (0.55, 1), (0.88, 0.9), (1, 0.55)):
        q = k * (1 - point * t ** 1.3)
        rings.append([(w / 2 * q * math.copysign(abs(math.cos(a)) ** 0.6, math.cos(a)), d / 2 * q * math.copysign(abs(math.sin(a)) ** 0.6, math.sin(a)), -h * t)
                      for a in (math.radians(22.5 + 45 * i) for i in range(8))])
    ob = loft(rings, mat or toothmat(), smooth=60, gvals=lambda c: -c.z / h)
    if up:
        move(ob, scl=(1, 1, -1))
    return move(ob, loc, rot)


def teeth(path, n, w, h, up=False, point=0.2, mat=None, wonk=0.25, seed=1, skip=(), gap=0.96, face=None):
    """A row of teeth along a path (list of points, viewer left to right). Uneven on purpose.
    face(point) -> normal to turn each tooth, e.g. on a round body. skip = indexes left out."""
    rnd = random.Random(seed)
    P = bez(path, 8)
    L = [0.0]
    for a, b in zip(P, P[1:]):
        L.append(L[-1] + (b - a).length)
    out = []
    for i in range(n):
        s = L[-1] * (i + 0.5) / n
        j = max(1, next((k for k in range(len(L)) if L[k] >= s), len(L) - 1))
        t = (s - L[j - 1]) / max(L[j] - L[j - 1], 1e-6)
        p = P[j - 1].lerp(P[j], t)
        if i in skip:
            rnd.random(), rnd.random(), rnd.random()
            continue
        hh = h * (1 + wonk * (rnd.random() - 0.5) * 1.6)
        ww = w * gap * (1 - wonk * rnd.random() * 0.5)
        o = tooth(ww, hh, mat, point=point, up=up, rot=(0, (rnd.random() - 0.5) * 30 * wonk, 0))
        aim(o, p, face(p) if face else (0, -1, 0))
        out.append(o)
    return out


def eye(r, loc=(0, 0, 0), look=(0, 0), iris="#3d5a66", white="#efe9dc", pink="#d4828a", pupil=0.5, iris_size=0.52,
        lid=0.0, lidmat=None, low=0.0, tilt=0.0, socket=None, normal=(0, -1, 0), veins=0.45, seg=14, shine=True):
    """A wet, worried, veiny eyeball facing -y. look=(x, z) in degrees (x>0 looks to viewer's right).
    lid 0..1 = how far the top lid closes (needs lidmat), low = bottom lid, tilt = lid angle
    (positive = sad on viewer's right). socket = material of a ring around it. pupil = share of iris.
    seg=8 and shine=False for small ones (about 200 triangles instead of 600)."""
    obs = []
    obs.append(ball(r, eyewhite(white, pink, veins), seg=seg, rings=max(6, int(seg * 0.7))))

    def cap(R, frac, mat, lift):
        a = math.asin(min(frac, 0.98))
        prof = [(0, -R)] + [(R * math.sin(a * t), -R * math.cos(a * t)) for t in ((0.5, 1.0) if seg < 10 else (0.35, 0.7, 1.0))]
        if seg >= 10:
            prof.append((R * math.sin(a) * 0.97, -R * math.cos(a) + r * 0.07))
        o = lathe(prof, mat, seg=seg)
        move(o, rot=(-90, 0, 0))
        move(o, scl=(1, 1, 1), loc=(0, -lift, 0))
        return o

    irismat = iris_mat(iris)
    parts = [cap(r * 1.02, iris_size, irismat, r * 0.015), cap(r * 1.04, iris_size * pupil, flat("#07060a", ao=0.0), r * 0.03)]
    hl = shine and ball(r * 0.12, flat("#ffffff", ao=0.0), (-r * 0.26, -r * 1.0, r * 0.3), seg=8, rings=6)
    move(parts, rot=(-look[1], 0, 0))
    move(parts, rot=(0, 0, look[0]))
    obs += parts
    if shine:
        obs.append(hl)
    if lid and lidmat:
        obs += _lid(r, lid, lidmat, tilt, True)
    if low and lidmat:
        obs += _lid(r, low, lidmat, tilt * 0.4, False)
    if socket:
        s = torus(r * 1.04, r * 0.2, socket, rot=(90, 0, 0), loc=(0, r * 0.18, 0), seg=18, sub=6)
        obs.append(s)
    return aim(obs, loc, normal)


@cached
def iris_mat(color):
    g = G("iris")
    # g runs 0 at the middle of the cap to 1 at its rim.
    c = g.mix(g.step(g.g, 0.2, 0.75), g.mix(0.35, color, "#ffffff"), color)
    c = g.mix(g.step(g.g, 0.72, 0.95), c, g.mix(0.75, color, "#060508"))
    return g.done(c, ao=0.15, top=0.0)


def _lid(r, amount, mat, tilt, upper):
    """A shell a little bigger than the eye, swung down over the front, with a fat rim."""
    R = r * 1.12
    bm = bmesh.new()
    rows, seg = 5, 12
    first, last = -70, 40 + amount * 95
    z = 1 if upper else -1
    grid = []
    for i in range(rows + 1):
        a = math.radians(first + (last - first) * i / rows)
        grid.append([bm.verts.new((R * math.cos(u), -R * math.sin(u) * math.sin(a), z * R * math.sin(u) * math.cos(a)))
                     for u in (math.pi * j / seg for j in range(seg + 1))])
    edge = [V(v.co) for v in grid[-1]]
    for A, B in zip(grid, grid[1:]):
        for j in range(seg):
            bm.faces.new((A[j], A[j + 1], B[j + 1], B[j]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    o = _finish(bm, mat, smooth=80)
    # normals of an open shell can come out inward
    if sum(p.normal.dot(p.center) for p in o.data.polygons) < 0:
        o.data.flip_normals()
    obs = [o, tube(edge, r * 0.09, mat, seg=6, smooth_path=False)]
    return move(obs, rot=(0, tilt, 0))


def bolt(r, mat=None, loc=(0, 0, 0), normal=(0, -1, 0)):
    m = mat or metal("#6a6462", 0.6)
    o = [cyl(r, r * 0.5, m, rot=(90, 0, 0), seg=8, bevel=r * 0.2), box((r * 1.3, r * 0.1, r * 0.22), flat("#1c1614"), (0, -r * 0.28, 0), r=0.0, n=1)]
    move(o, rot=(0, random.Random(str(loc)).random() * 180, 0))
    return aim(o, loc, normal)


def stitch(path, n, size, mat=None, normal=(0, -1, 0), cross=False, face=None):
    """Stitches across a seam path."""
    m = mat or cloth("#2a2028", 0.1)
    P = bez(path, 6)
    out = []
    for i in range(n):
        f = (i + 0.5) / n * (len(P) - 1)
        a = min(int(f), len(P) - 2)
        p = P[a].lerp(P[a + 1], f - a)
        t = (P[a + 1] - P[a]).normalized()
        nn = V(face(p) if face else normal).normalized()
        s = t.cross(nn).normalized()
        for k in ((-1, 1) if cross else (0,)):
            off = t * size * 0.35 * k
            out.append(tube([p - s * size / 2 - off, p + nn * size * 0.16, p + s * size / 2 + off], size * 0.11, m, seg=5, per=2))
    return out


def drip(w, length, mat, loc=(0, 0, 0), normal=(0, -1, 0)):
    """A hanging goo drip. loc is its top."""
    prof = [(0, -length), (w * 0.32, -length + w * 0.1), (w * 0.5, -length + w * 0.45), (w * 0.4, -length + w * 0.95),
            (w * 0.3, -length * 0.45), (w * 0.42, -length * 0.12), (w * 0.6, 0.0), (0, w * 0.15)]
    o = lathe(prof, mat, seg=10, scl=(1, 0.7, 1))
    return move(o, loc)


def tape(w, h, loc, normal=(0, -1, 0), roll=0, color="#cdb98a"):
    o = box((w, 0.03, h), plain(color, 0.5), r=0.01, n=2, rot=(0, roll, 0))
    crumple(o, 0.02, 5, seed=w)
    return aim(o, loc, normal)


def hand(side, mat, cuff=None, loc=(0, 0, 0), rot=(0, 0, 0), size=1.0, fingers=3, curl=1.0, cuff_r=0.33):
    """Chunky glove hanging down from loc (wrist). side = -1 robot right (viewer left), +1 left.
    Palm faces inward. About 0.9 tall."""
    obs = []
    palm = box((0.36, 0.52, 0.5), mat, (0, 0, -0.32), r=0.1, n=1, smooth=40)
    warp(palm, lambda v: V((v.x * (1 + 0.15 * (v.z + 0.3)), v.y * (1 - 0.25 * (v.z + 0.3)), v.z)))
    obs.append(palm)
    for i in range(fingers):
        y = -0.19 + 0.38 * i / max(fingers - 1, 1)
        # each finger curls a bit more than the last, so a side view still shows separate fingers
        c = 0.2 * curl * (0.55 + 0.9 * i / max(fingers - 1, 1))
        obs.append(tube([(0, y * 0.8, -0.42), (side * 0.04, y * 1.1, -0.68), (-side * c * 0.55, y * 1.15, -0.88), (-side * (c + 0.08), y * 1.1, -0.95), (-side * (c + 0.1), y * 1.08, -0.99)],
                        [0.12, 0.125, 0.12, 0.11, 0.075], mat, seg=6, per=2, ends=False))
    obs.append(tube([(0, -0.16, -0.22), (-side * 0.12, -0.36, -0.36), (-side * 0.2, -0.36, -0.58), (-side * 0.21, -0.35, -0.62)], [0.13, 0.125, 0.11, 0.075], mat, seg=6, per=2, ends=False))
    for y in (-0.13, 0, 0.13):  # raised glove seams, so the back of the hand never reads as a plain blob
        obs.append(box((0.07, 0.045, 0.26), mat, (side * 0.18, y, -0.3), (y * 60, 0, 0), r=0.0, n=1))
    obs.append(cyl(0.17, 0.26, mat, (0, 0, -0.06), seg=6, bevel=0.0))
    if cuff:
        obs.append(lathe([(0, -0.02), (cuff_r, -0.02), (cuff_r + 0.04, 0.03), (cuff_r + 0.02, 0.14), (cuff_r - 0.03, 0.18), (0, 0.18)], cuff, seg=14))
    move(obs, scl=size)
    return move(obs, loc, rot)


def shoe(side, x, main, sole="#cfc6b2", toe=None, lace="#e8e0cc", y=0.0, size=1.0, turn=8, loose=True, high=1.1, dirt=0.55, patch=None):
    """A chunky, dirty, worn sneaker standing on the floor at x, toe toward -y. Colors are hex.
    About 0.95 wide, 1.75 long, `high` tall. Ankle hole center is near (x, y + 0.3, high)."""
    obs = []
    M = cloth(main, dirt, 55)
    S = plain(sole, 0.8, 0.3)
    T = plain(toe, 0.6) if toe else plain(sole, 0.7, 0.3)
    k = high / 1.1

    def sec(yy, w, top, bot=0.2, n=14, pw=2.6):
        ring = []
        for i in range(n):
            a = 2 * math.pi * i / n
            ca, sa = math.cos(a), math.sin(a)
            xx = w * math.copysign(abs(ca) ** (2 / pw), ca)
            zz = (top + bot) / 2 + (top - bot) / 2 * math.copysign(abs(sa) ** (2 / pw), sa)
            if sa > 0:
                xx *= 1 - 0.28 * sa
            ring.append((xx, yy, zz))
        return ring

    up = [sec(0.66, 0.2, 0.75 * k), sec(0.6, 0.31, 0.98 * k), sec(0.4, 0.37, high), sec(0.1, 0.37, high * 0.97), sec(-0.2, 0.37, 0.82 * k),
          sec(-0.5, 0.4, 0.64), sec(-0.8, 0.43, 0.52), sec(-1.0, 0.38, 0.45), sec(-1.12, 0.22, 0.38)]
    obs.append(loft(up, M, smooth=60))
    out = [(-0.22, 0.72), (0.0, 0.76), (0.22, 0.72), (0.36, 0.55), (0.37, 0.25), (0.34, -0.1), (0.41, -0.5), (0.46, -0.8), (0.4, -1.06),
           (0.2, -1.22), (0.0, -1.26), (-0.2, -1.22), (-0.4, -1.06), (-0.46, -0.8), (-0.41, -0.5), (-0.34, -0.1), (-0.37, 0.25), (-0.36, 0.55)]

    def lay(z, s, wob=0.0):
        return [(px * s, (py + 0.25) * s - 0.25, z + (wob if i % 2 else 0)) for i, (px, py) in enumerate(out)]

    obs.append(loft([lay(0, 0.96), lay(0.03, 1.03, 0.02), lay(0.12, 1.09), lay(0.17, 1.02), lay(0.22, 1.07), lay(0.31, 1.03), lay(0.34, 0.93)], S, smooth=35))
    obs.append(ball((0.42, 0.36, 0.26), T, (0, -0.9, 0.31), seg=12, rings=6))
    obs.append(box((0.26, 0.16, 0.34 * k), T, (0, 0.62, 0.52 * k), r=0.07, n=1))
    obs.append(torus(0.27, 0.085, M, (0, 0.27, high * 0.98), scl=(1, 1.15, 1), seg=14, sub=6))
    obs.append(cyl(0.27, 0.05, flat("#120e10"), (0, 0.27, high * 0.99), seg=14))
    tongue = box((0.4, 0.1, 0.5 * k), M, r=0.05, n=1)
    obs.append(move(tongue, (0, -0.15, high * 0.98), (28, 0, 0)))
    L = cloth(lace, 0.5, 40)
    for i in range(4):
        t = i / 3
        yy, zz = -0.22 - t * 0.42, 0.87 * k + (0.6 - 0.87 * k) * t
        s = 1 if i % 2 else -1
        obs.append(tube([(-0.25, yy + 0.02 * s, zz - 0.1), (0, yy, zz + 0.04), (0.25, yy - 0.05 * s, zz - 0.1)], 0.045, L, seg=4, per=2))
    if loose:
        s = side
        obs.append(tube([(s * 0.1, -0.24, 0.9 * k), (s * 0.32, -0.4, 0.94 * k), (s * 0.48, -0.5, 0.55), (s * 0.52, -0.62, 0.16), (s * 0.62, -0.85, 0.05)], 0.035, L, seg=4, per=2))
    obs.append(tube([(-side * 0.02, -0.2, 0.9 * k), (-side * 0.2, -0.36, 1.02 * k), (-side * 0.3, -0.32, 0.86 * k), (-side * 0.04, -0.24, 0.9 * k)], 0.035, L, seg=4, per=2))
    if patch:
        for sx in (-1, 1):
            obs.append(move(box((0.05, 0.3, 0.2), plain(patch, 0.5), r=0.025, n=1), (sx * 0.39, 0.0, 0.52)))
    move(obs, scl=size)
    move(obs, rot=(0, 0, side * turn))
    return move(obs, (x, y, 0))


# ---------------------------------------------------------------- arms
# Roblox moderation looks at each part alone with no color. A smooth rod with a ball or dome on one end
# got taken down once, so limbs are faceted, flat ended, ribbed, and their joints are square blocks.
def _along(ob, a, d):
    """Moves something built up +z so its z=0 sits at a and it points along d."""
    q = V((0, 0, 1)).rotation_difference(d.normalized())
    for o in ob if isinstance(ob, (list, tuple)) else [ob]:
        o.data.transform(Matrix.Translation(a) @ q.to_matrix().to_4x4())
    return ob


def _block(s, at, d, mat, bolts=None):
    """Square joint block with chopped corners, turned along the limb."""
    h, c = s * 0.5, s * 0.36
    sq = math.sqrt(2)
    obs = [lathe([(0, -h), (c * sq, -h), (h * sq, -c), (h * sq, c), (c * sq, h), (0, h)], mat, rot=(0, 0, 45), seg=4, smooth=20)]
    if bolts:
        for t in (0, 180):
            obs.append(cyl(s * 0.24, s * 0.26, bolts, (0, (-1 if t == 0 else 1) * s * 0.55, 0), (90, 0, 0), seg=6, bevel=0.0))
    return _along(obs, at, d)


def _bone(a, b, mat, j, style, r):
    d = b - a
    L = d.length
    # cut into short rings: cull() drops a long face when its sample points are all under a collar
    hexrod = lambda q: [(0, 0)] + [(q, L * i / 14) for i in range(15)] + [(0, L)]
    if style == "spring":
        d1 = d.normalized()
        return [spring(a + d1 * 0.05, b - d1 * 0.05, r * 0.8, r * 0.2, mat, turns=max(3, int(L / (r * 0.95)))),
                _along(lathe(hexrod(r * 0.42), j, seg=6), a, d)]
    if style == "pipe":
        out = [lathe(hexrod(r), mat, seg=6)]
        for t in (0.3, 0.54, 0.78):
            w, R = r * 0.42, r * 1.42
            out.append(lathe([(r * 0.8, w), (r * 0.8, -w), (R * 0.84, -w), (R, -w * 0.5), (R, w * 0.5), (R * 0.84, w), (r * 0.8, w)], j, (0, 0, L * t), seg=6, smooth=20))
        return _along(out, a, d)
    if style == "sleeve":
        # three stepped tiers, each flaring to a flat lip, like a layered cuff
        prof, n = [(0, 0)], 3
        for i in range(n):
            z0, z1 = L * i / n, L * (i + 1) / n
            prof += [(r * 0.98, z0), (r * (1.42 - 0.06 * i), z1 - r * 0.22), (r * (1.42 - 0.06 * i), z1)]
        return _along([lathe(prof + [(0, L)], mat, seg=8)], a, d)
    # noodle: a bellows hose with fat flat ribs
    n = max(4, min(5, round(L / (r * 1.2))))
    prof = [(0, 0), (r * 0.8, 0)]
    for i in range(n):
        z0, w = L * i / n, L / n
        prof += [(r * 1.25, z0 + w * 0.3), (r * 1.25, z0 + w * 0.72), (r * 0.8, z0 + w)]
    return _along([lathe(prof + [(0, L)], mat, seg=8)], a, d)


def arm(robot, side, shoulder, elbow, wrist, mat, hand_mat, style="noodle", r=0.2, cuff=None, joint=None, hand_size=1.0,
        hand_rot=(0, 0, 0), fingers=3, curl=1.0, cuff_r=0.33):
    """Builds one arm and adds it as three stiff parts (upper, fore, hand), joints recorded.
    style: noodle (bellows hose), spring (coil), pipe (hex rod with collars), sleeve (stepped cloth).
    side -1 = robot right (viewer left) -> UpperArm/Forearm/Hand. +1 -> LeftUpperArm/..."""
    pre = "" if side < 0 else "Left"
    s, e, w = V(shoulder), V(elbow), V(wrist)
    j = joint or metal("#5a5452", 0.5)
    screws = metal("#4c4644", 0.5) if style in ("pipe", "spring") else j
    d = (w - e).normalized()
    U = _bone(s, e, mat, j, style, r) + _block(r * 2.5, s, e - s, j, screws)
    F = _bone(e, w, mat, j, style, r) + _block(r * 2.2, e, d, mat if style == "noodle" else j, screws)
    if cuff:
        # eight sided, open flat top, two buckle tabs
        R = cuff_r * 1.06
        c = [lathe([(0, -0.34), (R, -0.34), (R + 0.06, -0.27), (R + 0.03, -0.05), (R + 0.03, 0.06), (R + 0.09, 0.09), (R + 0.09, 0.24), (R * 0.55, 0.24), (0, 0.24)], cuff, rot=(0, 0, 22.5), seg=8, smooth=30)]
        for k in (-1, 1):
            c.append(box((0.16, 0.1, 0.3), cuff, (0, k * (R + 0.03), -0.06), r=0.0, n=1))
        F += _along(c, w - d * 0.2, -d)
    H = hand(side, hand_mat, loc=w, rot=hand_rot, size=hand_size, fingers=fingers, curl=curl)
    robot.add(pre + "UpperArm", *U)
    robot.add(pre + "Forearm", *F)
    robot.add(pre + "Hand", *H)
    key = (lambda n: n) if side < 0 else (lambda n: "left" + n[0].upper() + n[1:])
    robot.joint(key("shoulder"), s)
    robot.joint(key("elbow"), e)
    robot.joint(key("wrist"), w)
    robot.joint(key("grip"), w + V((-side * 0.12, -0.05, -0.62 * hand_size)))
    return U, F, H


def legs(robot, xs, top, mat, ankle=0.95, y=0.0, r=0.2, style="pipe", joint=None, shoe_y=0.0):
    """Two short legs from z=top down into the shoes. xs = (right x, left x)."""
    j = joint or metal("#4c4644", 0.6)
    for x in xs:
        a, b = V((x, y + 0.1, top)), V((x, shoe_y + 0.27, ankle))
        robot.add("Legs", _bone(a, b, mat, j, "spring" if style == "spring" else "pipe", r))
        robot.add("Legs", _block(r * 2.2, a, b - a, j))


# ---------------------------------------------------------------- the robot: join, bake, export, preview
# 0 = clean. Furniture sets 1 so the old world's stuff looks abandoned: faded, with dust settled on top faces.
DUST = 0.0

PARTS = ["Head", "Torso", "UpperArm", "Forearm", "Hand", "LeftUpperArm", "LeftForearm", "LeftHand"]
# Walkers split each leg at the knee so they can walk. The crawler keeps a Legs chassis plus six swinging legs.
EXTRA = ["Jaw", "Lid", "Extra", "Legs", "Thigh", "Shin", "LeftThigh", "LeftShin"] + [f"Leg{i}" for i in range(1, 7)]


class Robot:
    def __init__(self, name, folder="robots", max_h=5.0):
        wipe()
        self.name = name
        self.max_h = max_h
        self.dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), folder, name)
        os.makedirs(self.dir, exist_ok=True)
        self.parts = {}
        self.joints = {}

    def add(self, part, *obs):
        assert part in PARTS + EXTRA, f"{part} is not one of {PARTS + EXTRA}"
        for o in obs:
            if isinstance(o, (list, tuple)):
                self.add(part, *o)
            else:
                self.parts.setdefault(part, []).append(o)
        return obs[0] if len(obs) == 1 else obs

    def joint(self, name, at):
        self.joints[name] = V(at)

    def finish(self, size=1024, samples=24, big=(), quick=False):
        """Join, unwrap, bake, export, re-import, check, render. quick=True: rough bake and render.
        big = parts whose texture share is raised (e.g. ("Head",))."""
        scn = bpy.context.scene
        for p in PARTS:
            if p not in self.parts:
                print("MISSING PART", p)
        final = []
        for part, obs in self.parts.items():
            bpy.ops.object.select_all(action="DESELECT")
            for o in obs:
                o.select_set(True)
            bpy.context.view_layer.objects.active = obs[0]
            if len(obs) > 1:
                bpy.ops.object.join()
            o = bpy.context.view_layer.objects.active
            o.name = part
            o.data.name = part
            final.append(o)
        # feet on the floor, centered in x
        lowest = min(v.co.z for o in final for v in o.data.vertices)
        for o in final:
            o.data.transform(Matrix.Translation((0, 0, -lowest)))
        for k in self.joints:
            self.joints[k].z -= lowest
        top = max(v.co.z for o in final for v in o.data.vertices)
        if top > self.max_h:
            for o in final:
                o.data.transform(Matrix.Scale(self.max_h / top, 4))
            for k in self.joints:
                self.joints[k] *= self.max_h / top
            top = self.max_h
        for o in final:
            cull(o)
        tris = lambda o: sum(len(p.vertices) - 2 for p in o.data.polygons)
        raw = sum(map(tris, final))
        if raw > 9800:
            # last resort trim. Over about 13000 raw it starts to show, so cut prims instead.
            print("TRIMMING from", raw, "triangles")
            heavy = [o for o in final if tris(o) > 600]
            spare = sum(tris(o) for o in final if o not in heavy)
            for o in heavy:
                md = o.modifiers.new("d", "DECIMATE")
                md.ratio = (9700 - spare) / (raw - spare)
                bpy.context.view_layer.objects.active = o
                bpy.ops.object.modifier_apply(modifier="d")
                o.data.set_sharp_from_angle(angle=math.radians(48))
        # one shared unwrap
        bpy.ops.object.select_all(action="DESELECT")
        for o in final:
            o.select_set(True)
            o.data.uv_layers.new(name="UVMap")
        bpy.context.view_layer.objects.active = final[0]
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.0, area_weight=0.0)
        bpy.ops.object.mode_set(mode="OBJECT")
        for o in final:
            uv = o.data.uv_layers[0].data
            for p in o.data.polygons:
                # flat colors need almost no texture, so the good stuff gets more
                k = 0.3 if o.data.materials[p.material_index].name.startswith("flat") else 1.0
                k *= 1.4 if o.name in big else 1.0
                for i in p.loop_indices:
                    uv[i].uv = uv[i].uv * k
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.select_all(action="SELECT")
        bpy.ops.uv.pack_islands(rotate=True, margin_method="FRACTION", margin=0.0035, shape_method="CONCAVE")
        bpy.ops.object.mode_set(mode="OBJECT")
        img = bpy.data.images.new(self.name + "_color", size, size)
        for m in bpy.data.materials:
            if m.node_tree and m.users:
                t = m.node_tree.nodes.new("ShaderNodeTexImage")
                t.image = img
                m.node_tree.nodes.active = t
        scn.render.engine = "CYCLES"
        scn.cycles.samples = 6 if quick else samples
        scn.cycles.use_denoising = False
        scn.render.bake.use_selected_to_active = False
        scn.render.bake.margin = 6
        scn.view_settings.view_transform = "Standard"
        scn.world = bpy.data.worlds.new("w")
        bpy.ops.object.bake(type="EMIT")
        path = os.path.join(self.dir, self.name + "_color.png")
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
        mat = bpy.data.materials.new(self.name)
        mat.use_nodes = True
        bs = mat.node_tree.nodes["Principled BSDF"]
        bs.inputs["Roughness"].default_value = 0.75
        t = mat.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(path)
        mat.node_tree.links.new(t.outputs[0], bs.inputs["Base Color"])
        total = 0
        for o in final:
            o.data.materials.clear()
            o.data.materials.append(mat)
            for p in o.data.polygons:
                p.material_index = 0
            for a in ("lp", "g"):
                o.data.attributes.remove(o.data.attributes[a])
            md = o.modifiers.new("t", "TRIANGULATE")
            md.keep_custom_normals = True
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier="t")
            total += len(o.data.polygons)
        # origins at the joints, so each part turns where it should
        pre = {"UpperArm": "shoulder", "Forearm": "elbow", "Hand": "wrist", "Thigh": "thigh", "Shin": "knee"}
        for o in final:
            at = None
            for k, j in pre.items():
                if o.name == k:
                    at = self.joints.get(j)
                elif o.name == "Left" + k:
                    at = self.joints.get("left" + j.capitalize())
            if o.name in ("Head",):
                at = self.joints.get("neck")
            if o.name == "Torso":
                at = self.joints.get("hip")
            if o.name in ("Jaw", "Lid", "Extra") or o.name.startswith("Leg") and o.name != "Legs":
                at = self.joints.get(o.name.lower())
            if at is not None:
                o.data.transform(Matrix.Translation(-at))
                o.location = at
        fbx = os.path.join(self.dir, self.name + ".fbx")
        bpy.ops.object.select_all(action="DESELECT")
        for o in final:
            o.select_set(True)
        bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, global_scale=0.01, apply_scale_options="FBX_SCALE_NONE",
                                 axis_forward="-Z", axis_up="Y", path_mode="COPY", embed_textures=True, mesh_smooth_type="FACE",
                                 bake_anim=False, add_leaf_bones=False, object_types={"MESH"})
        self._joints_file(top)
        print(f"BUILT {self.name}: {total} triangles, {top:.2f} studs tall")
        for o in final:
            print(f"   {o.name}: {len(o.data.polygons)}")
        if total > 10000:
            print("TOO MANY TRIANGLES, stay under 10000")
        check(fbx)
        preview(fbx, os.path.join(self.dir, "preview.png"), samples=24 if quick else 64)

    def _joints_file(self, top):
        f = lambda v: f"Vector3.new({v.x:.2f}, {v.z:.2f}, {-v.y:.2f})"
        with open(os.path.join(self.dir, "joints.txt"), "w") as h:
            h.write(f"-- {self.name}, {top:.2f} studs tall, feet at 0. Roblox space, for MESH_JOINTS.\n")
            for k, v in self.joints.items():
                h.write(f"{k} = {f(v)},\n")


_DIRS = [V((math.sqrt(1 - z * z) * math.cos(a), math.sqrt(1 - z * z) * math.sin(a), z))
         for i in range(40) for z in [1 - (i + 0.5) / 20] for a in [i * 2.399963]]


def cull(o):
    """Deletes faces nobody can see from outside this part (backs of eyeballs, buried ends).
    Saves triangles and texture."""
    me = o.data
    t = BVHTree.FromPolygons([v.co for v in me.vertices], [p.vertices for p in me.polygons])
    gone = []
    for p in me.polygons:
        n = p.normal
        if n.length < 0.5:
            gone.append(p.index)
            continue
        c = p.center
        spots = [c] + [c.lerp(me.vertices[i].co, 0.85) for i in p.vertices]
        seen = False
        for s in spots:
            s = s + n * 0.004
            for d in _DIRS:
                if d.dot(n) > 0.05 and t.ray_cast(s, d)[0] is None:
                    seen = True
                    break
            if seen:
                break
        if not seen:
            gone.append(p.index)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in gone], context="FACES")
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(2.5), verts=bm.verts, edges=bm.edges, delimit={"MATERIAL"})
    bm.to_mesh(me)
    bm.free()


def check(fbx):
    """Re-imports the FBX and lists what Roblox will see."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=fbx)
    tot = 0
    for o in bpy.data.objects:
        n = len(o.data.polygons) if o.type == "MESH" else 0
        tot += n
        ok = o.type == "MESH" and o.name in PARTS + EXTRA and o.data.uv_layers and o.data.materials and o.data.materials[0].node_tree
        if not ok or n > 20000:
            print("CHECK BAD", o.name, o.type, n)
    print("CHECK", os.path.basename(fbx), len(bpy.data.objects), "parts", tot, "triangles", sorted(o.name for o in bpy.data.objects),
          "images", [i.name for i in bpy.data.images if i.size[0]])


def preview(fbx, out, samples=64, turn=-24, res=900):
    """Front three-quarter render from the FBX itself."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=fbx)
    scn = bpy.context.scene
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ v.co for o in bpy.data.objects if o.type == "MESH" for v in o.data.vertices]
    lo = V([min(p[i] for p in pts) for i in range(3)])
    hi = V([max(p[i] for p in pts) for i in range(3)])
    tall = hi.z - lo.z
    wide = max(hi.x - lo.x, hi.y - lo.y)
    flat = tall < wide * 0.3 or (tall < 0.5 and tall < wide * 0.45)  # pizza boxes, rugs, cheese: film from above or all you see is the edge
    h = max(tall, wide * 0.6) if flat else tall
    mid = (lo + hi) / 2
    for m in bpy.data.materials:
        if m.node_tree:
            for n in m.node_tree.nodes:
                if n.type == "BSDF_PRINCIPLED":
                    n.inputs["Roughness"].default_value = 0.6
                    n.inputs["Specular IOR Level"].default_value = 0.35
    root = bpy.data.objects.new("root", None)
    scn.collection.objects.link(root)
    me = bpy.data.meshes.new("floor")
    prof = [(-60, 0), (4, 0)] + [(4 + 4 * math.sin(math.radians(t)), 4 - 4 * math.cos(math.radians(t))) for t in range(6, 91, 6)] + [(8, 60)]
    me.from_pydata([(x * h, y * h, z * h) for y, z in prof for x in (-60, 60)], [],
                   [(2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2) for i in range(len(prof) - 1)])
    for p in me.polygons:
        p.use_smooth = True
    fl = bpy.data.objects.new("floor", me)
    fl.location = (0, 0, lo.z)
    fl.rotation_euler.z = math.radians(turn)
    fm = bpy.data.materials.new("f")
    fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.93, 0.93, 0.95, 1)
    me.materials.append(fm)
    scn.collection.objects.link(fl)
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.95, 0.96, 1, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.75
    scn.world = w

    def light(x, y, z, e, s):
        l = bpy.data.lights.new("l", "AREA")
        l.energy = e * h * h
        l.size = s * h
        o = bpy.data.objects.new("l", l)
        o.location = mid + V((x, y, z)) * h
        o.rotation_euler = (mid - o.location).to_track_quat("-Z", "Y").to_euler()
        scn.collection.objects.link(o)

    light(-1.2, -1.6, 1.6, 34, 1.0)
    light(1.6, -0.6, 0.8, 12, 1.0)
    light(0.6, 1.6, 1.4, 18, 0.8)
    cam = bpy.data.cameras.new("c")
    cam.lens = 90
    co = bpy.data.objects.new("c", cam)
    a = math.radians(turn)
    span = max(h, (hi.x - lo.x) * 1.0) * 1.0
    d = span * 3.0
    co.location = mid + V((math.sin(a) * d, -math.cos(a) * d, d * 0.6 if flat else h * 0.28))
    co.rotation_euler = (mid - co.location).to_track_quat("-Z", "Y").to_euler()
    cam.clip_start = d * 0.01
    cam.clip_end = d * 100
    scn.collection.objects.link(co)
    scn.camera = co
    scn.render.engine = "CYCLES"
    scn.cycles.samples = samples
    scn.cycles.use_denoising = True
    scn.render.resolution_x = res
    scn.render.resolution_y = res
    scn.view_settings.view_transform = "Standard"
    scn.view_settings.exposure = -0.15
    scn.render.filepath = out
    bpy.ops.render.render(write_still=True)
