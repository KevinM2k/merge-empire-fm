#!/usr/bin/env python3
"""The park backdrop, with the drawing's own sky knocked out.

`backgroundColorGrass.png` is a full scene — sky, distant haze-blue trees, a
treeline, then a flat field. The pitch scene needs the TREELINE and nothing
else: it draws its own sky and its own turf, so the plate's sky arrived as a
pale rectangle with a hard top edge across the scene's darker one. Reported as
the backdrop going up about fifty points and then being cut off.

Fading the top edge only softens the line; the block of near-white sky BEHIND
the trees is the other half of what reads as a pasted rectangle. Knocking the
sky out removes both, and the scene's own sky shows through where it should.

The key is that every sky tone in this pack is a light blue — blue above red,
and bright — while the foliage is green, the trunks brown and the fence a warm
cream. The distant haze-blue trees go with the sky, which is right: they are
drawn to sit against it and they are the palest thing in the plate.
"""

import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "bg", "kenney", "backgroundColorGrass.png")
OUT = os.path.join(ROOT, "assets", "bg", "kenney", "parkTreeline.png")

# Bright, and never warmer than it is blue. Sky runs b−r ≈ +45, cloud +3, and
# the foliage is nowhere near the brightness floor (its red is 35). Cloud has to
# go with it: the scene draws its own, and one left behind hangs in a band with
# a hard edge under it, which is the same rectangle by another name.
SKY_MIN_RED = 185
SKY_MIN_BLUE_OVER_RED = 0


def main():
    im = Image.open(SRC).convert("RGBA")
    px = im.load()
    w, h = im.size
    cleared = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a and r >= SKY_MIN_RED and b - r >= SKY_MIN_BLUE_OVER_RED:
                px[x, y] = (r, g, b, 0)
                cleared += 1
    im.save(OUT, "PNG")
    print(f"  {OUT}  ({cleared * 100 // (w * h)}% cleared)")


if __name__ == "__main__":
    main()
