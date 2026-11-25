"""Builds the Year 2029 sound pack from scratch by synthesis. Nothing is sampled.

Run from anywhere:
    nice python3 art/_kit/sounds.py            (whole pack)
    nice python3 art/_kit/sounds.py psst ding  (only names containing these words)

Writes sounds/<group>/<name>.mp3 (44.1 kHz mono, 128k) and sounds/index.html.
Names ending in _loop loop seamlessly. One-shots start on the first sample.
Loudness tiers set the peak: loud -1 dBFS, normal -6, quiet -12.
"""

import html
import math
import random
import subprocess
import sys
import tempfile
import wave
from array import array
from pathlib import Path

SR = 44100
TAU = 2 * math.pi
OUT = Path(__file__).resolve().parent.parent / "sounds"
PEAK_DB = {"loud": -1.0, "normal": -6.0, "quiet": -12.0}
GROUPS = {
    "kitchen": "Kitchen",
    "living": "Living room and bedroom",
    "office": "Office, bathroom, kids room",
    "fun": "Fun props",
    "food": "Food",
    "gear": "Guns and gear",
    "robots": "Robots",
    "players": "Players",
    "warehouse": "The warehouse",
}
SKIPPED = [
    "TV channel audio, boombox music, arcade chiptune, record player song, music box and toy chest tunes, "
    "jack in the box crank tune: real music, out of scope for synthesis.",
    "Every voice: announcer, robot lines, PRESS ME lines, phone message, walkie and radio voices, "
    "jack in the box laugh. See VOICE_LINES.md.",
    "Baby monitor and walkie live audio: the game plays what the mic or cam hears.",
]
SOUNDS = []


def sound(group, name, tier, note):
    def register(fn):
        SOUNDS.append((group, name, tier, note, fn))
        return fn

    return register


# ---------- basic signals ----------


def n_of(sec):
    return max(1, int(round(sec * SR)))


def at_index(sec):
    return int(round(sec * SR))


def as_list(v, n):
    if isinstance(v, list):
        return v + [v[-1]] * (n - len(v)) if len(v) < n else v
    return [float(v)] * n


def silence(sec):
    return [0.0] * n_of(sec)


def noise(sec):
    return [random.uniform(-1, 1) for _ in range(n_of(sec))]


def brown(sec):
    out, v = [], 0.0
    for _ in range(n_of(sec)):
        v = v * 0.996 + random.uniform(-1, 1) * 0.08
        out.append(v)
    return out


WAVES = {
    "sine": lambda p: math.sin(TAU * p),
    "square": lambda p: 1.0 if p % 1 < 0.5 else -1.0,
    "saw": lambda p: 2 * (p % 1) - 1,
    "tri": lambda p: 4 * abs(p % 1 - 0.5) - 1,
}


def osc(freq, sec=None, shape="sine", phase=0.0):
    n = len(freq) if sec is None else n_of(sec)
    f = as_list(freq, n)
    fn = WAVES[shape]
    out, p = [0.0] * n, phase
    for i in range(n):
        out[i] = fn(p)
        p += f[i] / SR
    return out


def snap(freq, loop_sec):
    """Round a frequency so it fits a whole number of cycles in the loop."""
    return max(1, round(freq * loop_sec)) / loop_sec


# ---------- envelopes and curves ----------


def ramp(points, sec):
    """Piecewise linear curve through (time, value) points."""
    n = n_of(sec)
    out, j = [0.0] * n, 0
    for i in range(n):
        t = i / SR
        while j < len(points) - 2 and t > points[j + 1][0]:
            j += 1
        (t0, v0), (t1, v1) = points[j], points[j + 1]
        if t <= t0:
            out[i] = v0
        elif t >= t1:
            out[i] = v1
        else:
            out[i] = v0 + (v1 - v0) * (t - t0) / (t1 - t0)
    return out


def expo(a, b, sec):
    n = n_of(sec)
    r = (b / a) ** (1 / max(1, n - 1))
    return [a * r**i for i in range(n)]


def decay(sec, tau, attack=0.0005):
    na = n_of(attack)
    return [i / na if i < na else math.exp(-(i - na) / SR / tau) for i in range(n_of(sec))]


def adsr(sec, attack, release, level=1.0):
    return ramp([(0, 0), (attack, level), (max(attack, sec - release), level), (sec, 0)], sec)


def wobble(sec, rate, lo=0.0, hi=1.0, smooth=0.3):
    """Random slow curve between lo and hi, for flutter and rough motion."""
    n = n_of(sec)
    step = max(1, int(SR / rate))
    pts = [random.uniform(lo, hi) for _ in range(n // step + 2)]
    out = []
    for i in range(n):
        k, frac = divmod(i, step)
        frac /= step
        frac = frac * frac * (3 - 2 * frac) if smooth else frac
        out.append(pts[k] + (pts[k + 1] - pts[k]) * frac)
    return out


# ---------- mixing ----------


def amp(x, e):
    if isinstance(e, list):
        return [a * b for a, b in zip(x, e)]
    return [a * e for a in x]


def layer(*parts):
    """Mix clips. Each part is a clip, or (clip, start_sec) or (clip, start_sec, gain)."""
    items = [(p, 0.0, 1.0) if isinstance(p, list) else (p[0], p[1], p[2] if len(p) > 2 else 1.0) for p in parts]
    out = [0.0] * max(at_index(at) + len(x) for x, at, _ in items)
    for x, at, g in items:
        s = at_index(at)
        for i, v in enumerate(x):
            out[s + i] += v * g
    return out


def wrap_layer(loop_sec, *parts):
    """Like layer, but clips that run past the end wrap to the start, so the loop stays seamless."""
    n = n_of(loop_sec)
    out = [0.0] * n
    for p in parts:
        x, at, g = (p, 0.0, 1.0) if isinstance(p, list) else (p[0], p[1], p[2] if len(p) > 2 else 1.0)
        s = at_index(at)
        for i, v in enumerate(x):
            out[(s + i) % n] += v * g
    return out


def circ(fn, x):
    """Run a filter as if the clip were already looping, so the seam has no click."""
    return fn(x + x)[len(x) :]


def cat(*xs):
    out = []
    for x in xs:
        out += x
    return out


def peak(x):
    return max((abs(v) for v in x), default=0.0)


def norm(x, level=1.0):
    p = peak(x) or 1.0
    return [v * level / p for v in x]


def fade(x, fin=0.0, fout=0.005):
    x = list(x)
    a, b = n_of(fin) if fin else 0, min(len(x), n_of(fout))
    for i in range(a):
        x[i] *= i / a
    for i in range(b):
        x[-1 - i] *= i / b
    return x


def speed(x, factor):
    """Resample: factor 0.8 plays slower and lower."""
    n = int(len(x) / factor)
    out = []
    for i in range(n):
        pos = i * factor
        k = int(pos)
        if k + 1 >= len(x):
            break
        out.append(x[k] + (x[k + 1] - x[k]) * (pos - k))
    return out


def warble(x, depth_sec, rate):
    """Tape style pitch wobble with a moving delay."""
    out = []
    for i in range(len(x)):
        pos = i - depth_sec * SR * (1 + math.sin(TAU * rate * i / SR))
        k = int(pos)
        out.append(x[k] + (x[k + 1] - x[k]) * (pos - k) if 0 <= k < len(x) - 1 else 0.0)
    return out


# ---------- effects ----------


def svf(x, cutoff, q=0.707, mode="low"):
    """Zero delay state variable filter. Cutoff can be a number or a per sample list."""
    n, k = len(x), 1 / q
    out, ic1, ic2 = [0.0] * n, 0.0, 0.0
    sweep = isinstance(cutoff, list)
    if sweep:
        cutoff = as_list(cutoff, n)
    else:
        g = math.tan(math.pi * min(cutoff, SR * 0.45) / SR)
        a1 = 1 / (1 + g * (g + k))
        a2, a3 = g * a1, g * g * a1
    for i in range(n):
        if sweep:
            g = math.tan(math.pi * min(max(cutoff[i], 20.0), SR * 0.45) / SR)
            a1 = 1 / (1 + g * (g + k))
            a2, a3 = g * a1, g * g * a1
        v0 = x[i]
        v3 = v0 - ic2
        v1 = a1 * ic1 + a2 * v3
        v2 = ic2 + a2 * ic1 + a3 * v3
        ic1, ic2 = 2 * v1 - ic1, 2 * v2 - ic2
        out[i] = v2 if mode == "low" else k * v1 if mode == "band" else v0 - k * v1 - v2
    return out


def lp(x, f, q=0.707):
    return svf(x, f, q, "low")


def hp(x, f, q=0.707):
    return svf(x, f, q, "high")


def bp(x, f, q=1.0):
    return svf(x, f, q, "band")


def dcblock(x):
    out, px, py = [], 0.0, 0.0
    for v in x:
        py = v - px + 0.9995 * py
        px = v
        out.append(py)
    return out


def drive(x, d):
    return [math.tanh(v * d) for v in x]


def crush(x, bits=6, hold=1):
    q = 2 ** (bits - 1)
    out, held = [], 0.0
    for i, v in enumerate(x):
        if i % hold == 0:
            held = round(v * q) / q
        out.append(held)
    return out


def echo(x, delay, feedback, taps=4):
    d = at_index(delay)
    return layer(x, *[(x, delay * k, feedback**k) for k in range(1, taps + 1)]) if d else x


def reverb(x, size=1.0, wet=0.3, tail=1.2, damp=0.4, fb=0.82):
    """Small Schroeder reverb: four combs into two allpasses."""
    x = x + [0.0] * n_of(tail)
    out = [0.0] * len(x)
    for d in (1557, 1617, 1491, 1422):
        d = int(d * size)
        buf, j, low = [0.0] * d, 0, 0.0
        for i, v in enumerate(x):
            y = buf[j]
            low = y * (1 - damp) + low * damp
            buf[j] = v + low * fb
            j = (j + 1) % d
            out[i] += y
    for d in (225, 556):
        d = int(d * size)
        buf, j = [0.0] * d, 0
        for i, v in enumerate(out):
            b = buf[j]
            out[i] = b - v
            buf[j] = v + b * 0.5
            j = (j + 1) % d
    return [a * (1 - wet) + b * wet * 0.25 for a, b in zip(x, out)]


# ---------- building blocks ----------


def modes(sec, parts):
    """Struck object: decaying sines given as (freq, amp, decay_sec)."""
    n = n_of(sec)
    out = [0.0] * n
    for f, a, tau in parts:
        if f >= SR / 2:
            continue
        w, d, e = TAU * f / SR, math.exp(-1 / (tau * SR)), a
        ph = random.uniform(0, TAU)
        for i in range(n):
            out[i] += e * math.sin(w * i + ph)
            e *= d
            if e < 1e-5:
                break
    return fade(out, 0.0005, 0.005)


def strike(sec=0.006, f=4000):
    return lp(amp(noise(sec), decay(sec, sec / 4)), f)


def click(f=3000, sec=0.015, q=1.5):
    return bp(amp(noise(sec), decay(sec, sec / 6, 0.0002)), f, q)


def knock(f=170, sec=0.2, bright=2500):
    body = modes(sec, [(f, 1, sec / 4), (f * 2.3, 0.5, sec / 7), (f * 4.1, 0.25, sec / 12)])
    return layer(body, (strike(0.008, bright), 0, 0.7))


def clang(f, sec=1.2, bright=1.0, ratios=(1, 2.41, 3.87, 5.43, 6.9, 8.6, 11.3)):
    parts = [(f * r, (0.8**k) * (bright if k else 1), sec / (1 + 0.7 * k)) for k, r in enumerate(ratios)]
    return layer(modes(sec, parts), (strike(0.005, 6000), 0, 0.5 * bright))


def clink(f, sec=0.35):
    return modes(sec, [(f, 1, sec / 3), (f * 2.32, 0.6, sec / 5), (f * 4.25, 0.35, sec / 8), (f * 6.63, 0.2, sec / 12)])


def thud(f=70, sec=0.3, drop=0.5, grit=0.4):
    body = amp(osc(expo(f, f * drop, sec), sec), decay(sec, sec / 4, 0.002))
    dirt = lp(amp(noise(0.05), decay(0.05, 0.012)), 900)
    return layer(body, (dirt, 0, grit))


def whoosh(sec, f1, f2, q=1.2, a=0.1, r=0.3):
    return amp(bp(noise(sec), expo(f1, f2, sec), q), adsr(sec, a, r))


def hiss(sec, lo=2500, a=0.02, r=0.2, flutter=0.15):
    e = amp(adsr(sec, a, r), wobble(sec, 25, 1 - flutter, 1))
    return amp(hp(noise(sec), lo), e)


def beep(f, sec, shape="square", tone=3500):
    return lp(amp(osc(f, sec, shape), adsr(sec, 0.003, 0.012)), tone)


def creak(sec, rate, bands, q=12, jitter=0.25):
    """Stick and slip: a pulse train whose rate wanders, rung through resonances."""
    n = n_of(sec)
    r = as_list(rate, n)
    x, i = [0.0] * n, 0
    while i < n:
        x[i] = random.uniform(0.5, 1.0)
        i += max(1, int(SR / max(1.0, r[i]) * random.uniform(1 - jitter, 1 + jitter)))
    return layer(*[bp(x, f, q) for f in bands])


def servo(sec, freq, grit=0.35, tone=1400, q=0.8):
    n = n_of(sec)
    f = as_list(freq, n)
    body = layer(osc(f, sec, "saw"), (osc([v * 2.01 for v in f], sec, "square"), 0, 0.35))
    teeth = osc([v / 7 for v in f], sec, "square")
    body = [b * (1 - grit + grit * (t * 0.5 + 0.5)) for b, t in zip(body, teeth)]
    return layer(bp(body, tone, q), (hp(noise(sec), 3000), 0, 0.04))


def crinkle(sec, density, lo=1800, hi=9000, env=None):
    out = [0.0] * n_of(sec)
    for _ in range(int(density * sec)):
        c = click(random.uniform(lo, hi), random.uniform(0.003, 0.012), random.uniform(1.5, 4))
        s = random.randrange(len(out))
        g = random.uniform(0.2, 1.0) * (env[s] if env else 1.0)
        for i, v in enumerate(c):
            if s + i < len(out):
                out[s + i] += v * g
    return out


def ratchet(sec, rate, f=2800, f2=900):
    parts, t = [], 0.0
    while t < sec:
        parts.append((layer(click(f, 0.01, 2), (knock(f2, 0.03), 0, 0.3)), t, random.uniform(0.7, 1)))
        t += 1 / rate * random.uniform(0.9, 1.1)
    return layer(*parts)


def squeak(sec, freq, vib=9, depth=0.03, tone=2200):
    n = n_of(sec)
    f = as_list(freq, n)
    f = [v * (1 + depth * math.sin(TAU * vib * i / SR) + random.uniform(-0.01, 0.01)) for i, v in enumerate(f)]
    body = layer(osc(f, sec, "saw"), (osc(f, sec), 0, 1.0))
    return amp(bp(body, tone, 1.2), adsr(sec, 0.02, 0.05))


def bubble(f0, sec=0.07, rise=1.8):
    return amp(osc(expo(f0, f0 * rise, sec), sec), decay(sec, sec / 3, 0.002))


def static(sec, bits=5, lo=400, hi=6000):
    s = crush(noise(sec), bits)
    s = bp(s, math.sqrt(lo * hi), 0.6)
    return amp(s, wobble(sec, 40, 0.3, 1.0, smooth=False))


def scatter(sec, clip_fn, count, jitter=1.0):
    """Drop clips at random times through a clip of the given length."""
    return layer(silence(sec), *[(clip_fn(), random.uniform(0, sec) * jitter, random.uniform(0.4, 1)) for _ in range(count)])


def tremble(sec, lo, hi, depth):
    """Amplitude shake whose speed wanders between lo and hi Hz, for shaky breath and dying batteries."""
    out, p = [], 0.0
    for r in wobble(sec, 3, lo, hi):
        p += r / SR
        out.append(1 - depth * (0.5 + 0.5 * math.sin(TAU * p)))
    return out


def follow(x, f=25):
    """Smooth loudness curve of a clip, so a layer can rise and fall with it."""
    return lp([abs(v) for v in x], f)


def tone_seq(notes, shape="tri"):
    """notes: (start_hz, end_hz, length_sec, gap_sec)."""
    parts, t = [], 0.0
    for f1, f2, d, gap in notes:
        parts.append((amp(osc(expo(f1, f2, d), d, shape), adsr(d, 0.004, min(0.03, d / 3))), t))
        t += d + gap
    return lp(layer(*parts), 5000)


# ---------- kitchen ----------


@sound("kitchen", "cabinet_creak", "normal", "wood cupboard door creaks open")
def cabinet_creak():
    sec = 0.8
    c = creak(sec, ramp([(0, 35), (0.3, 90), (0.8, 55)], sec), [620, 1150, 1900])
    return amp(c, adsr(sec, 0.05, 0.15))


@sound("kitchen", "cabinet_shut", "normal", "soft wood knock as the door shuts")
def cabinet_shut():
    return layer(knock(150, 0.22), (click(2200, 0.01), 0, 0.3))


@sound("kitchen", "fridge_open", "normal", "door seal pops open")
def fridge_open():
    suck = amp(lp(noise(0.12), 700), decay(0.12, 0.025))
    pop = thud(110, 0.12, 0.6, 0)
    return layer(suck, (pop, 0.004, 0.8), (knock(260, 0.1), 0.01, 0.2))


@sound("kitchen", "fridge_hum_loop", "normal", "low hum while the door is open")
def fridge_hum_loop():
    sec = 3.0
    hum = layer(osc(snap(59, sec), sec), (osc(snap(118, sec), sec), 0, 0.5), (osc(snap(177, sec), sec, "saw"), 0, 0.12))
    air = circ(lambda x: lp(x, 350), noise(sec))
    return layer(hum, (air, 0, 0.3))


@sound("kitchen", "fridge_jars", "normal", "jars rattle in the door")
def fridge_jars():
    return scatter(0.5, lambda: clink(random.uniform(1800, 3200), 0.25), 7, 0.8)


@sound("kitchen", "stove_ignite", "normal", "gas click click whoosh")
def stove_ignite():
    snap_ = lambda: layer(click(4500, 0.008, 1), (click(1800, 0.01, 2), 0, 0.5))
    flame = amp(lp(noise(1.0), expo(300, 1800, 1.0), 1.4), adsr(1.0, 0.12, 0.6))
    return layer(snap_(), (snap_(), 0.22), (flame, 0.42, 1.2))


@sound("kitchen", "stove_burner_loop", "normal", "soft gas burner roar")
def stove_burner_loop():
    sec = 3.0
    roar = circ(lambda x: lp(x, 600), noise(sec))
    flutter = circ(lambda x: bp(x, 1400, 0.8), noise(sec))
    return layer(roar, (flutter, 0, 0.25))


@sound("kitchen", "oven_door", "normal", "heavy oven door creaks down")
def oven_door():
    sec = 1.1
    c = amp(creak(sec, ramp([(0, 25), (0.6, 45), (1.1, 30)], sec), [280, 540, 980], 9), adsr(sec, 0.05, 0.1))
    stop = layer(clang(180, 0.7, 0.5), (thud(70, 0.25), 0, 0.8))
    return layer(amp(c, 4), (stop, 1.0, 1.2))


@sound("kitchen", "microwave_door", "normal", "microwave door clunk")
def microwave_door():
    return layer(click(2600, 0.01), (knock(220, 0.16, 1500), 0.012), (thud(90, 0.12, 0.7), 0.012, 0.5))


@sound("kitchen", "microwave_hum_loop", "normal", "microwave running hum")
def microwave_hum_loop():
    sec = 2.0
    buzz = circ(lambda x: lp(x, 900), osc(snap(120, sec), sec, "square"))
    fan = circ(lambda x: bp(x, 800, 0.7), noise(sec))
    return layer(buzz, (fan, 0, 0.6))


@sound("kitchen", "microwave_plate_squeak", "normal", "turning plate squeaks")
def microwave_plate_squeak():
    return squeak(0.35, ramp([(0, 1450), (0.35, 1650)], 0.35), vib=14, tone=1800)


@sound("kitchen", "microwave_ding", "loud", "the DING")
def microwave_ding():
    f = 2093
    return layer(modes(1.6, [(f, 1, 0.5), (f * 2.76, 0.35, 0.2), (f * 5.4, 0.12, 0.08), (f * 0.5, 0.1, 0.4)]), (strike(0.004, 8000), 0, 0.3))


@sound("kitchen", "toaster_lever", "normal", "toaster lever clacks down")
def toaster_lever():
    spring = amp(osc(ramp([(0, 340), (0.2, 300)], 0.2)), decay(0.2, 0.05))
    return layer(click(2000, 0.02, 1), (knock(400, 0.08), 0.06), (spring, 0.06, 0.3), (click(5000, 0.006), 0.07, 0.4))


@sound("kitchen", "toaster_tick_loop", "normal", "toaster timer ticking")
def toaster_tick_loop():
    sec = 1.0
    return wrap_layer(sec, *[(layer(click(3500, 0.008, 3), (knock(900, 0.02), 0, 0.3)), k / 6) for k in range(6)])


@sound("kitchen", "toaster_pop", "normal", "toast POP")
def toaster_pop():
    boing = amp(osc([300 * (1 + 0.15 * math.sin(TAU * 18 * i / SR)) for i in range(n_of(0.3))], 0.3), decay(0.3, 0.07))
    return layer(thud(140, 0.1, 0.6, 0.6), (clang(900, 0.25, 0.6), 0, 0.5), (boing, 0.005, 0.5))


# ---------- living room and bedroom ----------


@sound("living", "tv_channel_thunk", "loud", "old TV channel knob thunk")
def tv_channel_thunk():
    return layer(click(1800, 0.012), (knock(120, 0.15, 1200), 0.004), (click(4000, 0.006), 0.03, 0.4))


@sound("living", "tv_static_burst", "loud", "static burst between channels")
def tv_static_burst():
    sec = 1.0
    s = amp(hp(crush(noise(sec), 6), 300), amp(wobble(sec, 30, 0.5, 1.0), adsr(sec, 0.005, 0.15)))
    whine = amp(osc(15700, sec), adsr(sec, 0.005, 0.15, 0.03))
    return layer(s, whine)


@sound("living", "lamp_chain_click", "quiet", "pull chain click")
def lamp_chain_click():
    return layer(click(3200, 0.012, 2), (clink(5200, 0.06), 0, 0.2), (click(2600, 0.01, 2), 0.09, 0.6))


@sound("living", "bulb_buzz_loop", "quiet", "faint bulb buzz")
def bulb_buzz_loop():
    sec = 2.0
    buzz = circ(lambda x: bp(x, 1200, 0.5), osc(snap(120, sec), sec, "saw"))
    return layer(buzz, (circ(lambda x: hp(x, 3000), noise(sec)), 0, 0.05))


@sound("living", "cushion_squish", "quiet", "couch cushion squish")
def cushion_squish():
    sec = 0.45
    air = amp(lp(noise(sec), expo(1400, 300, sec)), adsr(sec, 0.05, 0.3))
    return layer(air, (thud(80, 0.2, 0.7, 0), 0.02, 0.6))


@sound("living", "spring_creak", "quiet", "couch or bed springs creak")
def spring_creak():
    sec = 0.5
    c = amp(creak(sec, ramp([(0, 120), (0.25, 200), (0.5, 90)], sec), [2100, 3300], 18), adsr(sec, 0.03, 0.15))
    twang = amp(osc([420 * (1 + 0.05 * math.sin(TAU * 7 * i / SR)) for i in range(n_of(sec))], sec), decay(sec, 0.12))
    return layer(c, (twang, 0.05, 0.2))


@sound("living", "wardrobe_creak", "normal", "big wardrobe door creak")
def wardrobe_creak():
    sec = 1.5
    c = creak(sec, ramp([(0, 18), (0.5, 50), (1.0, 30), (1.5, 22)], sec), [340, 780, 1450], 10)
    return amp(c, adsr(sec, 0.08, 0.3))


@sound("living", "hangers_clink", "normal", "hangers clinking")
def hangers_clink():
    return scatter(0.6, lambda: clink(random.uniform(2800, 5500), 0.2), 9, 0.85)


@sound("living", "drawer_wood", "normal", "wood drawer slides and bumps")
def drawer_wood():
    sec = 0.45
    slide = amp(bp(noise(sec), 700, 0.9), amp(adsr(sec, 0.04, 0.05), wobble(sec, 60, 0.3, 1.0, smooth=False)))
    return layer(slide, (knock(160, 0.2), sec - 0.02, 1.4))


@sound("living", "drawer_metal", "normal", "metal drawer rolls and clanks")
def drawer_metal():
    sec = 0.5
    roll = amp(bp(noise(sec), 1500, 1.2), adsr(sec, 0.03, 0.05))
    bearings = amp(ratchet(sec, 70, 4200, 1500), 0.3)
    return layer(roll, bearings, (clang(320, 0.6, 0.7), sec - 0.02, 1.2))


@sound("living", "alarm_clock_beep", "loud", "nightstand clock beep beep beep")
def alarm_clock_beep():
    b = beep(2000, 0.08, "square", 6000)
    group = layer(*[(b, k * 0.15) for k in range(4)])
    return layer(group, (group, 0.85))


@sound("living", "sheets_rustle", "quiet", "bed sheets rustle")
def sheets_rustle():
    sec = 1.0
    return amp(bp(noise(sec), 2800, 0.5), amp(wobble(sec, 9, 0.0, 1.0), adsr(sec, 0.08, 0.2)))


# ---------- office, bathroom, kids room ----------


@sound("office", "computer_chime", "normal", "old computer start up chime")
def computer_chime():
    notes = [293.66, 440.0, 554.37, 739.99]
    parts = []
    for k, f in enumerate(notes):
        tone = layer(osc(f, 2.2), (osc(f * 1.003, 2.2), 0, 0.6), (osc(f * 2, 2.2), 0, 0.15))
        parts.append((amp(tone, amp(adsr(2.2, 0.03, 1.4), decay(2.2, 1.2, 0.001))), k * 0.06))
    return reverb(layer(*parts), 1.0, 0.25, 0.8)


@sound("office", "computer_fan_loop", "normal", "computer fan whir")
def computer_fan_loop():
    sec = 3.0
    air = circ(lambda x: bp(x, 650, 0.6), noise(sec))
    blade = layer(osc(snap(180, sec), sec), (osc(snap(360, sec), sec), 0, 0.4))
    return layer(air, (blade, 0, 0.15))


@sound("office", "chair_roll", "normal", "office chair wheels roll")
def chair_roll():
    sec = 1.0
    rumble = amp(lp(noise(sec), 350), adsr(sec, 0.1, 0.3))
    casters = amp(ratchet(sec, 35, 1800, 500), adsr(sec, 0.1, 0.3, 0.25))
    return layer(rumble, casters)


@sound("office", "chair_squeak", "normal", "squeaky chair spin")
def chair_squeak():
    return squeak(0.5, ramp([(0, 900), (0.3, 1150), (0.5, 1000)], 0.5), vib=11, tone=1300)


@sound("office", "marker_squeak", "quiet", "marker squeaks on the whiteboard")
def marker_squeak():
    a = squeak(0.25, ramp([(0, 2300), (0.25, 2700)], 0.25), vib=30, depth=0.04, tone=2600)
    b = squeak(0.18, ramp([(0, 2600), (0.18, 2200)], 0.18), vib=30, depth=0.04, tone=2600)
    return layer(a, (b, 0.32))


@sound("office", "tap_squeak", "normal", "tap handle squeaks")
def tap_squeak():
    sec = 0.4
    return amp(creak(sec, ramp([(0, 250), (0.4, 380)], sec), [1300, 2600], 20, 0.1), adsr(sec, 0.02, 0.08))


@sound("office", "water_running_loop", "normal", "tap water running")
def water_running_loop():
    sec = 3.0
    bed = circ(lambda x: bp(x, 1100, 0.5), noise(sec))
    drops = [(bubble(random.uniform(700, 2400), random.uniform(0.02, 0.06)), random.uniform(0, sec), random.uniform(0.1, 0.4)) for _ in range(260)]
    return layer(amp(bed, 0.35), wrap_layer(sec, *drops))


@sound("office", "pipe_knock", "normal", "pipes knock in the wall")
def pipe_knock():
    k = lambda: lp(layer(modes(0.5, [(140, 1, 0.15), (330, 0.6, 0.08), (610, 0.3, 0.05)]), (strike(0.006, 2000), 0, 0.5)), 1500)
    return reverb(layer(k(), (k(), 0.18, 0.7), (k(), 0.31, 0.5)), 1.2, 0.3, 0.6)


@sound("office", "shower_slide", "normal", "glass shower door slides")
def shower_slide():
    sec = 0.6
    slide = amp(bp(noise(sec), 2400, 1.0), amp(adsr(sec, 0.05, 0.05), wobble(sec, 40, 0.5, 1.0)))
    stop = layer(modes(0.4, [(950, 1, 0.08), (1830, 0.6, 0.05), (3100, 0.3, 0.03)]), (thud(120, 0.1), 0, 0.6))
    return layer(slide, (stop, sec - 0.02, 1.3))


@sound("office", "shower_rattle", "normal", "glass door rattles")
def shower_rattle():
    return scatter(0.45, lambda: modes(0.12, [(1100, 1, 0.03), (2300, 0.5, 0.02)]), 12, 0.9)


@sound("office", "toilet_lid", "normal", "toilet lid clack")
def toilet_lid():
    return layer(knock(320, 0.12, 4000), (click(1500, 0.015), 0, 0.5))


@sound("office", "toilet_flush", "loud", "FLUSH")
def toilet_flush():
    sec = 3.2
    rush = amp(bp(noise(sec), ramp([(0, 400), (0.4, 2200), (1.6, 1200), (3.2, 500)], sec), 0.7), adsr(sec, 0.15, 1.6))
    swirl = amp(lp(noise(sec), 300), amp(adsr(sec, 0.3, 1.0), [0.6 + 0.4 * math.sin(TAU * 3 * i / SR) for i in range(n_of(sec))]))
    gurgle = layer(silence(sec), *[(bubble(random.uniform(250, 900), 0.08, 1.5), random.uniform(1.4, 3.0), random.uniform(0.2, 0.6)) for _ in range(40)])
    return layer(rush, (swirl, 0, 0.8), (gurgle, 0, 0.5), (click(1200, 0.02), 0, 0.5))


@sound("office", "toy_chest_creak", "quiet", "toy chest lid creak")
def toy_chest_creak():
    sec = 0.6
    return amp(creak(sec, ramp([(0, 50), (0.3, 110), (0.6, 70)], sec), [800, 1500, 2400]), adsr(sec, 0.04, 0.1))


# ---------- fun props ----------


@sound("fun", "lava_switch", "quiet", "lava lamp switch click")
def lava_switch():
    return layer(click(2500, 0.012, 2), (knock(600, 0.04), 0, 0.3))


@sound("fun", "lava_bubble_loop", "quiet", "soft slow bubbling")
def lava_bubble_loop():
    sec = 4.0
    blobs = [(bubble(random.uniform(140, 320), 0.18, 1.6), k * 0.5 + random.uniform(0, 0.3), random.uniform(0.4, 1)) for k in range(8)]
    return circ(lambda x: lp(x, 900), wrap_layer(sec, *blobs))


@sound("fun", "press_button_click", "normal", "big chunky button click")
def press_button_click():
    return layer(knock(150, 0.18, 1800), (click(2200, 0.015, 1.2), 0, 0.6), (thud(90, 0.12, 0.6), 0, 0.5), (click(1600, 0.012), 0.12, 0.35))


@sound("fun", "boombox_button", "normal", "tape deck key clunk")
def boombox_button():
    return layer(click(1900, 0.015), (knock(210, 0.12, 2000), 0.008), (clink(3100, 0.08), 0.01, 0.15))


@sound("fun", "boombox_tape_door", "normal", "tape door springs open")
def boombox_tape_door():
    sec = 0.3
    spring = amp(creak(sec, 160, [1800, 2900], 16), decay(sec, 0.08))
    return layer(click(2400, 0.01), (spring, 0.01, 0.6), (knock(480, 0.06, 4000), 0.25, 0.8))


@sound("fun", "arcade_coin", "normal", "coin drops into the slot")
def arcade_coin():
    c = lambda: clink(random.uniform(4200, 4600), 0.15)
    roll = amp(ratchet(0.35, 40, 3800, 1200), adsr(0.35, 0.02, 0.1, 0.3))
    return layer(c(), (c(), 0.09, 0.6), (c(), 0.15, 0.4), (roll, 0.2), (knock(300, 0.1), 0.58, 0.7))


@sound("fun", "arcade_joystick", "normal", "joystick micro switch clicks")
def arcade_joystick():
    m = lambda: layer(click(3800, 0.008, 3), (click(1500, 0.01), 0, 0.3))
    return layer(m(), (m(), 0.11, 0.8))


@sound("fun", "fan_click", "quiet", "fan knob click")
def fan_click():
    return layer(click(2000, 0.012, 2), (knock(500, 0.05), 0, 0.4))


@sound("fun", "fan_whir_loop", "quiet", "table fan whirring")
def fan_whir_loop():
    sec = 2.0
    blades = [0.7 + 0.3 * math.sin(TAU * snap(24, sec) * i / SR) for i in range(n_of(sec))]
    air = amp(circ(lambda x: bp(x, 450, 0.6), noise(sec)), blades)
    motor = osc(snap(120, sec), sec)
    return layer(air, (motor, 0, 0.08))


def clock_ticks(sec, beats):
    tick = layer(click(4200, 0.01, 4), (knock(1100, 0.03), 0, 0.4))
    tock = layer(click(3000, 0.01, 4), (knock(800, 0.035), 0, 0.5))
    return wrap_layer(sec, *[(tick if k % 2 == 0 else tock, k * sec / beats) for k in range(beats)])


@sound("fun", "clock_tick_loop", "quiet", "wall clock tick tock")
def clock_tick_loop():
    return clock_ticks(2.0, 2)


@sound("fun", "clock_tick_fast_loop", "quiet", "fast tick tock for the last minute")
def clock_tick_fast_loop():
    return clock_ticks(1.0, 4)


@sound("fun", "phone_ring", "loud", "RING RING")
def phone_ring():
    def ring(sec):
        hits = [(modes(0.12, [(1150, 1, 0.08), (1380, 0.8, 0.08), (2900, 0.3, 0.03)]), k * 0.05, 1 if k % 2 else 0.8) for k in range(int(sec / 0.05))]
        return layer(*hits)

    return layer(ring(0.9), (ring(0.9), 1.3))


@sound("fun", "phone_handset", "normal", "handset clatter")
def phone_handset():
    return layer(knock(260, 0.12, 3000), (knock(340, 0.1, 3000), 0.07, 0.7), (clink(2300, 0.3), 0.01, 0.12), (knock(300, 0.08), 0.15, 0.4))


@sound("fun", "phone_dial", "normal", "rotary dial whirrs back")
def phone_dial():
    sec = 0.9
    whirr = amp(bp(noise(sec), 900, 2), adsr(sec, 0.02, 0.05, 0.4))
    return layer(ratchet(sec, 11, 2600, 700), (whirr, 0, 0.5))


@sound("fun", "disco_motor_loop", "quiet", "disco ball motor hum")
def disco_motor_loop():
    sec = 2.0
    motor = circ(lambda x: lp(x, 600), osc(snap(90, sec), sec, "square"))
    grind = [0.8 + 0.2 * math.sin(TAU * snap(6, sec) * i / SR) for i in range(n_of(sec))]
    return amp(motor, grind)


@sound("fun", "vending_beep", "normal", "vending button beep")
def vending_beep():
    return beep(1560, 0.12, "square", 5000)


@sound("fun", "vending_whirr", "normal", "spiral motor turns")
def vending_whirr():
    sec = 1.4
    return amp(servo(sec, ramp([(0, 100), (0.2, 130), (1.4, 125)], sec), 0.5, 700, 0.6), adsr(sec, 0.08, 0.15))


@sound("fun", "vending_thud", "normal", "snack drops in the tray")
def vending_thud():
    return layer(thud(110, 0.2, 0.6), (clang(260, 0.4, 0.4), 0, 0.4), (crinkle(0.15, 60), 0.01, 0.3))


@sound("fun", "jack_crank", "normal", "crank clicks")
def jack_crank():
    return ratchet(1.6, 7, 2300, 600)


@sound("fun", "jack_boing", "loud", "BOING")
def jack_boing():
    sec = 0.9
    f = [190 * (1 + 0.35 * math.exp(-i / SR / 0.3) * math.sin(TAU * 11 * i / SR)) for i in range(n_of(sec))]
    spring = amp(layer(osc(f, sec), (osc([v * 2 for v in f], sec, "tri"), 0, 0.3)), decay(sec, 0.3, 0.003))
    return layer(spring, (thud(160, 0.08, 0.5, 0.8), 0, 0.6))


@sound("fun", "duck_squeak", "normal", "rubber duck squeak")
def duck_squeak():
    sec = 0.32
    f = ramp([(0, 650), (0.08, 1150), (0.25, 950), (0.32, 700)], sec)
    reed = amp(osc(f, sec, "square"), adsr(sec, 0.02, 0.06))
    air = amp(bp(noise(sec), 2500, 1), adsr(sec, 0.02, 0.06, 0.2))
    return layer(bp(reed, 1400, 1.4), air)


@sound("fun", "neon_buzz_loop", "quiet", "neon sign buzz with flicker")
def neon_buzz_loop():
    sec = 3.0
    buzz = circ(lambda x: bp(x, 900, 0.5), drive(osc(snap(120, sec), sec, "saw"), 3))
    gate = [1.0] * len(buzz)
    for start in (0.7, 0.82, 2.1):
        for i in range(at_index(start), at_index(start + random.uniform(0.03, 0.08))):
            gate[i] = 0.15
    sparks = wrap_layer(sec, *[(click(random.uniform(2000, 6000), 0.004, 1), t + random.uniform(0, 0.06)) for t in (0.7, 0.82, 2.1) for _ in range(3)])
    return layer(amp(buzz, circ(lambda x: lp(x, 300), gate)), sparks)


@sound("fun", "neon_crackle", "quiet", "neon flicker crackle")
def neon_crackle():
    return scatter(0.6, lambda: layer(click(random.uniform(1500, 7000), 0.004, 0.8), (click(400, 0.01), 0, 0.3)), 14, 0.9)


@sound("fun", "record_lid", "normal", "record player lid creak")
def record_lid():
    sec = 0.5
    c = amp(creak(sec, ramp([(0, 70), (0.5, 120)], sec), [1100, 2000], 14), adsr(sec, 0.03, 0.1))
    return layer(c, (knock(700, 0.05, 5000), sec, 0.7))


@sound("fun", "record_crackle_loop", "normal", "needle crackle")
def record_crackle_loop():
    sec = 4.0
    pops = [(click(random.uniform(1500, 7000), random.uniform(0.001, 0.004), 0.7), random.uniform(0, sec), random.uniform(0.1, 1) ** 2) for _ in range(180)]
    rumble = circ(lambda x: lp(x, 120), noise(sec))
    hum = circ(lambda x: bp(x, 3000, 0.5), noise(sec))
    return layer(wrap_layer(sec, *pops), (rumble, 0, 0.3), (hum, 0, 0.04))


@sound("fun", "spray_rattle", "normal", "spray can shake, clack clack")
def spray_rattle():
    ball = lambda: layer(modes(0.12, [(2900, 1, 0.03), (4400, 0.5, 0.02), (750, 0.4, 0.04)]), (strike(0.003, 6000), 0, 0.4))
    shake = lambda: layer(ball(), (ball(), 0.03, 0.5))
    return layer(*[(shake(), k * 0.16) for k in range(4)])


@sound("fun", "spray_hiss", "normal", "long spray hiss")
def spray_hiss():
    sec = 1.6
    return layer(bp(hiss(sec, 2000, 0.02, 0.15, 0.08), 5500, 0.7), (click(1800, 0.01), 0, 0.4))


@sound("fun", "walkie_click", "normal", "push to talk click")
def walkie_click():
    return layer(click(2800, 0.01, 2), (knock(700, 0.04), 0, 0.3))


@sound("fun", "walkie_static", "normal", "static crackle")
def walkie_static():
    sec = 0.8
    return amp(static(sec, 4, 500, 4000), adsr(sec, 0.005, 0.1))


@sound("fun", "walkie_beep", "normal", "beep when they let go")
def walkie_beep():
    return cat(beep(1250, 0.06), beep(950, 0.08))


@sound("fun", "cam_servo", "quiet", "baby cam pans")
def cam_servo():
    sec = 0.8
    return amp(servo(sec, ramp([(0, 200), (0.4, 260), (0.8, 230)], sec), 0.25, 900), adsr(sec, 0.06, 0.12))


@sound("fun", "monitor_static_loop", "quiet", "baby monitor static hiss")
def monitor_static_loop():
    sec = 3.0
    return circ(lambda x: bp(x, 2500, 0.5), crush(noise(sec), 7))


@sound("fun", "radio_crank", "normal", "crank radio ratchet")
def radio_crank():
    sec = 1.5
    gear = amp(servo(sec, 160, 0.6, 1000), adsr(sec, 0.1, 0.1, 0.3))
    return layer(ratchet(sec, 14, 3000, 900), gear)


@sound("fun", "radio_tune_squeal", "normal", "tuning squeal")
def radio_tune_squeal():
    sec = 1.5
    f = ramp([(0, 400), (0.6, 3000), (1.0, 1300), (1.5, 1800)], sec)
    f = [v * (1 + 0.02 * math.sin(TAU * 6 * i / SR)) for i, v in enumerate(f)]
    whistle = amp(osc(f, sec), adsr(sec, 0.05, 0.2))
    return layer(whistle, (amp(static(sec, 5), adsr(sec, 0.05, 0.2)), 0, 0.5))


# ---------- food ----------


@sound("food", "chips_crinkle", "loud", "loud chip bag crinkle open")
def chips_crinkle():
    sec = 1.0
    e = adsr(sec, 0.05, 0.3)
    tear = amp(bp(noise(0.25), 3000, 0.8), decay(0.25, 0.08))
    return layer(crinkle(sec, 600, env=e), (tear, 0.35, 0.8))


@sound("food", "wrapper_crinkle", "normal", "snack bar or ration pack crinkle")
def wrapper_crinkle():
    sec = 0.7
    return crinkle(sec, 350, env=adsr(sec, 0.05, 0.25))


@sound("food", "crunch", "normal", "crunching")
def crunch():
    sec = 0.28
    e = decay(sec, 0.08, 0.005)
    grains = crinkle(sec, 400, 900, 4500, env=e)
    return layer(grains, (amp(lp(noise(sec), 800), e), 0, 0.5))


@sound("food", "can_pop", "normal", "can lid pops")
def can_pop():
    return layer(amp(lp(noise(0.05), 2000), decay(0.05, 0.008)), (clang(1500, 0.25, 0.5), 0.003, 0.4), (thud(500, 0.04, 0.5, 0), 0, 0.5))


@sound("food", "jar_twist", "normal", "jar lid twists open")
def jar_twist():
    sec = 0.4
    grind = amp(creak(sec, 300, [1600, 2700], 10, 0.4), adsr(sec, 0.03, 0.05))
    return layer(grind, (amp(lp(noise(0.04), 1500), decay(0.04, 0.008)), sec, 0.8))


@sound("food", "cap_twist", "quiet", "bottle cap twist")
def cap_twist():
    return ratchet(0.3, 45, 4500, 2000)


@sound("food", "glug", "quiet", "glug glug")
def glug():
    g = lambda: lp(layer(bubble(random.uniform(180, 260), 0.12, 2.2), (amp(lp(noise(0.1), 600), decay(0.1, 0.03)), 0, 0.2)), 1500)
    return layer(g(), (g(), 0.2), (g(), 0.42, 0.8))


@sound("food", "straw_slurp", "quiet", "straw slurp")
def straw_slurp():
    sec = 0.8
    gurgle = wobble(sec, 30, 0.1, 1.0, smooth=False)
    return amp(bp(noise(sec), ramp([(0, 900), (0.8, 1800)], sec), 2), amp(gurgle, adsr(sec, 0.05, 0.15)))


@sound("food", "energy_crack_fizz", "normal", "can crack and fizz")
def energy_crack_fizz():
    sec = 1.6
    crack = layer(click(2500, 0.01, 0.8), (amp(hp(noise(0.12), 2000), decay(0.12, 0.03)), 0.005, 0.8))
    fizz = crinkle(sec, 500, 4000, 10000, env=decay(sec, 0.6, 0.01))
    return layer(crack, (fizz, 0.02, 0.6), (hiss(0.5, 3000, 0.01, 0.3), 0.01, 0.3))


@sound("food", "cardboard_lid", "normal", "cardboard box lid")
def cardboard_lid():
    return layer(thud(130, 0.12, 0.7, 0.8), (amp(bp(noise(0.15), 1200, 0.7), decay(0.15, 0.04)), 0, 0.5))


@sound("food", "tin_lid", "normal", "tin lunchbox lid")
def tin_lid():
    return layer(clang(780, 0.45, 0.8), (clang(820, 0.3, 0.6), 0.04, 0.4))


@sound("food", "cereal_rattle", "normal", "cereal box rattle")
def cereal_rattle():
    sec = 0.9
    e = [abs(math.sin(TAU * 1.8 * i / SR)) ** 3 for i in range(n_of(sec))]
    return layer(crinkle(sec, 900, 1500, 6000, env=e), (amp(lp(noise(sec), 500), e), 0, 0.3))


@sound("food", "popcorn_popping", "loud", "popcorn popping that builds up")
def popcorn_popping():
    sec = 5.0
    pops = []
    for _ in range(140):
        t = sec * random.random() ** 0.5
        p = layer(amp(bp(noise(0.03), random.uniform(900, 2400), 1.2), decay(0.03, 0.006)), (thud(random.uniform(150, 250), 0.04, 0.6, 0), 0, 0.4))
        pops.append((p, t, random.uniform(0.4, 1)))
    return layer(silence(sec), *pops)


@sound("food", "bite", "quiet", "crisp bite")
def bite():
    sec = 0.15
    return layer(crinkle(sec, 350, 1000, 5000, env=decay(sec, 0.04, 0.002)), (amp(lp(noise(sec), 700), decay(sec, 0.04)), 0, 0.5))


@sound("food", "chew", "quiet", "soft chewing")
def chew():
    c = lambda: amp(lp(noise(0.2), random.uniform(500, 900)), adsr(0.2, 0.06, 0.12))
    return layer(c(), (c(), 0.3), (c(), 0.62, 0.8))


# ---------- guns and gear ----------


@sound("gear", "blaster_zap", "loud", "sci-fi blaster zap")
def blaster_zap():
    sec = 0.3
    f = expo(2600, 180, sec)
    body = layer(osc(f, sec, "saw"), (osc([v * 1.5 for v in f], sec, "square"), 0, 0.4))
    body = [b * math.sin(TAU * 70 * i / SR) for i, b in enumerate(body)]
    body = amp(drive(body, 2.5), decay(sec, 0.09, 0.001))
    return layer(lp(body, 7000), (amp(hp(noise(0.03), 1500), decay(0.03, 0.006)), 0, 0.6))


@sound("gear", "blaster_thump", "loud", "heavy blaster thump")
def blaster_thump():
    sec = 0.5
    punch = amp(osc(expo(130, 38, sec), sec), decay(sec, 0.12, 0.002))
    tail = amp(osc(expo(700, 120, 0.35), 0.35, "tri"), decay(0.35, 0.08))
    return drive(layer(punch, (amp(lp(noise(0.08), 1200), decay(0.08, 0.02)), 0, 0.6), (tail, 0.01, 0.4)), 1.6)


@sound("gear", "shell_clink", "loud", "spent shell clinks on the floor")
def shell_clink():
    s = lambda: clink(random.uniform(3000, 3400), 0.2)
    return layer(s(), (s(), 0.11, 0.6), (s(), 0.19, 0.35), (s(), 0.24, 0.2))


@sound("gear", "cell_eject", "loud", "energy cell pops out on reload")
def cell_eject():
    chirp = amp(osc(expo(600, 2400, 0.15), 0.15, "tri"), adsr(0.15, 0.005, 0.05))
    return layer(hiss(0.18, 2000, 0.005, 0.12), (click(2200, 0.015), 0.01, 0.8), (chirp, 0.05, 0.5))


@sound("gear", "dart_pop", "normal", "foam dart pop")
def dart_pop():
    return layer(amp(lp(noise(0.06), 1500), decay(0.06, 0.012)), (thud(300, 0.06, 0.5, 0), 0, 0.6), (whoosh(0.18, 3000, 1200, 1.5, 0.01, 0.12), 0.02, 0.3))


@sound("gear", "nail_gun", "loud", "pneumatic thunk")
def nail_gun():
    air = amp(hp(noise(0.12), 1500), decay(0.12, 0.03))
    return layer(air, (clang(1400, 0.25, 0.7), 0.005, 0.6), (thud(110, 0.15, 0.5), 0, 0.9))


@sound("gear", "flare_pop", "loud", "flare gun pop")
def flare_pop():
    return layer(thud(150, 0.2, 0.4, 0.8), (amp(lp(noise(0.1), 3000), decay(0.1, 0.02)), 0, 0.8), (hiss(0.6, 2000, 0.05, 0.4), 0.05, 0.3))


@sound("gear", "flare_burn_loop", "loud", "flare fizzing burn")
def flare_burn_loop():
    sec = 3.0
    fizz = circ(lambda x: hp(x, 1500), noise(sec))
    roar = circ(lambda x: lp(x, 400), noise(sec))
    pops = [(click(random.uniform(1500, 6000), 0.004, 1), random.uniform(0, sec), random.uniform(0.3, 1)) for _ in range(120)]
    return layer(amp(fizz, 0.35), (roar, 0, 0.6), wrap_layer(sec, *pops))


@sound("gear", "disruptor_charge", "loud", "disruptor rising whine")
def disruptor_charge():
    sec = 1.5
    f = [v * (1 + 0.03 * (i / n_of(sec)) * math.sin(TAU * 18 * i / SR)) for i, v in enumerate(expo(300, 4000, sec))]
    whine = amp(layer(osc(f, sec), (osc([v * 0.5 for v in f], sec, "square"), 0, 0.15)), ramp([(0, 0.2), (1.45, 1), (1.5, 0)], sec))
    return lp(whine, 8000)


@sound("gear", "disruptor_crack", "loud", "electric crack")
def disruptor_crack():
    sec = 0.6
    crack = amp(noise(0.04), decay(0.04, 0.01, 0.0002))
    buzz = amp(drive(osc(60, sec, "square"), 1), decay(sec, 0.12))
    sparks = scatter(sec, lambda: click(random.uniform(2000, 7000), 0.004, 0.8), 25, 0.6)
    return layer(crack, (lp(buzz, 2500), 0, 0.5), (amp(sparks, decay(sec, 0.15)), 0, 0.6))


@sound("gear", "cuffs_lock", "normal", "handcuffs click click lock")
def cuffs_lock():
    tooth = lambda: layer(click(3500, 0.008, 3), (clink(4800, 0.05), 0, 0.2))
    return layer(tooth(), (tooth(), 0.07), (tooth(), 0.13), (clang(900, 0.25, 0.6), 0.22, 0.8))


@sound("gear", "cuffs_rattle", "normal", "cuffs rattle when struggling")
def cuffs_rattle():
    return layer(scatter(0.6, lambda: clink(random.uniform(3500, 6000), 0.12), 16, 0.9), (knock(400, 0.08), 0.1, 0.3), (knock(380, 0.08), 0.4, 0.3))


@sound("gear", "flashlight_click", "quiet", "flashlight click")
def flashlight_click():
    return layer(click(3000, 0.01, 2.5), (knock(800, 0.03), 0, 0.3))


@sound("gear", "visor_clack", "quiet", "riot visor clack")
def visor_clack():
    slide = amp(bp(noise(0.08), 1800, 1), adsr(0.08, 0.02, 0.02))
    return layer(slide, (knock(520, 0.08, 4000), 0.075))


@sound("gear", "zipper", "quiet", "backpack zipper")
def zipper():
    sec = 0.5
    teeth = ratchet(sec, 140, 3200, 1800)
    return amp(teeth, adsr(sec, 0.03, 0.06))


@sound("gear", "velcro", "normal", "velcro rip")
def velcro():
    sec = 0.45
    return amp(bp(noise(sec), 2500, 0.8), amp(wobble(sec, 600, 0, 1, smooth=False), adsr(sec, 0.01, 0.1)))


@sound("gear", "noise_maker_wind", "loud", "noise maker winding clicks")
def noise_maker_wind():
    return ratchet(1.5, 9, 3000, 800)


@sound("gear", "noise_maker_tick_loop", "loud", "noise maker ticking")
def noise_maker_tick_loop():
    sec = 1.0
    t = layer(click(3800, 0.01, 3), (knock(1000, 0.03), 0, 0.5))
    return wrap_layer(sec, (t, 0), (t, 0.5, 0.85))


def bell_ring(sec, f=1800):
    hit = lambda: modes(0.2, [(f, 1, 0.15), (f * 1.27, 0.7, 0.12), (f * 2.6, 0.3, 0.05), (f * 3.9, 0.15, 0.03)])
    return layer(*[(hit(), k * 0.04, 0.8 + 0.2 * (k % 2)) for k in range(int(sec / 0.04))])


@sound("gear", "noise_maker_bell", "loud", "alarm bell")
def noise_maker_bell():
    return bell_ring(2.5)


@sound("gear", "smoke_pin", "normal", "smoke can pin click")
def smoke_pin():
    return layer(click(3000, 0.012, 2), (clink(4200, 0.15), 0.005, 0.5))


@sound("gear", "smoke_hiss", "normal", "smoke hiss")
def smoke_hiss():
    sec = 3.0
    return layer(hiss(sec, 1200, 0.08, 1.0, 0.3), (amp(lp(noise(sec), 500), adsr(sec, 0.1, 1.0)), 0, 0.3))


@sound("gear", "emp_tab", "loud", "EMP tab pull")
def emp_tab():
    chirp = amp(osc(expo(900, 1800, 0.08), 0.08, "square"), adsr(0.08, 0.003, 0.03))
    return layer(click(2600, 0.015, 1.5), (clink(3700, 0.1), 0.005, 0.4), (lp(chirp, 4000), 0.04, 0.4))


@sound("gear", "emp_charge", "loud", "EMP charge whine")
def emp_charge():
    sec = 1.2
    f = expo(500, 6000, sec)
    return amp(layer(osc(f, sec), (osc([v * 1.01 for v in f], sec, "tri"), 0, 0.4)), ramp([(0, 0.2), (1.15, 1), (1.2, 0)], sec))


@sound("gear", "emp_thump", "loud", "deep electric thump")
def emp_thump():
    sec = 1.4
    boom = amp(osc(expo(60, 24, sec), sec), decay(sec, 0.35, 0.003))
    zap = amp(osc(expo(1200, 60, 0.6), 0.6, "saw"), decay(0.6, 0.15))
    sparks = amp(scatter(0.8, lambda: click(random.uniform(1500, 6000), 0.005, 0.8), 30), decay(0.8, 0.2))
    return drive(layer(boom, (amp(lp(noise(0.15), 800), decay(0.15, 0.04)), 0, 0.7), (lp(zap, 3000), 0, 0.3), (sparks, 0.02, 0.4)), 1.5)


@sound("gear", "crate_lid", "normal", "heavy loot crate lid")
def crate_lid():
    hinge = amp(creak(0.3, 60, [500, 1100], 10), adsr(0.3, 0.02, 0.05))
    return layer(hinge, (thud(80, 0.3, 0.6), 0.28, 1.0), (clang(240, 0.6, 0.6), 0.28, 0.5), (knock(160, 0.2), 0.28, 0.6))


@sound("gear", "locker_clang", "normal", "metal locker door clang")
def locker_clang():
    sheet = clang(310, 1.0, 1.0, (1, 1.52, 2.13, 2.9, 3.7, 5.1, 6.8))
    rattle = amp(scatter(0.25, lambda: clink(random.uniform(1500, 2500), 0.06), 8), 0.4)
    return layer(sheet, (thud(90, 0.2), 0, 0.6), (rattle, 0.02))


@sound("gear", "medkit_latch", "quiet", "medkit latch clicks")
def medkit_latch():
    latch = lambda: layer(click(2600, 0.012, 2), (knock(700, 0.04, 4000), 0, 0.5))
    return layer(latch(), (latch(), 0.14, 0.9))


@sound("gear", "tape_rip", "quiet", "bandage tape rip")
def tape_rip():
    sec = 0.4
    return amp(bp(noise(sec), ramp([(0, 2000), (0.4, 4500)], sec), 1), amp(wobble(sec, 300, 0.2, 1, smooth=False), adsr(sec, 0.01, 0.06)))


# ---------- robots ----------
# Heavy, old and wrong: big motors under strain, hydraulics, iron feet, joints that need oil. No beeps.


def motor(sec, freq, strain=0.5, tone=900, teeth=9):
    """A big worn motor: buzzy low saw whose pitch and grip slip, with gear teeth chattering through it."""
    n = n_of(sec)
    f = as_list(freq, n)
    slip = wobble(sec, 18, 1 - 0.06 * strain, 1 + 0.06 * strain)
    f = [a * b for a, b in zip(f, slip)]
    body = layer(osc(f, sec, "saw"), (osc([v * 1.5 for v in f], sec, "saw"), 0, 0.5), (osc([v * 0.5 for v in f], sec, "square"), 0, 0.35))
    chatter = osc([v * teeth / 4 for v in f], sec, "square")
    grip = wobble(sec, 30, 1 - strain, 1)
    body = [b * (0.55 + 0.45 * (c * 0.5 + 0.5)) * g for b, c, g in zip(body, chatter, grip)]
    return lp(drive(layer(lp(body, tone, 1.2), (bp(body, tone * 2.3, 3), 0, 0.4)), 1.8 + strain * 2), tone * 3)


def joint_creak(sec, rate, bands=(140, 290, 560, 1050), q=10):
    """A dry joint grinding: stick and slip low down, like a metal hinge the size of a car."""
    return lp(creak(sec, rate, list(bands), q, 0.3), 2200)


def hydraulic(sec, lo=900, hi=4000, a=0.01, r=0.25):
    """Pressure let out of a piston: a hiss that sweeps down as the pressure drops."""
    e = amp(adsr(sec, a, r), ramp([(0, 1), (sec, 0.4)], sec))
    return amp(layer(hp(noise(sec), lo), (bp(noise(sec), expo(hi, lo * 1.5, sec), 2), 0, 0.8)), e)


def plate(f=95, sec=0.8, weight=1.0):
    """A thick iron plate hit hard: low, dull, inharmonic."""
    return lp(modes(sec, [(f, 1, sec / 3), (f * 1.73, 0.7, sec / 4), (f * 2.61, 0.5, sec / 6), (f * 4.07, 0.3, sec / 9), (f * 5.9, 0.15, sec / 14)]), 1400 + 600 * weight)


def drip(f=420, sec=0.35):
    """One thick drop landing in a puddle: a bloop that bends up, with a soft splat."""
    blip = amp(osc(expo(f, f * 2.6, 0.06) + [f * 2.6] * n_of(sec - 0.06), sec), decay(sec, 0.035, 0.001))
    splat = lp(amp(noise(0.03), decay(0.03, 0.006)), 1200)
    return lp(layer((splat, 0, 0.5), (blip, 0.004)), 2600)


@sound("robots", "servo_whirr_1", "normal", "day: big servo groaning as a limb lifts")
def servo_whirr_1():
    sec = 1.1
    m = amp(motor(sec, ramp([(0, 48), (0.5, 82), (1.1, 74)], sec), 0.6, 700), adsr(sec, 0.08, 0.25))
    c = amp(joint_creak(sec, ramp([(0, 10), (0.5, 26), (1.1, 14)], sec)), adsr(sec, 0.15, 0.3))
    return layer(m, (c, 0.05, 0.5), (hydraulic(0.5, 1200, 3500), 0.75, 0.18))


@sound("robots", "servo_whirr_2", "normal", "day: servo settling a limb back down")
def servo_whirr_2():
    sec = 0.8
    m = amp(motor(sec, ramp([(0, 78), (0.8, 44)], sec), 0.5, 650), adsr(sec, 0.04, 0.2))
    return layer(m, (plate(120, 0.5, 0.6), sec - 0.12, 0.45), (hydraulic(0.6, 1000, 3000), sec - 0.05, 0.22))


@sound("robots", "curious_beep_1", "normal", "day: head tilts with a slow rising creak, asking")
def curious_beep_1():
    sec = 1.3
    tilt = amp(joint_creak(sec, ramp([(0, 7), (0.9, 30), (1.3, 40)], sec), (180, 360, 700, 1300), 14), adsr(sec, 0.2, 0.15))
    m = amp(motor(sec, ramp([(0, 40), (1.3, 70)], sec), 0.7, 600), adsr(sec, 0.3, 0.2))
    return layer(tilt, (m, 0, 0.45), (click(900, 0.03, 2), sec - 0.05, 0.6))


@sound("robots", "curious_beep_2", "normal", "day: ratcheting, thinking it over")
def curious_beep_2():
    parts, t = [], 0.0
    for k in range(7):
        parts.append((layer(knock(random.uniform(380, 460), 0.08, 1800), (click(1500, 0.01, 2), 0, 0.5)), t, random.uniform(0.5, 0.9)))
        t += random.uniform(0.08, 0.16) + (0.25 if k == 3 else 0)
    hum = amp(motor(t + 0.3, ramp([(0, 55), (t, 50)], t + 0.3), 0.8, 500), adsr(t + 0.3, 0.1, 0.2))
    return layer((hum, 0, 0.5), *parts)


@sound("robots", "curious_beep_3", "normal", "day: groan down and up, then a clunk: found something")
def curious_beep_3():
    sec = 1.0
    m = amp(motor(sec, ramp([(0, 70), (0.4, 46), (1.0, 92)], sec), 0.5, 750), adsr(sec, 0.05, 0.12))
    c = amp(joint_creak(sec, ramp([(0, 20), (0.4, 8), (1.0, 34)], sec)), adsr(sec, 0.05, 0.15))
    return layer(m, (c, 0, 0.45), (plate(110, 0.7, 0.8), sec - 0.05, 0.8), (hydraulic(0.4, 1500, 4000), sec, 0.15))


@sound("robots", "fumble", "normal", "day: fumbling with objects")
def fumble():
    hits = [knock(random.uniform(250, 600), 0.1, 3000), clink(random.uniform(2000, 3500), 0.15), click(1800, 0.015), knock(random.uniform(300, 500), 0.08)]
    whirr = amp(motor(0.4, 60, 0.6, 600), adsr(0.4, 0.04, 0.1))
    return layer((whirr, 0, 0.4), *[(h, k * 0.14 + random.uniform(0, 0.05), random.uniform(0.5, 1)) for k, h in enumerate(hits)])


@sound("robots", "spot_alert", "loud", "day: head snaps round with a grinding lurch when it spots you")
def spot_alert():
    sec = 0.9
    snap_m = amp(motor(0.35, expo(40, 160, 0.35), 0.9, 1200), adsr(0.35, 0.01, 0.05))
    lock = layer(plate(85, 0.8, 1.2), (thud(45, 0.5, 0.5, 0.6), 0, 0.9))
    groan = amp(motor(sec, ramp([(0, 160), (sec, 130)], sec), 0.9, 900), adsr(sec, 0.02, 0.5))
    return reverb(drive(layer(snap_m, (lock, 0.32), (groan, 0.32, 0.5)), 1.6), 1.6, 0.3, 1.0)


@sound("robots", "hum_loop", "loud", "night: low, dirty electrical drone with crackle")
def hum_loop():
    sec = 4.0
    n = n_of(sec)
    beat = [0.75 + 0.25 * math.sin(TAU * snap(0.75, sec) * i / SR) for i in range(n)]
    mains = layer(osc(snap(41, sec), sec, "saw"), (osc(snap(82.3, sec), sec, "square"), 0, 0.3), (osc(snap(41.6, sec), sec, "saw"), 0, 0.8))
    mains = circ(lambda x: lp(drive(x, 3.0), 520), mains)
    buzz = circ(lambda x: bp(drive(x, 6), 240, 4), osc(snap(123, sec), sec, "saw"))
    rumble = circ(lambda x: lp(x, 90), noise(sec))
    crackle = [(amp(click(random.uniform(1200, 4000), 0.02, 1), random.uniform(0.2, 1)), random.uniform(0, sec), 0.25) for _ in range(22)]
    sparks = wrap_layer(sec, *crackle)
    return layer(amp(mains, beat), (buzz, 0, 0.12), (rumble, 0, 1.6), (sparks, 0, 0.6))


@sound("robots", "scanner_ping", "loud", "night: deep pulse and a grinding lens turn, every few seconds")
def scanner_ping():
    pulse = layer(amp(osc(expo(70, 52, 1.2), 1.2), decay(1.2, 0.35, 0.004)), (amp(osc(expo(210, 160, 0.8), 0.8, "saw"), decay(0.8, 0.12, 0.004)), 0, 0.25))
    pulse = lp(drive(pulse, 2.2), 800)
    lens, t, gap = [], 0.1, 0.09
    while t < 0.9:
        lens.append((click(random.uniform(1800, 2400), 0.012, 3), t, 0.5))
        t += gap
        gap *= 0.82
    whine = amp(motor(0.9, expo(90, 180, 0.9), 0.4, 1100), adsr(0.9, 0.1, 0.3, 0.35))
    return reverb(layer(pulse, (whine, 0.08), *lens), 1.8, 0.45, 1.8)


def heavy_step(f=42, weight=1.0):
    body = thud(f, 0.6, 0.55, 0.9)
    iron = plate(random.uniform(78, 92), 0.6, weight)
    knee = amp(joint_creak(0.25, 22), adsr(0.25, 0.02, 0.1))
    psst = hydraulic(0.3, 1400, 3800, 0.01, 0.2)
    grit = lp(amp(noise(0.12), decay(0.12, 0.03)), 1500)
    return drive(layer(body, (iron, 0, 0.55 * weight), (grit, 0, 0.35), (knee, 0.04, 0.3), (psst, 0.12, 0.12)), 1.3)


@sound("robots", "heavy_step", "loud", "night: one heavy iron foot coming down, piston hiss")
def heavy_step_sound():
    return heavy_step()


@sound("robots", "chase_servo_scream", "loud", "chase: a horrible rising grind as it lurches into a run")
def chase_servo_scream():
    sec = 2.2
    f = ramp([(0, 34), (0.5, 60), (1.4, 150), (2.2, 210)], sec)
    deep = amp(motor(sec, f, 1.0, 900, 11), adsr(sec, 0.05, 0.35))
    shriek = amp(joint_creak(sec, ramp([(0, 15), (1.0, 60), (2.2, 140)], sec), (420, 880, 1700, 2900), 16), ramp([(0, 0), (0.6, 0.3), (1.8, 1), (2.2, 0)], sec))
    second = amp(motor(sec, [v * 1.41 for v in f], 1.0, 1300), adsr(sec, 0.5, 0.35, 0.6))
    blast = hydraulic(0.7, 700, 4500, 0.005, 0.5)
    hit = layer(plate(70, 0.9, 1.4), (thud(38, 0.6, 0.5, 0.8), 0, 1.0))
    return drive(layer(hit, (blast, 0, 0.35), (deep, 0.05), (second, 0.05, 0.6), (shriek, 0.05, 0.5)), 2.0)


@sound("robots", "chase_steps", "loud", "chase: heavy steps speeding up")
def chase_steps():
    parts, t, gap = [], 0.0, 0.55
    while t < 3.2:
        parts.append((heavy_step(random.uniform(40, 48), 0.8), t, random.uniform(0.8, 1)))
        t += gap
        gap = max(0.2, gap * 0.86)
    return layer(*parts)


def jingle(pitch=1.0):
    notes = [659.26, 880.0, 1108.73, 987.77]
    parts = []
    for k, f in enumerate(notes):
        f *= pitch
        ring = 1.8 if k == 3 else 0.5
        tone = modes(ring + 0.2, [(f, 1, ring * 0.6), (f * 2, 0.4, ring * 0.3), (f * 3.01, 0.15, ring * 0.15), (f * 4.2, 0.08, 0.06), (f * 0.5, 0.12, ring)])
        parts.append((layer(tone, (strike(0.003, 7000), 0, 0.15)), k * 0.22))
    return layer(*parts)


@sound("robots", "jingle_distorted", "loud", "chase: broken, slowed store jingle")
def jingle_distorted():
    j = speed(jingle(), 0.78)
    j = layer(warble(j, 0.004, 3.3), (warble(j, 0.006, 2.1), 0.03, 0.6))
    return lp(crush(drive(j, 3), 5, 3), 4500)


@sound("robots", "scout_step", "normal", "scout: thin clicking step")
def scout_step():
    c = lambda: layer(click(random.uniform(3800, 4600), 0.008, 3), (clink(5200, 0.04), 0, 0.2), (knock(900, 0.03), 0, 0.3))
    return layer(c(), (c(), 0.035, 0.7))


@sound("robots", "scout_eye_whine", "normal", "scout: eye whines as it focuses")
def scout_eye_whine():
    sec = 0.8
    f = [v * (1 + 0.01 * math.sin(TAU * 9 * i / SR)) for i, v in enumerate(expo(2000, 5200, sec))]
    whine = amp(osc(f, sec), adsr(sec, 0.05, 0.12))
    focus = amp(servo(0.3, 700, 0.4, 2500), adsr(0.3, 0.02, 0.05))
    return layer((whine, 0, 0.6), focus, (click(5000, 0.006), sec - 0.05, 0.4))


@sound("robots", "brute_thud", "loud", "brute: heavy thud")
def brute_thud():
    sec = 0.9
    boom = amp(osc(expo(42, 26, sec), sec), decay(sec, 0.25, 0.003))
    debris = amp(scatter(0.5, lambda: knock(random.uniform(300, 900), 0.05), 12), decay(0.5, 0.12))
    return drive(layer(boom, heavy_step(40, 1.4), (debris, 0.03, 0.3)), 1.4)


@sound("robots", "brute_groan", "loud", "brute: metal groan")
def brute_groan():
    sec = 2.0
    c = creak(sec, ramp([(0, 14), (0.8, 38), (1.4, 22), (2.0, 16)], sec), [150, 320, 610, 1150], 8, 0.15)
    bend = amp(osc(ramp([(0, 72), (1.0, 64), (2.0, 58)], sec), sec, "saw"), 0.15)
    return amp(layer(c, lp(bend, 400)), adsr(sec, 0.2, 0.5))


@sound("robots", "crawler_skitter_loop", "normal", "crawler: fast skittering")
def crawler_skitter_loop():
    sec = 2.0
    taps = []
    t = 0.0
    while t < sec:
        for leg in range(4):
            taps.append((click(random.uniform(2500, 5500), 0.006, 2.5), t + leg * 0.012 + random.uniform(0, 0.004), random.uniform(0.4, 1)))
        t += random.uniform(0.07, 0.11)
    return wrap_layer(sec, *taps)


@sound("robots", "grab_clank", "normal", "grabbing: a heavy iron clamp slams shut, then hisses")
def grab_clank():
    reach = amp(motor(0.3, expo(60, 120, 0.3), 0.7, 800), adsr(0.3, 0.02, 0.03))
    clamp = layer(plate(130, 0.9, 1.2), (clang(260, 0.6, 0.5), 0, 0.35), (thud(55, 0.4, 0.5, 0.7), 0, 0.9))
    ratchet = [(click(1400, 0.012, 2.5), 0.4 + k * 0.05, 0.4) for k in range(4)]
    return drive(layer((reach, 0, 0.6), (clamp, 0.28), *ratchet, (hydraulic(0.5, 1200, 3500), 0.55, 0.25)), 1.5)


@sound("robots", "scrape", "normal", "grabbing: metal dragged over concrete, juddering")
def scrape():
    sec = 1.0
    grind = bp(noise(sec), wobble(sec, 12, 600, 1100), 2)
    judder = joint_creak(sec, wobble(sec, 6, 18, 40), (230, 470, 900), 9)
    return amp(layer(amp(grind, wobble(sec, 40, 0.3, 1.0)), (judder, 0, 0.7), (lp(noise(sec), 150), 0, 0.6)), adsr(sec, 0.03, 0.2))


@sound("robots", "drag", "normal", "grabbing: something heavy hauled away across the floor")
def drag():
    sec = 2.0
    grind = amp(bp(noise(sec), wobble(sec, 8, 380, 700), 1.5), wobble(sec, 25, 0.4, 1.0))
    judder = joint_creak(sec, wobble(sec, 4, 10, 28), (120, 260, 520), 8)
    rumble = lp(noise(sec), 140)
    tug = amp(motor(sec, 46, 0.8, 500), 0.25)
    return amp(layer(grind, (judder, 0, 0.6), (rumble, 0, 1.2), (tug, 0, 0.5)), adsr(sec, 0.12, 0.35))


@sound("robots", "oil_drip", "quiet", "idle: thick oil dripping off a robot into a puddle")
def oil_drip():
    t, parts = 0.0, []
    for k in range(3):
        parts.append((drip(random.uniform(300, 460)), t, random.uniform(0.7, 1)))
        t += random.uniform(0.55, 0.9)
    return reverb(layer(*parts), 1.3, 0.35, 0.9, 0.6)


@sound("robots", "hydraulic_hiss", "normal", "idle: a piston letting pressure out, with a settling clunk")
def hydraulic_hiss():
    sec = 1.4
    return layer((plate(140, 0.5, 0.5), 0, 0.4), (hydraulic(sec, 900, 4200, 0.008, 0.9), 0.02), (joint_creak(0.4, 14), 0.9, 0.2))


@sound("robots", "emp_shutdown", "loud", "hit by EMP: power down whine, then silence")
def emp_shutdown():
    sec = 1.8
    f = expo(420, 28, sec)
    whine = lp(layer(osc(f, sec, "saw"), (osc([v * 4 for v in f], sec), 0, 0.3)), expo(5000, 200, sec))
    whine = amp(whine, ramp([(0, 1), (1.4, 0.6), (1.8, 0)], sec))
    sparks = amp(scatter(0.5, lambda: click(random.uniform(2000, 7000), 0.004, 0.8), 25), decay(0.5, 0.15))
    return layer(sparks, (whine, 0, 0.9), (amp(noise(0.03), decay(0.03, 0.008)), 0, 0.8))


@sound("robots", "error_stall", "loud", "frozen hunter at lights on: motor stalls, tries again, dies")
def error_stall():
    parts, t = [], 0.0
    for k, (f0, f1, d) in enumerate([(90, 60, 0.35), (80, 50, 0.3), (70, 22, 0.9)]):
        tries = amp(motor(d, expo(f0, f1, d), 1.0, 700), ramp([(0, 0), (0.02, 1), (d * 0.7, 0.8), (d, 0)], d))
        parts.append((tries, t))
        parts.append((amp(scatter(0.15, lambda: click(random.uniform(2000, 6000), 0.005, 0.8), 6), 0.4), t + d - 0.08))
        t += d + (0.12 if k < 2 else 0)
    parts.append((plate(100, 0.8, 1.0), t - 0.1, 0.7))
    parts.append((hydraulic(1.0, 800, 3000, 0.01, 0.8), t - 0.05, 0.3))
    return drive(layer(*parts), 1.4)


# ---------- players ----------


def footstep(floor, force=1.0):
    scuff = bp(amp(noise(0.08), decay(0.08, 0.015 * force)), 1800, 0.8)
    if floor == "concrete":
        body = thud(90, 0.12, 0.6, 0.6)
    elif floor == "wood":
        body = layer(knock(130, 0.18, 1500), (thud(80, 0.12, 0.6, 0), 0, 0.6))
    else:
        body = layer(thud(75, 0.15, 0.6), (lp(clang(420, 0.35, 0.6), 3000), 0, 0.25))
    return layer(body, (scuff, 0, 0.3 * force))


for _floor in ("concrete", "wood", "metal"):
    sound("players", f"walk_{_floor}", "quiet", f"walking on {_floor}")(lambda f=_floor: footstep(f))
    sound("players", f"run_{_floor}", "normal", f"running on {_floor}")(lambda f=_floor: footstep(f, 1.8))


@sound("players", "crouch_step", "quiet", "crouching, almost silent")
def crouch_step():
    return lp(amp(noise(0.1), adsr(0.1, 0.02, 0.07)), 600)


@sound("players", "psst", "quiet", "a short psst")
def psst():
    p = layer(amp(lp(noise(0.018), 900), decay(0.018, 0.004)), (thud(120, 0.03, 0.6, 0), 0, 0.5))
    s = amp(bp(hp(noise(0.32), 3500), 6200, 1.3), ramp([(0, 0), (0.05, 1), (0.22, 0.9), (0.32, 0)], 0.32))
    t = amp(bp(noise(0.02), 4000, 1), decay(0.02, 0.004))
    return layer((p, 0, 0.7), (s, 0.02), (t, 0.36, 0.4))


@sound("players", "land_thud", "normal", "landing from a jump")
def land_thud():
    return layer(thud(70, 0.3, 0.5, 0.7), (footstep("concrete", 1.5), 0, 0.5))


@sound("players", "prop_wood_knock", "normal", "pick up or drop: wood")
def prop_wood_knock():
    return knock(190, 0.22)


@sound("players", "prop_metal_clang", "normal", "pick up or drop: metal")
def prop_metal_clang():
    return layer(clang(460, 0.8, 0.8), (thud(110, 0.1), 0, 0.4))


@sound("players", "prop_cardboard_thump", "normal", "pick up or drop: cardboard")
def prop_cardboard_thump():
    return layer(thud(120, 0.15, 0.7, 0.9), (amp(bp(noise(0.1), 900, 0.7), decay(0.1, 0.03)), 0, 0.4))


@sound("players", "stack_crash", "loud", "stacking a prop wrong: clattering crash")
def stack_crash():
    makers = [lambda: knock(random.uniform(140, 400), 0.2), lambda: clang(random.uniform(300, 900), 0.6, 0.6), lambda: thud(random.uniform(90, 150), 0.2), lambda: crinkle(0.1, 200)]
    parts = [(random.choice(makers)(), 1.0 * random.random() ** 1.6, random.uniform(0.4, 1)) for _ in range(18)]
    return layer((thud(70, 0.4, 0.5), 0, 1.2), *parts)


@sound("players", "down_zap", "normal", "going down: robot zap static")
def down_zap():
    sec = 0.6
    buzz = amp(lp(osc(120, sec, "square"), 2000), decay(sec, 0.15))
    fall = amp(osc(expo(1500, 150, sec), sec, "saw"), decay(sec, 0.18))
    return layer(amp(static(sec, 4, 600, 5000), decay(sec, 0.2)), (buzz, 0, 0.6), (lp(fall, 3000), 0, 0.4))


@sound("players", "heartbeat_loop", "normal", "muffled heartbeat while down")
def heartbeat_loop():
    sec = 0.8
    lub = amp(osc(expo(55, 40, 0.15), 0.15), decay(0.15, 0.04, 0.008))
    dub = amp(osc(expo(48, 36, 0.15), 0.15), decay(0.15, 0.035, 0.008))
    return circ(lambda x: lp(x, 160), wrap_layer(sec, (lub, 0), (dub, 0.16, 0.7)))


def breath(sec, f1, f2, a, r):
    """Unvoiced air through the mouth: noise rung through two moving mouth shapes, no vocal tone."""
    air = noise(sec)
    f = expo(f1, f2, sec)
    body = layer(bp(air, f, 1.4), (bp(air, [v * 2.2 for v in f], 2.0), 0, 0.45), (hp(air, 4000), 0, 0.12))
    return amp(body, adsr(sec, a, r))


@sound("players", "breath_heavy_loop", "quiet", "winded breathing after a sprint, air only")
def breath_heavy_loop():
    sec = 3.3
    parts = []
    for k in range(3):
        t = k * 1.1
        inhale = breath(random.uniform(0.38, 0.44), 1500, 2100, 0.08, 0.1)
        exhale = breath(random.uniform(0.5, 0.58), 1100, 750, 0.04, 0.3)
        parts += [(inhale, t, random.uniform(0.5, 0.6)), (exhale, t + 0.46, random.uniform(0.85, 1.0))]
    return wrap_layer(sec, *parts)


@sound("players", "hold_breath", "quiet", "sharp inhale before holding the breath")
def hold_breath():
    sec = 0.42
    inhale = amp(breath(sec, 900, 2000, 0.03, 0.02), ramp([(0, 0.6), (0.06, 1), (0.42, 0.85)], sec))
    return layer(inhale, (click(1400, 0.006, 2), sec - 0.01, 0.25))


@sound("players", "breath_release", "quiet", "shaky exhale and gasp after holding the breath, air only")
def breath_release():
    gasp = breath(0.22, 1300, 2200, 0.01, 0.06)
    sec = 1.4
    out = amp(breath(sec, 1000, 700, 0.02, 0.5), tremble(sec, 7, 11, 0.55))
    calm = breath(0.5, 1400, 1800, 0.12, 0.15)
    return layer((gasp, 0, 0.8), (out, 0.24), (calm, 1.7, 0.35))


@sound("players", "hide_creak", "quiet", "wardrobe door pulled shut from inside, muffled slow creak")
def hide_creak():
    sec = 1.4
    c = amp(creak(sec, ramp([(0, 35), (0.7, 70), (1.4, 45)], sec), [380, 820, 1500], 14), adsr(sec, 0.1, 0.15))
    latch = layer(knock(300, 0.14, 1200), (click(1800, 0.008, 2), 0, 0.3))
    box = layer(norm(c), (norm(latch), sec + 0.05, 0.6))
    return lp(layer(box, (bp(box, 250, 3), 0, 0.5)), 1100)


@sound("players", "flashlight_flicker", "quiet", "low battery buzz and stutter clicks")
def flashlight_flicker():
    sec = 1.3
    hum = layer(osc(120, sec, "square"), (osc(240, sec, "saw"), 0, 0.4))
    hum = layer(bp(hum, 1200, 0.8), (osc(7800, sec), 0, 0.03))
    spans = [(0.0, 0.14, 1.0), (0.2, 0.25, 0.8), (0.31, 0.5, 0.9), (0.58, 0.61, 0.6), (0.7, 0.86, 0.55), (0.95, 0.98, 0.4), (1.08, 1.22, 0.3)]
    hum = amp(hum, tremble(sec, 25, 40, 0.35))
    clicks, pts = [], [(0, 0)]
    for on, off, lv in spans:
        pts += [(on, 0), (on + 0.002, lv), (off - 0.002, lv), (off, 0)]
        clicks += [(click(3200, 0.008, 2), on, 0.35 * lv), (click(2600, 0.008, 2), off, 0.2 * lv)]
    gate = ramp(pts + [(sec, 0)], sec)
    return layer(amp(hum, gate), *clicks)


# ---------- the warehouse ----------


@sound("warehouse", "store_jingle", "loud", "lights on: cheerful 4 note chime")
def store_jingle():
    return reverb(jingle(), 1.5, 0.3, 1.2)


@sound("warehouse", "siren", "loud", "rising siren before lights out")
def siren():
    sec = 6.0
    f = []
    for i in range(n_of(sec)):
        t = (i / SR) % 3.0
        f.append(280 + 640 * (1 - math.exp(-t / 0.9)) * (1 + 0.01 * math.sin(TAU * 6 * i / SR)))
    body = layer(osc(f, sec, "saw"), (osc(f, sec, "square"), 0, 0.5))
    shape = ramp([(0, 0), (0.15, 1), (5.6, 1), (6.0, 0)], sec)
    return reverb(amp(lp(body, 2500), shape), 1.8, 0.3, 1.0)


@sound("warehouse", "lights_out_clunk", "loud", "lights out: big electric clunk, lights die")
def lights_out_clunk():
    sec = 2.5
    boom = amp(osc(expo(55, 28, 1.0), 1.0), decay(1.0, 0.3, 0.002))
    relay = layer(clang(160, 1.0, 0.8, (1, 2.2, 3.4, 5.1, 7.3)), (knock(90, 0.3, 1200), 0, 0.8))
    zap = amp(static(0.25, 4), decay(0.25, 0.05))
    die = layer(osc(expo(120, 30, sec), sec, "saw"), (osc(expo(240, 60, sec), sec), 0, 0.3))
    die = amp(lp(die, 800), ramp([(0, 0.5), (2.5, 0)], sec))
    return reverb(layer(boom, (relay, 0, 0.7), (zap, 0, 0.5), (die, 0.02, 0.6)), 2.0, 0.35, 2.0)


@sound("warehouse", "distant_hum_loop", "loud", "after lights out: distant hum")
def distant_hum_loop():
    sec = 4.0
    hum = layer(osc(snap(60, sec), sec), (osc(snap(120, sec), sec), 0, 0.4), (osc(snap(180, sec), sec), 0, 0.15))
    swell = [0.8 + 0.2 * math.sin(TAU * snap(0.5, sec) * i / SR) for i in range(n_of(sec))]
    air = circ(lambda x: lp(x, 250), brown(sec))
    return layer(amp(hum, swell), (norm(air, 0.5), 0))


@sound("warehouse", "night_ambience_loop", "quiet", "always on: vents, far metal clanks, a ping somewhere")
def night_ambience_loop():
    sec = 24.0
    vents = circ(lambda x: lp(x, 450), brown(sec))
    vents = amp(norm(vents), [0.75 + 0.25 * math.sin(TAU * snap(0.125, sec) * i / SR) for i in range(n_of(sec))])
    far = lambda: lp(clang(random.uniform(150, 400), 1.2, 0.6), 1200)
    ping = amp(osc(expo(1900, 1750, 0.6), 0.6), decay(0.6, 0.12, 0.002))
    events = wrap_layer(sec, (far(), 3.0, 0.5), (far(), 9.5, 0.3), (far(), 9.8, 0.2), (ping, 15.0, 0.15), (far(), 20.5, 0.4))
    events = circ(lambda x: reverb(x, 2.5, 0.7, 0.0, 0.5, 0.88), events)
    return layer(amp(vents, 0.6), events)


def far_off(x, tail=3.0):
    """Push a sound to the far end of the warehouse: dull it, then a slap echo and a big room."""
    x = hp(lp(x, 1600), 120)
    return reverb(echo(x, 0.28, 0.35, 3), 2.6, 0.7, tail, 0.5, 0.86)


@sound("warehouse", "rain_roof_loop", "normal", "steady rain on the metal roof far above")
def rain_roof_loop():
    sec = 6.0
    n = n_of(sec)
    roar = circ(lambda x: lp(x, 1200), noise(sec))
    sizzle = circ(lambda x: bp(x, 3500, 0.6), noise(sec))
    low = norm(circ(lambda x: lp(x, 150), noise(sec)))
    drops = [(click(random.uniform(1500, 6000), random.uniform(0.003, 0.01), 2), random.uniform(0, sec), random.uniform(0.05, 1) ** 2) for _ in range(1500)]
    pings = [(clink(random.uniform(2500, 5000), 0.08), random.uniform(0, sec), random.uniform(0.02, 0.08)) for _ in range(60)]
    drops = circ(lambda x: lp(x, 3000), wrap_layer(sec, *drops, *pings))
    bed = layer(norm(roar), (norm(sizzle), 0, 0.25), (low, 0, 0.5), (norm(drops), 0, 0.35))
    swell = [0.85 + 0.15 * math.sin(TAU * snap(0.25, sec) * i / SR) for i in range(n)]
    return circ(lambda x: reverb(x, 2.2, 0.35, 0.0, 0.5, 0.84), amp(bed, swell))[:n]


@sound("warehouse", "thunder_near", "loud", "close thunder crack then a long rumble")
def thunder_near():
    sec = 7.0
    crack = layer(hp(amp(noise(0.4), decay(0.4, 0.06)), 300), (crinkle(0.3, 300, 1500, 9000), 0, 0.8))
    rumble = lp(noise(sec), expo(900, 120, sec))
    rumble = amp(rumble, amp(amp(adsr(sec, 0.15, 1.5), wobble(sec, 3, 0.4, 1)), decay(sec, 2.2, 0.15)))
    deep = amp(norm(lp(noise(sec), 60)), amp(wobble(sec, 2, 0.5, 1), decay(sec, 2.0, 0.3)))
    return reverb(layer((crack, 0, 1.2), (norm(rumble), 0.08), (deep, 0.05, 0.8)), 2.0, 0.4, 2.0)


@sound("warehouse", "thunder_far", "normal", "soft distant rumble")
def thunder_far():
    sec = 6.0
    shape = amp(ramp([(0, 0), (1.2, 1), (2.5, 0.7), (6, 0)], sec), wobble(sec, 2.5, 0.5, 1))
    body = layer(norm(lp(noise(sec), 180)), (norm(lp(noise(sec), 70)), 0, 0.8))
    return reverb(amp(body, shape), 2.4, 0.4, 2.0, 0.6)


@sound("warehouse", "shelf_scrape_far", "normal", "heavy metal shelving dragged over concrete far away")
def shelf_scrape_far():
    sec = 2.8
    stick = creak(sec, wobble(sec, 6, 25, 60), [320, 780, 1450], 10, 0.4)
    grind = amp(bp(noise(sec), 900, 0.7), wobble(sec, 12, 0.3, 1))
    scrape = layer(norm(stick), (norm(grind), 0, 0.5), (norm(bp(stick, 520, 20)), 0, 0.3))
    pushes = ramp([(0, 0), (0.1, 1), (1.1, 0.9), (1.25, 0.15), (1.5, 0.9), (2.6, 0.8), (2.8, 0)], sec)
    return far_off(amp(scrape, pushes))


@sound("warehouse", "shelf_thud_far", "normal", "heavy shelf set down far away, echo tail")
def shelf_thud_far():
    hit = layer(thud(55, 0.6, 0.6, 0.8), (clang(180, 1.2, 0.5), 0, 0.35), (thud(70, 0.3, 0.6, 0.5), 0.12, 0.5))
    rattle = scatter(0.4, lambda: clink(random.uniform(900, 1800), 0.2), 5)
    return far_off(layer(hit, (rattle, 0.05, 0.2)), 3.5)


@sound("warehouse", "pa_chime", "loud", "old store ding dong before a PA line, detuned and warped")
def pa_chime():
    def bell(f):
        return modes(1.6, [(f, 1, 0.8), (f * 1.007, 0.6, 0.8), (f * 2.01, 0.3, 0.4), (f * 3.93, 0.1, 0.15), (f * 0.5, 0.1, 1.0)])

    chime = layer(bell(740), (bell(587), 0.55))
    chime = speed(warble(chime, 0.003, 1.3), 0.96)
    horn = crush(drive(bp(chime, 1500, 0.5), 1.5), 7)
    return reverb(horn, 2.2, 0.5, 2.5)


@sound("warehouse", "pa_glitch", "loud", "PA speaker feedback squeal and static crackle")
def pa_glitch():
    sec = 1.2
    f = [v * (1 + 0.004 * math.sin(TAU * 5 * i / SR)) for i, v in enumerate(ramp([(0, 2400), (1.2, 2650)], sec))]
    squeal = amp(drive(osc(f, sec), 2), ramp([(0, 0), (0.1, 0.3), (0.7, 1), (0.85, 1), (0.86, 0), (1.2, 0)], sec))
    crackle = layer(amp(static(sec, 4, 500, 5000), wobble(sec, 15, 0, 1, smooth=False)), (crinkle(sec, 40, 800, 4000), 0, 0.8))
    hum = lp(osc(60, sec, "square"), 400)
    pop = thud(90, 0.1, 0.6, 0.6)
    return reverb(layer((squeal, 0, 0.6), (crackle, 0, 0.5), (hum, 0, 0.12), (pop, 0, 0.5), (pop, 0.86, 0.4)), 1.6, 0.25, 0.8)


# ---------- generator ----------


def exhaust_pop():
    return layer(lp(amp(noise(0.04), decay(0.04, 0.008)), 900), (thud(55, 0.06, 0.7, 0), 0, 0.8))


def engine(sec, rate, level=1.0, miss=0.0):
    """Gas engine firing: one exhaust pop per stroke, rate and level per sample, misses skip a stroke."""
    n = n_of(sec)
    r, lv = as_list(rate, n), as_list(level, n)
    pops, t = [], 0.0
    while t < sec:
        i = min(n - 1, at_index(t))
        if random.random() >= miss:
            pops.append((exhaust_pop(), t, lv[i] * random.uniform(0.8, 1.0)))
        t += 1 / max(1.0, r[i]) * random.uniform(0.96, 1.04)
    e = layer(silence(sec), *pops)
    rattle = amp(bp(noise(len(e) / SR), 3000, 1.5), follow(e))
    return lp(layer(e, (bp(e, 350, 4), 0, 0.4), (rattle, 0, 2.5)), 3500)


def pull_cord():
    sec = 0.45
    rope = amp(bp(noise(sec), expo(600, 1800, sec), 1.0), ramp([(0, 0), (0.05, 1), (0.35, 0.8), (0.45, 0)], sec))
    chuff = layer(*[(thud(60, 0.08, 0.7, 0.5), t, 0.5) for t in (0.04, 0.13, 0.22, 0.31)])
    return layer((rope, 0, 0.6), (ratchet(0.36, 35, 2200, 500), 0, 0.4), chuff)


def rewind():
    return ratchet(0.25, 50, 3000, 800)


@sound("warehouse", "generator_pull_fail", "normal", "pull cord yank, engine coughs, no start")
def generator_pull_fail():
    cough = engine(0.5, ramp([(0, 18), (0.5, 6)], 0.5), ramp([(0, 1), (0.5, 0.3)], 0.5), 0.3)
    bang = lp(amp(noise(0.15), decay(0.15, 0.03)), 1500)
    return layer(pull_cord(), (cough, 0.4), (bang, 0.42, 0.5), (rewind(), 0.5, 0.3))


@sound("warehouse", "generator_start", "normal", "pull, sputter, catches, settles to idle")
def generator_start():
    sputter = engine(0.8, wobble(0.8, 8, 8, 20), 0.8, 0.35)
    sec = 4.0
    rate = ramp([(0, 15), (0.4, 48), (1.0, 36), (1.6, 30), (4, 30)], sec)
    run = engine(sec, rate, ramp([(0, 0.8), (0.4, 1), (3.4, 0.9), (4.0, 0)], sec))
    return layer(pull_cord(), (rewind(), 0.45, 0.3), (sputter, 0.4), (run, 1.2))


@sound("warehouse", "generator_run_loop", "normal", "small gas generator running")
def generator_run_loop():
    sec, strokes = 2.0, 60
    pops = [(exhaust_pop(), k * sec / strokes + random.uniform(-0.0006, 0.0006), random.uniform(0.8, 1.0)) for k in range(strokes)]
    e = wrap_layer(sec, *pops)
    rattle = amp(circ(lambda x: bp(x, 3000, 1.5), noise(sec)), circ(follow, e))
    whine = layer(osc(snap(60, sec), sec), (osc(snap(390, sec), sec), 0, 0.2))
    body = layer(e, (circ(lambda x: bp(x, 350, 4), e), 0, 0.4), (rattle, 0, 2.5), (whine, 0, 0.04))
    return circ(lambda x: lp(x, 3500), body)


@sound("warehouse", "generator_sputter", "normal", "running engine stutters, about to run dry")
def generator_sputter():
    sec = 3.0
    return engine(sec, wobble(sec, 3, 16, 32), wobble(sec, 4, 0.4, 1), 0.3)


@sound("warehouse", "generator_die", "normal", "engine winds down and stops, cooling metal ticks")
def generator_die():
    sec = 1.6
    run = engine(sec, expo(30, 4, sec), ramp([(0, 1), (1.6, 0.3)], sec))
    ticks = [(clink(random.uniform(2500, 4500), 0.08), random.uniform(2.0, 4.0), random.uniform(0.05, 0.1)) for _ in range(6)]
    return layer(run, (knock(120, 0.25, 1200), 1.65, 0.5), *ticks)


@sound("warehouse", "fuel_pour", "normal", "fuel glugging from a jerry can into the tank")
def fuel_pour():
    sec = 3.0
    stream = amp(bp(noise(sec), 700, 0.8), wobble(sec, 8, 0.4, 1))
    glugs, t = [], 0.1
    while t < sec - 0.3:
        g = layer(bubble(random.uniform(120, 260), 0.09, 1.6), (amp(bp(noise(0.09), 400, 3), decay(0.09, 0.03)), 0, 0.5))
        glugs.append((g, t, random.uniform(0.6, 1)))
        t += random.uniform(0.12, 0.25)
    splash = scatter(sec, lambda: bubble(random.uniform(800, 2000), random.uniform(0.02, 0.05)), 60)
    pour = layer((stream, 0, 0.35), (splash, 0, 0.2), *glugs)
    pour = amp(pour, ramp([(0, 0), (0.1, 1), (2.7, 1), (3.0, 0)], sec))
    return layer(pour, (bp(pour, 300, 5), 0, 0.3))


@sound("warehouse", "phone_ring_far", "normal", "old bell phone ringing far off in the dark")
def phone_ring_far():
    def gong(f):
        return modes(0.5, [(f, 1, 0.25), (f * 2.76, 0.5, 0.12), (f * 5.4, 0.25, 0.06), (f * 8.9, 0.12, 0.03)])

    a, b = gong(1100), gong(1180)
    hits = [((a if k % 2 else b), start + k * 0.05, random.uniform(0.7, 1.0)) for start in (0.0, 3.0) for k in range(36)]
    ring = hp(lp(layer(*hits), 2500), 300)
    return reverb(echo(ring, 0.35, 0.3, 3), 2.5, 0.75, 3.0, 0.5, 0.88)


@sound("warehouse", "tape_insert", "normal", "cassette clacks in, play button thunk")
def tape_insert():
    slide = amp(bp(noise(0.1), 2000, 1), adsr(0.1, 0.02, 0.03))
    seat = layer(knock(1400, 0.05, 5000), (click(3500, 0.01, 2), 0, 0.5))
    door = layer(knock(900, 0.06, 4000), (click(2500, 0.01, 2), 0, 0.5))
    play = layer(knock(300, 0.1, 1500), (click(1800, 0.012, 2), 0, 0.5), (thud(90, 0.08, 0.7, 0.3), 0, 0.6))
    motor = amp(servo(0.4, ramp([(0, 60), (0.2, 120)], 0.4), 0.2, 700), adsr(0.4, 0.15, 0.1))
    return layer((slide, 0, 0.3), (seat, 0.1), (door, 0.4), (play, 0.85), (motor, 0.9, 0.15))


@sound("warehouse", "tape_hiss_loop", "quiet", "old cassette hiss with wow")
def tape_hiss_loop():
    sec = 4.0
    n = n_of(sec)
    wow, flutter = snap(0.5, sec), snap(7, sec)
    hiss_ = layer(norm(circ(lambda x: hp(x, 2500), noise(sec))), (norm(circ(lambda x: bp(x, 6000, 0.6), noise(sec))), 0, 0.5))
    swing = [1 + 0.15 * math.sin(TAU * wow * i / SR) + 0.05 * math.sin(TAU * flutter * i / SR) for i in range(n)]
    hum = osc([snap(50, sec) * (1 + 0.006 * math.sin(TAU * wow * i / SR)) for i in range(n)])
    rumble = norm(circ(lambda x: lp(x, 100), noise(sec)))
    pops = wrap_layer(sec, *[(click(random.uniform(2000, 5000), 0.003, 1), random.uniform(0, sec), random.uniform(0.1, 0.3)) for _ in range(8)])
    return layer(amp(hiss_, swing), (hum, 0, 0.05), (rumble, 0, 0.15), (pops, 0, 0.5))


# ---------- output ----------


def tighten(x):
    """Cut leading and trailing silence so the sound plays the moment it is triggered."""
    p = peak(x) or 1.0
    start = next(i for i, v in enumerate(x) if abs(v) > p * 0.003)
    end = len(x) - next(i for i, v in enumerate(reversed(x)) if abs(v) > p * 0.001)
    return fade(x[start:end], 0.0, 0.008)


def finish(name, tier, x):
    if name.endswith("_loop"):
        x = circ(dcblock, x)
    else:
        x = tighten(dcblock(x))
    return norm(x, 10 ** (PEAK_DB[tier] / 20))


def write_mp3(x, path, tmp):
    wav = Path(tmp) / "clip.wav"
    with wave.open(str(wav), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(array("h", [int(max(-1.0, min(1.0, v)) * 32767) for v in x]).tobytes())
    path.parent.mkdir(parents=True, exist_ok=True)
    cmd = ["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-ac", "1", "-ar", str(SR), "-c:a", "libmp3lame", "-b:a", "128k", str(path)]
    subprocess.run(cmd, check=True)


def write_index():
    rows = []
    for key, title in GROUPS.items():
        rows.append(f"<h2>{html.escape(title)}</h2>")
        for group, name, tier, note, _ in SOUNDS:
            if group != key:
                continue
            loop = " loop" if name.endswith("_loop") else ""
            rows.append(
                f'<div class="row"><span class="name">{name}</span><span class="tier {tier}">{tier}{loop}</span>'
                f'<span class="note">{html.escape(note)}</span>'
                f'<audio controls preload="none"{" loop" if loop else ""} src="{group}/{name}.mp3"></audio></div>'
            )
    skipped = "".join(f"<li>{html.escape(s)}</li>" for s in SKIPPED)
    page = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Year 2029 sounds</title>
<style>
body {{ background: #111316; color: #d8dde3; font: 15px/1.4 system-ui, sans-serif; margin: 2rem auto; max-width: 980px; padding: 0 1rem; }}
h1 {{ font-size: 1.5rem; }} h2 {{ margin-top: 2rem; border-bottom: 1px solid #2b3036; padding-bottom: .3rem; }}
.row {{ display: grid; grid-template-columns: 210px 90px 1fr 300px; gap: .8rem; align-items: center; padding: .3rem 0; border-bottom: 1px solid #1c2025; }}
.name {{ font-family: ui-monospace, monospace; }} .note {{ color: #8b939c; }}
.tier {{ font-size: .8rem; border-radius: 4px; padding: .1rem .4rem; text-align: center; }}
.loud {{ background: #5a1e1e; }} .normal {{ background: #4a3d16; }} .quiet {{ background: #1d3a2a; }}
audio {{ width: 300px; height: 32px; }}
</style></head><body>
<h1>Year 2029 sounds</h1>
<p>{len(SOUNDS)} sounds, all made from scratch by <code>_kit/sounds.py</code>. Loud peaks near -1 dB, normal near -6, quiet near -12. Loops repeat on their own here.</p>
{chr(10).join(rows)}
<h2>Not in the pack</h2><ul>{skipped}</ul>
</body></html>
"""
    (OUT / "index.html").write_text(page)


def main():
    words = sys.argv[1:]
    todo = [s for s in SOUNDS if not words or any(w in s[1] for w in words)]
    with tempfile.TemporaryDirectory() as tmp:
        for k, (group, name, tier, _, fn) in enumerate(todo, 1):
            random.seed(name)
            write_mp3(finish(name, tier, fn()), OUT / group / f"{name}.mp3", tmp)
            print(f"[{k}/{len(todo)}] {group}/{name}", flush=True)
    write_index()


if __name__ == "__main__":
    main()
