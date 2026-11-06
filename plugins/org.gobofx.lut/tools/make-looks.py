#!/usr/bin/env python3
"""Generate the six bundled Look LUTs of org.gobofx.lut.

Run from anywhere:

    python3 -I plugins/org.gobofx.lut/tools/make-looks.py [out-dir]

It writes faded-film.cube, cross-process.cube, vintage.cube,
instant-camera.cube, soft-tonal.cube and print-transfer.cube into the plugin
folder (the parent of this tools/ folder) unless an output directory is given.

Each table is a 17-point `.cube` (the size of the bundled identity table; these are smooth global grades, where trilinear interpolation on 17 points is exact enough and the package stays small; header style as the bundled
warm.cube) and is authored for the plugin's default input space: display
sRGB (gamma-encoded), 0..1. The grades are built from a handful of
monotone-per-channel operations applied to each lattice node (levels,
contrast around mid grey, a smoothstep S-curve, a highlight shoulder,
saturation against Rec. 709 luma, split toning by luma weight, a midtone
tint) so every table is finite, clamped to 0..1 and monotonic-ish along each
axis. Deterministic: no randomness, standard library only, so the files it
writes are byte-identical run after run. Comments describe the intent of each
look, not the maths.
"""

import os
import sys

SIZE = 17

# Rec. 709 luma weights, applied to the encoded values (good enough for a
# saturation pivot; the LUT works in display space anyway).
LUMA = (0.2126, 0.7152, 0.0722)


def luma(c):
    return LUMA[0] * c[0] + LUMA[1] * c[1] + LUMA[2] * c[2]


def clamp01(x):
    return 0.0 if x < 0.0 else 1.0 if x > 1.0 else x


def saturate(c, s):
    """Scale chroma around luma: s=0 is black and white, s=1 unchanged."""
    l = luma(c)
    return tuple(l + (x - l) * s for x in c)


def contrast(c, k, pivot=0.5):
    return tuple(pivot + (x - pivot) * k for x in c)


def levels(c, black=0.0, white=1.0):
    """Remap 0..1 onto black..white: black>0 lifts, white<1 lowers."""
    return tuple(black + x * (white - black) for x in c)


def soft_s(c, amount):
    """Blend towards a smoothstep S-curve (monotone, fixes 0 and 1)."""
    return tuple(x + (x * x * (3.0 - 2.0 * x) - x) * amount for x in c)


def shoulder(c, knee, a):
    """Soften highlights above `knee`: slope 1 at the knee, falling to 1-2a at
    white, so pure white lands at 1 - a*(1-knee). a <= 0.5 keeps it monotone."""
    out = []
    for x in c:
        x = min(x, 1.0)  # a tint can push past white; the curve is for 0..1
        if x <= knee:
            out.append(x)
        else:
            u = (x - knee) / (1.0 - knee)
            out.append(knee + (1.0 - knee) * (u - a * u * u))
    return tuple(out)


def gain(c, rgb):
    """Per-channel multiply: a warm/cool balance."""
    return tuple(x * g for x, g in zip(c, rgb))


def split_tone(c, shadows, highlights, strength=1.0):
    """Add a colour offset weighted (1-l)^2 in the shadows and l^2 in the
    highlights, so mid grey is left alone and the two tints never meet."""
    l = luma(c)
    ws = (1.0 - l) ** 2
    wh = l * l
    return tuple(x + strength * (ws * s + wh * h) for x, s, h in zip(c, shadows, highlights))


def midtone_tint(c, rgb, strength=1.0):
    """Add a colour offset weighted 4l(1-l): full at mid grey, nothing at the ends."""
    l = luma(c)
    w = 4.0 * l * (1.0 - l)
    return tuple(x + strength * w * t for x, t in zip(c, rgb))


# --- the looks -------------------------------------------------------------

def faded_film(c):
    # Lifted blacks, less contrast, a touch of warmth in the highlights,
    # slightly muted colour: the matte "faded print" look.
    c = saturate(c, 0.85)
    c = contrast(c, 0.88)          # black lands near 0.06, white near 0.94
    c = levels(c, black=0.02)      # ... and the black point ends up at ~0.08
    c = split_tone(c, shadows=(0.0, 0.0, 0.0), highlights=(0.035, 0.012, -0.03))
    return c


def cross_process(c):
    # Slide film through C-41: cyan/blue shadows, yellow highlights, a green
    # midtone cast and more contrast and colour than it should have.
    c = saturate(c, 1.15)
    c = soft_s(c, 0.35)
    c = contrast(c, 1.2)
    c = split_tone(c, shadows=(-0.07, 0.02, 0.12), highlights=(0.07, 0.06, -0.12))
    c = midtone_tint(c, (-0.015, 0.06, -0.025))
    return c


def vintage(c):
    # Warm and faded with a magenta lean, lifted blacks and soft highlights.
    c = saturate(c, 0.88)
    c = gain(c, (1.06, 0.99, 0.90))
    c = contrast(c, 0.92)
    c = midtone_tint(c, (0.02, -0.03, 0.015))
    c = shoulder(c, knee=0.65, a=0.2)
    c = levels(c, black=0.07, white=0.98)
    return c


def instant_camera(c):
    # The chemistry of an instant print: cyan shadows, warm highlights, low
    # saturation, blacks that never get black and whites that never get white.
    c = saturate(c, 0.72)
    c = shoulder(c, knee=0.6, a=0.2)
    c = levels(c, black=0.07, white=0.98)  # white ends near 0.9: slightly crushed
    # Tint last, so the shoulder does not flatten the warmth out of the whites.
    c = split_tone(c, shadows=(-0.06, 0.03, 0.07), highlights=(0.06, 0.025, -0.05))
    return c


def soft_tonal(c):
    # Black and white with a gentle S-curve and slightly lifted blacks.
    c = saturate(c, 0.0)
    c = soft_s(c, 0.5)
    c = levels(c, black=0.04, white=0.98)
    return c


def print_transfer(c):
    # A dupe of a dupe: muted colour, a slight green cast, whites that do
    # not reach paper white.
    c = saturate(c, 0.7)
    c = contrast(c, 0.95)
    c = midtone_tint(c, (-0.015, 0.035, -0.015))
    c = split_tone(c, shadows=(0.0, 0.0, 0.0), highlights=(-0.01, 0.02, -0.01))
    c = shoulder(c, knee=0.6, a=0.3)
    c = levels(c, black=0.03, white=1.0)
    return c


LOOKS = [
    ("faded-film.cube", "Faded Film", faded_film),
    ("cross-process.cube", "Cross Process", cross_process),
    ("vintage.cube", "Vintage", vintage),
    ("instant-camera.cube", "Instant Camera", instant_camera),
    ("soft-tonal.cube", "Soft Tonal", soft_tonal),
    ("print-transfer.cube", "Print Transfer", print_transfer),
]


def write_cube(path, title, fn, n=SIZE):
    lines = ['TITLE "%s"' % title, "LUT_3D_SIZE %d" % n, ""]
    # Red fastest, then green, then blue (spec/assets.md).
    for b in range(n):
        for g in range(n):
            for r in range(n):
                c = fn((r / (n - 1), g / (n - 1), b / (n - 1)))
                o = tuple(clamp01(x) for x in c)
                for x in o:
                    if x != x:  # NaN
                        raise SystemExit("%s: NaN at %d %d %d" % (path, r, g, b))
                lines.append("%.6f %.6f %.6f" % o)
    with open(path, "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def main(argv):
    here = os.path.dirname(os.path.abspath(__file__))
    out = argv[1] if len(argv) > 1 else os.path.dirname(here)
    for name, title, fn in LOOKS:
        path = os.path.join(out, name)
        write_cube(path, title, fn)
        print("wrote %s" % path)


if __name__ == "__main__":
    main(sys.argv)
