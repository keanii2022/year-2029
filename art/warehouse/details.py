"""Warehouse lights, signs and details: the abandoned big-box store look (cold dead fluorescents, faded store
signs, rust, black robot oil, faded safety yellow), plus a few liminal dreamcore pieces.
Run from art: _kit/run.sh warehouse/details.py <name> ...
Hanging items have their origin at the top attach point, wall items at the back-centre of the mount."""
import math, os, random, shutil, subprocess, sys, tempfile

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "furniture"))
from common import *  # noqa
import bmesh
import kit
import ykit
from mathutils import Matrix, Vector as V

STEEL = "#6b7176"
ENAMEL = "#b9b7ac"
SAFETY = "#c99a22"
BLACK = "#1c1b1a"
STORE_BLUE = "#4b6a88"
BANNER_YELLOW = "#cfb350"
FONT = "Futura, 'Avenir Next', Helvetica, sans-serif"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


# Materials are made per item: each build wipes the scene, so module-level materials would be gone.
def oil():
    return flat("#0b0a0a")


def cable():
    return metal("#3a3a3a", rust=0.3)


def cold():
    return glow("#d2ece4", core="#f2fff9", amount=0.3)


def exit_green():
    return glow("#3fdc6a", core="#b9ffcc", amount=0.25)


def alarm_red():
    return glow("#ff4a1c", core="#ffc39a", amount=0.25)


def steel(color=STEEL, chip=0.3):
    return paint(color, chip=chip, grime=0.6, streaks=0.7)


def housing():
    return paint(ENAMEL, chip=0.2, under="#6a5a4a", grime=0.65, streaks=0.8)


def safety():
    return paint(SAFETY, chip=0.4, grime=0.55, streaks=0.5)


def rubber():
    return plain(BLACK, grime=0.4, vary=0.2)


_screen_uv = ykit.screen_uv


def _screen_uv_two_sided(o):
    """Screen2 faces +y: flip its UVs so the picture reads the right way round from behind."""
    _screen_uv(o)
    if o.name.startswith("Screen2"):
        for loop in o.data.uv_layers[0].data:
            loop.uv = (1 - loop.uv[0], loop.uv[1])


ykit.screen_uv = _screen_uv_two_sided

GRIME = ('<filter id="g"><feTurbulence type="fractalNoise" baseFrequency="0.012" numOctaves="4" seed="7"/>'
         '<feColorMatrix values="0 0 0 0 0.3  0 0 0 0 0.25  0 0 0 0 0.18  0 0 0 1.4 -0.6"/></filter>')


def screen_png(P, w, h, bg, body):
    """Draws the default screen.png once with headless Chrome (own throwaway profile), faded and grimy."""
    dst = os.path.join(P.dir, "screen.png")
    if os.path.exists(dst) or not os.path.exists(CHROME):
        return
    tmp = tempfile.mkdtemp()
    src = os.path.join(tmp, "s.svg")
    with open(src, "w") as f:
        f.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><defs>{GRIME}</defs>'
                f'<rect width="{w}" height="{h}" fill="{bg}"/>{body}<rect width="{w}" height="{h}" filter="url(#g)"/></svg>')
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--user-data-dir={tmp}/chrome",
                    f"--window-size={w},{h}", f"--screenshot={dst}", "file://" + src], check=True, capture_output=True)
    shutil.rmtree(tmp, ignore_errors=True)


def text(x, y, s, size, fill):
    return (f'<text x="{x}" y="{y}" font-family="{FONT}" font-weight="bold" font-size="{size}" text-anchor="middle" '
            f'dominant-baseline="central" fill="{fill}">{s}</text>')


def bar(a, b, t, mat, r=0.0):
    """Square-section bar from point a to point b."""
    a, b = V(a), V(b)
    d = b - a
    o = box((t, t, d.length), mat, r=min(r, t / 2), n=1)
    q = V((0, 0, 1)).rotation_difference(d.normalized())
    o.data.transform(Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4())
    return o


def ribbon(pts, width, mats, twists):
    """Flat tape through points, one box per stretch, colors cycling through mats. twists in degrees per stretch."""
    out = []
    for i in range(len(pts) - 1):
        a, b = V(pts[i]), V(pts[i + 1])
        d = b - a
        o = box((d.length + 0.02, 0.02, width), mats[i % len(mats)], r=0.0, n=1)
        move(o, rot=(twists[i], 0, 0))
        q = V((1, 0, 0)).rotation_difference(d.normalized())
        o.data.transform(Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4())
        out.append(o)
    return out


def mesh_panel(origin, u, v, nu, nv, t, mat):
    """Wire mesh: bars across a rectangle from origin spanned by u and v, without the edge bars."""
    o, u, v = V(origin), V(u), V(v)
    out = [bar(o + u * i / nu, o + u * i / nu + v, t, mat) for i in range(1, nu)]
    out += [bar(o + v * j / nv, o + v * j / nv + u, t, mat) for j in range(1, nv)]
    return out


def clip_x(poly, lo, hi):
    for edge, keep in ((lo, lambda x: x >= lo - 1e-6), (hi, lambda x: x <= hi + 1e-6)):
        out = []
        for i in range(len(poly)):
            p, q = poly[i - 1], poly[i]
            cut = lambda: (edge, p[1] + (edge - p[0]) / (q[0] - p[0]) * (q[1] - p[1]))
            if keep(q[0]):
                if not keep(p[0]):
                    out.append(cut())
                out.append(q)
            elif keep(p[0]):
                out.append(cut())
        poly = [pt for i, pt in enumerate(out) if abs(pt[0] - out[i - 1][0]) + abs(pt[1] - out[i - 1][1]) > 1e-4]
        if len(poly) < 3:
            return []
    return poly


def stripes(w, h, n=6, depth=0.04):
    """Faded yellow/black hazard band facing -y, centred on the origin."""
    out = [box((w, depth, h), rubber(), r=0.0, n=1)]
    yel = plain(SAFETY, grime=0.55, vary=0.3)
    step = w / n
    k = h * 0.8
    for i in range(-2, n + 1):
        xa = -w / 2 + i * step
        poly = clip_x([(xa, -h / 2), (xa + step / 2, -h / 2), (xa + step / 2 + k, h / 2), (xa + k, h / 2)], -w / 2, w / 2)
        if poly:
            out.append(slab(poly, 0.01, yel, loc=(0, -depth / 2 - 0.004, 0)))
    return out


def handprint(x, z, y, s=1.0, rot=0, back=False):
    """Black oil handprint with a smear, on a face at depth y (facing -y, or +y if back)."""
    out = [box((0.34 * s, 0.008, 0.32 * s), oil(), r=0.0, n=1),
           box((0.14 * s, 0.008, 0.22 * s), oil(), loc=(0.03 * s, 0, -0.25 * s), r=0.0, n=1),
           box((0.07 * s, 0.008, 0.2 * s), oil(), loc=(-0.22 * s, 0, 0.02 * s), rot=(0, 40, 0), r=0.0, n=1)]
    for dx, ln in ((-0.12, 0.24), (-0.04, 0.28), (0.04, 0.27), (0.12, 0.22)):
        out.append(box((0.065 * s, 0.008, ln * s), oil(), loc=(dx * s, 0, (0.16 + ln / 2) * s), r=0.0, n=1))
    move(out, rot=(0, rot, 180 if back else 0))
    return move(out, loc=(x, y, z))


def oil_streaks(x0, x1, ztop, y, lengths, seed=0):
    rnd = random.Random(seed)
    out = []
    for ln in lengths:
        x, w = rnd.uniform(x0, x1), rnd.uniform(0.05, 0.11)
        out.append(box((w, 0.008, ln), oil(), loc=(x, y, ztop - ln / 2), r=0.0, n=1))
    return out


def hang(P, xs, z0, top, t=0.06):
    """Short cables from z0 up to the top attach height, with a clamp below and a ceiling plate on top."""
    for x in xs:
        P.add("Body", bar((x, 0, z0), (x, 0, top), t, cable()),
              box((0.22, 0.22, 0.14), steel("#4a4d50"), loc=(x, 0, z0 + 0.07), r=0.03, n=1),
              box((0.34, 0.34, 0.08), steel("#4a4d50"), loc=(x, 0, top - 0.04), r=0.02, n=1))


def top_pivots(top, x=0.0, parts=("Body", "Glow", "Screen", "Screen2")):
    return {p: (x, 0, top) for p in parts}


WALL = {"Body": (0, 0, 0), "Glow": (0, 0, 0), "Screen": (0, 0, 0)}

# ---------------------------------------------------------------- lights

STRIP_TOP = 3.0


def strip(lit=True):
    """Two-tube strip fixture, housing top at z=0, 8 long. Returns (body, glow) lists."""
    hm = housing()
    body = [box((8.0, 1.1, 0.45), hm, loc=(0, 0, -0.225), r=0.06, n=1)]
    for s in (-1, 1):
        body.append(box((7.9, 0.07, 0.4), hm, loc=(0, s * 0.6, -0.55), rot=(s * 20, 0, 0), r=0.02, n=1))
        body.append(box((0.16, 1.25, 0.65), steel("#4a4d50"), loc=(s * 4.02, 0, -0.38), r=0.04, n=1))
        body.append(box((0.22, 0.22, 0.14), steel("#4a4d50"), loc=(s * 3.4, 0, 0.07), r=0.03, n=1))
    body += oil_streaks(-3.5, 3.5, -0.02, -0.556, (0.3, 0.4, 0.22), seed=3)
    glw = []
    if lit:
        glw.append(box((7.7, 1.02, 0.1), cold(), loc=(0, 0, -0.62), r=0.03, n=1))
    else:
        grey = plain("#8d8f8a", grime=0.8, vary=0.3)
        tube = plain("#5c5e5a", grime=0.5)
        body.append(box((5.0, 1.02, 0.1), grey, loc=(-1.35, 0, -0.62), r=0.03, n=1))
        body.append(move(box((2.6, 1.02, 0.08), grey, loc=(2.55, 0, -0.62), r=0.02, n=1), rot=(-70, 0, 0), pivot=(2.55, -0.51, -0.62)))
        body.append(cyl(0.09, 7.4, tube, loc=(0, 0.22, -0.5), rot=(0, 90, 0), seg=6, bevel=0.02))
        body.append(cyl(0.09, 4.6, tube, loc=(-1.4, -0.22, -0.5), rot=(0, 90, 0), seg=6, bevel=0.02))
    return body, glw


@item("light_strip", "warehouse", pivots=top_pivots(STRIP_TOP))
def light_strip(P):
    body, glw = strip(True)
    P.add("Body", body)
    P.add("Glow", glw)
    hang(P, (-3.4, 3.4), 0.14, STRIP_TOP)


@item("light_strip_dead", "warehouse", pivots=top_pivots(STRIP_TOP))
def light_strip_dead(P):
    body, _ = strip(False)
    P.add("Body", body)
    hang(P, (-3.4, 3.4), 0.14, STRIP_TOP)


@item("light_dangling", "warehouse", pivots=top_pivots(STRIP_TOP, x=-3.4))
def light_dangling(P):
    body, glw = strip(True)
    tilt = 35
    move(body + glw, rot=(0, tilt, 0), pivot=(-3.4, 0, 0))
    P.add("Body", body)
    P.add("Glow", glw)
    hang(P, (-3.4,), 0.14, STRIP_TOP)
    a = math.radians(tilt)
    end = V((-3.4 + 6.8 * math.cos(a), 0, -6.8 * math.sin(a)))
    kink = end + V((-0.25, 0.05, 0.7))
    tip = kink + V((0.35, -0.1, 0.45))
    P.add("Body", bar(end, kink, 0.06, cable()), bar(kink, tip, 0.06, cable()),
          bar(tip, tip + V((0.12, 0, 0.18)), 0.03, cable()), bar(tip, tip + V((-0.1, 0.05, 0.2)), 0.03, cable()))
    cap = V((-3.4 + 7.4 * math.cos(a) + 0.4 * math.sin(a), 0, -7.4 * math.sin(a) - 0.4 * math.cos(a)))
    wire = [cap, cap + V((0.15, -0.1, -0.8)), cap + V((0.05, -0.15, -1.6)), cap + V((0.25, -0.1, -2.2))]
    for p, q in zip(wire, wire[1:]):
        P.add("Body", bar(p, q, 0.07, rubber()))


HIGHBAY_TOP = 3.7


@item("light_highbay", "warehouse", pivots=top_pivots(HIGHBAY_TOP))
def light_highbay(P):
    shade = paint("#5f6a64", chip=0.35, grime=0.6, streaks=0.8)
    dark = steel("#3d4144")
    P.add("Body", lathe([(0, 0.0), (0.5, 0.0), (0.65, -0.15), (1.15, -0.65), (1.6, -1.45), (1.7, -1.6), (1.6, -1.62),
                         (1.5, -1.5), (1.05, -0.7), (0.55, -0.2), (0, -0.2)], shade, seg=16))
    P.add("Body", cyl(0.38, 0.32, dark, loc=(0, 0, 0.16), seg=8, bevel=0.03))
    P.add("Body", cyl(0.75, 0.9, dark, loc=(0, 0, 0.75), seg=8, bevel=0.06))
    P.add("Body", cyl(0.85, 0.12, dark, loc=(0, 0, 1.18), seg=8, bevel=0.03))
    P.add("Body", box((0.45, 0.3, 0.2), dark, loc=(0, 0, 1.28), r=0.04, n=1))
    P.add("Body", bar((0, 0, 1.3), (0, 0, HIGHBAY_TOP - 0.3), 0.07, cable()))
    P.add("Body", box((0.12, 0.35, 0.35), cable(), loc=(0, 0, HIGHBAY_TOP - 0.2), r=0.03, n=1))
    P.add("Body", box((0.4, 0.4, 0.08), dark, loc=(0, 0, HIGHBAY_TOP - 0.04), r=0.02, n=1))
    P.add("Glow", cyl(1.5, 0.1, cold(), loc=(0, 0, -1.5), seg=16, bevel=0.02))
    for rz in (0, 90):
        P.add("Body", box((3.1, 0.08, 0.06), dark, loc=(0, 0, -1.58), rot=(0, 0, rz), r=0.0, n=1))


@item("light_emergency", "warehouse", pivots=WALL)
def light_emergency(P):
    P.add("Body", box((2.3, 0.12, 1.3), steel(), loc=(0, -0.06, 0), r=0.04, n=1))
    case = plain("#cfcbbd", grime=0.6, vary=0.3)
    P.add("Body", box((2.1, 0.7, 0.9), case, loc=(0, -0.45, -0.1), r=0.12, n=1))
    for i in range(5):
        P.add("Body", box((0.07, 0.02, 0.45), flat("#202020"), loc=(0.15 + i * 0.13, -0.805, -0.1), r=0.0, n=1))
    P.add("Body", box((0.12, 0.03, 0.12), plain("#a8702a", grime=0.2), loc=(-0.75, -0.81, 0.15), r=0.02, n=1))
    P.add("Body", box((0.16, 0.05, 0.12), plain("#3a3a3a"), loc=(-0.75, -0.81, -0.3), r=0.02, n=1))
    P.add("Body", handprint(-0.35, -0.2, -0.806, s=0.6, rot=15))
    P.add("Body", box((0.25, 0.2, 1.3), steel(), loc=(0.9, -0.14, 1.3), r=0.03, n=1))
    shell = plain("#2e2f30", grime=0.5)
    for sx in (-1, 1):
        P.add("Body", box((0.25, 0.25, 0.25), shell, loc=(sx * 0.6, -0.5, 0.45), r=0.04, n=1))
        head = [box((0.8, 0.6, 0.62), shell, r=0.14, n=1), box((0.8, 0.16, 0.06), shell, loc=(0, -0.36, 0.3), r=0.02, n=1)]
        lens = box((0.62, 0.08, 0.46), alarm_red(), loc=(0, -0.31, 0), r=0.08, n=1)
        move(head + [lens], rot=(20, 0, sx * 25), loc=(sx * 0.62, -0.55, 0.85))
        P.add("Body", head)
        P.add("Glow", lens)


# ---------------------------------------------------------------- signs

EXIT_TOP = 2.0
ARROW = [(-0.3, -0.1), (0.0, -0.1), (0.0, -0.25), (0.3, 0.0), (0.0, 0.25), (0.0, 0.1), (-0.3, 0.1)]


@item("exit_sign", "warehouse", pivots=top_pivots(EXIT_TOP))
def exit_sign(P):
    z = -0.65
    P.add("Body", box((3.0, 0.5, 1.3), plain("#bdb9ab", grime=0.7, vary=0.3), loc=(0, 0, z), r=0.08, n=1))
    broken = [(-1.3, -0.48), (1.3, -0.48), (1.3, 0.12), (1.12, 0.2), (1.18, 0.3), (0.98, 0.48), (-1.3, 0.48)]
    P.add("Glow", slab(broken, 0.04, exit_green(), loc=(0, -0.26, z)))
    P.add("Glow", box((2.6, 0.04, 0.96), exit_green(), loc=(0, 0.26, z), r=0.0, n=1))
    P.add("Body", box((0.42, 0.02, 0.42), flat("#151515"), loc=(1.12, -0.255, z + 0.28), r=0.0, n=1))
    for ang, ln in ((25, 0.55), (-15, 0.4), (60, 0.3)):
        c = box((ln, 0.01, 0.025), flat("#1d2a20"), loc=(-ln / 2, 0, 0), r=0.0, n=1)
        P.add("Body", move(c, rot=(0, ang, 0), loc=(1.0, -0.285, z + 0.22)))
    ink = plain("#ecebe2", grime=0.4)
    P.add("Body", words("EXIT", 0.6, ink, loc=(-0.25, -0.3, z), depth=0.03))
    P.add("Body", words("EXIT", 0.6, ink, loc=(-0.25, 0.3, z), rot=(0, 0, 180), depth=0.03))
    for y in (-0.3, 0.3):
        P.add("Body", slab(ARROW, 0.03, ink, loc=(0.85, y, z)))
    hang(P, (-1.1, 1.1), 0.0, EXIT_TOP, t=0.05)


DEPT_TOP = 2.5


@item("dept_sign", "warehouse", pivots=top_pivots(DEPT_TOP))
def dept_sign(P):
    screen_png(P, 1024, 246, STORE_BLUE, '<rect x="14" y="14" width="996" height="218" fill="none" stroke="#e3d8bd" stroke-width="6"/>'
               + text(512, 128, "SOFAS", 140, "#e8dfc8"))
    blue = paint("#3a5470", chip=0.25, under="#3a3a3a", grime=0.6, streaks=0.7)
    P.add("Body", box((8.2, 0.4, 2.3), blue, loc=(0, 0, -1.2), r=0.1, n=1))
    P.add("Body", box((8.4, 0.5, 0.16), steel("#4a4d50"), loc=(0, 0, -0.02), r=0.04, n=1))
    face = plain(STORE_BLUE, grime=0.3)
    P.add("Screen", box((7.7, 0.04, 1.85), face, loc=(0, -0.21, -1.2), r=0.0, n=1))
    P.add("Screen2", box((7.7, 0.04, 1.85), face, loc=(0, 0.21, -1.2), r=0.0, n=1))
    P.add("Body", oil_streaks(-3.8, 3.8, -0.1, -0.205, (0.12, 0.18), seed=8))
    hang(P, (-3.4, 3.4), 0.06, DEPT_TOP)


AISLE_TOP = 2.2


@item("aisle_sign_hanging", "warehouse", pivots=top_pivots(AISLE_TOP))
def aisle_sign(P):
    screen_png(P, 560, 600, STORE_BLUE, '<rect x="20" y="20" width="520" height="560" fill="none" stroke="#e8dfc8" stroke-width="10"/>'
               + text(280, 100, "AISLE", 70, "#e8dfc8") + text(280, 350, "14", 300, "#f1e9d4"))
    P.add("Body", box((3.2, 0.36, 3.5), safety(), loc=(0, 0, -1.9), r=0.08, n=1))
    P.add("Body", box((3.4, 0.48, 0.2), steel("#4a4d50"), loc=(0, 0, -0.1), r=0.04, n=1))
    face = plain(STORE_BLUE, grime=0.3)
    P.add("Screen", box((2.8, 0.04, 3.0), face, loc=(0, -0.19, -1.9), r=0.0, n=1))
    P.add("Screen2", box((2.8, 0.04, 3.0), face, loc=(0, 0.19, -1.9), r=0.0, n=1))
    hang(P, (-1.2, 1.2), 0.0, AISLE_TOP)


BANNER_TOP = 2.5


def sheet(nx, nz, at, depth, mat):
    """Thick cloth sheet as a quad grid. at(u, v) -> (x, y, z) for u, v in 0..1; thickness goes along y."""
    bm = bmesh.new()
    grid = {}
    for side, dy in ((0, -depth / 2), (1, depth / 2)):
        for i in range(nx + 1):
            for j in range(nz + 1):
                x, y, z = at(i / nx, j / nz)
                grid[side, i, j] = bm.verts.new((x, y + dy, z))
    for i in range(nx):
        for j in range(nz):
            bm.faces.new([grid[0, i, j], grid[0, i + 1, j], grid[0, i + 1, j + 1], grid[0, i, j + 1]])
            bm.faces.new([grid[1, i, j + 1], grid[1, i + 1, j + 1], grid[1, i + 1, j], grid[1, i, j]])
    rim = [(i, 0) for i in range(nx)] + [(nx, j) for j in range(nz)] + [(i, nz) for i in range(nx, 0, -1)] + [(0, j) for j in range(nz, 0, -1)]
    for k, a in enumerate(rim):
        b = rim[(k + 1) % len(rim)]
        bm.faces.new([grid[0, a[0], a[1]], grid[1, a[0], a[1]], grid[1, b[0], b[1]], grid[0, b[0], b[1]]])
    return kit._finish(bm, mat, smooth=60)


def wave_sheet(x0, x1, z0, z1, depth, mat, y, torn=0.0, nx=24, nz=4):
    """Banner cloth that ripples along x. torn lifts a ragged bottom-right corner."""
    rnd = random.Random(4)
    rags = [rnd.uniform(0, 0.12) for _ in range(nx + 1)]

    def at(u, v):
        x = x0 + (x1 - x0) * u
        rag = torn * max(0.0, (u - 0.75) / 0.25) + (rags[round(u * nx)] if torn and u > 0.75 else 0)
        bottom = z0 - 0.12 * math.sin(math.pi * u) + rag
        z = bottom + (z1 - bottom) * v
        return x, y + 0.12 * math.sin(x * 1.4) * (0.4 + 0.6 * (1 - v)), z

    return sheet(nx, nz, at, depth, mat)


@item("sale_banner", "warehouse", pivots=top_pivots(BANNER_TOP))
def sale_banner(P):
    screen_png(P, 1024, 294, BANNER_YELLOW, '<rect x="16" y="16" width="992" height="262" fill="none" stroke="#2a2622" stroke-width="8"/>'
               + text(512, 150, "SALE", 210, "#2a2622"))
    P.add("Body", wave_sheet(-4.5, 4.5, -3.1, -0.1, 0.05, cloth("#b89a3a", dirt=0.5, weave=80), 0.0, torn=0.45))
    P.add("Screen", wave_sheet(-4.0, 4.0, -2.65, -0.45, 0.02, plain(BANNER_YELLOW, grime=0.3), -0.04))
    P.add("Body", box((9.6, 0.22, 0.22), steel("#4a4d50"), loc=(0, 0, -0.05), r=0.04, n=1))
    for x in (-3.6, -1.2, 1.2, 3.6):
        P.add("Body", box((0.16, 0.3, 0.32), cloth("#6a5a2a", dirt=0.4), loc=(x, 0, -0.12), r=0.03, n=1))
    hang(P, (-4.6, 4.6), 0.06, BANNER_TOP)


# ---------------------------------------------------------------- floor details

@item("caution_tape", "warehouse")
def caution_tape(P):
    for sx in (-1, 1):
        x = sx * 8
        P.add("Body", box((1.3, 1.3, 0.3), rubber(), loc=(x, 0, 0.15), r=0.1, n=1),
              box((0.9, 0.9, 0.35), plain("#2b2b2b", grime=0.5), loc=(x, 0, 0.47), r=0.06, n=1),
              box((0.32, 0.32, 3.0), safety(), loc=(x, 0, 2.1), r=0.04, n=1),
              box((0.55, 0.55, 0.5), rubber(), loc=(x, 0, 3.6), r=0.06, n=1),
              box((0.62, 0.62, 0.1), rubber(), loc=(x, 0, 3.9), r=0.03, n=1))
    yel, blk = plain("#d8b52a", grime=0.5, vary=0.3), rubber()
    n = 40
    pts = [(-7.72 + 15.44 * i / n, 0, 3.55 - 0.85 * (1 - (2 * i / n - 1) ** 2)) for i in range(n + 1)]
    P.add("Body", ribbon(pts, 0.28, (yel, yel, blk), [12 * math.sin(i * 0.7) for i in range(n)]))
    fall = [(7.72, 0, 3.4), (7.4, -0.1, 2.6), (7.0, -0.25, 1.7), (6.6, -0.4, 0.9), (6.2, -0.55, 0.3), (5.8, -0.65, 0.05),
            (5.3, -0.75, 0.012), (4.8, -0.95, 0.012), (4.3, -1.0, 0.012), (3.8, -0.85, 0.012), (3.3, -0.95, 0.012)]
    P.add("Body", ribbon(fall, 0.28, (yel, yel, blk), [0, 5, 10, 15, 30, 60, 90, 90, 90, 90]))


@item("bollard", "warehouse")
def bollard(P):
    P.add("Body", box((1.6, 1.6, 0.15), steel("#4a4d50", chip=0.5), loc=(0, 0, 0.075), r=0.03, n=1))
    for sx in (-1, 1):
        for sy in (-1, 1):
            P.add("Body", cyl(0.09, 0.08, metal("#5a5652", rust=0.7), loc=(sx * 0.62, sy * 0.62, 0.19), seg=6, bevel=0.02))
    yel = paint(SAFETY, chip=0.55, grime=0.6, streaks=0.6)
    for z0, z1, mat in ((0.15, 1.2, yel), (1.2, 1.5, rubber()), (1.5, 2.6, yel), (2.6, 2.9, rubber()), (2.9, 3.4, yel)):
        P.add("Body", cyl(0.6, z1 - z0, mat, loc=(0, 0, (z0 + z1) / 2), seg=6, bevel=0.02))
    P.add("Body", cyl(0.6, 0.18, yel, loc=(0, 0, 3.49), r2=0.46, seg=6, bevel=0.02))
    P.add("Body", handprint(0.05, 2.15, -0.528, s=0.8, rot=-12))
    P.add("Body", oil_streaks(-0.15, 0.2, 1.48, -0.527, (0.5, 0.8), seed=2))


@item("hazard_barrier", "warehouse")
def hazard_barrier(P):
    leg = steel("#55595c")
    for sx in (-1, 1):
        x = sx * 2.6
        for sy in (-1, 1):
            P.add("Body", bar((x, 0, 3.3), (x, sy * 1.0, 0.1), 0.2, leg),
                  box((0.4, 0.5, 0.12), rubber(), loc=(x, sy * 1.0, 0.06), r=0.03, n=1))
        P.add("Body", box((0.36, 0.42, 0.42), rubber(), loc=(x, 0, 3.3), r=0.06, n=1),
              bar((x, -0.66, 1.1), (x, 0.66, 1.1), 0.12, leg))
    lean = -math.degrees(math.atan2(1.0, 3.2))
    board = plain("#e8e2d2", grime=0.6)
    for z in (2.75, 1.6):
        y = -(3.3 - z) / 3.2 - 0.2
        plank = [box((6.0, 0.12, 0.8), board, r=0.03, n=1)] + move(stripes(5.9, 0.7, n=8), loc=(0, -0.07, 0))
        P.add("Body", move(plank, rot=(lean, 0, 0), loc=(0, y, z)))


@item("floor_cage", "warehouse", size=1024, pivots={"Door": (-2.0, -3.9, 3.6)})
def floor_cage(P):
    frame = paint("#5d6b5f", chip=0.45, grime=0.6, streaks=0.6)
    wire = metal("#6a6e6c", rust=0.6)
    for sx in (-1, 1):
        for sy in (-1, 1):
            P.add("Body", box((0.25, 0.25, 8.0), frame, loc=(sx * 3.875, sy * 3.875, 4.0), r=0.03, n=1))
    for z in (0.1, 7.9):
        for s in (-1, 1):
            P.add("Body", box((7.5, 0.2, 0.2), frame, loc=(0, s * 3.875, z), r=0.0, n=1),
                  box((0.2, 7.5, 0.2), frame, loc=(s * 3.875, 0, z), r=0.0, n=1))
    P.add("Body", box((0.2, 7.5, 0.2), frame, loc=(-3.875, 0, 4.0), r=0.0, n=1),
          box((0.2, 7.5, 0.2), frame, loc=(3.875, 0, 4.0), r=0.0, n=1),
          box((7.5, 0.2, 0.2), frame, loc=(0, 3.875, 4.0), r=0.0, n=1))
    for sx in (-1, 1):
        P.add("Body", mesh_panel((sx * 3.88, -3.75, 0.2), (0, 7.5, 0), (0, 0, 7.6), 15, 15, 0.06, wire))
    P.add("Body", mesh_panel((-3.75, 3.88, 0.2), (7.5, 0, 0), (0, 0, 7.6), 15, 15, 0.06, wire))
    P.add("Body", mesh_panel((-3.75, -3.75, 7.88), (7.5, 0, 0), (0, 7.5, 0), 15, 15, 0.06, wire))
    P.add("Body", box((0.2, 0.2, 7.8), frame, loc=(-2.1, -3.875, 3.9), r=0.0, n=1),
          box((0.2, 0.2, 7.8), frame, loc=(1.6, -3.875, 3.9), r=0.0, n=1),
          box((3.5, 0.2, 0.2), frame, loc=(-0.25, -3.875, 7.1), r=0.0, n=1))
    P.add("Body", mesh_panel((-3.75, -3.88, 0.2), (1.65, 0, 0), (0, 0, 7.6), 3, 15, 0.06, wire))
    P.add("Body", mesh_panel((1.7, -3.88, 0.2), (2.05, 0, 0), (0, 0, 7.6), 4, 15, 0.06, wire))
    P.add("Body", mesh_panel((-2.0, -3.88, 7.2), (3.6, 0, 0), (0, 0, 0.68), 7, 1, 0.06, wire))
    for x in (-1.92, 1.42):
        P.add("Door", box((0.15, 0.15, 6.8), frame, loc=(x, -3.9, 3.6), r=0.02, n=1))
    for z in (0.28, 3.6, 6.92):
        P.add("Door", box((3.49, 0.15, 0.15), frame, loc=(-0.25, -3.9, z), r=0.02, n=1))
    P.add("Door", mesh_panel((-1.85, -3.9, 0.35), (3.2, 0, 0), (0, 0, 6.5), 6, 13, 0.06, wire))
    lock = metal("#8a8478", rust=0.5)
    P.add("Door", box((0.3, 0.12, 0.2), lock, loc=(1.42, -4.02, 3.6), r=0.02, n=1),
          box((0.26, 0.14, 0.3), lock, loc=(1.42, -4.1, 3.3), r=0.04, n=1),
          bar((1.34, -4.1, 3.45), (1.34, -4.1, 3.6), 0.04, lock), bar((1.5, -4.1, 3.45), (1.5, -4.1, 3.6), 0.04, lock),
          bar((1.32, -4.1, 3.6), (1.52, -4.1, 3.6), 0.04, lock))
    P.add("Door", box((1.0, 0.04, 0.6), safety(), loc=(0.3, -3.99, 4.6), r=0.02, n=1),
          words("C7", 0.42, rubber(), loc=(0.3, -4.02, 4.6), depth=0.02))


@item("pallet_jack", "warehouse")
def pallet_jack(P):
    red = paint("#8b3326", chip=0.5, grime=0.6, streaks=0.6)
    dark = steel("#3d4144", chip=0.4)
    for sx in (-1, 1):
        P.add("Body", box((0.55, 4.6, 0.24), red, loc=(sx * 0.75, 0.8, 0.22), r=0.04, n=1),
              box((0.55, 0.5, 0.18), red, loc=(sx * 0.75, 3.3, 0.18), rot=(-12, 0, 0), r=0.03, n=1),
              box((0.3, 0.3, 0.14), dark, loc=(sx * 0.75, 2.9, 0.07), r=0.03, n=1))
    P.add("Body", box((2.05, 0.7, 0.32), red, loc=(0, -1.65, 0.38), r=0.05, n=1))
    P.add("Body", cyl(0.36, 1.0, dark, loc=(0, -2.05, 0.95), seg=6, bevel=0.04))
    P.add("Body", box((0.9, 0.7, 0.35), red, loc=(0, -2.05, 1.5), r=0.06, n=1))
    for sx in (-1, 1):
        P.add("Body", cyl(0.32, 0.22, rubber(), loc=(sx * 0.3, -2.15, 0.32), rot=(0, 90, 0), seg=12, bevel=0.04),
              box((0.12, 0.45, 0.5), dark, loc=(sx * 0.48, -2.15, 0.5), r=0.02, n=1))
    base, top = V((0, -2.1, 1.6)), V((0, -3.1, 4.0))
    P.add("Body", bar(base, top, 0.2, red), box((0.3, 0.3, 0.3), dark, loc=base, r=0.04, n=1))
    P.add("Body", bar((-0.6, -3.1, 4.0), (0.6, -3.1, 4.0), 0.16, red), bar((-0.6, -3.25, 4.55), (0.6, -3.25, 4.55), 0.2, rubber()),
          bar((-0.6, -3.1, 4.0), (-0.6, -3.25, 4.55), 0.16, red), bar((0.6, -3.1, 4.0), (0.6, -3.25, 4.55), 0.16, red))
    P.add("Body", box((0.4, 0.1, 0.12), dark, loc=(0, -3.05, 4.3), rot=(-15, 0, 0), r=0.02, n=1))
    P.add("Body", oil_streaks(-0.2, 0.2, 1.33, -2.36, (0.55, 0.8), seed=5))


@item("rolling_ladder", "warehouse", size=1024)
def rolling_ladder(P):
    frame = paint(SAFETY, chip=0.45, grime=0.6, streaks=0.5)
    tread = steel("#55595c", chip=0.4)
    for sx in (-1, 1):
        x = sx * 1.2
        P.add("Body", bar((x, -3.0, 0.5), (x, 1.0, 6.0), 0.2, frame), bar((x, -3.0, 0.5), (x, 3.0, 0.5), 0.2, frame),
              bar((x, 3.0, 0.5), (x, 3.0, 9.1), 0.2, frame), bar((x, 1.0, 0.5), (x, 1.0, 9.1), 0.18, frame),
              bar((x, 1.0, 3.0), (x, 3.0, 3.0), 0.14, frame),
              bar((x, -3.0, 0.5), (x, -3.0, 3.6), 0.15, frame), bar((x, -3.0, 3.6), (x, 1.0, 9.1), 0.15, frame),
              bar((x, 1.0, 9.1), (x, 3.0, 9.1), 0.15, frame), bar((x, 1.0, 7.6), (x, 3.0, 7.6), 0.12, frame))
        for sy in (-1, 1):
            y = sy * 3.0
            P.add("Body", box((0.35, 0.35, 0.15), tread, loc=(x, y, 0.42), r=0.03, n=1),
                  cyl(0.18, 0.12, rubber(), loc=(x, y, 0.18), rot=(0, 90, 0), seg=10, bevel=0.03),
                  box((0.06, 0.25, 0.3), tread, loc=(x + 0.1, y, 0.25), r=0.0, n=1))
    for y, z in ((3.0, 0.5), (-3.0, 0.5), (3.0, 9.1), (3.0, 7.6)):
        P.add("Body", bar((-1.2, y, z), (1.2, y, z), 0.15, frame))
    P.add("Body", bar((-1.2, 3.0, 0.5), (1.2, 3.0, 6.0), 0.12, frame))
    for i in range(1, 6):
        P.add("Body", box((2.25, 0.6, 0.12), tread, loc=(0, -3.0 + 4.0 * i / 6, 0.5 + 5.5 * i / 6), r=0.0, n=1))
    P.add("Body", box((2.6, 2.2, 0.15), tread, loc=(0, 2.0, 6.0), r=0.02, n=1))
    P.add("Body", move(stripes(2.6, 0.3, n=6), loc=(0, 0.88, 5.8)))


@item("fire_cabinet", "warehouse", pivots={"Body": (0, 0, 0), "Door": (-1.4, -0.95, 0)})
def fire_cabinet(P):
    red = paint("#8f2b24", chip=0.35, grime=0.65, streaks=0.8)
    P.add("Body", hollow(2.8, 0.9, 3.8, red, y=-0.45, z0=-1.9, t=0.1))
    reel = paint("#7a2620", chip=0.3)
    hose = cloth("#c9b48a", dirt=0.5)
    P.add("Body", cyl(1.0, 0.12, reel, loc=(0, -0.2, 0.35), rot=(90, 0, 0), seg=16),
          cyl(0.2, 0.4, steel(), loc=(0, -0.35, 0.35), rot=(90, 0, 0), seg=8),
          torus(0.75, 0.13, hose, loc=(0, -0.38, 0.35), rot=(90, 0, 0), seg=16, sub=6),
          torus(0.52, 0.12, hose, loc=(0, -0.5, 0.35), rot=(90, 0, 0), seg=14, sub=6))
    P.add("Body", bar((0.75, -0.45, 0.2), (0.9, -0.5, -0.5), 0.2, hose),
          cyl(0.13, 0.6, metal("#8a7a50", rust=0.4), loc=(0.9, -0.5, -0.85), seg=6, bevel=0.03),
          box((0.3, 0.3, 0.1), metal("#8a7a50", rust=0.4), loc=(0.9, -0.5, -1.18), r=0.02, n=1))
    P.add("Body", cyl(0.3, 0.08, red, loc=(-0.8, -0.5, -1.35), rot=(90, 0, 0), seg=6, bevel=0.02),
          box((0.12, 0.4, 0.12), steel(), loc=(-0.8, -0.3, -1.35), r=0.0, n=1))
    for sx in (-1, 1):
        P.add("Door", box((0.25, 0.1, 3.8), red, loc=(sx * 1.275, -0.95, 0), r=0.03, n=1))
        P.add("Door", box((2.8, 0.1, 0.25), red, loc=(0, -0.95, sx * 1.775), r=0.03, n=1))
    P.add("Door", box((2.35, 0.04, 3.35), plain("#a9bcbc", grime=0.8, vary=0.4), loc=(0, -0.95, 0), r=0.0, n=1))
    for ang, ln in ((30, 0.9), (-50, 0.7), (110, 0.6), (200, 0.5)):
        c = box((ln, 0.01, 0.03), flat("#2a3333"), loc=(ln / 2, 0, 0), r=0.0, n=1)
        P.add("Door", move(c, rot=(0, ang, 0), loc=(0.45, -0.975, -0.5)))
    P.add("Door", words("FIRE", 0.55, plain("#b8322a", grime=0.3), loc=(0, -0.98, 1.1), depth=0.02))
    P.add("Door", box((0.1, 0.12, 0.4), steel("#3d4144"), loc=(1.2, -1.06, 0), r=0.03, n=1))
    P.add("Door", handprint(-0.45, -0.25, -0.976, s=0.9, rot=8))


@item("electrical_panel", "warehouse", pivots={"Body": (0, 0, 0), "Glow": (0, 0, 0), "Door": (-1.2, -0.64, 0)})
def electrical_panel(P):
    grey = steel("#717a7c", chip=0.35)
    dark = plain("#2a2a2a", grime=0.4)
    P.add("Body", hollow(2.4, 0.6, 3.8, grey, y=-0.3, z0=-1.9, t=0.08))
    P.add("Body", box((2.4, 0.08, 0.5), grey, loc=(0, -0.56, 1.65), r=0.02, n=1))
    P.add("Body", box((2.1, 0.04, 3.0), flat("#3a3c3e"), loc=(0, -0.1, -0.3), r=0.0, n=1))
    for sx in (-1, 1):
        for i in range(8):
            P.add("Body", box((0.5, 0.12, 0.22), dark, loc=(sx * 0.4, -0.18, -1.5 + i * 0.3), r=0.0, n=1))
    P.add("Body", box((1.0, 0.18, 0.45), dark, loc=(0, -0.2, 1.05), r=0.02, n=1))
    P.add("Body", box((1.6, 0.4, 2.0), grey, loc=(0, -0.25, 2.9), r=0.04, n=1),
          box((1.7, 0.46, 0.12), steel("#4a4d50"), loc=(0, -0.25, 1.96), r=0.02, n=1))
    P.add("Body", box((0.42, 0.06, 0.32), dark, loc=(0.75, -0.61, 1.65), r=0.04, n=1))
    P.add("Body", words("480V", 0.26, plain("#e3d8bd", grime=0.4), loc=(-0.45, -0.61, 1.65), depth=0.015))
    P.add("Glow", box((0.32, 0.1, 0.22), alarm_red(), loc=(0.75, -0.66, 1.65), r=0.05, n=1))
    P.add("Door", box((2.4, 0.08, 3.3), grey, loc=(0, -0.64, -0.25), r=0.03, n=1))
    for i in range(5):
        P.add("Door", box((0.9, 0.02, 0.06), flat("#1a1a1a"), loc=(-0.3, -0.685, -1.6 + i * 0.14), r=0.0, n=1))
    tri = [(-0.4, -0.3), (0.4, -0.3), (0.0, 0.39)]
    P.add("Door", slab([(x * 1.18, z * 1.18) for x, z in tri], 0.01, rubber(), loc=(0, -0.685, 0.6)),
          slab(tri, 0.01, plain(SAFETY, grime=0.4), loc=(0, -0.693, 0.6)),
          slab([(0.05, 0.22), (-0.1, -0.02), (0.0, -0.02), (-0.06, -0.22), (0.1, 0.04), (0.0, 0.04)], 0.01, rubber(), loc=(0, -0.7, 0.55)))
    P.add("Door", box((0.12, 0.12, 0.45), steel("#3d4144"), loc=(0.95, -0.73, -0.2), r=0.03, n=1))
    P.add("Door", handprint(-0.45, -0.6, -0.686, s=0.85, rot=-20))
    P.add("Door", oil_streaks(0.85, 1.05, -0.45, -0.686, (0.6, 0.9), seed=9))


@item("shopping_cart", "warehouse", size=512)
def shopping_cart(P):
    rust = metal("#8f8f8a", rust=0.9)
    t = 0.06

    def corner(sx, sy, f):
        b = V((sx * 0.72, -1.05 if sy < 0 else 1.25, 2.0))
        u = V((sx * 0.98, -1.55 if sy < 0 else 1.55, 3.3))
        return b.lerp(u, f)

    for sx in (-1, 1):
        for i in range(11):
            k = i / 10
            P.add("Body", bar(corner(sx, -1, 0).lerp(corner(sx, 1, 0), k), corner(sx, -1, 1).lerp(corner(sx, 1, 1), k), t, rust))
    for sy in (-1, 1):
        for i in range(1, 7):
            k = i / 7
            P.add("Body", bar(corner(-1, sy, 0).lerp(corner(1, sy, 0), k), corner(-1, sy, 1).lerp(corner(1, sy, 1), k), t, rust))
    for f, th in ((0.0, 0.07), (0.5, t), (1.0, 0.09)):
        ring = [corner(-1, -1, f), corner(1, -1, f), corner(1, 1, f), corner(-1, 1, f)]
        for a, b in zip(ring, ring[1:] + ring[:1]):
            P.add("Body", bar(a, b, th, rust))
    for i in range(1, 6):
        x = -0.72 + 1.44 * i / 6
        P.add("Body", bar((x, -1.05, 2.0), (x, 1.25, 2.0), t, rust))
    for sx in (-1, 1):
        P.add("Body", bar((sx * 0.72, 1.45, 0.45), (sx * 0.9, 1.8, 3.6), 0.1, rust),
              bar((sx * 0.72, -1.2, 0.45), (sx * 0.72, 1.45, 0.45), 0.12, rust),
              bar((sx * 0.72, -1.2, 0.45), (sx * 0.72, -0.95, 2.0), 0.08, rust),
              bar((sx * 0.98, 1.55, 3.3), (sx * 0.89, 1.76, 3.3), 0.08, rust),
              bar((sx * 0.72, 1.25, 2.0), (sx * 0.81, 1.62, 2.0), 0.08, rust),
              bar((sx * 0.72, -0.9, 0.45), (sx * 0.72, -0.9, 0.85), 0.06, rust))
    P.add("Body", bar((-0.72, -1.2, 0.45), (0.72, -1.2, 0.45), 0.12, rust))
    P.add("Body", bar((-1.0, 1.85, 3.62), (1.0, 1.85, 3.62), 0.1, rust),
          box((1.6, 0.18, 0.18), plain("#7e2a24", grime=0.6), loc=(0, 1.85, 3.62), r=0.06, n=1))
    for i in range(5):
        x = -0.6 + 1.2 * i / 4
        P.add("Body", bar((x, -0.9, 0.85), (x, 1.35, 0.85), 0.05, rust))
    for y in (-0.9, 1.35):
        P.add("Body", bar((-0.72, y, 0.85), (0.72, y, 0.85), 0.06, rust))
    for sx in (-1, 1):
        for y in (-1.2, 1.45):
            turned = sx > 0 and y > 0
            P.add("Body", box((0.2, 0.2, 0.18), steel("#4a4d50", chip=0.5), loc=(sx * 0.72, y, 0.36), r=0.02, n=1),
                  cyl(0.2, 0.1, rubber(), loc=(sx * 0.72, y, 0.2), rot=(90, 0, 0) if turned else (0, 90, 0), seg=10, bevel=0.03))


@item("wet_floor_sign", "warehouse")
def wet_floor_sign(P):
    yel = plain("#d6ad2a", grime=0.6, vary=0.3)
    ink = rubber()
    shape = [(-0.55, 0.0), (0.55, 0.0), (0.55, 1.9), (0.4, 2.3), (-0.4, 2.3), (-0.55, 1.9)]
    tri = [(-0.3, -0.24), (0.3, -0.24), (0.0, 0.28)]
    lean = math.degrees(math.atan2(0.55, 2.3))
    for side in (-1, 1):
        panel = [slab(shape, 0.08, yel),
                 slab([(x * 1.25, z * 1.25) for x, z in tri], 0.01, ink, loc=(0, -0.045, 1.55)),
                 slab(tri, 0.01, yel, loc=(0, -0.052, 1.53)),
                 box((0.06, 0.01, 0.2), ink, loc=(0, -0.058, 1.56), r=0.0, n=1),
                 box((0.06, 0.01, 0.06), ink, loc=(0, -0.058, 1.4), r=0.0, n=1),
                 words("SLIP", 0.36, ink, loc=(0, -0.05, 0.95), depth=0.01),
                 box((1.0, 0.01, 0.06), oil(), loc=(0.05, -0.046, 0.2), rot=(0, 4, 0), r=0.0, n=1)]
        if side > 0:
            move(panel, rot=(0, 0, 180))
        P.add("Body", move(panel, rot=(side * lean, 0, 0), pivot=(0, 0, 2.3)))
    P.add("Body", box((0.15, 0.16, 0.25), yel, loc=(-0.3, 0, 2.4), r=0.03, n=1),
          box((0.15, 0.16, 0.25), yel, loc=(0.3, 0, 2.4), r=0.03, n=1),
          box((0.75, 0.18, 0.14), yel, loc=(0, 0, 2.56), r=0.05, n=1))


# ---------------------------------------------------------------- liminal pockets

TROFFER_TOP = 0.45


@item("light_troffer", "warehouse", pivots=top_pivots(TROFFER_TOP, parts=("Body", "Glow")))
def light_troffer(P):
    trim = plain("#e6e3d8", grime=0.5, vary=0.2)
    P.add("Body", box((3.8, 1.8, 0.4), housing(), loc=(0, 0, 0.25), r=0.03, n=1))
    for sy in (-1, 1):
        P.add("Body", box((4.2, 0.2, 0.08), trim, loc=(0, sy * 1.0, 0.04), r=0.0, n=1))
    for sx in (-1, 1):
        P.add("Body", box((0.2, 2.2, 0.08), trim, loc=(sx * 2.0, 0, 0.04), r=0.0, n=1))
    P.add("Body", box((3.8, 0.08, 0.07), trim, loc=(0, 0, 0.02), r=0.0, n=1))
    P.add("Glow", box((3.8, 1.8, 0.05), cold(), loc=(0, 0, 0.06), r=0.0, n=1))


@item("picket_fence", "warehouse")
def picket_fence(P):
    white = paint("#e8e4da", chip=0.3, under="#8a8070", grime=0.55, streaks=0.5)
    picket = [(-0.22, 0.15), (0.22, 0.15), (0.22, 2.9), (0.06, 3.25), (-0.06, 3.25), (-0.22, 2.9)]
    for sx in (-1, 1):
        P.add("Body", box((0.4, 0.4, 3.5), white, loc=(sx * 3.8, 0.1, 1.75), r=0.03, n=1),
              box((0.5, 0.5, 0.12), white, loc=(sx * 3.8, 0.1, 3.56), r=0.02, n=1))
    for z in (0.8, 2.4):
        P.add("Body", box((7.4, 0.12, 0.3), white, loc=(0, 0.16, z), r=0.02, n=1))
    for i in range(10):
        P.add("Body", slab(picket, 0.1, white, loc=(-3.24 + i * 0.72, 0.05, 0), bevel=0.02))


ROAD_SIGN_FACE = [(math.cos(math.radians(22.5 + 45 * i)) * 1.3, math.sin(math.radians(22.5 + 45 * i)) * 1.3) for i in range(8)]


@item("road_sign", "warehouse")
def road_sign(P):
    screen_png(P, 512, 512, "#b03a30", '<polygon points="' + " ".join(
        f"{256 + 236 * math.cos(math.radians(22.5 + 45 * i)):.0f},{256 + 236 * math.sin(math.radians(22.5 + 45 * i)):.0f}" for i in range(8))
               + '" fill="none" stroke="#efe6d6" stroke-width="16"/><rect x="116" y="216" width="280" height="80" fill="#efe6d6"/>')
    grey = steel("#8a8d8c", chip=0.4)
    z = 6.2
    P.add("Body", box((0.25, 0.25, 6.4), grey, loc=(0, 0.2, 3.2), r=0.02, n=1),
          box((0.33, 0.33, 0.08), grey, loc=(0, 0.2, 6.44), r=0.01, n=1),
          box((1.0, 1.0, 0.1), grey, loc=(0, 0.2, 0.05), r=0.02, n=1))
    P.add("Body", slab([(x * 1.06, y * 1.06) for x, y in ROAD_SIGN_FACE], 0.06, grey, loc=(0, 0.04, z)))
    P.add("Screen", slab(ROAD_SIGN_FACE, 0.03, plain("#b03a30", grime=0.3), loc=(0, -0.01, z)))
    for dz in (-0.7, 0.7):
        P.add("Body", box((0.4, 0.06, 0.12), grey, loc=(0, 0.1, z + dz), r=0.0, n=1))


@item("door_frame_lone", "warehouse", size=1024, pivots={"Door": (-1.75, 0, 3.5)})
def door_frame_lone(P):
    jamb = paint("#a07850", chip=0.25, under="#5a4430", grime=0.5, streaks=0.4)
    for sx in (-1, 1):
        P.add("Body", box((0.35, 0.6, 7.35), jamb, loc=(sx * 1.925, 0, 3.675), r=0.04, n=1),
              box((0.6, 1.6, 0.12), jamb, loc=(sx * 1.925, 0, 0.06), r=0.02, n=1))
    P.add("Body", box((4.2, 0.6, 0.35), jamb, loc=(0, 0, 7.175), r=0.04, n=1))
    door = plain("#d9d2c2", grime=0.5, vary=0.2)
    P.add("Door", box((3.44, 0.15, 6.94), door, loc=(0, 0, 3.5), r=0.03, n=1))
    for z in (5.1, 2.0):
        P.add("Door", box((2.6, 0.03, 2.4 if z > 3 else 2.8), door, loc=(0, -0.09, z), r=0.02, n=1))
    knob = metal("#9a958a", rust=0.3)
    P.add("Door", box((0.25, 0.08, 0.35), knob, loc=(1.35, -0.11, 3.4), r=0.03, n=1),
          box((0.42, 0.1, 0.1), knob, loc=(1.25, -0.18, 3.45), r=0.03, n=1))
    P.add("Body", box((1.3, 0.14, 0.62), plain("#e6e3d8", grime=0.4), loc=(0, -0.36, 7.85), r=0.03, n=1),
          box((0.12, 0.2, 0.3), plain("#e6e3d8"), loc=(0, -0.2, 7.5), r=0.0, n=1))
    P.add("Glow", box((1.18, 0.04, 0.5), exit_green(), loc=(0, -0.44, 7.85), r=0.0, n=1))
    ink = plain("#ecebe2", grime=0.3)
    P.add("Body", box((0.04, 0.01, 0.34), ink, loc=(-0.45, -0.465, 7.85), r=0.0, n=1),
          box((0.04, 0.01, 0.34), ink, loc=(-0.19, -0.465, 7.85), r=0.0, n=1),
          box((0.3, 0.01, 0.04), ink, loc=(-0.32, -0.465, 8.0), r=0.0, n=1),
          slab([(x * 0.7, z * 0.7) for x, z in ARROW], 0.01, ink, loc=(0.25, -0.465, 7.85)))


@item("handrail", "warehouse", pivots={"Body": (0, 0, 0)})
def handrail(P):
    rail = steel("#7a7f80", chip=0.5)
    P.add("Body", box((8.0, 0.25, 0.25), rail, loc=(0, -0.6, 0), r=0.04, n=1))
    for sx in (-1, 1):
        P.add("Body", box((0.25, 0.6, 0.25), rail, loc=(sx * 3.875, -0.3, 0), r=0.04, n=1))
    for x in (-2.5, 0.0, 2.5):
        P.add("Body", box((0.5, 0.06, 0.6), rail, loc=(x, -0.03, -0.35), r=0.02, n=1),
              box((0.14, 0.5, 0.14), rail, loc=(x, -0.3, -0.35), r=0.0, n=1),
              box((0.14, 0.14, 0.35), rail, loc=(x, -0.6, -0.25), r=0.0, n=1))
    P.add("Body", handprint(1.2, 0.0, -0.73, s=0.5, rot=90))


@item("picture_frame", "warehouse", pivots=WALL)
def picture_frame(P):
    screen_png(P, 440, 560, "#c9a9d6", '<defs><linearGradient id="s" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#9b86c4"/>'
               '<stop offset="1" stop-color="#f2c6cf"/></linearGradient></defs><rect width="440" height="560" fill="url(#s)"/>'
               '<circle cx="320" cy="150" r="70" fill="#fbeec4"/><path d="M0 400 Q200 300 440 380 L440 560 L0 560Z" fill="#8fc49a"/>'
               '<rect x="120" y="330" width="90" height="70" fill="#f4c7c3"/><path d="M110 332 L165 290 L220 332Z" fill="#c98f8f"/>'
               '<rect x="150" y="360" width="22" height="40" fill="#7a6a80"/>')
    frame = wood("#8a6a3a", "#4d3a20", axis="x", wear=0.5)
    P.add("Body", box((2.4, 0.08, 3.0), plain("#3a3530"), loc=(0, -0.04, 0), r=0.0, n=1))
    for sx in (-1, 1):
        P.add("Body", box((0.25, 0.2, 3.0), frame, loc=(sx * 1.075, -0.1, 0), r=0.03, n=1),
              box((2.4, 0.2, 0.25), frame, loc=(0, -0.1, sx * 1.375), r=0.03, n=1))
    P.add("Screen", box((1.92, 0.02, 2.52), plain("#c9a9d6"), loc=(0, -0.1, 0), r=0.0, n=1))



# ---------------------------------------------------------------- installations (lit dreamcore rooms in the dark)

def moulded_orange():
    """Glossy moulded plastic gone a bit chalky: pale scuffs on the rims, a soft fake sheen, grime in the dips."""
    g = kit.G("plain")
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(1.8, 4), 0.3, 0.75), 0.15), "#e4511a", "#e07a48")
    scuffs = g.math("MULTIPLY", g.step(g.noise(9, 5, stretch=(1, 1, 0.2)), 0.68, 0.78), 0.5)
    rims = g.math("MULTIPLY", g.step(g.edge(0.12), 0.05, 0.4), 0.6)
    c = g.mix(g.math("ADD", scuffs, rims, clamp=True), c, "#f2b48c")
    sheen = g.n("ShaderNodeVectorMath")
    sheen.operation = "DOT_PRODUCT"
    g.t.links.new(g.geo.outputs["Normal"], sheen.inputs[0])
    sheen.inputs[1].default_value = V((-0.35, -0.55, 0.76)).normalized()
    c = g.mix(g.math("MULTIPLY", g.step(sheen.outputs["Value"], 0.86, 0.98), 0.45), c, "#ffe2c8")
    c = g.mix(g.math("MULTIPLY", g.step(g.noise(3.5, 6, world=True), 0.5, 0.8), 0.15), c, "#6a5646", "MULTIPLY")
    return g.done(c, ao=0.8)


def _spline(pts, per):
    """Catmull-Rom through 2D points, per samples per stretch."""
    pts = [pts[0]] + pts + [pts[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = (V(p) for p in pts[i - 1:i + 3])
        for k in range(per):
            t = k / per
            out.append(0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (3 * p1 - p0 - 3 * p2 + p3) * t ** 3))
    out.append(V(pts[-2]))
    return out


@item("giant_chair", "warehouse", size=1024)
def giant_chair(P):
    # One moulded shell: side profile (y, z) runs from under the rolled front lip, over the seat, round the soft
    # bend and up the back. Each cross-section is a thin dished strip, lofted along that path.
    path = _spline([(-3.5, 8.45), (-4.2, 8.75), (-4.25, 9.3), (-3.6, 9.55), (-1.5, 9.25), (1.2, 9.15), (2.9, 9.35),
                    (3.75, 10.2), (4.1, 11.8), (4.45, 14.0), (4.85, 16.2), (5.25, 17.75)], 4)
    n = len(path)
    dist = [0.0]
    for a, b in zip(path, path[1:]):
        dist.append(dist[-1] + (b - a).length)
    t, half = 0.32, 10
    rings = []
    for i, p in enumerate(path):
        s = dist[i] / dist[-1]
        tan = (path[min(i + 1, n - 1)] - path[max(i - 1, 0)]).normalized()
        nrm = V((-tan.y, tan.x))
        lip = min(1.0, max(0.0, (dist[i] - 2.2) / 1.5))
        back = min(1.0, max(0.0, (s - 0.55) / 0.12))
        width = 8.6 - 0.8 * back - 0.6 * math.exp(-((s - 0.6) / 0.12) ** 2)
        top_round = (dist[-1] - dist[i]) / 1.6
        if top_round < 1.0:
            width *= math.sqrt(max(0.05, 1.0 - (1.0 - top_round) ** 2))
        dish = lip * (0.55 - 0.15 * back) * (1.0 - 0.6 * math.exp(-((s - 0.6) / 0.1) ** 2)) * min(1.0, top_round)
        ring = []
        for side, off in ((1, t / 2), (-1, -t / 2)):
            for j in range(half + 1):
                u = (j / half * 2 - 1) * side
                x = u * width / 2
                d = off + dish * u ** 4
                ring.append(V((x, p.x + nrm.x * d, p.y + nrm.y * d)))
            x = side * (width / 2 + t * 0.45)
            ring.append(V((x, p.x + nrm.x * dish, p.y + nrm.y * dish)))
        rings.append(ring)
    P.add("Body", loft(rings, moulded_orange(), smooth=70))
    legs = metal("#8f918f", rust=0.3)
    for sx in (-1, 1):
        P.add("Body", box((0.5, 6.4, 0.35), legs, loc=(sx * 2.9, -0.3, 8.85), r=0.08, n=1))
        for y0, y1 in ((-3.2, -4.1), (2.6, 3.6)):
            P.add("Body", bar((sx * 2.9, y0, 8.95), (sx * 3.85, y1, 0.3), 0.42, legs),
                  box((0.7, 0.7, 0.3), rubber(), loc=(sx * 3.85, y1, 0.15), r=0.08, n=1))


@item("giant_cloud", "warehouse", size=1024)
def giant_cloud(P):
    white = plain("#f4f3ef", grime=0.06, vary=0.18, ao=0.6)
    rnd = random.Random(11)
    lumps = [(0, 0, 7, 7.5), (-7, 1, 5, 5.5), (7, -1, 5, 6), (-12, 0, 3, 3.8), (12, 1, 3, 4), (-3, -2, 11, 5.5),
             (4, 1, 12, 5), (0, 2, 15, 3.8), (-9, -3, 8, 3.6), (9, 3, 8, 3.8), (-4, 4, 4, 4.5), (4, -4, 4, 4.5), (-14, 1, 2.5, 2.8), (14, -1, 2.5, 2.6)]
    for x, y, z, r in lumps:
        P.add("Body", ball((r * rnd.uniform(1.0, 1.2), r * 0.85, r), white, loc=(x, y, z), seg=14, rings=9))
    for o in P.parts["Body"]:
        warp(o, lambda c: V((c.x, c.y, max(c.z, 0.6))))


@item("curtains", "warehouse", size=1024)
def curtains(P):
    blue = cloth("#5f8fc4", dirt=0.35, weave=90)
    top, w = 14.0, 7.7

    def panel(sx):
        def at(u, v):
            x = sx * (0.3 + w * (1 - u))
            x += sx * (1 - v) ** 2 * 1.4 * (0.5 - u)
            y = 0.35 * math.sin(u * w * 2.4) * (0.6 + 0.4 * (1 - v)) - 0.4 * (1 - v) ** 2
            return x, y, 0.05 + (top - 0.05) * v
        return sheet(36, 5, at, 0.12, blue)

    P.add("Body", panel(-1), panel(1))
    rail = steel("#3d4144")
    P.add("Body", box((16.8, 0.6, 0.45), rail, loc=(0, 0, top + 0.2), r=0.05, n=1),
          box((17.2, 0.9, 0.2), rail, loc=(0, 0.1, top + 0.5), r=0.03, n=1))


@item("pink_bench", "warehouse")
def pink_bench(P):
    pink = cloth("#e7a6b8", dirt=0.3, weave=70)
    frame = metal("#8a8a86", rust=0.3)
    P.add("Body", box((8.2, 2.2, 0.25), plain("#c88a9c", grime=0.4), loc=(0, 0, 1.0), r=0.05, n=1))
    for i in range(5):
        x = -3.28 + i * 1.64
        P.add("Body", box((1.6, 2.1, 0.45), pink, loc=(x, -0.05, 1.33), r=0.18, n=1),
              box((1.6, 0.45, 1.3), pink, loc=(x, 0.9, 2.2), rot=(-8, 0, 0), r=0.18, n=1))
    for sx in (-1, 1):
        for sy in (-1, 1):
            P.add("Body", box((0.12, 0.12, 0.9), frame, loc=(sx * 3.7, sy * 0.85, 0.45), r=0.0, n=1))


def star(r, mat, loc, rot, inner=0.45):
    """Flat five-point star facing -y, as five convex kites so it triangulates cleanly."""
    pt = lambda i: (math.cos(math.radians(90 + 36 * i)) * (r if i % 2 == 0 else r * inner),
                    math.sin(math.radians(90 + 36 * i)) * (r if i % 2 == 0 else r * inner))
    kites = [slab([(0, 0), pt(i - 1), pt(i), pt(i + 1)], 0.05, mat) for i in range(0, 10, 2)]
    return move(kites, rot=(0, rot, 0), loc=loc)


@item("star_decal", "warehouse", pivots={"Body": (0, 0, 0)})
def star_decal(P):
    cream, red, gold = plain("#efe2c6", grime=0.35), plain("#c2473f", grime=0.35), plain("#d9b04a", grime=0.35)
    for x, z, r, mat, rot in ((-2.4, 1.0, 0.9, cream, 8), (1.6, 1.4, 0.55, cream, -12), (2.6, -0.9, 0.85, red, 15),
                              (-0.6, -1.3, 0.45, gold, -5), (0.4, 0.2, 0.3, red, 20), (-2.8, -1.2, 0.35, cream, 0)):
        P.add("Body", star(r, mat, (x, -0.025, z), rot))


@item("moon_window", "warehouse", pivots={"Body": (0, 0, 0), "Glow": (0, 0, 0)})
def moon_window(P):
    trim = plain("#e9e4d8", grime=0.45)
    w, h = 3.0, 3.4
    P.add("Body", box((w - 0.4, 0.06, h - 0.4), flat("#0c1020"), loc=(0, -0.3, 0), r=0.0, n=1))
    for sx in (-1, 1):
        P.add("Body", box((0.3, 0.6, h), trim, loc=(sx * (w / 2 - 0.15), -0.3, 0), r=0.04, n=1),
              box((w, 0.6, 0.3), trim, loc=(0, -0.3, sx * (h / 2 - 0.15)), r=0.04, n=1))
    P.add("Body", box((w + 0.4, 0.9, 0.18), trim, loc=(0, -0.45, -h / 2 - 0.05), r=0.04, n=1))
    P.add("Glow", cyl(0.32, 0.04, glow("#f3efd9", core="#ffffff", amount=0.15), loc=(0.55, -0.35, 0.75), rot=(90, 0, 0), seg=16, bevel=0.01))


main()
