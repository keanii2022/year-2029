#!/usr/bin/env python3
"""Makes stand-in voice clips for every line the game speaks that Keani hasn't recorded.

Reads every { voice = "...", text = "..." } line in src/shared/Config plus the extra ids in
EXTRA below, and writes art/sounds/voice/<id>.mp3 with the Mac's built-in voices run through a
store-speaker, robot or whisper treatment. Never overwrites a clip that already exists, so
Keani's own recordings always win; delete a generated clip to make it again.

Run from the repo root: python3 art/_kit/voice_lines.py [--dry]
"""
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "art", "sounds", "voice")
CONFIG = os.path.join(ROOT, "src", "shared", "Config")

# Lines the code plays by name that aren't written as { voice, text } in a config file
EXTRA = {
    "voice_error_training": ("robot", "ERROR. NEEDS MORE TRAINING."),
    "voice_error_task": ("robot", "ERROR. TASK NOT FOUND."),
    "voice_error_data": ("robot", "ERROR. NOT ENOUGH DATA."),
    "voice_error_retry": ("robot", "ERROR. PLEASE TRY AGAIN TOMORROW."),
    "button_good_job": ("bright", "Good job!"),
    "button_task_complete": ("bright", "Task complete!"),
    "button_you_did_it": ("bright", "You did it!"),
    "phone_message": (
        "phone",
        "Hello! Thank you for calling. Your call is very important to us. Please stay on the line. "
        "We know where you are. Please hold.",
    ),
    "walkie_intro": (
        "walkie",
        "Is this thing on? If you can hear me, hide when the lights go out. "
        "When they come back on, the robots freeze. Over.",
    ),
    "kid_found_you": ("kid", "Found you."),
    "kid_come_find_me": ("kid", "Come find me."),
}

# Voice, speaking rate and the ffmpeg treatment for each style
SPEAKER = "highpass=f=350,lowpass=f=3300,acompressor=threshold=0.1:ratio=4,volume=1.6,aecho=0.8:0.55:140|320:0.28|0.14"
STYLES = {
    "pa": ("Samantha", 165, SPEAKER),
    "pa_night": ("Samantha", 138, "asetrate=44100*0.96,aresample=44100," + SPEAKER),
    "bright": ("Samantha", 185, "highpass=f=200,lowpass=f=5000,volume=1.4"),
    "phone": ("Samantha", 160, "highpass=f=500,lowpass=f=2800,acompressor,volume=1.8"),
    "walkie": ("Daniel", 170, "highpass=f=600,lowpass=f=2600,acrusher=bits=10:mix=0.4,volume=1.8"),
    "kid": ("Junior", 120, "asetrate=44100*1.12,aresample=44100,lowpass=f=4000,aecho=0.8:0.7:400|900:0.3|0.2,volume=1.2"),
    "robot": ("Ralph", 150, None),  # None: run through _kit/robotize.sh instead
}


def config_lines():
    """{ voice = "id", text = "..." } across config files, on one line or spread over a few."""
    lines = {}
    pattern = re.compile(r'voice\s*=\s*"([a-z0-9_]+)"\s*,\s*text\s*=\s*"((?:[^"\\]|\\.)*)"', re.S)
    for name in sorted(os.listdir(CONFIG)):
        if not name.endswith(".luau"):
            continue
        source = open(os.path.join(CONFIG, name)).read()
        for voice, text in pattern.findall(source):
            style = "pa_night" if name == "NightTricks.luau" else "pa"
            lines.setdefault(voice, (style, text.replace('\\"', '"')))
    return lines


def speak(voice_id, style, text):
    voice, rate, treatment = STYLES[style]
    out = os.path.join(OUT, voice_id + ".mp3")
    with tempfile.TemporaryDirectory() as tmp:
        raw = os.path.join(tmp, "raw.aiff")
        subprocess.run(["say", "-v", voice, "-r", str(rate), "-o", raw, text], check=True)
        if treatment is None:
            subprocess.run([os.path.join(ROOT, "art", "_kit", "robotize.sh"), raw, out], check=True)
        else:
            subprocess.run(
                ["ffmpeg", "-v", "error", "-y", "-i", raw, "-af", treatment + ",apad=pad_dur=0.1",
                 "-ac", "1", "-ar", "44100", "-c:a", "libmp3lame", "-b:a", "128k", out],
                check=True,
            )


def main():
    dry = "--dry" in sys.argv
    lines = config_lines()
    for voice_id, entry in EXTRA.items():
        lines.setdefault(voice_id, entry)
    made = kept = 0
    for voice_id, (style, text) in sorted(lines.items()):
        if os.path.exists(os.path.join(OUT, voice_id + ".mp3")):
            kept += 1
            continue
        print(f"{voice_id} [{style}]: {text}")
        if not dry:
            speak(voice_id, style, text)
        made += 1
    print(f"{made} made, {kept} kept (already recorded or generated)")


if __name__ == "__main__":
    main()
