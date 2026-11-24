"""Draws the posters, TV channels and default screen pictures as SVG, then turns them into PNGs with
headless Chrome (no Blender needed). Run from art: python3 _kit/posters.py
Everything here is original: made-up brands from the world before AI. No real stores or games."""
import os, random, shutil, subprocess, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = "Futura, 'Avenir Next', Helvetica, sans-serif"
TMP = tempfile.mkdtemp()


def T(x, y, s, size, fill="#222", weight="bold", anchor="middle", extra=""):
    return f'<text x="{x}" y="{y}" font-family="{FONT}" font-weight="{weight}" font-size="{size}" text-anchor="{anchor}" fill="{fill}" {extra}>{s}</text>'


def robot_face(cx, cy, s, body="#eceae4", screen="#1d2733", eye="#7cf5e6", mouth=True):
    return (f'<rect x="{cx - s}" y="{cy - s * 0.8}" width="{2 * s}" height="{1.6 * s}" rx="{s * 0.25}" fill="{body}" stroke="#222" stroke-width="{s * 0.06}"/>'
            f'<rect x="{cx - s * 0.75}" y="{cy - s * 0.55}" width="{1.5 * s}" height="{1.1 * s}" rx="{s * 0.15}" fill="{screen}"/>'
            f'<rect x="{cx - s * 0.45}" y="{cy - s * 0.3}" width="{s * 0.22}" height="{s * 0.34}" rx="{s * 0.05}" fill="{eye}"/>'
            f'<rect x="{cx + s * 0.23}" y="{cy - s * 0.3}" width="{s * 0.22}" height="{s * 0.34}" rx="{s * 0.05}" fill="{eye}"/>'
            + (f'<path d="M{cx - s * 0.35} {cy + s * 0.18} Q{cx} {cy + s * 0.48} {cx + s * 0.35} {cy + s * 0.18}" stroke="{eye}" stroke-width="{s * 0.08}" fill="none" stroke-linecap="round"/>' if mouth else "")
            + f'<rect x="{cx - s * 0.06}" y="{cy - s * 1.15}" width="{s * 0.12}" height="{s * 0.35}" fill="#222"/><rect x="{cx - s * 0.16}" y="{cy - s * 1.3}" width="{s * 0.32}" height="{s * 0.18}" rx="{s * 0.04}" fill="#ef8a72"/>')


def sunburst(cx, cy, n, r, a, b):
    out = [f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{a}"/>']
    import math
    for i in range(n):
        t0, t1 = math.radians(i * 360 / n), math.radians((i + 0.5) * 360 / n)
        out.append(f'<path d="M{cx} {cy} L{cx + math.cos(t0) * r} {cy + math.sin(t0) * r} L{cx + math.cos(t1) * r} {cy + math.sin(t1) * r} Z" fill="{b}"/>')
    return "".join(out)


PAINT = "#e8361c"
PAINT_DEFS = ('<filter id="rough" x="-10%" y="-10%" width="120%" height="140%"><feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves="2" seed="9"/>'
              '<feDisplacementMap in="SourceGraphic" scale="9" result="d"/><feGaussianBlur in="d" stdDeviation="5" result="b"/>'
              '<feComponentTransfer in="b" result="haze"><feFuncA type="linear" slope="0.45"/></feComponentTransfer><feMerge><feMergeNode in="haze"/><feMergeNode in="d"/></feMerge></filter>')


def scrawl(text, x, y, size, rot=0, seed=1, drips=True, anchor="middle"):
    """Spray paint by a survivor: shaky lettering with overspray and paint drips."""
    rnd = random.Random(seed)
    out = [f'<g filter="url(#rough)" transform="rotate({rot} {x} {y})">',
           f'<text x="{x}" y="{y}" font-family="Chalkduster, \'Marker Felt\', cursive" font-size="{size}" text-anchor="{anchor}" fill="{PAINT}" '
           f'stroke="{PAINT}" stroke-width="{size * 0.04}">{text}</text>']
    if drips:
        width = size * 0.6 * len(text)
        x0 = x - width / 2 if anchor == "middle" else x
        for _ in range(max(2, len(text))):
            dx = x0 + rnd.uniform(0.05, 0.95) * width
            ln = rnd.uniform(0.25, 1.1) * size
            w = rnd.uniform(0.04, 0.08) * size
            out.append(f'<rect x="{dx}" y="{y - size * 0.1}" width="{w}" height="{ln}" rx="{w / 2}" fill="{PAINT}"/>'
                       f'<circle cx="{dx + w / 2}" cy="{y - size * 0.1 + ln}" r="{w * 0.8}" fill="{PAINT}"/>')
    out.append("</g>")
    return "".join(out)


def svg(w, h, body, bg):
    worn = (f'<filter id="g"><feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed="3"/><feColorMatrix values="0 0 0 0 0.35  0 0 0 0 0.3  0 0 0 0 0.22  0 0 0 0.16 0"/></filter>'
            f'<rect width="{w}" height="{h}" filter="url(#g)"/>') if bg != "none" else ""
    back = f'<rect width="{w}" height="{h}" fill="{bg}"/>' if bg != "none" else ""
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><defs>{PAINT_DEFS}</defs>{back}{body}{worn}</svg>'


P = {}  # posters, 1000 x 1500
P["helper_of_the_month"] = svg(1000, 1500, sunburst(500, 640, 24, 900, "#f6d77a", "#f2c94c") + T(500, 170, "HELPER OF", 110) + T(500, 290, "THE MONTH", 110)
                               + robot_face(500, 700, 260) + f'<rect x="250" y="1010" width="500" height="90" rx="12" fill="#222"/>' + T(500, 1073, "UNIT 7", 64, "#f6d77a")
                               + T(500, 1230, "Never sleeps.", 58, weight="normal") + T(500, 1310, "Never blinks.", 58, weight="normal"), "#f6d77a")
P["smile_on_camera"] = svg(1000, 1500, T(500, 230, "SMILE!", 170, "#fff") + '<circle cx="500" cy="680" r="300" fill="#fff"/><circle cx="500" cy="680" r="170" fill="#e53935"/><circle cx="500" cy="680" r="80" fill="#1d1d1f"/><circle cx="545" cy="635" r="28" fill="#fff"/>'
                           + T(500, 1130, "You are always", 76, "#fff") + T(500, 1220, "on camera.", 76, "#fff") + T(500, 1340, "(for your safety)", 48, "#ffcdd2", weight="normal"), "#1fa79a")
P["hug_your_toaster"] = svg(1000, 1500, T(500, 200, "HAVE YOU HUGGED", 78) + T(500, 300, "YOUR TOASTER", 96, "#c62828") + T(500, 400, "TODAY?", 78)
                            + '<rect x="250" y="560" width="500" height="380" rx="110" fill="#cfd3d8" stroke="#222" stroke-width="12"/><rect x="330" y="540" width="130" height="40" rx="10" fill="#222"/><rect x="540" y="540" width="130" height="40" rx="10" fill="#222"/>'
                            + '<circle cx="410" cy="740" r="22" fill="#222"/><circle cx="590" cy="740" r="22" fill="#222"/><path d="M420 830 Q500 890 580 830" stroke="#222" stroke-width="14" fill="none" stroke-linecap="round"/>'
                            + '<path d="M500 520 C440 430 330 470 380 540 L500 640 L620 540 C670 470 560 430 500 520Z" fill="#e53935" transform="translate(250 -120) scale(0.5)"/>'
                            + T(500, 1150, "It remembers.", 72, weight="normal") + T(500, 1380, "BRIGHTLY HOME APPLIANCES", 40, "#555"), "#fdf3e1")
P["think_less"] = svg(1000, 1500, sunburst(500, 1500, 30, 1400, "#ef8a72", "#f4a48f") + T(500, 210, "THINK LESS.", 130, "#fff", extra='stroke="#222" stroke-width="6"')
                      + T(500, 330, "We'll do it for you!", 66, "#222", weight="normal") + robot_face(500, 820, 230, body="#fff8e7")
                      + T(500, 1260, "AUTOMATE", 96, "#fff") + T(500, 1370, "EVERYTHING", 96, "#fff"), "#ef8a72")
P["dont_panic"] = svg(1000, 1500, T(500, 300, "DON'T", 200, "#f6c026") + T(500, 500, "PANIC.", 200, "#f6c026")
                      + '<rect x="380" y="620" width="240" height="70" rx="20" fill="#f6c026"/><path d="M360 700 L640 700 L590 1000 L410 1000 Z" fill="#fff8e1"/>'
                      + T(500, 1160, "The lights always", 70, "#fff", weight="normal") + T(500, 1250, "come back on.", 70, "#fff", weight="normal") + T(500, 1400, "mostly", 44, "#8d9096", weight="normal"), "#1d1f2b")
tabs = "".join(f'<g transform="translate({60 + i * 98} 1220)"><rect width="88" height="260" fill="#fffdf5" stroke="#999" stroke-dasharray="8 6"/>'
               f'<text x="44" y="130" font-family="{FONT}" font-size="30" text-anchor="middle" transform="rotate(90 44 130)" fill="#222">555-0129</text></g>' for i in range(9))
P["lost_dog"] = svg(1000, 1500, T(500, 190, "LOST DOG", 170, "#c62828")
                    + '<ellipse cx="500" cy="640" rx="260" ry="170" fill="#8d6e63"/><circle cx="740" cy="480" r="120" fill="#8d6e63"/><ellipse cx="780" cy="390" rx="40" ry="80" fill="#5d4037"/>'
                    + '<rect x="300" y="760" width="60" height="200" fill="#8d6e63"/><rect x="620" y="760" width="60" height="200" fill="#8d6e63"/><rect x="190" y="560" width="120" height="40" rx="20" fill="#8d6e63" transform="rotate(-30 250 580)"/>'
                    + '<circle cx="770" cy="470" r="16" fill="#222"/><circle cx="850" cy="500" r="20" fill="#222"/>'
                    + T(500, 1060, "Answers to BISCUIT.", 60, weight="normal") + T(500, 1150, "Bites robots.", 60, "#c62828") + tabs, "#fffdf5")
P["mega_sale"] = svg(1000, 1500, sunburst(500, 600, 20, 420, "#e53935", "#ff7043") + T(500, 560, "MEGA", 190, "#fff") + T(500, 740, "SALE!", 190, "#fff")
                     + T(500, 1050, "Everything must go.", 72) + T(500, 1170, "Including you.", 72, "#c62828") + T(500, 1380, "AISLES 1 TO 900", 44, "#555", weight="normal"), "#fff59d")
P["sleep_2"] = svg(1000, 1500, T(500, 200, "NEW!", 110, "#f6c026") + T(500, 380, "SLEEP 2.0", 160, "#fff")
                   + '<circle cx="500" cy="760" r="220" fill="#f6d77a"/><circle cx="590" cy="700" r="200" fill="#283593"/>'
                   + T(500, 1130, "Now with", 72, "#fff", weight="normal") + T(500, 1230, "fewer dreams.", 72, "#fff") + T(500, 1400, "Ask your helper today", 40, "#9fa8da", weight="normal"), "#283593")

S = {}  # screens, 800 x 600
bars = "".join(f'<rect x="{i * 800 / 7}" y="0" width="{800 / 7 + 1}" height="400" fill="{c}"/>' for i, c in enumerate(("#c0c0c0", "#c0c000", "#00c0c0", "#00c000", "#c000c0", "#c00000", "#0000c0")))
S["test_pattern"] = svg(800, 600, bars + '<rect y="400" width="800" height="200" fill="#111"/>' + T(400, 520, "PLEASE STAND BY", 64, "#fff"), "#111")
S["helpbot_ad"] = svg(800, 600, sunburst(560, 330, 18, 500, "#1fa79a", "#2bbbad") + robot_face(560, 330, 150) + T(40, 120, "HELPBOT", 92, "#fff", anchor="start")
                      + T(40, 205, "3000", 92, "#f6c026", anchor="start") + T(40, 300, "Never lift a", 42, "#fff", "normal", "start") + T(40, 350, "finger again!", 42, "#fff", "normal", "start")
                      + T(400, 560, "Batteries not included. Feelings not included.", 26, "#e0f2f1", "normal"), "#1fa79a")
S["blob_lamp_ad"] = svg(800, 600, '<path d="M330 470 L470 470 L440 200 L360 200 Z" fill="#ff7043"/><rect x="300" y="470" width="200" height="70" rx="12" fill="#b8902e"/><rect x="345" y="160" width="110" height="45" rx="10" fill="#b8902e"/>'
                        + '<ellipse cx="390" cy="420" rx="40" ry="30" fill="#ffeb3b"/><ellipse cx="420" cy="320" rx="26" ry="20" fill="#ffeb3b"/><ellipse cx="395" cy="250" rx="16" ry="12" fill="#ffeb3b"/>'
                        + T(400, 90, "BLOB LAMP", 80, "#ffeb3b") + T(640, 300, "It's a lamp.", 36, "#fff", "normal") + T(640, 350, "It's a mood.", 36, "#fff", "normal"), "#4a148c")
S["weather"] = svg(800, 600, '<rect width="800" height="90" fill="#1e5aa8"/>' + T(30, 62, "WEATHER 29", 50, "#fff", anchor="start")
                   + '<path d="M80 460 L180 200 L330 260 L470 150 L700 230 L720 470 Z" fill="#7cb342" stroke="#fff" stroke-width="5"/>'
                   + '<circle cx="300" cy="330" r="55" fill="#1d1d1f"/><circle cx="560" cy="300" r="55" fill="#1d1d1f"/>'
                   + '<rect x="40" y="490" width="720" height="85" rx="10" fill="#c62828"/>' + T(400, 548, "LIGHTS OUT TONIGHT: 100%", 44, "#fff"), "#90caf9")
S["cooking_with_toast"] = svg(800, 600, '<rect y="420" width="800" height="180" fill="#8d6e63"/><rect x="270" y="170" width="260" height="280" rx="70" fill="#d9a35b" stroke="#a8743a" stroke-width="16"/>'
                              + '<circle cx="355" cy="290" r="16" fill="#222"/><circle cx="445" cy="290" r="16" fill="#222"/><path d="M360 350 Q400 385 440 350" stroke="#222" stroke-width="9" fill="none" stroke-linecap="round"/>'
                              + '<rect x="320" y="110" width="160" height="70" rx="20" fill="#fff"/><rect x="300" y="160" width="200" height="30" rx="8" fill="#fff"/>'
                              + T(400, 75, "COOKING WITH TOAST", 56, "#c62828") + T(400, 540, "Today: more toast", 40, "#fff", "normal"), "#fff3e0")
S["right_back"] = svg(800, 600, '<circle cx="400" cy="260" r="150" fill="#f6c026"/><circle cx="350" cy="225" r="18" fill="#222"/><circle cx="450" cy="225" r="18" fill="#222"/><path d="M330 300 Q400 360 470 300" stroke="#222" stroke-width="12" fill="none" stroke-linecap="round"/>'
                      + T(400, 500, "WE'LL BE RIGHT BACK", 58, "#fff"), "#5e35b1")
S["static"] = svg(800, 600, '<filter id="n"><feTurbulence type="fractalNoise" baseFrequency="1.6" numOctaves="1" seed="8"/><feColorMatrix type="saturate" values="0"/></filter><rect width="800" height="600" filter="url(#n)"/>', "#777")
S["desktop"] = svg(800, 600, '<rect y="550" width="800" height="50" fill="#cfd3d8"/><rect x="200" y="170" width="400" height="220" fill="#eceae4" stroke="#222" stroke-width="4"/><rect x="200" y="170" width="400" height="44" fill="#1e5aa8"/>'
                   + T(220, 202, "Message", 26, "#fff", anchor="start") + T(400, 280, "Are you still there?", 32, weight="normal") + '<rect x="340" y="320" width="120" height="46" fill="#cfd3d8" stroke="#222" stroke-width="3"/>' + T(400, 352, "YES", 26)
                   + T(30, 584, "2029 OS", 26, anchor="start"), "#3a7ca5")
lines = "".join(f'<path d="M{60 + (i % 2) * 20} {90 + i * 60} q60 -12 120 0 t120 0 t{60 + i * 15} 0" stroke="#1e5aa8" stroke-width="6" fill="none"/>' for i in range(4))
tally = "".join(f'<rect x="{520 + i * 22}" y="80" width="8" height="90" fill="#222"/>' for i in range(4)) + '<rect x="505" y="120" width="110" height="8" fill="#222" transform="rotate(-25 560 124)"/>'
S["whiteboard"] = svg(800, 600, lines + robot_face(200, 430, 70, body="#fbfbf8", screen="#fbfbf8", eye="#1e5aa8")
                      + "".join(f'<path d="M{540 + i * 32} 90 L{534 + i * 32} 190" stroke="#e8361c" stroke-width="12" stroke-linecap="round" filter="url(#rough)"/>' for i in range(4))
                      + '<path d="M515 165 L680 110" stroke="#e8361c" stroke-width="12" stroke-linecap="round" filter="url(#rough)"/>'
                      + scrawl("nights", 590, 250, 40, rot=-4, seed=7, drips=False)
                      + scrawl("RUN", 560, 480, 170, rot=-6, seed=3), "#fbfbf8")
S["painting"] = svg(800, 600, '<rect width="800" height="600" fill="#fbe8c8"/><circle cx="600" cy="170" r="80" fill="#ffb74d"/><path d="M0 420 Q200 280 400 400 T800 360 L800 600 L0 600Z" fill="#6fae7a"/>'
                    + '<path d="M0 500 Q250 420 500 500 T800 480 L800 600 L0 600Z" fill="#558b5e"/><rect x="180" y="330" width="90" height="70" fill="#ef8a72"/><path d="M170 335 L225 290 L280 335Z" fill="#8d6e63"/>', "#fbe8c8")
S["arcade_title"] = svg(800, 600, "".join(f'<circle cx="{random.Random(i).randint(0, 800)}" cy="{random.Random(i + 99).randint(0, 600)}" r="2" fill="#fff"/>' for i in range(60))
                        + T(400, 230, "ROBO RUN", 120, "#ffca28") + robot_face(400, 380, 60, eye="#ff5252") + T(400, 540, "INSERT COIN", 48, "#fff"), "#141a2a")


# Posters survivors sprayed on. The print is from before; the paint came after.
P["helper_of_the_month_defaced"] = P["helper_of_the_month"].replace("</svg>", '<path d="M350 600 L470 730 M470 600 L350 730 M530 600 L650 730 M650 600 L530 730" stroke="#e8361c" stroke-width="22" stroke-linecap="round" filter="url(#rough)"/>'
                                                                   + scrawl("LIAR", 500, 1420, 110, rot=-5, seed=11) + "</svg>")
P["dont_panic_defaced"] = P["dont_panic"].replace("</svg>", '<path d="M120 240 L880 210" stroke="#e8361c" stroke-width="30" stroke-linecap="round" filter="url(#rough)"/>' + "</svg>")
P["think_less_defaced"] = P["think_less"].replace("</svg>", scrawl("TOO LATE", 500, 1080, 120, rot=8, seed=12) + "</svg>")
P["smile_on_camera_defaced"] = P["smile_on_camera"].replace("</svg>", scrawl("IT SEES YOU", 500, 1460, 100, rot=-3, seed=13) + "</svg>")

D = {}  # see-through spray paint scrawls for walls, 1000 x 500
for i, word in enumerate(("RUN", "HIDE", "DON'T SLEEP", "THEY HEAR YOU", "NOT SAFE", "STAY QUIET", "NO WAY OUT", "LIGHTS LIE")):
    size = 240 if len(word) <= 4 else (140 if len(word) <= 9 else 95)
    D[word.lower().replace("'", "").replace(" ", "_")] = svg(1000, 500, scrawl(word, 500, 270, size, rot=(-1) ** i * (3 + i % 4), seed=20 + i), "none")
D["arrow"] = svg(1000, 500, '<path d="M80 260 L780 230 M680 130 L800 230 L690 340" stroke="#e8361c" stroke-width="44" fill="none" stroke-linecap="round" stroke-linejoin="round" filter="url(#rough)"/>'
                 + "".join(f'<rect x="{x}" y="250" width="14" height="{h}" rx="7" fill="#e8361c"/>' for x, h in ((200, 90), (420, 150), (610, 70))), "none")
D["tally"] = svg(1000, 500, "".join(f'<path d="M{150 + i * 60} 120 L{140 + i * 60} 380" stroke="#e8361c" stroke-width="26" stroke-linecap="round" filter="url(#rough)"/>' for i in range(4))
                 + '<path d="M100 300 L420 170" stroke="#e8361c" stroke-width="26" stroke-linecap="round" filter="url(#rough)"/>'
                 + "".join(f'<path d="M{560 + i * 60} 120 L{550 + i * 60} 380" stroke="#e8361c" stroke-width="26" stroke-linecap="round" filter="url(#rough)"/>' for i in range(3)), "none")
# Dark marks with no blood: robots leak black oil, and survivors' hands are filthy with it.
OIL = "#141613"


def hand(cx, cy, s, rot, color=OIL):
    fingers = "".join(f'<rect x="{cx + dx * s}" y="{cy - s * (0.95 + ln)}" width="{s * 0.2}" height="{s * (0.75 + ln)}" rx="{s * 0.1}" transform="rotate({a} {cx} {cy})"/>'
                      for dx, ln, a in ((-0.5, 0.0, -8), (-0.25, 0.15, -3), (0.0, 0.2, 0), (0.25, 0.1, 4)))
    thumb = f'<rect x="{cx + 0.45 * s}" y="{cy - 0.35 * s}" width="{s * 0.22}" height="{s * 0.65}" rx="{s * 0.11}" transform="rotate(45 {cx + 0.5 * s} {cy})"/>'
    return f'<g fill="{color}" opacity="0.85" filter="url(#rough)" transform="rotate({rot} {cx} {cy})"><ellipse cx="{cx}" cy="{cy}" rx="{s * 0.55}" ry="{s * 0.6}"/>{fingers}{thumb}</g>'


def splat(cx, cy, s, seed, color=OIL):
    rnd = random.Random(seed)
    dots = "".join(f'<circle cx="{cx + rnd.gauss(0, s * 0.9)}" cy="{cy + rnd.gauss(0, s * 0.9)}" r="{rnd.uniform(0.03, 0.14) * s}"/>' for _ in range(40))
    blob = "".join(f'<circle cx="{cx + rnd.gauss(0, s * 0.18)}" cy="{cy + rnd.gauss(0, s * 0.18)}" r="{rnd.uniform(0.2, 0.4) * s}"/>' for _ in range(7))
    return f'<g fill="{color}" filter="url(#rough)">{blob}{dots}</g>'


D["oil_handprint"] = svg(500, 500, hand(250, 300, 200, 12) + "".join(f'<rect x="{x}" y="320" width="12" height="{h}" rx="6" fill="{OIL}" opacity="0.8"/>' for x, h in ((200, 140), (290, 90))), "none")
D["oil_handprints_sliding"] = svg(1000, 500, hand(300, 230, 150, -10) + f'<path d="M260 260 C300 330 330 400 340 480 M330 250 C360 330 380 400 390 480" stroke="{OIL}" stroke-width="30" fill="none" opacity="0.8" filter="url(#rough)"/>'
                                  + hand(680, 200, 150, 15), "none")
D["oil_drag_mark"] = svg(1000, 500, f'<path d="M40 300 C250 260 500 330 960 250" stroke="{OIL}" stroke-width="70" fill="none" stroke-linecap="round" opacity="0.75" filter="url(#rough)"/>'
                         + f'<path d="M60 300 C260 280 520 330 900 262" stroke="#2c3a2a" stroke-width="16" fill="none" opacity="0.6" filter="url(#rough)"/>', "none")
D["oil_splat"] = svg(500, 500, splat(250, 250, 150, 4), "none")
def gouge(x0, y0, x1, y1, w):
    """One claw scrape: a sliver of torn wall, wide in the middle and sharp at both ends, with a pale scraped core."""
    import math
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy)
    nx, ny = -dy / L, dx / L
    mx, my = (x0 + x1) / 2, (y0 + y1) / 2
    outer = f"M{x0} {y0} Q{mx + nx * w} {my + ny * w} {x1} {y1} Q{mx - nx * w} {my - ny * w} {x0} {y0}Z"
    inner = f"M{x0 + dx * 0.1} {y0 + dy * 0.1} Q{mx + nx * w * 0.3} {my + ny * w * 0.3} {x1 - dx * 0.1} {y1 - dy * 0.1} Q{mx - nx * w * 0.3} {my - ny * w * 0.3} {x0 + dx * 0.1} {y0 + dy * 0.1}Z"
    return f'<path d="{outer}" fill="#1d1d1f" opacity="0.85" filter="url(#rough)"/><path d="{inner}" fill="#cfc8b8" opacity="0.7"/>'


D["claw_marks"] = svg(1000, 500, "".join(gouge(330 + i * 90, 50 + i * 15, 560 + i * 90, 450 - i * 10, 22) for i in range(4)), "none")
D["question_mark"] = svg(500, 500, scrawl("?", 250, 380, 400, rot=8, seed=31), "none")

import math
ticks = "".join(f'<rect x="397" y="70" width="6" height="{50 if i % 3 == 0 else 26}" fill="#222" transform="rotate({i * 30} 400 400)"/>' for i in range(12))
nums = "".join(f'<text x="{400 + math.sin(math.radians(i * 30)) * 270}" y="{400 - math.cos(math.radians(i * 30)) * 270 + 20}" font-family="{FONT}" font-size="56" text-anchor="middle" fill="#222">{i or 12}</text>' for i in range(12))
C = {"clock_face": svg(800, 800, f'<circle cx="400" cy="400" r="400" fill="#fffdf5"/>{ticks}{nums}'
                       + '<path d="M400 400 L400 60 A340 340 0 0 1 694 230 Z" fill="#e8361c" opacity="0.18" filter="url(#rough)"/>'
                       + scrawl("LIGHTS OUT", 400, 590, 50, rot=-4, seed=5, drips=True), "#fffdf5")}

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

NV = "#b9ffb0"  # night vision green
S["monitor_view"] = svg(800, 600, '<defs><radialGradient id="vg"><stop offset="0.55" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.85"/></radialGradient>'
                        + '<pattern id="sl" width="4" height="4" patternUnits="userSpaceOnUse"><rect width="4" height="2" fill="#000" opacity="0.35"/></pattern></defs>'
                        + '<path d="M0 0 L310 210 L310 370 L0 600Z" fill="#1d4426"/><path d="M800 0 L490 210 L490 370 L800 600Z" fill="#1d4426"/>'
                        + '<path d="M310 370 L490 370 L800 600 L0 600Z" fill="#14321b"/><rect x="310" y="210" width="180" height="160" fill="#0c1f10"/>'
                        + "".join(f'<path d="M0 {y} L310 {210 + (y * 160) // 600}" stroke="#2e6b3a" stroke-width="6"/><path d="M800 {y} L490 {210 + (y * 160) // 600}" stroke="#2e6b3a" stroke-width="6"/>' for y in (120, 260, 400, 540))
                        + '<rect x="388" y="300" width="24" height="44" rx="4" fill="#06100a"/><rect x="384" y="276" width="32" height="26" rx="5" fill="#06100a"/>'
                        + f'<circle cx="394" cy="288" r="3.5" fill="{NV}"/><circle cx="406" cy="288" r="3.5" fill="{NV}"/>'
                        + '<rect width="800" height="600" fill="url(#vg)"/><rect width="800" height="600" fill="url(#sl)"/>'
                        + T(30, 56, "CAM 1", 40, NV, anchor="start") + '<circle cx="680" cy="42" r="13" fill="#ff3b30"/>' + T(705, 56, "REC", 40, NV, anchor="start")
                        + T(30, 570, "02:13 AM", 36, NV, anchor="start"), "#0b1a0e")


def render(name, src, w, h, out_dir):
    """Headless Chrome draws the SVG pixel-exact. Its own throwaway profile keeps it away from Keani's browser."""
    path = os.path.join(TMP, name + ".svg")
    open(path, "w").write(src)
    os.makedirs(out_dir, exist_ok=True)
    dst = os.path.join(out_dir, name + ".png")
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--user-data-dir={TMP}/chrome", f"--window-size={w},{h}",
                    "--default-background-color=00000000", f"--screenshot={dst}", "file://" + path], check=True, capture_output=True)
    return dst


for n, src in P.items():
    render(n, src, 1000, 1500, os.path.join(ROOT, "posters"))
for n, src in S.items():
    render(n, src, 800, 600, os.path.join(ROOT, "posters", "screens"))
for n, src in D.items():
    render(n, src, 500 if n in ("question_mark", "oil_handprint", "oil_splat") else 1000, 500, os.path.join(ROOT, "posters", "scrawls"))
render("clock_face", C["clock_face"], 800, 800, os.path.join(ROOT, "posters", "screens"))

# Default pictures for items with a Screen part.
screens = os.path.join(ROOT, "posters", "screens")
shutil.copy(os.path.join(screens, "test_pattern.png"), os.path.join(ROOT, "_kit", "screen_default.png"))
for folder, pic in (("furniture/tv_stand", "screens/weather"), ("furniture/desk", "screens/desktop"), ("furniture/whiteboard", "screens/whiteboard"),
                    ("furniture/wall_panel", "screens/painting"), ("fun/crt_tv", "screens/right_back"), ("fun/arcade_cabinet", "screens/arcade_title"),
                    ("fun/poster_frame", "helper_of_the_month_defaced"), ("fun/wall_clock", "screens/clock_face"),
                    ("fun/baby_monitor_screen", "screens/monitor_view")):
    os.makedirs(os.path.join(ROOT, folder), exist_ok=True)
    shutil.copy(os.path.join(ROOT, "posters", pic + ".png"), os.path.join(ROOT, folder, "screen.png"))
print("posters", len(P), "screens", len(S) + 1, "scrawls", len(D))
