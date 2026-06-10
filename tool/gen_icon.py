#!/usr/bin/env python3
"""VisaRadar Travel app icon — vibrant, premium, FULL emblem.

A saturated teal→blue diagonal gradient with a bold, solid white radar (rings +
sweep) and a crisp white location pin at the centre. High contrast and rich, so
it reads clearly on the home screen. Rendered at 4x then downscaled to 1024.
"""
import math
from PIL import Image, ImageDraw, ImageFilter

SS = 4
SIZE = 1024
S = SIZE * SS
CX = CY = S / 2

# Vibrant brand gradient
TEAL = (0, 224, 196)      # bright teal (top-left)
BLUE = (18, 92, 226)      # vivid blue (bottom-right)
WHITE = (255, 255, 255)

img = Image.new("RGB", (S, S), BLUE)
px = img.load()


def gradient():
    """Diagonal teal→blue gradient with a soft corner glow for depth."""
    for y in range(S):
        for x in range(S):
            t = (x + y) / (2 * S)            # 0 top-left → 1 bottom-right
            r = int(TEAL[0] + (BLUE[0] - TEAL[0]) * t)
            g = int(TEAL[1] + (BLUE[1] - TEAL[1]) * t)
            b = int(TEAL[2] + (BLUE[2] - TEAL[2]) * t)
            px[x, y] = (r, g, b)


gradient()
draw = ImageDraw.Draw(img, "RGBA")


def vignette():
    """Subtle darkening toward the edges for a premium, deep finish."""
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    max_r = S * 0.72
    for i in range(int(max_r), int(S * 0.40), -3):
        t = (i - S * 0.40) / (max_r - S * 0.40)
        a = int(70 * t)
        ld.ellipse([CX - i, CY - i, CX + i, CY + i], outline=(4, 20, 50, a), width=SS * 2)
    img.paste(Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB"), (0, 0))


def rings():
    for frac, a, w in [(0.46, 150, 0.010), (0.34, 130, 0.009), (0.22, 120, 0.009)]:
        r = S * frac
        draw.ellipse([CX - r, CY - r, CX + r, CY + r],
                     outline=(*WHITE, a), width=int(S * w))
    # cross hairs
    r = S * 0.46
    draw.line([CX - r, CY, CX + r, CY], fill=(*WHITE, 70), width=int(S * 0.005))
    draw.line([CX, CY - r, CX, CY + r], fill=(*WHITE, 70), width=int(S * 0.005))


def sweep():
    r = S * 0.46
    start, lead = -100, -20
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer, "RGBA")
    n = int((lead - start) / 0.5)
    for i in range(n):
        a0 = start + i * 0.5
        frac = i / n
        alpha = int(150 * (frac ** 2.0))
        if alpha <= 0:
            continue
        ld.pieslice([CX - r, CY - r, CX + r, CY + r], a0, a0 + 0.7,
                    fill=(*WHITE, alpha))
    img.paste(Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB"), (0, 0))
    lr = math.radians(lead)
    draw.line([CX, CY, CX + r * math.cos(lr), CY + r * math.sin(lr)],
              fill=(*WHITE, 235), width=int(S * 0.009))


def pin():
    """Bold solid-white location pin with a gradient-coloured hole + shadow."""
    pr = S * 0.115
    pcx = CX
    pcy = CY - S * 0.05
    tip_y = pcy + S * 0.26

    # drop shadow
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    sd.ellipse([pcx - pr, pcy - pr + S * 0.02, pcx + pr, pcy + pr + S * 0.02],
               fill=(2, 18, 44, 120))
    half = pr * 0.74
    sd.polygon([(pcx - half, pcy + pr * 0.55 + S * 0.02),
                (pcx + half, pcy + pr * 0.55 + S * 0.02),
                (pcx, tip_y + S * 0.02)], fill=(2, 18, 44, 120))
    sh = sh.filter(ImageFilter.GaussianBlur(S * 0.012))
    img.paste(Image.alpha_composite(img.convert("RGBA"), sh).convert("RGB"), (0, 0))

    # solid white pin
    draw.ellipse([pcx - pr, pcy - pr, pcx + pr, pcy + pr], fill=WHITE)
    draw.polygon([(pcx - half, pcy + pr * 0.55),
                  (pcx + half, pcy + pr * 0.55),
                  (pcx, tip_y)], fill=WHITE)

    # gradient-coloured hole (samples the bg gradient at centre)
    hr = pr * 0.40
    t = (pcx + pcy) / (2 * S)
    hole = (int(TEAL[0] + (BLUE[0] - TEAL[0]) * t),
            int(TEAL[1] + (BLUE[1] - TEAL[1]) * t),
            int(TEAL[2] + (BLUE[2] - TEAL[2]) * t))
    draw.ellipse([pcx - hr, pcy - hr, pcx + hr, pcy + hr], fill=hole)


vignette()
rings()
sweep()
pin()

import os
out = img.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB")
dest = os.path.abspath(os.path.dirname(__file__) + "/../assets/icons/app_icon.png")
os.makedirs(os.path.dirname(dest), exist_ok=True)
out.save(dest, "PNG")
print("wrote", dest)
