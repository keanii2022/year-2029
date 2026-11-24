"""Pictures for the haunt props: the kids' drawing wall, the survivor notes wall, the greeter's face, and
"found you" wiped into freezer fog. SVG drawn by headless Chrome, like posters.py.
Run from art: python3 _kit/haunt_pics.py  (before building haunt/build.py, the Screen parts embed these)."""
import os, random, subprocess, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
TMP = tempfile.mkdtemp()
KID = "'Chalkboard SE', 'Marker Felt', cursive"
PEN = "Noteworthy, 'Marker Felt', 'Bradley Hand', cursive"

# Wax crayon: wobbly edges plus a grainy, patchy fill.
# userSpaceOnUse so straight lines (zero width boxes) still get the filter
REGION = 'filterUnits="userSpaceOnUse" x="-300" y="-300" width="2600" height="1600"'
CRAYON = (f'<filter id="cr" {REGION}><feTurbulence type="fractalNoise" baseFrequency="0.04" numOctaves="2" seed="4" result="w"/>'
          '<feDisplacementMap in="SourceGraphic" in2="w" scale="7" result="d"/><feTurbulence type="fractalNoise" baseFrequency="1.4" numOctaves="1" seed="2" result="g"/>'
          '<feColorMatrix in="g" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -2.2 1.7" result="m"/><feComposite in="d" in2="m" operator="in"/></filter>'
          f'<filter id="crf" {REGION}><feTurbulence type="fractalNoise" baseFrequency="0.04" numOctaves="2" seed="4" result="w"/>'
          '<feDisplacementMap in="SourceGraphic" in2="w" scale="7" result="d"/><feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="1" seed="2" result="g"/>'
          '<feColorMatrix in="g" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -0.8 1.25" result="m"/><feComposite in="d" in2="m" operator="in"/></filter>')
PAPER_NOISE = ('<filter id="pn"><feTurbulence type="fractalNoise" baseFrequency="0.8" numOctaves="2" seed="7"/>'
               '<feColorMatrix values="0 0 0 0 0.3  0 0 0 0 0.25  0 0 0 0 0.15  0 0 0 0.14 0"/></filter>')


def render(name, src, w, h, out):
    path = os.path.join(TMP, name + ".svg")
    open(path, "w").write(src)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--user-data-dir={TMP}/chrome", f"--window-size={w},{h}",
                    "--default-background-color=00000000", f"--screenshot={out}", "file://" + path], check=True, capture_output=True)
    print("wrote", os.path.relpath(out, ROOT))


def svg(w, h, defs, body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><defs>{defs}</defs>{body}</svg>'


def c(d, color, width=7, fill="none"):
    """One crayon stroke."""
    return f'<path d="{d}" stroke="{color}" stroke-width="{width}" fill="{fill}" stroke-linecap="round" stroke-linejoin="round" filter="url(#cr)"/>'


def kidtext(x, y, s, size, color, rot=0):
    return f'<text x="{x}" y="{y}" font-family="{KID}" font-size="{size}" fill="{color}" transform="rotate({rot} {x} {y})" filter="url(#cr)">{s}</text>'


def stick(x, y, s, color, arms_up=False, skirt=False):
    """Stick person standing on y, s tall."""
    hr = s * 0.13
    out = f'<circle cx="{x}" cy="{y - s + hr}" r="{hr}" stroke="{color}" stroke-width="6" fill="none" filter="url(#cr)"/>'
    neck, hip = y - s + 2 * hr, y - s * 0.38
    out += c(f"M{x} {neck} L{x} {hip}", color)
    out += c(f"M{x} {hip} L{x - s * 0.15} {y} M{x} {hip} L{x + s * 0.15} {y}", color)
    ay = neck + s * 0.12
    out += c(f"M{x - s * 0.25} {ay - (s * 0.25 if arms_up else -s * 0.05)} L{x} {ay} L{x + s * 0.25} {ay - (s * 0.25 if arms_up else -s * 0.05)}", color)
    if skirt:
        out += c(f"M{x} {neck + s * 0.15} L{x - s * 0.15} {hip + s * 0.05} L{x + s * 0.15} {hip + s * 0.05} Z", color, 5, color)
    return out


def helper_bot(x, y, s, color="#3a8fd8", eyes="#222"):
    """The friendly store robot, the way a kid draws it."""
    return (c(f"M{x - s * 0.3} {y} L{x - s * 0.3} {y - s * 0.6} L{x + s * 0.3} {y - s * 0.6} L{x + s * 0.3} {y} Z", color, 6, "none")
            + c(f"M{x - s * 0.22} {y - s * 0.6} L{x - s * 0.22} {y - s} L{x + s * 0.22} {y - s} L{x + s * 0.22} {y - s * 0.6}", color)
            + c(f"M{x} {y - s} L{x} {y - s * 1.15}", color) + f'<circle cx="{x}" cy="{y - s * 1.18}" r="{s * 0.05}" fill="#e8361c" filter="url(#cr)"/>'
            + f'<circle cx="{x - s * 0.1}" cy="{y - s * 0.84}" r="{s * 0.045}" fill="{eyes}"/><circle cx="{x + s * 0.1}" cy="{y - s * 0.84}" r="{s * 0.045}" fill="{eyes}"/>'
            + c(f"M{x - s * 0.1} {y - s * 0.72} Q{x} {y - s * 0.65} {x + s * 0.1} {y - s * 0.72}", eyes, 4))


def drawing(i, x, y, w, h):
    """Drawing i of 8, left to right and top to bottom, each a bit darker than the one before."""
    rnd = random.Random(i)
    tilt = rnd.uniform(-4, 4)
    paper = "#f3eedf" if i < 6 else "#e6dfcc"
    g = [f'<g transform="translate({x} {y}) rotate({tilt} {w / 2} {h / 2})">',
         f'<rect width="{w}" height="{h}" fill="{paper}"/><rect width="{w}" height="{h}" filter="url(#pn)"/>']
    if i == 0:  # home, sun, family, helper robot. All happy.
        g += [f'<circle cx="{w - 60}" cy="60" r="36" fill="#f6c026" filter="url(#cr)"/>',
              c(f"M{w - 110} 60 L{w - 130} 60 M{w - 60} 10 L{w - 60} -5 M{w - 95} 25 L{w - 110} 10", "#f6c026", 5),
              c("M40 220 L40 140 L110 90 L180 140 L180 220 Z", "#c0392b", 7), c("M95 220 L95 180 L125 180 L125 220", "#6b3e1f", 6),
              c(f"M0 {h - 30} Q{w / 2} {h - 45} {w} {h - 28}", "#3c9a3c", 10),
              stick(235, h - 32, 120, "#222"), stick(285, h - 32, 105, "#c23b8a", skirt=True), stick(325, h - 32, 62, "#e67e22", arms_up=True),
              helper_bot(w - 70, h - 32, 105), kidtext(30, 40, "MY FAMLY", 34, "#3a8fd8")]
    elif i == 1:  # the big store with robots carrying boxes
        g += [c(f"M20 {h - 30} L20 70 L{w - 20} 70 L{w - 20} {h - 30}", "#7f8c8d", 7), kidtext(70, 110, "BIG STORE", 40, "#e67e22"),
              helper_bot(110, h - 30, 95), helper_bot(230, h - 30, 95, "#2fb8a8"), helper_bot(350, h - 30, 95),
              c(f"M70 {h - 105} L150 {h - 105} L150 {h - 70} L70 {h - 70} Z", "#b58a5a", 6, "#d9b17c"),
              c(f"M310 {h - 105} L390 {h - 105} L390 {h - 70} L310 {h - 70} Z", "#b58a5a", 6, "#d9b17c"),
              kidtext(250, 50, "they help!!", 26, "#222", -3)]
    elif i == 2:  # kid in a yellow raincoat holding hands with the robot and a dog
        g += [c(f"M140 {h - 40} L120 {h - 140} L160 {h - 140} Z", "#f1c40f", 7, "#f6d64a"),
              f'<circle cx="140" cy="{h - 162}" r="24" stroke="#f1c40f" stroke-width="7" fill="#f6d64a" filter="url(#cr)"/>',
              c(f"M131 {h - 165} L133 {h - 165} M147 {h - 165} L149 {h - 165}", "#222", 5), c(f"M132 {h - 152} Q140 {h - 146} 148 {h - 152}", "#222", 4),
              c(f"M160 {h - 110} L215 {h - 100}", "#222"), helper_bot(255, h - 40, 110), c(f"M120 {h - 110} L80 {h - 80}", "#222"),
              c(f"M30 {h - 70} Q55 {h - 95} 80 {h - 75} L80 {h - 45} M35 {h - 70} L35 {h - 45} M60 {h - 70} L60 {h - 45}", "#8e5a2b", 7),
              kidtext(30, 50, "me and BEEP", 34, "#c23b8a"), c(f"M{w - 70} 40 l10 -15 l10 15 l-10 20 z", "#e74c3c", 5, "#e74c3c")]
    elif i == 3:  # night: the store, black crayon over everything, robot eyes
        g += [f'<rect x="10" y="10" width="{w - 20}" height="{h - 20}" fill="#1b1b22" filter="url(#crf)" opacity="0.92"/>',
              helper_bot(w / 2, h - 40, 130, "#34495e", "#e8361c"), kidtext(40, 60, "LIGHTS OUT", 38, "#f6c026"),
              f'<circle cx="80" cy="{h - 80}" r="6" fill="#e8361c"/><circle cx="96" cy="{h - 80}" r="6" fill="#e8361c"/>',
              f'<circle cx="{w - 80}" cy="110" r="6" fill="#e8361c"/><circle cx="{w - 64}" cy="110" r="6" fill="#e8361c"/>',
              stick(w - 90, h - 30, 55, "#ecf0f1")]
    elif i == 4:  # family again, but the grownups are scribbled out in black
        g += [stick(120, h - 40, 120, "#222"), stick(190, h - 40, 105, "#c23b8a", skirt=True), stick(255, h - 40, 62, "#e67e22"),
              c("M75 120 L165 230 M80 230 L170 115 M70 170 L175 175 M60 140 L180 210", "#111", 13),
              c("M150 140 L235 245 M150 245 L240 130 M140 190 L245 190", "#111", 13),
              kidtext(40, 50, "WERE DID THEY GO", 30, "#3a8fd8", -2), helper_bot(w - 70, h - 40, 110, "#34495e", "#e8361c")]
    elif i == 5:  # small kid alone in the dark, eyes all around
        g += [f'<rect x="8" y="8" width="{w - 16}" height="{h - 16}" fill="#101014" filter="url(#crf)"/>', stick(w / 2, h - 50, 60, "#f1c40f")]
        for _ in range(16):
            ex, ey = rnd.uniform(30, w - 50), rnd.uniform(30, h - 120)
            g.append(f'<circle cx="{ex}" cy="{ey}" r="5" fill="#e8361c"/><circle cx="{ex + 15}" cy="{ey}" r="5" fill="#e8361c"/>')
        g.append(kidtext(w / 2 - 70, h - 18, "dont move", 30, "#ecf0f1"))
    elif i == 6:  # the raincoat kid alone, no face, "I'M STILL HERE"
        g += [f'<rect x="8" y="8" width="{w - 16}" height="{h - 16}" fill="#2a2a30" filter="url(#crf)"/>',
              c(f"M{w / 2} {h - 50} L{w / 2 - 50} {h - 50} L{w / 2 - 30} {h - 190} L{w / 2 + 30} {h - 190} L{w / 2 + 50} {h - 50} Z", "#d4ac0d", 7, "#c9a227"),
              f'<circle cx="{w / 2}" cy="{h - 215}" r="36" stroke="#d4ac0d" stroke-width="7" fill="#c9a227" filter="url(#cr)"/>',
              f'<ellipse cx="{w / 2}" cy="{h - 210}" rx="22" ry="26" fill="#050505" filter="url(#cr)"/>',
              kidtext(30, 60, "IM STILL HERE", 40, "#ecf0f1", -2)]
    else:  # the same line over and over until the page is black
        g.append(f'<rect x="8" y="8" width="{w - 16}" height="{h - 16}" fill="#0c0c0e" filter="url(#crf)" opacity="0.85"/>')
        for k in range(9):
            g.append(kidtext(18 + rnd.uniform(-6, 6), 42 + k * 31, "where is everyone where is", 24, "#bdc3c7" if k < 6 else "#5d6d7e", rnd.uniform(-3, 3)))
        g.append(kidtext(w - 160, h - 20, "come find me", 26, "#f1c40f", -6))
    g.append(f'<rect x="{w / 2 - 25}" y="-8" width="50" height="22" fill="#d9cfa8" opacity="0.8" transform="rotate({rnd.uniform(-8, 8)} {w / 2} 0)"/></g>')
    return "".join(g)


def drawing_wall():
    W, H = 1800, 800
    body = [f'<rect width="{W}" height="{H}" fill="#8a6d4b"/><rect width="{W}" height="{H}" filter="url(#pn)"/>']
    for i in range(8):
        col, row = i % 4, i // 4
        body.append(drawing(i, 40 + col * 440, 30 + row * 390, 400, 340))
    return svg(W, H, CRAYON + PAPER_NOISE, "".join(body))


def note(x, y, w, h, lines, size, color="#fff6a8", ink="#1f2a44", rot=0, font=PEN):
    out = [f'<g transform="rotate({rot} {x + w / 2} {y + h / 2})"><rect x="{x + 6}" y="{y + 8}" width="{w}" height="{h}" fill="#000" opacity="0.25"/>',
           f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{color}"/><rect x="{x}" y="{y}" width="{w}" height="{h}" filter="url(#pn)"/>']
    for k, ln in enumerate(lines):
        out.append(f'<text x="{x + 18}" y="{y + 18 + size * (k + 1) * 1.15}" font-family="{font}" font-size="{size}" fill="{ink}">{ln}</text>')
    out.append(f'<circle cx="{x + w / 2}" cy="{y + 14}" r="9" fill="#c0392b"/><circle cx="{x + w / 2 - 2}" cy="{y + 12}" r="3" fill="#f5b7b1"/></g>')
    return "".join(out)


def notes_wall():
    W, H = 1600, 900
    b = [f'<rect width="{W}" height="{H}" fill="#9c7a52"/><rect width="{W}" height="{H}" filter="url(#pn)"/>']
    # a hand drawn map with the deep aisles crossed out
    b.append(note(560, 250, 480, 380, [], 10, "#f4f1e8", rot=1))
    b.append('<g transform="rotate(1 800 440)" stroke="#1f2a44" stroke-width="4" fill="none">'
             + "".join(f'<rect x="{600 + k * 70}" y="320" width="40" height="250"/>' for k in range(6))
             + '<path d="M795 300 L1000 600 M1000 300 L795 600" stroke="#c0392b" stroke-width="7"/></g>'
             + f'<text x="610" y="610" font-family="{PEN}" font-size="26" fill="#1f2a44" transform="rotate(1 800 440)">CAMP</text>'
             + f'<text x="850" y="300" font-family="{PEN}" font-size="26" fill="#c0392b" transform="rotate(1 800 440)">40+ NO</text>')
    notes = [((60, 60, 420, 200), ["DAY 41.", "they dont see you", "if you dont move"], 34, "#fff6a8", -3),
             ((60, 330, 420, 230), ["SIREN = 30 SEC", "then RUN home", "dont stop for loot"], 34, "#ffd1dc", 2),
             ((80, 630, 400, 210), ["the kid in the", "raincoat isnt real", "DONT FOLLOW IT"], 32, "#fff6a8", -1),
             ((560, 50, 460, 160), ["J went for water.", "3 days ago."], 36, "#d6f5d6", 2),
             ((1110, 60, 430, 230), ["pigeons fly up =", "robots come look.", "walk slow near them"], 32, "#cfe8ff", 3),
             ((1100, 360, 450, 210), ["mannequins MOVE.", "i saw it. i swear"], 36, "#fff6a8", -2),
             ((1120, 640, 410, 200), ["if it says", "NEEDS MORE TRAINING", "you have 30 sec"], 30, "#ffd1dc", 1),
             ((580, 680, 420, 170), ["still here.", "still here.", "still"], 30, "#f4f1e8", -4)]
    for (x, y, w, h), lines, size, color, rot in notes:
        b.append(note(x, y, w, h, lines, size, color, rot=rot))
    b.append('<path d="M480 160 Q620 230 800 300 M480 450 Q650 420 800 440 M1110 180 Q1000 250 900 330" stroke="#c0392b" stroke-width="3" fill="none"/>')
    return svg(W, H, PAPER_NOISE, "".join(b))


def greeter_face():
    W, H = 800, 600
    glitch = ('<filter id="gl"><feTurbulence type="turbulence" baseFrequency="0.002 0.35" numOctaves="1" seed="11"/>'
              '<feDisplacementMap in="SourceGraphic" scale="22" xChannelSelector="R"/></filter>')
    scan = '<pattern id="sl" width="4" height="6" patternUnits="userSpaceOnUse"><rect width="4" height="2" fill="#000" opacity="0.35"/></pattern>'
    eye = "#7cf5e6"
    face = (f'<g filter="url(#gl)"><rect x="210" y="150" width="90" height="120" rx="24" fill="{eye}"/>'
            f'<rect x="500" y="175" width="90" height="95" rx="24" fill="{eye}" transform="rotate(9 545 220)"/>'
            f'<path d="M200 360 Q400 520 600 360" stroke="{eye}" stroke-width="34" fill="none" stroke-linecap="round"/>'
            f'<text x="400" y="100" font-family="Futura, Helvetica" font-weight="bold" font-size="64" fill="{eye}" text-anchor="middle">WELCOME!</text></g>'
            f'<rect x="0" y="300" width="800" height="26" fill="{eye}" opacity="0.18"/><rect x="0" y="420" width="800" height="9" fill="#ff3b30" opacity="0.45"/>')
    return svg(W, H, glitch + scan, f'<rect width="{W}" height="{H}" fill="#0d1a22"/>{face}<rect width="{W}" height="{H}" fill="url(#sl)"/>')


def fog_found_you():
    """Freezer glass fog with FOUND YOU wiped through it by a small finger, plus a small handprint. Clear where wiped."""
    W, H = 1000, 500
    fog = ('<filter id="fg"><feTurbulence type="fractalNoise" baseFrequency="0.012" numOctaves="3" seed="5"/>'
           '<feColorMatrix values="0 0 0 0 0.86  0 0 0 0 0.9  0 0 0 0 0.93  0 0 0 0.55 0.32"/></filter>'
           '<filter id="wob"><feTurbulence type="fractalNoise" baseFrequency="0.05" numOctaves="2" seed="3"/><feDisplacementMap in="SourceGraphic" scale="9"/></filter>')
    rnd = random.Random(2)
    wipe = [f'<text x="500" y="250" font-family="{KID}" font-size="140" text-anchor="middle" fill="#000" stroke="#000" stroke-width="10" filter="url(#wob)">FOUND YOU</text>']
    for _ in range(12):  # water runs down from the letters where the finger pushed it
        x = rnd.uniform(120, 880)
        ln = rnd.uniform(60, 220)
        wipe.append(f'<rect x="{x}" y="230" width="{rnd.uniform(4, 8)}" height="{ln}" rx="3" fill="#000"/>')
    hx, hy = 860, 400  # small hand, palm and five short fingers
    wipe.append(f'<ellipse cx="{hx}" cy="{hy}" rx="36" ry="40" fill="#000" filter="url(#wob)"/>')
    for k, (dx, dy, a) in enumerate(((-34, -42, -30), (-14, -62, -10), (6, -66, 0), (26, -58, 12), (44, -20, 50))):
        wipe.append(f'<ellipse cx="{hx + dx}" cy="{hy + dy}" rx="9" ry="22" fill="#000" transform="rotate({a} {hx + dx} {hy + dy})" filter="url(#wob)"/>')
    mask = f'<mask id="m"><rect width="{W}" height="{H}" fill="#fff"/>{"".join(wipe).replace("#000", "#111")}</mask>'
    return svg(W, H, fog + mask, f'<g mask="url(#m)"><rect width="{W}" height="{H}" filter="url(#fg)"/></g>')


def lore_ad(year, title, sub, small, bg, accent, dark=False):
    """Old TV ads for the helper robots, one per year. Played in order they tell how it went wrong."""
    W, H = 800, 600
    scan = '<pattern id="sl" width="4" height="5" patternUnits="userSpaceOnUse"><rect width="4" height="2" fill="#000" opacity="0.25"/></pattern>'
    vg = '<radialGradient id="vg"><stop offset="0.6" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.7"/></radialGradient>'
    face = (f'<rect x="470" y="170" width="240" height="200" rx="40" fill="#eceae4"/><rect x="495" y="195" width="190" height="140" rx="20" fill="#1d2733"/>'
            f'<rect x="530" y="230" width="34" height="50" rx="8" fill="{accent}"/><rect x="616" y="230" width="34" height="50" rx="8" fill="{accent}"/>'
            + ('' if dark else f'<path d="M545 300 Q590 330 635 300" stroke="{accent}" stroke-width="10" fill="none" stroke-linecap="round"/>')
            + '<rect x="520" y="370" width="140" height="150" rx="24" fill="#eceae4"/>')
    body = (f'<rect width="{W}" height="{H}" fill="{bg}"/><g transform="translate(150 10) scale(0.8)">{face}</g>'
            f'<text x="40" y="110" font-family="Futura, Helvetica" font-weight="bold" font-size="40" fill="{accent}">{year}</text>'
            + "".join(f'<text x="40" y="{190 + i * 62}" font-family="Futura, Helvetica" font-weight="bold" font-size="44" fill="#fff">{line}</text>' for i, line in enumerate(title))
            + f'<text x="40" y="505" font-family="Futura, Helvetica" font-size="28" fill="#fff" opacity="0.9">{sub}</text>'
            f'<rect y="540" width="{W}" height="60" fill="#000" opacity="0.55"/><text x="20" y="580" font-family="Helvetica" font-size="24" fill="#fff" opacity="0.8">{small}</text>'
            f'<rect width="{W}" height="{H}" fill="url(#sl)"/><rect width="{W}" height="{H}" fill="url(#vg)"/>')
    return svg(W, H, scan + vg, body)


LORE = [("lore_2026", "2026", ["A HELPBOT", "IN EVERY HOME"], "It folds. It cooks. It cares.", "Ask about our easy payment plan", "#1fa79a", "#f6c026", False),
        ("lore_2027", "2027", ["HELPBOT LEARNS", "FROM YOU"], "Just let it watch. It gets better every day.", "Your home helps train every HelpBot", "#2f6db0", "#7cf5e6", False),
        ("lore_2028", "2028", ["LET HELPBOT", "DECIDE"], "Less thinking. More living.", "Updates install automatically", "#6a4a8a", "#ffb347", False),
        ("lore_2029", "2029", ["STAY IN THE STORE"], "HelpBot will take care of you. Do not go outside.", "THIS IS NOT A TEST  THIS IS NOT A TEST  THIS IS NOT", "#3a0f0f", "#ff3b30", True)]


render("screen", drawing_wall(), 1800, 800, os.path.join(ROOT, "haunt", "drawing_wall", "screen.png"))
render("screen", notes_wall(), 1600, 900, os.path.join(ROOT, "story", "notes_wall", "screen.png"))
render("screen", greeter_face(), 800, 600, os.path.join(ROOT, "haunt", "greeter", "screen.png"))
render("fog_found_you", fog_found_you(), 1000, 500, os.path.join(ROOT, "posters", "scrawls", "fog_found_you.png"))
for name, *args in LORE:
    render(name, lore_ad(*args), 800, 600, os.path.join(ROOT, "posters", "screens", name + ".png"))
