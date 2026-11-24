import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *  # noqa


@item("wall_panel", "furniture", size=1024)
def wall_panel(P):
    w, h = 8, 9
    P.add("Body", box((w, 0.5, h), plain(CREAM, grime=0.2, vary=0.15), loc=(0, 0, h / 2), r=0.04, n=1))
    P.add("Body", box((w, 0.56, 0.5), enamel(WHITE), loc=(0, 0, 0.25), r=0.04, n=1))
    P.add("Body", box((w, 0.08, 4.0), plain(MINT, grime=0.15, vary=0.15), loc=(0, -0.27, 2.5), r=0.0, n=1))
    P.add("Body", box((w, 0.12, 0.12), enamel(WHITE), loc=(0, -0.3, 4.5), r=0.03, n=1))
    P.add("Body", box((2.6, 0.12, 1.9), oak(), loc=(1.4, -0.3, 6.3), r=0.04, n=1))
    P.add("Screen", box((2.3, 0.02, 1.6), flat("#7cb6d8"), loc=(1.4, -0.37, 6.3), r=0.0, n=1))
    P.add("Body", box((0.6, 0.15, 0.6), plain(WHITE), loc=(-2.5, -0.32, 7.0), r=0.3, n=1))
    P.add("Body", box((0.04, 0.02, 0.22), flat("#222222"), loc=(-2.5, -0.4, 7.05), r=0.0, n=1))


@item("door_frame", "furniture")
def door_frame(P):
    w, h, ow, oh = 5, 8.5, 3.5, 7
    wall = plain(CREAM, grime=0.2, vary=0.15)
    side = (w - ow) / 2
    for sx in (-1, 1):
        P.add("Body", box((side, 0.5, h), wall, loc=(sx * (ow / 2 + side / 2), 0, h / 2), r=0.03, n=1))
        P.add("Body", box((0.3, 0.62, oh + 0.15), enamel(WHITE), loc=(sx * (ow / 2 + 0.05), 0, (oh + 0.15) / 2), r=0.04, n=1))
    P.add("Body", box((ow, 0.5, h - oh), wall, loc=(0, 0, oh + (h - oh) / 2), r=0.03, n=1))
    P.add("Body", box((ow + 0.4, 0.62, 0.3), enamel(WHITE), loc=(0, 0, oh + 0.1), r=0.04, n=1))
    P.add("Glow", box((1.4, 0.1, 0.45), glow("#43a047", core="#c8e6c9"), loc=(0, -0.3, oh + 0.65), r=0.03, n=1))
    P.add("Body", words("EXIT", 0.26, flat("#ffffff"), loc=(0, -0.36, oh + 0.65), depth=0.005))
    P.add("Body", spray("?", 0.7, 1.05, oh + 0.62, -0.32, drips=((-0.02, 0.6), (0.06, 0.35)), rot=8))


@item("rug", "furniture")
def rug(P):
    P.add("Body", box((6, 4, 0.06), cloth(CORAL, dirt=0.15, weave=90), loc=(0, 0, 0.03), r=0.02, n=1))
    P.add("Body", box((5.2, 3.2, 0.065), cloth(CREAM, dirt=0.1, weave=90), loc=(0, 0, 0.032), r=0.01, n=1))
    P.add("Body", box((4.4, 2.4, 0.07), cloth(MINT, dirt=0.1, weave=90), loc=(0, 0, 0.035), r=0.01, n=1))


main()
