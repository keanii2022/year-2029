# Writes the effect textures to art/effects/: a bullet tracer streak and a muzzle flash card, both PNG with alpha.
# Plain Python (no image libraries on this machine): python3 _kit/effects.py from art/
import math, os, struct, zlib

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "effects")


def write_png(path, w, h, pixel):
    rows = bytearray()
    for y in range(h):
        rows.append(0)
        for x in range(w):
            rows.extend(bytes(max(0, min(255, int(c * 255 + 0.5))) for c in pixel(x, y)))

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def warm(t):
    """0 = white-hot core, 1 = orange edge."""
    return (1.0, 0.95 - 0.4 * t, 0.8 - 0.75 * t)


def tracer(x, y, w=256, h=32):
    # Roblox Beams stretch the texture along u, so the head is at the right end and the tail fades left
    u, v = x / (w - 1), (y - (h - 1) / 2) / (h / 2)
    across = math.exp(-(v * 3.2) ** 2)
    along = u ** 1.6 * min(1.0, (1 - u) * 40)
    a = across * along
    return (*warm(min(1.0, abs(v) * 1.8)), a)


def flash(x, y, n=256):
    dx, dy = (x - n / 2) / (n / 2), (y - n / 2) / (n / 2)
    r, ang = math.hypot(dx, dy), math.atan2(dy, dx)
    core = math.exp(-(r * 3.0) ** 2)
    spikes = max(0.0, math.cos(ang * 3.5) ** 24) * math.exp(-(r * 1.6) ** 2) * (1 - min(1.0, r))
    a = min(1.0, core + spikes * 0.9)
    return (*warm(min(1.0, r * 1.6)), a)


os.makedirs(OUT, exist_ok=True)
write_png(os.path.join(OUT, "bullet_tracer.png"), 256, 32, tracer)
write_png(os.path.join(OUT, "muzzle_flash_card.png"), 256, 256, flash)
print("wrote", OUT)
