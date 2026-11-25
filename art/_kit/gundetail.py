# Close-up detail shared by the guns (gear/build.py) and the first-person blaster (viewmodel/build.py).
# Guns point along -y, side faces are +-x, up is +z. Everything here returns mesh objects to P.add().
from ykit import *  # noqa

LINE = "#1a1b1e"
WHITE = "#ecebe6"
GREY = "#9aa0a4"
DARK = "#2b2d31"
ORANGE = "#f07f2a"
TEAL = "#2bb3a8"
STEEL = "#3a3c40"
MARKER = "#34322f"


def marker(loc):
    """Hidden 0.08 cube the game code reads for a position."""
    return box((0.08, 0.08, 0.08), flat(MARKER), loc=loc, r=0.0, n=1)


def seam_y(x, y0, y1, z, t=0.008):
    """Dark panel line along the gun on a side face (x is the face, sign picks the side)."""
    return box((0.006, abs(y1 - y0), t), flat(LINE), loc=(x, (y0 + y1) / 2, z), r=0.0, n=1)


def seam_z(x, y, z0, z1, t=0.008):
    return box((0.006, t, abs(z1 - z0)), flat(LINE), loc=(x, y, (z0 + z1) / 2), r=0.0, n=1)


def panel(x, y0, y1, z0, z1, screws_at=True, mirror=True):
    """Panel outline on the side faces, with a screw in two corners."""
    out = []
    for sx in (1, -1) if mirror else (1,):
        fx = sx * x
        out += [seam_y(fx, y0, y1, z0), seam_y(fx, y0, y1, z1), seam_z(fx, y0, z0, z1), seam_z(fx, y1, z0, z1)]
        if screws_at:
            out += [bolt(0.013, loc=(fx + sx * 0.002, y0 + 0.03, z1 - 0.025), normal=(sx, 0, 0)),
                    bolt(0.013, loc=(fx + sx * 0.002, y1 - 0.03, z0 + 0.025), normal=(sx, 0, 0))]
    return out


def vents(x, y0, y1, z, h, n=4, mirror=True):
    """Row of cooling slots on the side faces: a grey frame with dark slots in it."""
    out, step = [], (y1 - y0) / n
    for sx in (1, -1) if mirror else (1,):
        fx = sx * x
        out.append(box((0.012, abs(y1 - y0) + 0.03, h + 0.03), plain(GREY, grime=0.5), loc=(fx, (y0 + y1) / 2, z), r=0.004, n=1))
        for k in range(n):
            out.append(box((0.016, step * 0.55, h), flat("#0e0e10"), loc=(fx + sx * 0.002, y0 + step * (k + 0.5), z), r=0.0, n=1))
    return out


def top_vents(y0, y1, z, w, n=4):
    """Slots across the top face."""
    step = (y1 - y0) / n
    return [box((w, step * 0.5, 0.012), flat("#0e0e10"), loc=(0, y0 + step * (k + 0.5), z), r=0.0, n=1) for k in range(n)]


def cell_window(x, y0, y1, zc, h, color, bars=3, mirror=True):
    """A glowing power cell seen through a framed window on the side. Returns (body parts, glow parts)."""
    body, lit_parts = [], []
    length = abs(y1 - y0)
    for sx in (1, -1) if mirror else (1,):
        fx = sx * x
        body.append(box((0.014, length + 0.05, h + 0.05), plain(DARK, grime=0.3), loc=(fx, (y0 + y1) / 2, zc), r=0.008, n=1))
        lit_parts.append(box((0.012, length, h), glow(color, amount=0.0), loc=(fx + sx * 0.005, (y0 + y1) / 2, zc), r=0.003, n=1))
        for k in range(bars):
            y = y0 + length * (k + 1) / (bars + 1)
            body.append(box((0.02, 0.018, h + 0.03), plain(GREY, grime=0.4), loc=(fx + sx * 0.008, y, zc), r=0.003, n=1))
    return body, lit_parts


def lean_point(centre, lean, ly, lz):
    """Point in a grip's own frame (ly forward/back, lz up its length), for a grip box built with rot=(lean, 0, 0)."""
    a = math.radians(lean)
    cy, cz = centre
    return (cy + ly * math.cos(a) - lz * math.sin(a), cz + ly * math.sin(a) + lz * math.cos(a))


def grip_texture(y, z, h, w=0.17, d=0.23, lean=14, ribs=6):
    """Rubber ridges down the sides and back of a grip box, and finger bumps on the front."""
    out, m = [], plain("#202124", grime=0.2, vary=0.1)
    for k in range(ribs):
        lz = -h * 0.36 + h * 0.62 * k / max(1, ribs - 1)
        for sx in (1, -1):
            py, pz = lean_point((y, z), lean, 0.01, lz)
            out.append(box((0.012, d * 0.66, 0.022), m, loc=(sx * (w / 2 + 0.002), py, pz), rot=(lean, 0, 0), r=0.006, n=1))
        py, pz = lean_point((y, z), lean, d / 2 + 0.002, lz)
        out.append(box((w * 0.7, 0.014, 0.024), m, loc=(0, py, pz), rot=(lean, 0, 0), r=0.006, n=1))
    for k in range(3):
        lz = -h * 0.22 + h * 0.2 * k
        py, pz = lean_point((y, z), lean, -d / 2 - 0.004, lz)
        out.append(box((w * 0.86, 0.03, 0.05), m, loc=(0, py, pz), rot=(lean, 0, 0), r=0.014, n=1))
    return out


def rail(y0, y1, z, w=0.09):
    """Ribbed mounting rail on top. z is the surface it sits on."""
    out = [box((w, abs(y1 - y0), 0.025), plain(STEEL, grime=0.25), loc=(0, (y0 + y1) / 2, z + 0.012), r=0.004, n=1)]
    n = max(2, int(abs(y1 - y0) / 0.045))
    for k in range(n):
        out.append(box((w + 0.02, 0.022, 0.02), plain(STEEL, grime=0.25), loc=(0, y0 + (y1 - y0) * (k + 0.5) / n, z + 0.033), r=0.003, n=1))
    return out


def reflex(y, z, glass="#1f5e5a", w=0.15, h=0.12):
    """Small open sight on a rail: a base, a frame around a tinted pane, an orange adjust knob. z is the rail top."""
    d = plain(DARK, grime=0.3)
    out = [box((w, 0.13, 0.035), d, loc=(0, y, z + 0.018), r=0.008, n=1)]
    for sx in (1, -1):
        out.append(box((0.025, 0.05, h), d, loc=(sx * (w / 2 - 0.0125), y - 0.03, z + h / 2 + 0.03), r=0.006, n=1))
    out.append(box((w, 0.05, 0.025), d, loc=(0, y - 0.03, z + h + 0.03), r=0.006, n=1))
    out.append(box((w - 0.05, 0.008, h - 0.02), flat(glass), loc=(0, y - 0.03, z + h / 2 + 0.035), r=0.0, n=1))
    out.append(box((0.016, 0.004, 0.016), flat(ORANGE), loc=(0, y - 0.036, z + h / 2 + 0.035), r=0.0, n=1))
    out.append(cyl(0.018, 0.025, plain(ORANGE, grime=0.2), loc=(w / 2 + 0.01, y + 0.02, z + 0.05), rot=(0, 90, 0), seg=8, bevel=0.004))
    return out


def shroud(y, z, r, length, ports=3):
    """Chunky hex muzzle shroud with ports in the sides. y is the front face."""
    out = [cyl(r, length, plain(DARK, grime=0.3), loc=(0, y + length / 2, z), rot=(90, 30, 0), seg=6, bevel=0.012)]
    for k in range(ports):
        py = y + length * (k + 0.5) / ports
        for sx in (1, -1):
            out.append(box((0.02, length / ports * 0.5, r * 0.7), flat("#0e0e10"), loc=(sx * r * 0.86, py, z), r=0.0, n=1))
    out.append(cyl(r * 0.5, 0.01, flat("#0c0c0e"), loc=(0, y - 0.002, z), rot=(90, 0, 0), seg=6, bevel=0.0))
    return out


def stripes(w, h, loc, normal, n=4):
    """Yellow and black hazard stripes on a flat face."""
    base = slab([(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)], 0.01, flat("#f2c230"))
    out = [base]
    s = w / (2 * n)
    k = h * 0.7
    clamp = lambda x: max(-w / 2, min(w / 2, x))
    for i in range(n):
        x0 = -w / 2 + 2 * i * s
        poly = [(clamp(x0), -h / 2), (clamp(x0 + s), -h / 2), (clamp(x0 + s + k), h / 2), (clamp(x0 + k), h / 2)]
        if poly[0][0] < poly[1][0]:
            out.append(slab(poly, 0.016, flat("#1e1e22")))
    if tuple(normal) == (0, 1, 0):
        # aim() picks an arbitrary half turn for a straight flip, which stands the stripes on end
        return move(out, loc=loc, rot=(0, 0, 180))
    return aim(out, loc, normal)


def charging_port(P, main, part, x, y, z, length=0.16, h=0.07, travel=0.08):
    """Ejection port on the -x side (the player's right, since guns point along -y): a dark slot on `main` that runs
    `travel` further back, and a steel bolt face with an orange knob on `part`, so the code can slide `part` back
    along +y without showing a hole. Eject marker just outside the port, where casings fly out."""
    P.add(main, box((0.012, length + travel, h + 0.02), flat("#0c0c0e"), loc=(-x - 0.004, y + travel / 2, z), r=0.0, n=1))
    P.add(part, box((0.02, length * 0.85, h), plain(STEEL, grime=0.3), loc=(-x - 0.009, y, z), r=0.004, n=1))
    P.add(part, box((0.05, 0.035, 0.035), plain(ORANGE, grime=0.3), loc=(-x - 0.035, y + length * 0.3, z), r=0.01, n=1))
    P.add("Eject", marker((-x - 0.1, y, z + 0.02)))


def pistol(P, main, light=TEAL):
    """The starter blaster, built once for the floor pickup (main="Handle") and the first-person view (main="Body").
    Long chunky slide over a lower frame, hex shroud up front, ribbed grip leaning back, a glowing cell in each side,
    a rail and small sight on top, and a busy back plate since that's what the player stares at.
    The slide, its side panels, cell window bars and back plate are the `Slide` part so the code can kick it back;
    the cell's glow strips stay on `Glow`."""
    worn = paint(WHITE, chip=0.25, under="#8d8f92", under2="#5d6064", grime=0.6, streaks=0.3)
    g = plain(GREY, grime=0.5)
    dark = plain(DARK)
    axis = 0.62
    # slide: y from -0.5 to 0.42, z 0.5 to 0.75, with a narrower cap on top so the top edge reads chamfered
    P.add("Slide", box((0.24, 0.92, 0.25), worn, loc=(0, -0.04, axis), r=0.03, n=1))
    P.add("Slide", box((0.19, 0.86, 0.04), worn, loc=(0, -0.05, 0.755), r=0.015, n=1))
    # lower frame under the slide, running forward to a dark accessory nose
    P.add(main, box((0.21, 0.78, 0.13), g, loc=(0, -0.05, 0.445), r=0.02, n=1))
    P.add(main, box((0.19, 0.16, 0.1), dark, loc=(0, -0.38, 0.4), r=0.02, n=1))
    for k in range(3):
        P.add(main, box((0.195, 0.022, 0.06), plain(STEEL), loc=(0, -0.43 + k * 0.05, 0.38), r=0.004, n=1))
    # front: shroud and barrel tip
    P.add(main, shroud(-0.66, axis, 0.105, 0.17, ports=3))
    P.add(main, cyl(0.05, 0.06, plain(STEEL, grime=0.2), loc=(0, -0.69, axis), rot=(90, 0, 0), seg=6, bevel=0.006))
    P.add(main, cyl(0.03, 0.01, flat("#0c0c0e"), loc=(0, -0.721, axis), rot=(90, 0, 0), seg=6, bevel=0.0))
    P.add("Slide", box((0.27, 0.035, 0.27), plain(ORANGE, grime=0.35), loc=(0, -0.495, axis), r=0.01, n=1))
    # grip and mag
    P.add(main, box((0.17, 0.23, 0.44), plain(DARK, grime=0.25, vary=0.15), loc=(0, 0.22, 0.22), rot=(14, 0, 0), r=0.035, n=1))
    P.add(main, grip_texture(0.22, 0.22, 0.44))
    P.add(main, box((0.185, 0.245, 0.06), plain("#cdb98a", grime=0.55), loc=(0, 0.2, 0.33), rot=(14, 0, 0), r=0.008, n=1))
    P.add("Mag", box((0.12, 0.17, 0.44), plain(light, grime=0.3), loc=(0, 0.225, 0.24), rot=(14, 0, 0), r=0.015, n=1))
    P.add("Mag", box((0.21, 0.28, 0.055), plain(ORANGE, grime=0.4), loc=(0, 0.28, -0.005), rot=(14, 0, 0), r=0.012, n=1))
    P.add("Mag", box((0.08, 0.04, 0.03), dark, loc=(0, 0.42, 0.02), rot=(14, 0, 0), r=0.008, n=1))
    # trigger and guard
    P.add(main, [box((0.05, 0.28, 0.035), g, loc=(0, -0.08, 0.3), r=0.01, n=1),
                 box((0.05, 0.035, 0.14), g, loc=(0, -0.21, 0.36), r=0.01, n=1),
                 box((0.035, 0.04, 0.09), plain(ORANGE, grime=0.2), loc=(0, -0.05, 0.36), rot=(-15, 0, 0), r=0.008, n=1)])
    # sides: panel lines, vents, glowing cell, hazard stripes, screws
    P.add("Slide", panel(0.121, -0.46, 0.38, 0.515, 0.725))
    P.add("Slide", vents(0.122, -0.45, -0.3, 0.64, 0.07, n=3))
    body, lit_parts = cell_window(0.122, -0.24, 0.1, 0.65, 0.065, light, bars=3)
    P.add("Slide", body)
    P.add("Glow", lit_parts)
    for sx in (1, -1):
        P.add("Slide", stripes(0.2, 0.06, (sx * 0.123, 0.24, 0.56), (sx, 0, 0), n=3))
    P.add(main, [bolt(0.016, loc=(sx * 0.122, y, 0.475), normal=(sx, 0, 0)) for sx in (1, -1) for y in (-0.36, 0.0, 0.3)])
    # top: vents up front, rail, small sight near the back, front dot
    P.add("Slide", top_vents(-0.44, -0.24, 0.776, 0.12, n=4))
    P.add(main, rail(-0.2, 0.36, 0.775, w=0.09))
    P.add(main, reflex(0.24, 0.81, w=0.14, h=0.095))
    P.add("Slide", box((0.04, 0.04, 0.05), plain(ORANGE), loc=(0, -0.46, 0.8), r=0.01, n=1))
    # back plate: what the player looks at down the top of the gun
    P.add("Slide", box((0.2, 0.014, 0.2), g, loc=(0, 0.427, axis), r=0.005, n=1))
    P.add("Slide", stripes(0.18, 0.04, (0, 0.436, 0.7), (0, 1, 0), n=3))
    P.add("Slide", [bolt(0.014, loc=(sx * 0.075, 0.435, z), normal=(0, 1, 0)) for sx in (1, -1) for z in (0.55, 0.66)])
    P.add("Slide", cyl(0.04, 0.03, dark, loc=(0, 0.445, 0.6), rot=(90, 0, 0), seg=8, bevel=0.006))
    P.add("Glow", cyl(0.018, 0.012, glow(light, amount=0.0), loc=(0, 0.462, 0.6), rot=(90, 0, 0), seg=8, bevel=0.002))
    P.add("Muzzle", marker((0, -0.72, axis)))
    P.add("Rear", marker((0, 0.42, axis)))
    P.add("Eject", marker((-0.22, 0.0, 0.74)))  # off the slide's right side, above the cell window
