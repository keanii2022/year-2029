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
    # Roblox Beams stretch the texture along u, so the head is at the right end and the tail fades left.
    # A thin white-hot core inside a wider orange glow, with most of the energy packed near the head,
    # so it reads as a fast bolt instead of an even ribbon.
    u, v = x / (w - 1), (y - (h - 1) / 2) / (h / 2)
    core = math.exp(-(v * 7.0) ** 2)
    halo = math.exp(-(v * 2.4) ** 2) * 0.55
    along = (u ** 3.2) * 0.85 + 0.15 * u
    head = min(1.0, (1 - u) * 18)
    a = min(1.0, (core + halo) * along * head * 1.15)
    t = min(1.0, abs(v) * 2.6) if core < 0.6 else 0.0
    return (*warm(t), a)


def flash(x, y, n=256):
    # Hot round core, four long main spikes and four short ones between them, with a ragged edge
    # so two flashes in a row never look the same once the game spins the card.
    dx, dy = (x - n / 2) / (n / 2), (y - n / 2) / (n / 2)
    r, ang = math.hypot(dx, dy), math.atan2(dy, dx)
    core = math.exp(-(r * 3.4) ** 2) * 1.2
    glow_ = math.exp(-(r * 1.9) ** 2) * 0.45
    rag = 0.85 + 0.15 * math.sin(ang * 23 + 1.7) * math.sin(ang * 11)
    main = abs(math.cos(ang * 2)) ** 40 * math.exp(-(r * 1.15 / rag) ** 2)
    minor = abs(math.sin(ang * 2)) ** 30 * math.exp(-(r * 2.1 / rag) ** 2)
    a = min(1.0, core + glow_ + main * 1.1 + minor * 0.8) * (1 - min(1.0, r) ** 6)
    return (*warm(min(1.0, r * 1.3)), a)


os.makedirs(OUT, exist_ok=True)
write_png(os.path.join(OUT, "bullet_tracer.png"), 256, 32, tracer)
write_png(os.path.join(OUT, "muzzle_flash_card.png"), 256, 256, flash)
print("wrote", OUT)
