"""Candidate scary robot noises for Keani to listen to and pick from (ideas in the scary-robots research note).

Writes art/sounds/robot_samples/NN_name.mp3 and an index.html that plays them. Nothing here is in the game yet:
the uploader skips this folder. Everything sits quiet to medium and stays smooth (Keani: scary, not overstimulating).
Voice-based ones process copies of Keani's own robot clips; the originals are never touched.

Run from art/: python3 _kit/robot_samples.py [number or name ...]
--game copies every sample into sounds/robots/ as robot_<name>, plus robot_copy_callout_0..6.
"""
import html, math, os, random, subprocess, sys, tempfile
from array import array
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sounds as S
from sounds import (SR, TAU, amp, bp, click, clang, crush, decay, expo, fade, hp, hum_loop, hydraulic, joint_creak, knock,
                    layer, lp, motor, noise, n_of, osc, ramp, ratchet, reverb, scatter, servo, silence, speed, static, warble,
                    wobble, adsr, brown, cat)

ART = Path(__file__).resolve().parent.parent
OUT = ART / "sounds" / "robot_samples"
RMS_DB = {"quiet": -33.0, "medium": -26.0}
CEILING_DB = -6.0
SAMPLES = []


def sample(name, level, what, when):
    def reg(fn):
        SAMPLES.append((name, level, what, when, fn))
        return fn
    return reg


def load(rel):
    """An mp3 from art/sounds as a mono float list."""
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(ART / "sounds" / rel), "-ac", "1", "-ar", str(SR), "-f", "s16le", "-"],
                         capture_output=True, check=True).stdout
    return [v / 32768 for v in array("h", raw)]


def soften(x, top=6500):
    """Round off the harsh top end so nothing stabs the ears."""
    return lp(x, top)


def tape_stop(x, sec):
    """Playback slowing to a halt over the last `sec` seconds, like the power dying."""
    n, start = len(x), max(0, len(x) - n_of(sec))
    out, pos = list(x[:start]), float(start)
    rate = 1.0
    while pos < n - 1 and rate > 0.02:
        k = int(pos)
        out.append(x[k] + (x[k + 1] - x[k]) * (pos - k))
        rate = max(0.0, 1.0 - (len(out) - start) / n_of(sec))
        pos += rate
    return out


def stutter(x, piece_sec, repeats):
    """Repeat the opening piece of a line a few times before letting it play on: 'val-val-valued'."""
    p = fade(x[:n_of(piece_sec)], 0.003, 0.01)
    return cat(*([p + silence(0.04)] * repeats), x)


# ---------------------------------------------------------------- the samples

@sample("wet_servo_breath", "quiet", "a slow in-and-out hiss, like the robot is breathing", "a still robot watching you at night")
def wet_servo_breath():
    def breath(sec, up):
        f = expo(500, 1400, sec) if up else expo(1300, 450, sec)
        body = amp(bp(noise(sec), f, 1.5), adsr(sec, sec * 0.45, sec * 0.5))
        return lp(layer(body, (amp(motor(sec, 38, 0.3, 300), adsr(sec, sec * 0.4, sec * 0.5)), 0, 0.25)), 2500)
    return layer(breath(1.6, True), (breath(1.9, False), 1.8), (breath(1.6, True), 4.6, 0.8))


@sample("neck_crank", "medium", "a slow ratcheting tick-tick-tick as a head turns", "the corner Watcher or scout turning to face you")
def neck_crank():
    sec = 2.4
    ticks = ratchet(sec, 8, f=1500, f2=420)
    grind = amp(joint_creak(sec, ramp([(0, 30), (sec, 60)], sec)), adsr(sec, 0.3, 0.6))
    return soften(reverb(layer((ticks, 0, 0.7), (grind, 0, 0.6)), 0.6, 0.18, 0.5), 5000)


@sample("lens_focus", "quiet", "a thin whine that rises, then a soft click", "a scout locking on to you")
def lens_focus():
    sec = 1.6
    whine = amp(osc(expo(900, 3100, sec), sec), ramp([(0, 0), (0.3, 0.4), (sec, 1)], sec))
    spin = amp(servo(sec, expo(120, 300, sec), 0.2, 1800), ramp([(0, 0.2), (sec, 0.6)], sec))
    return soften(reverb(layer((whine, 0, 0.35), (spin, 0, 0.5), (click(2200, 0.02, 2), sec, 0.9), (knock(600, 0.08), sec, 0.5)),
                         0.5, 0.15, 0.6), 5500)


@sample("broken_welcome", "medium", "your robot voice catching on its first syllable and repeating it, a bit crushed", "a chore bot noticing you")
def broken_welcome():
    line = load("voice/robot_notice.mp3")
    first = stutter(line, 0.16, 3)
    again = tape_stop(stutter(line, 0.12, 2), 0.5)
    x = cat(first, silence(0.6), again)
    x = layer((crush(x, 7, 2), 0, 0.6), (x, 0, 0.5))
    return soften(warble(x, 0.0012, 1.3), 5000)


@sample("smile_glitch", "medium", "a short tape-stop squelch into a few wrong jingle notes", "the cleaner's smiley face cracking to red")
def smile_glitch():
    jingle = load("robots/jingle_distorted.mp3")[: n_of(2.6)]
    stop = tape_stop(jingle, 0.9)
    fizz = amp(static(0.35, 6, 600, 4000), decay(0.35, 0.1))
    return soften(layer((crush(stop, 6, 3), 0, 0.8), (fizz, len(stop) / SR - 0.1, 0.3)), 4500)


@sample("floor_scrape_drag", "medium", "long metal dragging you can follow by ear, close and low", "the brute dragging its big arm")
def floor_scrape_drag():
    sec = 4.5
    grind = joint_creak(sec, wobble(sec, 3, 40, 90), bands=(180, 410, 900, 1700), q=6)
    drone = lp(motor(sec, 33, 0.4, 260), 400)
    swell = ramp([(0, 0), (1.5, 1), (3.5, 0.9), (sec, 0)], sec)
    return soften(amp(layer((grind, 0, 0.8), (drone, 0, 0.4), (lp(brown(sec), 300), 0, 0.3)), swell), 4000)


@sample("skitter_burst", "medium", "a fast clicking rush that stops dead", "the crawler moving, then freezing")
def skitter_burst():
    def burst(sec, count):
        taps = scatter(sec, lambda: layer(click(random.uniform(1800, 3600), 0.012, 1.5), (knock(random.uniform(300, 700), 0.04), 0, 0.4)), count)
        chain = speed(ratchet(sec * 0.7, 26, 1300, 300), 0.7)[: n_of(sec)]
        return fade(layer(taps, (chain, 0, 0.5)), 0.05, 0.004)
    return soften(cat(burst(1.1, 60), silence(0.9), burst(0.6, 35), silence(0.3)), 6000)


@sample("ceiling_tick", "quiet", "slow, spaced taps on metal from somewhere above", "a crawler up on top of the racks")
def ceiling_tick():
    taps = [(layer(knock(random.uniform(800, 1100), 0.06, 3500), (clang(random.uniform(1400, 1800), 0.25, 0.3), 0, 0.15)), t, g)
            for t, g in ((0, 1), (0.9, 0.8), (1.5, 0.9), (2.9, 0.7), (3.3, 0.85))]
    return soften(reverb(layer(silence(3.6), *taps), 1.6, 0.45, 2.0, 0.5, 0.86), 5000)


def copy_callout(k):
    """A robot replaying a player's callout from the call wheel: a hair lower, a bit narrow, a faint digital tail.
    Close enough to the real one that you think someone's nearby."""
    x = speed(load(f"voice/callout_{k}.mp3"), 2 ** (-0.6 / 12))
    x = layer((bp(x, 1500, 0.45), 0, 0.85), (x, 0, 0.35))
    x = warble(x, 0.0006, 0.8)
    tail = amp(static(0.3, 7, 1200, 4000), decay(0.3, 0.08))
    return layer((x, 0, 1), (tail, len(x) / SR - 0.03, 0.12))


@sample("copied_callout", "medium", "a robot replaying your own callouts, Waddup twin then Yyyyo, just a little off", "a robot luring you with a player's call from the wheel")
def copied_callout():
    return cat(copy_callout(0), silence(1.1), copy_callout(1))


@sample("still_there_hum", "quiet", "the robot hum, then it cuts to silence", "a robot close by freezing: the silence is the cue")
def still_there_hum():
    h = hum_loop()
    h = (h + h)[: n_of(3.0)]
    return cat(fade(h, 0.4, 0.06), silence(2.0))


@sample("order_bell", "medium", "a counter bell slightly out of tune with itself", "the cook plating something it found")
def order_bell():
    def bell(f):
        return clang(f, 2.2, 0.7, ratios=(1, 2.76, 5.4, 8.9))
    return soften(layer(bell(1320), (bell(1320 * 2 ** (-30 / 1200)), 0.004, 0.8), (knock(900, 0.03), 0, 0.4)), 6000)


@sample("reboot_gasp", "medium", "a rising whir into a sharp intake, then a click", "a robot getting back up after a knockdown")
def reboot_gasp():
    sec = 1.8
    whir = amp(motor(sec, expo(25, 140, sec), 0.4, 700), ramp([(0, 0), (0.4, 0.5), (sec, 1)], sec))
    gasp = amp(bp(noise(0.35), expo(700, 2600, 0.35), 1.2), adsr(0.35, 0.25, 0.05))
    return soften(layer((whir, 0, 0.6), (gasp, sec - 0.2, 0.8), (click(2000, 0.02, 2), sec + 0.15, 0.7),
                        (hydraulic(0.7, 700, 2500, 0.01, 0.5), sec + 0.2, 0.35)), 5500)


@sample("scanner_sweep", "quiet", "a low, slow sonar pulse that slides down", "the carrier scanning a room")
def scanner_sweep():
    def ping(at):
        return (amp(osc(expo(900, 520, 1.4), 1.4), decay(1.4, 0.35, 0.01)), at, 0.8)
    return soften(reverb(layer(ping(0), ping(1.6), ping(3.2)), 1.3, 0.35, 1.6), 4000)


@sample("pack_chatter", "medium", "quick clicks and beeps traded back and forth at different pitches", "a pack call and the robots answering")
def pack_chatter():
    parts, t = [], 0.0
    for voice in (1.0, 0.75, 1.3, 0.85, 1.0, 0.7):
        for _ in range(random.randint(3, 6)):
            f = random.choice((600, 800, 1000, 1300)) * voice
            parts.append((amp(osc(f, 0.06, "square"), adsr(0.06, 0.004, 0.02)), t, 0.5))
            parts.append((click(2400 * voice, 0.01, 2), t + 0.07, 0.4))
            t += random.uniform(0.08, 0.14)
        t += 0.25
    return soften(lp(reverb(layer(*parts), 0.8, 0.2, 0.6), 3500), 3500)


@sample("knockdown_sputter", "medium", "your robot voice slowing and dropping as it powers down, with crackle", "a robot getting knocked down")
def knockdown_sputter():
    line = load("voice/robot_error.mp3")
    down = tape_stop(line, min(1.4, len(line) / SR * 0.7))
    sec = len(down) / SR + 1.0
    crackle = amp(scatter(sec, lambda: click(random.uniform(900, 3000), 0.01, 1), 40), ramp([(0, 0.6), (sec - 1.0, 1), (sec, 0)], sec))
    buzz = amp(lp(motor(sec, expo(60, 18, sec), 0.6, 300), 500), ramp([(0, 0.5), (sec, 0)], sec))
    return soften(layer((down, 0, 0.9), (crackle, 0, 0.25), (buzz, 0, 0.3)), 4500)


# ---------------------------------------------------------------- output

def write_page():
    rows = "".join(
        f'<div class="row"><span class="n">{k:02d}</span><span><b>{html.escape(what)}</b><br><span class="when">Plays: {html.escape(when)}</span></span>'
        f'<audio controls preload="none" src="{k:02d}_{name}.mp3"></audio></div>'
        for k, (name, _, what, when, _) in enumerate(SAMPLES, 1))
    (OUT / "index.html").write_text(f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Scary robot sound samples</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body {{ background:#0f1113; color:#d8dde3; font:16px/1.45 system-ui,sans-serif; max-width:860px; margin:2rem auto; padding:0 1rem; }}
h1 {{ font-size:1.4rem; margin-bottom:.2rem; }} p {{ color:#8b939c; margin-top:0; }}
.row {{ display:grid; grid-template-columns:36px 1fr 300px; gap:.9rem; align-items:center; padding:.6rem .4rem; border-bottom:1px solid #1d2126; }}
.n {{ font-weight:700; color:#c45a4a; text-align:right; }} .when {{ color:#8b939c; font-size:.9rem; }}
audio {{ width:300px; height:32px; }}
@media (max-width:700px) {{ .row {{ grid-template-columns:30px 1fr; }} audio {{ grid-column:2; width:100%; }} }}
</style></head><body>
<h1>Scary robot sound samples</h1>
<p>Candidates, not in the game yet. Tell me the numbers you like. Kept quiet to medium on purpose. Headphones help.</p>
{rows}
</body></html>
""")


GAME = ART / "sounds" / "robots"


def level(x, lvl):
    x = S.tighten(S.dcblock(x))
    rms = math.sqrt(sum(v * v for v in x) / len(x)) or 1.0
    gain = min(10 ** (RMS_DB[lvl] / 20) / rms, 10 ** (CEILING_DB / 20) / (S.peak(x) or 1.0))
    return [v * gain for v in x]


def export_game(tmp):
    """Keani picked all of them: copy each into the game pack, and write a robot copy of every callout."""
    for name, lvl, _, _, fn in SAMPLES:
        if name == "copied_callout":
            continue
        random.seed(name)
        S.write_mp3(level(fn(), lvl), GAME / f"robot_{name}.mp3", tmp)
    for k in range(7):
        random.seed(f"copy_callout_{k}")
        S.write_mp3(level(copy_callout(k), "medium"), GAME / f"robot_copy_callout_{k}.mp3", tmp)
    print("wrote the game copies to sounds/robots/")


def main():
    if "--game" in sys.argv:
        with tempfile.TemporaryDirectory() as tmp:
            export_game(tmp)
        return
    words = sys.argv[1:]
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for k, (name, lvl, _, _, fn) in enumerate(SAMPLES, 1):
            if words and not any(w == str(k) or w in name for w in words):
                continue
            random.seed(name)
            x = level(fn(), lvl)
            S.write_mp3(x, OUT / f"{k:02d}_{name}.mp3", tmp)
            print(f"[{k}/{len(SAMPLES)}] {name}", flush=True)
    write_page()


if __name__ == "__main__":
    main()
