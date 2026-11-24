"""Shared bits for the fake-home furniture. Catalog colors, a little worn."""
import os, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "_kit"))
from ykit import *  # noqa
import kit

kit.DUST = 1.0

PINE = "#d9b98c"
OAK = "#b98a5a"
CREAM = "#f1e9d8"
MINT = "#9fd8c4"
CORAL = "#ef8a72"
BUTTER = "#f6d77a"
SKY = "#8cc2e8"
GREY = "#b9bcc2"
CHAR = "#4a4d55"
WHITE = "#f4f2ee"


def pine():
    return wood(PINE, "#a8875c", axis="x", wear=0.35)


def oak():
    return wood(OAK, "#6e4b2c", axis="x", wear=0.4)


def enamel(color):
    return plain(color, grime=0.25, vary=0.18)


def fabric(color):
    return cloth(color, dirt=0.25, weave=70)


def legs4(w, d, h, mat, t=0.22, inset=0.2, z0=0.0, taper=0.7):
    """Four square tapered legs under a w x d footprint, from z0 up to z0 + h."""
    out = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w / 2 - inset), sy * (d / 2 - inset)
            out.append(cyl(t * 0.75, h, mat, loc=(x, y, z0 + h / 2), r2=t * 0.75 / taper, seg=4, bevel=0.02, rot=(0, 0, 45)))
    return out


def handle(x, z, y, long=0.5, vertical=False, mat=None):
    """Flat bar pull on a front at depth y (front is -y)."""
    mat = mat or metal("#c9c6c0", rust=0.1)
    size = (0.08, 0.08, long) if vertical else (long, 0.08, 0.08)
    return box(size, mat, loc=(x, y - 0.06, z), r=0.03, n=1)


def door_lines(x, z, w, h, y, mat):
    """Shallow raised panel to suggest a door or drawer front."""
    return box((w, 0.04, h), mat, loc=(x, y - 0.02, z), r=0.03, n=1)


PAINT = "#e8361c"


def spray(text, size, x, z, y, drips=((0.0, 0.5),), rot=0):
    """A survivor's warning in red spray paint on a surface facing -y: the word plus paint drips.
    drips: (x offset, length) pairs."""
    mat = plain(PAINT, grime=0.25, vary=0.25)
    out = [words(text, size, mat, loc=(x, y, z), rot=(0, rot, 0), depth=0.01)]
    for dx, ln in drips:
        out.append(box((size * 0.07, 0.008, ln), mat, loc=(x + dx, y + 0.002, z - size * 0.3 - ln / 2), r=0.0, n=1))
    return out


def tag(x, z, y, text="29"):
    """Sticky price tag with a made-up number."""
    return [box((0.42, 0.02, 0.24), plain("#fffdf5", grime=0.1), loc=(x, y - 0.012, z), r=0.02, n=1),
            box((0.42, 0.022, 0.05), plain("#e53935", grime=0.1), loc=(x, y - 0.013, z + 0.1), r=0.01, n=1),
            words(text, 0.12, flat("#222222"), loc=(x, y - 0.026, z - 0.03), depth=0.005)]


def hollow(w, d, h, mat, x=0.0, y=0.0, z0=0.0, t=0.12, open_side="front", r=0.04):
    """A cabinet shell with one open side, so doors and lids reveal a real inside you can loot or hide in.
    open_side is "front" (-y) or "top"."""
    out = [box((t, d, h), mat, loc=(x + sx * (w / 2 - t / 2), y, z0 + h / 2), r=r, n=1) for sx in (-1, 1)]
    out.append(box((w, t, h), mat, loc=(x, y + d / 2 - t / 2, z0 + h / 2), r=r, n=1))
    out.append(box((w, d, t), mat, loc=(x, y, z0 + t / 2), r=r, n=1))
    if open_side == "front":
        out.append(box((w, d, t), mat, loc=(x, y, z0 + h - t / 2), r=r, n=1))
    else:
        out.append(box((w, t, h), mat, loc=(x, y - d / 2 + t / 2, z0 + h / 2), r=r, n=1))
    return out


def drawer(x, z, w, h, y, depth, front, tray=None, pull=True):
    """A real drawer: front panel, handle and an open tray behind it that shows when it slides out along -y."""
    tray = tray or plain("#d8cbb4", grime=0.2)
    th = h * 0.7
    out = [box((w, 0.1, h), front, loc=(x, y - 0.05, z), r=0.03, n=1)]
    if pull:
        out.append(handle(x, z + h * 0.1, y - 0.1, min(0.5, w * 0.35)))
    zc = z - h / 2 + 0.06 + th / 2
    out.append(box((w - 0.12, depth, 0.06), tray, loc=(x, y + depth / 2, z - h / 2 + 0.06), r=0.0, n=1))
    for sx in (-1, 1):
        out.append(box((0.06, depth, th), tray, loc=(x + sx * (w / 2 - 0.09), y + depth / 2, zc), r=0.0, n=1))
    out.append(box((w - 0.12, 0.06, th), tray, loc=(x, y + depth - 0.03, zc), r=0.0, n=1))
    return out
