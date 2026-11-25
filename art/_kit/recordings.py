# Cuts Keani's own recordings into game sounds: trims each take and sets the level. No added echo: Keani wants the raw takes.
# The raw takes live in art/sounds/recorded_raw/ (kept out of git). Run from art/: python3 _kit/recordings.py
import os, subprocess, tempfile

ART = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ART, "sounds", "recorded_raw")
OUT = os.path.join(ART, "sounds", "gear")
PEAK_DB = -1.0

# (name, source file, start sec, end sec); times are where the take sits in the raw recording
TAKES = [
    ("shot_pistol", "guns_1.m4a", 0.0, 0.5),
    ("shot_smg", "guns_1.m4a", 0.47, 1.6),
    ("shot_shotgun", "guns_1.m4a", 1.97, 2.45),
    ("shotgun_pump", "guns_1.m4a", 2.49, 2.95),  # the rack right after the blast, about half a second in
    ("shot_rifle", "guns_1.m4a", 3.33, 4.45),  # the whole three-round burst in one take
    ("shot_heavy", "guns_1.m4a", 5.31, 6.55),
    ("nail_gun", "guns_1.m4a", 7.72, 7.97),
    ("flare_pop", "guns_1.m4a", 9.98, 10.65),
    ("flare_burnout", "guns_1.m4a", 25.45, 27.45),
] + [(f"dart_pop_{k + 1}", "guns_1.m4a", start - 0.04, start + 0.5)
     for k, start in enumerate((28.38, 29.50, 30.52, 31.52, 32.50, 33.48, 34.40, 35.34))]

# The flare's burn becomes a loop: the steady stretch with its own next bit folded over the start, so the seam is seamless.
BURN = ("flare_burn_loop", "guns_1.m4a", 12.0, 8.0, 0.4)


def ffmpeg(*args):
    subprocess.run(["ffmpeg", "-v", "error", "-y", *args], check=True)


def peak_of(path):
    r = subprocess.run(["ffmpeg", "-i", path, "-af", "volumedetect", "-f", "null", "-"], capture_output=True, text=True)
    line = next(l for l in r.stderr.splitlines() if "max_volume" in l)
    return float(line.split("max_volume:")[1].split("dB")[0])


def finish(tmp_wav, name):
    gain = PEAK_DB - peak_of(tmp_wav)
    ffmpeg("-i", tmp_wav, "-af", f"volume={gain:.2f}dB", "-ac", "1", "-ar", "44100", "-c:a", "libmp3lame", "-b:a", "160k",
           os.path.join(OUT, name + ".mp3"))
    print("wrote", name)


with tempfile.TemporaryDirectory() as tmp:
    for name, src, start, end in TAKES:
        wav = os.path.join(tmp, name + ".wav")
        chain = ["highpass=f=35", "afade=t=in:d=0.004"]
        chain += [f"afade=t=out:st={max(0.0, end - start - 0.04):.3f}:d=0.04"]
        ffmpeg("-ss", f"{start:.3f}", "-to", f"{end:.3f}", "-i", os.path.join(RAW, src), "-af", ",".join(chain), wav)
        finish(wav, name)
    name, src, start, length, fold = BURN
    wav = os.path.join(tmp, name + ".wav")
    ffmpeg("-ss", f"{start:.3f}", "-t", f"{length + fold:.3f}", "-i", os.path.join(RAW, src), "-filter_complex",
           f"[0]highpass=f=35,asplit[a][b];[a]atrim=0:{length},afade=t=in:d={fold}[body];"
           f"[b]atrim={length}:{length + fold},asetpts=PTS-STARTPTS,afade=t=out:d={fold}[tail];"
           f"[body][tail]amix=inputs=2:normalize=0:duration=first", wav)
    finish(wav, name)
